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
| `allow-delete` | no | `false` | Delete monitors that are not in the config, and replace monitors whose `type` changes to or from `heartbeat` (the API cannot do that in place, so the old monitor and its history are deleted and a new one is created; other type changes are updates). When false, both are shown but not applied; a blocked replacement makes `apply` fail |
| `node-version` | no | `22` | Node.js version for the CLI (20 or later) |
| `base-url` | no | `https://app.uptimewarden.online` | API base URL, passed to the CLI as `UW_API_URL` |

## Outputs

| Name | Description |
|---|---|
| `created` | Monitors created (0 in `plan` and `diff`) |
| `updated` | Monitors updated (0 in `plan` and `diff`) |
| `replaced` | Monitors replaced because their `type` changed to or from `heartbeat` (0 unless `allow-delete` is true in `apply` mode) |
| `deleted` | Monitors deleted (0 unless `allow-delete` is true in `apply` mode) |
| `has-drift` | `true` when the config differed from what was live before the run. `unknown` when the plan failed |

The step also writes a summary table (or the plan) to the job summary.

## Config file

The config is the CLI's: a `monitors` array where each entry has an
`externalId`, a `name` and any `/api/v1/monitors` field under the API's name
(check settings, regions, thresholds, alert routing, maintenance windows,
heartbeat settings). Escalation policies and webhooks can be given by name.
See the [CLI README](https://github.com/UptimeWarden/cli#config-file) for the
field list and the diff rules.

```json
{
  "monitors": [
    {
      "externalId": "api-prod",
      "name": "API (production)",
      "type": "http",
      "url": "https://api.example.com/health",
      "interval": 60,
      "expectedStatusCodes": "200-299",
      "escalationPolicyId": "P1 on-call"
    }
  ]
}
```

## How it works

1. `uw apply -f <config> --diff-only` prints the plan. Its exit code sets
   `has-drift`: 0 means in sync, 2 means drift, anything else fails the step.
2. In `apply` mode, and only when there is drift, `uw apply -f <config> --yes`
   applies it.
3. `diff` mode exits 2 when there is drift; `plan` mode always exits 0.

The token and API URL reach the CLI as `UW_API_TOKEN` and `UW_API_URL`; no
config file is written.

## Notes

- The counters are read from the CLI's human-readable output, so they follow
  its `✓ created` / `✓ updated` / `✓ replaced` / `✓ deleted` lines.
- The action does nothing a local `uw apply` would not do. Test a config
  locally with `uw apply -f monitors.uw.json --diff-only` first.
