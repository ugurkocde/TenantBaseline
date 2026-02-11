function Show-TBMenuArrowMultiSelect {
    <#
    .SYNOPSIS
        Arrow-key multi-select menu for PS 7+ interactive terminals.
    .DESCRIPTION
        Renders menu items with checkboxes inside a box. Arrow keys move the
        highlight, Space toggles selection, A toggles all, Enter confirms the
        checked items, and Escape returns Back. Supports viewport scrolling
        for lists that exceed the available terminal height.
    .PARAMETER Title
        The menu title displayed above the items.
    .PARAMETER Options
        Array of option display strings.
    .PARAMETER IncludeBack
        If specified, Escape returns 'Back'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string[]]$Options,

        [Parameter()]
        [switch]$IncludeBack
    )

    $palette = Get-TBColorPalette
    $esc = [char]27
    $reset = "${esc}[0m"

    $innerWidth = Get-TBConsoleInnerWidth
    $border = ([char]0x2502)

    # Title inside box continuation
    $titlePadded = ('  {0}' -f $Title).PadRight($innerWidth)
    Write-Host ('  {0}{1}{2}{3}{4}{5}{6}' -f $palette.Surface, $border, $palette.Teal, $palette.Bold, $titlePadded, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset))

    $titleUnderline = ('  {0}' -f ('-' * $Title.Length)).PadRight($innerWidth)
    Write-Host ('  {0}{1}{2}{3}{4}{5}' -f $palette.Surface, $border, $palette.Dim, $titleUnderline, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset))

    $anchorTop = [Console]::CursorTop

    $selectedIndex = 0
    $itemCount = $Options.Count
    $checked = [bool[]]::new($itemCount)

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
            -Checked $checked -IncludeBack:$IncludeBack -MultiSelect `
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
                        -Checked $checked -IncludeBack:$IncludeBack -MultiSelect `
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
                        -Checked $checked -IncludeBack:$IncludeBack -MultiSelect `
                        -ViewportOffset $viewportOffset -ViewportSize $viewportSize
                }
                32 { # Space - toggle checkbox
                    $checked[$selectedIndex] = -not $checked[$selectedIndex]
                    Render-TBMenuBox -Items $Options -SelectedIndex $selectedIndex -AnchorTop $anchorTop `
                        -Checked $checked -IncludeBack:$IncludeBack -MultiSelect `
                        -ViewportOffset $viewportOffset -ViewportSize $viewportSize
                }
                13 { # Enter - confirm
                    $result = @()
                    for ($i = 0; $i -lt $itemCount; $i++) {
                        if ($checked[$i]) {
                            $result += $i
                        }
                    }
                    if ($result.Count -gt 0) {
                        return $result
                    }
                    # If nothing checked, do nothing (require at least one selection)
                }
                27 { # Escape
                    if ($IncludeBack) { return 'Back' }
                }
                65 { # A key - toggle all
                    $allChecked = $true
                    for ($i = 0; $i -lt $itemCount; $i++) {
                        if (-not $checked[$i]) {
                            $allChecked = $false
                            break
                        }
                    }
                    $newState = -not $allChecked
                    for ($i = 0; $i -lt $itemCount; $i++) {
                        $checked[$i] = $newState
                    }
                    Render-TBMenuBox -Items $Options -SelectedIndex $selectedIndex -AnchorTop $anchorTop `
                        -Checked $checked -IncludeBack:$IncludeBack -MultiSelect `
                        -ViewportOffset $viewportOffset -ViewportSize $viewportSize
                }
            }
        }
    }
    finally {
        try { [Console]::CursorVisible = $true } catch { }
    }
}
