function Read-TBUserInput {
    <#
    .SYNOPSIS
        Prompts the user for validated text input.
    .DESCRIPTION
        Reads user input with optional validation including minimum/maximum length,
        regex pattern matching, and Y/N confirmation mode.
    .PARAMETER Prompt
        The prompt message to display.
    .PARAMETER Mandatory
        If specified, empty input is rejected.
    .PARAMETER MinLength
        Minimum allowed input length.
    .PARAMETER MaxLength
        Maximum allowed input length.
    .PARAMETER Pattern
        Regex pattern the input must match.
    .PARAMETER PatternMessage
        Error message shown when pattern validation fails.
    .PARAMETER Confirm
        If specified, operates in Y/N confirmation mode. Returns $true or $false.
    .PARAMETER Default
        Default value if user presses Enter without typing.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [Parameter()]
        [switch]$Mandatory,

        [Parameter()]
        [int]$MinLength = 0,

        [Parameter()]
        [int]$MaxLength = 0,

        [Parameter()]
        [string]$Pattern,

        [Parameter()]
        [string]$PatternMessage,

        [Parameter()]
        [switch]$Confirm,

        [Parameter()]
        [string]$Default
    )

    if ($Confirm) {
        while ($true) {
            $suffix = ' (Y/N)'
            if ($Default) {
                $suffix = ' (Y/N) [{0}]' -f $Default
            }

            $input_value = Read-Host -Prompt ('  {0}{1}' -f $Prompt, $suffix)
            $input_value = $input_value.Trim()

            if (-not $input_value -and $Default) {
                $input_value = $Default
            }

            if ($input_value -eq 'Y' -or $input_value -eq 'y') {
                return $true
            }
            if ($input_value -eq 'N' -or $input_value -eq 'n') {
                return $false
            }

            Write-Host '  Please enter Y or N.' -ForegroundColor Red
        }
    }

    while ($true) {
        $suffix = ''
        if ($Default) {
            $suffix = ' [{0}]' -f $Default
        }

        $input_value = Read-Host -Prompt ('  {0}{1}' -f $Prompt, $suffix)
        $input_value = $input_value.Trim()

        if (-not $input_value -and $Default) {
            $input_value = $Default
        }

        if ($Mandatory -and -not $input_value) {
            Write-Host '  This field is required.' -ForegroundColor Red
            continue
        }

        if (-not $Mandatory -and -not $input_value) {
            return $input_value
        }

        if ($MinLength -gt 0 -and $input_value.Length -lt $MinLength) {
            Write-Host ('  Input must be at least {0} characters.' -f $MinLength) -ForegroundColor Red
            continue
        }

        if ($MaxLength -gt 0 -and $input_value.Length -gt $MaxLength) {
            Write-Host ('  Input must be at most {0} characters.' -f $MaxLength) -ForegroundColor Red
            continue
        }

        if ($Pattern -and -not ($input_value -match $Pattern)) {
            if ($PatternMessage) {
                Write-Host ('  {0}' -f $PatternMessage) -ForegroundColor Red
            }
            else {
                Write-Host '  Input does not match the required format.' -ForegroundColor Red
            }
            continue
        }

        return $input_value
    }
}
