from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum


# ── Intake ────────────────────────────────────────────────────────────────────

class IntakeRequest(BaseModel):
    business_name: str
    description: str
    employee_count: int
    state: str
    annual_revenue: float


class IntakeResponse(BaseModel):
    session_id: str


# ── WebSocket messages ─────────────────────────────────────────────────────────

class AgentStep(str, Enum):
    risk_profiler = "risk_profiler"
    coverage_mapper = "coverage_mapper"
    submission_builder = "submission_builder"
    explainer = "explainer"


class StepStatus(str, Enum):
    running = "running"
    complete = "complete"
    error = "error"


class StepUpdate(BaseModel):
    step: AgentStep
    status: StepStatus
    summary: str


# ── Results ───────────────────────────────────────────────────────────────────

class CoverageCategory(str, Enum):
    required = "required"
    recommended = "recommended"
    projected = "projected"


class CoverageOption(BaseModel):
    type: str
    description: str
    estimated_premium_low: float
    estimated_premium_high: float
    confidence: float = Field(ge=0.0, le=1.0)
    category: CoverageCategory
    trigger_event: Optional[str] = None  # only set for "projected" coverage


class ResultsResponse(BaseModel):
    coverage_options: list[CoverageOption]
    submission_packet_url: str
    voice_summary_url: str
    risk_profile: Optional[dict] = None
    submission_packet: Optional[dict] = None
    plain_english_summary: Optional[str] = None


# ── Status (widget) ───────────────────────────────────────────────────────────

class CoverageStatus(str, Enum):
    healthy = "healthy"
    gap_detected = "gap_detected"
    renewal_soon = "renewal_soon"
    unknown = "unknown"


class StatusResponse(BaseModel):
    status: CoverageStatus
    next_renewal_days: Optional[int] = None
    message: str


# ── Internal pipeline state ───────────────────────────────────────────────────

class PipelineState(BaseModel):
    session_id: str
    intake: IntakeRequest
    risk_profile: Optional[dict] = None
    coverage_requirements: Optional[list[dict]] = None
    submission_packet: Optional[dict] = None
    plain_english_summary: Optional[str] = None
    voice_url: Optional[str] = None
    submission_packet_url: Optional[str] = None
    error: Optional[str] = None


# ── Conversational AI intake ──────────────────────────────────────────────────

class ConvStartResponse(BaseModel):
    """Returned by POST /conv/start — hands the signed ElevenLabs WS URL to iOS."""
    session_id: str
    signed_url: str   # wss://… — iOS connects directly; no audio proxied by us


class ConvTranscriptTurn(BaseModel):
    role: str          # "agent" | "user"
    message: str


class ConvCompleteRequest(BaseModel):
    """iOS sends the finished transcript + the session_id it got from /conv/start."""
    session_id: str
    transcript: list[ConvTranscriptTurn]


class ConvCompleteResponse(BaseModel):
    session_id: str
