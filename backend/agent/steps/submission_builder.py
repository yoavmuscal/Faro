"""
Step 3 — Submission Builder
Input:  coverage requirements from Step 2
Output: carrier-ready submission packet as structured JSON, exportable as PDF
Model:  K2 Think V2 (with Claude fallback)
"""
import json
from datetime import date
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
    "business_type": "LLC | Corp | Sole Proprietor | Partnership",
    "years_in_business": number,
    "state_of_incorporation": "string",
    "primary_state_of_operations": "string",
    "mailing_address": "to be completed by applicant",
    "phone": "to be completed by applicant",
    "website": "to be completed by applicant",
    "federal_ein": "to be completed by applicant"
  }},
  "operations": {{
    "description": "2-3 sentence description for underwriter",
    "sic_code": "string",
    "naics_code": "string",
    "full_time_employees": number,
    "part_time_employees": 0,
    "subcontractors": false,
    "annual_revenue": number,
    "annual_payroll": number
  }},
  "loss_history": {{
    "years_reviewed": 3,
    "prior_losses": "to be completed by applicant",
    "currently_insured": "to be completed by applicant"
  }},
  "requested_coverages": [
    {{
      "type": "string",
      "limits": "string",
      "deductible": "string",
      "effective_date": "string",
      "notes": "string"
    }}
  ],
  "underwriter_notes": "string — any special circumstances or risk mitigations the underwriter should know"
}}"""


async def run(state: dict) -> dict:
    intake = state["intake"]
    risk_profile = state["risk_profile"]

    prompt = USER_PROMPT_TEMPLATE.format(
        business_name=intake["business_name"],
        description=intake["description"],
        employee_count=intake["employee_count"],
        state=intake["state"],
        annual_revenue=intake["annual_revenue"],
        risk_summary=risk_profile.get("reasoning_summary", ""),
        coverage_json=json.dumps(state["coverage_requirements"], indent=2),
        today=date.today().isoformat(),
    )
    raw = await chat_with_fallback(system=SYSTEM_PROMPT, user=prompt)
    submission_packet = parse_json_response(raw)
    return {**state, "submission_packet": submission_packet}
