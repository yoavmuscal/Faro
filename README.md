# Faro

Faro is a native SwiftUI iOS app with a FastAPI backend that runs an AI-driven commercial insurance workflow. A business owner describes their company in plain English, and Faro generates a risk profile, coverage recommendations, a submission packet, and a plain-English summary.

## What is in the repo

- `ios/`: SwiftUI app, WidgetKit extension, and app-side API clients
- `backend/`: FastAPI server, LangGraph-style pipeline steps, storage helpers, and tests
- `run-backend.sh`: repo-root convenience script for starting the API locally
- `CONTEXT.md`: hackathon plan and product framing

## Architecture

The backend exposes:

- `POST /intake`
- `GET /results/{session_id}`
- `GET /status/{session_id}`
- `GET /audio/{session_id}`
- `WS /ws/{session_id}`

The pipeline currently runs four major steps:

1. `risk_profiler`
2. `coverage_mapper`
3. `submission_builder`
4. `explainer`

The iOS app drives intake, listens for pipeline progress over WebSocket, and renders the final coverage dashboard. The widget reads a shared app-group snapshot written by the main app.

## Local development

### Backend

Create the virtual environment and install dependencies:

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env
```

Start the API from the repo root:

```bash
./run-backend.sh
```

The server runs on `http://127.0.0.1:8000`.

### iOS app

Open:

```text
ios/Faro.xcodeproj
```

Then run the `Faro` scheme in Xcode on an iPhone simulator or device.

The default local backend URL is configured in `ios/Faro/Info.plist` as `http://localhost:8000`.

## Environment variables

See `backend/.env.example`.

Common variables:

- `GEMINI_API_KEY`
- `MONGODB_URI`
- `MONGODB_DB`
- `ELEVENLABS_API_KEY`

MongoDB is optional for local development. The backend can fall back to in-memory storage when MongoDB is not configured.

## Testing

Run backend tests:

```bash
cd backend
.venv/bin/python -m unittest discover -s tests -v
```

## Widget notes

The repo includes a real WidgetKit extension target: `FaroWidgetExtension`.

To use it in Xcode:

1. Select the same development team for `Faro` and `FaroWidgetExtension`.
2. Make sure both targets have the `App Groups` capability enabled.
3. Use the shared group id: `group.com.faro.shared`.

If you are using a Personal Team, widget signing may work while shared app-group data remains limited by Apple account capabilities.
