<p align="center">
  <strong>Faro</strong> — AI-native commercial insurance intake & analysis on iOS / iPadOS
</p>

<p align="center">
  <a href="https://developer.apple.com/swift/"><img src="https://img.shields.io/badge/Swift-5.9+-F05138?logo=swift&logoColor=white" alt="Swift" /></a>
  <a href="https://developer.apple.com/xcode/swiftui/"><img src="https://img.shields.io/badge/SwiftUI-0066CC?logo=swift&logoColor=white" alt="SwiftUI" /></a>
  <a href="https://www.python.org/"><img src="https://img.shields.io/badge/Python-3.12+-3776AB?logo=python&logoColor=white" alt="Python" /></a>
  <a href="https://fastapi.tiangolo.com/"><img src="https://img.shields.io/badge/FastAPI-009688?logo=fastapi&logoColor=white" alt="FastAPI" /></a>
  <a href="https://www.mongodb.com/atlas"><img src="https://img.shields.io/badge/MongoDB_Atlas-47A248?logo=mongodb&logoColor=white" alt="MongoDB Atlas" /></a>
  <a href="https://auth0.com/"><img src="https://img.shields.io/badge/Auth0-EB5424?logo=auth0&logoColor=white" alt="Auth0" /></a>
</p>

<p align="center">
  <a href="https://ai.google.dev/"><img src="https://img.shields.io/badge/Google_Gemini-4285F4?logo=google&logoColor=white" alt="Google Gemini" /></a>
  <a href="https://www.langchain.com/langgraph"><img src="https://img.shields.io/badge/LangGraph-1C3C3C?logo=langchain&logoColor=white" alt="LangGraph" /></a>
  <a href="https://elevenlabs.io/"><img src="https://img.shields.io/badge/ElevenLabs-000000?logo=elevenlabs&logoColor=white" alt="ElevenLabs" /></a>
  <a href="https://developer.apple.com/documentation/charts"><img src="https://img.shields.io/badge/Swift_Charts-34C759?logo=apple&logoColor=white" alt="Swift Charts" /></a>
  <a href="https://developer.apple.com/documentation/widgetkit"><img src="https://img.shields.io/badge/WidgetKit-007AFF?logo=apple&logoColor=white" alt="WidgetKit" /></a>
</p>

---

## Table of contents

