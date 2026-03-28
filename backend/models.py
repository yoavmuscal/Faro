from __future__ import annotations

from datetime import date
from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class FaroBaseModel(BaseModel):
    model_config = ConfigDict(
        extra="ignore",
        populate_by_name=True,
        str_strip_whitespace=True,
    )


_PLACEHOLDER_STRINGS = {
    "-",
    "n/a",
    "na",
    "not provided",
    "to be completed",
    "to be completed by applicant",
    "to be supplied",
    "to be supplied by applicant",
    "tbd",
    "unknown",
}


def _clean_string(value: Any) -> Optional[str]:
    if value is None:
        return None
    if isinstance(value, bool):
        return "Yes" if value else "No"
    text = str(value).strip()
    return text or None


def _meaningful_string(value: Any) -> Optional[str]:
    text = _clean_string(value)
    if not text:
        return None
    if text.casefold() in _PLACEHOLDER_STRINGS:
        return None
    return text


def _string_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        items = (_meaningful_string(item) for item in value)
        return [item for item in items if item]
    item = _meaningful_string(value)
    return [item] if item else []


def _optional_int(value: Any) -> Optional[int]:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return None


def _optional_float(value: Any) -> Optional[float]:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        return float(value)
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip().replace(",", "")
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def _optional_bool(value: Any) -> Optional[bool]:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        return value
    text = str(value).strip().casefold()
    if text in {"true", "yes", "y", "1"}:
        return True
    if text in {"false", "no", "n", "0"}:
        return False
    return None


def _model_or_none(model_cls, payload: dict[str, Any]) -> Optional[Any]:
    cleaned = {key: value for key, value in payload.items() if value is not None}
    if not cleaned:
        return None
    return model_cls.model_validate(cleaned)


# ── Intake ────────────────────────────────────────────────────────────────────


class IntakeRequest(FaroBaseModel):
    business_name: str
    description: str
    employee_count: int
    state: str
    annual_revenue: float
    contact_first_name: Optional[str] = None
    contact_middle_name: Optional[str] = None
    contact_last_name: Optional[str] = None
    contact_email: Optional[str] = None


class IntakeResponse(FaroBaseModel):
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


class StepUpdate(FaroBaseModel):
    step: AgentStep
    status: StepStatus
    summary: str


# ── Results ───────────────────────────────────────────────────────────────────


class CoverageCategory(str, Enum):
    required = "required"
    recommended = "recommended"
    projected = "projected"


class RiskProfile(FaroBaseModel):
    industry: str
    sic_code: str
    risk_level: str
    primary_exposures: list[str]
    state_requirements: list[str]
    employee_implications: list[str]
    revenue_exposure: str
    unusual_risks: list[str]
    reasoning_summary: str

    @field_validator(
        "primary_exposures",
        "state_requirements",
        "employee_implications",
        "unusual_risks",
        mode="before",
    )
    @classmethod
    def _normalize_string_list(cls, value: Any) -> list[str]:
        return _string_list(value)

    @field_validator("risk_level", mode="before")
    @classmethod
    def _normalize_risk_level(cls, value: Any) -> str:
        text = (_clean_string(value) or "medium").casefold()
        if text not in {"low", "medium", "high"}:
            return "medium"
        return text


