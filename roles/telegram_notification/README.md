# telegram_notification

Sends a message to Telegram via the Bot API. You can pass a ready-made **`telegram_message`**, a **`telegram_template`** name, or **`has_error`** (role chooses the bundled template and renders it).

## Requirements

- `telegram_bot_token` and `telegram_chat_id` set in inventory (e.g. `inventory/group_vars/all`). Get the token from [@BotFather](https://t.me/BotFather), and the chat_id from `https://api.telegram.org/bot<TOKEN>/getUpdates`.
- Provide one of: **`telegram_message`** (ready text), **`telegram_template`** (template filename), or **`has_error`** (role picks `error_message_template.j2` vs `report_message_template.j2`).

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `telegram_message` | — | Ready-made text to send. |
| `telegram_template` | — | Template filename from the role’s `templates/`; the role renders it and sends. |
| `has_error` | — | When set, the role chooses the template: error vs report (see `telegram_error_template` / `telegram_report_template`). |
| `telegram_error_template` | `"error_message_template.j2"` | Template used when `has_error` is true. |
| `telegram_report_template` | `"report_message_template.j2"` | Template used when `has_error` is false. |
| `telegram_bot_token` | — | Bot token (usually from `group_vars/all`). |
| `telegram_chat_id` | — | Chat ID (usually from `group_vars/all` or per-host). |
| `telegram_parse_mode` | `"HTML"` | Telegram parse mode: `HTML` or `Markdown`. |

## Bundled templates

The role includes two templates for the network check use case:

- **`report_message_template.j2`** — status report (height, disk, links, issues, recommendations, ML nodes). Expects `network_node_status`, `network_node_response`, `network_node_nodes`, `disk_space_info`, `tracker_url`, `dashboard_url`, `account_address`, etc.
- **`error_message_template.j2`** — short error notice. Expects `inventory_hostname`, `ansible_host`, `ansible_date_time`.

Other playbooks can pass their own template names if the required variables are in scope when the role runs.

## Example: network check (role chooses template from `has_error`)

Set `has_error` in the playbook, then include the role. The role will choose the template, build the message, send it, and print the status.

```yaml
- hosts: network_node
  tasks:
    - name: Check for errors in reports
      set_fact:
        has_error: "{{ ... }}"
    - name: Send notification to Telegram
      include_role:
        name: telegram_notification
```

## Example: pass ready-made message

```yaml
- hosts: servers
  tasks:
    - set_fact:
        telegram_message: "Backup finished at {{ ansible_date_time.iso8601 }}"
    - include_role:
        name: telegram_notification
```

## License

MIT-0
