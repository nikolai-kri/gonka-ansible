# network_report

Gathers status from a Gonka network node (RPC status, admin report, nodes list, disk space), sets **`has_error`** and **`report_message`** (plain text), and optionally prints the report to the console. Use this role before `telegram_notification` when you want to send the same data to Telegram.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `network_report_output` | `true` | Whether to print the plain report at the end. |
| `nvme_dir` | (from inventory) | Path to the NVMe mount used by the node. |

## Registered / Set Facts

The role sets:

- **`has_error`** — true if any of the status/admin/nodes requests failed or returned an error.
- **`report_message`** — plain-text report (from `templates/report_message_plain.j2`).
- **`network_node_status`**, **`network_node_response`**, **`network_node_nodes`**, **`disk_space_info`**, **`project_dir_stat`** — raw data for other roles (e.g. `telegram_notification` templates).

## Example

```yaml
- hosts: network_node
  roles:
    - network_report
```

With Telegram:

```yaml
- hosts: network_node
  tasks:
    - include_role:
        name: network_report
    - include_role:
        name: telegram_notification
```

## License

MIT-0