class CoverageRequirement(FaroBaseModel):
    type: str
    category: CoverageCategory
    rationale: str
    estimated_premium_low: float = 0
    estimated_premium_high: float = 0
    confidence: float = Field(default=0.8, ge=0.0, le=1.0)
    trigger_event: Optional[str] = None

    @field_validator("category", mode="before")
    @classmethod
    def _normalize_category(cls, value: Any) -> str:
        if isinstance(value, CoverageCategory):
            return value.value
        text = str(value).strip().lower().replace(" ", "_").replace("-", "_")
        valid = {c.value for c in CoverageCategory}
        if text in valid:
            return text
        return CoverageCategory.recommended.value

    @field_validator("type", mode="before")
    @classmethod
    def _normalize_type(cls, value: Any) -> str:
        text = _meaningful_string(value)
        if not text:
            raise ValueError("coverage requirement type is required")
        return text

    @field_validator("rationale", mode="before")
    @classmethod
    def _normalize_rationale(cls, value: Any) -> str:
        return _meaningful_string(value) or "Coverage recommended based on the business profile."

    @field_validator("estimated_premium_low", "estimated_premium_high", mode="before")
    @classmethod
    def _normalize_premium(cls, value: Any) -> float:
        premium = _optional_float(value)
        return premium if premium is not None else 0.0

    @field_validator("trigger_event", mode="before")
    @classmethod
    def _normalize_trigger(cls, value: Any) -> Optional[str]:
        return _meaningful_string(value)

    @model_validator(mode="after")
    def _normalize_fields(self) -> "CoverageRequirement":
        self.estimated_premium_low = max(0.0, self.estimated_premium_low)
        self.estimated_premium_high = max(0.0, self.estimated_premium_high)
        if self.estimated_premium_high < self.estimated_premium_low:
            self.estimated_premium_low, self.estimated_premium_high = (
                self.estimated_premium_high,
                self.estimated_premium_low,
            )
        if self.category == CoverageCategory.projected:
            self.trigger_event = (
                self.trigger_event
                or "When the business grows materially or adds new exposure."
            )
        else:
            self.trigger_event = None
        return self


class CoverageOption(FaroBaseModel):
    type: str
    description: str
    estimated_premium_low: float = 0
    estimated_premium_high: float = 0
    confidence: float = Field(default=0.8, ge=0.0, le=1.0)
    category: CoverageCategory
    trigger_event: Optional[str] = None

    @field_validator("category", mode="before")
    @classmethod
    def _normalize_category(cls, value: Any) -> str:
        if isinstance(value, CoverageCategory):
            return value.value
        text = str(value).strip().lower().replace(" ", "_").replace("-", "_")
        valid = {c.value for c in CoverageCategory}
        if text in valid:
            return text
        return CoverageCategory.recommended.value

    @field_validator("estimated_premium_low", "estimated_premium_high", mode="before")
    @classmethod
    def _normalize_premium(cls, value: Any) -> float:
        if value is None:
            return 0.0
        try:
            return float(value)
        except (TypeError, ValueError):
            return 0.0

    @classmethod
    def from_requirement(cls, requirement: CoverageRequirement) -> "CoverageOption":
        return cls(
            type=requirement.type,
            description=requirement.rationale,
            estimated_premium_low=requirement.estimated_premium_low,
            estimated_premium_high=requirement.estimated_premium_high,
            confidence=requirement.confidence,
            category=requirement.category,
            trigger_event=requirement.trigger_event,
        )


class SubmissionApplicant(FaroBaseModel):
    legal_name: Optional[str] = None
    dba: Optional[str] = None
    business_type: Optional[str] = None
    years_in_business: Optional[int] = None
    state_of_incorporation: Optional[str] = None
    primary_state_of_operations: Optional[str] = None
    mailing_address: Optional[str] = None
    phone: Optional[str] = None
    website: Optional[str] = None
    federal_ein: Optional[str] = None


class SubmissionEmployeeInfo(FaroBaseModel):
    full_time: Optional[int] = None
    part_time: Optional[int] = None
    total: Optional[int] = None

    @field_validator("full_time", "part_time", "total", mode="before")
    @classmethod
    def _normalize_counts(cls, value: Any) -> Optional[int]:
        return _optional_int(value)

    @model_validator(mode="after")
    def _compute_total(self) -> "SubmissionEmployeeInfo":
        if self.total is None and (self.full_time is not None or self.part_time is not None):
            self.total = (self.full_time or 0) + (self.part_time or 0)
        return self


class SubmissionRevenueInfo(FaroBaseModel):
    annual: Optional[float] = None
    projected_growth: Optional[str] = None

    @field_validator("annual", mode="before")
    @classmethod
    def _normalize_annual(cls, value: Any) -> Optional[float]:
        return _optional_float(value)


