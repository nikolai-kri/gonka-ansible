# Gonka Ansible Deployment

Ansible playbooks and roles for deploying and managing ML nodes and network nodes in the Gonka infrastructure. The deployment flow follows the [Gonka Host Quickstart](https://gonka.ai/host/quickstart/).

## What you can do

- **Deploy Network and ML nodes separately** — Network nodes and ML nodes can be deployed on different hosts.
- **Register nodes** — Register hosts and complete key setup.
- **Collect reports** — Run network status checks and get a plain-text report (height, disk, issues, recommendations, ML nodes list).
- **Send health checks to Telegram** — Check node status and send the report to a Telegram chat.
- **Menu runner** — Use `./start.sh` for a simple interactive menu without typing full `ansible-playbook` commands.

## License

This project is licensed under the [MIT License](LICENSE).

## Prerequisites

- Ansible on your control machine
- SSH access to target nodes
- Python 3 on target nodes

## Set up with AI (prompt)

In an AI assistant (e.g. Cursor or Claude) that has access to this repo, you can use the **Project Setup** skill to get step-by-step setup. Clone the repo, then paste a prompt like:

> Clone or open **https://github.com/nikolai-kri/gonka-ansible**. Use the Project Setup skill to deploy and configure this project: install Ansible, copy and fill inventory and group_vars (hosts, all, per-node), then verify connectivity with ping. Walk me through each step and help me fill in all required values.

The skill (`.claude/skills/project_setup/skill.md`) will guide you through the same steps as the Quick Start below.

## Quick Start

For step-by-step guidance and help filling in all required values, use the **Project Setup** skill (`.claude/skills/project_setup/skill.md`) — it walks through the same steps and helps you configure the project correctly.

### 1. Copy example files and edit

Inventory and secrets are not committed. Copy the examples and edit:

```bash
cp inventory/hosts.example inventory/hosts.yml
cp inventory/group_vars/all.example inventory/group_vars/all
# Edit inventory/hosts.yml with your host IPs and groups
# Edit inventory/group_vars/all (SSH key path, optional Telegram, keyring, seed_host)
```

Do not commit `inventory/hosts.yml`, `inventory/group_vars/all`, or node-specific `group_vars/node*` files—they may contain secrets and private IPs. The `backup/` directory (if used) is in `.gitignore`.

### 2. Add per-node variables

For each node, copy the example and edit:

```bash
cp inventory/group_vars/node.example inventory/group_vars/node1.yml
# Repeat for node2.yml, node3, etc.; edit account_name, host, poc_callback_url, account_address, account_pubkey
```

### 3. Configure inventory

Edit `inventory/hosts.yml`: define hosts in `network_node` and `ml_node` groups with `ansible_host` (and `inference_node_ip` for ML nodes). Add deployment groups `node_net_deploy`, `node_ml_deploy` as needed, and account groups if you use per-account vars. See `inventory/hosts.example` for structure.

### 4. Run playbooks

Start the menu and pick a playbook by number:

```bash
./start.sh
```

Or run playbooks directly:

```bash
# Deploy
ansible-playbook playbooks/ml/deploy.yml
ansible-playbook playbooks/network/deploy.yml

# Checks
ansible-playbook playbooks/network/check.yml
ansible-playbook playbooks/ml/check_poc.yml

# Other
ansible-playbook playbooks/network/register.yml
ansible-playbook playbooks/network/launch.yml
ansible-playbook playbooks/ml/restart.yml
ansible-playbook playbooks/ml/stop_inference.yml
ansible-playbook playbooks/common/ping.yml
ansible-playbook playbooks/common/check_setup.yml
```

## Playbooks

| Category | Playbook | Description |
|----------|----------|-------------|
| ML | `playbooks/ml/deploy.yml` | Deploy ML nodes |
| ML | `playbooks/ml/restart.yml` | Restart ML nodes |
| ML | `playbooks/ml/check_poc.yml` | Check Proof-of-Compute setup |
| ML | `playbooks/ml/stop_inference.yml` | Stop inference |
| Network | `playbooks/network/deploy.yml` | Deploy network nodes |
| Network | `playbooks/network/launch.yml` | Launch network nodes |
| Network | `playbooks/network/register.yml` | Register nodes |
| Network | `playbooks/network/check.yml` | Check network node status |
| Network | `playbooks/network/check_with_telegram.yml` | Check and send status to Telegram |
| Network | `playbooks/network/delete_default_node.yml` | Delete default node |
| Common | `playbooks/common/ping.yml` | Ping hosts |
| Common | `playbooks/common/check_setup.yml` | Check setup |

## Project structure

```
.
├── ansible.cfg
├── inventory/
│   ├── hosts.example       # Copy to hosts.yml and edit
│   └── group_vars/
│       ├── all.example    # Copy to all and edit
│       ├── node_example.yml # Template for node vars
│       ├── network_node   # Network node defaults
│       ├── ml_*           # ML group defaults
│       └── ...
├── playbooks/
│   ├── ml/
│   ├── network/
│   └── common/
├── roles/
│   ├── check/
│   ├── ml_node/
│   ├── network_node/
│   └── ...
├── local/                 # Your personal files (gitignored)
├── start.sh               # Menu runner (optional)
└── LICENSE
```

The `local/` directory is gitignored — use it for your own scripts, notes, or configs that should not be committed.

## Configuration

- **ansible.cfg**: inventory path `./inventory/hosts.yml`, roles path `./roles`, YAML output.
- **group_vars/all**: set `ansible_user`, `ansible_ssh_private_key_file`, and optionally `keyring_password`, `seed_host`, `telegram_bot_token`, `telegram_chat_id` (for `check_with_telegram.yml`).

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on reporting issues, submitting pull requests, and code style.

## Troubleshooting

- Ensure SSH keys and `ansible_ssh_private_key_file` in `group_vars/all` are correct.
- Verify connectivity: `ansible all -m ping`
- Confirm Python 3 is available on targets.
