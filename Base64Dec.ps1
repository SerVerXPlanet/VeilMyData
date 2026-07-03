param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [string]$InputFile,
    [Parameter(Mandatory = $true, Position = 1)]
    [string]$OutputFile
)


function Decode-File {
    param (
        [Parameter(Mandatory = $true)]
        [string]$inFile,
        [Parameter()]
        [string]$outFile
    )

    if (Test-Path -Path $inFile) {
        $base64 = Get-Content -Path $inFile -Raw
    } else {
        $base64 = $inFile
    }

    $bytes = [Convert]::FromBase64String($base64)

    Set-Content -Path $outFile -Value $bytes -Encoding Byte
}


Decode-File $InputFile $OutputFile
