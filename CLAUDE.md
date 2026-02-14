# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A configuration repository defining AI agents, skills, and hooks for Claude Code (`.claude/`) and Cursor IDE (`.cursor/`). These two directories mirror each other — changes should typically be applied to both.

## Structure

```
.claude/
├── agents/           # Specialized agent definitions by domain
│   ├── code-quality/ # Reviewer, test analyzer, silent-failure-hunter, type-design-analyzer
│   ├── feature-development/ # code-architect, code-explorer
│   ├── general/      # planner, system-architect, api-designer, devops, docs
│   ├── infrastructure/ # docker, kubernetes, terraform
│   ├── python/       # debugger, refactor, fastapi, django, security, test-writer, reviewer
│   ├── c/            # architect, network-specialist, reviewer
│   ├── go/           # architect, cli-builder, reviewer
│   ├── react/        # architect, hooks-specialist, usability-specialist, reviewer
│   └── sql/          # query-optimizer, schema-designer, reviewer
├── hooks/            # PreToolUse/PostToolUse shell scripts
├── scripts/          # Supporting scripts for hooks
├── skills/           # User-invocable and auto-loaded workflows
│   ├── review-pr/    # Orchestrated PR review
│   ├── feature-dev/  # 7-phase feature development workflow
│   ├── code-review/  # Code review skill
│   ├── frontend-design/
│   ├── ralph-wiggum/ # Iterative refinement loop
│   └── python/       # Domain skills: asyncio, typing, logging, errors, database, docs, deps
└── settings.json     # Hooks registration and plugin configuration
```

## Agent File Format

Agent files use YAML frontmatter followed by Markdown instructions:

```yaml
---
name: agent-name
description: "Trigger description for when to use this agent"
tools: Read, Edit, Write, Bash, Grep, Glob
model: sonnet          # sonnet | opus | haiku
color: purple          # terminal display color
skills:
  - skill-name         # auto-loaded skills from .claude/skills/
---
```

## Skill File Format

```yaml
---
name: skill-name
description: What the skill does
user-invocable: true   # shows up in /skills list
argument-hint: "[optional args]"
allowed-tools: [Read, Bash, ...]
---
```

## Hooks

Defined in `settings.json` under `hooks`:
- **PreToolUse** (`pre-bash-dangerous.sh`) — blocks destructive bash commands before execution
- **PostToolUse** (`post-write-python.sh`, `post-write-pytest.sh`) — auto-lints and runs pytest after Python file writes
- **Stop** / **SubagentStop** — manages ralph-loop continuation state

When modifying hooks, update the corresponding script in `.claude/hooks/` and the matcher in `settings.json`.

## MCP Servers (configured in .mcp.json)

- `context7` — package documentation lookup
- `postgres` — database access
- `docker` — Docker API
- `github` — GitHub PRs/issues
- `playwright` — browser automation
- `atlassian` — Jira/Confluence

## Key Conventions

**FastAPI agents/skills:** Use `from http import HTTPStatus`; reference `HTTPStatus.OK`, `HTTPStatus.CREATED`, etc. — never integer literals or `fastapi.status.HTTP_*`.

**Agent descriptions matter:** The `description` field in agent frontmatter is what the orchestrator uses to decide when to invoke the agent. Write it as a trigger condition, not a title.

**Mirror changes:** Any agent or skill added/modified in `.claude/` should have a corresponding update in `.cursor/` and vice versa.

**Model selection:** Use `haiku` for quick lookups, `sonnet` for general coding tasks, `opus` for complex architecture/planning.
