import unittest
from unittest.mock import AsyncMock, patch

from agent import llm


class GeminiRouterTests(unittest.IsolatedAsyncioTestCase):
    async def test_primary_success(self) -> None:
        with patch(
            "agent.llm._generate_once",
            new=AsyncMock(return_value=('{"answer": "ok"}', 42)),
        ):
            value, meta = await llm.generate_validated_json_with_fallback(
                system="system",
                user="user",
                validator=lambda payload: payload,
            )

        self.assertEqual(value["answer"], "ok")
        self.assertEqual(meta["model_used"], llm.PRIMARY_MODEL)
        self.assertIsNone(meta["fallback_reason"])
        self.assertTrue(meta["parse_ok"])
        self.assertTrue(meta["validation_ok"])

    async def test_primary_timeout_then_fallback_success(self) -> None:
        with patch(
            "agent.llm._generate_once",
            new=AsyncMock(
                side_effect=[
                    llm._AttemptFailure("timeout", "primary timed out"),
                    ('{"answer": "fallback"}', 31),
                ]
            ),
        ):
            value, meta = await llm.generate_validated_json_with_fallback(
                system="system",
                user="user",
                validator=lambda payload: payload,
            )

        self.assertEqual(value["answer"], "fallback")
        self.assertEqual(meta["model_used"], llm.FALLBACK_MODEL)
        self.assertEqual(meta["fallback_reason"], "timeout")

    async def test_primary_invalid_json_then_fallback_success(self) -> None:
        with patch(
            "agent.llm._generate_once",
            new=AsyncMock(
                side_effect=[
                    ("not-json", 14),
                    ('{"answer": "rescued"}', 28),
                ]
            ),
        ):
            value, meta = await llm.generate_validated_json_with_fallback(
                system="system",
                user="user",
                validator=lambda payload: payload,
            )

        self.assertEqual(value["answer"], "rescued")
        self.assertEqual(meta["model_used"], llm.FALLBACK_MODEL)
        self.assertEqual(meta["fallback_reason"], "parse_error")

    async def test_both_models_fail_with_useful_error(self) -> None:
        with patch(
            "agent.llm._generate_once",
            new=AsyncMock(
                side_effect=[
                    llm._AttemptFailure("timeout", "primary timed out"),
                    llm._AttemptFailure("transport_error", "fallback transport failed"),
                ]
            ),
        ):
            with self.assertRaises(llm.GeminiRoutingError) as ctx:
                await llm.generate_validated_json_with_fallback(
                    system="system",
                    user="user",
                    validator=lambda payload: payload,
                )

        self.assertEqual(len(ctx.exception.attempts), 2)
        self.assertEqual(ctx.exception.attempts[0]["error_kind"], "timeout")
        self.assertEqual(ctx.exception.attempts[1]["error_kind"], "transport_error")


if __name__ == "__main__":
    unittest.main()
