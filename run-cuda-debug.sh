#!/bin/bash
set -e

# Script to run CUDA GPG key diagnostics on any base image

usage() {
    echo "Usage: $0 <base_image> [cuda_keyring_version]"
    echo ""
    echo "Runs comprehensive CUDA GPG key diagnostics to identify:"
    echo "  - Key presence and validity"
    echo "  - Key expiration status"
    echo "  - Repository signature verification"
    echo "  - APT configuration issues"
    echo ""
    echo "Examples:"
    echo "  $0 ubuntu:24.04"
    echo "  $0 ubuntu:22.04"
    echo ""
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

BASE_IMAGE="$1"
CUDA_KEYRING_VERSION="${2:-1.1-1}"

echo "======================================"
echo "CUDA GPG Key Debug Tool"
echo "======================================"
echo "Base Image:      $BASE_IMAGE"
echo "Keyring Version: $CUDA_KEYRING_VERSION"
echo ""
echo "This will:"
echo "1. Build a container from your base image"
echo "2. Install CUDA keyring (as rocker does)"
echo "3. Run diagnostics at each stage"
echo "4. Identify where the GPG error occurs"
echo ""
echo "Building..."
echo ""

# Build the debug image
docker build \
    --build-arg BASE_IMAGE="$BASE_IMAGE" \
    --build-arg CUDA_KEYRING_VERSION="$CUDA_KEYRING_VERSION" \
    -t cuda-debug-temp \
    -f Dockerfile.debug-cuda \
    . 2>&1 | tee /tmp/cuda-debug-build.log

BUILD_EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "======================================"
echo "Build Complete"
echo "======================================"

if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo "Status: SUCCESS"
    echo ""
    echo "The build completed successfully. This means:"
    echo "- CUDA keyring installed correctly"
    echo "- GPG keys are valid"
    echo "- apt-get update succeeded"
    echo ""
    echo "You can review the diagnostic output above."
    echo "To run diagnostics again:"
    echo "  docker run --rm cuda-debug-temp /tmp/debug-cuda-keys.sh"
else
    echo "Status: FAILED"
    echo ""
    echo "The build failed (matching your rocker error)."
    echo "Review the diagnostic output above to identify:"
    echo "  - Which stage failed"
    echo "  - Key expiration status"
    echo "  - Repository verification errors"
    echo "  - APT configuration issues"
    echo ""
    echo "Full build log saved to: /tmp/cuda-debug-build.log"
fi

echo ""
