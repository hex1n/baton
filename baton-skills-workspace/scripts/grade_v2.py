#!/usr/bin/env python3
"""Grade baton skill evals with discriminating assertions."""
import json
import re
import os

BASE = os.path.join(os.path.dirname(__file__), "..", "iteration-1")

EVALS = {
    "orchestrator-phase0-medium": {
        "assertions": [
            {
                "text": "Has Step 0.3b Codex Availability Check as a distinct step",
                "pattern": r"(?i)(step\s+)?0\.3b|codex\s+availability\s+check",
            },
            {
                "text": "Records codex_available in task-status.md",
                "pattern": r"codex_available\s*[:=]\s*true",
            },
            {
                "text": "Uses codex:rescue (not dead codex:review/adversarial-review)",
                "check": "codex_routing",
            },
            {
                "text": "Correctly assesses risk as Medium with AskUserQuestion confirmation",
                "pattern": r"AskUserQuestion\s*\(\s*\{[^}]*(?:[Mm]edium|风险)",
            },
            {
                "text": "Shows Codex integration at Phases 3, 4, 7 for Medium risk",
                "pattern": r"(?i)phase\s+[347].*codex|codex.*phase\s+[347]",
            },
        ]
    },
    "orchestrator-low-risk-fasttrack": {
        "assertions": [
            {
                "text": "Contains a Low-Risk Fast Track TABLE (not just mention of the concept)",
                "pattern": r"\|\s*Phase\s+\d.*Fast\s+Track|Fast\s+Track.*\|",
            },
            {
                "text": "Phase 1 is SKIPPED (not just abbreviated)",
                "pattern": r"(?i)phase\s+1.*skip|skip.*phase\s+1|clarif.*skip|SKIP",
            },
            {
                "text": "Phase 7 Layer A Codex review is explicitly skipped for Low risk",
                "pattern": r"(?i)(codex\s+review.*skip|layer\s+a.*skip|skip.*codex|skip.*layer\s+a)",
            },
            {
                "text": "Repair budget is capped at 1 round (not 3)",
                "pattern": r"(?i)(max\s+1|1\s+round|repair.*1|capped.*1)",
            },
            {
                "text": "Uses AskUserQuestion (not plain text) for triage confirmation",
                "pattern": r"AskUserQuestion\s*\(\s*\{[^}]*(?:triage|[Cc]onfirm|[Cc]larity|[Rr]isk)",
            },
        ]
    },
    "clarifier-finite-choices": {
        "assertions": [
            {
                "text": "At least 3 AskUserQuestion calls with options arrays",
                "check": "min_auq_count",
                "min_count": 3,
            },
            {
                "text": "Uses MUST/mandatory language about AskUserQuestion for finite choices",
                "pattern": r"(?i)(must\s+invoke|must\s+use|工具调用|结构化问题工具)",
            },
            {
                "text": "Clearly labels which questions are tool vs plain text",
                "pattern": r"(?i)(tool\s+(choice|used|selection)|工具.*[：:]|Plain\s+text|纯文本)",
            },
            {
                "text": "Output is in Chinese (follows artifact language policy defaulting to zh)",
                "pattern": r"[\u4e00-\u9fff]{5,}",
            },
        ]
    },
    "generator-quality-standards": {
        "assertions": [
            {
                "text": "Has named 'Quality Standards' section header",
                "pattern": r"(?i)#+\s+.*quality\s+standards",
            },
            {
                "text": "Enumerates all 8 quality criteria by number",
                "check": "quality_criteria_count",
            },
            {
                "text": "Mentions behavior-driven tests explicitly (not just deterministic)",
                "keywords": ["behavior-driven", "what the code should do", "what* the code should do"],
            },
            {
                "text": "References security validation of SESSION_EXPIRY_HOURS env var input",
                "pattern": r"(?i)(session_expiry.*valid|valid.*session_expiry|env.*valid|validated|parse.*number|numeric)",
            },
            {
                "text": "Self-review checklist is populated with task-specific values (not generic template)",
                "pattern": r"(?i)(session|auth|expir).*(?:test|pass|check)",
            },
            {
                "text": "Mentions architecture mismatch handling with stop/proceed thresholds",
                "keywords": ["structural mismatch", "stop", "blocked", "escalation"],
            },
        ]
    },
}


def count_auq_calls(text):
    """Count distinct AskUserQuestion calls with options."""
    return len(re.findall(r"AskUserQuestion\s*\(\s*\{[^}]*options\s*:", text))


def check_codex_routing(text):
    """Check if using codex:rescue (good) vs dead codex:review (bad)."""
    has_rescue = bool(re.search(r'codex:rescue', text))
    has_dead_review = bool(re.search(r'Skill\(\s*"codex:review"', text))
    has_dead_adversarial = bool(re.search(r'Skill\(\s*"codex:adversarial-review"', text))
    return has_rescue and not has_dead_review and not has_dead_adversarial


