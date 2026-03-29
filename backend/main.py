from __future__ import annotations

import asyncio
import json
import logging
import uuid
from contextlib import asynccontextmanager
from pathlib import Path

from dotenv import load_dotenv

# Load env before other backend imports so MONGODB_URI, GEMINI_API_KEY, etc. are visible.
_backend_dir = Path(__file__).resolve().parent
load_dotenv(_backend_dir / ".env")
load_dotenv(_backend_dir / ".env.local")

from fastapi import Depends, FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response

from auth import ensure_websocket_allowed, require_auth

from models import (
    IntakeRequest, IntakeResponse,
    ResultsResponse,
    StatusResponse, CoverageStatus,
    ConvStartResponse, ConvCompleteRequest, ConvCompleteResponse,
    StepStatus,
    build_results_response,
    normalize_coverage_requirements_payload,
    normalize_risk_profile_payload,
    normalize_submission_packet_payload,
    CoverageChatRequest,
    CoverageChatResponse,
)
import database as db
from agent.pipeline import run_pipeline

logger = logging.getLogger(__name__)

import agent.elevenlabs_conversation as elevenlabs_conv
from agent.llm import chat_with_fallback


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await db.close()


app = FastAPI(title="Faro Insurance API", lifespan=lifespan)
PIPELINE_TIMEOUT_SECONDS = 180

_api_auth = [Depends(require_auth)]

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten before production
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory WebSocket registry: session_id → WebSocket
_ws_connections: dict[str, WebSocket] = {}


def _wire_value(value):
    return value.value if hasattr(value, "value") else value


def _coverage_requirements_to_storage(coverage_requirements):
    return [
        {
            "type": requirement.type,
            "category": requirement.category.value,
            "rationale": requirement.rationale,
            "estimated_premium_low": requirement.estimated_premium_low,
            "estimated_premium_high": requirement.estimated_premium_high,
            "confidence": requirement.confidence,
            "trigger_event": requirement.trigger_event,
        }
        for requirement in coverage_requirements
    ]


def _normalized_session_fields_from_state(state_snapshot: dict) -> dict:
    intake = IntakeRequest.model_validate(state_snapshot.get("intake") or {})
    payload: dict = {
        "intake": intake.model_dump(mode="json"),
    }
    analysis_meta = state_snapshot.get("analysis_meta")
    if analysis_meta:
        payload["analysis_meta"] = analysis_meta

    risk_profile = None
    if state_snapshot.get("risk_profile") is not None:
        risk_profile = normalize_risk_profile_payload(
            state_snapshot.get("risk_profile"),
            intake=intake,
        )
        payload["risk_profile"] = risk_profile.model_dump(mode="json")

    coverage_requirements = []
    cov_filter_raw = state_snapshot.get("coverage_apply_evidence_filter")
    cov_filter = True if cov_filter_raw is None else bool(cov_filter_raw)
    if state_snapshot.get("coverage_requirements") is not None:
        coverage_requirements = normalize_coverage_requirements_payload(
            state_snapshot.get("coverage_requirements") or [],
            intake=intake,
            risk_profile=risk_profile,
            apply_evidence_filter=cov_filter,
        )
        payload["coverage_requirements"] = _coverage_requirements_to_storage(
            coverage_requirements
        )
    if cov_filter_raw is not None:
        payload["coverage_apply_evidence_filter"] = cov_filter

    if state_snapshot.get("submission_packet") is not None:
        submission_packet = normalize_submission_packet_payload(
            state_snapshot.get("submission_packet"),
            intake=intake,
            risk_profile=risk_profile,
            coverage_requirements=coverage_requirements,
        )
        payload["submission_packet"] = submission_packet.model_dump(mode="json")

    if state_snapshot.get("plain_english_summary") is not None:
        payload["plain_english_summary"] = state_snapshot.get("plain_english_summary")
    if state_snapshot.get("voice_url") is not None:
        payload["voice_url"] = state_snapshot.get("voice_url") or ""
    if state_snapshot.get("submission_packet_url") is not None:
        payload["submission_packet_url"] = state_snapshot.get("submission_packet_url") or ""

    return payload


