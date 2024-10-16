# CodeLlama Deployment

This project contains the necessary files and scripts to deploy the CodeLlama system using Docker and Kubernetes.

## Files

- `build-and-run.ps1`: Main PowerShell script for building and running the deployment
- `config.yaml`: Configuration file for the deployment
- `ai-api-deployment.yaml`
- `ai-api-service.yaml`
- `ai-worker-deployment.yaml`
- `ai-worker-service.yaml`
- `postgres-deployment.yaml`
- `postgres-service.yaml`
- `supabase-deployment.yaml`
- `supabase-service.yaml`
- `Dockerfile.ai-api`
- `Dockerfile.ai-worker`

## Prerequisites

- Docker Desktop with Kubernetes enabled
- PowerShell
- NVIDIA GPU with CUDA support (for AI tasks)

## Usage

1. Ensure all configuration files are properly set up.
2. Run the `build-and-run.ps1` script with desired parameters:

   ```powershell
   .\build-and-run.ps1 [-SkipGPUCheck] [-UpdateBaseImages] [-Cleanup] [-RebuildImages]
   ```

3. The script will build necessary images, deploy to Kubernetes, and provide status updates.

## Configuration

Edit the `config.yaml` file to modify deployment settings, including image names, ports, and Kubernetes configurations.

## Troubleshooting

- Check the `logs` directory for build and deployment logs.
- Use `kubectl` commands to inspect the status of pods and services.
- Refer to the console output for real-time deployment status and any error messages.

## Notes

- The deployment uses GPU acceleration for AI tasks. Ensure your system has a compatible NVIDIA GPU.
- Secrets for PostgreSQL and Supabase are generated automatically if not provided as environment variables.
# AI Environment Build

This repository contains the necessary files and instructions to set up an AI environment using Docker and Kubernetes.

## Prerequisites

- Docker
- Kubernetes (minikube or a cloud-based solution)
- Python 3.9+

## Getting Started

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/ai-environment-build.git
   cd ai-environment-build
   ```

2. Build and run the Docker images:
   ```
   python build-and-run.py
   ```

3. Apply the Kubernetes configurations:
   ```
   kubectl apply -f k8s/
   ```

## Components

- Master AI
- Worker AI
- RabbitMQ
- Supabase
- n8n
- OpenWebUI

## Configuration

Edit the `config.yaml` file to customize your environment settings.

## Troubleshooting

If you encounter any issues, please check the `logs/build-and-run.txt` file for error messages.

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License

[MIT](https://choosealicense.com/licenses/mit/)
