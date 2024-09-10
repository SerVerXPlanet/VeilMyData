param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [string]$InputFile,
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 1)]
    [string]$ChunkSize
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


function Dehumanize-Size {
    [OutputType([long])]

    param (
        [parameter(Mandatory=$true)]
        [string]$chunkSize
    )

    [string]$partStr = $chunkSize.Substring(0, $chunkSize.Length - 1)
    [string]$factor = $chunkSize.Substring($chunkSize.Length - 1, 1)
    
    [double]$part = 0
    if (![double]::TryParse($partStr, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, ([ref]$part))) {
        return 0
    }

    if ($part -lt 0) {
        $part *= -1
    }

    [long]$size = 0
    
    switch($factor) {
        "B" {
            $size = [long]$part
            break
        }
        "K" {
            $size = [long]($part * 1024)
            break
        }
        "M" {
            $size = [long]($part * 1024 * 1024)
            break
        }
        "G" {
            $size = [long]($part * 1024 * 1024 * 1024)
            break
        }
        "T" {
            $size = [long]($part * 1024 * 1024 * 1024 * 1024)
            break
        }
        default {
            $size = [long]$part
            break
        }
    }
    
    return $size
}


function Split-File {
    param (
        [parameter(Mandatory=$true)]
        [string]$inputFile,
        [parameter(Mandatory=$true)]
        [string]$chunkSize
    )

    [long]$size = Dehumanize-Size $chunkSize
            
    if ($size -eq 0) {
        return
    }
    
    Write-Output ("Block size = " + $size.ToString() + " bytes")
    
    Using-Object ($fin = New-Object System.IO.FileStream($inputFile, [System.IO.FileMode]::Open)) {
        [int]$parts = [int][System.Math]::Ceiling([double]$fin.Length / $size)
        
        Write-Output ("Count parts = " + $parts.ToString())
        
        if ($parts -gt 999) {
            Write-Output ("Too many parts")
            return
        }
        
        [byte[]]$buffer = [System.Byte[]]::CreateInstance([System.Byte], 8 * 1024 * 1024)
        
        [string]$outputFile = ""
        [long]$ost = 0
        
        for ($i = 0; $i -lt $parts; $i++) {
            $outputFile = $inputFile + (".p" + [System.String]::Format("{0:d3}", $i + 1))
            $ost = $size
            
            Using-Object ($fout = New-Object System.IO.FileStream($outputFile, [System.IO.FileMode]::Create)) {
                while ($ost -gt 0) {
                    [int]$bytesRead = $fin.Read($buffer, 0, [System.Math]::Min($buffer.Length, [int]$ost))
                    
                    if ($bytesRead -eq 0) {
                        break
                    }

                    $fout.Write($buffer, 0, $bytesRead)
                    
                    $ost -= $bytesRead
                }
            }
        }
    }
}


Split-File $InputFile $ChunkSize