# ── POST /intake ──────────────────────────────────────────────────────────────

@app.post("/intake", response_model=IntakeResponse, dependencies=_api_auth)
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
    last_failure: dict[str, str] | None = None
    step_failures: dict[str, str] = {}
    existing_session = await db.get_session(session_id) or {}
    persisted_analysis_meta = dict(existing_session.get("analysis_meta") or {})

    async def broadcast(update: dict, *, state_snapshot: dict | None = None):
        nonlocal last_failure
        update_payload = {
            "step": _wire_value(update["step"]),
            "status": _wire_value(update["status"]),
            "summary": update["summary"],
        }
        await db.save_session(
            session_id,
            {
                f"step_{update_payload['step']}": update_payload,
                "pipeline_status": (
                    "error"
                    if update_payload["status"] == StepStatus.error.value
                    else "running"
                ),
            },
        )

        if state_snapshot and update_payload["status"] == StepStatus.complete.value:
            try:
                partial_payload = _normalized_session_fields_from_state(state_snapshot)
                partial_analysis_meta = dict(partial_payload.get("analysis_meta") or {})
                persisted_analysis_meta.update(partial_analysis_meta)
                if persisted_analysis_meta:
                    partial_payload["analysis_meta"] = persisted_analysis_meta
                partial_payload["pipeline_status"] = "running"
                await db.save_session(session_id, partial_payload)
            except Exception as exc:
                logger.warning(
                    "Failed to persist partial pipeline state for %s/%s: %s",
                    session_id,
                    update_payload["step"],
                    exc,
                )

        if update_payload["status"] == StepStatus.error.value:
            last_failure = {
                "step": update_payload["step"],
                "error": update_payload["summary"],
            }
            step_failures[update_payload["step"]] = update_payload["summary"]
            await db.save_session(
                session_id,
                {
                    "last_failed_step": update_payload["step"],
                    "step_failures": step_failures,
                },
            )

        ws = _ws_connections.get(session_id)
        if ws:
            try:
                await ws.send_text(json.dumps(update_payload))
            except Exception:
                pass

    try:
        final_state = await asyncio.wait_for(
            run_pipeline(session_id, intake, broadcast),
            timeout=PIPELINE_TIMEOUT_SECONDS,
        )
        cov_evidence_filter = final_state.get("coverage_apply_evidence_filter")
        results = build_results_response(
            intake_payload=intake,
            risk_profile_payload=final_state.get("risk_profile"),
            coverage_requirements_payload=final_state.get("coverage_requirements"),
            submission_packet_payload=final_state.get("submission_packet"),
            plain_english_summary=final_state.get("plain_english_summary"),
            voice_url=final_state.get("voice_url"),
            submission_packet_url=final_state.get("submission_packet_url"),
            coverage_apply_evidence_filter=cov_evidence_filter,
        )
        _cov_apply = True if cov_evidence_filter is None else bool(cov_evidence_filter)
        await db.save_session(session_id, {
            "pipeline_status": "complete",
            "risk_profile": (
                results.risk_profile.model_dump(mode="json")
                if results.risk_profile else None
            ),
            "coverage_requirements": _coverage_requirements_to_storage(
                normalize_coverage_requirements_payload(
                    final_state.get("coverage_requirements") or [],
                    intake=IntakeRequest.model_validate(intake),
                    risk_profile=results.risk_profile,
                    apply_evidence_filter=_cov_apply,
                )
            ),
            "coverage_apply_evidence_filter": _cov_apply,
            "submission_packet": (
                results.submission_packet.model_dump(mode="json")
                if results.submission_packet else None
            ),
            "plain_english_summary": results.plain_english_summary,
            "voice_url": results.voice_summary_url,
            "submission_packet_url": results.submission_packet_url,
            "analysis_meta": {
                **persisted_analysis_meta,
                **dict(final_state.get("analysis_meta") or {}),
            },
            "step_failures": step_failures,
        })
    except asyncio.TimeoutError:
        await db.save_session(
            session_id,
            {
                "pipeline_status": "error",
                "error": f"Pipeline timed out after {PIPELINE_TIMEOUT_SECONDS}s",
                "last_failed_step": (last_failure or {}).get("step"),
                "step_failures": step_failures,
            },
        )
    except Exception as e:
        await db.save_session(
            session_id,
            {
                "pipeline_status": "error",
                "error": str(e),
                "last_failed_step": (last_failure or {}).get("step"),
                "step_failures": step_failures,
            },
        )


