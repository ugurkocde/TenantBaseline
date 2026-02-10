function Get-TBHeaderModel {
    <#
    .SYNOPSIS
        Builds the interactive header content model from module metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$Subtitle
    )

    if (-not $script:TBHeaderModelCache) {
        $moduleVersion = '0.0.0'

        try {
            $manifestPath = Join-Path -Path $script:TBModuleRoot -ChildPath 'TenantBaseline.psd1'
            if (Test-Path -Path $manifestPath -PathType Leaf) {
                $manifest = Import-PowerShellDataFile -Path $manifestPath
                if ($manifest.ModuleVersion) {
                    $moduleVersion = [string]$manifest.ModuleVersion
                }
            }
        }
        catch {
            # Keep default metadata values when manifest cannot be read.
        }

        $script:TBHeaderModelCache = [PSCustomObject]@{
            Title             = 'TenantBaseline'
            DefaultSubtitle   = 'Unified Tenand Configuration Management'
            VersionText       = ('Version: v{0}' -f $moduleVersion)
            AuthorText        = 'Author: Ugur'
            WebsiteText       = 'Website: tenantbaseline.com'
            LinkedInText      = 'LinkedIn: linkedin.com/in/ugurkocde'
            RepositoryText    = 'Repository: github.com/ugurkocde/tenantbaseline'
            UTCMText          = 'UTCM: Microsoft Graph Unified Tenant Configuration Management For Cross-Workload Policy Governance.'
            BackendText       = 'Backend: Uses The Microsoft First-Party UTCM App (App ID: 03b07b79-c5bc-4b5e-9bfa-13acf4a99998).'
            UseCasesText      = 'Use Cases: Tenant Configuration Monitoring, Drift Detection, Snapshot Auditing.'
            FeaturesText      = 'Features: Baseline Management, Monitor Workflows, Reports/Dashboard/Documentation, UTCM Setup Planning.'
            LinksLine         = 'tenantbaseline.com  |  github.com/ugurkocde/tenantbaseline'
            UTCMShort         = 'UTCM: Unified Tenant Configuration Management (Microsoft Graph)'
            CapabilitiesLine  = 'Monitoring, Drift Detection, Snapshots, Baselines, Reports'
        }
    }

    $resolvedSubtitle = if ($Subtitle) { $Subtitle } else { $script:TBHeaderModelCache.DefaultSubtitle }
    return [PSCustomObject]@{
        Title            = $script:TBHeaderModelCache.Title
        Subtitle         = $resolvedSubtitle
        VersionText      = $script:TBHeaderModelCache.VersionText
        AuthorText       = $script:TBHeaderModelCache.AuthorText
        WebsiteText      = $script:TBHeaderModelCache.WebsiteText
        LinkedInText     = $script:TBHeaderModelCache.LinkedInText
        RepositoryText   = $script:TBHeaderModelCache.RepositoryText
        UTCMText         = $script:TBHeaderModelCache.UTCMText
        BackendText      = $script:TBHeaderModelCache.BackendText
        UseCasesText     = $script:TBHeaderModelCache.UseCasesText
        FeaturesText     = $script:TBHeaderModelCache.FeaturesText
        MetaLine         = ('{0}  |  {1}' -f $script:TBHeaderModelCache.VersionText, $script:TBHeaderModelCache.AuthorText)
        LinksLine        = $script:TBHeaderModelCache.LinksLine
        UTCMShort        = $script:TBHeaderModelCache.UTCMShort
        CapabilitiesLine = $script:TBHeaderModelCache.CapabilitiesLine
    }
}

