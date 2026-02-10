function Show-TBMenu {
    <#
    .SYNOPSIS
        Renders a numbered menu and reads the user selection.
    .DESCRIPTION
        Displays a list of options with numbered indices, reads user input,
        validates the selection, and returns the chosen index or special value.
        Supports single-select and multi-select modes.

        On PS 7+ with an interactive console, uses arrow-key navigation with
        premium box rendering. On non-interactive hosts, falls back
        to the classic Read-Host numbered input.
    .PARAMETER Title
        The menu title displayed above the options.
    .PARAMETER Options
        Array of option display strings.
    .PARAMETER MultiSelect
        If specified, allows comma-separated multi-select (e.g., "1,3,5") and an "A" option for all.
    .PARAMETER IncludeBack
        If specified, adds a "0. Back" option.
    .PARAMETER IncludeQuit
        If specified, adds a "Q. Quit" option.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string[]]$Options,

        [Parameter()]
        [switch]$MultiSelect,

        [Parameter()]
        [switch]$IncludeBack,

        [Parameter()]
        [switch]$IncludeQuit
    )

    if (Test-TBArrowKeySupport) {
        if ($MultiSelect) {
            return Show-TBMenuArrowMultiSelect -Title $Title -Options $Options -IncludeBack:$IncludeBack
        }
        else {
            return Show-TBMenuArrowSingle -Title $Title -Options $Options -IncludeBack:$IncludeBack -IncludeQuit:$IncludeQuit
        }
    }

    # Classic Read-Host fallback for non-interactive hosts
    while ($true) {
        Write-Host ''
        Write-Host ('  {0}' -f $Title) -ForegroundColor Cyan
        Write-Host ('  {0}' -f ('-' * $Title.Length)) -ForegroundColor DarkCyan
        Write-Host ''

        for ($i = 0; $i -lt $Options.Count; $i++) {
            $num = $i + 1
            Write-Host ('    {0}. {1}' -f $num, $Options[$i]) -ForegroundColor White
        }

        Write-Host ''

        if ($MultiSelect) {
            Write-Host '    A. Select all' -ForegroundColor DarkYellow
        }

        if ($IncludeBack) {
            Write-Host '    0. Back' -ForegroundColor DarkGray
        }

        if ($IncludeQuit) {
            Write-Host '    Q. Quit' -ForegroundColor DarkGray
        }

        Write-Host ''
        $prompt = 'Select an option'
        if ($MultiSelect) {
            $prompt = 'Select option(s) (comma-separated, or A for all)'
        }

        $input_value = Read-Host -Prompt ('  {0}' -f $prompt)
        $input_value = $input_value.Trim()

        if ($IncludeQuit -and ($input_value -eq 'Q' -or $input_value -eq 'q')) {
            return 'Quit'
        }

        if ($IncludeBack -and $input_value -eq '0') {
            return 'Back'
        }

        if ($MultiSelect -and ($input_value -eq 'A' -or $input_value -eq 'a')) {
            $allIndices = @()
            for ($i = 0; $i -lt $Options.Count; $i++) {
                $allIndices += $i
            }
            return $allIndices
        }

        if ($MultiSelect) {
            $parts = $input_value -split ',' | ForEach-Object { $_.Trim() }
            $valid = $true
            $seen = @{}
            $selectedIndices = @()

            foreach ($part in $parts) {
                $num = 0
                if ([int]::TryParse($part, [ref]$num)) {
                    if ($num -ge 1 -and $num -le $Options.Count) {
                        $idx = $num - 1
                        if (-not $seen.ContainsKey($idx)) {
                            $seen[$idx] = $true
                            $selectedIndices += $idx
                        }
                    }
                    else {
                        $valid = $false
                        break
                    }
                }
                else {
                    $valid = $false
                    break
                }
            }

            if ($valid -and $selectedIndices.Count -gt 0) {
                return $selectedIndices
            }
        }
        else {
            $num = 0
            if ([int]::TryParse($input_value, [ref]$num)) {
                if ($num -ge 1 -and $num -le $Options.Count) {
                    return ($num - 1)
                }
            }
        }

        Write-Host '  Invalid selection. Please try again.' -ForegroundColor Red
    }
}
