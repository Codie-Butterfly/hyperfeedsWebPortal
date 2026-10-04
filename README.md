# Hyperfeeds staff web portal

Flutter desktop web portal for Customer Service, Branch Managers and Main Managers.
Source copied from the existing Hyperfeeds app; subsequent portal edits belong in this repository.

## Local build

Use Flutter 3.41.9. Run `flutter pub get`, `flutter test`, then
`flutter build web --release --pwa-strategy=none`.

## GitHub Actions deployment

Pushes to main test and build the portal and save a downloadable web artifact.
Deployment runs automatically. Set the repository variable `DEPLOY_ENABLED=false` to pause deployments.
Configure repository Actions secrets (reuse the backend values):

- `DOCKER_USERNAME`, `DOCKER_PASSWORD`
- `SERVER_IP`, `SCP_USERNAME`, `SCP_PASSWORD`
- `SSH_KNOWN_HOSTS`: trusted VPS SSH host key entry, verified against the server fingerprint.

The production job publishes an immutable Docker Hub image and deploys to the existing
VPS Docker network `hyperfeeds-network`. Nginx proxies `/api/` to `api:8080`.
The backend must already be running on that network. Docker access uses sudo,
matching the backend workflow.

The portal listens on VPS loopback `127.0.0.1:8091` and the Docker network.
A separate Caddy proxy (`hyperfeeds-https`) exposes `https://62.171.128.245`
on port 443 and forwards to `hyperfeeds-web-portal:80` on `hyperfeeds-network`.
Caddy manages the public IP certificate and renewal using the ACME shortlived
profile and TLS-ALPN validation on port 443. Port 80 remains owned by EduFlow.
Persistent certificate state is stored in the `hyperfeeds-caddy-data` volume.
This workflow does not modify the backend or database Compose project.

After configuring secrets and HTTPS, run the workflow
from Actions. Later pushes to main deploy automatically. The job verifies both
portal and proxied API health. To roll back, redeploy a previous commit using its
immutable image tag; no database changes are made by this portal deployment.

## IP-only HTTPS setup

The active configuration is `deploy/Caddyfile`. The earlier host Nginx template
`deploy/vps-ip-https.conf` is only an alternative; do not install it on this VPS.
To recreate the dedicated proxy, copy the Caddyfile to
`/opt/hyperfeeds-web/Caddyfile`, then run:

```sh
docker run -d --name hyperfeeds-https --restart unless-stopped \
  --network hyperfeeds-network -p 443:443 \
  -v /opt/hyperfeeds-web/Caddyfile:/etc/caddy/Caddyfile:ro \
  -v hyperfeeds-caddy-data:/data -v hyperfeeds-caddy-config:/config \
  caddy:2.11.6
```

TCP port 443 must remain publicly reachable for certificate issuance and renewal.
Do not remove the data volume when replacing the proxy container.
Check `docker logs hyperfeeds-https` for renewal errors.
Validate from outside the server using `curl -f https://62.171.128.245/healthz`
and `curl -f https://62.171.128.245/api/actuator/health`.
