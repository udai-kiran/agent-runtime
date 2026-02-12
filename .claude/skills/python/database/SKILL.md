---
name: database
description: Async database patterns for Python backends. Auto-loaded when working with asyncpg, SQLAlchemy async, database connections, repositories, or transactions. Covers pool setup, session management, repository pattern, transaction handling, and N+1 avoidance.
user-invocable: false
---

## Choosing a driver

| Use case | Driver |
|---|---|
| Raw SQL, maximum performance, PostgreSQL only | `asyncpg` |
| ORM, complex queries, multiple DB support | `SQLAlchemy 2.0 async` + `asyncpg` |
| Lightweight ORM, simple models | `SQLAlchemy 2.0 async` + `aiosqlite` (SQLite) |

Never use synchronous drivers (`psycopg2`, `sqlite3`) in `async def` endpoints — they block the event loop.

---

## asyncpg

### Pool setup (app lifespan)

```python
import asyncpg
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.db_pool = await asyncpg.create_pool(
        dsn=settings.database_url,
        min_size=2,
        max_size=10,           # tune to: (CPUs * 2) + effective_spindle_count
        command_timeout=30,
        statement_cache_size=100,
    )
    yield
    await app.state.db_pool.close()
```

### Dependency injection

```python
from fastapi import Request
from collections.abc import AsyncGenerator
from typing import Annotated
from fastapi import Depends
import asyncpg

async def get_conn(request: Request) -> AsyncGenerator[asyncpg.Connection, None]:
    async with request.app.state.db_pool.acquire() as conn:
        yield conn

Conn = Annotated[asyncpg.Connection, Depends(get_conn)]
```

### Queries — always use parameterised placeholders ($1, $2, ...)

```python
# fetch multiple rows → list[Record]
rows = await conn.fetch("SELECT id, email FROM users WHERE active = $1", True)

# fetch single row → Record | None
row = await conn.fetchrow("SELECT * FROM users WHERE id = $1", user_id)

# fetch scalar value
count = await conn.fetchval("SELECT COUNT(*) FROM users WHERE active = $1", True)

# execute (INSERT / UPDATE / DELETE) → command tag string
await conn.execute(
    "INSERT INTO users(id, email, name) VALUES($1, $2, $3)",
    user_id, email, name,
)
```

Never interpolate user input into SQL strings. `asyncpg` does not support `%s` style — always use `$N`.

### Transactions

```python
async with conn.transaction():
    await conn.execute("INSERT INTO accounts(id) VALUES($1)", acct_id)
    await conn.execute("INSERT INTO ledger(account_id, amount) VALUES($1, $2)", acct_id, 0)
    # rolls back automatically if an exception is raised
```

For savepoints (nested transactions):

```python
async with conn.transaction():
    async with conn.transaction():   # creates a savepoint
        await conn.execute(...)
```

---

## SQLAlchemy 2.0 async

### Engine and session factory (app lifespan)

```python
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.db_engine = create_async_engine(
        settings.database_url,       # postgresql+asyncpg://...
        pool_size=10,
        max_overflow=5,
        pool_pre_ping=True,          # drop stale connections automatically
        echo=settings.debug,
    )
    app.state.db_session_factory = async_sessionmaker(
        app.state.db_engine,
        expire_on_commit=False,      # avoids lazy-load after commit in async context
        class_=AsyncSession,
    )
    yield
    await app.state.db_engine.dispose()
```

`expire_on_commit=False` is required in async context — accessing expired attributes triggers implicit IO which is not allowed after the session closes.

### Dependency injection

```python
from fastapi import Request
from collections.abc import AsyncGenerator
from typing import Annotated
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

async def get_session(request: Request) -> AsyncGenerator[AsyncSession, None]:
    async with request.app.state.db_session_factory() as session:
        yield session

Session = Annotated[AsyncSession, Depends(get_session)]
```

### Queries (SQLAlchemy 2.0 style — always use `select()`)

