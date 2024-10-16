param(
  [switch]$SkipGPUCheck,
  [switch]$UpdateBaseImages,
  [switch]$Cleanup,
  [switch]$RebuildImages
)
Clear-Host
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

Import-Module powershell-yaml

$logsDir = "logs"
$logFile = Join-Path $logsDir "build-and-run.txt"
$configFile = "config.yaml"

function Write-Log($message, [switch]$Important) {
  $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $message"
  if ($Important) {
    Write-Host $logMessage
  }
  $logMessage | Add-Content -Path $logFile
}

if (-not (Test-Path $logsDir)) {
  New-Item -ItemType Directory -Path $logsDir | Out-Null
} else {
  Remove-Item "$logsDir\*" -Force
}

Write-Log "Script started" -Important

if (Test-Path $configFile) {
  $config = Get-Content -Path $configFile -Raw | ConvertFrom-Yaml
  $global:config = [PSCustomObject]$config
  Write-Log "Loaded configuration from $configFile" -Important
} else {
  Write-Log "Configuration file not found. Please create $configFile with the necessary deployment information." -Important
  exit 1
}

$global:secrets = @{
  postgresPassword = $env:POSTGRES_PASSWORD
  supabaseAnonKey = $env:SUPABASE_ANON_KEY
}

function Get-Versions {
  @{docker = docker version --format '{{.Server.Version}}'; kubernetes = (kubectl version --client -o json | ConvertFrom-Json).clientVersion.gitVersion; cuda = "12.6.0"}.GetEnumerator() | ForEach-Object { Write-Log "$($_.Key.ToUpper()) version: $($_.Value)" -Important }
}

function Update-BaseImages {
  Write-Log "Updating base images..." -Important
  $global:config.deployments | Where-Object { $_.baseImage } | ForEach-Object {
    Write-Log "Pulling $($_.baseImage)" -Important
    docker pull $_.baseImage | Out-Null
    Write-Log "Finished pulling $($_.baseImage)" -Important
  }
}

function Build-Image($deployment) {
  if ($deployment.dockerfile) {
    Write-Log "Building $($deployment.name)..." -Important
    $logFiles = @{
      build = Join-Path $logsDir "build_$($deployment.name).txt"
      error = Join-Path $logsDir "build_$($deployment.name)_error.txt"
    }
    if (-not (Test-Path $deployment.dockerfile)) {
      Write-Log "Error: Dockerfile not found: $($deployment.dockerfile)" -Important
      return
    }

    $tempDockerfile = "Dockerfile.$($deployment.name)_$(Get-Random)"
    Get-Content $deployment.dockerfile | Set-Content $tempDockerfile

    if ($deployment.name -eq "openwebui") {
      $packageJson = @{
        name = "openwebui"
        version = "1.0.0"
        description = "OpenWebUI application"
        main = "server.js"
        dependencies = @{}
      }
      $deployment.requirements | ForEach-Object {
        $packageJson.dependencies[$_] = "*"
      }
      $packageJsonContent = $packageJson | ConvertTo-Json -Depth 10
      Add-Content $tempDockerfile "COPY package.json ."
      $packageJsonContent | Set-Content "package.json"
      Add-Content $tempDockerfile "RUN npm install"
    }

    if ($deployment.requirements -and $deployment.name -ne "openwebui") {
      $requirementsString = $deployment.requirements -join " "
      Add-Content $tempDockerfile "RUN apt-get update && apt-get install -y $requirementsString && rm -rf /var/lib/apt/lists/*"
    }

    if ($deployment.pip_requirements) {
      $pipRequirementsString = $deployment.pip_requirements -join " "
      Add-Content $tempDockerfile "RUN pip3 install --no-cache-dir $pipRequirementsString"
    }

    $buildArgs = @(
      "build", "-t", "$($deployment.name):latest",
      "-f", $tempDockerfile
    )

    $deployment.additionalFiles | ForEach-Object {
      $buildArgs += "--build-arg", "$_=$_"
    }
    $buildArgs += "."

    $process = Start-Process -FilePath "docker" -ArgumentList $buildArgs -NoNewWindow -PassThru -RedirectStandardOutput $logFiles.build -RedirectStandardError $logFiles.error

    while (-not $process.HasExited) {
      Get-Content $logFiles.build -Tail 1 | ForEach-Object { Write-Host $_ }
      Start-Sleep -Milliseconds 100
    }

    if ($process.ExitCode -ne 0) {
      Write-Log "Failed to build $($deployment.name)." -Important
      Get-Content $logFiles.error | ForEach-Object { Write-Log "Build Error: $_" -Important }
    } else {
      Write-Log "Successfully built $($deployment.name)" -Important
    }

    Remove-Item $tempDockerfile
    if ($deployment.name -eq "openwebui") {
      Remove-Item "package.json"
    }
  } elseif ($deployment.baseImage) {
    Write-Log "Using base image for $($deployment.name): $($deployment.baseImage)" -Important
  } else {
    Write-Log "Warning: No Dockerfile or base image specified for $($deployment.name)" -Important
  }
}

