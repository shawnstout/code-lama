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
