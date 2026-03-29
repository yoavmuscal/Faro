"""
Deterministic premium bands and confidence for hybrid coverage mapping.
Used when a rule exists; otherwise ``estimate_premium`` returns None and the LLM estimate is kept.
"""
from __future__ import annotations

import re
from typing import Optional, Tuple

from models import IntakeRequest, RiskProfile


def _risk_multiplier(risk_profile: RiskProfile | None) -> float:
    if risk_profile is None:
        return 1.0
    rl = (risk_profile.risk_level or "medium").casefold()
    if rl == "high":
        return 1.28
    if rl == "low":
        return 0.88
    return 1.0


def _revenue(intake: IntakeRequest) -> float:
    return max(float(intake.annual_revenue), 1.0)


def _employees(intake: IntakeRequest) -> int:
    return max(int(intake.employee_count), 0)


def _map_policy_key(policy_type: str) -> str | None:
    t = policy_type.casefold()
    if re.search(r"worker|wc\b", t):
        return "workers_comp"
    if "general liability" in t or t.strip() in {"gl", "cgl"}:
        return "general_liability"
    if "professional" in t or "e&o" in t or "errors" in t:
        return "professional_liability"
    if "commercial auto" in t or "business auto" in t:
        return "commercial_auto"
    if "commercial property" in t or "building" in t and "property" in t:
        return "commercial_property"
    if "bop" in t or "business owner" in t:
        return "bop"
    if "umbrella" in t or "excess liability" in t:
        return "umbrella"
    if "liquor" in t:
        return "liquor_liability"
    if "product liability" in t:
        return "product_liability"
    if "cyber" in t:
        return "cyber"
    if "epli" in t or "employment practices" in t:
        return "epli"
    return None


def estimate_premium(
    policy_type: str,
    intake: IntakeRequest,
    risk_profile: RiskProfile | None,
) -> Optional[Tuple[float, float]]:
    """Return (low, high) annual premium band, or None if no deterministic rule."""
    key = _map_policy_key(policy_type)
    if key is None:
        return None

    rev = _revenue(intake)
    emps = _employees(intake)
    m = _risk_multiplier(risk_profile)
    rev_m = rev / 1_000_000.0

    # Rough illustrative bands; midpoint used by coverage_mapper for blending.
    if key == "workers_comp":
        base = 750.0 * emps + 1800.0 + 420.0 * rev_m
        spread = 0.22
    elif key == "general_liability":
        base = 950.0 + 2200.0 * rev_m + 35.0 * emps
        spread = 0.28
    elif key == "professional_liability":
        base = 1200.0 + 2800.0 * rev_m
        spread = 0.30
    elif key == "commercial_auto":
        base = 1800.0 + 900.0 * rev_m + 120.0 * emps
        spread = 0.32
    elif key == "commercial_property":
        base = 1100.0 + 0.00035 * rev
        spread = 0.26
    elif key == "bop":
        base = 1400.0 + 1900.0 * rev_m + 28.0 * emps
        spread = 0.27
    elif key == "umbrella":
        base = 800.0 + 450.0 * rev_m + 600.0
        spread = 0.25
    elif key == "liquor_liability":
        base = 900.0 + 800.0 * rev_m
        spread = 0.30
    elif key == "product_liability":
        base = 1100.0 + 2400.0 * rev_m
        spread = 0.29
    elif key == "cyber":
        base = 900.0 + 1500.0 * rev_m + 12.0 * emps
        spread = 0.33
    elif key == "epli":
        base = 800.0 + 55.0 * emps + 400.0 * rev_m
        spread = 0.28
    else:
        return None

    mid = base * m
    half = mid * spread
    low = max(250.0, mid - half)
    high = max(low + 100.0, mid + half)
    return (round(low, 2), round(high, 2))


def estimate_confidence(
    policy_type: str,
    intake: IntakeRequest,
    risk_profile: RiskProfile | None,
) -> float:
    """Confidence in rules-based numbers (used when blending with LLM)."""
    if _map_policy_key(policy_type) is None:
        return 0.72
    conf = 0.82
    if risk_profile is not None:
        conf += 0.06
    if intake.annual_revenue > 0 and intake.employee_count >= 0:
        conf += 0.04
    return min(0.96, conf)
