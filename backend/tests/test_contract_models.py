import unittest

from models import (
    CoverageCategory,
    IntakeRequest,
    build_results_response,
    normalize_coverage_requirements_payload,
    normalize_risk_profile_payload,
    normalize_submission_packet_payload,
    validate_coverage_requirements_payload,
    validate_risk_profile_payload,
)


class ContractModelTests(unittest.TestCase):
    def setUp(self) -> None:
        self.intake = IntakeRequest(
            business_name="Sunny Days Daycare",
            description="Licensed daycare serving children ages 2-12.",
            employee_count=12,
            state="NJ",
            annual_revenue=800000,
        )
        self.risk_profile = validate_risk_profile_payload(
            {
                "industry": "Child Day Care Services",
                "sic_code": "8351",
                "risk_level": "high",
                "primary_exposures": ["Child injury", "Abuse and molestation"],
                "state_requirements": ["Workers compensation coverage is required in NJ."],
                "employee_implications": ["12 employees requires workers compensation."],
                "revenue_exposure": "Moderate customer injury exposure.",
                "unusual_risks": ["Background check compliance"],
                "reasoning_summary": "Childcare operations carry elevated bodily injury and abuse exposure.",
            }
        )

    def test_coverage_requirements_are_normalized(self) -> None:
        requirements = validate_coverage_requirements_payload(
            [
                {
                    "type": "Workers Compensation",
                    "category": "required",
                    "rationale": "Required for employees in New Jersey.",
                    "estimated_premium_low": "4200",
                    "estimated_premium_high": "2400",
                    "confidence": 0.94,
                    "trigger_event": "should be cleared",
                },
                {
                    "type": "Employment Practices Liability",
                    "category": "projected",
                    "rationale": "Likely needed as the team scales.",
                    "estimated_premium_low": 900,
                    "estimated_premium_high": 1400,
                    "confidence": 0.61,
                },
            ]
        )

        self.assertEqual(len(requirements), 2)
        self.assertEqual(requirements[0].category, CoverageCategory.required)
        self.assertEqual(requirements[0].estimated_premium_low, 2400.0)
        self.assertEqual(requirements[0].estimated_premium_high, 4200.0)
        self.assertIsNone(requirements[0].trigger_event)
        self.assertEqual(requirements[1].category, CoverageCategory.projected)
        self.assertIsNotNone(requirements[1].trigger_event)

    def test_coverage_guardrails_dedupe_strip_and_repair(self) -> None:
        requirements = normalize_coverage_requirements_payload(
            [
                {
                    "type": "General Liability",
                    "category": "recommended",
                    "rationale": "Base liability coverage.",
                    "estimated_premium_low": 1200,
                    "estimated_premium_high": 2400,
                    "confidence": 0.7,
                },
                {
                    "type": "General Liability",
                    "category": "required",
                    "rationale": "Required by the venue contract.",
                    "estimated_premium_low": 1000,
                    "estimated_premium_high": 2600,
                    "confidence": 0.86,
                },
                {
                    "type": "Commercial Auto",
                    "category": "recommended",
                    "rationale": "Suggested by the model without evidence.",
                    "estimated_premium_low": 2000,
                    "estimated_premium_high": 3200,
                    "confidence": 0.55,
                },
            ],
            intake=self.intake,
            risk_profile=self.risk_profile,
        )

        names = [item.type for item in requirements]
        self.assertEqual(names.count("General Liability"), 1)
        self.assertIn("Workers Compensation", names)
        self.assertNotIn("Commercial Auto", names)
        general_liability = next(item for item in requirements if item.type == "General Liability")
        self.assertEqual(general_liability.category, CoverageCategory.required)

    def test_risk_profile_guardrails_reject_thin_payload(self) -> None:
        with self.assertRaises(ValueError):
            normalize_risk_profile_payload(
                {
                    "industry": "Daycare",
                    "sic_code": "8351",
                    "risk_level": "medium",
                    "primary_exposures": [],
                    "state_requirements": [],
                    "employee_implications": [],
                    "revenue_exposure": "Moderate",
                    "unusual_risks": [],
                    "reasoning_summary": "Looks fine.",
                },
                intake=self.intake,
            )

    def test_legacy_submission_packet_is_normalized_to_nested_shape(self) -> None:
        requirements = validate_coverage_requirements_payload(
            [
                {
                    "type": "General Liability",
                    "category": "required",
                    "rationale": "Protects against third-party injury claims.",
                    "estimated_premium_low": 1500,
                    "estimated_premium_high": 2500,
                    "confidence": 0.88,
                }
            ]
        )

        packet = normalize_submission_packet_payload(
            {
                "submission_date": "2026-03-28",
                "applicant": {
                    "legal_name": "Sunny Days Daycare LLC",
                    "business_type": "LLC",
                },
                "operations": {
                    "description": "Licensed daycare facility.",
                    "sic_code": "8351",
                    "full_time_employees": 10,
                    "part_time_employees": 2,
                    "annual_revenue": 800000,
                    "annual_payroll": 480000,
                    "subcontractors": False,
                },
                "loss_history": {
                    "years_reviewed": 3,
                    "prior_losses": "No prior losses reported.",
                    "currently_insured": "Currently insured with regional carrier.",
                },
                "underwriter_notes": "Background checks completed for all staff.",
            },
            intake=self.intake,
            risk_profile=self.risk_profile,
            coverage_requirements=requirements,
        )

        self.assertEqual(packet.applicant.legal_name, "Sunny Days Daycare LLC")
        self.assertEqual(packet.operations.employees.total, 12)
        self.assertEqual(packet.operations.revenue.annual, 800000.0)
        self.assertEqual(packet.operations.payroll.annual, 480000.0)
        self.assertEqual(packet.operations.subcontractors.used, False)
        self.assertEqual(len(packet.loss_history), 2)
        self.assertEqual(packet.underwriter_notes, ["Background checks completed for all staff."])
        self.assertEqual(packet.requested_coverages[0].type, "General Liability")

    def test_results_response_uses_authoritative_schema(self) -> None:
        response = build_results_response(
            intake_payload=self.intake.model_dump(mode="json"),
            risk_profile_payload=self.risk_profile.model_dump(mode="json"),
            coverage_requirements_payload=[
                {
                    "type": "Cyber Liability",
                    "category": "recommended",
                    "rationale": "Protects stored parent and child data.",
                    "estimated_premium_low": 700,
                    "estimated_premium_high": 1300,
                    "confidence": 0.77,
                }
            ],
            submission_packet_payload={
                "applicant": {"legal_name": "Sunny Days Daycare LLC"},
                "operations": {
                    "description": "Child daycare operations.",
                    "sic_code": "8351",
                    "employees": {"full_time": 10, "part_time": 2, "total": 12},
                    "revenue": {"annual": 800000},
                },
                "requested_coverages": [
                    {
                        "type": "Cyber Liability",
                        "policy_product_name": "Cyber / Privacy Liability",
                        "standard_forms": ["ACORD 127", "ACORD 131"],
                        "typical_markets": "Admitted cyber markets and E&S for tougher classes.",
                        "limits": "$1M",
                        "deductible": "$1,000",
                        "effective_date": "2026-03-28",
                        "notes": "Recommended based on data handling.",
                    }
                ],
                "underwriter_notes": ["Stores sensitive family data."],
            },
            plain_english_summary="You should carry cyber liability to protect customer data.",
            voice_url="/audio/test-session",
            submission_packet_url="",
        )

        cyber = next(item for item in response.coverage_options if item.type == "Cyber Liability")
        self.assertEqual(cyber.description, "Protects stored parent and child data.")
        self.assertEqual(cyber.category, CoverageCategory.recommended)
        self.assertTrue(
            any(item.type == "Workers Compensation" for item in response.coverage_options)
        )
        self.assertEqual(response.submission_packet.operations.employees.total, 12)
        self.assertEqual(response.voice_summary_url, "/audio/test-session")
        sub_cov = response.submission_packet.requested_coverages[0]
        self.assertEqual(sub_cov.policy_product_name, "Cyber / Privacy Liability")
        self.assertEqual(sub_cov.standard_forms, ["ACORD 127", "ACORD 131"])
        self.assertIn("E&S", sub_cov.typical_markets or "")


if __name__ == "__main__":
    unittest.main()
