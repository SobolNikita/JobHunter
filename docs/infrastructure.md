# Local infrastructure (Docker Compose)

Compose definitions and `.env.example` live in **`backend/deployments/`**. This page is the **only** document you need to install dependencies, start the stack, and connect your services.

## Prerequisites

- **Docker Engine** and the **Docker Compose** plugin (v2), installed and running.
- A shell where `docker compose version` prints a version (not the legacy standalone `docker-compose` binary unless it is compatible).

## 1. Create your environment file

From the **repository root**:

```bash
cp backend/deployments/.env.example backend/deployments/.env
```

Open `backend/deployments/.env` and replace every placeholder secret with a strong value you keep only on your machine.

| Variable | Notes |
|----------|--------|
| `POSTGRES_PASSWORD` | Required. |
| `REDIS_PASSWORD` | Required. |
| `RABBITMQ_DEFAULT_PASS` | Required. |
| `MINIO_ROOT_PASSWORD` | Required; **at least 8 characters** (MinIO rule). |

Optional: adjust `POSTGRES_USER`, `POSTGRES_DB`, `RABBITMQ_DEFAULT_USER`, `MINIO_ROOT_USER`, or the `*_HOST_PORT` variables if defaults clash with software already on your computer (defaults are listed in the connection tables below).

## 2. Start the stack

From the **repository root** (recommended, paths match CI and docs):

```bash
docker compose -f backend/deployments/docker-compose.yml --env-file backend/deployments/.env up -d
```

Equivalent if your current directory is **`backend/deployments`**:

```bash
cd backend/deployments
docker compose --env-file .env up -d
```

Compose loads variables from `--env-file` / `.env` for image configuration and published ports.

## 3. Confirm everything is healthy

```bash
docker compose -f backend/deployments/docker-compose.yml --env-file backend/deployments/.env ps
```

Each service should show **healthy** (or `running` where no healthcheck is shown) once startup finishes. Typical first-time RabbitMQ startup can take **30–60 seconds**.

View logs if something fails:

```bash
docker compose -f backend/deployments/docker-compose.yml --env-file backend/deployments/.env logs -f
```

## 4. Stop the stack (data kept)

```bash
docker compose -f backend/deployments/docker-compose.yml --env-file backend/deployments/.env down
```

Named volumes keep database and object data until you remove them explicitly (`docker volume rm …` or `down -v`).

---

## What each piece is for (JobHunter)

| Service | Role in the product |
|---------|---------------------|
| **PostgreSQL** | Primary **relational database**: users, resumes metadata, applications, job listings references, and other durable structured data the Go services persist. |
| **RabbitMQ** | **Message broker** for asynchronous work: resume parsing pipelines, job matching tasks, notifications, and other jobs you do not want to run inline in an HTTP request. Producers publish messages; consumers process them in the background. |
| **Redis** | **Fast in-memory store**: short-lived session or token state, rate limiting, caches of hot reads, and coordination primitives (locks, pub/sub) where PostgreSQL would be too slow or the wrong fit. |
| **MinIO** | **S3-compatible object storage** for large blobs: uploaded **resumes** (PDF/DOC), generated exports, or other files the API should not stream through the database. Applications use the S3 API against MinIO’s endpoint. |

---

## Connection reference

There are two common cases:

1. **Application on your host** (e.g. Go gateway run with `go run`, tests on the laptop): use **`localhost`** and the **published host ports** from your `.env` (defaults in parentheses).
2. **Application in another Docker container** attached to the same Compose project network: use the **service hostname** (below) and **container internal ports** (fixed: `5432`, `5672`, `6379`, `9000`, `9001`).

Compose project name is **`jobhunter`**; the shared network is named **`backend`** in the file (Docker will show it as something like `jobhunter_backend`).

### PostgreSQL

