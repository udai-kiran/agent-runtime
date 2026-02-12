---
name: asyncio
description: Guidelines for writing async Python code. Auto-loaded when writing async functions, working with IO-bound operations, or using asyncio. Covers semaphores, contextvars, task management, and common pitfalls.
user-invocable: false
---

## Async defaults

All IO-bound operations use `async/await`. Never use `requests`, `time.sleep`, or other blocking calls inside `async def`.

```python
# wrong
async def fetch(url: str) -> dict:
    return requests.get(url).json()  # blocks the event loop

# right
async def fetch(url: str, session: aiohttp.ClientSession) -> dict:
    async with session.get(url) as resp:
        return await resp.json()
```

## Bounding concurrency with Semaphore

Unbounded concurrency exhausts connection pools and triggers rate limits. Always bound concurrent external calls.

```python
import asyncio
from collections.abc import Awaitable

_SEM = asyncio.Semaphore(10)  # module-level, shared across tasks

async def guarded_fetch(url: str, session: aiohttp.ClientSession) -> dict:
    async with _SEM:
        return await fetch(url, session)

# For one-off fan-out:
async def fetch_all(urls: list[str]) -> list[dict]:
    sem = asyncio.Semaphore(10)
    async def _one(url: str) -> dict:
        async with sem:
            return await fetch(url, session)
    async with aiohttp.ClientSession() as session:
        return await asyncio.gather(*(_one(u) for u in urls))
```

## Propagating request context with ContextVar

Use `contextvars.ContextVar` for request-scoped state (trace ID, auth token, tenant). Never use module-level globals or `threading.local` for per-request data — they are not task-safe.

```python
from contextvars import ContextVar

trace_id: ContextVar[str] = ContextVar("trace_id", default="")
current_user: ContextVar[str | None] = ContextVar("current_user", default=None)

async def handle_request(request: Request) -> Response:
    token = trace_id.set(request.headers.get("X-Trace-ID", uuid4().hex))
    try:
        return await process(request)
    finally:
        trace_id.reset(token)  # always reset; prevents context bleed between tasks
```

`asyncio.create_task` and `asyncio.gather` copy the current context automatically — `ContextVar` values set before spawning are visible in child tasks.

## Task lifecycle

```python
# Prefer asyncio.TaskGroup (Python 3.11+) over gather for structured concurrency
async def run_pipeline(items: list[Item]) -> list[Result]:
    results: list[Result] = []
    async with asyncio.TaskGroup() as tg:
        tasks = [tg.create_task(process(item)) for item in items]
    return [t.result() for t in tasks]
```

- Use `asyncio.TaskGroup` — exceptions propagate correctly and all tasks are cancelled on failure
- Use `asyncio.gather(..., return_exceptions=True)` only when you need to handle per-item failures
- Always `await` tasks; fire-and-forget creates untracked tasks that swallow exceptions

## CPU-bound work

`asyncio` is single-threaded. CPU-bound code blocks the event loop:

```python
import asyncio
from concurrent.futures import ProcessPoolExecutor

_pool = ProcessPoolExecutor()

async def compute(data: bytes) -> bytes:
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(_pool, cpu_heavy_function, data)
```

Use `ThreadPoolExecutor` only for sync-only third-party libraries that perform IO internally.

## Resource management

Use `async with` for anything that has a lifecycle:

```python
# session shared across requests — open once, close once
async with aiohttp.ClientSession() as session:
    results = await asyncio.gather(*(fetch(u, session) for u in urls))
```

Use `contextlib.asynccontextmanager` for custom async context managers:

```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def db_transaction(conn: Connection):
    async with conn.transaction():
        yield conn
```
