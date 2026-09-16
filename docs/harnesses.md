# Supported Agent Harnesses

This repository supports five agent harnesses. Skills install to each harness's
discovery directory; the `planner` and `implementer` agent definitions are
authored per harness to match its schema.

| Harness | Skills installed to | Agents installed to | `planner` model | `implementer` model |
| :--- | :--- | :--- | :--- | :--- |
| Claude Code | `~/.agent/skills`, `~/.claude/skills` | `~/.claude/agents` (from `agents/`) | Opus | Sonnet |
| Codex | `~/.agent/skills` | `~/.codex/agents` (from `.codex/agents/`) | `gpt-5.6-sol` | `gpt-5.6-terra` |
| Pi | `~/.agent/skills` | `~/.pi/agent/agents` (from `.pi/agent/agents/`) | configured in harness | configured in harness |
| Antigravity CLI | `~/.gemini/config/skills` (also `~/.gemini/antigravity-cli/skills` if present) | `~/.gemini/config/agents` (from `.antigravity/agents/`) | `model: pro` | `model: inherit` |
| OpenCode | `~/.config/opencode/skills` | `~/.config/opencode/agents` (from `.opencode/agents/`) | inherited from `~/.config/opencode/opencode.json` | inherited from `~/.config/opencode/opencode.json` |

Install everything with the two installers (see [README.md](../README.md)):

```sh
./scripts/install-skills.sh
./scripts/install-agents.sh
```

Both installers only target an optional harness when its configuration
directory already exists (`~/.claude`, `~/.pi`, `~/.gemini`,
`~/.config/opencode`), or when the corresponding `--antigravity-*` /
`--opencode-*` / `--pi-*` flag is passed explicitly. Run with `--help` for the
full flag list, including source and install directory overrides.

Project-level alternatives: Antigravity also discovers skills and agents in
`.agents/{skills,agents}` within the repository, and OpenCode discovers skills
in `.agents/skills` and agents in `.opencode/agents`. This repository ships
`.agents/skills` as a symlink to `skills/` so project-level discovery works
without duplication.

## How /implement delegates per harness

`/implement` never plans or codes inline. It hands work between `planner` and
`implementer` subagents with clean context, passing absolute artifact paths
(task-brief, implementation-plan, etc.) in the delegation prompt. The
delegation mechanism per harness:

| Harness | Delegation mechanism | Context isolation settings | Artifact passing |
| :--- | :--- | :--- | :--- |
| Claude Code | Delegate subagent | Fresh subagent session | Artifact paths in prompt |
| Codex | Delegate subagent | `fork_turns="none"` | Artifact paths in prompt |
| Antigravity CLI | `invoke_subagent` | `TypeName: "planner"` / `"implementer"`, `Workspace: "inherit"` | Absolute artifact paths in `Prompt` |
| OpenCode | `task` tool | `subagent_type: "planner"` / `"implementer"`; omit `task_id` for a clean-context child session | Artifact paths in `prompt` |

Agent definition schemas per harness:

* **Claude Code** (`agents/*.md`): frontmatter with `type: agent`, `tools`,
  `model`, `permissionMode`, optional `fallbackModels`.
* **Codex** (`.codex/agents/*.toml`): TOML with `model`,
  `model_reasoning_effort`, `sandbox_mode`, `developer_instructions`. The
  planner runs `sandbox_mode = "read-only"`; the implementer edits files.
* **Pi** (`.pi/agent/agents/*.{md,toml}`): frontmatter with lowercase `tools`,
  `thinking`, `permissionMode`, `allowed_subagents`.
* **Antigravity CLI** (`.antigravity/agents/*.md`): YAML frontmatter with
  `subagent: true`, `model: pro|flash|inherit`, an explicit `tools` list.
  The planner has read-only tools; the implementer adds file-editing tools.
* **OpenCode** (`.opencode/agents/*.md`): YAML frontmatter with
  `mode: subagent` and a `permission` map (`edit`/`read`/`glob`/`grep`/`bash`).
  No `model` field: agents inherit the active model configured in
  `~/.config/opencode/opencode.json`. The planner sets `edit: deny`; the
  implementer sets `edit: allow`.

## Model selection philosophy

* **Claude Code** pins per-agent models: Opus plans, Sonnet implements.
  With `opusplan` and `defaultMode: plan` (see `.claude/settings.local.json`),
  moving from plan to implementation requires explicit approval.
* **Codex** pins per-agent models with reasoning effort: high for planning,
  medium for implementation.
* **Antigravity CLI** uses `model: pro` for the planner and `model: inherit`
  for the implementer, so implementation follows your active model.
* **OpenCode** inherits your configured model and provider for both agents,
  keeping cost control in `~/.config/opencode/opencode.json`.

## Design decisions

These decisions came out of the multi-harness support work; details live in
the linked issues.

* **Additive multi-harness** ([#4](https://github.com/cachemoney/ai-sdlc/issues/4)):
  existing Claude, Codex, and Pi directories and installer support are
  retained; Antigravity and OpenCode are added alongside them. No harness
  directory was consolidated or removed, so each harness's schema stays native
  rather than generated from a shared source.
* **Inherit / dynamic models** ([#5](https://github.com/cachemoney/ai-sdlc/issues/5)):
  OpenCode agent definitions omit `model` so both agents follow the user's
  configured provider; Antigravity pins the planner to `model: pro` and lets
  the implementer inherit. Cost control stays with the user's harness
  configuration instead of being hard-pinned in agent definitions.
* **Platform section matrix in /implement** ([#6](https://github.com/cachemoney/ai-sdlc/issues/6)):
  `/implement` documents one delegation row per harness, standardizes
  artifact paths passed between agents, and keeps OpenCode agents in
  `.opencode/agents/` (per-harness schema files rather than generated ones).

## Verification

After installing, verify harness integration:

```sh
# OpenCode: confirm the agents are discovered
opencode agent list

# Antigravity: confirm skills and agents resolve
ls ~/.gemini/config/skills ~/.gemini/config/agents

# Repository tests (all harness installers + interface contracts)
./test/install-skills.sh
./test/install-agents.sh
./test/install-standards.sh
./test/repository-interface.sh
```