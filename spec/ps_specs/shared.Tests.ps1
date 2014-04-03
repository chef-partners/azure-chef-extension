#
# To run pester tests you have to clone git-repo: $git clone https://github.com/pester/Pester
# Then open powershell terminal and do:
# To import pester
# PS>Import-Module <pester_git_repo_path>/Pester.psm1
#
# To run pester tests
# PS>Invoke-Pester -relative_path <azure-chef-extension-repo-path>/spec/shared.Tests.ps1
#
# For more info: http://johanleino.wordpress.com/2013/09/13/pester-unit-testing-for-powershell/

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")

. $here.Replace("\spec\ps_specs", "\ChefExtensionHandler\bin\$sut")

describe "#getMachineArch" {

  it "returns i686 when PROCESSOR_ARCHITECTURE is x86" {
    $env:PROCESSOR_ARCHITECTURE = "x86"
    $result = getMachineArch

    $result | should Be("i686")
  }

  it "returns x86_64 when PROCESSOR_ARCHITECTURE is AMD64" {
    $env:PROCESSOR_ARCHITECTURE = "AMD64"
    $result = getMachineArch

    $result | should Be("x86_64")
  }
}

describe "#getMachineOS" {

  context "when OSVersion is 6.0" {
    it "returns 2008 machine os" {
      mock getMajorOSVersion {return "6"}
      mock getMinorOSVersion {return "0"}

      $result = getMachineOS

      $result | should Be("2008")
    }
  }

  context "when OSVersion is 6.1" {
    it "returns 2008r2 machine os " {
      mock getMajorOSVersion {return "6"}
      mock getMinorOSVersion {return "1"}

      $result = getMachineOS

      $result | should Be("2008r2")
    }
  }

  context "when OSVersion is 6.2" {
    it "returns 2012 machine os " {
      mock getMajorOSVersion {return "6"}
      mock getMinorOSVersion {return "2"}

      $result = getMachineOS

      $result | should Be("2012")
    }
  }

  context "when OSVersion is 6.3" {
    it "returns 2012 machine os " {
      mock getMajorOSVersion {return "6"}
      mock getMinorOSVersion {return "3"}

      $result = getMachineOS

      $result | should Be("2012")
    }
  }

  context "when OSVersion is 5.2" {
    it "returns 2003r2 machine os" {
      mock getMajorOSVersion {return "5"}
      mock getMinorOSVersion {return "2"}

      $result = getMachineOS

      $result | should Be("2003r2")
    }
  }

  context "when OSVersion is unknown" {
    it "returns default 2008r2 machine os" {
      mock getMajorOSVersion {return "6"}
      mock getMinorOSVersion {return "5"}

      $result = getMachineOS

      $result | should Be("2008r2")
    }
  }
}