# ── POST /conv/start ──────────────────────────────────────────────────────────

@app.post("/conv/start", response_model=ConvStartResponse, dependencies=_api_auth)
async def conv_start():
    session_id = str(uuid.uuid4())
    # Generate the signed WebRTC URL for this session
    signed_url = await elevenlabs_conv.create_conversation_token(session_id)
    return ConvStartResponse(session_id=session_id, signed_url=signed_url)


# ── POST /conv/complete ───────────────────────────────────────────────────────

@app.post("/conv/complete", response_model=ConvCompleteResponse, dependencies=_api_auth)
async def conv_complete(body: ConvCompleteRequest):
    session_id = body.session_id

    # Require at least one real user turn before running the pipeline.
    user_turns = [t for t in body.transcript if t.role == "user"]
    if not user_turns:
        raise HTTPException(
            status_code=422,
            detail="No user speech found in transcript. Please complete the voice conversation first."
        )

    # 1. Ask Gemini to extract the 5 standard fields from the transcript
    try:
        raw_intake_dict, intake_meta = await elevenlabs_conv.extract_intake_from_transcript(
            body.transcript
        )
        intake_req = IntakeRequest(**raw_intake_dict)
    except Exception as exc:
        logger.warning("Voice intake extraction failed for session %s: %s", session_id, exc)
        raise HTTPException(
            status_code=422,
            detail=(
                "We couldn't confidently extract your business details from the conversation. "
                "Please retry voice intake or enter the details manually."
            ),
        ) from exc

    # 3. Save to DB just like standard /intake
    await db.save_session(session_id, {
        "session_id": session_id,
        "intake": intake_req.model_dump(),
        "pipeline_status": "pending",
        "analysis_meta": {"conv_intake": intake_meta},
    })
    
    # 4. Fire the pipeline background task
    asyncio.create_task(_run_pipeline_task(session_id, intake_req.model_dump()))
    
    return ConvCompleteResponse(session_id=session_id)


# ── WebSocket /ws/{session_id} ────────────────────────────────────────────────

@app.websocket("/ws/{session_id}")
async def websocket_endpoint(websocket: WebSocket, session_id: str):
    await websocket.accept()
    if not await ensure_websocket_allowed(websocket):
        return
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

@app.get("/results/{session_id}", response_model=ResultsResponse, dependencies=_api_auth)
async def get_results(session_id: str):
    session = await db.get_session(session_id)
    if not session:
        raise HTTPException(404, "Session not found")
    pipeline_status = session.get("pipeline_status")
    if pipeline_status == "error":
        raise HTTPException(500, session.get("error", "Pipeline failed"))
    if pipeline_status != "complete":
        raise HTTPException(202, "Pipeline not yet complete")

    try:
        return build_results_response(
            intake_payload=session.get("intake") or {},
            risk_profile_payload=session.get("risk_profile"),
            coverage_requirements_payload=session.get("coverage_requirements"),
            submission_packet_payload=session.get("submission_packet"),
            plain_english_summary=session.get("plain_english_summary"),
            voice_url=session.get("voice_url"),
            submission_packet_url=session.get("submission_packet_url"),
            coverage_apply_evidence_filter=session.get("coverage_apply_evidence_filter"),
        )
    except Exception as exc:
        raise HTTPException(500, f"Stored results are malformed: {exc}") from exc


