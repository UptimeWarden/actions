# UptimeWarden GitHub Actions

Composite GitHub Actions for [UptimeWarden](https://uptimewarden.online).
Each action lives in its own folder and runs with bash and curl (plus `jq`,
which every GitHub-hosted runner has).

```yaml
- uses: uptimewarden/actions/<name>@v1
```

| Action | What it does |
|---|---|
| [`check`](./check) | One-shot multi-region uptime check. No account needed (GitHub OIDC). |
| [`check-incidents`](./check-incidents) | Pre-deploy gate: fails when an active incident is at or above a severity. |
| [`heartbeat`](./heartbeat) | Sends a heartbeat ping, or reports a failure, from a CI step. |
| [`notify-deploy-start`](./notify-deploy-start) | Records a deploy marker and opens maintenance windows. |
| [`notify-deploy-finish`](./notify-deploy-finish) | Closes those windows and finalises the deploy marker. |
| [`postmortem-link`](./postmortem-link) | Links a merged PR to the incidents it references. |
| [`sync-monitors`](./sync-monitors) | Applies a Monitoring-as-Code file with `@uptimewarden/cli`. |

Every folder has its own README with the full details. The tables below
list the inputs as they are declared in each `action.yml`.

API tokens (`uptw_…`) are created in the dashboard under
**Settings → API tokens**. Store them as repository or organisation secrets.

## Versioning

`v1` is a moving tag that follows the latest `v1.x.y` release. Pin to `@v1`
for compatible updates, or to an exact tag such as `@v1.0.0`, or to a commit
SHA if your policy requires it.

---

## check

One-shot multi-region uptime check. Without `api-token`, the action uses the
workflow's GitHub OIDC token, so the job needs `permissions: id-token: write`.

```yaml
jobs:
  smoke:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
    steps:
      - uses: uptimewarden/actions/check@v1
        id: probe
        with:
          url: https://example.com
          expect-status: 200
      - run: echo "up=${{ steps.probe.outputs.up }}"
```

| Input | Required | Default | Description |
|---|---|---|---|
| `url` | yes | | Target URL (http or https, public addresses only) |
| `regions` | no | `""` (runs from `gwc`) | Comma-separated regions: `ae` (Sydney), `brs` (São Paulo), `gwc` (Sweden Central), `sea` (East Asia), `wus3` (Phoenix) |
| `expect-status` | no | `""` | Expected HTTP status. Empty means any 2xx is up |
| `timeout` | no | `30s` | Per-region probe timeout (`10s`, `5000ms`). Server ceiling is 50s |
| `fail-on-down` | no | `true` | Fail the step when any region reports down |
| `api-token` | no | `""` | UptimeWarden API token. Your plan's daily budget and region limit apply |
| `audience` | no | `uptimewarden` | OIDC audience requested from GitHub |
| `base-url` | no | `https://app.uptimewarden.online` | API base URL |

Outputs: `up`, `regions-down`, `slowest-region-ms`, `result-json`.

## check-incidents

```yaml
- uses: uptimewarden/actions/check-incidents@v1
  with:
    api-token: ${{ secrets.UW_API_TOKEN }}
    monitors: mon_01HXYZ0AAAAAAAAAAAAAAAAAAA
    severity-threshold: major
```

| Input | Required | Default | Description |
|---|---|---|---|
| `api-token` | yes | | API token with `incidents:read` |
| `monitors` | no | `""` | Comma-separated monitor publicIds. Empty means every active incident the token can see |
| `severity-threshold` | no | `major` | Lowest severity that blocks: `minor`, `major` or `critical` |
| `bypass` | no | `false` | Log matching incidents but don't fail the step |
| `base-url` | no | `https://app.uptimewarden.online` | API base URL |

Outputs: `blocked`, `incident-count`, `incidents-json`.

## heartbeat

```yaml
- uses: uptimewarden/actions/heartbeat@v1
  with:
    token: ${{ secrets.UW_HEARTBEAT_TOKEN }}
    state: success
    message: "Deploy ${{ github.sha }} done"
```

| Input | Required | Default | Description |
|---|---|---|---|
| `token` | yes | | Heartbeat token from the monitor's page in the dashboard |
| `state` | no | `success` | `success` pings `/ping`; `failure` calls `/fail`, which opens an incident within about 30 seconds |
| `message` | no | `""` | Note sent with the signal; on failure it becomes the incident error (first 500 characters) |
| `base-url` | no | `https://app.uptimewarden.online` | API base URL |

Outputs: `status` (HTTP status code of the heartbeat endpoint). Run a second
step with `if: failure()` and `state: failure` to report a failed job.

## notify-deploy-start and notify-deploy-finish

Use them as a pair. Run the finish step with `if: always()` so the
maintenance windows close whatever the outcome; the `mute-ceiling` expires
them server-side if the finish step never runs.

```yaml
- uses: uptimewarden/actions/notify-deploy-start@v1
  id: deploy
  with:
    api-token: ${{ secrets.UW_API_TOKEN }}
    service: api
    version: ${{ github.sha }}
    monitors: mon_01HXYZ0AAAAAAAAAAAAAAAAAAA
    mute-ceiling: 30m

- run: ./deploy.sh

- uses: uptimewarden/actions/notify-deploy-finish@v1
  if: always()
  with:
    api-token: ${{ secrets.UW_API_TOKEN }}
    deploy-id: ${{ steps.deploy.outputs.deploy-id }}
    monitor-windows: ${{ steps.deploy.outputs.monitor-windows }}
    status: ${{ job.status }}
```

**notify-deploy-start**

| Input | Required | Default | Description |
|---|---|---|---|
| `api-token` | yes | | API token with monitor write and deploy permissions |
| `service` | yes | | Service name shown on the timeline |
| `version` | no | `""` | Version, tag or build identifier |
| `commit-sha` | no | `""` (uses `github.sha`) | Commit SHA |
| `environment` | no | `production` | Deploy environment |
| `monitors` | no | `""` | Comma-separated monitor publicIds to mute during the deploy |
| `mute-ceiling` | no | `30m` | Maximum mute duration (`30m`, `2h`). Server maximum is 4h |
| `mute-reason` | no | `""` (`Deploy <sha> via GitHub Actions`) | Reason recorded on each maintenance window |
| `base-url` | no | `https://app.uptimewarden.online` | API base URL |

Outputs: `deploy-id`, `monitor-windows`.

**notify-deploy-finish**

| Input | Required | Default | Description |
|---|---|---|---|
| `api-token` | yes | | The same token as `notify-deploy-start` |
| `deploy-id` | yes | | `deploy-id` output of `notify-deploy-start` |
| `monitor-windows` | no | `""` | `monitor-windows` output of `notify-deploy-start` |
| `status` | no | `success` | Pass `${{ job.status }}`: `success`, `failure` or `cancelled` |
| `base-url` | no | `https://app.uptimewarden.online` | API base URL |

This step never fails the workflow; API errors become warnings.

## postmortem-link

```yaml
on:
  pull_request:
    types: [closed]

jobs:
  link:
    if: github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    steps:
      - uses: uptimewarden/actions/postmortem-link@v1
        with:
          api-token: ${{ secrets.UW_API_TOKEN }}
```

The PR body references incidents as `Fixes #incident-<publicId>` (also
`Closes` and `Resolves`).

| Input | Required | Default | Description |
|---|---|---|---|
| `api-token` | yes | | API token with `incidents:update` |
| `status` | no | `monitoring` | Status recorded on the timeline entry. The incident's own status is not changed |
| `base-url` | no | `https://app.uptimewarden.online` | API base URL |

Outputs: `matched-incidents`, `linked-count`.

## sync-monitors

> The CLI's first npm release is coming soon. Until `@uptimewarden/cli` is
> published, this action cannot install it and the step fails.

```yaml
- uses: actions/checkout@v4
- uses: uptimewarden/actions/sync-monitors@v1
  with:
    api-token: ${{ secrets.UW_API_TOKEN }}
    config-file: monitors.uw.json
    mode: ${{ github.event_name == 'pull_request' && 'diff' || 'apply' }}
```

| Input | Required | Default | Description |
|---|---|---|---|
| `api-token` | yes | | API token with Monitor Manager permissions |
| `config-file` | no | `monitors.uw.json` | Path to the config file (`{ "monitors": [...] }`) |
| `mode` | no | `apply` | `apply`, `diff` (exit 2 on drift) or `plan` (always exit 0) |
| `allow-delete` | no | `false` | Delete monitors that are not in the config, and replace (delete + create) monitors whose `type` changes to or from `heartbeat` |
| `node-version` | no | `22` | Node.js version for the CLI (20 or later) |
| `base-url` | no | `https://app.uptimewarden.online` | API base URL (passed to the CLI as `UW_API_URL`) |

Outputs: `created`, `updated`, `replaced`, `deleted`, `has-drift`. `has-drift`
comes from the exit code of `uw apply --diff-only` (0 = in sync, 2 = drift).

---

## Related

- CLI: [uptimewarden/cli](https://github.com/uptimewarden/cli)
- Terraform provider: [uptimewarden/terraform-provider-uptimewarden](https://github.com/uptimewarden/terraform-provider-uptimewarden)
- Documentation: [uptimewarden.online](https://uptimewarden.online)

## License

Apache-2.0. See [LICENSE](./LICENSE).
