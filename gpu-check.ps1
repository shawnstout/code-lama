$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Static variables
$CUDA_VERSION = "12.6"
$NVIDIA_SMI_VERSION = "560.76"
$NVIDIA_GPU = "NVIDIA RTX 1000 Ada Generation Laptop GPU"
$WINDOWS_VERSION = "10.0.22631"
$WSL_VERSION = "2.3.24.0"

function Write-Log($message) { 
  Write-Host $message 
}

function Get-ErrorLineContent($errorRecord) {
  $line = $errorRecord.InvocationInfo.ScriptLineNumber
  $file = $errorRecord.InvocationInfo.ScriptName
  $content = (Get-Content $file)[$line - 1].Trim()
  return "Error in file $file at line ${line}:`n$content"
}

function Check-Command($cmd) { 
  return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) 
}

function New-GPUInfoObject {
  param (
      [string]$Name,
      [int]$TotalMemory,
      [int]$UsedMemory,
      [int]$Utilization
  )
  return [PSCustomObject]@{
      Name          = $Name
      TotalMemory   = $TotalMemory
      UsedMemory    = $UsedMemory
      Utilization   = $Utilization
  }
}

function Check-NvidiaGPUAndCUDA {
  Write-Log "Checking NVIDIA GPU and CUDA..."
  Write-Log "NVIDIA GPU: $NVIDIA_GPU"
  Write-Log "NVIDIA-SMI Version: $NVIDIA_SMI_VERSION"
  Write-Log "CUDA Version: $CUDA_VERSION"

  try {
      $gpuInfo = & nvidia-smi --query-gpu=name,memory.total,memory.used,utilization.gpu --format=csv,noheader,nounits

      if ($gpuInfo) {
          $gpuObjects = @()
          $totalMemory = 0
          $usedMemory = 0

          $gpuInfo | ForEach-Object {
              $parts = $_ -split ','
              $gpuObject = New-GPUInfoObject -Name $parts[0] -TotalMemory ([int]$parts[1]) -UsedMemory ([int]$parts[2]) -Utilization ([int]$parts[3])
              $gpuObjects += $gpuObject

              Write-Log "GPU Name: $($gpuObject.Name)"
              Write-Log "Total Memory: $($gpuObject.TotalMemory) MB"
              Write-Log "Used Memory: $($gpuObject.UsedMemory) MB"
              Write-Log "GPU Utilization: $($gpuObject.Utilization)%"
              
              $totalMemory += $gpuObject.TotalMemory
              $usedMemory += $gpuObject.UsedMemory
          }

          Write-Log "Total GPU Cores Available: $($gpuObjects.Count)"
          Write-Log "Total GPU Memory: $totalMemory MB"
          Write-Log "Total GPU Memory Used: $usedMemory MB"
          return $gpuObjects.Count -gt 0
      } else {
          Write-Log "No NVIDIA GPU detected."
          return $false
      }
  } catch {
      Write-Log "Error: $_"
      Write-Log (Get-ErrorLineContent $_)
      return $false
  }
}

function Check-WindowsVersion {
  Write-Log "Checking Windows version..."
  $currentVersion = [version]$WINDOWS_VERSION
  $expectedVersion = [version]"10.0.22000"
  $result = $currentVersion -ge $expectedVersion
  Write-Log "Windows version: $WINDOWS_VERSION, Expected minimum: $expectedVersion, Check $(if($result){'Passed'}else{'Failed'})"
  if (-not $result) {
      Write-Log "Failure Reason: Current version $currentVersion is less than expected version $expectedVersion."
  }
  return $result
}

function Check-WSL2Enabled {
  Write-Log "Checking WSL 2..."
  try {
      $defaultDistro = Get-WslDistribution -Default
      $ubuntuWSLVersion = $defaultDistro.Version
      
      if ($ubuntuWSLVersion -eq 2) {
          Write-Log "Default WSL distribution is $($defaultDistro.Name) running on version $ubuntuWSLVersion"
          return $true
      } else {
          Write-Log "Default WSL distribution is running on version $ubuntuWSLVersion, expected version is 2."
          return $false
      }
  } catch {
      Write-Log "Error: $_"
      Write-Log (Get-ErrorLineContent $_)
      return $false
  }
}

