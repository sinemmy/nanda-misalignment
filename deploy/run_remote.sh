#!/bin/bash
# Wrapper script to run commands on remote with SSH key from .env
set -euo pipefail

# Navigate to project root (parent of deploy directory)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Source .env to get SSH_KEY_PATH
if [[ ! -f ".env" ]]; then
    echo "Error: .env file not found in project root" >&2
    echo "Please create .env from .env.example and set SSH_KEY_PATH" >&2
    exit 1
fi

source .env

# Expand SSH_KEY_PATH if it starts with ~
SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"

# Validate SSH key exists
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo "Error: SSH key not found at: $SSH_KEY_PATH" >&2
    echo "Please ensure SSH_KEY_PATH in .env points to a valid SSH key" >&2
    exit 1
fi

# Get connection details
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <ip> <port> [command...]" >&2
    echo "Example: $0 123.45.67.89 12345 ls -la" >&2
    exit 1
fi

VAST_IP="${1}"
VAST_PORT="${2}"
shift 2

# Run command on remote with proper SSH options
ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    -i "$SSH_KEY_PATH" \
    -p "$VAST_PORT" \
    "root@$VAST_IP" \
    "$@"