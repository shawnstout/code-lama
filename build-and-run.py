import os
import subprocess

# Function for logging
def write_log(message, important=False):
    log_message = f"IMPORTANT: {message}" if important else message
    print(log_message)

write_log("Python script initialized.", important=True)

# Function to execute shell commands
def execute_command(command):
    process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate()
    if process.returncode != 0:
        write_log(f"Error executing command: {stderr.decode('utf-8')}", important=True)
    else:
        write_log(stdout.decode('utf-8'))

# Example command execution (replace with actual commands)
execute_command('kubectl get pods')
write_log("Kubernetes command executed.", important=True)

# Function to handle deployment configurations
def apply_kubernetes_config(deployment_config):
    write_log(f"Applying {deployment_config['name']} configuration...", important=True)
    if os.path.exists(deployment_config['k8sConfig']):
        result, error = execute_command(f"kubectl apply -f {deployment_config['k8sConfig']}")
        if error:
            write_log(f"Failed to apply {deployment_config['name']} configuration. Error: {error}", important=True)
        else:
            write_log(f"Successfully applied {deployment_config['name']} configuration", important=True)
    else:
        write_log(f"Error: K8s config file not found: {deployment_config['k8sConfig']}", important=True)

# Example configurations to apply
configurations = [
    {'name': 'agentk-deployment', 'k8sConfig': 'deploy-agentk.yaml'},
    {'name': 'agentk-dockerfile', 'k8sConfig': 'agentk.Dockerfile'}
]

# Apply all configurations
for config in configurations:
    apply_kubernetes_config(config)
