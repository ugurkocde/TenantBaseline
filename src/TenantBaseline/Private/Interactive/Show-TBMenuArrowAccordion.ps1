function Build-TBAccordionRows {
    <#
    .SYNOPSIS
        Builds a flat list of visible rows from accordion section definitions.
    .DESCRIPTION
        Computes the visible parent and child rows based on which section (if any)
        is currently expanded. Returns an array of hashtables with Type, Label,
        SectionIndex, ChildIndex, ChildCount, Expanded, and IsDirect fields.
    .PARAMETER Sections
        Array of section hashtables. Each must have Title (string), Children
        (string array), and IsDirect (bool).
    .PARAMETER ExpandedIndex
        The index of the currently expanded section, or -1 for none.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Sections,

        [Parameter()]
        [int]$ExpandedIndex = -1
    )

    $rows = [System.Collections.ArrayList]::new()

    for ($s = 0; $s -lt $Sections.Count; $s++) {
        $section = $Sections[$s]
        $isExpanded = ($s -eq $ExpandedIndex) -and ($section.Children.Count -gt 0)

        $null = $rows.Add(@{
            Type         = 'parent'
            SectionIndex = $s
            Label        = $section.Title
            ChildCount   = $section.Children.Count
            Expanded     = $isExpanded
            IsDirect     = $section.IsDirect
        })

        if ($isExpanded) {
            for ($c = 0; $c -lt $section.Children.Count; $c++) {
                $null = $rows.Add(@{
                    Type         = 'child'
                    SectionIndex = $s
                    ChildIndex   = $c
                    Label        = $section.Children[$c]
                })
            }
        }
    }

    return @(, $rows.ToArray())
}

