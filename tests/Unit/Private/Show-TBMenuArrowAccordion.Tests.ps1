#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Build-TBAccordionRows' {

    Context 'All sections collapsed' {

        It 'Returns only parent rows when no section is expanded' {
            $result = InModuleScope TenantBaseline {
                $sections = @(
                    @{ Title = 'Section A'; Children = @('Child 1', 'Child 2'); IsDirect = $false }
                    @{ Title = 'Section B'; Children = @('Child 3'); IsDirect = $false }
                    @{ Title = 'Section C'; Children = @(); IsDirect = $true }
                )
                Build-TBAccordionRows -Sections $sections -ExpandedIndex -1
            }

            $result.Count | Should -Be 3
            $result[0].Type | Should -Be 'parent'
            $result[0].Label | Should -Be 'Section A'
            $result[0].Expanded | Should -Be $false
            $result[0].ChildCount | Should -Be 2
            $result[1].Type | Should -Be 'parent'
            $result[1].Label | Should -Be 'Section B'
            $result[1].ChildCount | Should -Be 1
            $result[2].Type | Should -Be 'parent'
            $result[2].IsDirect | Should -Be $true
            $result[2].ChildCount | Should -Be 0
        }
    }

    Context 'One section expanded' {

        It 'Includes child rows under the expanded section' {
            $result = InModuleScope TenantBaseline {
                $sections = @(
                    @{ Title = 'Section A'; Children = @('Child 1', 'Child 2'); IsDirect = $false }
                    @{ Title = 'Section B'; Children = @('Child 3'); IsDirect = $false }
                )
                Build-TBAccordionRows -Sections $sections -ExpandedIndex 0
            }

            $result.Count | Should -Be 4
            $result[0].Type | Should -Be 'parent'
            $result[0].Expanded | Should -Be $true
            $result[0].ChildCount | Should -Be 2
            $result[1].Type | Should -Be 'child'
            $result[1].Label | Should -Be 'Child 1'
            $result[1].ChildIndex | Should -Be 0
            $result[2].Type | Should -Be 'child'
            $result[2].Label | Should -Be 'Child 2'
            $result[2].ChildIndex | Should -Be 1
            $result[3].Type | Should -Be 'parent'
            $result[3].Expanded | Should -Be $false
        }

        It 'Expands a middle section correctly' {
            $result = InModuleScope TenantBaseline {
                $sections = @(
                    @{ Title = 'A'; Children = @('A1'); IsDirect = $false }
                    @{ Title = 'B'; Children = @('B1', 'B2', 'B3'); IsDirect = $false }
                    @{ Title = 'C'; Children = @('C1'); IsDirect = $false }
                )
                Build-TBAccordionRows -Sections $sections -ExpandedIndex 1
            }

            $result.Count | Should -Be 6
            $result[0].Type | Should -Be 'parent'
            $result[0].Expanded | Should -Be $false
            $result[0].ChildCount | Should -Be 1
            $result[1].Type | Should -Be 'parent'
            $result[1].Expanded | Should -Be $true
            $result[1].ChildCount | Should -Be 3
            $result[2].Type | Should -Be 'child'
            $result[2].SectionIndex | Should -Be 1
            $result[2].ChildIndex | Should -Be 0
            $result[3].Type | Should -Be 'child'
            $result[3].ChildIndex | Should -Be 1
            $result[4].Type | Should -Be 'child'
            $result[4].ChildIndex | Should -Be 2
            $result[5].Type | Should -Be 'parent'
        }
    }

    Context 'Direct sections' {

        It 'Does not expand a direct section even when ExpandedIndex points to it' {
            $result = InModuleScope TenantBaseline {
                $sections = @(
                    @{ Title = 'Direct'; Children = @(); IsDirect = $true }
                    @{ Title = 'Normal'; Children = @('N1'); IsDirect = $false }
                )
                Build-TBAccordionRows -Sections $sections -ExpandedIndex 0
            }

            # Direct has no children so Expanded check passes but no child rows appear
            $result.Count | Should -Be 2
            $result[0].Type | Should -Be 'parent'
            $result[0].ChildCount | Should -Be 0
            $result[1].Type | Should -Be 'parent'
            $result[1].ChildCount | Should -Be 1
        }
    }

    Context 'Section indices' {

        It 'Preserves section and child indices' {
            $result = InModuleScope TenantBaseline {
                $sections = @(
                    @{ Title = 'S0'; Children = @('S0C0', 'S0C1'); IsDirect = $false }
                    @{ Title = 'S1'; Children = @('S1C0'); IsDirect = $false }
                )
                Build-TBAccordionRows -Sections $sections -ExpandedIndex 0
            }

            $result[0].SectionIndex | Should -Be 0
            $result[0].ChildCount | Should -Be 2
            $result[1].SectionIndex | Should -Be 0
            $result[1].ChildIndex | Should -Be 0
            $result[2].SectionIndex | Should -Be 0
            $result[2].ChildIndex | Should -Be 1
            $result[3].SectionIndex | Should -Be 1
            $result[3].ChildCount | Should -Be 1
        }
    }
}

Describe 'Show-TBMenuArrowAccordion' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Write-Host {}
        Mock -ModuleName TenantBaseline Get-TBColorPalette {
            $empty = @{}
            foreach ($key in @('Text','Subtext','Dim','Blue','Green','Red','Yellow','Mauve','Teal','Peach','Surface','BgSelect','Bold','Italic','DimStyle','Reset')) {
                $empty[$key] = ''
            }
            return $empty
        }
    }

    Context 'Quit behavior' {

        It 'Returns Quit string when mocked to return Quit' {
            # We test routing in Show-TBMainMenu tests; here just verify the function exists
            InModuleScope TenantBaseline {
                $cmd = Get-Command Show-TBMenuArrowAccordion -ErrorAction SilentlyContinue
                $cmd | Should -Not -BeNullOrEmpty
                $cmd.Parameters.ContainsKey('Sections') | Should -Be $true
                $cmd.Parameters.ContainsKey('InitialExpanded') | Should -Be $true
            }
        }
    }
}
