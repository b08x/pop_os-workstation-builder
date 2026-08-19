# Role: `ai_langfuse`

**Langfuse LLM telemetry and observability.**

Deploys Langfuse web server connected to Postgres and Clickhouse.

## Role Variables

| Variable | Type | Required | Default | Description |
|---|---|---|---|---|
| `ai_langfuse_db_password` | `str` | false | `change_me_in_vault` | Password to connect to the PostgreSQL database. |
| `ai_langfuse_clickhouse_password` | `str` | false | `change_me_in_vault` | Password to connect to the Clickhouse database. |
| `ai_langfuse_nextauth_secret` | `str` | false | `generate_a_secret` | Secret for NextAuth session encryption. |
| `ai_langfuse_salt` | `str` | false | `generate_a_salt` | Cryptographic salt value. |
