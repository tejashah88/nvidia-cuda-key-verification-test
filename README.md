# nvidia-cuda-key-verification-test
Meant for https://github.com/osrf/rocker/issues/336.

Disclaimer: All source is created by Claude Sonnet 4.5.

## Instructions

```bash
# Generate the CUDA Key debug logs

# Example: ./run-cuda-debug.sh ubuntu:24.04
./run-cuda-debug.sh <base_image_in_docker>

# Print the diagnostic report
docker run --rm cuda-debug-temp /tmp/debug-cuda-keys.sh
```
