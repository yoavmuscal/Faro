"""
Step 3 — Submission Builder
Input:  coverage requirements from Step 2
Output: carrier-ready submission packet as structured JSON, exportable as PDF
Model:  Gemini 3 Flash with Gemini 2.5 Flash fallback
"""
from datetime import date
import json

from models import (
    IntakeRequest,
    normalize_submission_packet_payload,
    normalize_coverage_requirements_payload,
    normalize_risk_profile_payload,
)

from ..llm import generate_validated_json_with_fallback

SYSTEM_PROMPT = """You are an expert commercial insurance broker who prepares carrier submission packets.
You know exactly what information underwriters need. Be thorough and precise.
Always respond with valid JSON only."""

USER_PROMPT_TEMPLATE = """Build a complete carrier submission packet for the following business.

Business Profile:
- Name: {business_name}
- Description: {description}
- Employees: {employee_count}
- State: {state}
- Annual Revenue: ${annual_revenue:,.0f}

Risk Profile Summary: {risk_summary}

Requested Coverage:
{coverage_json}

Generate a carrier-ready submission packet. This is what a broker sends to underwriters.
Include all standard fields that commercial insurance carriers require.

Return JSON with this structure:
{{
  "submission_date": "{today}",
  "applicant": {{
    "legal_name": "string",
    "dba": "string or null",
    "business_type": "LLC | Corp | Sole Proprietor | Partnership | null",
    "years_in_business": number | null,
    "state_of_incorporation": "string or null",
    "primary_state_of_operations": "string",
    "mailing_address": "string or null",
    "phone": "string or null",
    "website": "string or null",
    "federal_ein": "string or null"
  }},
  "operations": {{
    "description": "2-3 sentence description for underwriter",
    "sic_code": "string",
    "naics_code": "string or null",
    "employees": {{
      "full_time": number,
      "part_time": number,
      "total": number
    }},
    "revenue": {{
      "annual": number,
      "projected_growth": "string or null"
    }},
    "payroll": {{
      "annual": number | null
    }},
    "subcontractors": {{
      "used": true | false | null,
      "details": "string or null"
    }}
  }},
  "loss_history": [
    {{
      "year": 2024 | null,
      "type": "string",
      "amount": number | null,
      "description": "string"
    }}
  ],
  "requested_coverages": [
    {{
      "type": "string",
      "limits": "string",
      "deductible": "string",
      "effective_date": "YYYY-MM-DD",
      "notes": "string"
    }}
  ],
  "underwriter_notes": ["string"]
}}

Important:
- `loss_history` MUST be an empty array `[]` because no actual loss data was provided by the applicant. Do NOT invent or fabricate any loss events.
- `underwriter_notes` must be an array of strings
- `employees`, `revenue`, `payroll`, and `subcontractors` must be nested objects exactly as shown"""


async def run(state: dict) -> dict:
    intake = IntakeRequest.model_validate(state["intake"])
    risk_profile = normalize_risk_profile_payload(state["risk_profile"], intake=intake)
    cov_filter = state.get("coverage_apply_evidence_filter", True)
    coverage_requirements = normalize_coverage_requirements_payload(
        state["coverage_requirements"],
        intake=intake,
        risk_profile=risk_profile,
        apply_evidence_filter=cov_filter,
    )

    prompt = USER_PROMPT_TEMPLATE.format(
        business_name=intake.business_name,
        description=intake.description,
        employee_count=intake.employee_count,
        state=intake.state,
        annual_revenue=intake.annual_revenue,
        risk_summary=risk_profile.reasoning_summary,
        coverage_json=json.dumps(
            [item.model_dump(mode="json") for item in coverage_requirements],
            indent=2,
        ),
        today=date.today().isoformat(),
    )
    submission_packet, llm_meta = await generate_validated_json_with_fallback(
        system=SYSTEM_PROMPT,
        user=prompt,
        validator=lambda parsed: normalize_submission_packet_payload(
            parsed,
            intake=intake,
            risk_profile=risk_profile,
            coverage_requirements=coverage_requirements,
        ),
    )

    analysis_meta = dict(state.get("analysis_meta") or {})
    analysis_meta["submission_builder"] = llm_meta

    return {
        **state,
        "submission_packet": submission_packet.model_dump(mode="json"),
        "analysis_meta": analysis_meta,
    }
