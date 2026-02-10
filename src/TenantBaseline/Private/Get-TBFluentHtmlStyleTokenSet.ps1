function Get-TBFluentHtmlStyleTokenSet {
    <#
    .SYNOPSIS
        Returns shared Fluent enterprise design tokens for HTML outputs.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return @"
:root {
    --tb-bg: #f4f6fb;
    --tb-surface: #ffffff;
    --tb-surface-muted: #f8f9fc;
    --tb-border: #d9deea;
    --tb-text: #1f2330;
    --tb-text-muted: #4f5a73;
    --tb-accent: #0f6cbd;
    --tb-accent-strong: #005ea2;
    --tb-success: #107c10;
    --tb-warning: #986f0b;
    --tb-danger: #c50f1f;
    --tb-shadow: 0 4px 16px rgba(21, 35, 62, 0.08);
}
body {
    font-family: 'Segoe UI Variable Text', 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;
    background: radial-gradient(circle at top right, #edf4ff, var(--tb-bg) 45%);
    color: var(--tb-text);
}
a { color: var(--tb-accent); }
a:hover { color: var(--tb-accent-strong); }
.card,
.monitor-card,
.baseline-card,
nav,
table {
    background: var(--tb-surface);
    border: 1px solid var(--tb-border);
    box-shadow: var(--tb-shadow);
}
"@
}
