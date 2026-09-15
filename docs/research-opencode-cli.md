# OpenCode CLI: Skills Discovery, Agent Schemas, and Subagent Delegation

> Research ticket: [cachemoney/ai-sdlc#3](https://github.com/cachemoney/ai-sdlc/issues/3)  
> Parent map: [cachemoney/ai-sdlc#1](https://github.com/cachemoney/ai-sdlc/issues/1)  
> Primary sources:
> - Local binary `/opt/homebrew/bin/opencode` (version 1.18.31, arm64 Darwin)
> - Built-in documentation `/builtin/customize-opencode.md`
> - Effect-TS runtime modules `@opencode/SkillDiscovery`, `@opencode/Skill`, `@opencode/Agent`, `ConfigAgentPlugin`, `ConfigPaths`, `TaskTool`
> - User configuration `~/.config/opencode/opencode.json`

---

## Executive Summary

OpenCode CLI (v1.18.31) has robust native support for skills, custom agents, and subagent delegation:
1. **Skills Discovery**: OpenCode automatically discovers skills in both its native config paths (`~/.config/opencode/skills/`, `.opencode/skills/`) AND external paths (`~/.agents/skills/`, `~/.claude/skills/`, and project-level `.agents/skills/`, `.claude/skills/`). No extra configuration is needed if skills are placed in `.agents/skills/` or `~/.config/opencode/skills/`.
2. **Agent Discovery**: OpenCode loads agents strictly from `.opencode/agent(s)/**/*.md` (project) and `~/.config/opencode/agent(s)/**/*.md` (global). It does **not** scan `.agents/` or `.claude/` for agents.
3. **Agent Schema**: OpenCode uses Markdown files with YAML frontmatter. Key fields are `description`, `mode: subagent` (or `primary`), and `permission` (specifying tool permissions such as `edit: deny`, `bash: allow`). The Markdown body becomes the system prompt.
4. **Subagent Delegation**: The LLM delegates via the built-in `task` tool (`subagent_type`, `description`, `prompt`, optional `task_id`). When `task_id` is omitted, OpenCode spawns a fresh child session with an empty conversation context, matching the requirements of orchestration workflows like `/implement`.
5. **Installer Updates**:
   - `scripts/install-skills.sh`: Link skills to `~/.config/opencode/skills/` when `~/.config/opencode` exists, and support `--opencode-skills-dir`.
   - `scripts/install-agents.sh`: Add OpenCode agent definitions (`.opencode/agents/planner.md`, `.opencode/agents/implementer.md`) and install to `~/.config/opencode/agents/`.

---

## 1. Skills Discovery

### Standard Paths
OpenCode resolves skills in multiple tiers via `@opencode/SkillDiscovery`:

| Tier | Path Pattern | Condition / Scope |
|---|---|---|
| **Global Native** | `~/.config/opencode/{skill,skills}/**/SKILL.md` | Built-in native path |
| **Project Native** | `<worktree>/.opencode/{skill,skills}/**/SKILL.md` | Scans up from cwd to worktree root |
| **Global External** | `~/.agents/skills/**/SKILL.md`<br>`~/.claude/skills/**/SKILL.md` | Auto-loaded unless disabled via env |
| **Project External** | `<worktree>/.agents/skills/**/SKILL.md`<br>`<worktree>/.claude/skills/**/SKILL.md` | Auto-loaded unless disabled via env |
| **Config Explicit** | `skills.paths` in `opencode.json` | Any arbitrary directory array (`**/SKILL.md`) |
| **Remote Catalogs** | `skills.urls` in `opencode.json` | Remote `index.json` endpoints |

### External Skills Auto-Loading
OpenCode's `Skill.discovery` routine inspects `Z = [".claude", ".agents"]` unless `OPENCODE_DISABLE_EXTERNAL_SKILLS=1` or `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1` is set:
```typescript
// Extracted from binary @opencode/Skill
if (!disableExternalSkills) {
  if (!disableClaudeCodeSkills) Z.push(".claude");
  Z.push(".agents");
  for (let target of Z) {
    let globalDir = path.join(home, target);
    if (yield* isDir(globalDir)) yield* scan(globalDir, "skills/**/SKILL.md");
  }
  let projectDirs = yield* walkUp({ targets: Z, start: cwd, stop: worktree });
  for (let projDir of projectDirs) yield* scan(projDir, "skills/**/SKILL.md");
}
```

**Key Takeaways for Skills**:
- OpenCode **does** automatically check `.agents/skills/` and `.claude/skills/` at both project and user level.
- `skills-sdlc` currently installs into `~/.agent/skills` (singular `.agent`, used by Codex) and `~/.claude/skills`.
- Installing or linking into `~/.config/opencode/skills/` (or `~/.agents/skills/`) provides full native support.

---

## 2. Agent Discovery

### Standard Paths
Unlike skills, OpenCode's agent scanner (`ConfigAgentPlugin` / `id: "config-agent"`) only checks native OpenCode configuration directories returned by `ConfigPaths.directories`:

| Scope | Path Pattern |
|---|---|
| **Global** | `~/.config/opencode/agent/**/*.md`<br>`~/.config/opencode/agents/**/*.md` |
| **Project** | `.opencode/agent/**/*.md`<br>`.opencode/agents/**/*.md` |
| **Alternative Mode Alias** | `{mode,modes}/*.md` (treated as `mode: primary`) |
| **Inline Config** | `"agent": { "<name>": { ... } }` in `opencode.json` |

```typescript
// Extracted from binary ConfigAgentPlugin
var Qr = [
  { pattern: "{agent,agents}/**/*.md", primary: false },
  { pattern: "{mode,modes}/*.md", primary: true }
];
// Scanned in ~/.config/opencode and <worktree>/.opencode
```

**Crucial Finding**:
OpenCode does **NOT** automatically scan `.agents/` or `.claude/agents/` for agent definitions. OpenCode agents must be located in `.opencode/agents/` (or `.opencode/agent/`) or `~/.config/opencode/agents/`.

---

## 3. Agent Frontmatter Schema

OpenCode parses agent Markdown files using YAML frontmatter. The file basename (or relative path without extension) determines the agent's identifier.

### Schema Specification
Top-level YAML fields (`ConfigV2.Agent`):
- `description` *(string, optional)*: Explains what the agent does and when to invoke it.
- `mode` *(string, optional)*: One of:
  - `"subagent"`: Designed to be invoked via the `task` tool or `@agent` mention.
  - `"primary"`: Top-level agent that user interacts with directly (like `build`, `plan`).
  - `"all"`: Usable both as primary and subagent.
- `model` *(string, optional)*: Model specifier in `"provider/model-id"` format (e.g. `"anthropic/claude-sonnet-4-6"`, `"ollama-cloud/glm-5.2"`).
- `variant` *(string, optional)*: Model variant (e.g. reasoning effort).
- `steps` / `maxSteps` *(integer, optional)*: Max agentic turns before forcing text completion.
- `hidden` *(boolean, optional)*: Hide subagent from the TUI `@` menu.
- `color` *(string, optional)*: Theme color (`"primary"`, `"accent"`, etc.) or hex code (`"#FF5733"`).
- `disabled` / `disable` *(boolean, optional)*: Disables the agent.
- `permission` *(object, optional)*: Fine-grained permission rules. Available tools/permissions:
  `bash`, `read`, `edit`, `glob`, `grep`, `webfetch`, `task`, `todowrite`, `websearch`, `lsp`, `doom_loop`, `skill`, `external_directory`.
  - Actions: `"allow"`, `"ask"`, `"deny"`.
  - Can be flat (`edit: deny`) or pattern-based (`bash: { "git *": "allow", "*": "ask" }`).
- Prompt body: Everything after the closing `---` is treated as the system prompt.

### Recommended Agent Definitions for `skills-sdlc`

#### `planner.md`
```markdown
---
description: Produces an implementation plan to handoff to an implementer. Also usable as an architect.
mode: subagent
permission:
  edit: deny
  read: allow
  glob: allow
  grep: allow
  bash: allow
---

Produce a plan only; do not edit files unless specifically instructed to.

When delegated with artifacts, begin with them, then inspect relevant repository files as needed.

If access to write a plan file is available, the plan should be returned as a file name with the plan written to a file.
Otherwise return it as a direct response.
```

#### `implementer.md`
```markdown
---
description: "Implementer. Implement code, preferably from a plan."
mode: subagent
permission:
  edit: allow
  read: allow
  glob: allow
  grep: allow
  bash: allow
---

Read repo documentation for conventions before editing code.
This might be CODING_STANDARDS.md or README.md or AGENTS.md, etc.

Stay strictly within the scope of work given.

Ask for clarity if the work given:
* is ambiguous or seems wrong
* needs an expansion in scope
```

---

## 4. Subagent Delegation & Orchestration

### The `task` Tool
Subagent delegation in OpenCode is mediated through the built-in `task` tool:
- **Parameters**:
  - `subagent_type`: String (required). Name of the subagent (`"planner"`, `"implementer"`, etc.).
  - `description`: String (required). 3-5 word summary of the subtask.
  - `prompt`: String (required). Complete instructions and context for the subagent.
  - `task_id`: String (optional). ID of an existing subagent session to resume.

### Execution Semantics & Context Isolation
1. **Fresh Context**: When `task_id` is omitted, OpenCode spawns a brand new child session (`sessionId: O.id`, `parentID: parent.id`). The child does **not** inherit the parent's conversation turns. This directly satisfies `/implement`'s requirement:
   > *"Start every planner, reviewer, and implementer delegation without inherited conversation history."*
2. **Context Passing**: The orchestrator must pass all relevant context, file paths (`task-brief.md`, `implementation-plan.md`), and constraints in the `prompt` string.
3. **Execution & Return**: The subagent executes tools synchronously. Upon completion, OpenCode extracts the subagent's final assistant text (`parts.findLast(p => p.type === 'text').text`) and returns it to the parent orchestrator as the tool result.
4. **Subagent Nesting & Limits**:
   - OpenCode enforces `subagent_depth` (default: `1`).
   - Child subagents default to `task: deny` unless explicitly granted `task: allow` in permissions.
   - If an agent needs to delegate recursively (e.g. `/implement` running inside a subagent), `subagent_depth: 2` must be configured in `opencode.json`, and `task: allow` must be added to the agent's permissions.

---

## 5. Required Installer Modifications in `skills-sdlc`

### 1. `scripts/install-skills.sh`
- **Current State**:
  - `INSTALL_DIR="${HOME}/.agent/skills"`
  - Optional Claude install: `${HOME}/.claude/skills`
- **Changes Needed**:
  - Add variable `OPENCODE_DIR="${HOME}/.config/opencode"` and `OPENCODE_SKILLS_DIR="$OPENCODE_DIR/skills"`.
  - Add flag `--opencode-skills-dir DIR` to override or force installation.
  - When `~/.config/opencode` exists or `--opencode-skills-dir` is provided, call `link_all_skills "$OPENCODE_SKILLS_DIR"`.
  - Also consider linking `${HOME}/.agents/skills` (plural) which OpenCode auto-discovers natively.
  - Update `usage()` and `test/install-skills.sh`.

### 2. `scripts/install-agents.sh`
- **Current State**:
  - Claude: `agents/*.md` -> `~/.claude/agents/`
  - Codex: `.codex/agents/*.toml` -> `~/.codex/agents/`
  - Pi: `.pi/agent/agents/*.{md,toml}` -> `~/.pi/agent/agents/` (gated on `~/.pi`)
- **Changes Needed**:
  - Add OpenCode agent definitions to the repository under `.opencode/agents/`:
    - `.opencode/agents/planner.md`
    - `.opencode/agents/implementer.md`
  - Add variables to `scripts/install-agents.sh`:
    - `OPENCODE_SOURCE_DIR="$REPOSITORY_ROOT/.opencode/agents"`
    - `OPENCODE_INSTALL_DIR="${HOME}/.config/opencode/agents"`
    - `OPENCODE_HOME="${HOME}/.config/opencode"`
    - `OPENCODE_INSTALL_DIR_EXPLICIT=false`
  - Add flags:
    - `--opencode-source-dir DIR`
    - `--opencode-install-dir DIR`
  - Gate OpenCode agent installation on `[ -d "$OPENCODE_HOME" ]` or `"$OPENCODE_INSTALL_DIR_EXPLICIT"`.
  - Add OpenCode agent discovery (`discover_agents "$OPENCODE_SOURCE_DIR" md OpenCode opencode_agents`).
  - Add target preflight, directory creation, symlinking, and backup support.
  - Update `test/install-agents.sh` to include contract tests for OpenCode agent installation, gating, dry-run, and backup behaviors.

---

## Summary Matrix

| Capability | OpenCode Support | Location / Format | Notes |
|---|---|---|---|
| Global Skills | Native & Auto | `~/.config/opencode/skills/`<br>`~/.agents/skills/`<br>`~/.claude/skills/` | OpenCode scans all three paths by default. |
| Project Skills | Native & Auto | `.opencode/skills/`<br>`.agents/skills/`<br>`.claude/skills/` | `.agents/skills/` works without any config. |
| Global Agents | Native | `~/.config/opencode/agents/<name>.md` | Does **not** auto-load from `.agents/` or `.claude/`. |
| Project Agents | Native | `.opencode/agents/<name>.md` | Must be inside `.opencode/agent(s)/`. |
| Agent Frontmatter | YAML in `.md` | `description`, `mode: subagent`, `permission: ...` | Markdown body becomes system prompt. |
| Subagent Delegation | Built-in | Tool `task` (`subagent_type`, `description`, `prompt`) | Spawns clean session without history unless `task_id` given. |
| Recursion Depth | Configurable | `subagent_depth` in `opencode.json` (default: 1) | Set to >= 2 if nested subagents needed. |
