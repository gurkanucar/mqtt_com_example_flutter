# Staging server — MQTT + nginx (SSL)

Host: `173.249.32.141` · Domain: `stagingenvironment.space` (DNS `@` and `*` → the IP)

## What runs where

| Piece            | Where                          | Notes                                   |
|------------------|--------------------------------|-----------------------------------------|
| Mosquitto broker | Docker (`/opt/mqtt`)           | `eclipse-mosquitto:2`, auth `app`/`changeme` |
| nginx + certbot  | Host (Ubuntu 24.04)            | TLS termination + Let's Encrypt cert    |
| TLS cert         | `/etc/letsencrypt/live/stagingenvironment.space/` | auto-renews |

The broker itself speaks **plaintext**. nginx is what adds SSL in front of it.

## Connection options (the two the app exposes)

| Mode        | URL                                        | Port | Path through the box                       |
|-------------|--------------------------------------------|------|--------------------------------------------|
| **SSL**     | `mqtts://stagingenvironment.space:8883`    | 8883 | nginx `stream` TLS → mosquitto `1883`      |
| **Plain IP**| `mqtt://173.249.32.141:1883`               | 1883 | docker-proxy → mosquitto `1883` (no TLS)   |
| Web (WSS)   | `wss://stagingenvironment.space/mqtt`      | 443  | nginx `http` → mosquitto `9001` (websocket)|

Auth on every path: username `app`, password `changeme`.

## Files in this folder (mirror of what's on the server)

- `mqtt-stream.conf` → `/etc/nginx/stream.d/mqtt-stream.conf`
  nginx `stream` server: `listen 8883 ssl` → `proxy_pass 127.0.0.1:1883`. This is the SSL/MQTT bridge.
- `mqtt-web.conf` → `/etc/nginx/conf.d/mqtt-web.conf`
  Port 80 (ACME challenge + redirect) and 443 (WSS at `/mqtt` + a plaintext status page).
- `nginx.conf.snippet` → appended to `/etc/nginx/nginx.conf` (top level) so the stream config loads.
- `renewal-deploy-hook.sh` → `/etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh`
  Reloads nginx after a cert renewal so the new cert is picked up on 8883 and 443.

## One-time setup that was done on the server

```sh
# packages
apt-get install -y nginx certbot python3-certbot-nginx libnginx-mod-stream

# firewall (ufw was already active; SSH + docker 1883 were already allowed)
ufw allow 80/tcp && ufw allow 443/tcp && ufw allow 8883/tcp

# cert (HTTP-01 via nginx)
certbot certonly --nginx -d stagingenvironment.space \
  --non-interactive --agree-tos -m ucar.gurkan@hotmail.com

# drop the conf files in place (see table above), then:
nginx -t && systemctl restart nginx
```

## Verify

```sh
# TLS handshake on the MQTT port (should print a valid Let's Encrypt cert)
echo | openssl s_client -connect stagingenvironment.space:8883 -servername stagingenvironment.space

# real publish over TLS
mosquitto_pub -h stagingenvironment.space -p 8883 --capath /etc/ssl/certs \
  -u app -P changeme -t healthcheck/tls -m ok
```
