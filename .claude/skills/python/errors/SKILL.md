---
name: errors
description: Exception hierarchy patterns for Python. Auto-loaded when defining custom exceptions, writing error handling, or using raise/try/except. Covers exception chaining, structured error context, and when to create custom types.
user-invocable: false
---

## When to create a custom exception

Create a custom exception when callers need to **catch it specifically**. Do not create one just to rename a built-in.

```python
# pointless — callers would just catch ValueError anyway
class InvalidAgeError(ValueError): pass

# justified — callers need to distinguish this from other ValueErrors
class UserNotFoundError(LookupError):
    def __init__(self, user_id: str) -> None:
        self.user_id = user_id
        super().__init__(f"User {user_id!r} not found")
```

## Exception hierarchy

Define a base exception per package/module boundary. Callers can catch the base or a specific subclass:

```python
# errors.py — one file per package
class AppError(Exception):
    """Base for all application errors."""

class NotFoundError(AppError):
    def __init__(self, resource: str, id: str) -> None:
        self.resource = resource
        self.id = id
        super().__init__(f"{resource} {id!r} not found")

class ValidationError(AppError):
    def __init__(self, field: str, message: str) -> None:
        self.field = field
        self.message = message
        super().__init__(f"{field}: {message}")

class ExternalServiceError(AppError):
    def __init__(self, service: str, cause: Exception) -> None:
        self.service = service
        super().__init__(f"{service} failed: {cause}")
```

## Exception chaining — always use `raise X from Y`

Preserve the original cause. Never swallow it:

```python
# wrong — original traceback lost
try:
    result = await external_api.fetch()
except Exception as e:
    raise ServiceError("fetch failed")

# right — original cause attached and visible in traceback
try:
    result = await external_api.fetch()
except httpx.HTTPError as e:
    raise ServiceError("fetch failed") from e

# database examples (catch driver-specific exceptions):
# asyncpg: except asyncpg.PostgresError as e
# SQLAlchemy: except sqlalchemy.exc.SQLAlchemyError as e
# aiosqlite: except aiosqlite.Error as e

# explicit suppression when cause is intentionally hidden
try:
    secret = vault.get(key)
except VaultError as e:
    raise ConfigError(f"missing secret: {key}") from None
```

## Structured error context

Attach structured data to exceptions so error handlers and loggers can use it without parsing the message string:

```python
class RateLimitError(AppError):
    def __init__(self, service: str, retry_after: float) -> None:
        self.service = service
        self.retry_after = retry_after
        super().__init__(f"{service} rate limited, retry after {retry_after}s")

# caller can branch on the data:
except RateLimitError as e:
    await asyncio.sleep(e.retry_after)
    return await retry()
```

## Catching exceptions

Catch the most specific type possible. Never use bare `except:` and never suppress without logging:

```python
# wrong
try:
    data = parse(raw)
except Exception:
    return None  # swallows bugs silently

# right
try:
    data = parse(raw)
except ValidationError as e:
    logger.warning("parse failed", field=e.field, error=e.message)
    raise
except ValueError as e:
    raise ValidationError("body", str(e)) from e
```

## Async error handling

In `asyncio.gather`, use `return_exceptions=True` when per-item failures are expected:

```python
results = await asyncio.gather(*tasks, return_exceptions=True)
for result in results:
    if isinstance(result, AppError):
        logger.error("task failed", error=str(result))
    elif isinstance(result, Exception):
        raise result  # unexpected — re-raise
```
