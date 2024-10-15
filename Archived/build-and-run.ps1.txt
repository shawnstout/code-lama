$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

Write-Verbose "Script started"

function Test-KubectlAvailable {
    try {
        $kubectlVersion = kubectl version --client
        Write-Verbose "kubectl version: $kubectlVersion"
        return $true
    }
    catch {
        Write-Error "kubectl is not available. Please ensure it's installed and in your PATH."
        return $false
    }
}

function Apply-KubernetesConfig {
    param ([string]$configFile)
    
    Write-Verbose "Applying ${configFile}..."
    $output = kubectl apply -f $configFile --validate=true
    Write-Verbose ($output -join "`n")
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to apply ${configFile}. Error: $($output -join "`n")"
    }
}

function Wait-ForDeployment {
    param (
        [string]$deploymentName,
        [int]$timeoutSeconds = 300
    )
    
    Write-Verbose "Waiting for ${deploymentName} to be ready (timeout: ${timeoutSeconds} seconds)..."
    $startTime = Get-Date
    
    while ($true) {
        $status = kubectl rollout status deployment/$deploymentName --timeout=10s
        Write-Verbose ($status -join "`n")
        
        if ($LASTEXITCODE -eq 0) {
            Write-Verbose "${deploymentName} is ready."
            return
        }
        
        if (((Get-Date) - $startTime).TotalSeconds -gt $timeoutSeconds) {
            throw "${deploymentName} failed to become ready within ${timeoutSeconds} seconds."
        }
        
        Start-Sleep -Seconds 10
    }
}

if (-not (Test-KubectlAvailable)) {
    throw "kubectl not available"
}

$deployments = @(
    "deploy-nfs-server.yaml",
	"deploy-master-ai.yaml",
    "deploy-worker-ai-70b.yaml",
    "deploy-worker-ai-34b.yaml",
    "deploy-openwebui.yaml",
    "deploy-n8n.yaml",
    "deploy-kubernetes.yaml"
)

foreach ($deployment in $deployments) {
    Write-Verbose "Processing ${deployment}"
    
    try {
        Apply-KubernetesConfig -configFile $deployment
        $deploymentName = ($deployment -split "-",2)[1] -replace '\.yaml$',''
        Wait-ForDeployment -deploymentName $deploymentName
        
        Write-Verbose "Current deployments after ${deployment}:"
        kubectl get deployments
        
        Write-Verbose "Current pods after ${deployment}:"
        kubectl get pods
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            $errorMessage = $_.Exception.Message
        } elseif ($_ -is [System.Array]) {
            $errorMessage = $_ -join "`n"
        }
        Write-Error "Error processing ${deployment}: $errorMessage"
        Write-Verbose "Deployments at time of error:"
        kubectl get deployments
        Write-Verbose "Pods at time of error:"
        kubectl get pods
        throw
    }
}

Write-Verbose "All deployments completed. Final status:"
kubectl get deployments
kubectl get pods
kubectl get services

Write-Verbose "Script execution completed."