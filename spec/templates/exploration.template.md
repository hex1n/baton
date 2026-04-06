# Scoped Map: <task-id>

**Requirement**: <one-line task statement>  
**Domain**: <domain>  
**Owner**: `scoped-explorer`  
**Status**: `template`

## 1. Scope

- In scope:
- Out of scope:
- Expected write boundary:

## 2. Entry Point

- Primary entry classes or files:
- Methods, APIs, commands, or scripts:
- Why these are the entries:

## 3. Call Chain

```text
entry -> layer -> dependency -> output
```

## 4. Data Flow

- Source: where data originates
- Transforms: intermediate processing steps
- Sink: where data lands (DB, API response, file, etc.)
- State mutations at each boundary:

> For Low-risk tasks: this section may be abbreviated or merged into Call Chain.

## 5. Existing Behavior

- Current observable behavior:
- Current validation rules:
- Existing implicit constraints:

## 6. Existing Tests

- Directly relevant tests:
- Nearby reusable tests:
- No useful tests found:

## 7. Change History

- Recent changes in affected area (from git log):
- High-churn files:
- Active contributors:

> For Low-risk tasks: this section may be omitted.

## 8. Dependency / Risk Scan

- Will this likely touch integration or infra?
- Will this likely touch migrations or schema?
- Will this likely cross business domains?
- Areas of fragility, coupling, or missing coverage:

## 9. Change Shape

- This looks like:
- Estimated file count:
- Preferred implementation depth:

## 10. Open Questions

- <question>

## 11. Recommendation

- Proceed?
- Suggested next step:
- Uncertainty flags: <areas where exploration was shallow or findings
  are based on inference rather than direct evidence>

## 12. Historical Lessons

> **Required — explicit-empty allowed.** Explorer MUST read
> `<repo-root>/knowledge/lessons.md` and record findings here. If the
> file is missing or nothing applies, say so explicitly. Omission is a
> validator failure — previous silent skips were how cross-task
> compounding failed to work for months. Treat lessons as subsidiary
> awareness; do not quote them as requirements or constraints.

- Relevant prior lessons:
- Lessons explicitly not applicable:
- (if nothing applies) `no relevant lessons in index`
- (if file missing) `no lessons file found at knowledge/lessons.md`
