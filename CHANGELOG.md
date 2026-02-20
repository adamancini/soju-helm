# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-02-20

### Added

- soju Deployment with Recreate strategy and security-hardened containers
- Templated soju.conf ConfigMap from values (hostname, title, listeners, auth, TLS, file uploads)
- SQLite database backend (default) with PVC-backed persistent storage
- PostgreSQL database backend (optional, bundled StatefulSet or external)
- Post-install Helm Job for admin user creation via sojudb (direct DB access)
- Admin credentials Secret with auto-generation and lookup-based persistence
- cert-manager Certificate resource (optional)
- Ingress with path-based routing (/socket -> soju WebSocket, / -> gamja)
- Optional LoadBalancer Service for direct IRC client access
- Gamja IRC web client as vendored subchart (enabled by default)
- Prometheus metrics endpoint with optional ServiceMonitor
- NetworkPolicy for zero-trust network isolation
- Security-hardened defaults (non-root, read-only rootfs, seccomp, dropped capabilities)
- Progressive disclosure values.yaml structure
- CI/CD: Helm lint, kubeconform (K8s 1.28-1.32), Trivy, chart-testing
- Release workflow: GitHub Releases, GitHub Pages chart repo, OCI registry (ghcr.io)

[0.1.0]: https://github.com/adamancini/soju-helm/releases/tag/chart-v0.1.0
