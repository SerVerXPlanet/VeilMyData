param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [string]$InputFile,
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 1)]
    [string]$OutputFile,
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 2)]
    [string]$Key
)


function Using-Object
{
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

    try
    {
        . $ScriptBlock
    }
    finally
    {
        if ($null -ne $InputObject -and $InputObject -is [System.IDisposable])
        {
            $InputObject.Dispose()
        }
    }
}


function Xor-Block {
    param (
        [byte[]]$buffer,
        [int]$count,
        [byte[]]$passwd,
        [ref][int]$start
    )

    for ($i = 0; $i -lt $count; $i++) {
        $buffer[$i] = ($buffer[$i] -bxor $passwd[($i + $start.Value) % $passwd.Length])
    }
    
    $start.Value = ($count + $start.Value) % $passwd.Length
}


function Xor-File {
    param (
        [string]$inFile,
        [string]$outFile,
        [string]$pass
    )

    $passwd = [System.Text.Encoding]::UTF8.GetBytes($pass)

    Using-Object ($fin = New-Object System.IO.FileStream($inFile, [System.IO.FileMode]::Open)) {
        Using-Object ($fout = New-Object System.IO.FileStream($outFile, [System.IO.FileMode]::Create)) {
            $buffer = [System.Byte[]]::CreateInstance([System.Byte], 1024 * 1024)

            $start = 0

            while ($true) {
                $bytesRead = $fin.Read($buffer, 0, $buffer.Length)
                
                if ($bytesRead -eq 0) {
                    break
                }

                Xor-Block $buffer $bytesRead $passwd ([ref]$start)

                $fout.Write($buffer, 0, $bytesRead)
            }
        }
    }
}


Xor-File $InputFile $OutputFile $Key
