# ELLY Maps

AI-powered mobility intelligence platform. ELLY Maps combines navigation,
personal intelligence, emergency response, healthcare access, business
productivity, smart home integration, and AI assistance into one unified
ecosystem — an intelligent companion rather than a navigation tool.

> Full product vision and Version 1 feature list:
> [`reference/SPECIFICATION.md`](reference/SPECIFICATION.md).
> Reference UI: [`reference/Elly Maps Overview Design.jpeg`](reference/Elly%20Maps%20Overview%20Design.jpeg).
**Live Demo:** https://ellytest.vercel.app/
## Platform architecture

Four intelligence systems that share a unified user context:

| # | System                     | Backend module            | App tab       |
|---|----------------------------|---------------------------|---------------|
| 1 | Maps Intelligence          | `modules/maps`            | Map           |
| 2 | Connections Intelligence   | `modules/connections`     | Connections   |
| 3 | Emergency Intelligence     | `modules/emergency`       | Emergency     |
| 4 | ELLY AI Travel Assistant   | `modules/assistant`       | Contextual features inside existing tabs |

The shared user profile lives in `backend/app/shared/context.py`.

## Repository layout

```
Elly-Maps/
├── reference/     Product spec + reference UI design (source of truth)
├── backend/       FastAPI service — the four modules + shared context
└── frontend/      React Native (Expo + TypeScript) app — the three-tab shell
```

## Backend (FastAPI)

Recommended stack from the spec: Python + FastAPI.

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # then fill in provider keys
uvicorn app.main:app --reload
```

Open http://localhost:8000/docs for the interactive API. All Version 1
endpoints are wired up as stubs returning placeholder data — connect them to
real maps/location/LLM providers to bring them to life.

## Frontend (React Native)

Recommended stack from the spec: TypeScript + React Native.

```bash
cd frontend
npm install
npm run start                 # Expo dev server
```

Set `EXPO_PUBLIC_API_URL` to point the app at a separate backend. When it is
unset, web builds use the frontend's current hostname on port `8000`, so the
same build works through localhost, a LAN address, or Tailscale.

Product workflows that do not yet have client endpoints run against typed mock
data. See [`docs/mock-data-development.md`](docs/mock-data-development.md) for
the implemented features, persistence behaviour, demo reset, and the repository
boundary used to replace fixtures later.

## Status

This is Version 1 boilerplate: structure, the four-module split, shared user
context, and stubbed endpoints/screens. AI pipelines (destination prediction,
crash detection, conversational navigation, etc.) are documented in the spec as
future work and are not yet implemented.