function Get-TBHeroLines {
    <#
    .SYNOPSIS
        Provides consistent hero content for premium and classic headers.
    .PARAMETER Premium
        When set, returns bold block-letter art for PS 7+ terminals.
        Otherwise returns clean ASCII art safe for all hosts.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$HeaderModel,

        [Parameter()]
        [switch]$Premium
    )

    # Unicode box-drawing and block character aliases
    $B  = [string][char]0x2588  # Full block
    $TR = [string][char]0x2557  # Top-right double corner
    $TL = [string][char]0x2554  # Top-left double corner
    $BR = [string][char]0x255D  # Bottom-right double corner
    $BL = [string][char]0x255A  # Bottom-left double corner
    $H  = [string][char]0x2550  # Horizontal double line
    $V  = [string][char]0x2551  # Vertical double line

    if ($Premium) {
        # Big T at pos 1-9, big B at pos 22-29.
        $bGapWidth = 2
        $bGap = ' ' * $bGapWidth      # between T end and B start
        $sGap = ' ' * ($bGapWidth + 3) # stem is 3 chars narrower than top bar
        $artLines = @(
            ($B*8 + $TR + $bGap + $B*6 + $TR)
            ($BL + $H*2 + $B*2 + $TL + $H*2 + $BR + $bGap + $B*2 + $TL + $H*2 + $B*2 + $TR)
            ('   ' + $B*2 + $V + $sGap + $B*6 + $TL + $BR)
            ('   ' + $B*2 + $V + $sGap + $B*2 + $TL + $H*2 + $B*2 + $TR)
            ('   ' + $B*2 + $V + $sGap + $B*6 + $TL + $BR)
            ('   ' + $BL + $H + $BR + $sGap + $BL + $H*5 + $BR)
        )
        $subtitleLine = $HeaderModel.Subtitle
    }
    else {
        # Figlet-inspired T/B mark for plain terminals.
        # ASCII safe for all terminals (6 lines).
        $artLines = @(
            ' _______    ____         '
            '|__   __|   |  _ \        '
            '   | |      | |_) |       '
            '   | |      |  _ <        '
            '   | |      | |_) |       '
            '   |_|      |____/        '
        )
        $subtitleLine = $HeaderModel.Subtitle
    }

    return [PSCustomObject]@{
        ArtLines     = $artLines
        SubtitleLine = $subtitleLine
    }
}

function Write-TBMenuHeader {
    <#
    .SYNOPSIS
        Displays the TenantBaseline interactive console banner.
    .DESCRIPTION
        Renders a premium box-drawn header with gradient title on PS 7+,
        or a plain ASCII border header in hosts without arrow-key support.
    .PARAMETER Subtitle
        Optional subtitle displayed below the main title.
    .PARAMETER Mode
        Header density mode:
        - Compact: title/subtitle only.
        - Rich: includes version, author, links, UTCM context, use-cases, and features.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Subtitle,

        [Parameter()]
        [ValidateSet('Compact', 'Rich')]
        [string]$Mode = 'Compact'
    )

    $headerModel = Get-TBHeaderModel -Subtitle $Subtitle
    if (Test-TBArrowKeySupport) {
        Write-TBMenuHeaderPremium -HeaderModel $headerModel -Mode $Mode
    }
    else {
        Write-TBMenuHeaderClassic -HeaderModel $headerModel -Mode $Mode
    }
}

