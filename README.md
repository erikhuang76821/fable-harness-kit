# fable-harness-kit

**English** | [繁體中文](README.zh-TW.md)

**A multi-model development harness template for Claude Code**: instead of paying for a more
expensive model, buy back its thinking discipline with process enforcement. The judgment calls —
*where to doubt, how many times, who arbitrates, when to converge* — are sunk from model
temperament into hooks and workflow scripts, so that **Opus 4.8 (planning/arbitration) +
Sonnet (execution) + Codex/Agy (cross-model review)** approaches Fable-class output.
Cost envelope: ≤ what bare Fable 5 costs for the same task.

Core equation: **Opus 4.8 + fable-emu workflow (pre-compiled orchestration judgment) ≈ Fable 5**

**Evidence-level statement**: the equation and cost envelope come from the author's internal
ablation experiments (4 groups × 3 runs, double-blind scoring, 2026-07); raw data is not shipped
with the kit — adopters should treat them as a **working hypothesis** to verify on their own
tasks, not an established benchmark. The kit's own decision core demands exactly this: an
unverified claim is a pending hypothesis, not truth.
**2026-07-07 update**: the first controlled measurement ([`benchmark/REPORT.md`](benchmark/REPORT.md),
pre-registered protocol, blind dual judges from non-Claude model families) supports the equation
on 4 small-to-mid verifiable tasks: pass rate tied 4/4, quality delta −0.13 (tolerance −0.5),
cost 59%. Evidence level: **calibration-grade (n=4)** — does not extrapolate to large,
long-horizon tasks (see the honest-reading section of the report). Raw evidence:
[`benchmark/evidence/`](benchmark/evidence/).

> **Who it's for**: teams whose primary models are Opus/Sonnet, who want Fable-class
> self-doubt and verification discipline, and who care about cost.
> **Prerequisites**: Claude Code (Windows; hooks and scripts are PowerShell — mac/linux users
> should port them or use pwsh). Optional: `codex` and `agy` CLIs for cross-model review;
> when absent the kit degrades honestly to single-family review with an audit trail.
> **Not on Claude Code?** The hooks and workflow enforcement layers are **not portable**;
> what ports is the prompt clauses and the decision core (AGENTS.md for Codex, GEMINI.md for
> Gemini) — see `docs/HARNESS.md` §2.5.
> **Quick start**: click "Use this template" on GitHub for a new project, or run `init.ps1`
> against an existing repo (below).

## What's inside

```
fable-harness-kit/
├── README.md / README.zh-TW.md     # this file (not copied into target repos)
├── init.ps1                         # one-shot installer (not copied)
├── CLAUDE.md                        # template: tiered routing + decision core + prompt clauses (fill TODOs)
├── CONTEXT.md                       # template: domain glossary + architecture map (fill in)
├── fable-run.ps1                    # supervised headless runner for Tier 2/3 (truncation detect + resume)
├── docs/
│   ├── DECISION-CORE.md             # decision core: authorization / fact rulings / criteria, with evidence tags
│   ├── TIER3-FRONTIER.md            # frontier mode: de-prescribed deep-dive template + tournament math
│   ├── HARNESS.md                   # full design guide (prompt-ceiling table, model routing)
│   ├── invariants.md                # template: invariants — guardrails for weaker models
│   └── adr/0001-adopt-fable-harness.md
├── benchmark/                       # controlled benchmark: bare Fable 5 vs kit-ified Opus
│                                    #   (pre-registered PROTOCOL.md; blind non-Claude dual judges)
├── scripts/
│   ├── canary.ps1                   # one-click end-to-end canary after fable-emu changes
│   ├── schedule-canary.ps1          # weekly scheduled canary: senses silent upstream model drift
│   └── upstream-suggestions.ps1     # fleet feedback: deployed projects' accepted lessons → kit issues
├── tests/                           # behavior contracts: hooks (Pester) + workflow (node --test stub runner)
└── .claude/
    ├── settings.json                # six hooks incl. two Stop gates (verify first, retro second)
    ├── status-contract.json         # single source of workflow statuses
    ├── agents/                      # adversarial reviewers: spec-lawyer / regression-hunter / invariant-auditor
    ├── hooks/                       # git-guard / session-brief / prompt-nudge / verify-gate / stop-retro-gate / rule-guard
    └── workflows/
        ├── fable-emu.js             # Tier 2: understand → plan → execute → cross-model review → completeness
        └── deep-attempts.js         # Tier 3 tournament: N parallel deep dives (worktree-isolated) + judged
```

