---
name: dependency-rules
description: Reference for the waitforit import/dependency rules — what each layer (domain/app/infra/module/cmd/shared) may import, the hard prohibitions, the consumer-side-interface pattern for infra/http, and the cut-property rationale. Use when deciding whether an import is allowed, "can X import Y", "where should this dependency live", explaining boundaries, or wiring a handler to a service. Companion to the arch-test skill: arch-test *checks* the rules, this *explains* them. Reference, not a procedure.
---

# dependency-rules

The import contract for `src/` (DDD/Hexagonal modular monolith). Authoritative source is
[CLAUDE.md#dependency-rules](CLAUDE.md#dependency-rules); this skill is the working guide.

## Allowed import directions

| This package | May import |
|---|---|
| `src/<bc>/domain/` | **stdlib only** |
| `src/<bc>/app/` | `src/<bc>/domain` + `src/shared/*` |
| `src/<bc>/infra/<adapter>/` | `src/<bc>/domain` + external SDKs (`net/http`, chi, AWS/Redis clients) |
| `src/<bc>/module.go` | `src/<bc>/domain` + `src/<bc>/app` + `src/<bc>/infra/*` + `src/shared/*` |
| `src/shared/<pkg>/` | stdlib + other `src/shared/*` (no cycles) |
| `cmd/<binary>/main.go` | any `src/<bc>` **via `module.go`** + `src/shared/*` |

## Hard prohibitions (CI/arch-test should fail)

- `domain/` → `app/`, `infra/`, another BC, `net/http`, DB drivers, third-party SDKs.
- `app/` → `infra/`, `net/http`, DB drivers, third-party SDKs.
- `infra/<X>/` → `<bc>/app/`, or a **sibling** `infra/<Y>/` of the same BC (adapters are isolated).
- `src/<bcA>/...` → `src/<bcB>/...` — **no** direction between BCs. Communicate only via
  `src/shared/events.Bus` (typed events).
- `src/shared/<pkg>/` → any `src/<bc>/...` — shared sits at the bottom of the graph.
- `cmd/` → `src/<bc>/domain|app|infra` directly — only through `module.go`.

## The consumer-side interface pattern (the easy-to-miss one)

`infra/http` must **not** import `app/`. But the handler needs the use-case service. Resolve it by
declaring the port **in the adapter** and wiring the concrete service in `module.go`:

```go
// src/<bc>/infra/http/handler.go — handler depends on a locally-declared interface
type TenantUseCases interface {
    CreateTenant(ctx context.Context, name string) (*domain.Tenant, error)
    // ...only the methods this handler calls
}
func New(uc TenantUseCases) *Handler { ... }

// src/<bc>/module.go — allowed to see both app and infra, does the wiring
svc := app.NewTenantService(...)        // *app.TenantService satisfies TenantUseCases structurally
h := identityhttp.New(svc)
```

So `infra/http` imports only `<bc>/domain` (for return types / sentinel errors) + chi + stdlib —
never `app`. Don't "simplify" this back to a direct `*app.TenantService` field: the current
grep-based arch-test does **not** catch an infra→app edge, so this rule is guarded by humans/this guide.

## Keeping domain pure

`domain/` is stdlib-only and deterministic. Don't import a UUID or clock library there — pass IDs
and timestamps **in** (constructors take `id`, `createdAt`); the app layer injects `shared/ids` and
`shared/clock`. This is what keeps domain tests trivial and the BC extractable.

## Why these rules — the cut-property

Extracting any BC into its own service must stay trivial:
`git mv src/<bc>/ ../wfiv-<bc>-service/src/<bc>/` + a new `go.mod`. If one BC imports another's
`domain`/`app`, the extract needs an anti-corruption layer or both BCs move together. The rules
above preserve this cut.

## Verify
Run the **arch-test** skill (grep checks + `go build`/`go vet`). Note its known gap: it does not
detect `infra/http → app`; check that one by reading the handler's imports (only `domain` + chi).