- [Inspiration](#inspiration)
- [What it does](#what-it-does)
- [Hackathon context & sponsor tracks](#hackathon-context--sponsor-tracks)
- [How we built it](#how-we-built-it)
  - [Libraries & dependencies](#libraries--dependencies)
- [Repository layout](#repository-layout)
- [API surface](#api-surface)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration (environment variables)](#configuration-environment-variables)
- [Local development](#local-development)
- [Testing](#testing)
- [iOS: Widget & App Groups](#ios-widget--app-groups)
- [Challenges we ran into](#challenges-we-ran-into)
- [Accomplishments we're proud of](#accomplishments-were-proud-of)
- [What we learned](#what-we-learned)
- [What's next](#whats-next)
- [License](#license)

---

## Inspiration

Commercial insurance for small businesses is broken. Getting coverage takes days of back-and-forth with human brokers, pages of confusing jargon, and mountains of paperwork. A daycare owner, a restaurant operator, a contractor—they want to know what they need, how much it costs, and where to get it. For people building a business, that friction is an easy problem to overlook until it blocks them cold.

We built **Faro** to compress that workflow into **under two minutes**, powered by an autonomous AI agent that reasons like a broker.

We chose to build natively on **iOS** and **iPadOS** because we believe the future of AI applications is increasingly **on-device**. Today, Faro runs model inference through cloud APIs, but a native Swift architecture positions the product for a world where models run directly on the phone or tablet with minimal data leaving the device. For a product handling sensitive business financials, headcount, and revenue, that privacy story matters.

---

## What it does

A business owner opens Faro on an **iPhone** or **iPad**, describes their company in plain English, and within about two minutes receives a **structured insurance analysis**. There are two primary intake paths:

- **Guided questionnaire** — A one-question-at-a-time flow for business name, description, employee count, US state, and approximate annual revenue.
- **Conversational voice intake** — The user talks naturally with Faro. An **ElevenLabs Conversational AI** agent runs a voice interview over a **WebSocket**; when the conversation finishes, the transcript is turned into structured intake fields using **Google Gemini**.

After intake, Faro runs a **four-step agent pipeline** (orchestrated with **LangGraph**, reasoning with **Gemini**):

1. **Risk profiler** — Risk exposure and regulatory-style considerations.
2. **Coverage mapper** — Required, recommended, and projected coverages with premium estimates (hybrid rules + LLM).
3. **Submission builder** — Carrier-oriented submission packet content.
4. **Explainer** — Plain-English narrative; optional **ElevenLabs text-to-speech** produces audio served at `GET /audio/{session_id}`.

The **Agent tracker** screen streams step progress over **WebSocket** so users see the pipeline work in real time.

Outputs include a **coverage dashboard** (including **Swift Charts**), **spoken summary** playback, **PDF export** via the system share sheet (UIKit-based PDF generation), a **WidgetKit** home screen widget fed from **App Group** data, and **MongoDB-backed** session persistence (with an **in-memory fallback** when no database is configured). **Auth0** secures HTTP and WebSocket access when configured. A simple **marketing landing page** lives under `web/`.

---

## Hackathon context & sponsor tracks

Faro was built for **YHack 2026** (team context and prize strategy are captured in [`CONTEXT.md`](./CONTEXT.md)). Official eligibility always depends on the **published Devpost / organizer rules**; the list below is how the project **maps** to the tracks the team targeted.

| Track / prize (as planned in team strategy) | How Faro qualifies |
| --- | --- |
| **Harper — Personal AI Agent (1st)** | End-to-end **agentic** workflow: autonomous multi-step pipeline (risk → coverage → submission → explanation), not a single-shot chatbot. |
| **ElevenLabs (MLH)** | **Conversational AI** intake (live voice agent + WebSocket audio) **and** **TTS** for the spoken summary in the explainer step. |
| **MongoDB (MLH)** | **MongoDB Atlas** (via **Motor**) for session state, step artifacts, and stored audio; **in-memory** degradation when `MONGODB_URI` is unset. |
| **Auth0 (MLH)** | **Auth0.swift** on iOS; **FastAPI** verifies **JWTs** (RS256 via JWKS). Auth is **optional** if `AUTH0_DOMAIN` / `AUTH0_AUDIENCE` are omitted (useful for local hacking). |
| **Built with Zed** | Team used the **Zed** editor during the build (honor-system / process prize—confirm submission requirements). |
| **Best UI/UX** | Polished **SwiftUI** flows, adaptive iPad/iPhone layouts, charts, PDF export, widget, and real-time agent UI. |
| **Grand Prize** | Overall product completeness: native client + backend + real-time streaming + voice + persistence + auth. |

---

## How we built it

### Native iOS & iPadOS (SwiftUI)

The client is a **SwiftUI** app with adaptive layouts for phone and tablet, **WidgetKit** extension, **URLSession** REST clients, **WebSocket** for pipeline progress, **AVFoundation** for microphone capture and audio playback (including ElevenLabs live conversation), and **UIKit**-based PDF rendering for exports. **Swift Charts** powers dashboard visualizations.

### Google Gemini (primary AI)

Gemini drives structured JSON generation across pipeline steps and **post-processes** ElevenLabs transcripts into validated **`IntakeRequest`** payloads. Defaults (overridable via env): `gemini-3-flash-preview` primary, `gemini-2.5-flash` fallback, with timeouts and validation wrappers in code.

### ElevenLabs (voice)

- **Conversational AI** — Backend provisions or reuses a **ConvAI agent**, returns a **signed WebSocket URL** from `POST /conv/start`; the iOS client connects directly to ElevenLabs for bidirectional audio.
- **Text-to-speech** — Explainer step calls the **REST TTS** API; audio is persisted and exposed through `GET /audio/{session_id}`.

### MongoDB Atlas (persistence)

**Motor** (async driver) talks to Atlas when configured. Documents accumulate heterogeneous JSON from each agent step—natural fit for a document store.

### Auth0 (authentication)

**Auth0.swift** (with **JWTDecode** and **SimpleKeychain** transitive dependencies) handles login; the API uses **PyJWT** with **cryptography** for RS256 verification against Auth0’s JWKS.

### LangGraph agent pipeline

Four **sequential** graph nodes mirror the business workflow. Each transition can broadcast **running / complete / error** updates to the client WebSocket.

### Hybrid premium estimation

Deterministic **pricing rules** are blended with model-generated components so premium ranges are **grounded** in policy-type logic rather than pure free-form generation.

### Marketing website

Static landing page: [`web/index.html`](./web/index.html).

---

### Libraries & dependencies

#### Python (`backend/requirements.txt`)

| Package | Version constraint | Role in Faro |
| --- | --- | --- |
| **fastapi** | ≥ 0.111 | HTTP API, dependency injection, OpenAPI docs |
| **uvicorn**\[standard\] | ≥ 0.29 | ASGI server (local dev & process deployment) |
| **websockets** | ≥ 12 | WebSocket stack used with Starlette/FastAPI |
| **langgraph** | ≥ 0.1 | State graph orchestration for the four-step agent |
| **langchain-core** | ≥ 0.2 | Shared abstractions LangGraph builds on |
| **google-genai** | (pinned by pip resolve) | Official **Google Gen AI** client for Gemini |
| **motor** | ≥ 3.4 | Async **MongoDB** driver |
| **httpx** | ≥ 0.27 | Async HTTP for ElevenLabs REST, etc. |
| **pydantic** | ≥ 2.7 | Request/response models & validation |
| **PyJWT**\[crypto\] | ≥ 2.8 | JWT parsing/verification for **Auth0** |
| **python-dotenv** | ≥ 1.0 | Loads `.env` / `.env.local` before other imports |
| **mangum** | ≥ 0.17 | **AWS Lambda** ASGI adapter (optional serverless hosting) |
| **elevenlabs** | ≥ 1.0 | Declared dependency (REST integrations also use **httpx** directly where applicable) |

#### Swift Package Manager (iOS)

Resolved in [`ios/Faro.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`](./ios/Faro.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved):

| Package | Version | Role |
| --- | --- | --- |
| [**Auth0.swift**](https://github.com/auth0/Auth0.swift) | 2.18.0 | OAuth / OIDC login, credentials |
| [**JWTDecode.swift**](https://github.com/auth0/JWTDecode.swift) | 3.3.0 | Decode JWT claims client-side when needed |
| [**SimpleKeychain**](https://github.com/auth0/SimpleKeychain) | 1.3.0 | Secure storage for tokens |

#### Apple frameworks (no SPM)

| Framework | Usage |
| --- | --- |
| **SwiftUI** | App structure, screens, design system |
| **WidgetKit** + **App Groups** | Home screen widget + shared `UserDefaults` |
| **Charts** | Coverage / premium visualizations |
| **AVFoundation** | Audio session, capture, playback |
| **UIKit** | PDF generation (`UIGraphicsPDFRenderer`), share sheet bridges |

---

## Repository layout

| Path | Contents |
| --- | --- |
| `ios/` | Xcode project, **Faro** app target, **FaroWidget** extension |
| `backend/` | **FastAPI** app (`main.py`), `agent/` pipeline, `tests/` |
| `web/` | Static marketing **`index.html`** |
| `run-backend.sh` | Repo-root wrapper → `backend/run.sh` |
| `CONTEXT.md` | YHack strategy, timeline, demo script |

---

## API surface

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/intake` | Start pipeline from structured intake |
| `POST` | `/conv/start` | Mint `session_id` + ElevenLabs **signed WebSocket URL** |
| `POST` | `/conv/complete` | Submit voice transcript → Gemini extraction → same pipeline as intake |
| `WebSocket` | `/ws/{session_id}` | Stream step status updates |
| `GET` | `/results/{session_id}` | Full structured results |
| `POST` | `/results/{session_id}/chat` | Coverage Q&A / follow-up chat (server-side) |
| `GET` | `/status/{session_id}` | Compact status (e.g. widget / polling) |
| `GET` | `/audio/{session_id}` | Spoken summary audio (when generated) |
| `GET` | `/health` | Liveness check (**unauthenticated**) |

Protected routes use **Bearer** tokens when Auth0 env vars are set; WebSockets enforce the same policy via connection-time checks.

---

## Prerequisites

- **macOS** with **Xcode** (for iOS 17+ targets; project deployment target is **17.0**).
- **Python 3.12+** recommended (matches team venv; 3.11 may work if dependencies resolve).
- **MongoDB Atlas** cluster **or** run without `MONGODB_URI` for in-memory mode.
- API keys: **Gemini** (`GEMINI_API_KEY` or `GOOGLE_API_KEY`), **ElevenLabs** (voice + TTS), optional **Auth0** tenant.

---

## Installation

### Backend

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -U pip
.venv/bin/pip install -r requirements.txt
cp .env.example .env
# Edit .env — never commit real secrets
```

The helper script `backend/run.sh` auto-creates `.venv` on first launch if missing (or uses `.uenv` if you already have that directory).

### iOS

1. Open **`ios/Faro.xcodeproj`** in Xcode.
2. Let Swift Package Manager resolve **Auth0** packages.
3. Select the **Faro** scheme; set your **Signing & Capabilities** team.
4. For the widget, align signing and **App Groups** with the main app (see below).

### Marketing page

Open `web/index.html` in a browser, or serve the folder with any static file server.

---

## Configuration (environment variables)

Backend loads `backend/.env` then `backend/.env.local` (see `main.py`).

| Variable | Required | Description |
| --- | --- | --- |
| `GEMINI_API_KEY` | For real AI | Primary Gemini API key |
| `GOOGLE_API_KEY` | Alternative to above | Recognized by `agent/llm.py` as an alias |
| `GEMINI_PRIMARY_MODEL` | No | Default `gemini-3-flash-preview` |
| `GEMINI_FALLBACK_MODEL` | No | Default `gemini-2.5-flash` |
| `GEMINI_TEMPERATURE` | No | Default `0.1` |
| `GEMINI_JSON_TIMEOUT_SECONDS` | No | Structured call timeout |
| `GEMINI_TEXT_TIMEOUT_SECONDS` | No | Text call timeout |
| `MONGODB_URI` | No | If unset, server uses **in-memory** storage |
| `MONGODB_DB` | No | Database name (default `faro`) |
| `ELEVENLABS_API_KEY` | For voice / TTS | ConvAI signing + TTS |
| `ELEVENLABS_CONV_AGENT_ID` | No | Pin agent id; otherwise server may create/cache one |
| `ELEVENLABS_VOICE_ID` | No | TTS voice override |
| `ELEVENLABS_MODEL_ID` | No | TTS model override |
| `ELEVENLABS_MAX_CHARS` | No | TTS chunk sizing |
| `AUTH0_DOMAIN` | For auth | e.g. `dev-xxx.us.auth0.com` |
| `AUTH0_AUDIENCE` | For auth | API identifier / audience string |
| `PIPELINE_STEP_TIMEOUT_SECONDS` | No | Per-node timeout in LangGraph wrappers (default `40`) |

iOS backend URL: default **`http://localhost:8000`** via `ios/Faro/Info.plist` (adjust for device testing using your machine’s LAN IP).

---

## Local development

### API server

From the **repository root**:

```bash
./run-backend.sh
```

Or directly:

```bash
./backend/run.sh
```

Server listens on **`http://127.0.0.1:8000`**. Interactive docs: **`http://127.0.0.1:8000/docs`**.

### iOS simulator

1. Start the backend (above).
2. Run the **Faro** scheme in Xcode against a simulator.

### Physical iPhone / iPad

Use your Mac’s **LAN IP** in `Info.plist` (or your config pattern) instead of `localhost`, and ensure the device can reach port **8000**.

---

## Testing

```bash
cd backend
.venv/bin/python -m unittest discover -s tests -v
```

(Use `.uenv` instead of `.venv` if that is what you created.)

---

## iOS: Widget & App Groups

1. Use the **same development team** for **Faro** and **FaroWidgetExtension**.
2. Enable **App Groups** on both targets.
3. Shared group identifier: **`group.com.faro.shared`**.

Apple’s free/personal teams can limit certain capabilities; widgets may sign while **App Group** persistence is constrained—test on a paid team when possible.

---

## Challenges we ran into

- **ElevenLabs Conversational AI on iOS** — Bidirectional **WebSocket** audio required careful protocol alignment (initiation messages, format negotiation, echo handling, transcript assembly). Native **AVAudioSession** and converter plumbing added complexity.
- **Auth0** — Redirect URLs, bundle identifiers, API **audience** strings, and JWKS verification must match **exactly** across dashboard, Swift SDK, and FastAPI.
- **Gemini JSON reliability** — Structured outputs need timeouts, **fallback models**, and **Pydantic** validation to survive edge cases under demo pressure.
- **Parallel development** — Swift models and FastAPI contracts evolved together; WebSocket payloads and results schemas had to stay in lockstep.

---

## Accomplishments we're proud of

- **Native SwiftUI** client plus **FastAPI** backend with a **real** multi-step agent, built on a hackathon clock.
- **Live WebSocket agent tracker** so users watch the pipeline progress instead of a static spinner.
- **Two intake modes**—guided form **and** **ElevenLabs** voice—converging on one analysis path.
- **Hybrid pricing logic** plus LLM reasoning for many commercial line types.
- **PDF export**, **TTS summary**, **MongoDB** persistence with graceful degradation, **Auth0** security, and a **widget** surface.

---

## What we learned

- **Defensive LLM engineering** (timeouts, fallback models, strict parsing) is non-negotiable for demos that must not flake.
- **Voice-first UX** is compelling, but **native** real-time audio is a specialty integration—budget time accordingly.
- **Document databases** fit agent pipelines that accumulate nested, evolving JSON per session.
- **Auth0** accelerates security, but cross-platform **JWT** alignment has a learning curve.
- **Streaming UX** (WebSocket progress) dramatically improves perceived quality versus batch-only APIs.

---

## What's next

- **On-device inference** where feasible for privacy-sensitive fields.
- **Carrier integrations** for bindable quotes vs. illustrative estimates.
- **Proactive risk monitoring** via widgets and notifications.
- **Document upload / OCR** for existing policies.
- **Multi-state / multi-location** rules expansion.
- **Broker marketplace** handoff once needs are understood.

---

## License

No license file is present in this repository as of the last update. Add a `LICENSE` file before open-sourcing or redistributing.
