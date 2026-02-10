function Get-TBColorPalette {
    <#
    .SYNOPSIS
        Returns the color palette for premium menu rendering.
    .DESCRIPTION
        Returns a hashtable of ANSI 24-bit escape code strings based on the
        Catppuccin Mocha color scheme. On non-interactive hosts,
        returns empty strings so callers degrade gracefully.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $esc = [char]27

    if ($PSVersionTable.PSVersion.Major -ge 7) {
        return @{
            Text      = "${esc}[38;2;205;214;244m"
            Subtext   = "${esc}[38;2;166;173;200m"
            Dim       = "${esc}[38;2;108;112;134m"
            Blue      = "${esc}[38;2;137;180;250m"
            Green     = "${esc}[38;2;166;227;161m"
            Red       = "${esc}[38;2;243;139;168m"
            Yellow    = "${esc}[38;2;249;226;175m"
            Mauve     = "${esc}[38;2;203;166;247m"
            Teal      = "${esc}[38;2;148;226;213m"
            Peach     = "${esc}[38;2;250;179;135m"
            Surface   = "${esc}[38;2;69;71;90m"
            BgSelect  = "${esc}[48;2;49;50;68m"
            Bold      = "${esc}[1m"
            Italic    = "${esc}[3m"
            DimStyle  = "${esc}[2m"
            Reset     = "${esc}[0m"
        }
    }

    # Non-interactive fallback: empty strings
    $empty = @{}
    foreach ($key in @('Text','Subtext','Dim','Blue','Green','Red','Yellow','Mauve','Teal','Peach','Surface','BgSelect','Bold','Italic','DimStyle','Reset')) {
        $empty[$key] = ''
    }
    return $empty
}
