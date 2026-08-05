#!/usr/bin/env python3
"""
probe_report.py — collect probe JSON, detect knees, compare reference.

Usage:
    probe_report.py --logs out/probe/<arch>/*.log \
                    --reference reference/<arch>.yaml \
                    --output  out/probe/<arch>/report.md

Each probe binary prints a JSON document to stdout between
##PROBE_JSON_BEGIN## / ##PROBE_JSON_END## markers. The runner is expected to
save that stdout verbatim to <arch>/<case>.log. This script scans every .log,
extracts the JSON blob, runs the detector declared in reference/<arch>.yaml,
compares against the expected value, and writes a markdown report.

Detectors
---------
plateau  — y increases monotonically then flattens; return smallest K
           such that y[K] >= 0.95 * max(y).
knee     — y flat then degrades; return largest K such that y[K] <= y[0]*1.1.
step     — y is piecewise constant with a single up-step; return x at the
           step's midpoint (useful for cache-size-like cases).

All detectors are intentionally simple. Curves with multi-segment structure
(e.g. split IQs) will need case-specific detectors later; extend this file.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    sys.stderr.write(
        "probe_report.py: PyYAML not installed. Run:\n"
        "  source ~/.venvs/tools/bin/activate && pip install pyyaml\n"
    )
    sys.exit(2)


JSON_BEGIN = "##PROBE_JSON_BEGIN##"
JSON_END = "##PROBE_JSON_END##"


@dataclass
class Point:
    x: float
    y: float


@dataclass
class ProbeResult:
    case: str
    arch: str
    x_label: str
    y_unit: str
    points: list[Point]


def extract_json_blob(text: str) -> dict[str, Any] | None:
    m = re.search(
        rf"{re.escape(JSON_BEGIN)}\s*(\{{.*?\}})\s*{re.escape(JSON_END)}",
        text,
        re.DOTALL,
    )
    if not m:
        return None
    return json.loads(m.group(1))


def load_probe_log(path: Path, y_field: str) -> ProbeResult | None:
    blob = extract_json_blob(path.read_text())
    if blob is None:
        return None
    pts = [Point(x=float(p["x"]), y=float(p[y_field])) for p in blob["points"]]
    return ProbeResult(
        case=blob["case"],
        arch=blob["arch"],
        x_label=blob.get("x_label", "x"),
        y_unit=blob.get("y_unit", "y"),
        points=pts,
    )


# --- detectors -------------------------------------------------------------


def detect_plateau(pts: list[Point], threshold: float = 0.95) -> float:
    """Smallest x such that y[x] >= threshold * max(y).
    For IPC-vs-K: the point where we've reached (threshold of) peak."""
    y_max = max(p.y for p in pts)
    if y_max <= 0:
        return float("nan")
    for p in pts:
        if p.y >= threshold * y_max:
            return p.x
    return pts[-1].x


def detect_knee(pts: list[Point], degrade: float = 1.1) -> float:
    """Largest x such that y[x] <= y[0] * degrade.
    For cycles-vs-N: the point right before the curve breaks upward."""
    base = pts[0].y
    last_good = pts[0].x
    for p in pts:
        if p.y <= base * degrade:
            last_good = p.x
        else:
            break
    return last_good


def detect_step(pts: list[Point]) -> float:
    """X at which the largest y-delta between consecutive points occurs."""
    if len(pts) < 2:
        return float("nan")
    best_i, best_d = 0, -1.0
    for i in range(1, len(pts)):
        d = abs(pts[i].y - pts[i - 1].y)
        if d > best_d:
            best_d = d
            best_i = i
    # midpoint between the two points bracketing the step
    return (pts[best_i - 1].x + pts[best_i].x) / 2.0


DETECTORS = {
    "plateau": detect_plateau,
    "knee": detect_knee,
    "step": detect_step,
}


# --- comparison + report ---------------------------------------------------