The adversarial agents can be dispatched by name at Tier 0/1 ("send spec-lawyer at this diff");
they share one design with fable-emu's Tier-2 panel — *information slicing*: cut the author's
persuasion, never the facts a judgment needs.

## Install

```powershell
# Option 1: script (copies only files that don't exist in the target; never overwrites)
powershell -NoProfile -ExecutionPolicy Bypass -File .\init.ps1 -Target C:\path\to\your\repo

# Option 2: manual — copy everything except README* / init.ps1 / LICENSE / benchmark into the repo root
```

## Post-install checklist (mandatory)

1. **CLAUDE.md**: fill every `TODO(...)` — build/test/lint commands, the project's definition of trivial.
2. **CONTEXT.md**: domain glossary and architecture map. Write the *why*, not what the code already shows.
3. **docs/invariants.md**: list the rules this project must never break, one per line.
4. **Cross-model review only needs a CLI on PATH**: either `codex` or `agy` — fable-emu's bridge
   agent detects and calls the CLI directly (echo-grounding acceptance guards against a half-broken
   bridge fabricating empty reviews); **no plugin/skill install required**. With neither present it
   degrades to a same-family persona panel (spec lawyer: spec but no author rationale; regression
   hunter: diff plus one-line intent but no author reasoning; `thorough` adds an invariant auditor).
   Slicing principle: cut the persuasion, not the facts. Shared same-weights blind spots cannot be
   bought back — arbitration must read the code, and the degradation is disclosed in logs and the
   final report.
5. **Trial run**: hand it a small real task — "handle with the fable-emu workflow: <task>" — and
   watch each phase. Afterwards, any change to fable-emu.js: run the contract tests first
   (`node --test tests/workflow-contract.test.mjs tests/persona-sync.test.mjs`, seconds), then
   `scripts/canary.ps1` before merging (~$1, fixed fixture, artifacts kept). Unit tests hold the
   contracts; the canary holds reality — failures like a scribe model hallucinating only show up live.
6. (Optional) auto lint/typecheck: **append** a handler to the existing PostToolUse array
   (⚠️ don't replace the array — you'd wipe the built-in rule-guard audit hook).

## Cost envelope (settled by ablation; raw data lives in the dev repo, not shipped)

**Design goal: cost ≤ bare Fable 5 on the same task, same order-of-magnitude time, quality no worse.**

- **Tiered routing** (CLAUDE.md): Tier 0 prompt layer (default) → Tier 1 + fresh-context verifier
  (high-risk single module) → Tier 2 fable-emu (cross-module / irreversible; interactive sessions only).
- **fable-emu cost control**: plan arena and insight agent only for `complex`; single reviewer by
  default (`thorough` for two); haiku verification for low-risk steps; batched journaling; retro
  only when something is worth retro-ing. Target ~$1.0–1.3 per run.
- **Ship-first criterion**: for an irreversible disagreement with a reversible default path,
  ship the reversible part and escalate the dispute with the final report — deliverable work
  never blocks on a pending decision.
- **Reference, don't copy**: task understanding is journaled to `.fable/runs/<slug>/ctx.md` and
  referenced by path; execution steps carry one progress line + last-step detail (the old design
  re-injected the whole history each step — quadratic context cost).
- **Cost telemetry**: fable-run sums `total_cost_usd` and tokens from the stream-json result
  events into `.fable/COST-LOG.md` — the envelope claim audits itself with every run.
- **Controlled benchmark**: `benchmark/` measures bare Fable 5 vs kit-ified Opus under a
  pre-registered protocol with blind non-Claude dual judges — the mechanism that upgrades the
  core equation from working hypothesis to reviewable measurement.
- **Headless truncation protection**: `fable-run.ps1` (terminal-state detection + bounded
  resume) plus delivery checkpoints at phase boundaries — truncation no longer loses deliverables.
- **Tier 3 (frontier)**: hard problems skip the pipeline (orchestration is leverage for medium
  tasks, a tax on hard ones) — a single Opus xhigh deep-dive (half Fable's unit price = twice the
  tokens for the same money), or `deep-attempts` tournaments when an objective verifier exists.
  See docs/TIER3-FRONTIER.md, including the honest boundary: taste problems without verifiers
  and multi-day autonomy remain Fable terrain.

## Context tax (measured estimate)

