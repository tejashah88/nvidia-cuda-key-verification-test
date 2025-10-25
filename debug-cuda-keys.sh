#!/bin/bash
# Comprehensive CUDA GPG Key Diagnostic Script
# Checks key presence, validity, expiration, and repository verification

set +e  # Don't exit on errors - we want to see all diagnostics

echo "======================================"
echo "CUDA GPG Key Diagnostics Report"
echo "======================================"
echo ""
date
echo ""

# Color codes (optional, keeping simple)
CHECK_MARK="[✓]"
CROSS_MARK="[✗]"
WARN_MARK="[!]"

# Key variables
KEYRING_PATH="/usr/share/keyrings/cuda-archive-keyring.gpg"
EXPECTED_KEY_ID="A4B469963BF863CC"
CUDA_REPO="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64"

echo "=== 1. Keyring File Check ==="
if [ -f "$KEYRING_PATH" ]; then
    echo "$CHECK_MARK Keyring file exists: $KEYRING_PATH"
    ls -lh "$KEYRING_PATH"
else
    echo "$CROSS_MARK Keyring file NOT found: $KEYRING_PATH"
    echo "    Looking for alternative locations..."
    find /usr/share/keyrings/ -name "*cuda*" -o -name "*nvidia*" 2>/dev/null || echo "    No CUDA/NVIDIA keyrings found"
fi
echo ""

echo "=== 2. GPG Key Content ==="
if [ -f "$KEYRING_PATH" ]; then
    echo "Listing keys in keyring..."
    gpg --no-default-keyring --keyring "$KEYRING_PATH" --list-keys --keyid-format LONG
    echo ""

    # Check for expected key
    if gpg --no-default-keyring --keyring "$KEYRING_PATH" --list-keys --keyid-format LONG | grep -q "$EXPECTED_KEY_ID"; then
        echo "$CHECK_MARK Expected key ID found: $EXPECTED_KEY_ID"
    else
        echo "$CROSS_MARK Expected key ID NOT found: $EXPECTED_KEY_ID"
        echo "    Available key IDs:"
        gpg --no-default-keyring --keyring "$KEYRING_PATH" --list-keys --keyid-format LONG | grep "pub" || echo "    No keys found"
    fi
else
    echo "$CROSS_MARK Cannot check key content - keyring file missing"
fi
echo ""

echo "=== 3. Key Expiration Check ==="
if [ -f "$KEYRING_PATH" ]; then
    echo "Checking key expiration dates..."
    gpg --no-default-keyring --keyring "$KEYRING_PATH" --list-keys --with-colons | \
    while IFS=: read -r type validity length algo keyid date expiry rest; do
        if [ "$type" = "pub" ]; then
            if [ -z "$expiry" ] || [ "$expiry" = "" ]; then
                echo "$CHECK_MARK Key $keyid: Never expires"
            else
                expiry_date=$(date -d "@$expiry" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Unknown")
                current_epoch=$(date +%s)
                if [ "$expiry" -gt "$current_epoch" ]; then
                    echo "$CHECK_MARK Key $keyid: Expires on $expiry_date (still valid)"
                else
                    echo "$CROSS_MARK Key $keyid: EXPIRED on $expiry_date"
                fi
            fi
        fi
    done
else
    echo "$CROSS_MARK Cannot check expiration - keyring file missing"
fi
echo ""

echo "=== 4. APT Sources Configuration ==="
echo "Checking CUDA repository configuration in APT sources..."
if [ -d "/etc/apt/sources.list.d" ]; then
    CUDA_SOURCES=$(find /etc/apt/sources.list.d/ -name "*cuda*" -o -name "*nvidia*" 2>/dev/null)
    if [ -n "$CUDA_SOURCES" ]; then
        for source in $CUDA_SOURCES; do
            echo "Found: $source"
            cat "$source"
            echo ""

            # Check if signed-by directive is present
            if grep -q "signed-by" "$source"; then
                echo "$CHECK_MARK Uses 'signed-by' directive (modern APT method)"
            else
                echo "$WARN_MARK No 'signed-by' directive (legacy APT method)"
                echo "    This may cause verification issues on newer systems"
            fi
            echo ""
        done
    else
        echo "$WARN_MARK No CUDA/NVIDIA sources found in /etc/apt/sources.list.d/"
        echo "    Checking main sources.list..."
        if grep -q "cuda" /etc/apt/sources.list 2>/dev/null; then
            echo "Found CUDA repo in /etc/apt/sources.list:"
            grep "cuda" /etc/apt/sources.list
        else
            echo "$CROSS_MARK No CUDA repository configured in APT"
        fi
    fi
else
    echo "$CROSS_MARK /etc/apt/sources.list.d/ directory not found"
fi
echo ""

echo "=== 5. Network Connectivity ==="
echo "Testing connection to CUDA repository..."
if command -v curl &> /dev/null; then
    if curl --connect-timeout 10 -s -I "$CUDA_REPO/InRelease" > /dev/null 2>&1; then
        echo "$CHECK_MARK CUDA repository is accessible: $CUDA_REPO"
    else
        echo "$CROSS_MARK Cannot reach CUDA repository: $CUDA_REPO"
        echo "    This may be a network issue or repository availability problem"
    fi
else
    echo "$WARN_MARK curl not available, skipping network test"
fi
echo ""

echo "=== 6. Repository InRelease Signature ==="
echo "Downloading and checking InRelease file signature..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1

if command -v wget &> /dev/null; then
    wget -q "$CUDA_REPO/InRelease" -O InRelease 2>/dev/null
    if [ -f "InRelease" ]; then
        echo "$CHECK_MARK Downloaded InRelease file"
        echo ""
        echo "InRelease signature info:"
        head -n 20 InRelease
        echo ""

        # Try to verify signature
        if [ -f "$KEYRING_PATH" ]; then
            echo "Attempting to verify signature with keyring..."
            if gpg --no-default-keyring --keyring "$KEYRING_PATH" --verify InRelease 2>&1; then
                echo "$CHECK_MARK Signature verification SUCCESSFUL"
            else
                echo "$CROSS_MARK Signature verification FAILED"
                echo "    This indicates the key cannot verify the repository"
            fi
        else
            echo "$WARN_MARK Cannot verify signature - keyring file missing"
        fi
    else
        echo "$CROSS_MARK Failed to download InRelease file"
    fi
else
    echo "$WARN_MARK wget not available, skipping InRelease download"
fi

cd - > /dev/null
rm -rf "$TEMP_DIR"
echo ""

echo "=== 7. Legacy APT Key Check ==="
echo "Checking for keys in legacy apt-key location..."
if command -v apt-key &> /dev/null; then
    echo "Legacy apt-key list:"
    apt-key list 2>/dev/null | grep -A 5 -i "cuda\|nvidia" || echo "    No CUDA/NVIDIA keys in legacy keyring"
else
    echo "$WARN_MARK apt-key command not available (expected on modern systems)"
fi
echo ""

echo "=== 8. System Information ==="
echo "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo "Architecture: $(uname -m)"
echo "Date: $(date)"
echo ""

echo "======================================"
echo "Diagnostic Report Complete"
echo "======================================"
echo ""
echo "Summary:"
echo "- If keyring exists but signature verification fails: Key may be corrupted or mismatched"
echo "- If key is expired: NVIDIA needs to update the key"
echo "- If signed-by directive missing: APT sources may need updating"
echo "- If network issues: Repository may be temporarily unavailable"
echo ""
