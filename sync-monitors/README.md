# UptimeWarden Sync Monitors

Applies a Monitoring-as-Code config file to UptimeWarden from a GitHub
workflow. It installs `@uptimewarden/cli` from npm and runs `uw apply`
against the file.

> The CLI's first npm release is coming soon. Until `@uptimewarden/cli` is
> published, this action cannot install it and the step fails.

Typical setup: `diff` on pull requests to show what would change, `apply` on
push to the main branch.

## Usage

```yaml
on:
  pull_request:
  push:
    branches: [main]

jobs:
  monitors:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: uptimewarden/actions/sync-monitors@v1
        id: sync
        with:
          api-token: ${{ secrets.UW_API_TOKEN }}
          config-file: monitors.uw.json
          mode: ${{ github.event_name == 'pull_request' && 'diff' || 'apply' }}
      - run: echo "Drift: ${{ steps.sync.outputs.has-drift }}"
```

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `api-token` | yes | — | API token with Monitor Manager permissions |
| `config-file` | no | `monitors.uw.json` | Path to the config file (JSON: `{ "monitors": [...] }`) |
| `mode` | no | `apply` | `apply` applies every change. `diff` shows the plan and exits 2 when there is drift. `plan` shows the plan and always exits 0 |
| `allow-delete` | no | `false` | Delete monitors that are not in the config. When false, deletions are shown but not applied |
| `node-version` | no | `22` | Node.js version for the CLI (20 or later) |
| `base-url` | no | `https://app.uptimewarden.online` | API base URL |

## Outputs

| Name | Description |
|---|---|
| `created` | Monitors created (0 in `plan` and `diff`) |
| `updated` | Monitors updated (0 in `plan` and `diff`) |
| `deleted` | Monitors deleted (0 unless `allow-delete` is true in `apply` mode) |
| `has-drift` | `true` when the config differs from what is live |

The step also writes a summary table (or the plan) to the job summary.

## Notes

- The counters are read from the CLI's human-readable output, so they follow
  its `✓ created` / `✓ updated` / `✓ deleted` lines.
- The action does nothing a local `uw apply` would not do. Test a config
  locally with `uw apply -f monitors.uw.json --diff-only` first.
