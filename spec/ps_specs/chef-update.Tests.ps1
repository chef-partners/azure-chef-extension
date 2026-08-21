#
# To run pester tests you have to clone git-repo: $git clone https://github.com/pester/Pester
# Then open powershell terminal and do:
# To import pester
# PS>Import-Module <pester_git_repo_path>/Pester.psm1
#
# To run pester tests
# PS>Invoke-Pester -relative_path <azure-chef-extension-repo-path>/spec/chef-update.Tests.ps1
#
# For more info: http://johanleino.wordpress.com/2013/09/13/pester-unit-testing-for-powershell/

# Pester 5 only executes file-scope code during Discovery, not Run — compute
# paths and dot-source/import inside BeforeAll so the functions under test
# are available when It blocks execute.
BeforeAll {
  $here = Split-Path -Parent $PSCommandPath
  $suit = (Split-Path -Leaf $PSCommandPath).Replace(".Tests.ps1", ".psm1")

  $module= $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\$suit")
  # Load the .psm1 content into this scope (rather than Import-Module) so
  # Pester's Mock can intercept calls to its functions directly. Dot-source
  # from a real temp .ps1 file (not Invoke-Expression) so Chef-GetScriptDirectory's
  # $MyInvocation.MyCommand.Path lookup resolves to a real path instead of $null.
  $code = Get-Content $module | Out-String
  $tempModuleScript = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.ps1'
  Set-Content -Path $tempModuleScript -Value $code
  # Export-ModuleMember only works inside a real module; no-op it since we're
  # intentionally loading into this scope directly (for Pester mocking) rather
  # than via Import-Module.
  function Export-ModuleMember { }
  . $tempModuleScript
  Remove-Item $tempModuleScript

  $sharedHelper = $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\shared.ps1")
  . $sharedHelper

  $chefUninstall = $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\chef-uninstall.psm1")
  $chefInstall = $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\chef-install.psm1")

  Import-Module $chefInstall
  Import-Module $chefUninstall
}

describe "#Update-ChefClient" {
  BeforeEach {
    $script:tempPS = ([System.IO.Path]::GetTempFileName() | Rename-Item -NewName { $_ -replace 'tmp$', 'ps1' } -PassThru)
    mock Get-SharedHelper {return $script:tempPS}
    mock Import-Module
    mock Uninstall-ChefClient
    mock Install-ChefClient
    mock Update-ChefExtensionRegistry
    mock Write-ChefStatus
  }

  AfterEach {
    Remove-Item $script:tempPS -ErrorAction SilentlyContinue
  }

  context "when there is no stale node-registered file" {
    it "uninstalls then reinstalls chef and marks the registry updated" {
      mock Get-BootstrapDirectory { return $env:tmp }
      mock Test-Path { return $false }
      mock Remove-Item

      Update-ChefClient

      Assert-MockCalled Uninstall-ChefClient -Times 1 -ParameterFilter { $calledFromUpdate -eq $true }
      Assert-MockCalled Install-ChefClient -Times 1
      Assert-MockCalled Update-ChefExtensionRegistry -Times 1 -ParameterFilter { $Value -eq "updated" }
      Assert-MockCalled Remove-Item -Times 0
    }
  }

  context "when a stale node-registered file exists" {
    it "removes it before running the update" {
      mock Get-BootstrapDirectory { return $env:tmp }
      mock Test-Path { return $true }
      mock Remove-Item

      Update-ChefClient

      Assert-MockCalled Remove-Item -Times 1
      Assert-MockCalled Install-ChefClient -Times 1
    }
  }

  context "when the install step fails" {
    it "reports the error via Write-ChefStatus instead of throwing" {
      mock Get-BootstrapDirectory { return $env:tmp }
      mock Test-Path { return $false }
      mock Install-ChefClient { throw "boom" }

      { Update-ChefClient } | Should -Not -Throw

      Assert-MockCalled Write-ChefStatus -Times 1 -ParameterFilter { $statusType -eq "error" }
      Assert-MockCalled Update-ChefExtensionRegistry -Times 0
    }
  }
}