# AGENTS.md

This file provides guidance to AI coding agents working in this repository.

## Overview

A personal home-lab setup defined as a single Docker Compose project ([compose.yaml](compose.yaml)). There is no application code, build, lint, or test tooling. It currently runs two container-management UIs, **Portainer CE** and **Dockge**, two dashboards, **Homer** and **Homepage**, and a **Traefik** reverse proxy in front of them. Prerequisites are Docker Engine with the compose plugin, and `make`.

## Commands

The [Makefile](Makefile) wraps `docker compose` and is the intended entry point. Every target depends on `os-check` (fails outside Linux), and every `docker compose` invocation is called with `--env-file $(ENV_FILE)` (resolved to `<repo>/.env`) so commands behave the same regardless of the caller's working directory:

```bash
make help          # list targets
make env-init      # create .env from .env.example if missing (does not overwrite)
make run           # docker compose up -d
make stop          # docker compose down
make restart       # down, then up (keeps data)
make restart-hard  # down -v, then up (WIPES named-volume data)
make status        # docker compose ps
make logs          # docker compose logs -f (all services)
make install       # prints docker/kubectl versions (sanity check; no k8s is actually used here)
```

Equivalent raw `docker compose` commands (e.g. for targeting a single service, which `make logs`/`make status` don't support):

```bash
docker compose --env-file .env -f compose.yaml up -d
docker compose --env-file .env -f compose.yaml down
docker compose --env-file .env -f compose.yaml config          # validate/render with .env substitution
docker compose --env-file .env -f compose.yaml logs -f <svc>   # svc: traefik | portainer | dockge | homer | homer-config | homepage
```

If `make` fails with `Makefile:28: *** missing separator.  Stop.`, an editor has converted leading tabs to spaces; fix with `sed -i 's/^    /\t/' Makefile`.

## Configuration

- `.env` (gitignored) must define `VOLUMES_DIR`, the **absolute host path** to the `volumes/` directory. [.env.example](.env.example) is the template; keep it updated when adding new variables. Run `make env-init` to bootstrap `.env` from the example on a fresh checkout.
- `.env` also holds `PORTAINER_SETUP_TOKEN`, which is currently a placeholder and not referenced anywhere (not by compose.yaml, not by the Makefile). Portainer CE doesn't read a plain env var for initial admin setup — the real mechanism is `--admin-password-file` pointing to a bcrypt hash, passed as a container `command:` arg — so wiring this up correctly needs that approach, not a simple `environment:` entry.
- `.env` defines `HOMER_URL`, `HOMEPAGE_URL` and `TRAEFIK_URL` (used as Homepage label hrefs) and `DOCKER_GID`, the group id owning `/var/run/docker.sock` on the host (`stat -c %g /var/run/docker.sock`).
- `.env` defines the published host ports `PORTAINER_PORT`, `DOCKGE_PORT`, `HOMER_PORT`, `HOMEPAGE_PORT`, `TRAEFIK_HTTP_PORT` and `TRAEFIK_DASHBOARD_PORT` (container-side ports stay fixed in compose.yaml). `TRAEFIK_DASHBOARD_PORT` must differ from `HOMER_PORT` (both containers use 8080 internally). Compose refuses to start if any is unset. `HOMEPAGE_ALLOWED_HOSTS` is built from `HOMEPAGE_PORT`.
- `.env` defines `LAB_HOSTNAME`, the host name every Traefik route hangs off (`<service>.${LAB_HOSTNAME}`). It is used in the `Host()` router rules, in `HOMEPAGE_ALLOWED_HOSTS`, and inside every `*_URL` (compose interpolates variables inside the env file, so `LAB_HOSTNAME` must be defined above the URLs). It is deliberately not called `HOSTNAME`: shell environment variables override `.env`, and many shells export `HOSTNAME`.
- `.env` also defines `PORTAINER_URL` and `DOCKGE_URL`, the URLs Homer links to. All `*_URL`s point at the Traefik routes, not the published ports, and assume `TRAEFIK_HTTP_PORT` is 80 (append the port otherwise). They are followed by the browser, so `LAB_HOSTNAME` must resolve from the client (not container names). Compose refuses to start if they are unset.
- `.gitignore` ignores everything under `/volumes/` (persisted runtime data) except `volumes/.gitkeep`, `volumes/homer/` (Homer assets), `volumes/traefik/` (Traefik config) and `volumes/homepage/config/` (Homepage config, minus its runtime `logs/`), `volumes/homepage/images/` (Homepage images), which are tracked. Keep real API keys/tokens out of the tracked Homepage YAML (Homepage supports `{{HOMEPAGE_VAR_*}}` substitution from env vars for that). Within `volumes/homer/`, `config.yml` is generated and ignored — edit `config.yml.tmpl` instead. Runtime data under `volumes/` (Portainer DB/keys/certs, Dockge SQLite DB) is owned by root/container users, so it may not be readable by the host user; never commit it.

## Architecture notes

- **Bind-backed named volumes:** named volumes (`portainer_data`, `dockge`, `homer`, `homepage`, `traefik`) use the `local` driver with `type: none, o: bind, device: ${VOLUMES_DIR}/<name>`. The target directories must exist on the host before `docker compose up`, or volume creation fails.
- **Dockge volume quirks:** the single `dockge` volume is mounted twice: at `/app/data` using `subpath: dockge-data` (its own DB and config), and at `${VOLUMES_DIR}/dockge` inside the container. The second mount is because Dockge requires the stacks directory to have the *same path inside the container as on the host* (`DOCKGE_STACKS_DIR`), so stacks it creates resolve correctly when it drives the host Docker daemon.
- **Homer config templating:** Homer is a static web app and cannot read env vars, so the one-shot `homer-config` service (alpine + `envsubst`) renders `volumes/homer/config.yml.tmpl` into `config.yml` on every `up`, and `homer` waits for it (`service_completed_successfully`). `envsubst` is given an explicit variable list, so only those `${VAR}`s are replaced; add new variables to that list, the `homer-config` `environment:`, and `.env.example`. `homer` runs with `INIT_ASSETS=0` so it never copies default assets over the tracked ones.
- **Homepage:** config lives in `${VOLUMES_DIR}/homepage/config` (mounted via `subpath: config`); images (e.g. the `background:` in `settings.yaml`) live in `${VOLUMES_DIR}/homepage/images`, mounted at `/app/public/images` (`subpath: images`) and referenced as `/images/<file>`. Next.js only serves `public/` files that existed when the server started, so restart `homepage` after adding an image or it returns 404. Services are discovered from `homepage.*` container labels (group, name, icon, href, description) through the `local` socket entry in that directory's `docker.yaml`; give new services the same labels, with `href` taken from a `*_URL` variable in `.env`. Homepage drops root and runs as `PUID`/`PGID`, and supplementary groups (`group_add`) are lost in that switch, so `PGID` is set to `DOCKER_GID` (the socket's group) or discovery fails silently. `HOMEPAGE_ALLOWED_HOSTS` must list every host:port the dashboard is reached through, or Homepage rejects the request.
- **Traefik:** static config is `volumes/traefik/traefik.yml` (tracked), mounted read-only at `/etc/traefik/traefik.yml` through the top-level `configs:` entry `traefik_static`; it is read only at startup, so restart `traefik` after editing. Don't add `command:` flags: Traefik reads a single static source (file, else flags, else env vars, never merged), so with the file present any flags other than `--configFile` are silently ignored. The `traefik` volume's `dynamic/` subpath is mounted at `/etc/traefik/dynamic` for the file provider (watched, picks up changes live). It listens on the `web` entrypoint and routes only containers labelled `traefik.enable=true` (`exposedbydefault=false`). Every long-running service joins the `proxy` network (fixed name `proxy`, so external stacks such as Dockge's can attach to it with `external: true`) and carries `traefik.http.routers.<svc>.rule=Host(`<svc>.${LAB_HOSTNAME}`)`, `entrypoints=web` and `traefik.http.services.<svc>.loadbalancer.server.port=<container port>`; give new services the same labels and network. Traefik's own dashboard is routed to `api@internal`. Portainer is routed to its plain-HTTP port 9000 (its published port is HTTPS 9443). Homepage's `HOMEPAGE_ALLOWED_HOSTS` includes its Traefik host name (`homepage.${LAB_HOSTNAME}`); if `TRAEFIK_HTTP_PORT` is not 80, that entry needs the port appended. `homer-config` is a one-shot job and stays off `proxy`.
- **Docker socket:** `portainer` and `dockge` bind-mount `/var/run/docker.sock`, giving them full control of the host's Docker daemon; `homepage` and `traefik` mount it read-only for discovery. `dockge` has `depends_on: portainer`.
- New services for the lab go in [compose.yaml](compose.yaml) following the same pattern (data under `${VOLUMES_DIR}/<name>`). The `# ~/secrets/compose/*.yaml` comments in the file are leftover references to the original standalone compose files.
