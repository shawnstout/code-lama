$ErrorActionPreference = "Continue"

Write-Host "Starting cleanup process..."

function Invoke-CleanupCommand {
    param (
        [string]$Command,
        [string]$Description
    )
    
    Write-Host $Description
    $output = Invoke-Expression -Command $Command 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Warning: $Description failed with exit code $LASTEXITCODE"
        Write-Host $output
    }
}

try {
    # Remove Kubernetes resources
    Invoke-CleanupCommand -Command "kubectl delete -f kubernetes-deployment.yaml --ignore-not-found" -Description "Removing resources defined in kubernetes-deployment.yaml"
    
    # Remove Supabase resources
    Invoke-CleanupCommand -Command "kubectl delete secret supabase-secrets --ignore-not-found" -Description "Removing Supabase secrets"
    Invoke-CleanupCommand -Command "docker-compose -f C:\Github\supabase\docker\docker-compose.yml down -v" -Description "Stopping and removing Supabase containers"
    
    # Remove RabbitMQ cluster
    Invoke-CleanupCommand -Command "kubectl delete rabbitmqcluster rabbitmq-cluster --ignore-not-found" -Description "Removing RabbitMQ cluster"
    
    # Remove RabbitMQ Cluster Operator
    Invoke-CleanupCommand -Command "kubectl delete -f https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml --ignore-not-found" -Description "Removing RabbitMQ Cluster Operator"
    
    # Remove n8n deployment, service, and workflow
    Invoke-CleanupCommand -Command "kubectl delete deployment n8n --ignore-not-found" -Description "Removing n8n deployment"
    Invoke-CleanupCommand -Command "kubectl delete service n8n --ignore-not-found" -Description "Removing n8n service"
    Invoke-CleanupCommand -Command "kubectl delete configmap n8n-workflow --ignore-not-found" -Description "Removing n8n workflow ConfigMap"
    
    # Remove all other Kubernetes resources
    Invoke-CleanupCommand -Command "kubectl delete all --all --ignore-not-found" -Description "Removing all Kubernetes resources"
    Invoke-CleanupCommand -Command "kubectl delete pvc --all --ignore-not-found" -Description "Removing persistent volume claims"
    Invoke-CleanupCommand -Command "kubectl delete pv --all --ignore-not-found" -Description "Removing persistent volumes"
    Invoke-CleanupCommand -Command "kubectl delete configmap --all --ignore-not-found" -Description "Removing config maps"
    Invoke-CleanupCommand -Command "kubectl delete secret --all --ignore-not-found" -Description "Removing secrets"
    Invoke-CleanupCommand -Command "kubectl delete ingress --all --ignore-not-found" -Description "Removing ingresses"

    # Remove Docker images
    Invoke-CleanupCommand -Command "docker rmi -f master-ai:latest worker-ai:latest" -Description "Removing Docker images"

    # Clean up Docker system
    Invoke-CleanupCommand -Command "docker system prune -af --volumes" -Description "Cleaning up Docker system"

    Write-Host "Cleanup completed successfully."
}
catch {
    Write-Host "An error occurred during cleanup:"
    Write-Host $_.Exception.Message
    Write-Host "Stack trace:"
    Write-Host $_.ScriptStackTrace
    exit 1
}