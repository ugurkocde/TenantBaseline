function Get-TBConsoleInnerWidth {
    <#
    .SYNOPSIS
        Calculates a responsive inner box width for interactive rendering.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter()]
        [int]$Minimum = 48,

        [Parameter()]
        [int]$Maximum = 100,

        [Parameter()]
        [int]$Default = 56
    )

    try {
        $windowWidth = [Console]::WindowWidth
        if ($windowWidth -le 0) {
            return $Default
        }

        # 2 leading spaces + 2 border characters + 2 safety padding
        $candidate = $windowWidth - 6
        if ($candidate -lt $Minimum) {
            return $Minimum
        }

        if ($candidate -gt $Maximum) {
            return $Maximum
        }

        return $candidate
    }
    catch {
        return $Default
    }
}