function Show-TBMenuArrowAccordion {
    <#
    .SYNOPSIS
        Arrow-key accordion menu navigator for PS 7+ interactive terminals.
    .DESCRIPTION
        Renders an accordion-style menu where parent sections expand/collapse
        inline to reveal child actions. Only one section is expanded at a time.
        Returns a hashtable with Section and Item indices, or the string 'Quit'.
    .PARAMETER Sections
        Array of section hashtables. Each must have Title (string), Children
        (string array), and IsDirect (bool). IsDirect sections execute
        immediately on Enter without expanding children.
    .PARAMETER InitialExpanded
        Index of the section to start expanded, or -1 for none.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Sections,

        [Parameter()]
        [int]$InitialExpanded = -1
    )

    $palette = Get-TBColorPalette
    $esc = [char]27
    $reset = "${esc}[0m"

    # Print accordion title inside the box continuation
    $innerWidth = Get-TBConsoleInnerWidth
    $border = ([char]0x2502)
    $hLine = ([char]0x2500)

    $titleText = '  Main Menu'
    $titlePadded = $titleText.PadRight($innerWidth)
    Write-Host ('  {0}{1}{2}{3}{4}{5}{6}' -f $palette.Surface, $border, $palette.Teal, $palette.Bold, $titlePadded, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset))

    $titleUnderline = ('  ' + ([string]$hLine * 9)).PadRight($innerWidth)
    Write-Host ('  {0}{1}{2}{3}{4}{5}' -f $palette.Surface, $border, $palette.Dim, $titleUnderline, $reset, ('{0}{1}{2}' -f $palette.Surface, $border, $reset))

    # Record anchor position
    $anchorTop = [Console]::CursorTop

    $expandedIndex = $InitialExpanded
    $selectedIndex = 0
    $previousRowCount = 0

    # If we have an initial expanded section, position cursor on first child
    if ($expandedIndex -ge 0 -and $expandedIndex -lt $Sections.Count) {
        if ($Sections[$expandedIndex].Children.Count -gt 0) {
            # Count rows up to the expanded section's first child
            $offset = $expandedIndex + 1  # parent rows before + the expanded parent itself
            $selectedIndex = $offset
        }
        else {
            $selectedIndex = $expandedIndex
        }
    }

    $rows = Build-TBAccordionRows -Sections $Sections -ExpandedIndex $expandedIndex

    try {
        try { [Console]::CursorVisible = $false } catch { }

        # Initial render
        Render-TBAccordionBox -Rows $rows -SelectedIndex $selectedIndex -AnchorTop $anchorTop -PreviousRowCount $previousRowCount
        $previousRowCount = $rows.Count

        while ($true) {
            $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            $itemCount = $rows.Count

            switch ($key.VirtualKeyCode) {
                38 { # Up arrow
                    if ($selectedIndex -gt 0) {
                        $selectedIndex--
                    }
                    else {
                        $selectedIndex = $itemCount - 1
                    }
                    Render-TBAccordionBox -Rows $rows -SelectedIndex $selectedIndex -AnchorTop $anchorTop -PreviousRowCount $previousRowCount
                    $previousRowCount = $rows.Count
                }
                40 { # Down arrow
                    if ($selectedIndex -lt ($itemCount - 1)) {
                        $selectedIndex++
                    }
                    else {
                        $selectedIndex = 0
                    }
                    Render-TBAccordionBox -Rows $rows -SelectedIndex $selectedIndex -AnchorTop $anchorTop -PreviousRowCount $previousRowCount
                    $previousRowCount = $rows.Count
                }
                39 { # Right arrow - expand current section
                    $currentRow = $rows[$selectedIndex]
                    if ($currentRow.Type -eq 'parent' -and -not $currentRow.Expanded -and -not $currentRow.IsDirect -and $Sections[$currentRow.SectionIndex].Children.Count -gt 0) {
                        $expandedIndex = $currentRow.SectionIndex
                        $rows = Build-TBAccordionRows -Sections $Sections -ExpandedIndex $expandedIndex

                        # Move selection to first child
                        for ($f = 0; $f -lt $rows.Count; $f++) {
                            if ($rows[$f].Type -eq 'child' -and $rows[$f].SectionIndex -eq $expandedIndex) {
                                $selectedIndex = $f
                                break
                            }
                        }

                        Render-TBAccordionBox -Rows $rows -SelectedIndex $selectedIndex -AnchorTop $anchorTop -PreviousRowCount $previousRowCount
                        $previousRowCount = $rows.Count
                    }
                }
                37 { # Left arrow - collapse current expanded section
                    if ($expandedIndex -ge 0) {
                        $collapseTarget = $expandedIndex
                        $expandedIndex = -1
                        $rows = Build-TBAccordionRows -Sections $Sections -ExpandedIndex $expandedIndex

                        # Move selection to the collapsed parent
                        $selectedIndex = $collapseTarget
                        if ($selectedIndex -ge $rows.Count) {
                            $selectedIndex = $rows.Count - 1
                        }

                        Render-TBAccordionBox -Rows $rows -SelectedIndex $selectedIndex -AnchorTop $anchorTop -PreviousRowCount $previousRowCount
                        $previousRowCount = $rows.Count
                    }
                }
                13 { # Enter
                    $currentRow = $rows[$selectedIndex]

                    if ($currentRow.Type -eq 'child') {
                        # Return child selection
                        return @{
                            Section = $currentRow.SectionIndex
                            Item    = $currentRow.ChildIndex
                        }
                    }
                    elseif ($currentRow.IsDirect) {
                        # Direct-action parent (no children)
                        return @{
                            Section = $currentRow.SectionIndex
                            Item    = -1
                        }
                    }
                    else {
                        # Toggle expand/collapse on parent
                        if ($currentRow.Expanded) {
                            $expandedIndex = -1
                        }
                        else {
                            $expandedIndex = $currentRow.SectionIndex
                        }
                        $rows = Build-TBAccordionRows -Sections $Sections -ExpandedIndex $expandedIndex

                        # If expanding, move to first child; if collapsing, stay on parent
                        if ($expandedIndex -ge 0 -and $Sections[$expandedIndex].Children.Count -gt 0) {
                            for ($f = 0; $f -lt $rows.Count; $f++) {
                                if ($rows[$f].Type -eq 'child' -and $rows[$f].SectionIndex -eq $expandedIndex) {
                                    $selectedIndex = $f
                                    break
                                }
                            }
                        }
                        else {
                            # Find the parent row for the collapsed section
                            for ($f = 0; $f -lt $rows.Count; $f++) {
                                if ($rows[$f].Type -eq 'parent' -and $rows[$f].SectionIndex -eq $currentRow.SectionIndex) {
                                    $selectedIndex = $f
                                    break
                                }
                            }
                        }

                        Render-TBAccordionBox -Rows $rows -SelectedIndex $selectedIndex -AnchorTop $anchorTop -PreviousRowCount $previousRowCount
                        $previousRowCount = $rows.Count
                    }
                }
                27 { # Escape
                    return 'Quit'
                }
            }
        }
    }
    finally {
        try { [Console]::CursorVisible = $true } catch { }
    }
}
