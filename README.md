# Mitosis

> **Recursively self-replicating agents on Locus.**

**Paygentic Hackathon — Week 2 (BuildWithLocus)**

An agent receives a task. It decides whether to do the task itself, or split into N specialist children — each spawned as its own deployment on BuildWithLocus, each with a portion of the parent's USDC wallet. Children may spawn grandchildren. The tree expands and collapses dynamically, bounded only by the root budget.

`fork()` and `wait()` for the agent economy, with USDC as the only governor of recursion.

## What Locus uniquely enables

Three primitives, one substrate for autonomous decomposition:

- **BuildWithLocus** — agents *can* spawn agents because deployment is an API call
- **PayWithLocus** — every agent has a real wallet, so fiscal bounding is enforceable
- **Wrapped APIs** — pay-per-call USDC means costs are knowable at decision time

## Demo task

Series A investment due diligence. Submit a startup name + budget, watch a tree of specialist agents (market, team, tech, financial, competitive) bloom on Locus, each running its own analysis via wrapped APIs, root synthesizing the final memo as agents self-terminate.

See [`PLAN.md`](./PLAN.md) for full architecture, build sequence, demo plan, and risk register.

## Status

Pre-build — planning complete, execution starts in next session.
