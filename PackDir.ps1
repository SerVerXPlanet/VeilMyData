param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [string]$DirName,
    [Parameter()]
    [string]$FileName = "",
    [Parameter()]
    [bool]$IsCompressDat = $true,
    [Parameter()]
    [bool]$IsCompressNam = $true
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


function Compress-Array {
    [OutputType([byte[]])]

    param (
        [Parameter(Mandatory = $true)]
        [byte[]]$data
    )
    
    $output = New-Object System.IO.MemoryStream

    Using-Object ($dstream = New-Object System.IO.Compression.DeflateStream($output, [System.IO.Compression.CompressionMode]::Compress)) {
        $dstream.Write($data, 0, $data.Length)
    }
    
    return $output.ToArray()
}


function Write-Info {
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileStream]$fs,
        [Parameter(Mandatory = $true)]
        [bool]$isCompressNam,
        [Parameter(Mandatory = $true)]
        [bool]$isDir,
        [Parameter(Mandatory = $true)]
        [string]$name,
        [Parameter()]
        [System.Int16]$level = 0
    )

    $fs.WriteByte([System.Convert]::ToByte($isDir))
    
    if ($isDir) {
        [byte[]]$binLevel = [System.BitConverter]::GetBytes($level)
        $fs.Write($binLevel, 0, $binLevel.Length)
    }
    
    [byte[]]$binName = [System.Text.Encoding]::UTF8.GetBytes($name)
    
    if ($isCompressNam) {
        $binName = Compress-Array $binName
    }
    
    [byte[]]$binLen = [System.BitConverter]::GetBytes([System.Int16]$binName.Length)
    
    $fs.Write($binLen, 0, $binLen.Length)
    $fs.Write($binName, 0, $binName.Length)
}


function Write-Data {
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileStream]$fs,
        [Parameter(Mandatory = $true)]
        [bool]$isCompress,
        [Parameter(Mandatory = $true)]
        [long]$size,
        [Parameter(Mandatory = $true)]
        [string]$path
    )

    [byte[]]$buffer = [System.Byte[]]::CreateInstance([System.Byte], 8 * 1024 * 1024)
    [byte[]]$binSize = [System.Byte[]]::CreateInstance([System.Byte], 0)
    
    Using-Object ($data = New-Object System.IO.FileStream($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)) {
        if ($isCompress) {
            $fs.Seek(8, [System.IO.SeekOrigin]::Current) | Out-Null
            
            [long]$posBefore = $fs.Position

            Using-Object ($compressor = New-Object System.IO.Compression.DeflateStream($fs, [System.IO.Compression.CompressionMode]::Compress, $true)) {
                $data.CopyTo($compressor, $buffer.Length)
            }
            
            [long]$posAfter = $fs.Position
            
            [long]$compressSize = $posAfter - $posBefore
            $binSize = [System.BitConverter]::GetBytes($compressSize)
            $fs.Seek(-$compressSize - $binSize.Length, [System.IO.SeekOrigin]::Current) | Out-Null
            $fs.Write($binSize, 0, $binSize.Length)
            
            $fs.Seek($compressSize, [System.IO.SeekOrigin]::Current) | Out-Null
        }
        else {
            $binSize = [System.BitConverter]::GetBytes($size)
            $fs.Write($binSize, 0, $binSize.Length)
            
            $data.CopyTo($fs, $buffer.Length)
        }
    }
}


function Write-Dir {
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileStream]$fs,
        [Parameter(Mandatory = $true)]
        [bool]$isCompressDat,
        [Parameter(Mandatory = $true)]
        [bool]$isCompressNam,
        [Parameter(Mandatory = $true)]
        [string]$dirName,
        [Parameter()]
        [System.Int16]$level = 0
    )

    $level++
    
    $di = New-Object System.IO.DirectoryInfo($dirName)
    
    if (-not $di.Exists) {
        Write-Output("Directory was not found, missed")
        return
    }
    
    Write-Info $fs $isCompressNam $true $di.Name $level
    
    $files = New-Object System.Collections.Generic.List[string]([System.IO.Directory]::EnumerateFiles($di.FullName))
    
    foreach ($file in $files) {
        $fi = New-Object System.IO.FileInfo($file)
        
        if(-not $fi.Exists) {
            Write-Output("File " + $fi.FullName + " was not found, missed")
            continue
        }
        
        Write-Info $fs $isCompressNam $false $fi.Name
        Write-Data $fs $isCompressDat $fi.Length $fi.FullName
    }
    
    $dirs = New-Object System.Collections.Generic.List[string]([System.IO.Directory]::EnumerateDirectories($di.FullName))
    
    foreach ($dir in $dirs) {
        Write-Dir $fs $isCompressDat $isCompressNam $dir $level
    }
}


function Pack-Dir {
    param (
        [Parameter(Mandatory = $true)]
        [string]$dirName,
        [Parameter()]
        [string]$fileName = "",
        [Parameter()]
        [bool]$isCompressDat = $true,
        [Parameter()]
        [bool]$isCompressNam = $true
    )

    [string]$EXT = ".pkd"
    [string]$MAGIC = "EasyArchiveDir"
    [byte]$version = 2
    
    $di = New-Object System.IO.DirectoryInfo($dirName)
    
    if (-not $di.Exists) {
        Write-Output("Directory not found")
        return
    }
    
    [string]$outputFile = ""
    
    if ($fileName -eq "") {
        $outputFile = $di.FullName + $EXT
    }
    else {
        $fi = New-Object System.IO.FileInfo($fileName)
        $outputFile = $fi.FullName
    }
    
    [byte[]]$header = [System.Text.Encoding]::UTF8.GetBytes($MAGIC)
    
    Using-Object ($fout = New-Object System.IO.FileStream($outputFile, [System.IO.FileMode]::Create)) {
        $fout.Write($header, 0, $header.Length)
        $fout.WriteByte($version)
        
        [byte]$settings = 0
        
        $settings = $settings -bor [byte]([System.Convert]::ToByte($isCompressDat) -shl 7)
        $settings = $settings -bor [byte]([System.Convert]::ToByte($isCompressNam) -shl 6)
        
        $fout.WriteByte($settings)
        
        Write-Dir $fout $isCompressDat $isCompressNam $di.FullName
    }
    
    Write-Output("Created file " + $outputFile)
}


Pack-Dir $DirName $FileName $IsCompressDat $IsCompressNam
