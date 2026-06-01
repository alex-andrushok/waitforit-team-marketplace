---
name: arch-test
description: Verifies that current src/ code respects the Dependency Rules from CLAUDE.md — no cross-BC imports, domain/ free of net/http and DB drivers, app/ free of infrastructure, shared/ does not depend on BCs. Use before committing code in src/, after adding a new BC, after rewiring shared/, or whenever the user asks to "check arch", "run arch test", "verify boundaries".
---

# arch-test

Automated sanity-check that the codebase under `src/` matches the [Dependency Rules](CLAUDE.md#dependency-rules). Runs grep-based AST-light checks plus `go build`/`go vet`. Returns a checklist of ✓/✗ per rule.

## When to invoke
- Before committing any change under `src/`.
- After adding a new BC (per ARCHITECTURE.md runbook).
- After moving / renaming packages.
- Anytime the user asks "check arch", "run arch-test", "verify dependency rules", "are boundaries clean".
- As a precondition for `make ci` once `arch-test` is wired into Makefile.

## Steps

Run the following from `waitforit/` working directory. **Stop and report at the first failure** — don't run later steps if an earlier one fails.

### 1. domain/ purity
No file under `src/<bc>/domain/` may import `net/http`, `database/sql`, Redis/Dynamo SDKs, or any other BC.

```bash
for f in src/*/domain/*.go; do
  bad=$(grep -E '"net/http"|"database/sql"|go-redis|aws-sdk|redis/v|dynamodb|waitforit/src/(identity|room|session|admission)' "$f" 2>/dev/null | grep -v 'package domain')
  if [ -n "$bad" ]; then echo "✗ domain not pure: $f"; echo "$bad"; fi
done
```

### 2. app/ purity
No file under `src/<bc>/app/` may import HTTP, DB drivers, or third-party SDKs.

```bash
for f in src/*/app/*.go; do
  bad=$(grep -E '"net/http"|"database/sql"|go-redis|aws-sdk|redis/v|dynamodb' "$f" 2>/dev/null)
  if [ -n "$bad" ]; then echo "✗ app not pure: $f"; echo "$bad"; fi
done
```

### 3. No cross-BC imports
For every BC, ensure it does not import any other BC's package.

```bash
for bc in identity room session admission; do
  others=$(echo "identity room session admission" | tr ' ' '\n' | grep -v "^$bc$" | paste -sd'|' -)
  bad=$(grep -rEn "waitforit/src/($others)/" "src/$bc/" 2>/dev/null)
  if [ -n "$bad" ]; then echo "✗ $bc imports another BC:"; echo "$bad"; fi
done
```

### 4. shared/ does not depend on BCs
```bash
grep -rEn 'waitforit/src/(identity|room|session|admission)/' src/shared/ 2>/dev/null
# any output = FAIL
```

### 5. Build + vet clean
```bash
go vet ./... && go build ./...
```

## Output format
Report as checklist. Example pass:
```
✓ 1. domain/ purity — clean
✓ 2. app/ purity — clean
✓ 3. No cross-BC imports — clean
✓ 4. shared/ independent of BCs — clean
✓ 5. go vet + go build — clean
```

Example fail:
```
✗ 1. domain/ purity — src/session/domain/foo.go imports net/http
  → fix: move HTTP-dependent code to src/session/infra/http/ or src/session/app/
```

## Action on fail
If any check fails, **do not auto-fix**. Report the violation, propose 1-2 concrete migration paths (e.g. "move this to infra/http/", "extract this as event in src/shared/events/"), and let the user decide before changing code. Auto-fix risks moving code into the wrong layer.

## Future
When `make arch-test` лands у Makefile (ADR-0001 follow-up), this skill should delegate to it instead of running grep inline.
