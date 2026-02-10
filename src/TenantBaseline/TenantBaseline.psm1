if ($PSVersionTable.PSVersion -lt [version]'7.2') {
    throw 'TenantBaseline requires PowerShell 7.2 or later. Install PowerShell 7.2+ and re-import the module.'
}

# Module-scoped state
$script:TBApiBaseUri = 'https://graph.microsoft.com/beta/admin/configurationManagement'
$script:UTCMAppId = '03b07b79-c5bc-4b5e-9bfa-13acf4a99998'
$script:TBConnection = $null
$script:TBModuleRoot = $PSScriptRoot

# Dot-source all private functions
$privatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Private'
if (Test-Path -Path $privatePath) {
    $privateFiles = Get-ChildItem -Path $privatePath -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $privateFiles) {
        try {
            . $file.FullName
        }
        catch {
            Write-Error -Message ("Failed to import private function '{0}': {1}" -f $file.FullName, $_)
        }
    }
}

# Dot-source all public functions (recursively through subdirectories)
$publicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
if (Test-Path -Path $publicPath) {
    $publicFiles = Get-ChildItem -Path $publicPath -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $publicFiles) {
        try {
            . $file.FullName
        }
        catch {
            Write-Error -Message ("Failed to import public function '{0}': {1}" -f $file.FullName, $_)
        }
    }
}