function Check-DockerDesktop {
  Write-Log "Checking Docker Desktop..."
  try {
      if (-not (Check-Command docker)) { throw "Docker not installed." }
      $dockerVersion = docker version --format '{{.Server.Version}}'
      Write-Log "Docker version: $dockerVersion"
      $dockerInfo = docker info --format '{{.OSType}}'
      if ($dockerInfo -ne "linux") { throw "Docker not using Linux backend." }
      return $true
  } catch {
      Write-Log "Error: $_"
      Write-Log (Get-ErrorLineContent $_)
      return $false
  }
}

function Check-WSLGPUSupport {
  Write-Log "Checking WSL GPU Support..."
  $wslConfigPath = "$env:USERPROFILE\.wslconfig"
  if (Test-Path $wslConfigPath) {
      $wslConfig = Get-Content $wslConfigPath -Raw
      if ($wslConfig -match "gpuSupport=true") { return $true }
  }
  Write-Log "Enabling GPU support in .wslconfig..."
  try {
      "[wsl2]`ngpuSupport=true" | Set-Content -Path $wslConfigPath -Force
      return $true
  } catch {
      Write-Log "Error: $_"
      Write-Log (Get-ErrorLineContent $_)
      return $false
  }
}

function Check-DockerGPUSupport {
  Write-Log "Checking Docker GPU Support..."
  try {
      $cudaImageTag = "12.6.1-base-ubuntu24.04"
      $testResult = docker run --rm --gpus all "nvidia/cuda:$cudaImageTag" nvidia-smi
      if ($LASTEXITCODE -eq 0) {
          Write-Log "Docker GPU support is working with CUDA image: nvidia/cuda:$cudaImageTag"
          return $true
      } else {
          Write-Log "Docker GPU support test failed. Output:`n$testResult"
          return $false
      }
  } catch {
      Write-Log "Error: $_"
      Write-Log (Get-ErrorLineContent $_)
      return $false
  }
}

function Run-Checks {
  $checks = @(
      @{Name="NVIDIA GPU and CUDA"; Func={Check-NvidiaGPUAndCUDA}},
      @{Name="Windows Version"; Func={Check-WindowsVersion}},
      @{Name="WSL 2 Enabled"; Func={Check-WSL2Enabled}},
      @{Name="Docker Desktop"; Func={Check-DockerDesktop}},
      @{Name="WSL GPU Support"; Func={Check-WSLGPUSupport}},
      @{Name="Docker GPU Support"; Func={Check-DockerGPUSupport}}
  )

  $results = @()
  foreach ($check in $checks) {
      $result = & $check.Func
      $results += @{Name=$check.Name; Passed=$result}
      if (-not $result) { break }
  }
  return $results
}

$checkResults = Run-Checks

$allPassed = ($checkResults | Where-Object { -not $_.Passed } | Measure-Object).Count -eq 0

if ($allPassed) {
  Write-Log "All checks passed. Your system is ready for GPU-accelerated Docker containers using Ubuntu on WSL 2."
} else {
  Write-Log "Some checks failed. Results:"
  $checkResults | ForEach-Object {
      Write-Log "$($_.Name): $(if($_.Passed){'Passed'}else{'Failed'})"
      if (-not $_.Passed) {
          Write-Log "Failure Details: Check the individual function for more information."
      }
  }
  Write-Log "Please address the issues and run the script again."
  Write-Error "GPU check failed. Address the issues before proceeding."
}

Write-Log "`nAdditional Debugging Information:"
Write-Log "WSL Version: $WSL_VERSION"
Write-Log "`nWSL Distributions:"
wsl -l -v
Write-Log "`nWSL and WSLg Versions:"
wsl --version
Write-Log "`nDocker Version:"
docker version
Write-Log "`nDocker Info:"
docker info
Write-Log "`nNVIDIA-SMI Output:"
nvidia-smi