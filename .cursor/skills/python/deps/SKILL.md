---
name: deps
description: Python dependency management conventions. Auto-loaded when editing pyproject.toml, adding packages, setting up a new project, or discussing pinning strategy. Covers dependency groups, version constraints, and uv/pip-tools workflows.
user-invocable: false
---

## New project setup

Use the project-standard toolchain and Python version. For new services without constraints, prefer `uv` and target Python 3.14. Before pinning any package version, use context7 (`/python-docs <package>`) to fetch the current release and set a sensible lower bound.

```bash
uv init my-service --python 3.14
cd my-service
uv add aiohttp          # uv resolves and locks the latest compatible version
uv add --dev ruff pyright pytest pytest-asyncio bandit pip-audit
```

## pyproject.toml structure

```toml
[project]
name = "my-service"
version = "0.1.0"
requires-python = ">=3.14"

# Runtime dependencies — keep minimal, use loose lower bounds
dependencies = [
    "aiohttp>=3.9",
    "structlog>=24.0",
    "pydantic>=2.0",
]

[project.optional-dependencies]
# Dev tools — never installed in production
dev = [
    "ruff>=0.4",
    "pyright>=1.1",
    "pytest>=8.0",
    "pytest-asyncio>=0.23",
    "bandit>=1.7",
    "pip-audit>=2.7",
]
# Test-only runtime deps (e.g. test doubles, factories)
test = [
    "pytest>=8.0",
    "pytest-asyncio>=0.23",
    "factory-boy>=3.3",
    "aioresponses>=0.7",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

## Version constraint strategy

| Dependency type | Constraint | Rationale |
|---|---|---|
| Runtime (library) | `>=X.Y` | Consumers need flexibility |
| Runtime (application) | `>=X.Y,<X+1` | Prevent surprise major bumps |
| Dev tools | `>=X.Y` | Loose is fine; pin in lockfile |
| Security-sensitive | `>=X.Y.Z` | Pin to patched version floor |

Avoid `==` in `pyproject.toml` for anything other than lockfiles — it breaks dependency resolution for downstream consumers.

## Lockfiles

Use a lockfile for applications (not libraries). Lockfiles guarantee reproducible installs across environments.

**With uv (recommended):**
```bash
uv sync                        # install from lockfile (uv.lock)
uv add aiohttp                 # add and update lockfile
uv add --dev ruff              # add to dev group
uv lock --upgrade-package ruff # upgrade one package
uv lock --upgrade              # upgrade all
```

**With pip-tools:**
```bash
pip-compile pyproject.toml -o requirements.txt              # runtime
pip-compile pyproject.toml --extra dev -o requirements-dev.txt
pip-sync requirements-dev.txt  # install exactly what's in lockfile
```

Commit `uv.lock` or `requirements*.txt` to version control.

## Dependency groups in practice

```bash
# Install everything for local development
uv sync --extra dev --extra test

# CI test run — test deps only, no dev tools
uv sync --extra test

# Production container — runtime only, no extras
uv sync --no-dev
```

## Keeping dependencies healthy

```bash
# Check for known vulnerabilities
pip-audit

# Find outdated packages
uv tree --outdated

# Check for unused imports (not unused packages — use pip-autoremove for that)
ruff check --select F401
```

## What not to do

- Do not pin transitive dependencies in `pyproject.toml` — that's what lockfiles are for
- Do not mix `requirements.txt` and `pyproject.toml` as sources of truth — pick one
- Do not install dev dependencies in production containers
- Do not use `*` or no constraint for packages with frequent breaking changes (`pydantic`, `sqlalchemy`, `fastapi`)
