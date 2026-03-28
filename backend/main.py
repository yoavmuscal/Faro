import asyncio
import json
import uuid
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from dotenv import load_dotenv

from models import (
    IntakeRequest, IntakeResponse,
    ResultsResponse, CoverageOption, CoverageCategory,
    StatusResponse, CoverageStatus,
    StepUpdate,
    ConvStartResponse, ConvCompleteRequest, ConvCompleteResponse,
)
import database as db
from agent.pipeline import run_pipeline
import agent.elevenlabs_conversation as elevenlabs_conv

# Load backend-local environment variables for local development.
load_dotenv(Path(__file__).with_name(".env"))
load_dotenv(Path(__file__).with_name(".env.local"))


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await db.close()


app = FastAPI(title="Faro Insurance API", lifespan=lifespan)
PIPELINE_TIMEOUT_SECONDS = 180

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten before production
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory WebSocket registry: session_id → WebSocket
_ws_connections: dict[str, WebSocket] = {}


# ── POST /intake ──────────────────────────────────────────────────────────────

@app.post("/intake", response_model=IntakeResponse)
async def intake(body: IntakeRequest):
    session_id = str(uuid.uuid4())
    await db.save_session(session_id, {
        "session_id": session_id,
        "intake": body.model_dump(),
        "pipeline_status": "pending",
    })
    # Fire-and-forget: pipeline runs in background, pushes to WebSocket
    asyncio.create_task(_run_pipeline_task(session_id, body.model_dump()))
    return IntakeResponse(session_id=session_id)


async def _run_pipeline_task(session_id: str, intake: dict):
    async def broadcast(update: dict):
        await db.save_session(session_id, {f"step_{update['step']}": update})
        ws = _ws_connections.get(session_id)
        if ws:
            try:
                await ws.send_text(json.dumps(update))
            except Exception:
                pass

    try:
        final_state = await asyncio.wait_for(
            run_pipeline(session_id, intake, broadcast),
            timeout=PIPELINE_TIMEOUT_SECONDS,
        )
        await db.save_session(session_id, {
            "pipeline_status": "complete",
            "risk_profile": final_state.get("risk_profile"),
            "coverage_requirements": final_state.get("coverage_requirements"),
            "submission_packet": final_state.get("submission_packet"),
            "plain_english_summary": final_state.get("plain_english_summary"),
            "voice_url": final_state.get("voice_url"),
        })
    except asyncio.TimeoutError:
        await db.save_session(
            session_id,
            {
                "pipeline_status": "error",
                "error": f"Pipeline timed out after {PIPELINE_TIMEOUT_SECONDS}s",
            },
        )
    except Exception as e:
        await db.save_session(session_id, {"pipeline_status": "error", "error": str(e)})


# ── POST /conv/start ──────────────────────────────────────────────────────────

@app.post("/conv/start", response_model=ConvStartResponse)
async def conv_start():
    session_id = str(uuid.uuid4())
    # Generate the signed WebRTC URL for this session
    signed_url = await elevenlabs_conv.create_conversation_token(session_id)
    return ConvStartResponse(session_id=session_id, signed_url=signed_url)


# ── POST /conv/complete ───────────────────────────────────────────────────────

@app.post("/conv/complete", response_model=ConvCompleteResponse)
async def conv_complete(body: ConvCompleteRequest):
    session_id = body.session_id
    
    # 1. Ask Gemini to extract the 5 standard fields from the transcript
    raw_intake_dict = await elevenlabs_conv.extract_intake_from_transcript(body.transcript)
    
    # 2. Convert to the standard IntakeRequest
    try:
        intake_req = IntakeRequest(**raw_intake_dict)
    except Exception as e:
        logger.error(f"Failed to parse gemini output into IntakeRequest: {e}")
        # fallback defaults so we don't crash
        intake_req = IntakeRequest(
            business_name=raw_intake_dict.get("business_name", "Unknown Business"),
            description=raw_intake_dict.get("description", "Not specified"),
            employee_count=1,
            state="NY",
            annual_revenue=0.0
        )

    # 3. Save to DB just like standard /intake
    await db.save_session(session_id, {
        "session_id": session_id,
        "intake": intake_req.model_dump(),
        "pipeline_status": "pending",
    })
    
    # 4. Fire the pipeline background task
    asyncio.create_task(_run_pipeline_task(session_id, intake_req.model_dump()))
    
    return ConvCompleteResponse(session_id=session_id)


