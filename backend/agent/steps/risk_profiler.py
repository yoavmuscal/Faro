"""
Step 1 — Risk Profiler
Input:  raw business description from intake
Output: structured risk profile JSON
Model:  Gemini 3 Flash with Gemini 2.5 Flash fallback
"""

from models import IntakeRequest, normalize_risk_profile_payload, normalize_risk_profile_payload_relaxed

from ..llm import GeminiRoutingError, generate_validated_json_with_fallback


SYSTEM_PROMPT = """You are a commercial insurance risk analyst with deep expertise in small business risk assessment.
You reason carefully and systematically through every risk factor before reaching conclusions.
Always respond with valid JSON only — no markdown, no explanation outside the JSON."""

USER_PROMPT_TEMPLATE = """Analyze the following small business and produce a structured risk profile.

Business: {business_name}
Description: {description}
Employees: {employee_count}
State: {state}
Annual Revenue: ${annual_revenue:,.0f}

Think step by step through:
1. Industry classification and SIC code
2. Primary risk exposures (physical, liability, regulatory)
3. Employee count implications (workers comp thresholds, benefits requirements)
4. State-specific regulatory requirements for this business type in {state}
5. Revenue-based liability exposure
6. Any unusual or elevated risk characteristics

Return a JSON object with this exact structure:
{{
  "industry": "string",
  "sic_code": "string",
  "risk_level": "low" | "medium" | "high",
  "primary_exposures": ["string"],
  "state_requirements": ["string"],
  "employee_implications": ["string"],
  "revenue_exposure": "string",
  "unusual_risks": ["string"],
  "reasoning_summary": "2-3 sentence summary of the overall risk picture"
}}"""


async def run(state: dict) -> dict:
    intake = IntakeRequest.model_validate(state["intake"])
    prompt = USER_PROMPT_TEMPLATE.format(
        business_name=intake.business_name,
        description=intake.description,
        employee_count=intake.employee_count,
        state=intake.state,
        annual_revenue=intake.annual_revenue,
    )
    try:
        risk_profile, llm_meta = await generate_validated_json_with_fallback(
            system=SYSTEM_PROMPT,
            user=prompt,
            validator=lambda parsed: normalize_risk_profile_payload(parsed, intake=intake),
        )
    except GeminiRoutingError as exc:
        risk_profile, llm_meta = await generate_validated_json_with_fallback(
            system=SYSTEM_PROMPT,
            user=prompt,
            validator=lambda parsed: normalize_risk_profile_payload_relaxed(
                parsed, intake=intake
            ),
        )
        llm_meta["risk_profiler_relaxed_fallback"] = True
        llm_meta["strict_risk_profiler_error"] = str(exc)

    analysis_meta = dict(state.get("analysis_meta") or {})
    analysis_meta["risk_profiler"] = llm_meta

    return {
        **state,
        "risk_profile": risk_profile.model_dump(mode="json"),
        "analysis_meta": analysis_meta,
    }
