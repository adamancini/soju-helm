# Upstream soju is published FROM scratch: no shell, no coreutils, just the
# soju/sojudb/sojuctl binaries. sojudb reads the admin password from stdin
# only (no flag/env alternative), so the chart's post-install Job needs `sh -c
# 'echo ... | sojudb ...'` to run at all. This wraps the upstream binaries in
# busybox to provide that shell without touching soju's own build.
ARG SOJU_VERSION=v0.10.1
FROM codeberg.org/emersion/soju:${SOJU_VERSION} AS soju
FROM busybox:1.36.1-musl

COPY --from=soju /soju /sojudb /sojuctl /usr/local/bin/
COPY --from=soju /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=soju /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=soju /etc/mime.types /etc/mime.types

ENTRYPOINT ["soju"]
