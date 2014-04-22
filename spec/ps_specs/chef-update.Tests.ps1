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

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.ps1", ".psm1")

$module= $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\$sut")
$code = Get-Content $module | Out-String
Invoke-Expression $code

$sharedHelper = $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\shared.ps1")
. $sharedHelper

$chefUninstall = $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\chef-uninstall.psm1")
$chefInstall = $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\chef-install.psm1")

Import-Module $chefUninstall
Import-Module $chefInstall

describe "#Update-ChefClient" {
  context "when powershell version 3" {
    it "update ChefClient" {
      mock Import-Module
      $tmp = "$($env:tmp)"
      mock Get-BootstrapDirectory { return "C:/chef"}
      mock Get-TempBackupDir { return $tmp}
      # create temp powershell file for mock Get-SharedHelper
      $tempPS = ([System.IO.Path]::GetTempFileName() | Rename-Item -NewName { $_ -replace 'tmp$', 'ps1' } -PassThru)
      mock Get-SharedHelper {return $tempPS}
      mock Get-PowershellVersion { return 3 }
      mock Read-JsonFile
      mock Read-JsonFileUsingRuby
      mock Copy-Item

      mock Uninstall-ChefClient
      mock Install-ChefClient
      mock Update-ChefExtensionRegistry

      Update-ChefClient
      # Delete temp file created for Get-SharedHelper
      Remove-Item $tempPS

      # Read-JsonFile call when PS version >=3
      Assert-MockCalled Read-JsonFile -Times 1
      # Read-JsonFileUsingRuby call when PS version <=3
      Assert-MockCalled Read-JsonFileUsingRuby -Times 0
      Assert-MockCalled Get-BootstrapDirectory -Times 1
      Assert-MockCalled Get-TempBackupDir -Times 1
      Assert-MockCalled Copy-Item -Times 2
      Assert-MockCalled Uninstall-ChefClient -Times 1
      Assert-MockCalled Install-ChefClient -Times 1
      Assert-MockCalled Update-ChefExtensionRegistry -Times 1
    }
  }

  context "when powershell version 2" {
    it "update ChefClient" {
      mock Import-Module
      $tmp = "$($env:tmp)"
      mock Get-BootstrapDirectory { return "C:/chef"}
      mock Get-TempBackupDir { return $tmp}
      # create temp powershell file for mock Get-SharedHelper
      $tempPS = ([System.IO.Path]::GetTempFileName() | Rename-Item -NewName { $_ -replace 'tmp$', 'ps1' } -PassThru)
      mock Get-SharedHelper {return $tempPS}
      mock Get-PowershellVersion { return 2 }
      mock Read-JsonFile
      mock Read-JsonFileUsingRuby
      mock Copy-Item

      mock Uninstall-ChefClient
      mock Install-ChefClient
      mock Update-ChefExtensionRegistry

      Update-ChefClient
      # Delete temp file created for Get-SharedHelper
      Remove-Item $tempPS

      # Read-JsonFile call when PS version >=3
      Assert-MockCalled Read-JsonFile -Times 0
      # Read-JsonFileUsingRuby call when PS version <=3
      Assert-MockCalled Read-JsonFileUsingRuby -Times 1
      Assert-MockCalled Get-BootstrapDirectory -Times 1
      Assert-MockCalled Get-TempBackupDir -Times 1
      Assert-MockCalled Copy-Item -Times 2
      Assert-MockCalled Uninstall-ChefClient -Times 1
      Assert-MockCalled Install-ChefClient -Times 1
      Assert-MockCalled Update-ChefExtensionRegistry -Times 1
    }
  }
}
