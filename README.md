# soju-helm

Helm chart for deploying [soju](https://codeberg.org/emersion/soju) IRC bouncer with [gamja](https://codeberg.org/emersion/gamja) web client on Kubernetes.

## Features

- **soju IRC bouncer** with full configuration templating (listeners, auth, TLS, file uploads)
- **gamja web client** as a vendored subchart, enabled by default
- **Automated admin user creation** via post-install Helm hook using `sojudb`
- **SQLite** (default) or **PostgreSQL** database backends
- **cert-manager** integration for automated TLS certificates
- **Ingress** with path-based routing (`/socket` -> soju WebSocket, `/` -> gamja)
- **Optional LoadBalancer** Service for direct IRC client access
- **Prometheus** metrics endpoint with optional ServiceMonitor
- **NetworkPolicy** for zero-trust network isolation
- **Security-hardened** defaults (non-root, read-only rootfs, seccomp, dropped capabilities)

## Prerequisites

- Kubernetes 1.28+
- Helm 3
- PV provisioner (for SQLite persistence)
- cert-manager (optional, for automated TLS)
- Prometheus Operator (optional, for ServiceMonitor)

## Quick Start

### Install from OCI Registry

```bash
helm install soju oci://ghcr.io/adamancini/charts/soju \
  --set soju.domain=irc.example.com
```

### Install from Source

```bash
git clone https://github.com/adamancini/soju-helm.git
cd soju-helm
helm install soju charts/soju --set soju.domain=irc.example.com
```

### Verify

```bash
# Check pods
kubectl get pods -l app.kubernetes.io/name=soju

# Get admin credentials
kubectl get secret soju-admin -o jsonpath='{.data.admin-username}' | base64 -d
kubectl get secret soju-admin -o jsonpath='{.data.admin-password}' | base64 -d

# Port-forward gamja
kubectl port-forward svc/soju-gamja 8080:80
# Open http://localhost:8080
```

## Configuration

### Basic Parameters

| Parameter | Default | Description |
|---|---|---|
| `soju.domain` | `""` | **Required.** IRC server hostname |
| `soju.title` | `"soju IRC bouncer"` | Server title shown to clients |
| `soju.motd` | `""` | Message of the Day file path |
| `image.repository` | `codeberg.org/emersion/soju` | Container image |
| `image.tag` | `""` | Image tag (defaults to `appVersion`) |
| `image.pullPolicy` | `IfNotPresent` | Pull policy |
| `admin.enabled` | `true` | Create admin user on install |
| `admin.username` | `admin` | Admin username |
| `admin.password` | `""` | Admin password (auto-generated if empty) |
| `admin.existingSecret` | `""` | Use existing Secret for admin credentials |
| `ingress.enabled` | `false` | Enable Ingress |
| `ingress.className` | `""` | Ingress class name |
| `ingress.host` | `""` | Ingress host (defaults to `soju.domain`) |
| `ingress.tls.enabled` | `true` | Enable TLS on Ingress |

### Advanced Parameters

| Parameter | Default | Description |
|---|---|---|
| `database.driver` | `sqlite3` | Database backend (`sqlite3` or `postgres`) |
| `database.sqlite.path` | `/data/soju.db` | SQLite database path |
| `database.postgres.host` | `""` | PostgreSQL host |
| `database.postgres.port` | `5432` | PostgreSQL port |
| `database.postgres.database` | `soju` | PostgreSQL database name |
| `certificate.enabled` | `false` | Create cert-manager Certificate |
| `certificate.secretName` | `soju-tls` | TLS Secret name |
| `certificate.issuerRef.name` | `letsencrypt` | Issuer name |
| `tls.existingSecret` | `""` | Use existing TLS Secret |
| `listeners.ircs` | `true` | IRC+TLS on port 6697 |
| `listeners.irc` | `false` | Plain IRC on port 6667 |
| `listeners.websocket` | `true` | WebSocket on port 8080 |
| `listeners.metrics` | `true` | Prometheus on port 9090 |
| `listeners.admin` | `true` | Unix admin socket |
| `persistence.enabled` | `true` | Enable persistent storage |
| `persistence.size` | `1Gi` | Storage size |
| `persistence.storageClass` | `""` | StorageClass name |
| `loadBalancer.enabled` | `false` | Create LoadBalancer Service |
| `loadBalancer.loadBalancerIP` | `""` | Static IP for LoadBalancer |
| `fileUpload.enabled` | `true` | Enable file uploads |
| `auth.method` | `internal` | Auth method (`internal`, `pam`, `oauth2`, `http`) |
| `metrics.serviceMonitor.enabled` | `false` | Create Prometheus ServiceMonitor |
| `networkPolicy.enabled` | `false` | Enable NetworkPolicy |
| `gamja.enabled` | `true` | Deploy gamja web client |
| `gamja.server.url` | `""` | WebSocket URL (defaults to `/socket`) |
| `gamja.server.autojoin` | `""` | Channel to auto-join |

## Production Deployment

### With Traefik Ingress and cert-manager

```yaml
soju:
  domain: irc.example.com

certificate:
  enabled: true
  issuerRef:
    name: letsencrypt
    kind: ClusterIssuer

ingress:
  enabled: true
  className: traefik
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: default-headers@kubernetescrd
  tls:
    enabled: true

loadBalancer:
  enabled: true
  loadBalancerIP: "10.0.0.200"
  annotations:
    external-dns.alpha.kubernetes.io/hostname: irc.example.com

metrics:
  serviceMonitor:
    enabled: true

networkPolicy:
  enabled: true
```

### With nginx Ingress

```yaml
soju:
  domain: irc.example.com

certificate:
  enabled: true

ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
  tls:
    enabled: true
```

### With External PostgreSQL

```yaml
soju:
  domain: irc.example.com

database:
  driver: postgres
  postgres:
    host: postgres.example.com
    port: 5432
    database: soju
    user: soju
    existingSecret: my-postgres-secret
    passwordKey: password
```

## Architecture

```
                    Internet
                       |
              +-----------------+
              |    Ingress      |
              |  (Traefik/nginx)|
              +---+--------+----+
                  |        |
          /socket |        | /
                  v        v
            +--------+  +-------+
            |  soju  |  | gamja |
            | :8080  |  |  :80  |
            | (WS)   |  | (web) |
            +---+----+  +-------+
                |
    +-----------+-----------+
    |           |           |
  :6697      :9090       :6667
  (IRCS)   (metrics)    (IRC)
    |                      |
  LB Svc               (optional)
    |
  IRC Clients
```

## Post-Installation

### Admin User

When `admin.enabled: true` (default), an admin user is created automatically via a post-install Helm hook. The hook runs `sojudb create-user` directly against the database, so it does not require a running soju server.

Credentials are stored in a Secret and preserved across upgrades via `lookup`.

### Connecting an IRC Client

1. Configure your client to connect to your soju domain on port 6697 (TLS)
2. Authenticate with your admin username and password
3. Use `BouncerServ` to add upstream IRC networks:
   ```
   /msg BouncerServ network create -addr irc.libera.chat:6697 -name libera
   ```

## Upgrading

```bash
helm upgrade soju oci://ghcr.io/adamancini/charts/soju \
  --set soju.domain=irc.example.com
```

The admin user hook only runs on `post-install` (not `post-upgrade`), so existing credentials are preserved.

## Uninstalling

```bash
helm uninstall soju
```

PVCs are not deleted automatically. To clean up:

```bash
kubectl delete pvc soju-data
```

## Development

```bash
# Lint
helm lint charts/soju --strict --set soju.domain=test.example.com

# Template
helm template soju charts/soju --set soju.domain=test.example.com --debug

# Template with specific CI values
helm template soju charts/soju -f charts/soju/ci/full-values.yaml

# YAML lint
yamllint -c .yamllint.yml charts/soju/values.yaml charts/soju/Chart.yaml charts/soju/ci/
```

## License

This chart is provided as-is. soju and gamja are developed by [Simon Ser](https://codeberg.org/emersion).
