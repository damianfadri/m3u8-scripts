Function Download-Stream {
[CmdletBinding()]
param (
    [Parameter(
        Mandatory=$true, 
        HelpMessage="URI of the .m3u8 file"
    )]
    [string] $Uri,

    [Parameter(
        Mandatory=$true,
        HelpMessage="Local path to the output file"
    )]
    [string] $OutputFile
)
BEGIN {
    $keyUriPattern = "#EXT-X-KEY:METHOD=AES-128,URI=""(.*)"""
    $userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:107.0) Gecko/20100101 Firefox/107.0"

    # Detect if the user uses a path with directory.
    # If there's no directory, use the current directory instead.
    $filename = [System.IO.Path]::GetFileName($OutputFile)
    $directory = [System.IO.Path]::GetDirectoryName($OutputFile)
    if ([string]::IsNullOrWhiteSpace($directory)) {
        $directory = (Get-Location).Path
    }
}
PROCESS {
    Write-Output "Querying .m3u8 URI $uri..."
    Write-Output ""

    $content = 
        [System.Text.Encoding]::UTF8.GetString(
            (
                Invoke-WebRequest `
                    -Uri "$Uri" `
                    -UseBasicParsing
            ).
            Content
        )

    Write-Output "Found .m3u8 content with length $($content.Length)"
    Write-Output "Extracting AES key URI..."
    Write-Output ""

    $keyUri = 
    (
        Select-String `
            -Pattern $keyUriPattern `
            -InputObject $content
    ).
    Matches.
    Groups[1].
    Value

    Write-Output "Found AES key URI $keyUri"
    Write-Output "Querying AES key URI $keyUri..."
    Write-Output ""

    $keyContent = 
    (
        (Invoke-WebRequest `
            -Uri $keyUri `
            -UserAgent $userAgent `
            -UseBasicParsing `
        ).
        Content 
    )

    Write-Output "Found AES key content with length $($keyContent.Length)"
    Write-Output "Converting to hexadecimal..."
    Write-Output ""

    $key = 
    (
        $keyContent `
        | Format-Hex `
        | Select-Object `
            -Expand Bytes `
        | ForEach-Object `
            { '{0:x2}' -f $_ }
    ) `
    -join ''

    Write-Output "Converted to hexadecimal key $key"
    Write-Output "Downloading stream to $output..."

    # Use a temporary filename during download 
    # since hlsdl rejects some characters in the filename.
    $tempPath = Join-Path `
        -Path $directory `
        -ChildPath "temp.ts"

    # selsta/hlsdl as external dependency.
    # https://github.com/selsta/hlsdl
    hlsdl `
        -o $tempPath `
        -K $key `
        $Uri
}
END {
    # Rename the file back to the original output filename.
    Rename-Item `
        -Path $tempPath `
        -NewName $filename
}
}