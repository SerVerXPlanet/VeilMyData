param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [string]$InputFile,
    [Parameter()]
    [string]$Dir = ""
)


function Using-Object {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [AllowNull()]
        [Object]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    try {
        . $ScriptBlock
    }
    finally {
        if ($null -ne $InputObject -and $InputObject -is [System.IDisposable]) {
            $InputObject.Dispose()
        }
    }
}


function Decompress-Array {
    [OutputType([byte[]])]

    param (
        [Parameter(Mandatory = $true)]
        [byte[]]$data
    )
    
    $input = New-Object System.IO.MemoryStream($data)
    $output = New-Object System.IO.MemoryStream

    Using-Object ($dstream = New-Object System.IO.Compression.DeflateStream($input, [System.IO.Compression.CompressionMode]::Decompress)) {
        $dstream.CopyTo($output)
    }
    
    return $output.ToArray()
}


function Read-Block {
    [OutputType([byte[]])]

    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileStream]$fs,
        [Parameter(Mandatory = $true)]
        [int]$size
    )

    [byte[]]$buffer = [System.Byte[]]::CreateInstance([System.Byte], $size)

    [int]$bytesRead = $fs.Read($buffer, 0, $buffer.Length)
    
    if($bytesRead -ne $size) {
        Write-Output("File corrupt")
        System.Environment.Exit(1)
    }
    
    return $buffer
}


function Unpack-Dir {
    param (
        [Parameter(Mandatory = $true)]
        [string]$inputFile,
        [Parameter()]
        [string]$dir
    )

    [string]$MAGIC = "EasyArchiveDir"
    
    [int]$magicSize = $MAGIC.Length
    
    $fi = New-Object System.IO.FileInfo($inputFile)
    
    if (-not $fi.Exists) {
        Write-Output("File not found")
        return
    }
    
	[string]$exDir = ""
	
    if ($dir -eq "") {
		$exDir = $fi.Directory.FullName
    }
    else {
        $di = New-Object System.IO.DirectoryInfo($dir)
        
        if (-not $di.Exists) {
            $di = [System.IO.Directory]::CreateDirectory($di.FullName)
            
            if (-not $di.Exists) {
                Write-Output("Directory not found")
                return
            }
        }
        
		$exDir = $di.FullName
    }
	
	[System.IO.Directory]::SetCurrentDirectory($exDir)
    
    Using-Object ($fin = New-Object System.IO.FileStream($inputFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)) {
        [byte[]]$header = [System.Byte[]]::CreateInstance([System.Byte], $magicSize)
        [byte[]]$buffer = [System.Byte[]]::CreateInstance([System.Byte], 8 * 1024 * 1024)
        
        if ($fin.Length -lt 16) {
            Write-Output("File too short")
            return
        }
        
        $fin.Read($header, 0, $magicSize) | Out-Null
        
        [string]$title = [System.Text.Encoding]::UTF8.GetString($header)
        
        if ($title -ne $MAGIC) {
            Write-Output("The wrong format")
            return
        }
        
        [int]$version = $fin.ReadByte()
        
        if ($version -ne 2) {
            Write-Output("Incompatible format")
            return
        }
        
        [int]$settings = $fin.ReadByte()
        [bool]$isCompressDat = [System.Convert]::ToBoolean($settings -band (1 -shl 7))
        [bool]$isCompressNam = [System.Convert]::ToBoolean($settings -band (1 -shl 6))
        
        [bool]$isDir = $false
        [int]$sizeName = 0
        [string]$name = ""
        [long]$size = 0
        [long]$pos = 0
        [long]$ost = 0
        [int16]$level = 0
        [int16]$currentLevel = 1
        [int]$delta = 0
        [string]$outputFile = ""
        [int]$bytesRead = 0
        
        while ($fin.Position -lt $fin.Length) {
            $isDir = [System.Convert]::ToBoolean($fin.ReadByte())
            
            if ($isDir) {
                $binLevel = Read-Block $fin 2
                $level = [System.BitConverter]::ToInt16($binLevel, 0)
                
                $delta = $currentLevel - $level
                
                for ([int]$i = 0; $i -lt $delta; $i++) {
                    [System.IO.Directory]::SetCurrentDirectory((New-Object System.IO.DirectoryInfo([System.IO.Directory]::GetCurrentDirectory())).Parent.FullName)
                    $currentLevel--
                }
                
                $binLen = Read-Block $fin 2
                $sizeName = [System.BitConverter]::ToInt16($binLen, 0)
                
                $binName = Read-Block $fin $sizeName
                
                if ($isCompressNam) {
                    $binName = Decompress-Array $binName
                }
                
                $name = [System.Text.Encoding]::UTF8.GetString($binName)
                
                $di = [System.IO.Directory]::CreateDirectory([System.IO.Path]::Combine((New-Object System.IO.DirectoryInfo([System.IO.Directory]::GetCurrentDirectory())).FullName, $name))
                
                if (-not $di.Exists) {
                    Write-Output("Error in creating the structure of catalogs")
                    return
                }
                
                [System.IO.Directory]::SetCurrentDirectory($di.FullName)
                $currentLevel++
            }
            else {
                $binLen = Read-Block $fin 2
                $sizeName = [System.BitConverter]::ToInt16($binLen, 0)
                
                $binName = Read-Block $fin $sizeName
                
                if ($isCompressNam) {
                    $binName = Decompress-Array $binName
                }
                
                $name = [System.Text.Encoding]::UTF8.GetString($binName)
                
                $binSize = Read-Block $fin 8
                $size = [System.BitConverter]::ToInt64($binSize, 0)
                
                $outputFile = [System.IO.Path]::Combine((New-Object System.IO.DirectoryInfo([System.IO.Directory]::GetCurrentDirectory())).FullName, $name)
                
                Using-Object ($fout = New-Object System.IO.FileStream($outputFile, [System.IO.FileMode]::Create)) {
                    if ($isCompressDat) {
                        Using-Object ($decompressor = New-Object System.IO.Compression.DeflateStream($fin, [System.IO.Compression.CompressionMode]::Decompress, $true)) {
                            $pos = $fin.Position
                            
                            $decompressor.CopyTo($fout, $buffer.Length)
                            
                            $fin.Position = $pos + $size
                        }
                    }
                    else {
                        $ost = $size
                        
                        while ($ost -gt 0) {
                            $bytesRead = $fin.Read($buffer, 0, $(if ($ost -gt $buffer.Length) {$buffer.Length} else {[int]$ost}))
                            
                            $fout.Write($buffer, 0, $bytesRead)
                            
                            $ost -= $bytesRead
                        }
                    }
                }
            }
        }
    }

    Write-Output("Extracted to " + $exDir);
}


Unpack-Dir $InputFile $Dir