class SubmissionPayrollInfo(FaroBaseModel):
    annual: Optional[float] = None

    @field_validator("annual", mode="before")
    @classmethod
    def _normalize_annual(cls, value: Any) -> Optional[float]:
        return _optional_float(value)


class SubmissionSubcontractorInfo(FaroBaseModel):
    used: Optional[bool] = None
    details: Optional[str] = None

    @field_validator("used", mode="before")
    @classmethod
    def _normalize_used(cls, value: Any) -> Optional[bool]:
        return _optional_bool(value)


class SubmissionOperations(FaroBaseModel):
    description: Optional[str] = None
    sic_code: Optional[str] = None
    naics_code: Optional[str] = None
    employees: Optional[SubmissionEmployeeInfo] = None
    revenue: Optional[SubmissionRevenueInfo] = None
    payroll: Optional[SubmissionPayrollInfo] = None
    subcontractors: Optional[SubmissionSubcontractorInfo] = None


class SubmissionLoss(FaroBaseModel):
    year: Optional[int] = None
    type: Optional[str] = None
    amount: Optional[float] = None
    description: Optional[str] = None

    @field_validator("year", mode="before")
    @classmethod
    def _normalize_year(cls, value: Any) -> Optional[int]:
        return _optional_int(value)

    @field_validator("amount", mode="before")
    @classmethod
    def _normalize_amount(cls, value: Any) -> Optional[float]:
        return _optional_float(value)


class SubmissionRequestedCoverage(FaroBaseModel):
    type: Optional[str] = None
    limits: Optional[str] = None
    deductible: Optional[str] = None
    effective_date: Optional[str] = None
    notes: Optional[str] = None


class SubmissionPacket(FaroBaseModel):
    submission_date: Optional[str] = None
    applicant: Optional[SubmissionApplicant] = None
    operations: Optional[SubmissionOperations] = None
    loss_history: list[SubmissionLoss] = Field(default_factory=list)
    requested_coverages: list[SubmissionRequestedCoverage] = Field(default_factory=list)
    underwriter_notes: list[str] = Field(default_factory=list)


class ResultsResponse(FaroBaseModel):
    coverage_options: list[CoverageOption]
    submission_packet_url: str
    voice_summary_url: str
    risk_profile: Optional[RiskProfile] = None
    submission_packet: Optional[SubmissionPacket] = None
    plain_english_summary: Optional[str] = None


# ── Status (widget) ───────────────────────────────────────────────────────────


class CoverageStatus(str, Enum):
    healthy = "healthy"
    gap_detected = "gap_detected"
    renewal_soon = "renewal_soon"
    unknown = "unknown"


class StatusResponse(FaroBaseModel):
    status: CoverageStatus
    next_renewal_days: Optional[int] = None
    message: str


# ── Internal pipeline state ───────────────────────────────────────────────────


class PipelineState(FaroBaseModel):
    session_id: str
    intake: IntakeRequest
    risk_profile: Optional[RiskProfile] = None
    coverage_requirements: Optional[list[CoverageRequirement]] = None
    submission_packet: Optional[SubmissionPacket] = None
    plain_english_summary: Optional[str] = None
    voice_url: Optional[str] = None
    submission_packet_url: Optional[str] = None
    error: Optional[str] = None


# ── Conversational AI intake ──────────────────────────────────────────────────

class ConvStartResponse(FaroBaseModel):
    """Returned by POST /conv/start — hands the signed ElevenLabs WS URL to iOS."""
    session_id: str
    signed_url: str   # wss://… — iOS connects directly; no audio proxied by us


class ConvTranscriptTurn(FaroBaseModel):
    role: str          # "agent" | "user"
    message: str


class ConvCompleteRequest(FaroBaseModel):
    """iOS sends the finished transcript + the session_id it got from /conv/start."""
    session_id: str
    transcript: list[ConvTranscriptTurn]


class ConvCompleteResponse(FaroBaseModel):
    session_id: str


def validate_risk_profile_payload(payload: Any) -> RiskProfile:
    return RiskProfile.model_validate(payload)


