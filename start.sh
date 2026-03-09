#!/bin/bash

# Gonka Ansible Deployment Script
# Interactive menu runner for playbooks

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if ! command -v ansible-playbook &> /dev/null; then
    error "Ansible is not installed. Install it with: pip install ansible"
    exit 1
fi

if [ ! -f "inventory/hosts.yml" ]; then
    warn "inventory/hosts.yml not found. Copy from inventory/hosts.example and edit it."
fi

if [ ! -f "inventory/group_vars/all" ]; then
    warn "inventory/group_vars/all not found. Copy from inventory/group_vars/all.example and edit it."
fi

show_menu() {
    echo ""
    echo "=========================================="
    echo "  Gonka Ansible Deployment"
    echo "=========================================="
    echo ""
    echo "Choose an action:"
    echo ""
    echo "  Checks:"
    echo "    1 - Check Network nodes"
    echo "    2 - Check setup"
    echo "    3 - Ping all hosts"
    echo "    4 - Stop inference"
    echo "    5 - Check ML nodes (POC)"
    echo "    9 - Check Network nodes + send status to Telegram"
    echo ""
    echo "  Deploy Network Nodes (node_net_deploy):"
    echo "    10 - Deploy Network nodes"
    echo "    11 - Register Network nodes"
    echo "    12 - Launch Network nodes"
    echo "    13 - Backup Network nodes"
    echo ""
    echo "  Deploy ML Nodes (node_ml_deploy):"
    echo "    20 - Deploy ML nodes"
    echo "    21 - Restart ML nodes"
    echo ""
    echo "------------------------------------------"
    echo "    0 - Exit"
    echo ""
    read -p "Your choice: " choice
}

run_playbook() {
    local playbook=$1
    local description=$2
    
    info "Running: $description"
    info "Playbook: $playbook"
    echo ""
    
    if ansible-playbook "$playbook"; then
        info "Done: $description completed successfully"
        return 0
    else
        error "Failed: $description"
        return 1
    fi
}

while true; do
    show_menu
    
    case $choice in
        1)
            run_playbook "playbooks/network/check.yml" "Check Network nodes"
            ;;
        2)
            run_playbook "playbooks/common/check_setup.yml" "Check setup"
            ;;
        3)
            run_playbook "playbooks/common/ping.yml" "Ping all hosts"
            ;;
        4)
            run_playbook "playbooks/ml/stop_inference.yml" "Stop inference"
            ;;
        5)
            run_playbook "playbooks/ml/check_poc.yml" "Check ML nodes (POC)"
            ;;
        9)
            run_playbook "playbooks/network/check_with_telegram.yml" "Check Network nodes + send status to Telegram"
            ;;
        10)
            run_playbook "playbooks/network/deploy.yml" "Deploy Network nodes"
            ;;
        11)
            run_playbook "playbooks/network/register.yml" "Register Network nodes"
            ;;
        12)
            run_playbook "playbooks/network/launch.yml" "Launch Network nodes"
            ;;
        13)
            run_playbook "playbooks/network/backup_network_node.yml" "Backup Network nodes"
            ;;
        20)
            run_playbook "playbooks/ml/deploy.yml" "Deploy ML nodes"
            ;;
        21)
            run_playbook "playbooks/ml/restart.yml" "Restart ML nodes"
            ;;
        0)
            info "Exiting..."
            exit 0
            ;;
        *)
            error "Invalid choice. Please try again."
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
