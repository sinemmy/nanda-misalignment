#!/bin/bash
# Helper script to attach to running experiment tmux session
set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Get script directory and project root
readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
readonly VAST_IP="${1:-}"
readonly VAST_PORT="${2:-22}"

usage() {
    cat << EOF
Usage: $0 <ip> <port>

Attach to a running experiment tmux session on vast.ai

Arguments:
  ip:   vast.ai instance IP address
  port: vast.ai SSH port

Example:
  $0 123.45.67.89 12345

Tmux commands once attached:
  Ctrl-b d     - Detach from session (experiments continue running)
  Ctrl-b [     - Enter scroll mode (use arrows/PgUp/PgDn, q to exit)
  Ctrl-c       - Stop the current experiment (if needed)

EOF
    exit 1
}

main() {
    [[ $# -lt 2 ]] && usage
    
    echo -e "${GREEN}Connecting to experiment session on vast.ai...${NC}"
    echo "Instance: $VAST_IP:$VAST_PORT"
    echo
    
    # Load SSH key if available
    SSH_OPTS=""
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        source "$PROJECT_ROOT/.env"
        if [[ -n "${SSH_KEY_PATH:-}" ]]; then
            SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"
            if [[ -f "$SSH_KEY_PATH" ]]; then
                SSH_OPTS="-i $SSH_KEY_PATH"
            fi
        fi
    fi
    
    # Check if session exists
    echo -e "${YELLOW}Checking for tmux session...${NC}"
    if ssh ${SSH_OPTS:-} -o StrictHostKeyChecking=no -p "$VAST_PORT" "root@$VAST_IP" \
        "tmux has-session -t misalignment_exp 2>/dev/null"; then
        
        echo -e "${GREEN}Session found! Attaching...${NC}"
        echo -e "${YELLOW}Press Ctrl-b d to detach and leave experiments running${NC}"
        echo
        
        # Attach to tmux session
        ssh ${SSH_OPTS:-} -o StrictHostKeyChecking=no -p "$VAST_PORT" "root@$VAST_IP" \
            -t "tmux attach-session -t misalignment_exp"
    else
        echo -e "${RED}No experiment session found.${NC}"
        echo "The session may have completed or not been started yet."
        echo
        echo "To start experiments, run:"
        echo "  ./deploy/deploy_run_terminate.sh initial $VAST_IP $VAST_PORT"
    fi
}

main "$@"