param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [string]$InputFirstFile
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


function Merge-File {
    param (
        [parameter(Mandatory=$true)]
        [string]$inputFirstFile
    )

    $fi = New-Object System.IO.FileInfo($inputFirstFile)
    
    if (-not $fi.Exists) {
        Write-Output "File not found"
        return
    }
    
    if ($fi.Extension -ne ".p001") {
        Write-Output "It's not first part"
        return
    }
    
    [string]$outputFile = $inputFirstFile.Substring(0, $inputFirstFile.Length - 5)
    
    [string]$nextFile = $inputFirstFile
    [int]$i = 1

    Using-Object ($fout = New-Object System.IO.FileStream($outputFile, [System.IO.FileMode]::Create)) {
        [byte[]]$buffer = [System.Byte[]]::CreateInstance([System.Byte], 8 * 1024 * 1024)
        
        [bool]$lastPart = $false
        
        while ($true) {
            Using-Object ($fin = New-Object System.IO.FileStream($nextFile, [System.IO.FileMode]::Open)) {
                while ($true) {
                    [int]$bytesRead = $fin.Read($buffer, 0, $buffer.Length)
                    
                    if ($bytesRead -eq 0) {
                        break
                    }
                    
                    $fout.Write($buffer, 0, $bytesRead)
                }
            }

            $i++

            if($lastPart) {
                break
            }

            $nextFile = $outputFile + (".p" + [System.String]::Format("{0:d3}", $i))

            $nextfi = New-Object System.IO.FileInfo($nextFile)
                
            if (-not $nextfi.Exists) {
                break
            }

            if ($nextfi.Length -lt $fi.Length) {
                $lastPart = $true
            }
        }
        
        Write-Output ("Merged " + ($i - 1).ToString() + " parts")
    }
}


Merge-File $InputFirstFile
