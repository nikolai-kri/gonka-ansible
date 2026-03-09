---
name: project_setup
description: Project Setup — first run: install Ansible, copy and fill inventory and group_vars. Use for initial project setup, onboarding, or when the user asks about setup, installation, or environment configuration.
---

# Project Setup

This skill guides you through the **Quick Start** in the project [README](../../../README.md#quick-start). Use it to set up the project correctly: install Ansible, copy and fill inventory and group_vars step by step, then verify with the setup check. Follow the steps below and help the user fill in every required value.

## When to use

- First clone of the repository or setup on a new machine
- Questions about "how to run", "how to configure", "what to copy"
- Errors due to missing `inventory/hosts.yml` or `inventory/group_vars/all`

## Steps

### 1. Install Ansible

```bash
pip install ansible
```

Verify: `ansible-playbook --version`

### 2. Copy example files and edit (inventory + global vars)

- Copy and edit:
  ```bash
  cp inventory/hosts.example inventory/hosts.yml
  cp inventory/group_vars/all.example inventory/group_vars/all
  ```
- **inventory/hosts.yml**: define hosts in `network_node` and `ml_node` with `ansible_host`; for ML hosts add `inference_node_ip` (prefer private/local address). Add groups `node_net_deploy`, `node_ml_deploy` as needed, and account groups if using per-node vars. Use `inventory/hosts.example` as structure reference.
- **inventory/group_vars/all**: set at minimum `ansible_user`, `ansible_ssh_private_key_file`. Optionally: `keyring_password`, `seed_host`, RPC/dashboard URLs, `telegram_bot_token`, `telegram_chat_id`.
- Do not commit these files (they are in .gitignore).

### 3. Per-node variables (if needed)

- For each node: copy **inventory/group_vars/node.example** → **inventory/group_vars/nodeN.yml** (e.g. node1.yml, node2.yml):
  ```bash
  cp inventory/group_vars/node.example inventory/group_vars/node1.yml
  ```
- Fill in: `account_name`, `host`, `poc_callback_url`, `account_address`, `account_pubkey`. Optionally override `telegram_chat_id` per node.
- Do not commit **inventory/group_vars/node*** files (except *.example).

### 4. Run playbooks (menu or direct)

- Recommended: run **./start.sh** and pick an option by number (deploy, check setup, ping, etc.).
- Or run playbooks directly, e.g. deploy: `playbooks/ml/deploy.yml`, `playbooks/network/deploy.yml`; checks: `playbooks/network/check.yml`, `playbooks/ml/check_poc.yml`.

### 5. Verify setup (nodes)

- Verify connectivity to nodes: **./start.sh** → option **3** (Ping all hosts), or:
  ```bash
  ansible-playbook playbooks/common/ping.yml
  ```
- Optionally run **./start.sh** → option **2** (Check setup) or `ansible-playbook playbooks/common/check_setup.yml` for a fuller check.

## Project configuration

- **ansible.cfg**: inventory = `./inventory/hosts.yml`, roles_path = `./roles`
- Run playbooks via menu: **./start.sh**
- Logs and backups: **logs/**, **backup/** — in .gitignore

## Do not commit

- inventory/hosts.yml, inventory/hosts
- inventory/group_vars/* (except *.example)
- inventory/host_vars/
- .vault_pass, .vault_pass.txt
- backup/, logs/, local/, .env

## Quick checklist

When reporting setup status, output a table with emoji: ✅ — done, ❌ — not done.

| Step | Status |
|------|--------|
| 1. Ansible installed | ✅ / ❌ |
| 2. inventory/hosts.yml created from hosts.example and filled in | ✅ / ❌ |
| 3. inventory/group_vars/all created from all.example (ansible_user, key) | ✅ / ❌ |
| 4. If needed: group_vars/nodeN.yml from node.example | ✅ / ❌ |
| 5. playbooks/common/ping.yml run successfully (nodes reachable) | ✅ / ❌ |

Checklist for the user:

- [ ] Ansible installed
- [ ] inventory/hosts.yml created from hosts.example and filled in
- [ ] inventory/group_vars/all created from all.example with ansible_user and key set
- [ ] If needed, inventory/group_vars/nodeN.yml created from node.example
- [ ] playbooks/common/ping.yml run successfully (nodes reachable)