def validate_coverage_requirements_payload(payload: Any) -> list[CoverageRequirement]:
    if payload is None:
        return []
    if not isinstance(payload, list):
        raise ValueError("coverage requirements must be a JSON array")
    return [CoverageRequirement.model_validate(item) for item in payload]


def _default_limits_for_coverage(coverage_type: str) -> str:
    name = coverage_type.casefold()
    if "workers compensation" in name:
        return "Statutory"
    if "umbrella" in name or "excess" in name:
        return "$1M excess"
    if "auto" in name:
        return "$1M combined single limit"
    if "property" in name:
        return "Replacement cost"
    if "professional liability" in name or "e&o" in name:
        return "$1M per claim"
    if "cyber" in name:
        return "$1M"
    return "$1M per occurrence / $2M aggregate"


def _default_deductible_for_coverage(coverage_type: str) -> str:
    name = coverage_type.casefold()
    if "workers compensation" in name:
        return "N/A"
    if "property" in name or "cyber" in name:
        return "$1,000"
    return "$0"


def _normalize_loss_history(payload: Any) -> list[SubmissionLoss]:
    if payload is None:
        return []

    if isinstance(payload, list):
        return [SubmissionLoss.model_validate(item) for item in payload]

    if not isinstance(payload, dict):
        raise ValueError("submission packet loss_history must be an array or object")

    normalized: list[SubmissionLoss] = []
    prior_losses = _meaningful_string(payload.get("prior_losses"))
    currently_insured = _meaningful_string(payload.get("currently_insured"))
    years_reviewed = _optional_int(payload.get("years_reviewed"))

    if prior_losses:
        normalized.append(
            SubmissionLoss(
                year=None,
                type="Prior Losses",
                amount=None,
                description=prior_losses,
            )
        )

    if currently_insured:
        description = currently_insured
        if years_reviewed is not None:
            description = f"{description} ({years_reviewed}-year review)"
        normalized.append(
            SubmissionLoss(
                year=None,
                type="Current Insurance",
                amount=None,
                description=description,
            )
        )

    return normalized


def _normalize_requested_coverages(
    payload: Any,
    coverage_requirements: list[CoverageRequirement],
) -> list[SubmissionRequestedCoverage]:
    if isinstance(payload, list) and payload:
        return [SubmissionRequestedCoverage.model_validate(item) for item in payload]

    return [
        SubmissionRequestedCoverage(
            type=requirement.type,
            limits=_default_limits_for_coverage(requirement.type),
            deductible=_default_deductible_for_coverage(requirement.type),
            effective_date=date.today().isoformat(),
            notes=requirement.rationale,
        )
        for requirement in coverage_requirements
        if requirement.category != CoverageCategory.projected
    ]


def _normalize_underwriter_notes(payload: Any, risk_profile: Optional[RiskProfile]) -> list[str]:
    notes = _string_list(payload)
    if notes:
        return notes
    if risk_profile and risk_profile.unusual_risks:
        return risk_profile.unusual_risks
    if risk_profile and risk_profile.reasoning_summary:
        return [risk_profile.reasoning_summary]
    return []


