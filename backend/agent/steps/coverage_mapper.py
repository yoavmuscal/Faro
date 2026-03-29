"""
Step 2 — Coverage Mapper
Input:  risk profile from Step 1
Output: coverage requirements list with priority flags
Model:  Gemini 3 Flash with Gemini 2.5 Flash fallback
"""
import json

from models import (
    IntakeRequest,
    normalize_coverage_requirements_payload,
    normalize_risk_profile_payload,
)

from ..llm import generate_validated_json_with_fallback

SYSTEM_PROMPT = """You are a commercial insurance coverage specialist.
Given a business risk profile, you determine exactly which insurance policies are needed.
Always respond with valid JSON only — no markdown, no explanation outside the JSON."""

USER_PROMPT_TEMPLATE = """Given the following business risk profile, map out all relevant insurance coverage requirements.

Risk Profile:
{risk_profile_json}

Business Context:
- Name: {business_name}
- State: {state}
- Employees: {employee_count}
- Annual Revenue: ${annual_revenue:,.0f}

For each applicable policy type, determine:
- required: legally mandated or effectively mandatory for this business
- recommended: strongly advisable given the risk profile
- projected: not needed now, but will be needed at a specific growth trigger

Policy types to evaluate (include all that apply):
- Workers Compensation and Employers Liability
- Commercial General Liability
- Professional Liability (E&O)
- Commercial Auto
- Commercial Property
- Business Owner's Policy (BOP)
- Umbrella / Excess Liability
- Liquor Liability (if applicable)
- Product Liability (if applicable)
- Cyber Liability (if applicable)
- Employment Practices Liability (EPLI)

Return a JSON array:
[
  {{
    "type": "policy name",
    "category": "required" | "recommended" | "projected",
    "trigger_event": "string — only for projected, e.g. 'When headcount exceeds 25'",
    "rationale": "one sentence why",
    "estimated_premium_low": number,
    "estimated_premium_high": number,
    "confidence": 0.0-1.0
  }}
]

Base premium estimates on typical market rates for this business size and state. Use conservative estimates."""


async def run(state: dict) -> dict:
    intake = IntakeRequest.model_validate(state["intake"])
    risk_profile = normalize_risk_profile_payload(state["risk_profile"], intake=intake)
    prompt = USER_PROMPT_TEMPLATE.format(
        risk_profile_json=json.dumps(risk_profile.model_dump(mode="json"), indent=2),
        business_name=intake.business_name,
        state=intake.state,
        employee_count=intake.employee_count,
        annual_revenue=intake.annual_revenue,
    )
    coverage_requirements, llm_meta = await generate_validated_json_with_fallback(
        system=SYSTEM_PROMPT,
        user=prompt,
        validator=lambda parsed: normalize_coverage_requirements_payload(
            parsed,
            intake=intake,
            risk_profile=risk_profile,
        ),
    )

    analysis_meta = dict(state.get("analysis_meta") or {})
    analysis_meta["coverage_mapper"] = llm_meta

    return {
        **state,
        "coverage_requirements": [
            requirement.model_dump(mode="json")
            for requirement in coverage_requirements
        ],
        "analysis_meta": analysis_meta,
    }
