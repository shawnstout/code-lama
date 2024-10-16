import os
import subprocess
from typing import Dict

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
        raise subprocess.CalledProcessError(process.returncode, command)
    else:
        write_log(stdout.decode('utf-8'))
        return stdout.decode('utf-8')

# Function to apply Kubernetes configurations
def apply_kubernetes_config(deployment_config: Dict[str, str]):
    write_log(f"Applying {deployment_config['name']} configuration...", important=True)
    if os.path.exists(deployment_config['k8sConfig']):
        result = execute_command(f"kubectl apply -f {deployment_config['k8sConfig']}")
        write_log(f"Successfully applied {deployment_config['name']} configuration", important=True)
    else:
        write_log(f"Error: K8s config file not found: {deployment_config['k8sConfig']}", important=True)
        raise FileNotFoundError(f"K8s config file not found: {deployment_config['k8sConfig']}")

# Main function
def main():
    # Apply Kubernetes configurations
    configurations = [
        {'name': 'agentk-deployment', 'k8sConfig': 'deploy-agentk.yaml'},
        {'name': 'agentk-dockerfile', 'k8sConfig': 'agentk.Dockerfile'}
    ]

    for config in configurations:
        try:
            apply_kubernetes_config(config)
        except (subprocess.CalledProcessError, FileNotFoundError) as e:
            write_log(f"Error applying {config['name']} configuration: {str(e)}", important=True)
            continue

    write_log("Deployment process completed.", important=True)

if __name__ == "__main__":
    main()
