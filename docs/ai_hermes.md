# Role: `ai_hermes`

**Hermes agent API gateway and dashboard.**

Deploys the Hermes workspace agent infrastructure.

## Role Variables

| Variable | Type | Required | Default | Description |
|---|---|---|---|---|
| `ai_hermes_openrouter_api_key` | `str` | false | `set_in_vault` | API key for OpenRouter LLM routing. |
| `ai_hermes_telegram_bot_token` | `str` | false | `set_in_vault` | API token for Telegram bot integration. |
