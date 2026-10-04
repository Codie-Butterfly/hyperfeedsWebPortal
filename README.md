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
proxy for the chosen portal domain to forward to this address and preserve Host,
X-Forwarded-For and X-Forwarded-Proto. HTTPS is needed for browser secure storage.
Domain and TLS setup must be completed before enabling production deployment.
This workflow does not modify the backend or database Compose project.

After configuring secrets and HTTPS, set `DEPLOY_ENABLED=true` and run the workflow
from Actions. Later pushes to main deploy automatically. The job verifies both
portal and proxied API health. To roll back, redeploy a previous commit using its
immutable image tag; no database changes are made by this portal deployment.
