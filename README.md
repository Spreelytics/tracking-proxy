# Spreelytics tracking proxy

Serve the [Spreelytics](https://spreelytics.com/?utm_source=github&utm_medium=readme&utm_campaign=tracking-proxy) analytics script and its tracking requests from your own domain, so fewer of your visitors go uncounted.

```bash
docker run -p 8080:8080 ghcr.io/spreelytics/tracking-proxy
```

> **Don't want to run a server?** Spreelytics runs this same proxy for you. Add one CNAME record and you're done: no container, no TLS certificates, no updates.
> [Set up the managed proxy](https://spreelytics.com/docs/proxy?utm_source=github&utm_medium=readme&utm_campaign=tracking-proxy) or [create a free Spreelytics account](https://app.spreelytics.com/auth?utm_source=github&utm_medium=readme&utm_campaign=tracking-proxy).

## Why you'd want this

Blockers don't need to know an analytics tool by name to stop it. Ad blocker extensions match URL patterns and file names as well as hostnames. Privacy browsers and built-in tracking protection treat requests to other domains more strictly than requests to the site you're on. DNS blockers like Pi-hole and NextDNS, and many company networks, block whole categories of third-party domains. Any analytics script served from a domain other than your site's runs into some of this, whichever tool it is, and every request that gets stopped is a visit that's never counted. On sites with a technical audience that can be a large share of real people.

When the script and its requests come from a subdomain of your own site instead, say `t.example.com`, they're first-party requests like the rest of your site, and far more of them get through. Your numbers get closer to what actually happened. It isn't a guarantee: a blocker that's strict enough can still stop some requests, but most of the reasons above no longer apply.

## Set it up

### 1. Run the container

Run the image on any host that runs containers. Ready-made setups for popular hosts are [below](#deploy-it). To try it on your machine first:

```bash
docker run -p 8080:8080 ghcr.io/spreelytics/tracking-proxy
```

Open http://localhost:8080 and you should see "Spreelytics proxy is running".

### 2. Give it a subdomain

Point a subdomain of your site at it, with HTTPS, for example `t.example.com`. Avoid names with words like "analytics", "tracking" or "stats" in them, which blockers look for.

### 3. Update your snippet

Replace your Spreelytics snippet with this one, using your subdomain for `YOUR_HOST`:

```html
<script src="https://YOUR_HOST/cdn/sdk/spreelytics-loader.js"></script>
<script>
  Spreelytics.init({
    client_key: "YOUR_CLIENT_KEY",
    api_host: "https://YOUR_HOST/1.0",
  });
</script>
```

Your client key is in Spreelytics under **Settings → Tracking script**. The [install guide](https://spreelytics.com/docs/install?utm_source=github&utm_medium=readme&utm_campaign=tracking-proxy) covers the other snippet options.

### 4. Check it works

1. Open your site with the browser's **Network** tab open and filter by your subdomain. The Spreelytics script and its requests should all go to your subdomain with status `200`.
2. Open **Realtime** in Spreelytics. You should show up within a minute, in your own location.

If everyone shows up in the same place, see [Troubleshooting](#troubleshooting).

## Deploy it

Use `ghcr.io/spreelytics/tracking-proxy:1` in production. It's also on Docker Hub as `spreelytics/tracking-proxy:1`. The `1` tag gets every 1.x update and is rebuilt weekly with security fixes, but never a change that would break your setup. A running proxy picks up a new build when it restarts and pulls the image again, so redeploy it now and then.

### Kubernetes

Download [`examples/k8s.yaml`](https://github.com/spreelytics/tracking-proxy/blob/main/examples/k8s.yaml), change `t.example.com` to your subdomain, and apply it:

```bash
kubectl apply -f k8s.yaml
```

It has a Deployment, a Service and an Ingress. If you'd rather write your own, the minimum is:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spreelytics-proxy
spec:
  replicas: 2
  selector:
    matchLabels: { app: spreelytics-proxy }
  template:
    metadata:
      labels: { app: spreelytics-proxy }
    spec:
      containers:
        - name: proxy
          image: ghcr.io/spreelytics/tracking-proxy:1
          # Fetch the newest build of `1` whenever a pod starts.
          imagePullPolicy: Always
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: spreelytics-proxy
spec:
  selector: { app: spreelytics-proxy }
  ports:
    - { port: 80, targetPort: 8080 }
```

If your cluster requires `readOnlyRootFilesystem`, mount an `emptyDir` on `/etc/nginx/conf.d` and on `/tmp`. The example file already does.

To pick up the weekly security build, restart the proxy now and then:

```bash
kubectl rollout restart deployment/spreelytics-proxy
```

### Google Cloud Run

```bash
gcloud run deploy spreelytics-proxy \
  --image docker.io/spreelytics/tracking-proxy:1 \
  --allow-unauthenticated \
  --region us-central1
```

Then add your subdomain with a [Cloud Run domain mapping](https://cloud.google.com/run/docs/mapping-custom-domains) or a load balancer.

### Fly.io

Save this as `fly.toml`:

```toml
app = "my-spreelytics-proxy"
primary_region = "iad"

[build]
  image = "ghcr.io/spreelytics/tracking-proxy:1"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = "stop"
  auto_start_machines = true
  min_machines_running = 1
```

```bash
fly deploy
fly certs add t.example.com
```

### Render

In the dashboard, choose **New → Web Service → Existing image**, enter `ghcr.io/spreelytics/tracking-proxy:1`, then add your subdomain under **Settings → Custom Domains**.

Or with a `render.yaml` blueprint:

```yaml
services:
  - type: web
    name: spreelytics-proxy
    runtime: image
    image:
      url: ghcr.io/spreelytics/tracking-proxy:1
```

### Anything else

Any host that runs a container image works: ECS, Azure Container Apps, Railway, a VM with Docker. Run the image, give it HTTPS on your subdomain, and you're done.

## Troubleshooting

**Everyone shows up in the same place.** Something in front of the proxy is hiding your visitors' addresses, so Spreelytics only sees one. Most load balancers and CDNs pass them on without any setup. On Kubernetes, a `Service` of type `LoadBalancer` doesn't by default: put an ingress in front of it, or set `externalTrafficPolicy: Local` on the Service.

**Nothing shows up in Realtime.** Check that the snippet uses your subdomain in both places, the script `src` and `api_host`, and that `https://YOUR_HOST/cdn/sdk/spreelytics-loader.js` opens in your browser.

For anything else, see the [proxy guide](https://spreelytics.com/docs/proxy?utm_source=github&utm_medium=readme&utm_campaign=tracking-proxy).

## Managed proxy: skip all of this

Running your own proxy means a container to host, a certificate to keep valid and an image to keep updated. If you'd rather not, Spreelytics' managed proxy gives you the same result on your own subdomain:

1. Choose a subdomain in Spreelytics, such as `t.example.com`.
2. Add the one CNAME record it shows you.
3. Copy the updated snippet.

Spreelytics handles HTTPS, scaling and updates for you.

[Read the proxy guide](https://spreelytics.com/docs/proxy?utm_source=github&utm_medium=readme&utm_campaign=tracking-proxy) · [See pricing](https://spreelytics.com/pricing?utm_source=github&utm_medium=readme&utm_campaign=tracking-proxy) · [Start free](https://app.spreelytics.com/auth?utm_source=github&utm_medium=readme&utm_campaign=tracking-proxy)

## About Spreelytics

[Spreelytics](https://spreelytics.com/?utm_source=github&utm_medium=readme&utm_campaign=tracking-proxy) is web analytics for people who want answers, not dashboards to dig through: traffic, funnels, goals, revenue, session replay, and you can ask about your data in plain English, in the app or from your own AI agent over MCP. It works with or without cookies.

- [Website](https://spreelytics.com/?utm_source=github&utm_medium=readme&utm_campaign=tracking-proxy)
- [Docs](https://spreelytics.com/docs?utm_source=github&utm_medium=readme&utm_campaign=tracking-proxy)
- [Sign up free](https://app.spreelytics.com/auth?utm_source=github&utm_medium=readme&utm_campaign=tracking-proxy)

## License

[MIT](LICENSE)
