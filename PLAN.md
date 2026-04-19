# Mitosis — Master Plan

> **Recursively self-replicating agents on Locus.** An agent receives a task, decides whether to execute or *split*, and if it splits — spawns N child services on BuildWithLocus with portions of its wallet. Children may spawn grandchildren. The tree expands and collapses, bounded only by the root budget.
>
> **Hackathon**: Paygentic Week 2 (BuildWithLocus). **Submission**: Wed 22 Apr. **Prize target**: 1st place → 30-min YC founder call.
>
> **Demo task**: Series A investment due diligence — root agent + 5 specialists writing a complete investment memo on a real startup, live on stage.

---

## Table of Contents

1. [TL;DR](#tldr)
2. [The Pitch](#the-pitch)
3. [The Demo Task](#the-demo-task)
4. [Architecture](#architecture)
5. [The Recursion Decision](#the-recursion-decision)
6. [Wallet Splitting and Bounds](#wallet-splitting-and-bounds)
7. [Coordination Protocol](#coordination-protocol)
8. [Locus Primitives and Endpoints](#locus-primitives-and-endpoints)
9. [Tech Stack and Repo Structure](#tech-stack-and-repo-structure)
10. [Build Sequence](#build-sequence)
11. [Spike Validations](#spike-validations)
12. [Pitch Outline (5 min)](#pitch-outline-5-min)
13. [Judging Rubric Alignment](#judging-rubric-alignment)
14. [Risk Register](#risk-register)
15. [Deferred / Out of Scope](#deferred--out-of-scope)
16. [Open Questions for Next Session](#open-questions-for-next-session)
17. [Carryover from Sentinel Planning](#carryover-from-sentinel-planning)
18. [Next Session Quick Start](#next-session-quick-start)

---

## TL;DR

**Mitosis** is a platform for **recursive autonomous computation**. Every agent runs as its own deployed service on BuildWithLocus, holds its own USDC wallet, and decides at runtime whether to do its task itself or **fork into N child agents** — each spawned as a fresh Locus deployment with a portion of the parent's budget.

The tree of agents grows and collapses dynamically. The only thing preventing infinite recursion is **fiscal bounding**: each split divides the parent's wallet, and a minimum-budget threshold forces leaves to execute directly. When children finish, parents synthesize and self-terminate.

This is `fork()` + `wait()` for the agent economy, with USDC as the bound.

---

## The Pitch

**Hook**: *"What if every difficult task could decide for itself how big it needs to be?"*

**Problem**: Today's agents either run as monoliths (one model, one prompt, one shot — limited by context window and token budget) or as hand-orchestrated pipelines (engineers pre-define every step). Neither scales to genuinely complex, open-ended work where the right decomposition isn't known up front.

**Solution**: Mitosis lets agents **decide their own structure**. Submit a task with a budget. The root agent introspects: *"Can I do this in one pass for $X, or should I split into specialists?"* If it splits, it deploys child agents on Locus, hands each a sub-task and a sub-budget, and waits. Children make the same decision recursively.

**Why Locus is the only platform that makes this work**:
- BuildWithLocus turns a service deployment into an API call — agents *can* spawn agents
- PayWithLocus gives every agent a real wallet — fiscal bounding is enforceable, not just simulated
- Wrapped APIs are pay-per-call USDC — costs are knowable at decision time
- Tasks API extends the recursion to humans for branches that exceed agent capability

Three Locus primitives, one substrate for autonomous decomposition.

---

## The Demo Task

**Series A Investment Due Diligence**

Submit: *"Analyze [Startup Name] (website [URL]) for a $5M Series A investment. Budget: $5 USDC."*

**Expected tree** (live demo, ~3 min total):

```
                       ┌─────────────────────────┐
                       │  ROOT (DD Coordinator)  │
                       │  Budget: $5.00          │
                       │  Retains: $1.00         │
                       └────────────┬────────────┘
                                    │
       ┌──────────────┬─────────────┼─────────────┬──────────────┐
       ▼              ▼             ▼             ▼              ▼
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│ Market   │   │ Team     │   │ Tech     │   │ Financial│   │ Compet.  │
│ Analyst  │   │ Analyst  │   │ Analyst  │   │ Analyst  │   │ Analyst  │
│ $0.80    │   │ $0.80    │   │ $0.80    │   │ $0.80    │   │ $0.80    │
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
```

Each specialist:
1. Calls **Exa** (wrapped) to search relevant content for its angle
2. Calls **Anthropic Claude Haiku** (wrapped) to reason over results
3. Reports a structured finding back to root

Root synthesizes a one-page investment memo in markdown. Memo is the **demo artifact** — judges see a real, structured output.

**Why this task wins for Week 2**:
- Naturally decomposes — VCs in the room recognize the workflow instantly
- Visible artifact (memo) at the end — not just architecture, but output
- Each level of the tree is real Locus deployments — BuildWithLocus is the substrate, not an afterthought
- Real-world ROI is immediately legible (a junior analyst doing this manually = 4 hours of work)

**Backup tree** (recorded offline for the polish video):
- Deeper variant where one of the specialist children further splits into grandchildren (e.g., Market Analyst spawns 3 grandchildren — TAM, SAM, SOM). Demonstrates depth-2 recursion.

---

## Architecture

### Topology

```
┌─────────────────────────────────────────────────────────────┐
│  SPAWNER  (1 Locus service, always on)                       │
│  - Public API: POST /tasks (submit a root task)              │
│  - Demo UI: live tree visualizer (SSE stream)                │
│  - Reaper: dead man's switch for orphaned children           │
│  - Result store reader (GET /tasks/{id})                     │
└──────────┬──────────────────────────────────────────────────┘
           │ POST /v1/services  (spawns root agent)
           ▼
┌─────────────────────────────────────────────────────────────┐
│  AGENT  (1 Locus service per agent in the tree)              │
│  Same image, different env vars                              │
│  Env: TASK_ID, PARENT_URL, BUDGET, DEPTH, TASK_DESC          │
│                                                              │
│  Lifecycle:                                                  │
│   1. Boot, register with Postgres                            │
│   2. DECIDE — split or execute? (LLM introspection)          │
│   3a. If SPLIT — spawn N children via BuildWithLocus API     │
│        wait for all child reports                            │
│        synthesize, report to PARENT_URL                      │
│        DELETE self                                           │
│   3b. If EXECUTE — call wrapped APIs for the work            │
│        report to PARENT_URL                                  │
│        DELETE self                                           │
└──────────┬──────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│  POSTGRES (shared addon)                                     │
│  - tree_nodes: id, parent_id, depth, status, budget, spent   │
│  - agent_results: agent_id, output_json, synthesis_input     │
│  - audit_log: append-only ledger of every decision/spawn     │
└─────────────────────────────────────────────────────────────┘
```

### Service Count for Demo

| Service | Count | Cost |
|---|---|---|
| Spawner | 1 | $0.25 |
| Postgres addon | 1 | $0.25 |
| Root agent | 1 | $0.25 |
| Specialist children | 5 | $1.25 |
| **Total fixed** | **8** | **$2.00** |

Plus wrapped API calls (~$2-3) and 1-2 Tasks API submissions for the recorded backup video (~$2-4). Lands within the realistic $8-9 hackathon credit grant.

---

## The Recursion Decision

Every agent's first action is to **decide whether to split or execute**. This is the core of the system.

### Decision Inputs

| Variable | Source | Notes |
|---|---|---|
| `task_description` | Env var | Free-form natural language |
| `budget` | Env var | USDC available to this agent and its descendants |
| `depth` | Env var | Current depth in tree (root = 0) |
| `MAX_DEPTH` | Constant = 4 | Hard ceiling on recursion |
| `MIN_BUDGET_FOR_SPLIT` | Constant = $0.50 | Below this, must execute |
| `MAX_CHILDREN_PER_SPLIT` | Constant = 5 | Controls fan-out |
| `RETAINER_RATIO` | Constant = 0.20 | Parent keeps 20% of budget for synthesis |

### Decision Logic (in pseudo-code)

```python
def decide(task, budget, depth):
    if depth >= MAX_DEPTH:
        return EXECUTE  # forced — recursion ceiling

    if budget < MIN_BUDGET_FOR_SPLIT:
        return EXECUTE  # forced — can't afford to split

    # LLM introspection
    plan = anthropic_call(SPLIT_OR_EXECUTE_PROMPT, task=task, budget=budget)
    # plan is structured: {"action": "split"|"execute", "children": [...] | None}

    if plan.action == "execute":
        return EXECUTE
    else:
        return SPLIT(children=plan.children)
```

### The Split Prompt (sketch)

```
You are an autonomous agent considering a task.
Task: {task}
Budget: ${budget} USDC
Depth: {depth} of {MAX_DEPTH}

Decide ONE of:
1. EXECUTE — do this task directly with one focused LLM call
2. SPLIT — decompose into 2-{MAX_CHILDREN_PER_SPLIT} independent sub-tasks

Choose EXECUTE if:
- The task is atomic or already narrow
- Sub-tasks would have heavy overlap
- Budget is too small to fund meaningful children

Choose SPLIT if:
- Distinct sub-tasks are clearly separable
- Each sub-task benefits from its own specialist context
- Budget supports at least 2 children with non-trivial allocations

Respond JSON:
{
  "action": "execute" | "split",
  "reasoning": "...",
  "children": [
    {"task_description": "...", "budget_share_pct": 20},
    ...
  ]  // null if action=execute
}
```

---

## Wallet Splitting and Bounds

### Split Math

```
parent_budget = $5.00
retainer = parent_budget * 0.20 = $1.00   # parent keeps for synthesis + overhead
distributable = parent_budget * 0.80 = $4.00

# Distributed across N children proportional to LLM-recommended shares
# E.g., 5 equal children: $0.80 each
```

### Per-Agent Spend Tracking

Each agent tracks its own spend in real time:
- Wrapped API calls: deduct estimated cost on call (truth-up after response)
- Pre-flight check before each call: `budget - spent_so_far > estimated_call_cost`
- If a wrapped call would exceed budget → emergency-return with partial work + budget-exceeded flag

### Recursion Bounds (defense in depth)

| Bound | Value | Failure mode it prevents |
|---|---|---|
| `MAX_DEPTH` | 4 | Infinite recursive descent |
| `MIN_BUDGET_FOR_SPLIT` | $0.50 | Splits with sub-cent children |
| `MAX_CHILDREN_PER_SPLIT` | 5 | Pathological fan-out |
| `MAX_TREE_TOTAL_SERVICES` | 50 | Spawner refuses new spawns once total exceeded |
| `MAX_AGENT_LIFETIME_SEC` | 600 | Reaper kills agents older than this |

The fiscal substrate is the *primary* bound. The numerical bounds are belt-and-suspenders.

---

## Coordination Protocol

### Spawn

When parent decides to SPLIT:
1. Insert `tree_nodes` row per child (`status = pending`)
2. For each child:
   ```
   POST $LOCUS_BUILD_API_URL/v1/services
   { source: { type: image, imageUri: ghcr.io/fuadsn/mitosis-agent:latest },
     env: { TASK_ID, PARENT_URL: <my INTERNAL_URL>, BUDGET, DEPTH+1, TASK_DESC },
     runtime: { ... }
   }
   ```
3. Then `POST /v1/deployments` for each
4. Parent polls `tree_nodes` for child statuses (or accepts inbound webhook)

### Report

When child completes:
```
POST {PARENT_URL}/agent/{AGENT_ID}/report
{
  "agent_id": "...",
  "result": { ... },          # the actual output
  "spent_usdc": 0.45,
  "status": "complete" | "partial" | "failed",
  "child_tree": [...]         # if this child also split, recursive view
}
```

Parent tracks `expected_children = N`, `received_reports = M`. When `M == N` (or all timed out), trigger synthesis.

### Synthesis

Parent calls Anthropic with all child results:
```
prompt: "Here are reports from {N} specialist agents. Synthesize a unified output for: {original_task}.\n\n{child_reports_json}"
```

Output goes to parent's own report payload, sent up the chain.

### Self-Termination

After reporting (or if parent is root, after writing final result to Postgres):
```
DELETE $LOCUS_BUILD_API_URL/v1/services/{my_service_id}
```

### Reaper (in spawner)

Every 60s, scan `tree_nodes` for agents past `MAX_AGENT_LIFETIME_SEC`. For each:
1. Force `DELETE` on the service
2. Mark `tree_nodes.status = reaped`
3. If parent is still alive, send synthetic "child_failed" report so parent can synthesize without waiting

---

## Locus Primitives and Endpoints

### Authentication (RESOLVE FIRST IN SESSION 1)

⚠️ **Confirmed during planning probe**: `POST https://api.buildwithlocus.com/v1/auth/exchange` with the beta `claw_dev_*` key returns `{"error":"Invalid API key"}`. Beta has no `/v1/auth/exchange` either.

**Resolution path** for session 1:
1. Read `https://beta-api.paywithlocus.com/api/skills/skill.md` end-to-end
2. Try `Authorization: Bearer $LOCUS_API_KEY` directly against Build API endpoints (no exchange)
3. If still failing, ask in hackathon Discord
4. Last resort: register a separate production key

**This is the gate. Nothing deploys until resolved.**

### Confirmed Working Endpoints

| Operation | Endpoint | Auth |
|---|---|---|
| Wallet balance | `GET https://beta-api.paywithlocus.com/api/pay/balance` | `Bearer $LOCUS_API_KEY` |
| Gift code request | `POST https://beta-api.paywithlocus.com/api/gift-code-requests` | `Bearer $LOCUS_API_KEY` |

### BuildWithLocus — Provisioning (auth pending)

| Operation | Endpoint |
|---|---|
| Create project | `POST $LOCUS_BUILD_API_URL/v1/projects` |
| Create environment | `POST $LOCUS_BUILD_API_URL/v1/projects/{id}/environments` |
| Create service (pre-built image) | `POST $LOCUS_BUILD_API_URL/v1/services` with `source.type: "image"` |
| Trigger deployment | `POST $LOCUS_BUILD_API_URL/v1/deployments` |
| Poll deployment | `GET $LOCUS_BUILD_API_URL/v1/deployments/{id}` |
| Patch service env vars | `PUT $LOCUS_BUILD_API_URL/v1/variables/service/{id}` |
| Delete service | `DELETE $LOCUS_BUILD_API_URL/v1/services/{id}` |
| Provision Postgres addon | per docs (verify in skill.md) |

**Constraints**:
- Pre-built images must be `linux/arm64`
- Containers listen on `PORT=8080` (auto-injected)
- Health check endpoint `/health` returning HTTP 200 required
- Cold start: 1-2 min for pre-built image to reach `healthy`

### Wrapped APIs (auth confirmed via API key Bearer)

Demo uses three providers:

| Job | Provider | Endpoint |
|---|---|---|
| Search (per specialist analyst) | Exa | `wrapped/exa/search` |
| Reasoning + synthesis (every agent) | Anthropic Claude Haiku | `wrapped/anthropic/messages` |
| Embeddings (de-dup of search results, optional) | OpenAI | `wrapped/openai/embeddings` |

### Tasks API

Reserved for the **recorded backup video** (1-2 real submissions). Use case: when an agent decides a sub-task requires human judgment (e.g., "interpret a non-public legal filing"), it submits a Locus Task instead of executing or splitting. Demo shows architectural diagram + recorded clip; live demo doesn't burn budget on Tasks.

### Wallet + Credits

- **Current**: $5 promo on `ws_d75521d6` (verified 2026-04-19)
- **Pending**: gift code request `52606d86-658f-4442-a7b7-45b60f5ea0fd` ($50 asked, $5-10 expected)
- Watch with: `bash scripts/check_balance.sh`

---

## Tech Stack and Repo Structure

| Component | Choice | Rationale |
|---|---|---|
| Spawner + Agent | **Python 3.11 + FastAPI** | Same image for all roles; behavior controlled by env var (`AGENT_ROLE=spawner|agent`) |
| Container base | **`python:3.11-slim` on `linux/arm64`** | Locus requires ARM64 |
| Image registry | **GHCR** (`ghcr.io/fuadsn/mitosis-agent:latest`) | Free for public, native to GitHub |
| Demo UI | **Next.js 15 (App Router) + SSE** | Live tree visualization streams from Postgres deltas |
| Persistence | **Postgres addon only** (no Redis) | Single source of truth for tree state |

```
mitosis/
├── agent/                            # the recursive unit
│   ├── main.py                       # FastAPI entry, decides role from AGENT_ROLE
│   ├── decision.py                   # split-or-execute LLM call
│   ├── splitter.py                   # spawn children via BuildWithLocus
│   ├── executor.py                   # do the actual work via wrapped APIs
│   ├── synthesizer.py                # merge child reports
│   ├── reporter.py                   # POST to parent, then self-DELETE
│   ├── budget.py                     # spend tracking + pre-flight checks
│   └── prompts/
│       ├── decide.md                 # split-or-execute prompt
│       ├── execute_dd_specialist.md  # one per analyst type
│       └── synthesize_dd_memo.md     # root synthesis prompt
├── spawner/                          # always-on control plane
│   ├── main.py                       # FastAPI: POST /tasks, GET /tasks/{id}
│   ├── reaper.py                     # dead man's switch
│   ├── locus_client.py               # BuildWithLocus API wrapper
│   └── sse.py                        # demo UI live stream
├── ui/                               # Next.js demo
│   ├── app/
│   ├── components/TreeViz.tsx        # the live tree
│   └── lib/sse.ts
├── infra/
│   ├── Dockerfile                    # ONE Dockerfile, works for spawner + agent
│   └── locusbuild_sample.json        # for documentation, may not be used
├── scripts/
│   ├── spikes/                       # validation scripts
│   ├── check_balance.sh
│   ├── build_and_push.sh
│   └── seed_demo_task.sh             # submits the DD task for the demo
├── .env.example
├── .gitignore
├── README.md
└── PLAN.md
```

---

## Build Sequence

> Effective build days remaining: Sun (today, partial), Mon, Tue. Wed = polish + submit.

| Day | Goal | "Done" signal |
|---|---|---|
| **Sun (today)** | Build API auth resolved + spikes 1-3 green + spawner skeleton deploys | Can `POST /v1/services` from local; spawner reaches `healthy` on Locus |
| **Mon** | Single-agent path end-to-end | One agent spawns from spawner, makes one wrapped API call, reports back, self-deletes |
| **Tue AM** | Tree of depth 2 working | Root agent splits into 5 specialists, all complete, root synthesizes, demo task produces a real DD memo |
| **Tue PM** | UI + recorded backup video | Tree visualizer is presentable; 90s backup recording in hand |
| **Wed AM** | Live demo dry-run + polish | Full pitch executes live without intervention; backup tested |
| **Wed PM** | Submit | Repo + demo video link + 5-min pitch summary in README |

**Cut list if we slip**:
1. Drop demo UI — show terminal output + Postgres queries (ugly but proves the architecture)
2. Drop synthesis quality — root just concatenates child outputs (ugly but proves recursion)
3. Drop the depth-2 backup variant — demo only depth-1 (5 specialists, no grandchildren)

**Never cut**: real Locus deploys for every agent, real wrapped API calls, real self-DELETE, observable tree shape.

---

## Spike Validations

Before sinking days into building, prove the architecture is feasible.

### Spike 0 — Build API Auth (15 min, BLOCKER)

```bash
source .env

# Plan A: try direct Bearer with API key (no exchange)
curl -sS "$LOCUS_BUILD_API_URL/v1/projects" -H "Authorization: Bearer $LOCUS_API_KEY"

# Plan B: fetch the skill file and read auth section
curl -sS "$LOCUS_BASE_URL/api/skills/skill.md" > /tmp/locus-skill.md
grep -A 30 -i "auth\|exchange\|bearer" /tmp/locus-skill.md | head -50

# Plan C: Discord ask
```

**Pass criteria**: any Build API endpoint returns 200 with our key. Document the working pattern in `.env` as `LOCUS_BUILD_AUTH_HEADER=...`

### Spike 1 — Wallet Read + Wrapped API + Deduction (10 min)

```bash
# Balance before
BEFORE=$(bash scripts/check_balance.sh | jq -r '.promo_credit_balance')

# Cheapest wrapped API — OpenAI moderation
curl -sS -X POST "https://api.paywithlocus.com/api/wrapped/openai/moderations" \
  -H "Authorization: Bearer $LOCUS_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"input": "test"}' | jq

# Balance after
AFTER=$(bash scripts/check_balance.sh | jq -r '.promo_credit_balance')
echo "$BEFORE → $AFTER"
```

**Pass criteria**: response valid, balance decreased.
**Fallback**: if wrapped not on `api.paywithlocus.com`, try `beta-api.paywithlocus.com/api/wrapped/...`

### Spike 2 — Single Service Deploy from Pre-Built Image (20 min)

Prep — build a tiny ARM64 image:

```dockerfile
# infra/Dockerfile.spike
FROM python:3.11-slim
RUN pip install --no-cache-dir fastapi uvicorn
RUN printf 'from fastapi import FastAPI\napp=FastAPI()\n@app.get("/health")\ndef h(): return {"status":"ok"}\n@app.get("/")\ndef r(): return {"hello":"mitosis"}' > /app.py
EXPOSE 8080
CMD ["uvicorn","app:app","--host","0.0.0.0","--port","8080"]
```

Build + push:
```bash
docker buildx build --platform linux/arm64 \
  -t ghcr.io/fuadsn/mitosis-spike:latest \
  -f infra/Dockerfile.spike --push .
```

Deploy via Build API (uses auth pattern from Spike 0).

**Pass criteria**: deployment reaches `healthy` within 3 min; service URL returns `{"hello":"mitosis"}`.

### Spike 3 — Recursive Spawn Sanity (30 min)

The critical spike. Prove an agent can spawn another agent on Locus, *from inside a deployed worker*.

1. Modify the spike image to: on startup, count itself; if `DEPTH < 1`, spawn a child via Build API; report child's URL; exit.
2. Deploy with `DEPTH=0`. Watch a child appear automatically.

**Pass criteria**: depth-0 service spawns depth-1 service; depth-1 reaches `healthy`; depth-1 does NOT spawn further (depth bound holds).

If this fails, the entire architecture is invalid. Resolve before building anything else.

### Spike 4 — Tasks API Submission (10 min, optional for demo)

For the recorded backup video. Pull endpoint shape from `skill.md`, submit one tier-1 task, observe.

---

## Pitch Outline (5 min)

| Time | Beat | Visual |
|---|---|---|
| 0:00–0:30 | **Hook** — *"What if a task could decide for itself how big it needs to be?"* | Black screen, single sentence |
| 0:30–1:15 | **Problem** — monolithic agents hit context/budget walls; hand-orchestrated pipelines don't scale to open-ended work | Two failure-mode diagrams |
| 1:15–4:00 | **Live demo** — submit "DD on [real Series A startup]" with $5 budget. Watch root deploy. Watch root decide "I need 5 specialists" — 5 services bloom on Locus dashboard. Each specialist hits Exa + Claude. Reports flow back. Root synthesizes. Memo appears on screen. Tree collapses as agents self-delete. | Split-screen: live tree visualizer + the actual investment memo materializing |
| 4:00–4:40 | **Architecture reveal** — recursive spawn diagram, three Locus primitives, fiscal bounding as the only governor of recursion. Show the depth-2 recorded variant. | Diagram + recording overlay |
| 4:40–5:00 | **Close** — *"Mitosis isn't an app. It's a primitive. Any task that can be decomposed can run on it. We demoed VC due diligence. Tomorrow it's legal review, code refactoring, scientific literature synthesis. The agent decides."* | Tagline + repo + demo link |

### Q&A Prep

- **"What stops infinite recursion?"** → Fiscal substrate. Each split divides the budget. `MIN_BUDGET_FOR_SPLIT = $0.50` forces leaves. `MAX_DEPTH = 4` is belt-and-suspenders, but the wallet is the real bound.
- **"Cold start of 1-2 min per spawn — isn't that slow?"** → Yes, intentionally. Spawning is expensive, so agents only split when the LLM judges the task genuinely benefits from specialization. Cheap for narrow tasks, slower for big ones — that's the right shape.
- **"What if a child crashes mid-task?"** → Reaper in the spawner (60s sweep) force-kills orphaned services and sends synthetic "failed" reports. Parent synthesizes with what it has.
- **"How is this different from LangGraph / CrewAI?"** → Those are libraries that orchestrate inside one process. Mitosis's agents are *separate deployments* with *separate wallets* and *real OS-level isolation*. No shared state, no shared budget, no shared crash domain. It's the difference between threads and microservices.
- **"Can grandchildren of children of children work?"** → Demo shows depth 1 live; backup video shows depth 2. Depth 4 has been tested offline (or: "is the configured ceiling — we held back to keep the demo readable").

---

## Judging Rubric Alignment

| Dimension | Points | Our play |
|---|---|---|
| **Technical Excellence** | 30 | Real BuildWithLocus per-agent deploys (not faked), real wrapped API metering, real self-DELETE, real fiscal bounding via on-chain wallet, dead-man's switch reaper |
| **Innovation & Creativity** | 25 | Recursive self-spawning agents is genuinely novel — not in the example list, no team will do this. Fiscal bounding *as the recursion governor* is the architectural insight. |
| **Business Impact** | 25 | Demo task (Series A DD) is a real workflow VCs in the room recognize. Memo is a real artifact, not a toy. The platform generalizes to any decomposable knowledge work. |
| **User Experience** | 20 | Tree visualizer is the product surface. Live spawning is the wow moment. Memo as artifact gives the demo a concrete payoff. |

---

## Risk Register

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 0 | **Build API auth blocker (Spike 0) cannot be resolved** | M | **Catastrophic** | Read skill.md immediately; Discord ask in parallel; if hard-blocked by Mon noon, fall back to mocked-deploy demo (architecture story still valid, but loses "real Locus" credibility) |
| 1 | Cold start 1-2 min per spawn makes 6-agent demo take 6-10 min | H | H | Pre-deploy root agent before pitch starts; only the 5 specialists spawn live (parallel, ~2 min total); narrate the wait |
| 2 | LLM decision (split vs execute) is unreliable / inconsistent | M | M | Stable seed, low temperature, structured output validation; canned task that we know triggers split |
| 3 | Recursive spawn from inside a worker fails (Spike 3) | M | **Catastrophic** | Spike 3 IS the early-warning. If it fails, redesign as "central spawner orchestrates all spawns" instead of agent-spawns-agent |
| 4 | Synthesis quality is bad → memo looks junk | M | M | Strong synthesis prompt with explicit structure; demo memo on a startup with rich public info to reduce dependency on search quality |
| 5 | Credit grant comes back at $5 not $50 | H | H | $2 fixed + $3 wrapped + buffer = ~$5 minimum demo cost. Possible. If granted only $5, drop synthesis grandchild calls and use template-based synthesis |
| 6 | Live demo deploy fails during pitch | M | H | Pre-recorded 90s backup with voiceover ready; switch within 10s |
| 7 | Tree visualizer doesn't render fast enough | L | M | Server-render the static post-completion view as fallback |
| 8 | A specialist agent overspends its budget | M | L | Pre-flight cost check before each wrapped call; emergency-return on overspend; parent synthesizes with partial results |
| 9 | Two children try to spawn simultaneously and exceed total budget | L | M | Spawner enforces global service-count cap; parent's distributable budget is locked at split-time |
| 10 | Service spawn API has rate limits we don't know about | M | M | Spike 0 includes spawning 6 services in quick succession to verify; if rate-limited, serialize spawns at 5s intervals |

---

## Deferred / Out of Scope

- Multi-region deploys (us-east-1 only)
- Custom domains
- Git-push deploy (using pre-built image only)
- Multi-environment isolation (single production env)
- Persistent agent memory across runs (each task is fresh)
- Real Tasks API live in demo (recorded only)
- Generic adapter SDK for other domains (DD prompts hardcoded)
- Tree depth > 2 in live demo (recorded only)
- Cost optimization beyond pre-flight checks (no caching, no de-dup of wrapped calls across agents)

---

## Open Questions for Next Session

1. ⚠️ **Build API auth with beta `claw_dev_*` key** — the gating question. See Spike 0.
2. **Wrapped API base URL** — confirm `api.paywithlocus.com` vs `beta-api.paywithlocus.com`
3. **Tasks API endpoint shape** — pull from skill.md (only matters for backup recording)
4. **Per-service env var injection at create time** — confirm we can pass arbitrary env vars in the `POST /v1/services` body, not via separate variables PUT (avoids extra round-trip per spawn)
5. **Service spawn rate limits** — undocumented; Spike 3 will flush them out
6. **GHCR pull from Locus** — confirm public GHCR pulls work; if not, push to a registry Locus prefers
7. **`DELETE /v1/services/{id}` cascade behavior** — does it instantly tear down running containers, or schedule? Affects how fast the tree collapses visually.

---

## Carryover from Sentinel Planning

Salvaged from the previous (Sentinel) plan:

- **Repo**: `https://github.com/fuadsn/sentinel` (will rename to `mitosis` next)
- **API key + .env**: same beta key, unchanged
- **Gift code request**: `52606d86-658f-4442-a7b7-45b60f5ea0fd` filed Sun, $50 asked
- **`scripts/check_balance.sh`**: still works as-is
- **Build API auth blocker**: confirmed during Sentinel planning, carries over as Spike 0
- **Tech stack**: Python/FastAPI/ARM64/GHCR/Postgres — all unchanged
- **GHCR setup**: still needed before Spike 2

Discarded:
- All Shopify / T&S / per-tenant moderation logic
- 3-tenant brand fixtures
- Staged-degradation kill switch (Mitosis bounds via fiscal recursion, not staged degradation)
- Engine/adapter split (Mitosis is one cohesive system, not a platform)

---

## Next Session Quick Start

```bash
# 1. Orient
cd /Users/fuad/Developer/Projects/personal/sentinel  # or mitosis after rename
cat PLAN.md | less

# 2. Verify wallet + credit status
bash scripts/check_balance.sh

# 3. CRITICAL — resolve Build API auth (Spike 0). Nothing deploys until this passes.
curl -sS "$LOCUS_BUILD_API_URL/v1/projects" -H "Authorization: Bearer $LOCUS_API_KEY"
# If 401, fetch skill.md and read auth section
curl -sS "$LOCUS_BASE_URL/api/skills/skill.md" > /tmp/locus-skill.md

# 4. Once auth resolved, build + push the spike image
docker buildx build --platform linux/arm64 \
  -t ghcr.io/fuadsn/mitosis-spike:latest \
  -f infra/Dockerfile.spike --push .

# 5. Run Spikes 1 → 3 in order
# 6. Start spawner skeleton
```

**Session 1 success criteria**:
- Spike 0 passes (Build API auth pattern documented in `.env`)
- Spikes 1, 2, 3 all green
- Spawner FastAPI skeleton deploys to Locus and reaches `healthy`
- Agent FastAPI skeleton built (decide → execute path only, no split yet)
- One end-to-end submission works: spawner accepts a task, deploys one agent, agent makes one wrapped API call, reports back, self-deletes.

If Sun ends with all of the above, Mon is on track.
