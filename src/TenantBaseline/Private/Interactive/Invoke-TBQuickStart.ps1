function Invoke-TBQuickStart {
    <#
    .SYNOPSIS
        Runs the first-run quick start flow after successful sign-in.
    #>
    [CmdletBinding()]
    param()

    Write-Host ''
    Write-Host '  Starting quick start...' -ForegroundColor Cyan

    try {
        Write-Host '  Step 1/2: Running setup check' -ForegroundColor Yellow
        Show-TBSetupMenu -DirectAction 1

        Write-Host ''
        Write-Host '  Step 2/2: Create your first monitor' -ForegroundColor Yellow
        Show-TBMonitorMenu -DirectAction 0
    }
    catch {
        Write-Host ('  Quick start failed: {0}' -f $_.Exception.Message) -ForegroundColor Red
    }
}
