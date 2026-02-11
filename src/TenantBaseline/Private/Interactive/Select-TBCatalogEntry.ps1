function Show-TBCatalogDetailView {
    <#
    .SYNOPSIS
        Renders a full-screen detail view for a single catalog category.
    .DESCRIPTION
        Displays category metadata, description, and all security checks with
        their recommended values. In arrow-key mode, uses ReadKey for Enter/Esc
        navigation. In classic mode, uses a Y/N confirmation prompt.
    .PARAMETER Category
        The catalog category object to display.
    .OUTPUTS
        [bool] $true if the user confirms, $false to go back.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Category
    )

    $tests = @($Category.Tests)
    $separator = '  ' + ('-' * 54)

    Write-Host ''
    Write-Host ('  {0}' -f $Category.Name) -ForegroundColor Cyan
    Write-Host ('  {0} | {1}' -f $Category.Framework, $Category.Severity) -ForegroundColor DarkGray
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ''
    Write-Host ('  {0}' -f $Category.Description) -ForegroundColor White
    Write-Host ''
    Write-Host ('  Security Checks ({0}):' -f $tests.Count) -ForegroundColor Cyan
    Write-Host ''

    foreach ($test in $tests) {
        $valueStr = $test.RecommendedValue
        if ($valueStr.Length -gt 30) {
            $valueStr = $valueStr.Substring(0, 27) + '...'
        }
        Write-Host ('    {0} = {1}' -f $test.Property, $valueStr) -ForegroundColor White
        Write-Host ('      {0}' -f $test.Description) -ForegroundColor DarkGray
    }

    Write-Host ''
    Write-Host $separator -ForegroundColor DarkGray

    if (Test-TBArrowKeySupport) {
        Write-Host ''
        Write-Host '  Press Enter to use this category, Esc to go back' -ForegroundColor DarkGray

        while ($true) {
            $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            if ($key.VirtualKeyCode -eq 13) { return $true }   # Enter
            if ($key.VirtualKeyCode -eq 27) { return $false }  # Escape
        }
    }
    else {
        $confirmed = Read-TBUserInput -Prompt 'Use this category?' -Confirm
        return $confirmed
    }
}

function Select-TBCatalogEntry {
    <#
    .SYNOPSIS
        Interactive two-level selection from the Maester baseline security catalog.
    .DESCRIPTION
        Groups catalog categories by Workload, lets the user pick a workload,
        then single-select a category with a detail view before confirming.
        Returns unique UTCM resource type name strings for the confirmed category.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    $catalog = Get-TBBaselineCatalog
    $categories = @($catalog.Categories)

    # Group categories by Workload
    $workloads = [ordered]@{}
    foreach ($cat in $categories) {
        $wl = $cat.Workload
        if (-not $workloads.Contains($wl)) {
            $workloads[$wl] = @()
        }
        $workloads[$wl] += $cat
    }

    # Step 1: Show workload selection
    $workloadNames = @($workloads.Keys)
    $workloadOptions = foreach ($wl in $workloadNames) {
        $count = @($workloads[$wl]).Count
        '{0} ({1} monitors)' -f $wl, $count
    }

    $wlChoice = Show-TBMenu -Title 'Security Catalog - Select Workload' -Options $workloadOptions -IncludeBack

    if ($wlChoice -eq 'Back') {
        return $null
    }

    $selectedWorkload = $workloadNames[$wlChoice]
    $workloadCategories = @($workloads[$selectedWorkload])

    # Step 2: Category browsing loop (single-select with detail view)
    $categoryOptions = foreach ($cat in $workloadCategories) {
        $testCount = @($cat.Tests).Count
        '{0} [{1}] -- {2} checks' -f $cat.Name, $cat.Severity, $testCount
    }

    $arrowMode = Test-TBArrowKeySupport

    while ($true) {
        if ($arrowMode) {
            Clear-Host
            Write-Host ''
            Write-Host '  -- Create from Maester --' -ForegroundColor Cyan
            Write-Host ''
        }

        $catChoice = Show-TBMenu -Title ('{0} - Select Category' -f $selectedWorkload) -Options $categoryOptions -IncludeBack

        if ($catChoice -eq 'Back') {
            return $null
        }

        $selectedCategory = $workloadCategories[$catChoice]

        if ($arrowMode) {
            Clear-Host
            Write-Host ''
            Write-Host '  -- Create from Maester --' -ForegroundColor Cyan
        }

        $confirmed = Show-TBCatalogDetailView -Category $selectedCategory

        if ($confirmed) {
            $allTypes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($rt in $selectedCategory.ResourceTypes) {
                $null = $allTypes.Add($rt)
            }

            if ($allTypes.Count -eq 0) {
                return $null
            }

            $testCount = @($selectedCategory.Tests).Count
            Write-Host ''
            Write-Host ('  Selected "{0}" covering {1} resource type(s) and {2} security check(s):' -f $selectedCategory.Name, $allTypes.Count, $testCount) -ForegroundColor Green
            foreach ($typeName in $allTypes) {
                Write-Host ('    - {0}' -f $typeName) -ForegroundColor White
            }
            Write-Host ''

            return @($allTypes)
        }
        # If not confirmed, loop back to category menu
    }
}
