"""
Step 1 — Risk Profiler
Input:  raw business description from intake
Output: structured risk profile JSON
Model:  K2 Think V2 (with Claude fallback)
"""
from ..llm import chat_with_fallback, parse_json_response
from typing import Literal
from pydantic import BaseModel, ValidationError


class RiskProfile(BaseModel):
    industry: str
    sic_code: str
    risk_level: Literal["low", "medium", "high"]
    primary_exposures: list[str]
    state_requirements: list[str]
    employee_implications: list[str]
    revenue_exposure: str
    unusual_risks: list[str]
    reasoning_summary: str


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
    intake = state["intake"]
    prompt = USER_PROMPT_TEMPLATE.format(
        business_name=intake["business_name"],
        description=intake["description"],
        employee_count=intake["employee_count"],
        state=intake["state"],
        annual_revenue=intake["annual_revenue"],
    )
    raw = await chat_with_fallback(system=SYSTEM_PROMPT, user=prompt)
    try:
        parsed = parse_json_response(raw)
        risk_profile = RiskProfile(**parsed)
    except (ValueError, ValidationError) as e:
        raise ValueError(f"Risk profiler failed to parse LLM output: {e}\n\nRaw: {raw}")

    return {**state, "risk_profile": risk_profile.model_dump()}
