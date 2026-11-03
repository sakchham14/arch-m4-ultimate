#!/bin/bash
# arch-ultimate.sh — universal dispatcher
# Detects host architecture and pulls the appropriate installer from GitHub.

set -uo pipefail

REPO="sakchham14/arch-m4-ultimate"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

ARCH="$(uname -m)"

case "$ARCH" in
    aarch64|arm64)
        SCRIPT="arch-ultimate-aarch64.sh"
        ;;
    x86_64|amd64)
        SCRIPT="arch-ultimate-x86_64.sh"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "Detected architecture: $ARCH"
echo "Fetching installer: $SCRIPT"

curl -fsSL "${BASE_URL}/${SCRIPT}" -o "/tmp/${SCRIPT}" || {
    echo "Failed to download $SCRIPT"
    exit 1
}
chmod +x "/tmp/${SCRIPT}"
exec "/tmp/${SCRIPT}" "$@"
EOF