# Contributing to Gonka Ansible

Thank you for considering contributing to this project! Here are a few guidelines to help things go smoothly.

## Reporting Issues

Open a GitHub issue describing the problem, the expected behavior, and steps to reproduce. Include relevant Ansible and OS versions.

## Submitting Changes

1. Fork the repository and create a feature branch from `main`.
2. Make your changes, keeping commits focused and well-described.
3. Run `ansible-lint` and `yamllint` before pushing — the CI pipeline checks both.
4. Open a pull request with a clear description of what changed and why.

## Code Style

- **Language**: Write all documentation (README, docs, commit messages) and code comments in **English**.
- Use 2-space indentation in YAML files.
- Follow [Ansible best practices](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html) for playbook and role structure.
- Name tasks descriptively (e.g., "Install Docker prerequisites" rather than "Step 1").
- Use `snake_case` for variable and file names.

## Security

**Never commit secrets.** Passwords, API tokens, private keys, and real host IPs belong in local configuration files that are listed in `.gitignore`:

- `inventory/hosts.yml`
- `inventory/group_vars/all`
- `inventory/group_vars/node*.yml`

Use the provided `.example` files as templates. If you accidentally commit sensitive data, notify the maintainers immediately.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