function Write-TBMenuHeaderPremium {
    <#
    .SYNOPSIS
        Premium box-drawn header with gradient colors for PS 7+.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$HeaderModel,

        [Parameter()]
        [ValidateSet('Compact', 'Rich')]
        [string]$Mode = 'Compact'
    )

    $palette = Get-TBColorPalette
    $esc = [char]27
    $reset = "${esc}[0m"

    $innerWidth = Get-TBConsoleInnerWidth
    $fitText = {
        param([string]$Text)
        if ($null -eq $Text) { return '' }
        if ($Text.Length -le $innerWidth) { return $Text }
        if ($innerWidth -le 3) { return $Text.Substring(0, [Math]::Max(0, $innerWidth)) }
        return $Text.Substring(0, $innerWidth - 3) + '...'
    }

    $writePaddedLine = {
        param(
            [string]$Text,
            [string]$Style
        )

        $clipped = & $fitText $Text
        $padded = $clipped.PadRight($innerWidth)
        Write-Host ('  {0}{1}{2}{3}{4}{5}' -f $palette.Surface, ([char]0x2502), $Style, $padded, $reset, ('{0}{1}{2}' -f $palette.Surface, ([char]0x2502), $reset))
    }

    $hero = Get-TBHeroLines -HeaderModel $HeaderModel -Premium
    $subtitleText = & $fitText $hero.SubtitleLine

    $writeCenteredStyledLine = {
        param(
            [string]$Text,
            [string]$Style
        )

        $clipped = & $fitText $Text
        $pad = $innerWidth - $clipped.Length
        $left = [Math]::Floor($pad / 2)
        $right = $pad - $left
        Write-Host ('  {0}{1}{2}{3}{4}{5}{6}{7}' -f $palette.Surface, ([char]0x2502), (' ' * $left), $Style, $clipped, (' ' * $right), $palette.Surface, ([char]0x2502)) -NoNewline
        Write-Host $palette.Reset
    }

    # Color definitions for gradients
    $blueRGB = @(137, 180, 250)
    $mauveRGB = @(203, 166, 247)
    $dimRGB = @(108, 112, 134)
    $tealRGB = @(148, 226, 213)

    # Top border
    $topLine = Get-TBGradientLine -Character ([char]0x2500) -Length $innerWidth -StartRGB $blueRGB -EndRGB $mauveRGB
    Write-Host ('  {0}{1}{2}{3}' -f $palette.Surface, ([char]0x256D), $topLine, ([char]0x256E)) -NoNewline
    Write-Host $palette.Reset

    # Empty line
    $emptyInner = ' ' * $innerWidth
    Write-Host ('  {0}{1}{2}{3}' -f $palette.Surface, ([char]0x2502), $emptyInner, ([char]0x2502)) -NoNewline
    Write-Host $palette.Reset

    # ASCII art title (centered as a single block with gradient)
    $heroArtLines = @($hero.ArtLines | ForEach-Object { $_.TrimEnd() })
    $heroArtWidth = ($heroArtLines | Measure-Object -Property Length -Maximum).Maximum
    foreach ($artLine in $heroArtLines) {
        $artNormalized = $artLine.PadRight($heroArtWidth)
        $artClipped = & $fitText $artNormalized
        $artPad = $innerWidth - $artClipped.Length
        $artLeft = [Math]::Floor($artPad / 2)
        $artRight = $artPad - $artLeft
        $gradientArt = Get-TBGradientString -Text $artClipped -StartRGB $blueRGB -EndRGB $mauveRGB -Prefix "${esc}[1m"
        Write-Host ('  {0}{1}{2}{3}{4}{5}{6}' -f $palette.Surface, ([char]0x2502), (' ' * $artLeft), $gradientArt, (' ' * $artRight), $palette.Surface, ([char]0x2502)) -NoNewline
        Write-Host $palette.Reset
    }

    # Brand line under monogram
    $brandText = & $fitText $HeaderModel.Title
    $brandPad = $innerWidth - $brandText.Length
    $brandLeft = [Math]::Floor($brandPad / 2)
    $brandRight = $brandPad - $brandLeft
    $gradientBrand = Get-TBGradientString -Text $brandText -StartRGB $blueRGB -EndRGB $mauveRGB -Prefix "${esc}[1m"
    Write-Host ('  {0}{1}{2}{3}{4}{5}{6}' -f $palette.Surface, ([char]0x2502), (' ' * $brandLeft), $gradientBrand, (' ' * $brandRight), $palette.Surface, ([char]0x2502)) -NoNewline
    Write-Host $palette.Reset

    # Subtitle line (centered, gradient dim to teal, italic)
    $subPad = $innerWidth - $subtitleText.Length
    $subLeft = [Math]::Floor($subPad / 2)
    $subRight = $subPad - $subLeft
    $gradientSub = Get-TBGradientString -Text $subtitleText -StartRGB $dimRGB -EndRGB $tealRGB -Prefix "${esc}[3m"
    Write-Host ('  {0}{1}{2}{3}{4}{5}{6}' -f $palette.Surface, ([char]0x2502), (' ' * $subLeft), $gradientSub, (' ' * $subRight), $palette.Surface, ([char]0x2502)) -NoNewline
    Write-Host $palette.Reset

    # Connection status and identity lines
    try {
        $connStatus = Get-TBConnectionStatus
        if ($connStatus.Connected) {
            $identityLabel = Format-TBTenantIdentity -ConnectionStatus $connStatus
            $statusText = 'Status: Connected'
            $statusStyle = $palette.Green
            $identityText = 'Organization: {0}' -f $identityLabel
            $identityStyle = $palette.Teal
            $actionText = $null
            $actionStyle = $palette.Dim
        }
        else {
            $statusText = 'Status: Sign-in required'
            $statusStyle = $palette.Red
            $identityText = 'Organization: n/a'
            $identityStyle = $palette.Dim
            $actionText = 'Action: Select Sign in to continue'
            $actionStyle = $palette.Yellow
        }
    }
    catch {
        $statusText = 'Status: Unknown'
        $statusStyle = $palette.Yellow
        $identityText = 'Organization: n/a'
        $identityStyle = $palette.Dim
        $actionText = 'Action: Open Connection Status to sign in'
        $actionStyle = $palette.Yellow
    }
    & $writeCenteredStyledLine -Text $statusText -Style $statusStyle
    & $writeCenteredStyledLine -Text $identityText -Style $identityStyle
    if ($actionText) {
        & $writeCenteredStyledLine -Text $actionText -Style $actionStyle
    }

    if ($Mode -eq 'Rich') {
        & $writePaddedLine -Text '' -Style $palette.Text
        & $writePaddedLine -Text $HeaderModel.MetaLine -Style $palette.Dim
        & $writePaddedLine -Text $HeaderModel.LinksLine -Style $palette.Subtext
        & $writePaddedLine -Text $HeaderModel.UTCMShort -Style $palette.Peach
        & $writePaddedLine -Text $HeaderModel.CapabilitiesLine -Style $palette.Subtext
    }

    # Empty line
    Write-Host ('  {0}{1}{2}{3}' -f $palette.Surface, ([char]0x2502), $emptyInner, ([char]0x2502)) -NoNewline
    Write-Host $palette.Reset

    # Separator
    $sepLine = Get-TBGradientLine -Character ([char]0x2500) -Length $innerWidth -StartRGB $blueRGB -EndRGB $mauveRGB
    Write-Host ('  {0}{1}{2}{3}' -f $palette.Surface, ([char]0x251C), $sepLine, ([char]0x2524)) -NoNewline
    Write-Host $palette.Reset
}

