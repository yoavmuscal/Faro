"""
LangGraph pipeline — 4 sequential steps.
Streams step status to a WebSocket connection as each node completes.
"""
import asyncio
import os
from typing import Awaitable, Callable
from langgraph.graph import StateGraph, END

from .steps import risk_profiler, coverage_mapper, submission_builder, explainer
from models import AgentStep, StepStatus

STEP_TIMEOUT_SECONDS = float(os.environ.get("PIPELINE_STEP_TIMEOUT_SECONDS", "40"))


# ── Graph node wrappers ───────────────────────────────────────────────────────

def make_node(
    step_module,
    step_name: AgentStep,
    broadcast: Callable[..., Awaitable[None]],
):
    async def node(state: dict) -> dict:
        await broadcast({"step": step_name, "status": StepStatus.running, "summary": f"Running {step_name}..."})
        try:
            new_state = await asyncio.wait_for(
                step_module.run(state),
                timeout=STEP_TIMEOUT_SECONDS,
            )
            summary = _extract_summary(step_name, new_state)
            await broadcast(
                {"step": step_name, "status": StepStatus.complete, "summary": summary},
                state_snapshot=new_state,
            )
            return new_state
        except asyncio.TimeoutError as exc:
            message = f"{step_name} timed out after {STEP_TIMEOUT_SECONDS:.0f}s"
            await broadcast(
                {"step": step_name, "status": StepStatus.error, "summary": message},
                state_snapshot=state,
            )
            raise TimeoutError(message) from exc
        except Exception as e:
            await broadcast(
                {"step": step_name, "status": StepStatus.error, "summary": str(e)},
                state_snapshot=state,
            )
            raise

    node.__name__ = step_name
    return node


def _extract_summary(step: AgentStep, state: dict) -> str:
    if step == AgentStep.risk_profiler:
        rp = state.get("risk_profile", {})
        return f"Risk level: {rp.get('risk_level', 'assessed')}. {rp.get('reasoning_summary', '')}"
    if step == AgentStep.coverage_mapper:
        reqs = state.get("coverage_requirements", [])
        required = [c["type"] for c in reqs if c.get("category") == "required"]
        return f"Found {len(reqs)} applicable policies. Required: {', '.join(required) or 'none'}."
    if step == AgentStep.submission_builder:
        return "Carrier-ready submission packet generated."
    if step == AgentStep.explainer:
        return "Plain-English summary ready. Audio synthesis complete."
    return "Step complete."


# ── Graph builder ─────────────────────────────────────────────────────────────

def build_graph(broadcast: Callable[..., Awaitable[None]]) -> StateGraph:
    builder = StateGraph(dict)

    builder.add_node(AgentStep.risk_profiler, make_node(risk_profiler, AgentStep.risk_profiler, broadcast))
    builder.add_node(AgentStep.coverage_mapper, make_node(coverage_mapper, AgentStep.coverage_mapper, broadcast))
    builder.add_node(AgentStep.submission_builder, make_node(submission_builder, AgentStep.submission_builder, broadcast))
    builder.add_node(AgentStep.explainer, make_node(explainer, AgentStep.explainer, broadcast))

    builder.set_entry_point(AgentStep.risk_profiler)
    builder.add_edge(AgentStep.risk_profiler, AgentStep.coverage_mapper)
    builder.add_edge(AgentStep.coverage_mapper, AgentStep.submission_builder)
    builder.add_edge(AgentStep.submission_builder, AgentStep.explainer)
    builder.add_edge(AgentStep.explainer, END)

    return builder.compile()


async def run_pipeline(
    session_id: str,
    intake: dict,
    broadcast: Callable[..., Awaitable[None]],
) -> dict:
    graph = build_graph(broadcast)
    initial_state = {"session_id": session_id, "intake": intake}
    final_state = await graph.ainvoke(initial_state)
    return final_state
