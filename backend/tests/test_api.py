import unittest
from unittest.mock import AsyncMock, Mock, patch

from fastapi.testclient import TestClient

import main


class ApiEndpointTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)

    def tearDown(self) -> None:
        self.client.close()

    def _complete_session(self) -> dict:
        return {
            "session_id": "session-123",
            "pipeline_status": "complete",
            "intake": {
                "business_name": "Sunny Days Daycare",
                "description": "Licensed daycare serving children ages 2-12.",
                "employee_count": 12,
                "state": "NJ",
                "annual_revenue": 800000,
            },
            "risk_profile": {
                "industry": "Child Day Care Services",
                "sic_code": "8351",
                "risk_level": "high",
                "primary_exposures": ["Child injury", "Abuse and molestation"],
                "state_requirements": ["Workers compensation coverage is required in NJ."],
                "employee_implications": ["12 employees requires workers compensation."],
                "revenue_exposure": "Moderate customer injury exposure.",
                "unusual_risks": ["Background check compliance"],
                "reasoning_summary": "Childcare operations carry elevated bodily injury and abuse exposure.",
            },
            "coverage_requirements": [
                {
                    "type": "General Liability",
                    "category": "recommended",
                    "rationale": "Broad liability coverage.",
                    "estimated_premium_low": 1400,
                    "estimated_premium_high": 2400,
                    "confidence": 0.78,
                },
                {
                    "type": "General Liability",
                    "category": "required",
                    "rationale": "Required by landlord contract.",
                    "estimated_premium_low": 1200,
                    "estimated_premium_high": 2600,
                    "confidence": 0.88,
                },
                {
                    "type": "Commercial Auto",
                    "category": "recommended",
                    "rationale": "Model hallucination without vehicle evidence.",
                    "estimated_premium_low": 2000,
                    "estimated_premium_high": 3200,
                    "confidence": 0.51,
                },
            ],
            "submission_packet": {
                "applicant": {"legal_name": "Sunny Days Daycare LLC"},
                "operations": {
                    "description": "Child daycare operations.",
                    "sic_code": "8351",
                    "employees": {"full_time": 10, "part_time": 2, "total": 12},
                    "revenue": {"annual": 800000},
                },
                "underwriter_notes": ["Stores sensitive child records."],
            },
            "plain_english_summary": "Coverage review ready.",
            "voice_url": "",
            "submission_packet_url": "",
        }

    def test_intake_creates_session_and_schedules_work(self) -> None:
        async def fake_save_session(*args, **kwargs):
            return None

        def fake_create_task(coro):
            coro.close()
            return Mock()

        with patch.object(main.db, "save_session", new=AsyncMock(side_effect=fake_save_session)) as save_mock, patch.object(
            main.asyncio,
            "create_task",
            side_effect=fake_create_task,
        ) as task_mock:
            response = self.client.post(
                "/intake",
                json={
                    "business_name": "Sunny Days Daycare",
                    "description": "Licensed daycare serving children ages 2-12.",
                    "employee_count": 12,
                    "state": "NJ",
                    "annual_revenue": 800000,
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertIn("session_id", response.json())
        save_mock.assert_awaited()
        task_mock.assert_called_once()

    def test_results_returns_normalized_contract(self) -> None:
        with patch.object(
            main.db,
            "get_session",
            new=AsyncMock(return_value=self._complete_session()),
        ):
            response = self.client.get("/results/session-123")

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        names = [item["type"] for item in payload["coverage_options"]]
        self.assertIn("Workers Compensation", names)
        self.assertEqual(names.count("General Liability"), 1)
        self.assertNotIn("Commercial Auto", names)
        self.assertEqual(payload["voice_summary_url"], "")
        requested = payload["submission_packet"]["requested_coverages"]
        self.assertEqual(requested[0]["policy_name"], "Commercial General Liability (CGL)")
        self.assertIn("ACORD 126 Commercial General Liability Section", requested[0]["application_forms"])

    def test_status_reflects_pending_complete_and_error(self) -> None:
        with patch.object(
            main.db,
            "get_session",
            new=AsyncMock(return_value={"pipeline_status": "pending"}),
        ):
            pending = self.client.get("/status/pending-session")
        self.assertEqual(pending.status_code, 200)
        self.assertEqual(pending.json()["status"], "unknown")

        with patch.object(
            main.db,
            "get_session",
            new=AsyncMock(return_value=self._complete_session()),
        ):
            complete = self.client.get("/status/complete-session")
        self.assertEqual(complete.status_code, 200)
        self.assertEqual(complete.json()["status"], "healthy")

        with patch.object(
            main.db,
            "get_session",
            new=AsyncMock(return_value={"pipeline_status": "error", "error": "boom"}),
        ):
            failed = self.client.get("/status/error-session")
        self.assertEqual(failed.status_code, 200)
        self.assertEqual(failed.json()["status"], "gap_detected")

    def test_conv_complete_rejects_incomplete_extraction(self) -> None:
        with patch.object(
            main.elevenlabs_conv,
            "extract_intake_from_transcript",
            new=AsyncMock(side_effect=ValueError("missing fields")),
        ):
            response = self.client.post(
                "/conv/complete",
                json={
                    "session_id": "voice-123",
                    "transcript": [{"role": "user", "message": "I run a business"}],
                },
            )

        self.assertEqual(response.status_code, 422)
        self.assertIn("couldn't confidently extract", response.json()["detail"].lower())


if __name__ == "__main__":
    unittest.main()
