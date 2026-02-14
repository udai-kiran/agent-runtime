---
name: project-init
description: Bootstrap a new project from a PRD or description. Runs planner → system-architect → domain architects in parallel. Use when starting a brand-new project (not adding a feature to an existing codebase).
user-invocable: true
argument-hint: "[PRD or project description]"
allowed-tools: [Task, TodoWrite, Read, Write, Glob]
---

# Project Init

You are bootstrapping a brand-new project. There is no existing codebase to explore. Follow these phases in order, pausing for user input at each gate.

## Input

Project description or PRD: $ARGUMENTS

If $ARGUMENTS is empty, ask the user:
- What are you building? (one paragraph description)
- Who are the users and what problem does it solve?
- What is the tech stack? (or should you recommend one?)
- Any constraints? (timeline, team size, existing infrastructure)

---

## Phase 1: Planning

**Goal**: Decompose the project into epics, stories, and tasks.

**Actions**:
1. Create a todo list with all phases
2. Launch the `planner` agent with the full PRD/description. Ask it to produce:
   - Epics and user stories with acceptance criteria
   - Task breakdown with dependencies and sequencing
   - Parallel work streams (what can be built concurrently)
   - Risk assessment and unknowns
3. Present the plan summary to the user
4. **Ask the user to confirm the scope before proceeding**

---

## Phase 2: System Architecture

**Goal**: Design the overall system — service boundaries, API contracts, data flow, infrastructure.

**Actions**:
1. Launch the `system-architect` agent with the confirmed plan. Ask it to produce:
   - Service/component boundaries
   - API contracts between services (REST, gRPC, message queues)
   - Data flow diagrams
   - Technology stack recommendation with rationale
   - Infrastructure topology (containers, databases, caches)
2. Present the architecture to the user
3. **Ask the user to confirm the architecture before proceeding**

---

## Phase 3: Domain Architecture

**Goal**: Get deep, per-layer implementation blueprints from domain specialists.

**Detect the tech stack** from the confirmed system architecture, then launch the matching agents **in parallel**:

| If stack includes | Launch agent |
|---|---|
| Go (API, CLI, gateway) | `cli-builder` or `go/architect` |
| Python (FastAPI) | `fastapi` |
| Python (Django) | `django` |
| React / TypeScript | `react/architect` |
| PostgreSQL / database schema | `schema-designer` |
| REST API design | `api-designer` |
| Docker / containers | `docker` |
| Kubernetes | `kubernetes` |
| Terraform / IaC | `terraform` |

For each agent launched, pass:
- The full system architecture from Phase 2
- The specific layer/component that agent owns
- Key integration points with other layers

**After agents complete**:
1. Read all key files each agent identified
2. Synthesize into a unified implementation blueprint showing how the layers connect
3. Highlight integration points that require cross-layer coordination

---

## Phase 4: Project Scaffold Plan

**Goal**: Give the user a concrete starting point.

**Actions**:
1. Produce a directory structure for the project
2. List the first 5 tasks to implement (the critical path foundation)
3. Identify any blockers or decisions still needed
4. Ask the user: **"Ready to start implementing? Which layer do you want to tackle first?"**

---

## Phase 5: Handoff

**Goal**: Leave the user ready to code.

**Actions**:
1. Mark all todos complete
2. Summarize:
   - What was designed (not built — this skill plans, it does not write code)
   - Key architecture decisions made
   - Suggested implementation order
   - Which skills/agents to use per layer going forward:
     - Feature work → `/feature-dev`
     - Go layer → explicitly ask for `go/architect` or `cli-builder`
     - Python layer → explicitly ask for `fastapi` or `django` agent
     - React layer → explicitly ask for `react/architect` or `hooks-specialist`
     - Infrastructure → explicitly ask for `docker`, `kubernetes`, or `terraform`
     - Code review → `/code-review` or explicitly ask for domain `reviewer` agents