# ── POST /results/{session_id}/chat ───────────────────────────────────────────

@app.post("/results/{session_id}/chat", response_model=CoverageChatResponse, dependencies=_api_auth)
async def coverage_chat(session_id: str, body: CoverageChatRequest):
    """
    Ask follow-up questions about a completed analysis (plain-text LLM reply).
    """
    session = await db.get_session(session_id)
    if not session:
        raise HTTPException(404, "Session not found")
    if session.get("pipeline_status") != "complete":
        raise HTTPException(400, "Analysis is not complete yet")

    intake = session.get("intake") or {}
    summary = (session.get("plain_english_summary") or "")[:6000]
    risk_raw = session.get("risk_profile")
    cov_raw = session.get("coverage_requirements") or []

    lines: list[str] = []
    for item in cov_raw[:50]:
        if not isinstance(item, dict):
            continue
        t = item.get("type") or ""
        lo = item.get("estimated_premium_low")
        hi = item.get("estimated_premium_high")
        cat = item.get("category")
        lines.append(f"- {t} ({cat}): ${lo}–${hi}")

    risk_blob = ""
    if risk_raw is not None:
        try:
            risk_blob = json.dumps(risk_raw, default=str)[:8000]
        except (TypeError, ValueError):
            risk_blob = str(risk_raw)[:8000]

    system = f"""You are Faro, a concise insurance assistant. You are helping a user who already ran a coverage analysis for their business.
Use only the session context below. If they ask something unrelated or you lack data, say so briefly.
Intake (JSON): {json.dumps(intake, default=str)[:4000]}
Plain-English summary: {summary}
Risk profile (JSON): {risk_blob}
Coverage lines:
{chr(10).join(lines)}

Reply in plain English. Keep answers short unless the user asks for detail."""

    user_msg = body.message.strip()
    try:
        reply = await chat_with_fallback(system, user_msg)
    except Exception as exc:
        logger.exception("coverage_chat failed")
        raise HTTPException(500, f"Assistant could not respond: {exc}") from exc

    reply = (reply or "").strip()
    if not reply:
        reply = "I couldn’t generate a reply. Please try again."
    return CoverageChatResponse(reply=reply)


# ── GET /status/{session_id} ──────────────────────────────────────────────────

@app.get("/status/{session_id}", response_model=StatusResponse, dependencies=_api_auth)
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

    try:
        intake = IntakeRequest.model_validate(session.get("intake") or {})
        risk_profile = (
            normalize_risk_profile_payload(session.get("risk_profile"), intake=intake)
            if session.get("risk_profile") is not None
            else None
        )
        coverage = normalize_coverage_requirements_payload(
            session.get("coverage_requirements") or [],
            intake=intake,
            risk_profile=risk_profile,
        )
    except Exception:
        return StatusResponse(
            status=CoverageStatus.unknown,
            message="Coverage results need to be refreshed.",
        )
    if coverage:
        return StatusResponse(
            status=CoverageStatus.healthy,
            next_renewal_days=365,
            message=f"Coverage analysis complete. {len(coverage)} policy recommendations identified.",
        )
    return StatusResponse(
        status=CoverageStatus.gap_detected,
        message="Coverage analysis completed but did not identify usable policy recommendations.",
    )


# ── GET /audio/{session_id} ──────────────────────────────────────────────────

@app.get("/audio/{session_id}", dependencies=_api_auth)
async def get_audio(session_id: str):
    audio_bytes = await db.get_audio(session_id)
    if not audio_bytes:
        raise HTTPException(404, "Audio not found")
    return Response(content=audio_bytes, media_type="audio/mpeg")


# ── Health check ──────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok"}