# ── WebSocket /ws/{session_id} ────────────────────────────────────────────────

@app.websocket("/ws/{session_id}")
async def websocket_endpoint(websocket: WebSocket, session_id: str):
    await websocket.accept()
    _ws_connections[session_id] = websocket

    # Replay any steps already completed (race condition guard)
    session = await db.get_session(session_id)
    if session:
        for key, value in session.items():
            if key.startswith("step_"):
                await websocket.send_text(json.dumps(value))

    try:
        while True:
            await websocket.receive_text()  # keep alive; client sends pings
    except WebSocketDisconnect:
        pass
    finally:
        _ws_connections.pop(session_id, None)


# ── GET /results/{session_id} ─────────────────────────────────────────────────

@app.get("/results/{session_id}", response_model=ResultsResponse)
async def get_results(session_id: str):
    session = await db.get_session(session_id)
    if not session:
        raise HTTPException(404, "Session not found")
    pipeline_status = session.get("pipeline_status")
    if pipeline_status == "error":
        raise HTTPException(500, session.get("error", "Pipeline failed"))
    if pipeline_status != "complete":
        raise HTTPException(202, "Pipeline not yet complete")

    _VALID_CATEGORIES = {"required", "recommended", "projected"}
    coverage_options = [
        CoverageOption(
            type=c["type"],
            description=c.get("rationale", ""),
            estimated_premium_low=c.get("estimated_premium_low", 0),
            estimated_premium_high=c.get("estimated_premium_high", 0),
            confidence=c.get("confidence", 0.8),
            category=CoverageCategory(
                c.get("category", "recommended")
                if c.get("category") in _VALID_CATEGORIES
                else "recommended"
            ),
            trigger_event=c.get("trigger_event"),
        )
        for c in (session.get("coverage_requirements") or [])
    ]

    return ResultsResponse(
        coverage_options=coverage_options,
        submission_packet_url=session.get("submission_packet_url", ""),
        voice_summary_url=session.get("voice_url", ""),
        risk_profile=session.get("risk_profile"),
        submission_packet=session.get("submission_packet"),
        plain_english_summary=session.get("plain_english_summary"),
    )


# ── GET /status/{session_id} ──────────────────────────────────────────────────

@app.get("/status/{session_id}", response_model=StatusResponse)
async def get_status(session_id: str):
    session = await db.get_session(session_id)
    if not session:
        return StatusResponse(status=CoverageStatus.unknown, message="No coverage data found")

    pipeline_status = session.get("pipeline_status", "pending")
    if pipeline_status == "error":
        return StatusResponse(
            status=CoverageStatus.gap_detected,
            message=f"Analysis failed: {session.get('error', 'unknown error')}",
        )
    if pipeline_status != "complete":
        return StatusResponse(status=CoverageStatus.unknown, message="Analysis in progress...")

    # Simple heuristic: check if any required coverages were found
    coverage = session.get("coverage_requirements") or []
    required_count = sum(1 for c in coverage if c.get("category") == "required")

    if required_count > 0:
        return StatusResponse(
            status=CoverageStatus.healthy,
            next_renewal_days=365,
            message=f"Coverage analysis complete. {required_count} required policies identified.",
        )
    return StatusResponse(status=CoverageStatus.unknown, message="Coverage review recommended")


# ── GET /audio/{session_id} ──────────────────────────────────────────────────

@app.get("/audio/{session_id}")
async def get_audio(session_id: str):
    audio_bytes = await db.get_audio(session_id)
    if not audio_bytes:
        raise HTTPException(404, "Audio not found")
    return Response(content=audio_bytes, media_type="audio/mpeg")


# ── Health check ──────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok"}
