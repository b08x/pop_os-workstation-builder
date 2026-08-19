# Role: `ai_dify`

**Dify LLM orchestration platform.**

Deploys Dify components (api, worker, web, sandbox) connected to ai_databases.

## Role Variables

| Variable | Type | Required | Default | Description |
|---|---|---|---|---|
| `ai_dify_db_password` | `str` | false | `change_me_in_vault` | Password to connect to the PostgreSQL database. |
| `ai_dify_secret_key` | `str` | false | `generate_a_secret_for_dify` | Flask secret key for the Dify API. |
