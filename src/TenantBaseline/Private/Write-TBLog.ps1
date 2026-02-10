function Write-TBLog {
    <#
    .SYNOPSIS
        Writes a log message to the verbose stream and optionally to a file.
    .DESCRIPTION
        Central logging function for the TenantBaseline module. Writes messages
        to the verbose stream and optionally appends to a log file if the
        TBLogPath environment variable is set.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Verbose', 'Warning', 'Error', 'Information')]
        [string]$Level = 'Verbose'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $formatted = '[{0}] [{1}] {2}' -f $timestamp, $Level, $Message

    switch ($Level) {
        'Verbose'     { Write-Verbose -Message $formatted }
        'Warning'     { Write-Warning -Message $formatted }
        'Error'       { Write-Error -Message $formatted }
        'Information' { Write-Verbose -Message $formatted }
    }

    $logPath = $env:TBLogPath
    if ($logPath) {
        try {
            $formatted | Out-File -FilePath $logPath -Append -Encoding utf8
        }
        catch {
            Write-Verbose -Message ("Failed to write to log file: {0}" -f $_)
        }
    }
}
