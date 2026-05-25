# Todo Management

[English](README.md) | [简体中文](README-zh_CN.md) | [日本語](README-ja_JP.md)

Full-stack sample with a FastAPI + PostgreSQL backend and Vue 3 + Vite frontend. The solution runs on Azure Container Apps with ACR, Microsoft Entra ID, user-assigned managed identity (UAI), and private networking to implement a zero-plaintext-secret architecture.

## System Overview

The infrastructure is designed to be **private, secure, and identity-based**, with no hardcoded secrets.

![Architecture](images/01.Architecture.png)


## Architecture At A Glance
- Containers: `todomanagement-api` (FastAPI) and `todomanagement-web` (Vite/Vue)
- Infrastructure: private VNet subnets, PostgreSQL Flexible Server (Microsoft Entra ID auth), ACR private endpoint, Container Apps Environment, Log Analytics, and UAI
- CI/CD: GitHub Actions builds and pushes images to ACR, then performs rolling updates with `az containerapp up`
- Reference: `docs/ARCHITECTURE_GUIDE.md`

## Repository Structure
- `src/api`: FastAPI service (SQLite for local development, PostgreSQL for production)
- `src/web`: Vue 3 SPA (MSAL sign-in, Todo/search features)
- `infra`: Bicep templates, deployment scripts, and parameters
- `docs`: architecture and supporting documentation

## Local Run
Prerequisites: Python 3.11, pip, Node 18+, npm.

API
```powershell
cd src\api
copy .env.local.example .env.local
python -m venv .venv; .\.venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
# Health check: http://localhost:8000/health
```
If you use local PostgreSQL, set `DATABASE_TYPE=postgresql` and `POSTGRES_*` in `.env.local`.

Web
```powershell
cd src\web
copy .env.example .env.local
npm install
npm run dev  # http://localhost:5173
```
During local development, Vite automatically proxies `/api` to the local backend. For production, run `npm run build` (output in `dist/`). In Azure, the web Container App uses `API_PROXY_TARGET` to reverse proxy same-origin `/api` to the internal API Container App.

## Deployment
Recommended deployment order:
1. Beginner track (GUI): `handson/DEPLOY_GUIDE_GUI.md`
2. Advanced track (IaC): `handson/DEPLOY_GUIDE.md`

IaC deployment flow summary:
1. Deploy infrastructure from `infra/deploy.ps1`
2. Record outputs such as ACR, PostgreSQL hostname, Container Apps environment, and UAI IDs
3. Create workflow files from `.github/workflows/*.yml.template`
4. Configure GitHub secret `AZURE_CREDENTIALS` and required repository variables
5. Trigger GitHub Actions and validate the deployed API and web app

See `handson/DEPLOY_GUIDE_GUI.md` for the GUI-first beginner guide.
See `handson/DEPLOY_GUIDE.md` for the IaC advanced guide.

## Related Docs
- `docs/ARCHITECTURE_GUIDE.md`
- `handson/DEPLOY_GUIDE_GUI.md`
- `handson/DEPLOY_GUIDE.md`
- `infra/README.md`