function Replace-Placeholders($filePath, $placeholders) {
  $content = Get-Content $filePath -Raw
  $replacementsCount = 0
  if ($null -ne $placeholders -and $placeholders.Count -gt 0) {
    $placeholders.GetEnumerator() | ForEach-Object {
      $value = switch ($_.Value) {
        "{{SUPABASE_KEY}}" { $global:secrets.supabaseAnonKey }
        "{{POSTGRES_PASSWORD}}" { $global:secrets.postgresPassword }
        default { $_.Value }
      }
      if ($content -match "{{$($_.Key)}}") {
        $content = $content -replace "{{$($_.Key)}}", $value
        $replacementsCount++
        Write-Log "Replaced placeholder: $($_.Key)" -Important
      }
    }
  }
  if ($replacementsCount -eq 0) {
    Write-Log "No placeholders found or replaced in $filePath" -Important
  } else {
    Write-Log "Replaced $replacementsCount placeholder(s) in $filePath" -Important
  }
  $content | Set-Content $filePath
}

function Cleanup-Resources {
  Write-Log "Cleaning up resources..." -Important
  $global:config.deployments | Sort-Object -Property deployOrder -Descending | ForEach-Object {
    if (Test-Path $_.k8sConfig) {
      kubectl delete -f $_.k8sConfig
    } else {
      Write-Log "Warning: K8s config file not found: $($_.k8sConfig)" -Important
    }
  }
  Write-Log "Cleanup completed." -Important
}

function Get-NonReadyDeployments {
  $nonReadyDeployments = kubectl get deployments -o json | ConvertFrom-Json | 
  Select-Object -ExpandProperty items | 
  Where-Object { $_.status.readyReplicas -lt $_.status.replicas } |
  ForEach-Object {
    [PSCustomObject]@{
      Name = $_.metadata.name
      ReadyReplicas = $_.status.readyReplicas
      TotalReplicas = $_.status.replicas
      Conditions = $_.status.conditions | Where-Object { $_.status -eq 'False' } | Select-Object -ExpandProperty reason
    }
  }
  return $nonReadyDeployments
}

function Update-NonReadyDeployments {
  $nonReadyDeployments = Get-NonReadyDeployments
  foreach ($deployment in $nonReadyDeployments) {
    Write-Log "Attempting to update deployment: $($deployment.Name)" -Important
    $config = $global:config.deployments | Where-Object { $_.name -eq $deployment.Name }
    if ($config) {
      Write-Log "Rebuilding image for $($deployment.Name)" -Important
      Build-Image $config
      Write-Log "Reapplying configuration for $($deployment.Name)" -Important
      if (Test-Path $config.k8sConfig) {
        Replace-Placeholders $config.k8sConfig $config.placeholders
        $result = kubectl apply -f $config.k8sConfig --force 2>&1
        if ($LASTEXITCODE -ne 0) {
          Write-Log "Failed to reapply $($deployment.Name) configuration. Error: $result" -Important
        } else {
          Write-Log "Successfully reapplied $($deployment.Name) configuration" -Important
        }
      } else {
        Write-Log "Error: K8s config file not found for $($deployment.Name): $($config.k8sConfig)" -Important
      }
    } else {
      Write-Log "Error: Deployment $($deployment.Name) not found in global deployments configuration" -Important
    }
  }
}

