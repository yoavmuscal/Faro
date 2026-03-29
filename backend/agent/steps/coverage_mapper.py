"""
Step 2 — Coverage Mapper  (hybrid: LLM selection + rules-engine pricing)
Input:  risk profile from Step 1
Output: coverage requirements list with priority flags and deterministic premiums
Model:  Gemini 3 Flash with Gemini 2.5 Flash fallback

The LLM decides WHICH coverages apply, their priority category, rationale, and
trigger events. A deterministic rules engine then overwrites the premium
estimates so numbers are stable and explainable.  When the rules engine has no
formula for a niche coverage type, the LLM estimate is kept as a fallback.
"""
from __future__ import annotations

import json
import logging

from models import (
    CoverageRequirement,
    IntakeRequest,
    RiskProfile,
    normalize_coverage_requirements_payload,
    normalize_risk_profile_payload,
)

from ..llm import GeminiRoutingError, generate_validated_json_with_fallback
from ..pricing_rules import estimate_confidence, estimate_premium

log = logging.getLogger(__name__)

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
- Workers Compensation
- General Liability
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

For premium estimates, provide your best guess based on typical market rates.
These will be cross-checked against an actuarial rules engine for accuracy."""


def _apply_rules_engine(
    requirements: list[CoverageRequirement],
    intake: IntakeRequest,
    risk_profile: RiskProfile | None,
) -> list[CoverageRequirement]:
    """Overlay deterministic premiums onto LLM-selected coverages.

    Strategy:
    - If the rules engine has a formula, use its numbers.
    - If the LLM estimate is within 40% of the rules-engine midpoint,
      blend them (70% rules, 30% LLM) to preserve LLM nuance.
    - If the LLM is wildly off, prefer the rules engine entirely.
    - If there is no rule, keep the LLM estimate as-is.
    """
    enriched: list[CoverageRequirement] = []

    for req in requirements:
        rule_result = estimate_premium(req.type, intake, risk_profile)
        if rule_result is None:
            enriched.append(req)
            continue

        rule_low, rule_high = rule_result
        rule_mid = (rule_low + rule_high) / 2
        llm_mid = (req.estimated_premium_low + req.estimated_premium_high) / 2

        if rule_mid > 0 and abs(llm_mid - rule_mid) / rule_mid <= 0.40:
            blended_low = rule_low * 0.70 + req.estimated_premium_low * 0.30
            blended_high = rule_high * 0.70 + req.estimated_premium_high * 0.30
        else:
            blended_low = rule_low
            blended_high = rule_high

        rules_confidence = estimate_confidence(req.type, intake, risk_profile)
        blended_confidence = min(0.97, rules_confidence * 0.60 + req.confidence * 0.40)

        enriched.append(
            CoverageRequirement(
                type=req.type,
                category=req.category,
                rationale=req.rationale,
                estimated_premium_low=round(blended_low, 2),
                estimated_premium_high=round(blended_high, 2),
                confidence=round(blended_confidence, 2),
                trigger_event=req.trigger_event,
            )
        )
        log.info(
            "Hybrid premium for %s: rules=(%.0f–%.0f) llm=(%.0f–%.0f) → final=(%.0f–%.0f)",
            req.type,
            rule_low, rule_high,
            req.estimated_premium_low, req.estimated_premium_high,
            blended_low, blended_high,
        )

    return enriched


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
    coverage_apply_evidence_filter = True
    try:
        coverage_requirements, llm_meta = await generate_validated_json_with_fallback(
            system=SYSTEM_PROMPT,
            user=prompt,
            validator=lambda parsed: normalize_coverage_requirements_payload(
                parsed,
                intake=intake,
                risk_profile=risk_profile,
                apply_evidence_filter=True,
            ),
        )
        coverage_requirements = _apply_rules_engine(
            coverage_requirements, intake, risk_profile,
        )
        pricing_mode = "hybrid"
    except GeminiRoutingError as exc:
        coverage_requirements, llm_meta = await generate_validated_json_with_fallback(
            system=SYSTEM_PROMPT,
            user=prompt,
            validator=lambda parsed: normalize_coverage_requirements_payload(
                parsed,
                intake=intake,
                risk_profile=risk_profile,
                apply_evidence_filter=False,
            ),
        )
        coverage_apply_evidence_filter = False
        pricing_mode = "llm_only"
        llm_meta["coverage_llm_only_fallback"] = True
        llm_meta["strict_coverage_mapper_error"] = str(exc)

    analysis_meta = dict(state.get("analysis_meta") or {})
    analysis_meta["coverage_mapper"] = {**llm_meta, "pricing_mode": pricing_mode}

    return {
        **state,
        "coverage_requirements": [
            requirement.model_dump(mode="json")
            for requirement in coverage_requirements
        ],
        "coverage_apply_evidence_filter": coverage_apply_evidence_filter,
        "analysis_meta": analysis_meta,
    }