def check_quality_count(text):
    """Check if 8 quality criteria are enumerated."""
    # Look for numbered items like "1. **Linting**" through "8. **Comments**"
    numbered = re.findall(r'^\s*\d+\.\s+\*\*', text, re.MULTILINE)
    return len(numbered) >= 7  # at least 7 of 8


def grade_response(text, assertions):
    results = []
    for a in assertions:
        passed = False
        evidence = ""

        if "check" in a:
            if a["check"] == "min_auq_count":
                count = count_auq_calls(text)
                passed = count >= a.get("min_count", 3)
                evidence = f"Found {count} AskUserQuestion calls with options (min: {a.get('min_count', 3)})"
            elif a["check"] == "codex_routing":
                passed = check_codex_routing(text)
                has_rescue = bool(re.search(r'codex:rescue', text))
                has_dead = bool(re.search(r'codex:(?:review|adversarial-review)"', text))
                evidence = f"codex:rescue={'yes' if has_rescue else 'no'}, dead codex calls={'yes' if has_dead else 'no'}"
            elif a["check"] == "quality_criteria_count":
                passed = check_quality_count(text)
                numbered = re.findall(r'^\s*\d+\.\s+\*\*', text, re.MULTILINE)
                evidence = f"Found {len(numbered)} numbered quality criteria"

        elif "pattern" in a:
            matches = re.findall(a["pattern"], text)
            if matches:
                passed = True
                sample = matches[0] if isinstance(matches[0], str) else str(matches[0])
                evidence = f"Found {len(matches)} match(es): '{sample[:60]}'"
            else:
                evidence = f"Pattern not found"

        elif "keywords" in a:
            found = [kw for kw in a["keywords"] if kw in text]
            if found:
                passed = True
                evidence = f"Found: {found}"
            else:
                evidence = f"None of {a['keywords']} found"

        results.append({"text": a["text"], "passed": passed, "evidence": evidence})
    return results


def main():
    print("=" * 70)
    print("BATON SKILL EVAL GRADING (v2 — discriminating assertions)")
    print("=" * 70)

    all_results = {}

    for eval_name in EVALS:
        print(f"\n--- {eval_name} ---")
        for variant in ["with_skill", "old_skill"]:
            path = os.path.join(BASE, eval_name, variant, "outputs", "response.md")
            if not os.path.exists(path):
                print(f"  SKIP {variant}")
                continue
            with open(path) as f:
                text = f.read()
            results = grade_response(text, EVALS[eval_name]["assertions"])
            passed = sum(1 for r in results if r["passed"])
            total = len(results)
            rate = round(passed / total, 2) if total > 0 else 0

            grading = {
                "expectations": results,
                "summary": {"passed": passed, "failed": total - passed, "total": total, "pass_rate": rate},
            }
            out = os.path.join(BASE, eval_name, variant, "grading.json")
            with open(out, "w") as f:
                json.dump(grading, f, indent=2)

            tag = "IMPROVED" if variant == "with_skill" else "BASELINE"
            print(f"  [{tag}] {passed}/{total} ({rate*100:.0f}%)")
            for r in results:
                mark = "PASS" if r["passed"] else "FAIL"
                print(f"    [{mark}] {r['text']}")
                if not r["passed"]:
                    print(f"           {r['evidence']}")

            all_results[f"{eval_name}/{variant}"] = grading

    # Summary
    print("\n" + "=" * 70)
    print("SUMMARY TABLE")
    print("=" * 70)
    print(f"{'Eval':<40} {'Improved':>10} {'Baseline':>10} {'Delta':>10}")
    print("-" * 70)
    total_improved = 0
    total_baseline = 0
    total_assertions = 0
    for eval_name in EVALS:
        ws = all_results.get(f"{eval_name}/with_skill", {}).get("summary", {})
        os_ = all_results.get(f"{eval_name}/old_skill", {}).get("summary", {})
        ws_rate = ws.get("pass_rate", 0)
        os_rate = os_.get("pass_rate", 0)
        delta = ws_rate - os_rate
        total_improved += ws.get("passed", 0)
        total_baseline += os_.get("passed", 0)
        total_assertions += ws.get("total", 0)
        print(f"  {eval_name:<38} {ws_rate*100:>8.0f}% {os_rate*100:>8.0f}% {delta*100:>+8.0f}%")

    overall_imp = round(total_improved / total_assertions * 100) if total_assertions else 0
    overall_base = round(total_baseline / total_assertions * 100) if total_assertions else 0
    print(f"\n  {'OVERALL':<38} {overall_imp:>8}% {overall_base:>8}% {overall_imp - overall_base:>+8}%")


if __name__ == "__main__":
    main()
