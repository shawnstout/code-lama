#!/bin/bash

# Check for NVIDIA GPU
if command -v nvidia-smi &> /dev/null
then
    echo "NVIDIA GPU found:"
    nvidia-smi
else
    echo "No NVIDIA GPU found. GPU-accelerated tasks will not be available."
fi
