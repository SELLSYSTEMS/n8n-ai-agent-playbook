# n8n Installation Log

Use this file to record install attempts, failures, and resolutions.

## Template Entry

### 2026-05-30T00:00:00+00:00
- Issue: ...
- Root cause: ...
- Fix: ...
- Command used: ...
- Validation: ...


### 2026-05-30T10:03:08+00:00
- Initial readiness check for https://liven8nleonyo.sellsystems.agency failed: returns default Nginx welcome page; SSH to 65.109.64.152 blocked from this network (port 22 closed/public-key required). Root/Candidate users ubuntu/debian/admin/n8n/deploy also denied publickey.

### 2026-05-30T10:04:49+00:00
- Deployment blocker persists: no SSH/admin access or non-standard port was confirmed for 65.109.64.152 (port 22 closed/blocked in this runtime). HTTPS still serves nginx default page with 'Welcome to nginx!' and readiness check fails with default-page guard.

### 2026-05-30T10:06:14+00:00
- Attempted alternative access on 8443 shows LXD unauthenticated API; /1.0 endpoints return auth/403. /1.0/images is public empty. No management access path from here; still default Nginx page on 443.
