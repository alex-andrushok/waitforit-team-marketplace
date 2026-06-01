---
name: bc-guide
description: Reference map of the waitforit bounded contexts — what each BC owns, the events it publishes/subscribes, where code lives, and the locked tech choices. Use to answer "which BC owns X", "what events does Y publish/subscribe", "where does this code live", "what's the tech stack", or to map a feature to a BC. Reference, not a procedure. For the full per-BC contract, load .claude/rules/<bc>.md.
---

# bc-guide

The waitforit service is a modular monolith: 4 bounded contexts + a shared library, each at
`src/<bc>/{domain,app,infra,module.go}`. Cross-BC communication is **only** via
`src/shared/events.Bus`. Full architecture: [ARCHITECTURE.md](ARCHITECTURE.md).

## Bounded contexts

| BC | Owns | Plane |
|---|---|---|
| **identity** | Tenant, AdminUser, ApiKey; auth (JWT), RBAC, API-key verify. **Root BC** — subscribes to nothing. | control |
| **room** | WaitingRoom aggregate; lifecycle `draft→active⇄paused→closed`, schedule, config. | control |
| **session** | Session aggregate; end-user queue lifecycle, SSE position updates. High-RPS. | data |
| **admission** | AdmissionToken; Redis Streams worker (`XREADGROUP`/`XACK`/`XAUTOCLAIM`), HMAC token, verify. **Core BC.** | data |
| **shared** | Library (not a BC): `events` bus, `clock`, `ids`. Bottom of the dependency graph. | — |

## Events (publisher → event → subscribers)

| Event (`EventName()`) | Published by | Subscribed by |
|---|---|---|
| `identity.tenant_suspended` (`TenantSuspended`) | identity | room (cascade pause) |
| `identity.api_key_rotated` (`ApiKeyRotated`) | identity | session (cache invalidation) |
| `room.activated` (`RoomActivated`) | room | admission |
| `room.paused` (`RoomPaused`) | room | admission |
| `room.closed` (`RoomClosed`) | room | admission, session |
| `room.config_changed` (`RoomConfigChanged`) | room | admission |
| `session.enqueued` (`SessionEnqueued`) | session | — (analytics post-MVP) |
| `session.abandoned` (`SessionAbandoned`) | session | — |
| `session.expired` (`SessionExpired`) | session | — |
| `admission.session_admitted` (`SessionAdmitted`) | admission | session |
| `admission.session_verified` (`SessionVerified`) | admission | session |

Event structs live in `src/shared/events/events.go`; the in-memory synchronous bus in `bus.go`
(`Publish(ctx, Event)` and `Subscribe(name, Handler)` — both error-free). Naming: past tense,
namespaced `<bc>.<event>`. Publish an event **only after** the state change is persisted.

## Where code lives
- Per BC: `domain/` (aggregates, FSM, ports), `app/` (use-cases), `infra/<adapter>/`
  (dynamodb, http, …), `module.go` (`NewModule(...)` + `RegisterRoutes(r chi.Router)` + optional
  `StartWorker(ctx)`).
- `cmd/server` and `cmd/worker` instantiate modules — never reach inside a BC.
- For a BC's invariants, routes, and don'ts, load **`.claude/rules/<bc>.md`**.

## Locked tech choices
Go 1.22+ · chi router · zerolog · **DynamoDB single-table** (`PK`/`SK`, single-table design) ·
**Redis Streams + Consumer Groups** for admission · opaque session ID + `HMAC(stream_id, secret)`
token · SSE with `Last-Event-ID` · UUID per `.docs/02` · **RFC 7807** `application/problem+json`
errors · **testcontainers** for integration (don't mock DDB/Redis). Rationale: `../.docs/07-tech-stack.md`.

## When to stop and ask
A **new BC** or a **new cross-BC dependency** is an architectural decision — stop and ask the user
(and likely write an ADR), don't introduce it silently.
