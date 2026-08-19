# Role: `dotfiles`

**Install yadm and clone the user's dotfiles.**

Layer 1 stops here. Everything under $HOME, including user-scope CLI tools, is the responsibility of the yadm bootstrap script.

## Role Variables

| Variable | Type | Required | Default | Description |
|---|---|---|---|---|
| `dotfiles_user` | `str` | true | `None` | Login name owning the dotfiles. |
| `dotfiles_manage` | `bool` | false | `true` | Install yadm and attempt the clone. |
| `dotfiles_repo` | `str` | false | `` | yadm repository URL. Empty skips the clone. |
| `dotfiles_run_bootstrap` | `bool` | false | `true` | Pass --bootstrap to yadm clone. |
| `dotfiles_require_clone` | `bool` | false | `false` | Fail the play when the clone does not succeed. Leave false for first runs, where no SSH key exists yet. |
| `dotfiles_packages` | `list` | false | `None` | APT packages providing yadm. |
