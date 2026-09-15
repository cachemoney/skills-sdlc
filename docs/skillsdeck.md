# Skills for the SDLC: Practical AI Usage

> Using Agent Skills to make coding agents more reliable, more disciplined, and less supervised — across the software development lifecycle.
>
> Links: [github.com/gregwebs/skills-sdlc](https://github.com/gregwebs/skills-sdlc) · [github.com/mattpocock/skills](https://github.com/mattpocock/skills)

---

## Slide 1: Title

**INTERNAL ENG TALK**

# Skills for the SDLC
### Practical AI Usage

Using Agent Skills to make coding agents more reliable, more disciplined, and less supervised — across the software development lifecycle.

- `github.com/gregwebs/skills-sdlc`
- `github.com/mattpocock/skills`

---

## Slide 2: Why Skills Matter

**THE BIG PICTURE**

> **Without good skills, AI will not produce good results — no matter how closely you supervise it.**

Skills turn ad-hoc prompting into reusable, on-demand discipline:
good prompts, managed context, and a feedback loop that catches mistakes before they compound.

---

## Slide 3: What We'll Cover

**AGENDA**

- **Context & skill design** — why huge context windows don't save you, and how to write skills without garbage bash
- **What an Agent Skill actually is** — `SKILL.md`, progressive disclosure, model- vs user-invoked
- **mattpocock/skills** — the foundation: alignment, feedback loops, architecture discipline
- **gregwebs/skills-sdlc** — our layer on top: planning, adversarial review, PR automation
- **The end-to-end workflow, stitched together**

---

## Slide 4: Context Management

**SKILLS · CONTEXT**

Even a model that supports a 1 million-token context window won't follow instructions or perform well once you actually fill it that far — that's an information-retrieval capability, not a coding one.

> **Bring things into context when they're needed, and discard them once they're not.**

- In a normal chat, forking or rewinding a conversation helps — but heavy skill utilization beats staying in a "normal" chat flow at all.

---

## Slide 5: Minimize AGENTS.md, Maximize Discoverability

**SKILLS · CONTEXT**

- **Minimize your `AGENTS.md` / `CLAUDE.md`** — as a side benefit, most of what the agent needs to know ends up documented for everyone else too.
- **Make documentation discoverable when it's needed:** `CODING_STANDARDS.md`, `CONTRIBUTING.md`, and `USAGE.md` can live separately from `README.md`.
- **Launch sub-agents and hand them specific context** — this is best captured by skills.
- **Skills bring context in only when it's needed:** move things out of `AGENTS.md` and into skills. By carefully launching sub-agents and managing the information flow, skills manage context — and can even pick the right model for the job.

> **Second Opinion:** An independent code review is often best done by a separate sub-agent — it hasn't seen your reasoning, so it can't rubber-stamp it.

---

## Slide 6: What is an Agent Skill?

**FOUNDATIONS**

A Skill is a folder with a `SKILL.md` file: instructions, metadata, and optional bundled scripts/templates that give an agent reusable, on-demand expertise.

- **Model-invoked** — the agent reaches for it automatically when the task matches its description.
- **User-invoked** — you call it explicitly, e.g. `/implement`.

### Progressive Disclosure

| Level | Loaded | Cost |
| :--- | :--- | :--- |
| **metadata** | always, at startup | ~100 tokens |
| **instructions** | when triggered | <5k tokens |
| **resources** | only if accessed | ~0 until needed |

*A skill with dozens of reference files costs nothing until the agent actually opens them.*

---

## Slide 7: Good Prompts, Mostly via Skills

**SKILLS · AUTHORING**

Good prompts should be handled mostly by skills: we want highly reusable, reliable skills that are still flexible enough to accept ad-hoc instructions on top.

### Skill Code and Garbage Bash

The most useful skills tend to have very little code.

| The Trap | What's Fine | Otherwise |
| :--- | :--- | :--- |
| Stop having agents write garbage bash just because it's "a skill." Can you understand and own a hundred-line script? Does it touch credentials? AI-slop bash handling credentials is a security vulnerability you just created. | Small, simple bash you're genuinely comfortable reviewing and owning end-to-end is fine. | Write a real program. Have the agent produce quality code in a language your org already uses — it doesn't need to be a scripting language, just easy to run. Go is a great fit if your org uses it; Python gets harder to run reliably once you step outside the standard library. |

---

## Slide 8: Two Skill Libraries, Stacked

**THE STACK**

| Foundation: `mattpocock/skills` | Our Overrides: `gregwebs/skills-sdlc` |
| :--- | :--- |
| General-purpose engineering discipline: alignment, TDD, code review, debugging, architecture. Model-agnostic, designed to be hacked on. | Adds a stricter `spec → plan → implement → review → verify` pipeline, adversarial review at every stage, and GitHub-specific automation (PRs, CI). |

`skills-sdlc` depends on `mattpocock/skills` for most of its skills — but for `/implement` it doesn't depend on the upstream version at all, it replaces it entirely with its own skill, installed to override the same-named mattpocock skill rather than build on it.

---

## Slide 9: Four Failure Modes These Skills Target

**MOTIVATION**

| Failure Mode | Problem & Solution |
| :--- | :--- |
| **1. Agent didn't do what I wanted** | Misalignment between what you meant and what got built.<br>→ **Fixed by:** `/grill-with-docs` — an interview before any code is written. |
| **2. Agent is way too verbose** | No shared vocabulary, so the agent narrates instead of naming things.<br>→ **Fixed by:** A living `CONTEXT.md` glossary. |
| **3. The code doesn't work** | No feedback loop.<br>→ **Fixed by:** `/implement`, which orchestrates planning, TDD, and review instead of coding straight through — plus `/diagnosing-bugs` for the hard cases. |
| **4. We built a ball of mud** | Agents accelerate entropy as much as velocity.<br>→ **Fixed by:** `/improve-codebase-architecture`, run periodically as a survey, not a rescue. |

---

## Slide 10: Deep Dive: `/grill-with-docs`

**MATTPOCOCK/SKILLS · DEEP DIVE**

A relentless interview that aligns the AI with you before a line of code is written, and generates a thorough specification as it goes — resolving every branch of the design tree and building a shared language along the way.

- Interviews you the way a good tech lead would, until ambiguity is gone.
- Updates `CONTEXT.md` with sharpened domain terms — "materialization cascade" instead of three sentences of explanation, every session after.
- Captures hard-to-explain decisions as ADRs inline.
- Pays off repeatedly: fewer tokens spent re-explaining, more consistent naming, easier navigation.

> `/implement` is actually the most-used skill day to day — but it only works well once `/grill-with-docs` has done its job.

---

## Slide 11: Two Feedback-Driven Loops: `/implement` and `/diagnosing-bugs`

**MATTPOCOCK/SKILLS · DEEP DIVE**

Two full, self-contained loops at the same grain: one turns a spec into working code, the other turns a bug report into a fix. Both lean on tight feedback to stay honest.

| `/implement` (User-invoked) | `/diagnosing-bugs` (Model-invoked) |
| :--- | :--- |
| In `mattpocock/skills` this is a thin orchestrator: implement the spec/tickets, use `/tdd` at pre-agreed seams, typecheck and run tests regularly, close out with `/code-review`, then commit. *(skills-sdlc later replaces this with a fuller multi-agent pipeline — coming up.)* | A gated 6-phase loop for hard bugs and perf regressions:<br>`build a tight red-capable repro` → `reproduce & minimize` → `3–5 falsifiable hypotheses` → `instrument one variable at a time` → `fix with a regression test` → `clean up`.<br>The agent reaches for it automatically on "debug this" or a failure report. |

> `/tdd` is the technique both loops call on at each seam — red before green, one vertical slice at a time — not a peer workflow to either of them.

---

## Slide 12: Deep Dive: `/improve-codebase-architecture`

**MATTPOCOCK/SKILLS · DEEP DIVE**

Agents can radically speed up coding — which also radically speeds up software entropy. This skill is the counterweight.

- Scans the codebase for **deepening opportunities** — places where a shallow module could hide more behind a simpler interface.
- Presents candidates as a visual HTML report, then grills you through whichever one you pick.
- **It's a survey, not a rescue** — on a genuinely old codebase it finds real candidates, it won't untangle the mud for you.
- **Recommended cadence:** run it every few days, not once at the end.

---

## Slide 13: The Catalog, at a Glance

**MATTPOCOCK/SKILLS**

| User-invoked *(you call these)* | Description | Model-invoked *(agent reaches for these)* | Description |
| :--- | :--- | :--- | :--- |
| `/grill-with-docs` | Align + build domain model | `/tdd` | Red-green-refactor |
| `/to-spec` | Conversation → published spec | `/diagnosing-bugs` | Disciplined debugging loop |
| `/to-tickets` | Plan → tracer-bullet tickets | `/code-review` | Spec-axis + standards-axis review |
| `/implement` | Build a spec, drives `/tdd` + `/code-review` | `/domain-modeling` | Sharpen glossary against edge cases |
| `/wayfinder` | Plan work too big for one session | `/resolving-merge-conflicts` | Hunk-by-hunk, intent-traced |
| `/triage` | Move issues through triage states | `/research` | Cited findings from primary sources |

---

## Slide 14: Installing mattpocock/skills — Three Techniques

**GETTING IT RUNNING**

| Technique | Command | Characteristics |
| :--- | :--- | :--- |
| **`subscribe`**<br>Claude Code plugin | `/plugin install mattpocock-skills` | Managed, read-only bundle. Updates arrive automatically. In the official marketplace, nothing to add first. |
| **`fork`**<br>skills.sh installer | `npx skills@latest add mattpocock/skills` | Copies editable files into your repo. You own them, hack on them, and pull updates on demand with `npx skills update`. |
| **`symlink`**<br>Clone + symlink | Clone the repo yourself, then symlink individual skills from `~/.agents/skills` (and/or `~/.claude/skills`) into it. | Manual, but full control — and it's what lets you layer `skills-sdlc`'s override of `/implement` on top of the same-named upstream skill. |

> Run `/setup-matt-pocock-skills` once per repo: it asks which issue tracker (GitHub / Linear / local files), triage labels, and where docs get saved.

---

## Slide 15: What Our Layer Adds

**GREGWEBS/SKILLS-SDLC**

`skills-sdlc` orchestrates the same tools into a stricter pipeline aimed at two goals: higher agent code quality, and less of your time spent supervising.

```
[spec] ──> [plan] ──> [implement] ──> [review] ──> [verify] ──> [commit / PR]
```

- Requires you to stay **deeply involved at the speccing/planning stage** — mostly optional after that.
- **Trade-off:** takes longer and costs more up front; pays back on defects and change-cost over a sustained codebase (less useful for a throwaway prototype).
- Applies consistent coding standards, compiled per-project from a shared library.

---

## Slide 16: The Implementation Plan

**GREGWEBS/SKILLS-SDLC · DEEP DIVE**

mattpocock's `/to-spec` is intentionally light on detail, since details change. `skills-sdlc` adds a detailed **Implementation Plan**, generated fresh at the start of implementation.

| Planner Agent (`Opus`) | Implementer Agent (`Sonnet`) |
| :--- | :--- |
| Smarter, costlier. Produces the design: background, intuition, file-level changes, tests, diagrams, failure modes, a task checklist. | Cheaper, faster. Executes an already-approved plan without redesigning it. Handles the bulk of the token spend. |

> Plan mode can require explicit approval before implementation starts — or, once you're aligned via `/grill-with-docs`, `skills-sdlc` can move automatically.

---

## Slide 17: `/implement`: The Orchestrator

**GREGWEBS/SKILLS-SDLC · DEEP DIVE**

The skill's only job is to hand work between fresh sub-agents — it never plans or codes inline.

```
Phase 1 — Plan
planner agent runs /implementation-plan, includes an adversarial review
       │
       ▼
Phase 2 — Execute
implementer agent follows the plan, TDD at pre-agreed seams
       │
       ▼
Phase 3 — Review
/code-review-with-followup by a reviewer/planner agent
       │
       ▼
Phase 3 — Verify
fresh implementer runs the verification checklist e2e
       │
       ▼
Phase 4 — Complete
commit, PR, watch CI, /document-changes
```

---

## Slide 18: Adversarial Review, at Every Stage

**GREGWEBS/SKILLS-SDLC · DEEP DIVE**

Both the plan and the code get an independent, adversarial review — a separate agent whose only job is to find problems, not to defend its own work.

### Plan Review Order
1. **Spec completeness & scope**
2. **Architecture** (module boundaries, ADRs)
3. **Quality** (standards, tests, operational risk)

### Code Review, Two Axes
- **Standards** — repo conventions + a Fowler smell baseline.
- **Spec** — does the diff faithfully implement the ticket?

*Run as parallel sub-agents so neither pollutes the other's judgment.*

---

## Slide 19: Artifact-Based Handoffs

**GREGWEBS/SKILLS-SDLC · DEEP DIVE**

Every planner, reviewer, and implementer sub-agent starts with **no inherited conversation history** — this keeps context lean and prevents earlier mistakes from contaminating later stages.

- Agents hand off through task-scoped Markdown artifacts in a temp directory **outside the repo** — `task-brief.md`, `implementation-plan.md`, `implementation-result.md`, `verifications.md`.
- Each artifact is self-contained: the plan restates all the ticket detail the implementer needs.
- Absolute artifact paths are passed between agents, not pasted transcripts.

---

## Slide 20: Shipping the Work

**GREGWEBS/SKILLS-SDLC · DEEP DIVE**

| Skill / Integration | Behavior & Capabilities |
| :--- | :--- |
| **`/pull-request`** | Branches correctly (default vs. parent vs. stacked), writes the description via `/document-changes`, auto-closes the issue with "Resolves #N". |
| **`/github-app`** | Authenticate as a GitHub App instead of as you — PRs don't impersonate you, and permissions are scoped down. The Claude GitHub App can't do this; it always acts as you. |
| **`/github-actions-ci`** | A bundled, allow-listed check-run helper so the agent can watch CI and react to failures without prompting you for permission on every call. |

---

## Slide 21: Installing & Customizing skills-sdlc

**GETTING IT RUNNING**

### Script Helpers
- `./scripts/install-skills.sh` — audits every skill reference in your docs, links matching skills into `~/.agents/skills` (and `~/.claude/skills`)
- `./scripts/install-agents.sh` — links the `planner` / `implementer` agent definitions
- `./scripts/install-standards.sh coding go security` — compiles chosen `standards/*.md` docs into your project's `CODING_STANDARDS.md`

### Per-Repo Customization
You customize per-repo via:
- `AGENTS.md` — workflow + tool usage notes
- `CODING_STANDARDS.md` — writing & reviewing code
- `CONTRIBUTING.md` — how to run/test the project
- `USAGE.md` — public interface docs, if any

*The skills themselves stay generic across language and project.*

---

## Slide 22: The Workflow, End to End

**PUTTING IT TOGETHER**

```
[idea / conversation] ──> [/grill-with-docs] ──> [/to-spec] ──> [/breakdown or /to-tickets]
                                                                        │
                                                                        ▼
[merged] <── [CI watched via /github-actions-ci] <── [/pull-request] <── [/implement]
```

- `/implement` itself expands into its own 4-phase pipeline — plan, execute, review, verify, complete — each phase a fresh sub-agent with artifact handoffs (see the orchestrator slide earlier).
- Two entry points started by you (a frontier model): a new feature via `/grill-with-docs`, or a fix via `/diagnosing-bugs`. Everything downstream is mostly optional supervision.

---

## Slide 23: When This is Worth It

**HONEST TRADE-OFFS**

| ✓ Worth it when | ✗ Costs you |
| :--- | :--- |
| The codebase is sustained and non-prototype. Fewer defects and a more agile codebase pay back the extra up-front cost over time. | More time for the agent to complete a task. Higher cost to finish the first version of a feature. Requires your real engagement at spec/plan time. |

> This is not a "vibe coding" shortcut — it's an investment in discipline that agents will happily apply if you direct them to: linting, CI, e2e tests, all of it. The skills provide the scaffolding; the standards are still on you.

---

## Slide 24: Takeaways

**WRAPPING UP**

- **Skills = reusable, on-demand discipline** — not magic prompts
- **Minimize `AGENTS.md`, maximize discoverability** — let skills bring in context only when it's needed
- **`mattpocock/skills`** fixes alignment, feedback loops, and architecture entropy
- **`skills-sdlc`** adds planning rigor, adversarial review, and safe GitHub automation
- **Try it on a real ticket:** `/grill-with-docs` → `/to-spec` → `/implement`
