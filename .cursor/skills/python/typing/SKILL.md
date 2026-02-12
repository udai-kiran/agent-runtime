---
name: typing
description: Guidelines for Python type annotations. Auto-loaded when writing or reviewing type hints, protocols, generics, or when using mypy/pyright. Covers Python 3.10+ syntax, Protocols, TypeVar, and common patterns.
user-invocable: false
---

## Syntax (Python 3.10+)

Use built-in types directly — no `typing` imports for basic hints:

```python
# wrong (pre-3.10)
from typing import Optional, List, Dict, Tuple, Union
def f(x: Optional[str]) -> List[Dict[str, int]]: ...

# right (3.10+)
def f(x: str | None) -> list[dict[str, int]]: ...
```

## Protocols over ABCs for duck typing

Use `Protocol` when you care about interface, not inheritance:

```python
from typing import Protocol, runtime_checkable

@runtime_checkable  # enables isinstance() checks
class Closeable(Protocol):
    async def close(self) -> None: ...

class Readable(Protocol):
    async def read(self, n: int = -1) -> bytes: ...

# function accepts anything with .read(), no base class required
async def consume(source: Readable) -> bytes:
    return await source.read()
```

## TypeVar and generics

```python
from typing import TypeVar, Generic
T = TypeVar("T")

class Repository(Generic[T]):
    async def get(self, id: str) -> T | None: ...
    async def save(self, entity: T) -> None: ...

# Python 3.12+ syntax (preferred when targeting 3.12+):
class Repository[T]:
    async def get(self, id: str) -> T | None: ...
```

## TypedDict for structured dicts

Prefer `dataclass` for internal data. Use `TypedDict` only at system boundaries (JSON payloads, config files):

```python
from typing import TypedDict, NotRequired

class UserPayload(TypedDict):
    id: str
    email: str
    role: NotRequired[str]  # optional key
```

## Narrowing and guards

```python
from typing import TypeGuard

def is_str_list(val: list[object]) -> TypeGuard[list[str]]:
    return all(isinstance(x, str) for x in val)

# assert_never for exhaustive matching
from typing import assert_never, Literal

Status = Literal["ok", "error", "pending"]

def handle(status: Status) -> str:
    match status:
        case "ok": return "success"
        case "error": return "failed"
        case "pending": return "waiting"
        case _ as unreachable:
            assert_never(unreachable)  # type error if Status gains a new value
```

## Annotating async code

```python
from collections.abc import AsyncIterator, AsyncGenerator, Coroutine

async def stream_lines(path: str) -> AsyncIterator[str]:
    async with aiofiles.open(path) as f:
        async for line in f:
            yield line

# Callable that returns a coroutine:
from collections.abc import Callable, Awaitable
Handler = Callable[[Request], Awaitable[Response]]
```

## Common patterns

```python
from typing import overload, Literal

# overload for different return types based on input type
@overload
def parse(raw: str) -> dict[str, object]: ...
@overload
def parse(raw: bytes) -> dict[str, object]: ...
def parse(raw: str | bytes) -> dict[str, object]:
    ...

# ParamSpec for decorator type safety (preserves wrapped function signature)
from typing import ParamSpec, Concatenate
P = ParamSpec("P")

def with_logging(fn: Callable[P, Awaitable[T]]) -> Callable[P, Awaitable[T]]:
    async def wrapper(*args: P.args, **kwargs: P.kwargs) -> T:
        logger.info(f"calling {fn.__name__}")
        return await fn(*args, **kwargs)
    return wrapper
```
