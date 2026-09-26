# AGENTS.md

This file provides guidance to AI coding agents working in this repository.

## Overview

A personal home-lab setup defined as a single Docker Compose project ([compose.yaml](compose.yaml)). There is no application code, build, lint, or test tooling. It currently runs two container-management UIs, **Portainer CE** and **Dockge**, plus a **Homer** dashboard. Prerequisites are Docker Engine with the compose plugin, and `make`.

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
docker compose --env-file .env -f compose.yaml logs -f <svc>   # svc: portainer | dockge | homer | homer-config
```

If `make` fails with `Makefile:28: *** missing separator.  Stop.`, an editor has converted leading tabs to spaces; fix with `sed -i 's/^    /\t/' Makefile`.

## Configuration

- `.env` (gitignored) must define `VOLUMES_DIR`, the **absolute host path** to the `volumes/` directory. [.env.example](.env.example) is the template; keep it updated when adding new variables. Run `make env-init` to bootstrap `.env` from the example on a fresh checkout.
- `.env` also holds `PORTAINER_SETUP_TOKEN`, which is currently a placeholder and not referenced anywhere (not by compose.yaml, not by the Makefile). Portainer CE doesn't read a plain env var for initial admin setup — the real mechanism is `--admin-password-file` pointing to a bcrypt hash, passed as a container `command:` arg — so wiring this up correctly needs that approach, not a simple `environment:` entry.
- `.env` also defines `PORTAINER_URL` and `DOCKGE_URL`, the URLs Homer links to. They are followed by the browser, so use a host name/IP reachable from the client (not container names). Compose refuses to start if they are unset.
- `.gitignore` ignores everything under `/volumes/` (persisted runtime data) except `volumes/.gitkeep` and `volumes/homer/` (Homer assets, tracked). Within `volumes/homer/`, `config.yml` is generated and ignored — edit `config.yml.tmpl` instead. Runtime data under `volumes/` (Portainer DB/keys/certs, Dockge SQLite DB) is owned by root/container users, so it may not be readable by the host user; never commit it.

## Architecture notes

- **Bind-backed named volumes:** named volumes (`portainer_data`, `dockge`) use the `local` driver with `type: none, o: bind, device: ${VOLUMES_DIR}/<name>`. The target directories must exist on the host before `docker compose up`, or volume creation fails.
- **Dockge volume quirks:** the single `dockge` volume is mounted twice: at `/app/data` using `subpath: dockge-data` (its own DB and config), and at `${VOLUMES_DIR}/dockge` inside the container. The second mount is because Dockge requires the stacks directory to have the *same path inside the container as on the host* (`DOCKGE_STACKS_DIR`), so stacks it creates resolve correctly when it drives the host Docker daemon.
- **Homer config templating:** Homer is a static web app and cannot read env vars, so the one-shot `homer-config` service (alpine + `envsubst`) renders `volumes/homer/config.yml.tmpl` into `config.yml` on every `up`, and `homer` waits for it (`service_completed_successfully`). `envsubst` is given an explicit variable list, so only those `${VAR}`s are replaced; add new variables to that list, the `homer-config` `environment:`, and `.env.example`. `homer` runs with `INIT_ASSETS=0` so it never copies default assets over the tracked ones.
- **Docker socket:** both services bind-mount `/var/run/docker.sock`, giving them full control of the host's Docker daemon. `dockge` has `depends_on: portainer`.
- New services for the lab go in [compose.yaml](compose.yaml) following the same pattern (data under `${VOLUMES_DIR}/<name>`). The `# ~/secrets/compose/*.yaml` comments in the file are leftover references to the original standalone compose files.
