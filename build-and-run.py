import os
import subprocess
from typing import Dict
import traceback

# Function for logging
def write_log(message, important=False):
    log_message = f"IMPORTANT: {message}" if important else message
    print(log_message)

write_log("Python script initialized.", important=True)

# Function to execute shell commands
def execute_command(command):
    try:
        process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = process.communicate()
        if process.returncode != 0:
            error_message = stderr.decode('utf-8')
            write_log(f"Error executing command: {error_message}", important=True)
            print(f"Error occurred on line {traceback.extract_stack()[-1][1]}: {error_message.strip()}")
            raise subprocess.CalledProcessError(process.returncode, command)
        else:
            write_log(stdout.decode('utf-8'))
            return stdout.decode('utf-8')
    except subprocess.CalledProcessError as e:
        write_log(f"Error executing command: {e}", important=True)
        print(f"Error occurred on line {traceback.extract_stack()[-1][1]}: {e}")
        raise e

# Function to apply Kubernetes configurations
def apply_kubernetes_config(deployment_config: Dict[str, str]):
    write_log(f"Applying {deployment_config['name']} configuration...", important=True)
    if os.path.exists(deployment_config['k8sConfig']):
        try:
            result = execute_command(f"kubectl apply -f {deployment_config['k8sConfig']}")
            write_log(f"Successfully applied {deployment_config['name']} configuration", important=True)
        except (subprocess.CalledProcessError, FileNotFoundError) as e:
            write_log(f"Error applying {deployment_config['name']} configuration: {str(e)}", important=True)
            print(f"Error occurred on line {traceback.extract_stack()[-1][1]}: {str(e).strip()}")
            raise e
    else:
        error_message = f"Error: K8s config file not found: {deployment_config['k8sConfig']}"
        write_log(error_message, important=True)
        print(f"Error occurred on line {traceback.extract_stack()[-1][1]}: {error_message.strip()}")
        raise FileNotFoundError(error_message)

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
