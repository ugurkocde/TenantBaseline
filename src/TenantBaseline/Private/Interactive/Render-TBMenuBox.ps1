function Render-TBMenuBox {
    <#
    .SYNOPSIS
        Renders menu items inside a rounded-corner box with in-place redraw.
    .DESCRIPTION
        Draws menu items with optional highlight indicator and checkboxes
        inside a Unicode box. Uses Console.SetCursorPosition for flicker-free
        in-place updates. Supports both single-select and multi-select modes.
        When ViewportSize is set and the item list exceeds it, only a scrollable
        window of items is rendered with scroll indicators.
    .PARAMETER Items
        Array of menu item display strings.
    .PARAMETER SelectedIndex
        The currently highlighted item index.
    .PARAMETER AnchorTop
        The console row to start rendering from.
    .PARAMETER Checked
        Optional boolean array for multi-select checkbox state.
    .PARAMETER IncludeBack
        If set, shows 'Esc to go back' in the hint line.
    .PARAMETER IncludeQuit
        If set, shows 'Esc to quit' in the hint line.
    .PARAMETER MultiSelect
        If set, renders checkboxes and shows multi-select hints.
    .PARAMETER ViewportOffset
        First item index in the visible window. Defaults to 0.
    .PARAMETER ViewportSize
        Number of item slots in the viewport. 0 means show all items (no viewport).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Items,

        [Parameter(Mandatory = $true)]
        [int]$SelectedIndex,

        [Parameter(Mandatory = $true)]
        [int]$AnchorTop,

        [Parameter()]
        [bool[]]$Checked,

        [Parameter()]
        [switch]$IncludeBack,

        [Parameter()]
        [switch]$IncludeQuit,

        [Parameter()]
        [switch]$MultiSelect,

        [Parameter()]
        [int]$ViewportOffset = 0,

        [Parameter()]
        [int]$ViewportSize = 0
    )

    $palette = Get-TBColorPalette
    $esc = [char]27
    $reset = "${esc}[0m"

    $innerWidth = Get-TBConsoleInnerWidth
    $border = ([char]0x2502)
    $hLine = ([char]0x2500)

    $blueRGB  = @(137, 180, 250)
    $mauveRGB = @(203, 166, 247)
    $fitText = {
        param([string]$Text)
        if ($null -eq $Text) { return '' }
        if ($Text.Length -le $innerWidth) { return $Text }
        if ($innerWidth -le 3) { return $Text.Substring(0, $innerWidth) }
        return $Text.Substring(0, $innerWidth - 3) + '...'
    }

    $bufferHeight = [Console]::BufferHeight

    # Determine viewport boundaries
    $useViewport = ($ViewportSize -gt 0) -and ($ViewportSize -lt $Items.Count)
    if ($useViewport) {
        $showAbove = ($ViewportOffset -gt 0)
        $showBelow = (($ViewportOffset + $ViewportSize) -lt $Items.Count)
        $slotCount = $ViewportSize
    }
    else {
        $showAbove = $false
        $showBelow = $false
        $slotCount = $Items.Count
    }

    $row = $AnchorTop

    # Empty line inside box
    $emptyLine = '  {0}{1}{2}{3}{4}' -f $palette.Surface, $border, (' ' * $innerWidth), $border, $reset
    if ($row -lt $bufferHeight) {
        [Console]::SetCursorPosition(0, $row)
        [Console]::Write($emptyLine)
    }
    $row++

    # Render item slots
    for ($slot = 0; $slot -lt $slotCount; $slot++) {
        if ($row -ge $bufferHeight) { break }
        [Console]::SetCursorPosition(0, $row)

        # Scroll-up indicator in the first slot
        if ($useViewport -and $slot -eq 0 -and $showAbove) {
            $aboveCount = $ViewportOffset
            $indicatorText = ('     {0} {1} more above' -f ([char]0x25B4), $aboveCount)
            $indicatorPadded = (& $fitText $indicatorText).PadRight($innerWidth)
            $line = '  {0}{1}{2}{3}{4}{5}' -f $palette.Surface, $border, $palette.Dim, $indicatorPadded, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset)
            [Console]::Write($line)
            $row++
            continue
        }

        # Scroll-down indicator in the last slot
        if ($useViewport -and $slot -eq ($slotCount - 1) -and $showBelow) {
            $belowCount = $Items.Count - ($ViewportOffset + $ViewportSize)
            $indicatorText = ('     {0} {1} more below' -f ([char]0x25BE), $belowCount)
            $indicatorPadded = (& $fitText $indicatorText).PadRight($innerWidth)
            $line = '  {0}{1}{2}{3}{4}{5}' -f $palette.Surface, $border, $palette.Dim, $indicatorPadded, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset)
            [Console]::Write($line)
            $row++
            continue
        }

        # Map slot to actual item index
        $i = if ($useViewport) { $ViewportOffset + $slot } else { $slot }

        $num = $i + 1
        $isHighlighted = ($i -eq $SelectedIndex)

        if ($MultiSelect -and $Checked) {
            if ($Checked[$i]) {
                $checkChar = [char]0x2611  # checked box
            }
            else {
                $checkChar = [char]0x2610  # unchecked box
            }

            if ($isHighlighted) {
                $chevron = [char]0x276F  # heavy chevron
                $itemText = ('  {0} {1} {2}  {3} {4}' -f $chevron, $checkChar, $num, ([char]0x25B8), $Items[$i])
                $padded = (& $fitText $itemText).PadRight($innerWidth)
                $line = '  {0}{1}{2}{3}{4}{5}{6}{7}' -f $palette.Surface, $border, $palette.BgSelect, $palette.Mauve, $palette.Bold, $padded, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset)
            }
            else {
                $checkColor = if ($Checked[$i]) { $palette.Green } else { $palette.Dim }
                $itemText = ('     {0} {1}  {2} {3}' -f $checkChar, $num, ([char]0x25B8), $Items[$i])
                $padded = (& $fitText $itemText).PadRight($innerWidth)
                $line = '  {0}{1}{2}{3}{4}{5}' -f $palette.Surface, $border, $checkColor, $padded, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset)
            }
        }
        else {
            if ($isHighlighted) {
                $chevron = [char]0x276F
                $itemText = ('  {0} {1}  {2} {3}' -f $chevron, $num, ([char]0x25B8), $Items[$i])
                $padded = (& $fitText $itemText).PadRight($innerWidth)
                $line = '  {0}{1}{2}{3}{4}{5}{6}{7}' -f $palette.Surface, $border, $palette.BgSelect, $palette.Mauve, $palette.Bold, $padded, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset)
            }
            else {
                $itemText = ('     {0}  {1} {2}' -f $num, ([char]0x25B8), $Items[$i])
                $padded = (& $fitText $itemText).PadRight($innerWidth)
                $line = '  {0}{1}{2}{3}{4}{5}' -f $palette.Surface, $border, $palette.Text, $padded, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset)
            }
        }

        [Console]::Write($line)
        $row++
    }

    # Empty line
    if ($row -lt $bufferHeight) {
        [Console]::SetCursorPosition(0, $row)
        [Console]::Write($emptyLine)
    }
    $row++

    # Separator line
    if ($row -lt $bufferHeight) {
        $sepGradient = Get-TBGradientLine -Character $hLine -Length $innerWidth -StartRGB $blueRGB -EndRGB $mauveRGB
        $sepLine = '  {0}{1}{2}{3}{4}' -f $palette.Surface, ([char]0x251C), $sepGradient, ([char]0x2524), $reset
        [Console]::SetCursorPosition(0, $row)
        [Console]::Write($sepLine)
    }
    $row++

    # Hint line
    if ($MultiSelect) {
        $hintText = '  Space to toggle, A for all, Enter to confirm'
    }
    else {
        $hintText = '  Use arrow keys to navigate, Enter to select'
    }

    if ($IncludeBack) {
        $hintText += ', Esc to go back'
    }
    elseif ($IncludeQuit) {
        $hintText += ', Esc to quit'
    }

    if ($row -lt $bufferHeight) {
        $hintPadded = $hintText.PadRight($innerWidth)
        $hintLine = '  {0}{1}{2}{3}{4}{5}' -f $palette.Surface, $border, $palette.Dim, $hintPadded, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset)
        [Console]::SetCursorPosition(0, $row)
        [Console]::Write($hintLine)
    }
    $row++

    # Bottom border
    if ($row -lt $bufferHeight) {
        $bottomGradient = Get-TBGradientLine -Character $hLine -Length $innerWidth -StartRGB $blueRGB -EndRGB $mauveRGB
        $bottomLine = '  {0}{1}{2}{3}{4}' -f $palette.Surface, ([char]0x2570), $bottomGradient, ([char]0x256F), $reset
        [Console]::SetCursorPosition(0, $row)
        [Console]::Write($bottomLine)
    }
    $row++

    # Move cursor below the box
    if ($row -lt $bufferHeight) {
        [Console]::SetCursorPosition(0, $row)
    }
}
