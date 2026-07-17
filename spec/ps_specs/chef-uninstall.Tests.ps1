#
# To run pester tests you have to clone git-repo: $git clone https://github.com/pester/Pester
# Then open powershell terminal and do:
# To import pester
# PS>Import-Module <pester_git_repo_path>/Pester.psm1
#
# To run pester tests
# PS>Invoke-Pester -relative_path <azure-chef-extension-repo-path>/spec/chef-uninstall.Tests.ps1
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
}

describe "#Uninstall-ChefClient" {
  BeforeEach {
    $script:tempPS = ([System.IO.Path]::GetTempFileName() | Rename-Item -NewName { $_ -replace 'tmp$', 'ps1' } -PassThru)
    mock Get-SharedHelper {return $script:tempPS}
    mock Read-JsonFile
    mock Write-ChefStatus
    mock Uninstall-ChefService
    mock Uninstall-ChefSchTask
    mock Uninstall-AzureChefExtensionGem
    mock Update-ChefExtensionRegistry
    mock Get-PublicSettings-From-Config-Json { return "service" } -ParameterFilter { $key -eq "daemon" }
  }

  AfterEach {
    Remove-Item $script:tempPS -ErrorAction SilentlyContinue
  }

  context "when daemon is service and not mid-update" {
    it "uninstalls the chef service and azure-chef-extension gem" {
      mock Get-PowershellVersion { return 3 }
      mock Test-ChefExtensionRegistry { return $false }

      Uninstall-ChefClient

      Assert-MockCalled Write-ChefStatus -Times 2
      Assert-MockCalled Read-JsonFile -Times 1
      Assert-MockCalled Uninstall-ChefService -Times 1
      Assert-MockCalled Uninstall-ChefSchTask -Times 0
      Assert-MockCalled Uninstall-AzureChefExtensionGem -Times 1
    }
  }

  context "when daemon is task" {
    it "uninstalls the scheduled task instead of the service" {
      mock Get-PublicSettings-From-Config-Json { return "task" } -ParameterFilter { $key -eq "daemon" }
      mock Get-PowershellVersion { return 3 }
      mock Test-ChefExtensionRegistry { return $false }

      Uninstall-ChefClient

      Assert-MockCalled Uninstall-ChefSchTask -Times 1
      Assert-MockCalled Uninstall-ChefService -Times 0
      Assert-MockCalled Uninstall-AzureChefExtensionGem -Times 1
    }
  }

  context "when powershell version is below 3" {
    it "skips json status logging but still uninstalls" {
      mock Get-PowershellVersion { return 2 }
      mock Test-ChefExtensionRegistry { return $false }

      Uninstall-ChefClient

      Assert-MockCalled Write-ChefStatus -Times 0
      Assert-MockCalled Read-JsonFile -Times 0
      Assert-MockCalled Uninstall-ChefService -Times 1
      Assert-MockCalled Uninstall-AzureChefExtensionGem -Times 1
    }
  }

  context "when update process is running" {
    it "skips chef uninstallation" {
      mock Get-PowershellVersion { return 3 }
      mock Test-ChefExtensionRegistry { return $true }

      Uninstall-ChefClient

      Assert-MockCalled Update-ChefExtensionRegistry -Times 1 -ParameterFilter { $Value -eq "X" }
      Assert-MockCalled Write-ChefStatus -Times 1
      Assert-MockCalled Read-JsonFile -Times 1
      Assert-MockCalled Uninstall-ChefService -Times 0
      Assert-MockCalled Uninstall-AzureChefExtensionGem -Times 0
    }
  }
}