import subprocess

def main():
    try:
        # Check for NVIDIA GPU
        result = subprocess.run(['command', '-v', 'nvidia-smi'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode == 0:
            print("NVIDIA GPU found:")
            subprocess.run(['nvidia-smi'])
        else:
            print("No NVIDIA GPU found. GPU-accelerated tasks will not be available.")
    except subprocess.CalledProcessError as e:
        print(f"Error checking for GPU: {e}")

if __name__ == "__main__":
    main()
import torch
import subprocess

def main():
    print("Checking GPU availability...")
    
    if torch.cuda.is_available():
        print("CUDA is available!")
        print(f"CUDA version: {torch.version.cuda}")
        print(f"Number of GPUs: {torch.cuda.device_count()}")
        for i in range(torch.cuda.device_count()):
            print(f"GPU {i}: {torch.cuda.get_device_name(i)}")
        
        # Additional CUDA information
        print("\nAdditional CUDA Information:")
        try:
            nvcc_output = subprocess.check_output(["nvcc", "--version"]).decode("utf-8")
            print(nvcc_output)
        except subprocess.CalledProcessError:
            print("Unable to get NVCC version. Make sure CUDA is properly installed.")
        
        try:
            nvidia_smi_output = subprocess.check_output(["nvidia-smi"]).decode("utf-8")
            print(nvidia_smi_output)
        except subprocess.CalledProcessError:
            print("Unable to run nvidia-smi. Make sure NVIDIA drivers are properly installed.")
    else:
        print("CUDA is not available. GPU acceleration will not be possible.")

if __name__ == "__main__":
    main()
