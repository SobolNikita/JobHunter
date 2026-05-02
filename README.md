# JobHunter

JobHunter is a job-hunting platform.

## Tech stack
- Frontend: React + Bootstrap
- Backend: Go microservices
- Database: PostgreSQL
- Cache: Redis
- Messaging: RabbitMQ
- File storage: MinIO
- Internal communication: gRPC

## Repository structure
- `frontend/` - React application
- `backend/` - Go services, gateway, infrastructure, and shared contracts
- `docs/` - project notes and architecture documents

## Branch workflow
- `main` - production branch
- `develop` - development branch
- `feature/*` - branches for new work

All new work should start from `develop` and merge back into `develop` after completion.

## Project goal
The app will help users upload resumes, analyze them, find matching jobs, and manage applications with optional auto-apply workflows.