Get-Versions

if ($Cleanup) {
  Cleanup-Resources
}

if ($UpdateBaseImages) { Update-BaseImages }

if (-not $SkipGPUCheck) {
  $gpuCheckOutput = & .\gpu-check.ps1 *>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Log "GPU check failed. Output: $gpuCheckOutput" -Important
    exit 1
  }
  Write-Log "GPU check passed. Proceeding with the build and run process..." -Important
} else { Write-Log "GPU check skipped." -Important }

if ($RebuildImages -or $Cleanup) {
  $global:config.deployments | ForEach-Object { Build-Image $_ }
} elseif (-not $UpdateBaseImages) {
  $global:config.deployments | Where-Object { $_.dockerfile } | ForEach-Object { Build-Image $_ }
}

@('postgresPassword', 'supabaseAnonKey') | ForEach-Object {
  if (-not $global:secrets.$_) {
    $global:secrets.$_ = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | % {[char]$_})
  }
}

kubectl create secret generic supabase-secrets `
  --from-literal=postgres-password=$global:secrets.postgresPassword `
  --from-literal=supabase-anon-key=$global:secrets.supabaseAnonKey `
  --dry-run=client -o yaml | kubectl apply -f -

if ($null -eq $global:config.deployments -or $global:config.deployments.Count -eq 0) {
  Write-Log "Error: No deployments found in the configuration." -Important
  exit 1
}

Write-Log "Applying configurations..." -Important
$global:config.deployments | Sort-Object -Property deployOrder | ForEach-Object {
  Write-Log "Applying $($_.name) configuration..." -Important
  if (Test-Path $_.k8sConfig) {
    Replace-Placeholders $_.k8sConfig $_.placeholders
    $result = kubectl apply -f $_.k8sConfig 2>&1
    if ($LASTEXITCODE -ne 0) {
      Write-Log "Failed to apply $($_.name) configuration. Error: $result" -Important
    } else { 
      Write-Log "Successfully applied $($_.name) configuration" -Important
    }
  } else {
    Write-Log "Error: K8s config file not found: $($_.k8sConfig)" -Important
  }
}

Write-Log "Waiting for all pods to be ready..." -Important
$waitTimeout = 300
$startTime = Get-Date
while ((Get-Date) - $startTime -lt [TimeSpan]::FromSeconds($waitTimeout)) {
  $nonReadyDeployments = Get-NonReadyDeployments
  if ($nonReadyDeployments.Count -eq 0) {
    Write-Log "All deployments are ready." -Important
    break
  }
  foreach ($deployment in $nonReadyDeployments) {
    $podStatus = kubectl get pods -l app=$($deployment.Name) -o jsonpath='{.items[0].status.phase}'
    Write-Log "Deployment $($deployment.Name) is not ready. Ready: $($deployment.ReadyReplicas)/$($deployment.TotalReplicas)" -Important
    Write-Log "Conditions: $($deployment.Conditions -join ', ')" -Important
    Write-Log "Pod status: $podStatus" -Important
    $podLogs = kubectl logs -l app=$($deployment.Name) --tail=10 2>&1
    if ($podLogs -match 'Error:|Exception:') {
      Write-Log "Error Logs for $($deployment.Name): $podLogs" -Important
    }
  }
  Start-Sleep -Seconds 10
}

if ((Get-Date) - $startTime -ge [TimeSpan]::FromSeconds($waitTimeout)) {
  Write-Log "Not all pods are ready after $waitTimeout seconds." -Important
  Update-NonReadyDeployments
}

Write-Log "Deployment completed. Current status:" -Important
kubectl get all

$global:config.deployments | Where-Object { $_.port } | ForEach-Object {
  Write-Log "- $($_.name): http://localhost:$($_.port)" -Important
}

Write-Log "Script execution completed successfully." -Important