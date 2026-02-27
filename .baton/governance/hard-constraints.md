# Hard Constraints

## Universal (from Baton)

### HC-000: Do not write source code before plan is APPROVED
- **Added:** project init
- **Reason:** Enforced by phase-lock hook
- **Scope:** all source files
- **Verify:** phase-lock.sh hook
- **Last-validated:** (auto)
- **Status:** ✅ Active

## Project-specific
Add your project's non-negotiable rules here. Use the format:

### HC-NNN: <constraint title>
- **Added:** YYYY-MM-DD
- **Reason:** Why this constraint exists
- **Scope:** Which files/paths it applies to
- **Verify:** How to check compliance (grep, lint rule, test, etc.)
- **Last-validated:** YYYY-MM-DD (task: <task-id>)
- **Status:** ✅ Active / ⚠️ STALE / ❌ Deprecated