@dataclass
class CaseReport:
    case: str
    detected: float
    expected: float
    tolerance: float
    status: str      # PASS | FAIL | MISS (no data)
    y_field: str
    detector: str
    notes: str
    points: list[Point]


def evaluate(result: ProbeResult, spec: dict[str, Any]) -> CaseReport:
    detector_name = spec.get("detector", "plateau")
    detector = DETECTORS.get(detector_name)
    if detector is None:
        raise ValueError(f"unknown detector: {detector_name}")
    detected = detector(result.points)
    expected = float(spec["expected"])
    tolerance = float(spec.get("tolerance", 0))
    if abs(detected - expected) <= tolerance:
        status = "PASS"
    else:
        status = "FAIL"
    return CaseReport(
        case=result.case,
        detected=detected,
        expected=expected,
        tolerance=tolerance,
        status=status,
        y_field=spec.get("y_field", "ipc"),
        detector=detector_name,
        notes=spec.get("notes", ""),
        points=result.points,
    )


def format_report(arch: str, reports: list[CaseReport]) -> str:
    lines: list[str] = []
    lines.append(f"# Probe Report — arch: {arch}\n")
    lines.append("## Summary\n")
    lines.append("| Case | Status | Detected | Expected (±tol) | Detector | y field |")
    lines.append("|------|--------|----------|-----------------|----------|---------|")
    for r in reports:
        lines.append(
            f"| {r.case} | **{r.status}** | {r.detected:.3g} | "
            f"{r.expected:g} ± {r.tolerance:g} | {r.detector} | {r.y_field} |"
        )
    lines.append("")
    for r in reports:
        lines.append(f"## {r.case}\n")
        if r.notes:
            lines.append(f"_{r.notes}_\n")
        lines.append("| x | y |")
        lines.append("|---|---|")
        for p in r.points:
            lines.append(f"| {p.x:g} | {p.y:.4f} |")
        lines.append("")
    return "\n".join(lines)


# --- main ------------------------------------------------------------------


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--logs", nargs="+", required=True,
                    help="probe stdout logs (one per case)")
    ap.add_argument("--reference", required=True,
                    help="reference/<arch>.yaml")
    ap.add_argument("--output", default="-",
                    help="markdown output path, or - for stdout")
    args = ap.parse_args()

    ref = yaml.safe_load(Path(args.reference).read_text())
    arch = ref.get("arch", "unknown")
    cases = ref.get("cases", {})

    reports: list[CaseReport] = []
    seen: set[str] = set()

    for log_path in args.logs:
        path = Path(log_path)
        if not path.exists():
            sys.stderr.write(f"warn: {path} not found\n")
            continue
        text = path.read_text()
        blob = extract_json_blob(text)
        if blob is None:
            sys.stderr.write(f"warn: {path} has no PROBE_JSON markers\n")
            continue
        case_name = blob["case"]
        if case_name not in cases:
            sys.stderr.write(
                f"warn: no reference entry for case '{case_name}', skipping\n"
            )
            continue
        spec = cases[case_name]
        result = load_probe_log(path, spec.get("y_field", "ipc"))
        if result is None:
            continue
        reports.append(evaluate(result, spec))
        seen.add(case_name)

    for missing in sorted(set(cases) - seen):
        spec = cases[missing]
        reports.append(CaseReport(
            case=missing,
            detected=float("nan"),
            expected=float(spec["expected"]),
            tolerance=float(spec.get("tolerance", 0)),
            status="MISS",
            y_field=spec.get("y_field", "ipc"),
            detector=spec.get("detector", "plateau"),
            notes=spec.get("notes", ""),
            points=[],
        ))

    md = format_report(arch, reports)
    if args.output == "-":
        sys.stdout.write(md)
    else:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(md)
        sys.stderr.write(f"wrote {args.output}\n")

    fails = [r for r in reports if r.status == "FAIL"]
    return 1 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())
