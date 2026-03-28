# Iteration 3 Modification

**Target dimension**: Efficiency (via simplification, following B1 insight)

**Change**: Condensed contradiction resolution protocol from 4 numbered steps + 2-line principle (8 lines) to 4 lines. Same meaning, 50% less text.

Before (8 lines):
```
**Resolve contradictions, don't just note them.** When two sources disagree:
1. State both claims with their source and confidence level.
2. Identify what would distinguish them — a file to read, a test to run, a third source to check.
3. If the distinguishing check is in scope, do it now and report the result.
4. If out of scope or still unresolved, flag it as an open question with what's needed to resolve it.

Two unverified sources agreeing does not equal verification. A verified source
always outranks an unverified one, regardless of how many unverified sources agree.
```

After (4 lines):
```
**Resolve contradictions, don't just note them.** When sources disagree:
state both claims with sources, then try to resolve (read a file, run a test,
check a third source). If unresolvable, flag it as an open question with what's
needed. Two unverified sources agreeing ≠ verification.
```

**Hypothesis**: Following B1's key finding — shorter = more focused = higher quality for mature skills. The 4-step protocol over-specifies an obvious procedure (check sources, resolve, escalate).

**Size**: Saves ~200 bytes
