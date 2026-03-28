"""
Step 3 — Submission Builder
Input:  coverage requirements from Step 2
Output: carrier-ready submission packet as structured JSON, exportable as PDF
Model:  K2 Think V2 (with Claude fallback)
"""
import json
from datetime import date

from pydantic import ValidationError

from models import (
    IntakeRequest,
    normalize_submission_packet_payload,
    validate_coverage_requirements_payload,
    validate_risk_profile_payload,
)

from ..llm import chat_with_fallback, parse_json_response

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
- `loss_history` must be an array, not an object
- `underwriter_notes` must be an array of strings
- `employees`, `revenue`, `payroll`, and `subcontractors` must be nested objects exactly as shown"""


async def run(state: dict) -> dict:
    intake = IntakeRequest.model_validate(state["intake"])
    risk_profile = validate_risk_profile_payload(state["risk_profile"])
    coverage_requirements = validate_coverage_requirements_payload(
        state["coverage_requirements"]
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
    raw = await chat_with_fallback(system=SYSTEM_PROMPT, user=prompt)
    try:
        parsed = parse_json_response(raw)
        submission_packet = normalize_submission_packet_payload(
            parsed,
            intake=intake,
            risk_profile=risk_profile,
            coverage_requirements=coverage_requirements,
        )
    except (ValueError, ValidationError, json.JSONDecodeError) as e:
        snippet = (raw[:500] + "…") if isinstance(raw, str) and len(raw) > 500 else raw
        raise ValueError(f"Submission builder failed to parse LLM output: {e}\n\nRaw: {snippet!r}")

    return {
        **state,
        "submission_packet": submission_packet.model_dump(mode="json"),
    }
