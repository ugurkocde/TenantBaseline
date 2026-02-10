function Render-TBAccordionBox {
    <#
    .SYNOPSIS
        Renders accordion menu items inside a rounded-corner box with in-place redraw.
    .DESCRIPTION
        Draws parent (section) and child (action) rows inside a Unicode box using
        Console.SetCursorPosition for flicker-free updates. Expanded parents show
        their children inline. Supports a single expanded section at a time.

        Visual indicators:
        - Collapsed parent: right-pointing triangle with child count
        - Expanded parent: down-pointing triangle in Teal
        - IsDirect parent: right arrow (no expand/collapse)
        - Child item: angle bracket indicator
    .PARAMETER Rows
        Array of row hashtables from Build-TBAccordionRows. Each row has Type
        (parent/child), Label, and metadata fields including ChildCount for parents.
    .PARAMETER SelectedIndex
        The currently highlighted row index in the flat list.
    .PARAMETER AnchorTop
        The console row to start rendering from.
    .PARAMETER PreviousRowCount
        The number of rows rendered in the previous frame. Used to blank excess
        rows when collapsing a section.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Rows,

        [Parameter(Mandatory = $true)]
        [int]$SelectedIndex,

        [Parameter(Mandatory = $true)]
        [int]$AnchorTop,

        [Parameter()]
        [int]$PreviousRowCount = 0
    )

    $palette = Get-TBColorPalette
    $esc = [char]27
    $reset = "${esc}[0m"

    $innerWidth = Get-TBConsoleInnerWidth
    $border = ([char]0x2502)
    $hLine = ([char]0x2500)

    $blueRGB  = @(137, 180, 250)
    $mauveRGB = @(203, 166, 247)

    $collapsedChar = [char]0x25B8  # right-pointing triangle
    $expandedChar  = [char]0x25BE  # down-pointing triangle
    $directChar    = [char]0x2192  # right arrow for IsDirect sections
    $childChar     = [char]0x203A  # single right-pointing angle quotation mark
    $fitText = {
        param([string]$Text)
        if ($null -eq $Text) { return '' }
        if ($Text.Length -le $innerWidth) { return $Text }
        if ($innerWidth -le 3) { return $Text.Substring(0, $innerWidth) }
        return $Text.Substring(0, $innerWidth - 3) + '...'
    }

    $row = $AnchorTop

    # Empty line inside box
    $emptyLine = '  {0}{1}{2}{3}{4}' -f $palette.Surface, $border, (' ' * $innerWidth), $border, $reset
    [Console]::SetCursorPosition(0, $row)
    [Console]::Write($emptyLine)
    $row++

    # Render each row
    for ($i = 0; $i -lt $Rows.Count; $i++) {
        [Console]::SetCursorPosition(0, $row)

        $currentRow = $Rows[$i]
        $isHighlighted = ($i -eq $SelectedIndex)

        if ($currentRow.Type -eq 'parent') {
            $sectionNum = $currentRow.SectionIndex + 1

            if ($currentRow.IsDirect) {
                $indicator = $directChar
            }
            elseif ($currentRow.Expanded) {
                $indicator = $expandedChar
            }
            else {
                $indicator = $collapsedChar
            }

            # Build label with child count for collapsed expandable sections
            $displayLabel = $currentRow.Label
            if (-not $currentRow.IsDirect -and -not $currentRow.Expanded -and $currentRow.ChildCount -gt 0) {
                $displayLabel = '{0} ({1})' -f $currentRow.Label, $currentRow.ChildCount
            }

            if ($isHighlighted) {
                $chevron = [char]0x276F
                $itemText = ('  {0} {1}  {2} {3}' -f $chevron, $sectionNum, $indicator, $displayLabel)
                $padded = (& $fitText $itemText).PadRight($innerWidth)
                $line = '  {0}{1}{2}{3}{4}{5}{6}{7}' -f $palette.Surface, $border, $palette.BgSelect, $palette.Mauve, $palette.Bold, $padded, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset)
            }
            elseif ($currentRow.Expanded) {
                $itemText = ('     {0}  {1} {2}' -f $sectionNum, $indicator, $displayLabel)
                $padded = (& $fitText $itemText).PadRight($innerWidth)
                $line = '  {0}{1}{2}{3}{4}{5}' -f $palette.Surface, $border, $palette.Teal, $padded, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset)
            }
            elseif ($currentRow.IsDirect) {
                $itemText = ('     {0}  {1} {2}' -f $sectionNum, $indicator, $displayLabel)
                $padded = (& $fitText $itemText).PadRight($innerWidth)
                $line = '  {0}{1}{2}{3}{4}{5}' -f $palette.Surface, $border, $palette.Peach, $padded, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset)
            }
            else {
                $itemText = ('     {0}  {1} {2}' -f $sectionNum, $indicator, $displayLabel)
                $padded = (& $fitText $itemText).PadRight($innerWidth)
                $line = '  {0}{1}{2}{3}{4}{5}' -f $palette.Surface, $border, $palette.Text, $padded, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset)
            }
        }
        else {
            # Child row
            $childNum = '{0}.{1}' -f ($currentRow.SectionIndex + 1), ($currentRow.ChildIndex + 1)

            if ($isHighlighted) {
                $chevron = [char]0x276F
                $itemText = ('    {0} {1}  {2} {3}' -f $chevron, $childNum, $childChar, $currentRow.Label)
                $padded = (& $fitText $itemText).PadRight($innerWidth)
                $line = '  {0}{1}{2}{3}{4}{5}{6}{7}' -f $palette.Surface, $border, $palette.BgSelect, $palette.Mauve, $palette.Bold, $padded, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset)
            }
            else {
                $itemText = ('       {0}  {1} {2}' -f $childNum, $childChar, $currentRow.Label)
                $padded = (& $fitText $itemText).PadRight($innerWidth)
                $line = '  {0}{1}{2}{3}{4}{5}' -f $palette.Surface, $border, $palette.Subtext, $padded, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset)
            }
        }

        [Console]::Write($line)
        $row++
    }

    # Blank any excess rows from previous render (when collapsing)
    $currentRowCount = $Rows.Count
    if ($PreviousRowCount -gt $currentRowCount) {
        $blankCount = $PreviousRowCount - $currentRowCount
        for ($b = 0; $b -lt $blankCount; $b++) {
            [Console]::SetCursorPosition(0, $row)
            [Console]::Write($emptyLine)
            $row++
        }
    }

    # Empty line
    [Console]::SetCursorPosition(0, $row)
    [Console]::Write($emptyLine)
    $row++

    # Separator line
    $sepGradient = Get-TBGradientLine -Character $hLine -Length $innerWidth -StartRGB $blueRGB -EndRGB $mauveRGB
    $sepLine = '  {0}{1}{2}{3}{4}' -f $palette.Surface, ([char]0x251C), $sepGradient, ([char]0x2524), $reset
    [Console]::SetCursorPosition(0, $row)
    [Console]::Write($sepLine)
    $row++

    # Hint line
    $hintText = '  Arrows | Right/Left: expand | Enter | Esc'
    $hintPadded = (& $fitText $hintText).PadRight($innerWidth)
    $hintLine = '  {0}{1}{2}{3}{4}{5}' -f $palette.Surface, $border, $palette.Dim, $hintPadded, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset)
    [Console]::SetCursorPosition(0, $row)
    [Console]::Write($hintLine)
    $row++

    # Bottom border
    $bottomGradient = Get-TBGradientLine -Character $hLine -Length $innerWidth -StartRGB $blueRGB -EndRGB $mauveRGB
    $bottomLine = '  {0}{1}{2}{3}{4}' -f $palette.Surface, ([char]0x2570), $bottomGradient, ([char]0x256F), $reset
    [Console]::SetCursorPosition(0, $row)
    [Console]::Write($bottomLine)
    $row++

    # Clear one trailing line below the box to avoid stale footer artifacts
    # when terminals repaint or wrap unexpectedly during rapid redraws.
    try {
        if ($row -lt [Console]::BufferHeight) {
            $windowWidth = [Console]::WindowWidth
            if ($windowWidth -gt 1) {
                [Console]::SetCursorPosition(0, $row)
                [Console]::Write(' ' * ($windowWidth - 1))
            }
        }
    }
    catch {
        # Best-effort visual cleanup only.
    }

    # Move cursor below the box
    [Console]::SetCursorPosition(0, $row)
}
