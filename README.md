# n8n Setup (No Docker, Reverse Proxy, HTTPS-first)

This folder contains a practical, repeatable setup for installing n8n on a Linux
server when:

- you do not use Docker,
- the public TLS/HTTPS termination already exists on a main host,
- n8n is reached through a reverse proxy (main host -> instance) on port 80,
- the instance domain can change between environments.

Current default behavior assumes:

- n8n runs on the instance on `N8N_PORT` (default `5678`).
- the instance is only exposed via the main host proxy.
- external HTTPS is already valid due to an existing wildcard certificate on the
  main host.
- if your main host proxy forwards to instance port `80`, set `N8N_PORT=80`.

## 1) Prepare values

```bash
export N8N_INSTANCE_DOMAIN="your-instance.example.com"
export N8N_PORT="5678"
export N8N_USER="n8n"
export N8N_DATA_DIR="/var/lib/n8n"
```

Example for your domain:

```bash
export N8N_INSTANCE_DOMAIN="liven8nleonyo.sellsystems.agency"
export N8N_PORT="5678"
export N8N_USER="n8n"
export N8N_DATA_DIR="/var/lib/n8n"
```

Optional basic-auth:

```bash
export N8N_BASIC_AUTH_ACTIVE=true
export N8N_BASIC_AUTH_USER="admin"
export N8N_BASIC_AUTH_PASSWORD="$(openssl rand -base64 24)"
```

You can use any domain for each agent/instance later by only changing
`N8N_INSTANCE_DOMAIN`.

## 2) Install n8n on the instance

Run as root (or with `sudo`) on the instance:

```bash
cd /home/n8n
sudo ./scripts/install-n8n-no-docker.sh
```

If you cannot login directly from this chat environment, run from your admin machine:

```bash
cd /home/n8n
./scripts/provision-n8n-instance.sh root@65.109.64.152 \
  liven8nleonyo.sellsystems.agency 5678
```

If SSH requires a non-default key or port:

```bash
SSH_OPTS="-i ~/.ssh/id_rsa -p 2222"
export SSH_OPTS
./scripts/provision-n8n-instance.sh admin@65.109.64.152 \
  liven8nleonyo.sellsystems.agency 5678
```

If your SSH user is not `root`, replace it:

```bash
./scripts/provision-n8n-instance.sh deploy@65.109.64.152 \
  liven8nleonyo.sellsystems.agency 5678 deploy
```

### What the installer does

- installs OS dependencies and Node.js 20 LTS,
- installs n8n globally with npm,
- creates the dedicated `n8n` system user,
- writes `/etc/n8n/n8n.env` and `/etc/systemd/system/n8n.service`,
- enables + starts the `n8n` systemd service.
- sets `N8N_PROTOCOL=https` so generated links and webhooks remain HTTPS.

## 3) Reverse proxy expectation (main host)

Main host should proxy HTTPS to the instance (internal HTTP endpoint):

- Browser: `https://$N8N_INSTANCE_DOMAIN`
- Instance: `http://INSTANCE_IP:$N8N_PORT`
- SSL: managed only on main host (wildcard cert already in place).

Use `/home/n8n/templates/n8n-proxy-main-host.conf` as a starting point for the
main-host proxy config.

Render a filled copy (replace `INSTANCE_IP` with the internal IP of this n8n
VM):

```bash
./scripts/render-main-proxy-conf.sh \
  liven8nleonyo.sellsystems.agency \
  65.109.64.152 \
  5678 \
  /tmp/liven8n-leon-n8n.conf
```

On the main host, after confirming the backend IP and port, you can apply the
proxy directly:

```bash
sudo ./scripts/configure-main-nginx-proxy.sh \
  liven8nleonyo.sellsystems.agency \
  127.0.0.1 \
  5678
```

## 4) Environment variables used

The installer writes variables in `/etc/n8n/n8n.env`:

- `N8N_HOST=0.0.0.0`
- `N8N_LISTEN_ADDRESS=0.0.0.0`
- `N8N_PORT=$N8N_PORT`
- `N8N_PROTOCOL=https` (important for generated links in the n8n UI)
- `N8N_EDITOR_BASE_URL=https://$N8N_INSTANCE_DOMAIN`
- `WEBHOOK_URL=https://$N8N_INSTANCE_DOMAIN`
- `N8N_USER_FOLDER=$N8N_DATA_DIR`

If you keep n8n completely internal behind the main host, these settings keep
links and webhooks aligned with HTTPS.

## 5) Post-install checks

```bash
sudo systemctl status n8n --no-pager
sudo journalctl -u n8n -n 120 --no-pager
curl -sS "http://127.0.0.1:${N8N_PORT:-5678}/healthz"
```

From your browser:

- open `https://$N8N_INSTANCE_DOMAIN`

From the edge host, use this check to confirm readiness:

```bash
./scripts/check-n8n-url.sh liven8nleonyo.sellsystems.agency
```

Successful readiness checks return:

- `HTTP/200` at `https://liven8nleonyo.sellsystems.agency/` with n8n HTML markers
- `HTTP/200` for `https://liven8nleonyo.sellsystems.agency/healthz`

## 6) Log installation issues locally

`notes/installation-log.md` is included for incident notes (command failures,
timeouts, permission fixes, proxy misroutes). Add entries as you go.

Use:

```bash
./scripts/log-issue.sh "Your issue summary and fix"
```

## 7) Future updates

Because this is a local git repo, you can commit updates after each install attempt:

```bash
git init
git add .
git commit -m "Initial n8n no-docker setup"
```

As issues appear, commit fixes to installer script, service env, and proxy notes.
