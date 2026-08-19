# Role: `ai_databases`

**Stateful data tier for AI services.**

Deploys Postgres (pgvector), Redis, and Clickhouse as Quadlets attached to ai-net.

## Role Variables

| Variable | Type | Required | Default | Description |
|---|---|---|---|---|
| `ai_databases_postgres_user` | `str` | false | `postgres` | The username for the PostgreSQL database. |
| `ai_databases_postgres_password` | `str` | false | `change_me_in_vault` | The password for the PostgreSQL database. |
| `ai_databases_clickhouse_user` | `str` | false | `clickhouse` | The username for the Clickhouse database. |
| `ai_databases_clickhouse_password` | `str` | false | `change_me_in_vault` | The password for the Clickhouse database. |
