param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [string]$InputFile,
    [Parameter(Position = 1)]
    [string]$OutputFile = ""
)


function Encode-File {
    param (
        [Parameter(Mandatory = $true)]
        [string]$inFile,
        [Parameter()]
        [string]$outFile = ""
    )

    $bytes = Get-Content -Path $inFile -Encoding Byte -ReadCount 0
    $base64 = [Convert]::ToBase64String($bytes)

    if ($outFile -eq "") {
        Write-Output($base64)
    }
    else {
        Set-Content -Path $outFile -Value $base64 -Encoding UTF8
    }
}


Encode-File $InputFile $OutputFile
