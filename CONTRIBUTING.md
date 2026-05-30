# Contributing

Thank you for helping improve this playbook.

## Scope

This repository is meant to be reusable across many n8n instances and AI agents. Keep edits architecture-safe:

- Preserve the contract: main host TLS termination, proxy to instance port `80`.
- Keep `N8N_PUBLIC_DOMAIN` as the only required instance-specific value.
- Do not introduce per-instance hardcoded domains or instance IPs in global scripts.

## Suggested workflow

1. Make your change in a dedicated branch.
2. Keep shell scripts POSIX-safe and shellcheck-friendly.
3. Validate any changes manually on a staging instance before merging.
4. Update `README.md` and `AGENTS.md` whenever deployment behavior changes.

## Script editing rules

- Prefer idempotent commands.
- Keep default behavior production-safe (no destructive actions unless explicitly requested).
- Add comments when making behavior assumptions.

## Review checklist

- [ ] No new per-instance hardcoded values introduced.
- [ ] `N8N_PUBLIC_DOMAIN` remains the primary external input.
- [ ] Instance remains non-Docker and port 80 based.
- [ ] README reflects behavior changes.
