# Reusable Operations Guide (AI Agent Contract)

## Deployment contract

All deployments follow the same structure:

- One required external variable: `<N8N_PUBLIC_DOMAIN>`.
- Main host proxy target is always `http://<instance_private_ip>:80`.
- Main host owns HTTPS, instance serves plain HTTP.

## Modes for automation

- `install`: run `scripts/install-n8n-no-docker.sh` on the instance.
- `proxy`: run main-host proxy config scripts with domain + private IP.
- `verify`: run remote and public endpoint checks.
- `full`: install + proxy + verify.

## What each mode requires

| Mode | Inputs | Output |
| --- | --- | --- |
| install | `N8N_PUBLIC_DOMAIN`, target instance shell access | systemd-managed n8n service on port 80 |
| proxy | `N8N_PUBLIC_DOMAIN`, `INSTANCE_PRIVATE_IP` | main-host nginx route for `https://domain` |
| verify | `SSH_TARGET`, `N8N_PUBLIC_DOMAIN` | service status + public URL result |
| full | `SSH_TARGET`, `N8N_PUBLIC_DOMAIN`, `INSTANCE_PRIVATE_IP` | completed, validated deployment |

## Failure triage quick steps

1. Confirm instance SSH reachability.
2. Run `./scripts/verify-remote-instance.sh <SSH_TARGET> <N8N_PUBLIC_DOMAIN>`.
3. Confirm main host points to correct private IP on port 80.
4. Run `./scripts/check-n8n-url.sh <N8N_PUBLIC_DOMAIN>` from control context.

## Safe extension rules

- Add support flags in scripts only if defaults keep the same architecture.
- Keep scripts readable and commented around non-obvious decisions.
- Add a documentation line in this file for any changed flow.
