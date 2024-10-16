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

# Function to build and push Docker images
def build_and_push_docker_images():
    write_log("Building and pushing Docker images...", important=True)

    try:
        # Build the AI API Docker image
        execute_command("docker build -t ai-api -f api.Dockerfile .")
        execute_command("docker push ai-api")
        write_log("AI API Docker image built and pushed successfully.", important=True)

        # Build the AI Worker Docker image
        execute_command("docker build -t ai-worker -f worker.Dockerfile .")
        execute_command("docker push ai-worker")
        write_log("AI Worker Docker image built and pushed successfully.", important=True)
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        write_log(f"Error building or pushing Docker images: {str(e)}", important=True)
        print(f"Error occurred on line {traceback.extract_stack()[-1][1]}: {str(e).strip()}")
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

# Function to delete Kubernetes deployments
def delete_kubernetes_deployments():
    write_log("Deleting existing Kubernetes deployments...", important=True)
    try:
        execute_command("kubectl delete deployment agentk")
        write_log("Existing agentk deployment deleted successfully.", important=True)
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        write_log(f"Error deleting existing deployments: {str(e)}", important=True)
        print(f"Error occurred on line {traceback.extract_stack()[-1][1]}: {str(e).strip()}")
        raise e

# Main function
def main():
    # Delete existing Kubernetes deployments
    delete_kubernetes_deployments()

    # Build and push Docker images
    build_and_push_docker_images()

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
import subprocess
import os
import yaml
import time
from typing import Dict

def write_log(message, important=False):
    """Write a message to the log file."""
    with open("logs/build-and-run.txt", "a") as log_file:
        if important:
            log_file.write("\n" + "=" * 50 + "\n")
        log_file.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} - {message}\n")
        if important:
            log_file.write("=" * 50 + "\n")
    print(message)

def execute_command(command):
    """Execute a shell command and return its output."""
    try:
        result = subprocess.run(command, check=True, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        write_log(f"Command executed successfully: {command}")
        return result.stdout
    except subprocess.CalledProcessError as e:
        write_log(f"Error executing command: {command}")
        write_log(f"Error output: {e.stderr}")
        raise

def build_and_push_docker_images():
    """Build and push Docker images for all components."""
    components = ["master", "worker", "agentk", "ai-api", "ai-worker"]
    for component in components:
        write_log(f"Building Docker image for {component}...", important=True)
        dockerfile_name = f"{component}.Dockerfile"
        if component in ["ai-api", "ai-worker", "agentk"]:
            dockerfile_name = f"{component}.Dockerfile"
        execute_command(f"docker build -t {component}:latest -f {dockerfile_name} .")
        write_log(f"Pushing Docker image for {component}...")
        execute_command(f"docker push {component}:latest")

def apply_kubernetes_config(deployment_config: Dict[str, str]):
    """Apply Kubernetes configurations."""
    for config_file, config_type in deployment_config.items():
        write_log(f"Applying {config_type} configuration: {config_file}", important=True)
        execute_command(f"kubectl apply -f {config_file}")

def delete_kubernetes_deployments():
    """Delete all Kubernetes deployments."""
    write_log("Deleting all Kubernetes deployments...", important=True)
    execute_command("kubectl delete deployments --all")

def main():
    # Ensure log directory exists
    os.makedirs("logs", exist_ok=True)

    write_log("Starting build and run process...", important=True)

    # Load configuration
    with open("config.yaml", "r") as config_file:
        config = yaml.safe_load(config_file)

    # Update requirements file names in Dockerfiles
    update_dockerfile_requirements()

    # Build and push Docker images
    build_and_push_docker_images()

    # Delete existing deployments
    delete_kubernetes_deployments()

    # Apply Kubernetes configurations
    apply_kubernetes_config(config["kubernetes_configs"])

    write_log("Build and run process completed successfully!", important=True)

def update_dockerfile_requirements():
    """Update requirements file names in Dockerfiles."""
    dockerfiles = ["ai-api.Dockerfile", "ai-worker.Dockerfile", "agentk.Dockerfile"]
    for dockerfile in dockerfiles:
        if os.path.exists(dockerfile):
            with open(dockerfile, "r") as f:
                content = f.read()
            updated_content = content.replace("requirements.txt", f"{dockerfile.split('.')[0]}-requirements.txt")
            with open(dockerfile, "w") as f:
                f.write(updated_content)
            write_log(f"Updated requirements file name in {dockerfile}")

if __name__ == "__main__":
    main()
