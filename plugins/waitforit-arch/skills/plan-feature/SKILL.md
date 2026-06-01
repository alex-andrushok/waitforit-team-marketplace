---
name: plan-feature
description: Plans a new feature as a vertical slice in the waitforit modular monolith — orients on the source-of-truth, maps the feature to a bounded context, and produces a structured slice plan with test gates and verification. Planning-only — it stops before writing code. Use when the user says "plan a feature", "scope work for X", "/plan-feature", or before implementing any new capability under src/. NOT for bug fixes or for implementation itself. Delegates boundary rules to the dependency-rules skill and BC/events/tech facts to the bc-guide skill.
---

# plan-feature

Turns a feature request into an executable **vertical-slice plan** for this repo (DDD/Hexagonal
modular monolith). Produces a plan and **stops** — implementation is a separate flow.

Two reference skills carry the stable facts so this procedure stays short:
- **`dependency-rules`** — what each layer may import + the consumer-side-interface pattern.
- **`bc-guide`** — which BC owns what, the events table, and the locked tech choices.

And one subagent runs first: the **`feature-scout`** agent does read-only prior-art +
encapsulating-BC reconnaissance, so the plan reuses existing work instead of rebuilding it.

## When to invoke
- "plan a feature", "scope work for X", "what's the slice for Y", `/plan-feature`.
- Before adding a new capability under `src/<bc>/`.
- **Not** for bug fixes (just fix + test) and **not** to write production code (this skill only plans).

## Output (what the plan must contain)
A single structured plan — concise, scannable, no code dumps:
1. **Context** — why; the problem and intended outcome.
2. **Scope** — explicit in / out (defer auth, analytics, etc. unless asked).
3. **BC + events** — which bounded context(s); events published / subscribed (from `bc-guide`).
4. **Vertical slice** — per-layer changes in order `domain → app → infra → http → module`.
5. **Tests** — what to test per layer + coverage gates.
6. **Sequence** — ordered steps, each with a verify gate.
7. **Verification** — how to prove it works end-to-end.
8. **Risks / open questions** — tradeoffs; real forks go to the user via AskUserQuestion.

End with a handoff note: implementation is separate; run `arch-test` before committing.

## Method

### 0. Scout for prior art & the encapsulating BC  → dispatch the **`feature-scout`** subagent
Before anything else, spawn the `feature-scout` agent (Agent tool, `subagent_type: feature-scout`)
with the feature request. It returns a compact verdict: existing/partial implementations to reuse
or extend, which existing BC should own the work, duplication risk, and a recommendation. Fold its
verdict into **Scope** and **BC + events**:
- If it reports **REUSE/EXTEND** — plan to extend that file; do **not** design a new build.
- If it reports **ESCALATE** (no existing BC fits) — stop and ask the user before planning (a new
  BC is an architectural decision, likely an ADR).
- If it reports a clean **new slice in `<bc>`** — proceed with the rest of the method.

### 1. Orient on the source of truth
On conflict, higher wins (per [CLAUDE.md](CLAUDE.md#source-of-truth-hierarchy)):
code under `src/` > `../.docs/` > `SPEC.md`/`ARCHITECTURE.md` > ADRs in `docs/adr/`.
Reference `.docs/` — don't copy it into the plan.

### 2. Verify the ACTUAL repo state
Before planning, confirm what is really on disk and builds:
```
git status --short && git ls-files <area> | head && go build ./...
```
Uncommitted skeleton ≠ what a remote/cloud session sees — a real divergence has bitten us before.
If the request was drafted elsewhere (Ultraplan, web), reconcile its assumptions against disk.

### 3. Map to a bounded context  → use the **`bc-guide`** skill
Identify the BC(s), the events the slice publishes/subscribes, and the tech choices. Load
`.claude/rules/<bc>.md` for that BC's invariants and don'ts. A **new BC** or **new cross-BC
dependency** → stop and ask (and likely an ADR).

### 4. Design the vertical slice (order matters)
- **domain/** — aggregates, FSM/invariants as guard-methods, sentinel errors, repository port.
  Stdlib-only: pass IDs/timestamps in.
- **app/** — use-case service; publish events **only after** the state change is persisted.
- **infra/<adapter>/** — DynamoDB single-table repo, etc.; adapters isolated.
- **infra/http/** — chi routes + DTOs + RFC 7807 errors.
- **module.go** — `NewModule(...)` wires everything; `cmd/*` only touches modules.

For every cross-layer dependency, apply the **`dependency-rules`** skill — especially the
`infra/http` must-not-import-`app` consumer-side-interface pattern.

### 5. Plan tests & gates
- Gates: `domain ≥90%`, `app ≥80%`, `adapter ≥60%`.
- Unit: `testing` + `testify`; hand-written fakes for app ports.
- **Don't mock DDB/Redis** — integration via testcontainers.
- Full-stack happy-path API test lives at the **module level** (`package <bc>_test`), not in
  `infra/http/` (which would import `infra/dynamodb` and break the infra→infra rule).

### 6. Sequence with verify gates
Order steps so each ends green: `go build` / `go test [-tags=integration]` / **`arch-test`**.
Put cross-cutting changes (e.g. a router swap) in a **separate commit** from feature logic.
Commit messages: imperative mood, no trailing punctuation.

### 7. Surface tradeoffs
State assumptions; present multiple interpretations. For genuine forks the user must decide
(persistence, API shape, scope) use **AskUserQuestion** — don't guess silently.

## Don'ts
- Don't pick an interpretation silently, and don't plan speculative scope.
- Don't propose a top-level layout — BCs live under `src/<bc>/` (CLAUDE.md wins over `.docs`).
- Don't skip step 2 (actual repo state).
- Don't duplicate `.docs/` or the reference skills into the plan — link to them.
- Don't write production code — this skill plans only.

## Handoff
The plan is the deliverable. Implementation is a separate flow; run `arch-test` before each commit
and keep cross-cutting changes in their own commit.
