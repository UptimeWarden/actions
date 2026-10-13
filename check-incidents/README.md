# UptimeWarden Check Incidents

Pre-deploy gate. Exits the step non-zero if there's an active
UptimeWarden incident on a configured monitor at or above a
severity threshold — so you don't push into a fire.

Pairs naturally with `notify-deploy-start` / `notify-deploy-finish`:

```yaml
- uses: uptimewarden/actions/check-incidents@v1
  with:
    api-token: ${{ secrets.UW_API_TOKEN }}
    monitors: mon_01HXYZ0AAAAAAAAAAAAAAAAAAA
    severity-threshold: major

- uses: uptimewarden/actions/notify-deploy-start@v1
  id: deploy
  with:
    api-token: ${{ secrets.UW_API_TOKEN }}
    service: api
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

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `api-token` | yes | — | UW API token with `incidents:read` permission |
| `monitors` | no | `""` | Csv of monitor publicIds. Empty = every active incident the token can see counts |
| `severity-threshold` | no | `major` | Lowest severity that blocks: `minor`, `major`, or `critical` |
| `bypass` | no | `false` | If `true`, log incidents but don't fail the step |
| `base-url` | no | `https://app.uptimewarden.online` | API base URL |

## Outputs

| Name | Description |
|---|---|
| `blocked` | `"true"` if one or more incidents matched (regardless of `bypass`) |
| `incident-count` | Number of matching incidents |
| `incidents-json` | Compact JSON array; each entry has `publicId`, `monitorPublicId`, `severity`, `title`, `status` |

## Severity ordering

UptimeWarden incidents use three severities: `minor` < `major` <
`critical`. The threshold is inclusive: `severity-threshold: major`
blocks on `major` and `critical` but lets `minor` pass.

## Bypass mode

`bypass: true` runs the action read-only — `blocked` and
`incidents-json` still surface the matching incidents, but the step
exits 0. Useful for:

- Dashboards / status reports where you want to see incidents
  without blocking the workflow.
- Migration windows where you accept the risk of deploying during
  an active incident and don't want to comment out the gate.

Don't ship this to a production gate workflow unless you really
mean it — it's the deploy-equivalent of `--force`.

## Requirements

- `jq` in PATH (preinstalled on every GitHub-hosted runner).
