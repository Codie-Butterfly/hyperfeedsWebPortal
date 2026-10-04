# Hyperfeeds staff web portal

Flutter desktop web portal for Customer Service, Branch Managers and Main Managers.
Source copied from the existing Hyperfeeds app; subsequent portal edits belong in this repository.

## Local build

Use Flutter 3.41.9. Run `flutter pub get`, `flutter test`, then
`flutter build web --release --pwa-strategy=none`.

## GitHub Actions deployment

Pushes to main test and build the portal and save a downloadable web artifact.
Deployment is disabled until the repository variable `DEPLOY_ENABLED` is `true`.
Configure repository Actions secrets (reuse the backend values):

- `DOCKER_USERNAME`, `DOCKER_PASSWORD`
- `SERVER_IP`, `SCP_USERNAME`, `SCP_PASSWORD`
- `SSH_KNOWN_HOSTS`: trusted VPS SSH host key entry, verified against the server fingerprint.

The production job publishes an immutable Docker Hub image and deploys to the existing
VPS Docker network `hyperfeeds-network`. Nginx proxies `/api/` to `api:8080`.
The backend must already be running on that network. Docker access uses sudo,
matching the backend workflow.

The portal listens on VPS loopback `127.0.0.1:8091`. Configure the VPS HTTPS reverse
proxy for the confirmed IP address `62.171.128.245` to forward to this address and preserve Host,
X-Forwarded-For and X-Forwarded-Proto. HTTPS is needed for browser secure storage.
IP certificate and TLS setup must be completed before enabling production deployment.
This workflow does not modify the backend or database Compose project.

After configuring secrets and HTTPS, set `DEPLOY_ENABLED=true` and run the workflow
from Actions. Later pushes to main deploy automatically. The job verifies both
portal and proxied API health. To roll back, redeploy a previous commit using its
immutable image tag; no database changes are made by this portal deployment.

## IP-only HTTPS setup

Target portal address: `https://62.171.128.245/#/employee-login`.
`deploy/vps-ip-https.conf` is a host Nginx template, not installed by Actions.
Inspect existing port 80/443 listeners and IP virtual hosts before installing it;
do not replace an existing Imba virtual host. Adapt the template to the actual
reverse proxy if the VPS does not use host Nginx.

For host Nginx, first enable only the HTTP server block and create
`/var/www/letsencrypt`. Port 80 must be reachable for the ACME challenge.
With Certbot 5.4 or newer, request the IP certificate:

```sh
sudo certbot certonly --preferred-profile shortlived --webroot \
  --webroot-path /var/www/letsencrypt --ip-address 62.171.128.245 \
  --deploy-hook 'nginx -t && systemctl reload nginx'
```

Complete the interactive certificate account setup. Then enable the TLS block,
run `sudo nginx -t`, and reload Nginx. Ensure the Certbot renewal timer is enabled
and verify renewal with `sudo certbot renew --dry-run`. IP certificates last only
six days, so automated renewal and the Nginx reload hook are required.

Reference: https://letsencrypt.org/2026/03/11/shorter-certs-certbot/