function Write-TBMenuHeaderClassic {
    <#
    .SYNOPSIS
        Classic ASCII header for non-interactive hosts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$HeaderModel,

        [Parameter()]
        [ValidateSet('Compact', 'Rich')]
        [string]$Mode = 'Compact'
    )

    $maxWidth = [Math]::Min((Get-TBConsoleInnerWidth), 100)
    if ($maxWidth -lt 40) {
        $maxWidth = 40
    }

    $fitText = {
        param([string]$Text)
        if ($null -eq $Text) { return '' }
        if ($Text.Length -le $maxWidth) { return $Text }
        if ($maxWidth -le 3) { return $Text.Substring(0, [Math]::Max(0, $maxWidth)) }
        return $Text.Substring(0, $maxWidth - 3) + '...'
    }

    $centerText = {
        param([string]$Text)
        $clipped = & $fitText $Text
        if ($clipped.Length -ge $maxWidth) {
            return $clipped
        }
        $left = [Math]::Floor(($maxWidth - $clipped.Length) / 2)
        $right = $maxWidth - $clipped.Length - $left
        return (' ' * $left) + $clipped + (' ' * $right)
    }

    $hero = Get-TBHeroLines -HeaderModel $HeaderModel
    $heroArtLines = @($hero.ArtLines | ForEach-Object { $_.TrimEnd() })
    $heroArtWidth = ($heroArtLines | Measure-Object -Property Length -Maximum).Maximum
    $lines = [System.Collections.ArrayList]::new()
    foreach ($heroLine in $heroArtLines) {
        $null = $lines.Add((& $centerText $heroLine.PadRight($heroArtWidth)))
    }
    $null = $lines.Add((& $centerText $HeaderModel.Title))
    $null = $lines.Add((& $centerText $hero.SubtitleLine))

    # Connection status lines
    try {
        $connStatus = Get-TBConnectionStatus
        if ($connStatus.Connected) {
            $statusText = 'Status: Connected'
            $identityText = 'Organization: {0}' -f (Format-TBTenantIdentity -ConnectionStatus $connStatus)
            $actionText = $null
        }
        else {
            $statusText = 'Status: Sign-in required'
            $identityText = 'Organization: n/a'
            $actionText = 'Action: Select Sign in to continue'
        }
    }
    catch {
        $statusText = 'Status: Unknown'
        $identityText = 'Organization: n/a'
        $actionText = 'Action: Open Connection Status to sign in'
    }
    $null = $lines.Add((& $centerText $statusText))
    $null = $lines.Add((& $centerText $identityText))
    if ($actionText) {
        $null = $lines.Add((& $centerText $actionText))
    }

    if ($Mode -eq 'Rich') {
        $null = $lines.Add((& $fitText $HeaderModel.MetaLine).PadRight($maxWidth))
        $null = $lines.Add((& $fitText $HeaderModel.LinksLine).PadRight($maxWidth))
        $null = $lines.Add((& $fitText $HeaderModel.UTCMShort).PadRight($maxWidth))
        $null = $lines.Add((& $fitText $HeaderModel.CapabilitiesLine).PadRight($maxWidth))
    }

    $border = '=' * ($maxWidth + 2)
    $shadowBorder = '-' * ($maxWidth + 2)

    Write-Host ''
    Write-Host ('  {0}' -f $shadowBorder) -ForegroundColor DarkGray
    Write-Host ('  {0}' -f $border) -ForegroundColor Cyan
    foreach ($line in $lines) {
        Write-Host ('  |{0}|' -f $line) -ForegroundColor Cyan
    }
    Write-Host ('  {0}' -f $border) -ForegroundColor Cyan
    Write-Host ('  {0}' -f $shadowBorder) -ForegroundColor DarkGray
    Write-Host ''
}
