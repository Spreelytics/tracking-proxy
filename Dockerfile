# Spreelytics tracking proxy: serves the Spreelytics script and its tracking requests from your own domain.
# Runs as a non-root user (uid 101) on nginx's stable branch.
# https://github.com/spreelytics/tracking-proxy
FROM nginxinc/nginx-unprivileged:1.30-alpine

LABEL org.opencontainers.image.title="Spreelytics tracking proxy" \
      org.opencontainers.image.description="Serve the Spreelytics analytics script and tracking requests from your own domain, so fewer visitors go uncounted." \
      org.opencontainers.image.url="https://spreelytics.com/?utm_source=github&utm_medium=readme&utm_campaign=tracking-proxy" \
      org.opencontainers.image.documentation="https://github.com/spreelytics/tracking-proxy#readme" \
      org.opencontainers.image.source="https://github.com/spreelytics/tracking-proxy" \
      org.opencontainers.image.vendor="Spreelytics" \
      org.opencontainers.image.licenses="MIT"

# The port the proxy listens on. Most hosts set PORT for you.
ENV PORT=8080
# Find Spreelytics' hosts with the DNS servers the container was given (Kubernetes, Docker, Cloud Run, ...),
# so the proxy also works where outbound DNS to public resolvers is blocked.
ENV NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1

# The image's entrypoint fills in ${PORT} and ${NGINX_LOCAL_RESOLVERS} and writes /etc/nginx/conf.d/default.conf.
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template

EXPOSE 8080
