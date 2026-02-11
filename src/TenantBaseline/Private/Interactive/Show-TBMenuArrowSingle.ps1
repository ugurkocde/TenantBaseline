function Show-TBMenuArrowSingle {
    <#
    .SYNOPSIS
        Arrow-key single-select menu for PS 7+ interactive terminals.
    .DESCRIPTION
        Renders a title area and menu items inside a box, then enters a key
        loop where Up/Down moves the highlight, Enter selects the item, and
        Escape returns Back or Quit. Hides the cursor during navigation.
        Supports viewport scrolling for lists that exceed the available
        terminal height.
    .PARAMETER Title
        The menu title displayed above the items.
    .PARAMETER Options
        Array of option display strings.
    .PARAMETER IncludeBack
        If specified, Escape returns 'Back'.
    .PARAMETER IncludeQuit
        If specified, Escape returns 'Quit'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string[]]$Options,

        [Parameter()]
        [switch]$IncludeBack,

        [Parameter()]
        [switch]$IncludeQuit
    )

    $palette = Get-TBColorPalette
    $esc = [char]27
    $reset = "${esc}[0m"

    # Print the title inside the box continuation
    $innerWidth = Get-TBConsoleInnerWidth
    $border = ([char]0x2502)

    $titlePadded = ('  {0}' -f $Title).PadRight($innerWidth)
    Write-Host ('  {0}{1}{2}{3}{4}{5}{6}' -f $palette.Surface, $border, $palette.Teal, $palette.Bold, $titlePadded, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset))

    $titleUnderline = ('  {0}' -f ('-' * $Title.Length)).PadRight($innerWidth)
    Write-Host ('  {0}{1}{2}{3}{4}{5}' -f $palette.Surface, $border, $palette.Dim, $titleUnderline, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset))

    # Record anchor position for the item rendering area
    $anchorTop = [Console]::CursorTop

    $selectedIndex = 0
    $itemCount = $Options.Count

    # Viewport: chrome rows = top-empty + bottom-empty + separator + hint + bottom-border
    $chromeRows = 5
    $maxVisible = [Math]::Max(3, [Console]::WindowHeight - $anchorTop - $chromeRows)
    $viewportSize = if ($itemCount -gt $maxVisible) { $maxVisible } else { 0 }
    $viewportOffset = 0

    $adjustViewport = {
        if ($viewportSize -le 0) { return }
        $hasAbove = ($viewportOffset -gt 0)
        $hasBelow = (($viewportOffset + $viewportSize) -lt $itemCount)
        $visibleFirst = $viewportOffset + $(if ($hasAbove) { 1 } else { 0 })
        $visibleLast  = $viewportOffset + $viewportSize - 1 - $(if ($hasBelow) { 1 } else { 0 })
        $newOffset = $viewportOffset
        if ($selectedIndex -lt $visibleFirst) {
            $newOffset = [Math]::Max(0, $selectedIndex - 1)
            if ($selectedIndex -eq 0) { $newOffset = 0 }
        }
        elseif ($selectedIndex -gt $visibleLast) {
            $newOffset = [Math]::Min($itemCount - $viewportSize, $selectedIndex - $viewportSize + 2)
            if ($selectedIndex -eq ($itemCount - 1)) { $newOffset = $itemCount - $viewportSize }
        }
        Set-Variable -Name viewportOffset -Value $newOffset -Scope 1
    }

    try {
        try { [Console]::CursorVisible = $false } catch { }

        # Initial render
        & $adjustViewport
        Render-TBMenuBox -Items $Options -SelectedIndex $selectedIndex -AnchorTop $anchorTop `
            -IncludeBack:$IncludeBack -IncludeQuit:$IncludeQuit `
            -ViewportOffset $viewportOffset -ViewportSize $viewportSize

        while ($true) {
            $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

            switch ($key.VirtualKeyCode) {
                38 { # Up arrow
                    if ($selectedIndex -gt 0) {
                        $selectedIndex--
                    }
                    else {
                        $selectedIndex = $itemCount - 1
                    }
                    & $adjustViewport
                    Render-TBMenuBox -Items $Options -SelectedIndex $selectedIndex -AnchorTop $anchorTop `
                        -IncludeBack:$IncludeBack -IncludeQuit:$IncludeQuit `
                        -ViewportOffset $viewportOffset -ViewportSize $viewportSize
                }
                40 { # Down arrow
                    if ($selectedIndex -lt ($itemCount - 1)) {
                        $selectedIndex++
                    }
                    else {
                        $selectedIndex = 0
                    }
                    & $adjustViewport
                    Render-TBMenuBox -Items $Options -SelectedIndex $selectedIndex -AnchorTop $anchorTop `
                        -IncludeBack:$IncludeBack -IncludeQuit:$IncludeQuit `
                        -ViewportOffset $viewportOffset -ViewportSize $viewportSize
                }
                13 { # Enter
                    return $selectedIndex
                }
                27 { # Escape
                    if ($IncludeBack) { return 'Back' }
                    if ($IncludeQuit) { return 'Quit' }
                }
            }
        }
    }
    finally {
        try { [Console]::CursorVisible = $true } catch { }
    }
}
