# Sentinel

> Per-tenant Trust & Safety workers with wallet-bounded autonomy, built on Locus.

**Paygentic Hackathon — Week 2 (BuildWithLocus)**

Sentinel gives each merchant on a marketplace platform their own isolated, wallet-capped moderation worker deployed on BuildWithLocus. When a tenant's wallet drops through defined thresholds, only that tenant's pipeline degrades — other tenants keep running at full capacity.

Three Locus primitives, one programmable economy:

- **BuildWithLocus** — per-tenant service deploys
- **Wrapped APIs** — OpenAI Moderation + GPT-4o-mini vision, Anthropic Claude Haiku reasoning
- **Locus Tasks** — human reviewer escalation for low-confidence items

All settled in one wallet, one ledger, one currency.

See [`PLAN.md`](./PLAN.md) for the full architecture, build sequence, and demo plan.

## Status

Pre-build — planning complete, execution starts next session.
