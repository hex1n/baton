# Verifier Guide: Adversarial Testing

> Activated by: Dispatch in Full mode.
> When to run: Final round (full suite) or any round with security-surface ACs and Mode A (input + auth subset only).

## Adversarial Testing

Run after core Tier 3a (AC Coverage Verification).

**When to run:**
- **Final round:** always run full suite (a + b + c + d)
- **Any round where ACs touch auth, input parsing, or data mutation AND Mode A available:**
  run (a) input boundaries + (b) auth attacks only
- Verifier determines applicability from AC content, not a manual tag

```
a) Input boundary attacks:
   - Empty / missing required input → should get validation error, not crash
   - Negative or zero values where positive expected → should reject
   - Maximum boundary values (e.g., MAX_INT) → should handle gracefully
   - Injection payloads (SQL, command, XSS as applicable) → should be sanitized
   - Extremely large input → should not cause OOM or timeout

b) Authorization attacks (if applicable):
   - Call without auth → should be rejected
   - Call with wrong user's credentials → should be forbidden
   - Privilege escalation → should be blocked

c) Concurrency attacks:
   - Same operation from multiple threads simultaneously
   - Check: no duplicate records, no data corruption, no lost updates

d) Resource exhaustion:
   - High-frequency repeated operations → should not degrade performance
   - Check: connection pool stable, no resource leaks
```

**Adversarial findings are categorized as P1/P2/P3:**
- P1 (blocks shipping): SQL injection possible, data corruption, auth bypass
- P2 (should fix): missing input validation, no rate limiting
- P3 (nice to have): verbose error messages, slow response under extreme load

### Verification review.md section (append to core review.md output)

```markdown
### Adversarial Testing
- P1: {critical security / data integrity issues}
- P2: {should-fix issues}
- P3: {nice-to-have improvements}
```