def normalize_submission_packet_payload(
    payload: Any,
    *,
    intake: IntakeRequest,
    risk_profile: Optional[RiskProfile],
    coverage_requirements: list[CoverageRequirement],
) -> SubmissionPacket:
    raw = payload if isinstance(payload, dict) else {}

    applicant_raw = raw.get("applicant") if isinstance(raw.get("applicant"), dict) else {}
    operations_raw = raw.get("operations") if isinstance(raw.get("operations"), dict) else {}

    employee_block_raw = operations_raw.get("employees")
    if isinstance(employee_block_raw, dict):
        employees = SubmissionEmployeeInfo.model_validate(employee_block_raw)
    else:
        employees = _model_or_none(
            SubmissionEmployeeInfo,
            {
                "full_time": operations_raw.get("full_time_employees"),
                "part_time": operations_raw.get("part_time_employees"),
                "total": operations_raw.get("total_employees"),
            },
        )

    revenue_block_raw = operations_raw.get("revenue")
    if isinstance(revenue_block_raw, dict):
        revenue = SubmissionRevenueInfo.model_validate(revenue_block_raw)
    else:
        revenue = _model_or_none(
            SubmissionRevenueInfo,
            {
                "annual": operations_raw.get("annual_revenue"),
                "projected_growth": operations_raw.get("projected_growth"),
            },
        )

    payroll_block_raw = operations_raw.get("payroll")
    if isinstance(payroll_block_raw, dict):
        payroll = SubmissionPayrollInfo.model_validate(payroll_block_raw)
    else:
        payroll = _model_or_none(
            SubmissionPayrollInfo,
            {"annual": operations_raw.get("annual_payroll")},
        )

    subcontractors_raw = operations_raw.get("subcontractors")
    if isinstance(subcontractors_raw, dict):
        subcontractors = SubmissionSubcontractorInfo.model_validate(subcontractors_raw)
    else:
        subcontractors = _model_or_none(
            SubmissionSubcontractorInfo,
            {
                "used": subcontractors_raw,
                "details": None if isinstance(subcontractors_raw, bool) else subcontractors_raw,
            },
        )

    applicant = _model_or_none(
        SubmissionApplicant,
        {
            "legal_name": applicant_raw.get("legal_name") or intake.business_name,
            "dba": applicant_raw.get("dba"),
            "business_type": applicant_raw.get("business_type"),
            "years_in_business": applicant_raw.get("years_in_business"),
            "state_of_incorporation": applicant_raw.get("state_of_incorporation") or intake.state,
            "primary_state_of_operations": applicant_raw.get("primary_state_of_operations") or intake.state,
            "mailing_address": applicant_raw.get("mailing_address"),
            "phone": applicant_raw.get("phone"),
            "website": applicant_raw.get("website"),
            "federal_ein": applicant_raw.get("federal_ein"),
        },
    )

    operations = _model_or_none(
        SubmissionOperations,
        {
            "description": operations_raw.get("description") or intake.description,
            "sic_code": operations_raw.get("sic_code") or (risk_profile.sic_code if risk_profile else None),
            "naics_code": operations_raw.get("naics_code"),
            "employees": employees.model_dump(mode="json") if employees else None,
            "revenue": revenue.model_dump(mode="json") if revenue else {"annual": intake.annual_revenue},
            "payroll": payroll.model_dump(mode="json") if payroll else None,
            "subcontractors": subcontractors.model_dump(mode="json") if subcontractors else None,
        },
    )

    return SubmissionPacket(
        submission_date=_clean_string(raw.get("submission_date")) or date.today().isoformat(),
        applicant=applicant,
        operations=operations,
        loss_history=_normalize_loss_history(raw.get("loss_history")),
        requested_coverages=_normalize_requested_coverages(
            raw.get("requested_coverages"),
            coverage_requirements,
        ),
        underwriter_notes=_normalize_underwriter_notes(raw.get("underwriter_notes"), risk_profile),
    )


def build_results_response(
    *,
    intake_payload: Any,
    risk_profile_payload: Any,
    coverage_requirements_payload: Any,
    submission_packet_payload: Any,
    plain_english_summary: Any,
    voice_url: Any,
    submission_packet_url: Any,
) -> ResultsResponse:
    intake = IntakeRequest.model_validate(intake_payload)
    risk_profile = (
        validate_risk_profile_payload(risk_profile_payload)
        if risk_profile_payload is not None
        else None
    )
    coverage_requirements = validate_coverage_requirements_payload(coverage_requirements_payload)
    submission_packet = normalize_submission_packet_payload(
        submission_packet_payload,
        intake=intake,
        risk_profile=risk_profile,
        coverage_requirements=coverage_requirements,
    )

    return ResultsResponse(
        coverage_options=[
            CoverageOption.from_requirement(requirement)
            for requirement in coverage_requirements
        ],
        submission_packet_url=_clean_string(submission_packet_url) or "",
        voice_summary_url=_clean_string(voice_url) or "",
        risk_profile=risk_profile,
        submission_packet=submission_packet,
        plain_english_summary=_clean_string(plain_english_summary),
    )
