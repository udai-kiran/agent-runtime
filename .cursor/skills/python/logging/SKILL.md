---
name: logging
description: Structured logging patterns for Python backends. Auto-loaded when adding logging, configuring log output, or working with trace IDs. Covers structlog, stdlib logging, and ContextVar-based trace propagation.
user-invocable: false
---

## Use structured logging

Emit key-value pairs, not formatted strings. Log aggregators (Datadog, Loki, CloudWatch) can filter and alert on fields — they cannot parse arbitrary strings.

Prefer `structlog` for new code. Use stdlib `logging` with a JSON formatter when you can't add dependencies.

## structlog setup

```python
# logging_config.py
import structlog
import logging

def configure_logging(level: str = "INFO") -> None:
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,   # injects ContextVar fields
            structlog.stdlib.add_log_level,
            structlog.stdlib.add_logger_name,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.ExceptionRenderer(),
            structlog.processors.JSONRenderer(),        # swap for ConsoleRenderer in dev
        ],
        wrapper_class=structlog.make_filtering_bound_logger(
            logging.getLevelName(level)
        ),
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(),
    )
```

Usage:

```python
import structlog
logger = structlog.get_logger(__name__)

logger.info("user.created", user_id=user.id, email=user.email)
logger.warning("rate_limit.hit", service="stripe", retry_after=2.5)
logger.error("db.query_failed", table="orders", error=str(e), exc_info=True)
```

## Trace ID propagation with ContextVar

Bind request-scoped fields once at the request boundary. All downstream log calls in the same async task pick them up automatically via `merge_contextvars`:

```python
from contextvars import ContextVar
import structlog

trace_id: ContextVar[str] = ContextVar("trace_id", default="")

async def handle_request(request: Request) -> Response:
    tid = request.headers.get("X-Trace-ID", uuid4().hex)
    token = trace_id.set(tid)
    structlog.contextvars.bind_contextvars(trace_id=tid)
    try:
        return await process(request)
    finally:
        trace_id.reset(token)
        structlog.contextvars.clear_contextvars()
```

Every log line emitted during that request now includes `trace_id` with no extra arguments.

## stdlib logging with JSON (no structlog)

```python
import logging
import json

class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
        }
        if record.exc_info:
            payload["exc"] = self.formatException(record.exc_info)
        payload.update(record.__dict__.get("extra", {}))
        return json.dumps(payload)

handler = logging.StreamHandler()
handler.setFormatter(JsonFormatter())
logging.basicConfig(handlers=[handler], level=logging.INFO)
```

## What to log at each level

| Level | When |
|---|---|
| `DEBUG` | Internal state useful for diagnosing a specific bug; off in production |
| `INFO` | Normal significant events: request received, job started, user created |
| `WARNING` | Unexpected but recoverable: retrying after timeout, fallback used |
| `ERROR` | Operation failed, requires attention: unhandled exception, external call failed |
| `CRITICAL` | System cannot continue: DB unreachable at startup, config missing |

## What NOT to log

- Passwords, tokens, secrets, PII — scrub before logging
- High-cardinality fields as top-level keys (use a nested dict or omit)
- Successful health check pings — they flood logs with zero signal