| Scope | Tokens (approx.) | Of a 1M window |
|---|---|---|
| Auto-loaded per session (CLAUDE.md + hook brief) | 2,600 | 0.26% |
| Starting a task (+ required reading: DECISION-CORE / CONTEXT / invariants) | 4,300 | 0.43% |
| Reading the whole kit (only when explicitly asked) | 27,000 | 2.7% |

fable-emu.js (~11k tokens) never enters the main model's context in normal operation — the
harness executes the workflow and its prompts go to subagents piecemeal. Estimation: CJK ≈ 1.1
token/char, other ≈ 4 chars/token, ±30%.

## Ceiling mechanisms (spend on generation; the verification funnel never bends)

Principle: **raise the ceiling on the generation side, lock the floor on the verification side,
never swap the two.** All exploratory output merges through the same verification funnel — no VIP lane.

| Mechanism | What it does | Trigger |
|---|---|---|
| Complexity grading | Understand rates trivial/standard/complex → how much planning redundancy to buy | every run |
| Plan arena | 2 planners with opposed stances in parallel; a judge synthesizes | complex only, budget allowing |
| Insight agent | "What would a stronger engineer see that this plan misses?" fundamental findings trigger one revision | complex only, budget allowing |
| Replan loop | Reality falsifies a plan premise → replan the remainder with facts on the ground (once) | plan_invalidated |
| Risk-graded verification | High-risk steps: dual-lens (correctness + regression), all must pass; low-risk: haiku single. Grading cuts generation cost, never blocking power | every step |
| Metacognitive safety valve | Task fundamentally doesn't fit the pipeline → explicit escalation with a suggested route | process_mismatch |
| Maverick sandbox | An isolated worktree tries a radically different route; report-only, never auto-merged | args.maverick (opt-in) |
| Post-run retro | Process-waste analysis + rule-promotion candidates → .fable/KIT-SUGGESTIONS.md for human review | when there's something to review |
| Budget bulkheads | 30% of budget reserved for verification/review; exploration cannot invade it | when a budget is set |

## Audit trail (.fable/, written by the workflow)

- `.fable/runs/<slug>/TASK.md` — live task state: definition of done, step checkboxes, blockers
- `.fable/DECISIONS.md` — append-only: trade-offs, escalations, review arbitrations (rejected findings included)
- `.fable/LESSONS.md` — append-only: lessons from refuted attempts and reviewer-caught blind spots
- `.fable/KIT-SUGGESTIONS.md` — `- [pending] suggestion (evidence: ...; date)`; humans mark
  [accepted]/[rejected]; only accepted entries become rules. The loop is hook-driven: Stop hook
  forces writing, SessionStart forces reading, rule-guard keeps the provenance chain.

Next task's understand phase **must read** LESSONS and DECISIONS — lessons persist across tasks
instead of dissolving into chat history. Commit `.fable/` (it's team knowledge, not scratch).

## Known limitations (accepted residual risk)

- **git-guard is best-effort, not a sandbox**: the regex gate stops common dangerous forms
  (flag-position variants included) — it guards against model slips, not adversaries. The
  block/allow samples are pinned by `tests/git-guard.Tests.ps1`.
- **The two Stop gates yield to each other boundedly**: each blocks at most once
  (`stop_hook_active`); worst case a session close is blocked twice (evidence once, retro once),
  never an infinite loop.
- **verify-gate can't see verification inside subagents** (transcripts are separate): if blocked,
  cite the subagent's evidence (command + result) in your reply and the next close passes.
- **Hooks use relative paths**: they rely on Claude Code running hooks from the project root.
- Auto-lint and a codex review gate remain opt-in — append handlers, never replace arrays.

## Design notes

- Prompts govern quality and style; **everything non-negotiable (verification counts, votes,
  budgets, dangerous commands) sinks into the harness.**
- Fan-out subagents and agent loops are Claude Code capabilities, model-agnostic — Opus 4.8 gets
  them all; what Opus lacks is initiative, supplied by CLAUDE.md trigger rules.
- Codex/Gemini serve as callable single workers (review, second opinions), never as the orchestrator.
- The residual (single-shot reasoning depth) is bought back with token redundancy: higher effort,
  judge panels, multi-round adversarial review.
- Prompt craft (rationalization-alarm table, evidence-gate phrasing, SessionStart injection) is
  absorbed from [obra/superpowers](https://github.com/obra/superpowers) — a refined prompt layer
  on which this kit adds the deterministic layer it lacks (JS workflows + schemas + journaling).

Full discussion: `docs/HARNESS.md`. How this kit was built (method + real evidence chains):
`docs/METHOD.md`.

## License

MIT — see [LICENSE](LICENSE).
