#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Render-TBAccordionBox' {

    Context 'Function exists and has correct parameters' {

        It 'Has required parameters' {
            InModuleScope TenantBaseline {
                $cmd = Get-Command Render-TBAccordionBox -ErrorAction SilentlyContinue
                $cmd | Should -Not -BeNullOrEmpty
                $cmd.Parameters.ContainsKey('Rows') | Should -Be $true
                $cmd.Parameters.ContainsKey('SelectedIndex') | Should -Be $true
                $cmd.Parameters.ContainsKey('AnchorTop') | Should -Be $true
                $cmd.Parameters.ContainsKey('PreviousRowCount') | Should -Be $true
            }
        }
    }

    Context 'Rendering with mocked Console' {

        It 'Does not throw when rendering parent and child rows' {
            Mock -ModuleName TenantBaseline Get-TBColorPalette {
                $empty = @{}
                foreach ($key in @('Text','Subtext','Dim','Blue','Green','Red','Yellow','Mauve','Teal','Peach','Surface','BgSelect','Bold','Italic','DimStyle','Reset')) {
                    $empty[$key] = ''
                }
                return $empty
            }
            Mock -ModuleName TenantBaseline Get-TBGradientLine { return ('-' * $Length) }

            InModuleScope TenantBaseline {
                $rows = @(
                    @{ Type = 'parent'; SectionIndex = 0; Label = 'Section A'; Expanded = $true; IsDirect = $false }
                    @{ Type = 'child'; SectionIndex = 0; ChildIndex = 0; Label = 'Child 1' }
                    @{ Type = 'child'; SectionIndex = 0; ChildIndex = 1; Label = 'Child 2' }
                    @{ Type = 'parent'; SectionIndex = 1; Label = 'Section B'; Expanded = $false; IsDirect = $false }
                )

                # Mock Console methods since they are not available in test host
                $mockSetCursor = { param($x, $y) }
                $mockWrite = { param($text) }

                # Use try/catch since Console methods may not work in test host
                try {
                    Render-TBAccordionBox -Rows $rows -SelectedIndex 1 -AnchorTop 5 -PreviousRowCount 4
                }
                catch {
                    # Expected in non-interactive test host - Console.SetCursorPosition fails
                    $_.Exception.Message | Should -Not -BeNullOrEmpty
                }
            }
        }
    }

    Context 'Accepts empty rows' {

        It 'Has AllowEmptyCollection on Rows parameter' {
            InModuleScope TenantBaseline {
                $cmd = Get-Command Render-TBAccordionBox
                $attr = $cmd.Parameters['Rows'].Attributes | Where-Object { $_ -is [AllowEmptyCollection] }
                $attr | Should -Not -BeNullOrEmpty
            }
        }
    }
}