```python
from sqlalchemy import select, update, delete
from sqlalchemy.ext.asyncio import AsyncSession

# fetch many
result = await session.execute(select(User).where(User.active == True))
users: list[User] = result.scalars().all()

# fetch one or None
result = await session.execute(select(User).where(User.id == user_id))
user: User | None = result.scalar_one_or_none()

# insert
session.add(User(id=user_id, email=email, name=name))
await session.commit()

# bulk update
await session.execute(
    update(User).where(User.active == False).values(deleted_at=now())
)
await session.commit()
```

Never use the legacy `session.query(User)` — it does not work with async sessions.

### Transactions

The session is already transactional. Commit when the unit of work is complete; the dependency above will roll back automatically on exception:

```python
async def get_session(request: Request) -> AsyncGenerator[AsyncSession, None]:
    async with request.app.state.db_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

For explicit nested transactions (savepoints):

```python
async with session.begin_nested():   # savepoint
    session.add(some_object)
```

---

## Repository pattern

Repositories isolate data access. They receive a connection/session, query the DB, and return **domain types** — never ORM model instances or raw `asyncpg.Record` objects beyond the repository boundary.

```python
# repositories/user_repository.py
from dataclasses import dataclass
import asyncpg

@dataclass(frozen=True)
class UserRecord:
    id: str
    email: str
    name: str

class UserRepository:
    def __init__(self, conn: asyncpg.Connection) -> None:
        self._conn = conn

    async def get_by_id(self, user_id: str) -> UserRecord:
        row = await self._conn.fetchrow(
            "SELECT id, email, name FROM users WHERE id = $1", user_id
        )
        if row is None:
            raise NotFoundError("User", user_id)
        return UserRecord(**dict(row))

    async def create(self, user_id: str, email: str, name: str) -> UserRecord:
        await self._conn.execute(
            "INSERT INTO users(id, email, name) VALUES($1, $2, $3)",
            user_id, email, name,
        )
        return UserRecord(id=user_id, email=email, name=name)
```

Services import `UserRecord`, not `asyncpg` or SQLAlchemy — keeping the service layer free of persistence concerns.

---

## Avoiding N+1 queries

### asyncpg — batch with `IN` or a join

```python
# wrong — one query per user
for user_id in user_ids:
    profile = await conn.fetchrow("SELECT * FROM profiles WHERE user_id = $1", user_id)

# right — single query
rows = await conn.fetch(
    "SELECT * FROM profiles WHERE user_id = ANY($1::uuid[])", user_ids
)
```

### SQLAlchemy async — use `selectinload` / `joinedload`

```python
from sqlalchemy.orm import selectinload, joinedload

# selectinload: separate IN query — good for collections (one-to-many)
result = await session.execute(
    select(User).options(selectinload(User.orders))
)

# joinedload: JOIN — good for single related objects (many-to-one, one-to-one)
result = await session.execute(
    select(Order).options(joinedload(Order.user))
)
```

Never access a relationship attribute outside the session scope — it triggers a lazy load that raises `MissingGreenlet` in async context.

---

## Connection pool sizing

```
pool_size = (number_of_workers) * 2
```

- For a single-process FastAPI app: `pool_size=10` is a safe default
- Postgres max connections default is 100 — account for all app instances + migrations + admin connections
- Use `pgBouncer` in transaction pooling mode if you need >50 connections per instance
- `min_size=2` keeps warm connections ready without holding too many idle

## Common mistakes to flag

- Synchronous driver (`psycopg2`) used in an `async def` handler
- `session.query()` used with `AsyncSession` (legacy API — raises `greenlet` errors)
- Accessing ORM relationship outside session scope (lazy load in async = `MissingGreenlet`)
- Missing `expire_on_commit=False` on async session factory
- `SELECT *` in production queries (over-fetches, fragile to schema changes)
- Loop of individual queries instead of `ANY($1)` or `IN` batch query
- Pool created per-request instead of once at startup on `app.state`
- Committing inside a repository (commit belongs to the service/use-case layer, not the repository)
