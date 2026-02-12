---
name: docs
description: Fetch up-to-date Python library documentation via context7. Use when you need the current API for a Python package (asyncio, pydantic, fastapi, sqlalchemy, aiohttp, etc.) before writing or reviewing code.
user-invocable: true
allowed-tools: mcp__context7__resolve-library-id, mcp__context7__get-library-docs
argument-hint: [library-name] [optional: topic]
---

Fetch documentation for the Python library: $ARGUMENTS

Steps:
1. Use `mcp__context7__resolve-library-id` to resolve "$0" to a context7 library ID
2. Use `mcp__context7__get-library-docs` with that ID to fetch the docs
   - If a topic was given ("$1"), pass it as the `topic` parameter to scope the results
3. Summarise the relevant API: function signatures, key parameters, return types, and a minimal usage example
4. Flag any breaking changes or deprecations visible in the docs

If the library is not found in context7, fall back to the official docs URL and note that the results may be outdated.
