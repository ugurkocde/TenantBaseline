function Get-TBGradientString {
    <#
    .SYNOPSIS
        Renders a string with per-character gradient coloring.
    .DESCRIPTION
        Applies ANSI 24-bit color codes to each character, linearly interpolating
        between the start and end RGB values. Uses StringBuilder for performance.
    .PARAMETER Text
        The text to render with gradient.
    .PARAMETER StartRGB
        Array of 3 integers [R, G, B] for the start color.
    .PARAMETER EndRGB
        Array of 3 integers [R, G, B] for the end color.
    .PARAMETER Prefix
        Optional ANSI prefix applied before each character color (e.g., bold/italic).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int[]]$StartRGB,

        [Parameter(Mandatory = $true)]
        [int[]]$EndRGB,

        [Parameter()]
        [string]$Prefix = ''
    )

    if ($Text.Length -eq 0) { return '' }

    $esc = [char]27
    $reset = "${esc}[0m"
    $sb = [System.Text.StringBuilder]::new($Text.Length * 20)

    $len = $Text.Length
    if ($len -eq 1) {
        $null = $sb.Append("${Prefix}${esc}[38;2;$($StartRGB[0]);$($StartRGB[1]);$($StartRGB[2])m$($Text)${reset}")
        return $sb.ToString()
    }

    for ($i = 0; $i -lt $len; $i++) {
        $ratio = $i / ($len - 1)
        $r = [int]($StartRGB[0] + ($EndRGB[0] - $StartRGB[0]) * $ratio)
        $g = [int]($StartRGB[1] + ($EndRGB[1] - $StartRGB[1]) * $ratio)
        $b = [int]($StartRGB[2] + ($EndRGB[2] - $StartRGB[2]) * $ratio)
        $null = $sb.Append("${Prefix}${esc}[38;2;${r};${g};${b}m$($Text[$i])")
    }
    $null = $sb.Append($reset)
    return $sb.ToString()
}

function Get-TBGradientLine {
    <#
    .SYNOPSIS
        Renders a line of repeated characters with gradient coloring.
    .DESCRIPTION
        Creates a string of the specified character repeated for the given length,
        with per-character gradient from start to end RGB values.
    .PARAMETER Character
        The character to repeat (e.g., a Unicode box-drawing character).
    .PARAMETER Length
        The number of times to repeat the character.
    .PARAMETER StartRGB
        Array of 3 integers [R, G, B] for the start color.
    .PARAMETER EndRGB
        Array of 3 integers [R, G, B] for the end color.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Character,

        [Parameter(Mandatory = $true)]
        [int]$Length,

        [Parameter(Mandatory = $true)]
        [int[]]$StartRGB,

        [Parameter(Mandatory = $true)]
        [int[]]$EndRGB
    )

    $line = $Character * $Length
    return Get-TBGradientString -Text $line -StartRGB $StartRGB -EndRGB $EndRGB
}