| Where the app runs | Host | Port | Database / user |
|--------------------|------|------|-------------------|
| On your machine | `localhost` | `${POSTGRES_HOST_PORT}` (**default `5430`**) maps to Postgres `5432` inside the container | DB: `${POSTGRES_DB}` (default `jobhunter`). User: `${POSTGRES_USER}` (default `jobhunter`). Password: `${POSTGRES_PASSWORD}`. |
| In Docker on the same Compose network | `postgres` | **5432** | Same variable names for credentials (injected from your `.env` when the DB container starts). |

Example URL from the host:

```text
postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:${POSTGRES_HOST_PORT:-5430}/${POSTGRES_DB}
```

(Use proper URL-encoding if the password contains special characters.)

### RabbitMQ (AMQP)

| Where the app runs | Host | Port | Credentials |
|--------------------|------|------|----------------|
| On your machine | `localhost` | `${RABBITMQ_AMQP_HOST_PORT}` (**default `5672`**) | User `${RABBITMQ_DEFAULT_USER}` (default `jobhunter`), password `${RABBITMQ_DEFAULT_PASS}`. |
| In Docker on the same Compose network | `rabbitmq` | **5672** | Same. |

Example AMQP URL from the host:

```text
amqp://${RABBITMQ_DEFAULT_USER}:${RABBITMQ_DEFAULT_PASS}@localhost:${RABBITMQ_AMQP_HOST_PORT:-5672}/
```

**Note:** The built-in `guest` user is **not** suitable for connections from other containers; this stack uses **`RABBITMQ_DEFAULT_USER`** instead.

### RabbitMQ management UI

Browser URL from your machine:

```text
http://localhost:${RABBITMQ_MANAGEMENT_HOST_PORT:-15672}/
```

Sign in with **`RABBITMQ_DEFAULT_USER`** and **`RABBITMQ_DEFAULT_PASS`**. Use this UI to inspect queues, exchanges, bindings, and consumers while developing.

### Redis

| Where the app runs | Host | Port | Auth |
|--------------------|------|------|------|
| On your machine | `localhost` | `${REDIS_HOST_PORT}` (**default `6380`**) maps to Redis `6379` inside the container | Password: `${REDIS_PASSWORD}` (`AUTH` / CLI `-a` / client `password` option). |
| In Docker on the same Compose network | `redis` | **6379** | Same password. |

Example `redis-cli` from the host (after install). Load variables from `.env` into your shell first (for example `set -a && source backend/deployments/.env && set +a` from the repo root), or paste the port and password manually:

```bash
redis-cli -h 127.0.0.1 -p 6380 -a "<REDIS_PASSWORD from .env>" ping
```

Use the port you set in `REDIS_HOST_PORT` if it is not `6380`.

### MinIO (S3 API and web console)

Credentials are always **`MINIO_ROOT_USER`** and **`MINIO_ROOT_PASSWORD`** from your `.env` (defaults for the username only: `minioadmin` if unset; password has no default and must be set).

| Endpoint | URL from your machine |
|----------|------------------------|
| **S3 API** (SDKs, aws-cli, presigned URLs) | `http://localhost:${MINIO_API_HOST_PORT:-9000}` |
| **Web console** (buckets, keys, access keys in the UI) | `http://localhost:${MINIO_CONSOLE_HOST_PORT:-9001}` |

In application config, set the S3 **endpoint** to the API URL above, **region** can be a placeholder such as `us-east-1` if your SDK requires one, **access key** = `MINIO_ROOT_USER`, **secret key** = `MINIO_ROOT_PASSWORD`, and use **path-style** addressing unless your client defaults work with MinIO’s virtual-host setup on localhost.

---

## Quick checklist for a new developer

1. Install Docker + Compose.
2. `cp backend/deployments/.env.example backend/deployments/.env` and fill secrets.
3. Run `docker compose -f backend/deployments/docker-compose.yml --env-file backend/deployments/.env up -d`.
4. Wait until `docker compose … ps` shows services healthy.
5. Point local services at **localhost** + ports and credentials from `.env` (tables above).

If a port is already in use, change the corresponding `*_HOST_PORT` in `.env` and run `docker compose … up -d` again.
