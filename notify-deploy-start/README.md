# UptimeWarden Notify Deploy (start)

Records a deploy marker on the UptimeWarden timeline and (optionally)
opens maintenance windows on the listed monitors so alerts are
suppressed for the duration of the deploy.

Pair with [`notify-deploy-finish`](../notify-deploy-finish/) under
`if: always()` so the windows close + marker is finalised regardless
of the deploy's outcome.

## Why the split

Composite GitHub Actions don't support `runs.post:` lifecycle hooks
the way JavaScript actions do, so the lifecycle is split into two
composite actions. The server-side `mute-ceiling` (default
30m, hard max 4h) ensures windows auto-expire even if `notify-deploy-finish`
is skipped (runner crash, network outage, forgotten step).

## Usage

```yaml
- uses: uptimewarden/actions/notify-deploy-start@v1
  id: deploy
  with:
    api-token: ${{ secrets.UW_API_TOKEN }}
    service: api
    version: ${{ github.sha }}
    environment: production
    monitors: mon_01HXYZ0AAAAAAAAAAAAAAAAAAA,mon_01HXYZ0BBBBBBBBBBBBBBBBBBB
    mute-ceiling: 30m
    mute-reason: 'Deploy ${{ github.sha }}'

- run: ./deploy.sh

- uses: uptimewarden/actions/notify-deploy-finish@v1
  if: always()
  with:
    api-token: ${{ secrets.UW_API_TOKEN }}
    deploy-id: ${{ steps.deploy.outputs.deploy-id }}
    monitor-windows: ${{ steps.deploy.outputs.monitor-windows }}
    status: ${{ job.status }}
```

## Authentication

`api-token` is a UW API token (prefix `uptw_…`) created from the API
Tokens admin page. The token must be able to write monitors (for the
maintenance window calls) and create deploys. Store it as a repo or
organisation secret (e.g. `UW_API_TOKEN`) and reference it as
`${{ secrets.UW_API_TOKEN }}`.

Granular permission scopes (e.g. `deploys:write`,
`monitors:maintenance:write`) and the "Deploy Manager" permission
preset are on the roadmap; until they ship, a Monitor Manager-class
token covers the surface this action needs.

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `api-token` | yes | — | UW API token (`uptw_…`) with monitor write + deploy permissions. See "Authentication" above |
| `service` | yes | — | Service name (free-form, surfaces on the timeline) |
| `version` | no | `""` | Version / tag / build identifier |
| `commit-sha` | no | `${{ github.sha }}` | Commit SHA |
| `environment` | no | `production` | Deploy environment |
| `monitors` | no | `""` | Csv of monitor publicIds. Each gets a maintenance window |
| `mute-ceiling` | no | `30m` | Hard cap on mute duration — `30m`, `2h`, `240m`, `90s` |
| `mute-reason` | no | `Deploy <sha> via GitHub Actions` | Audit reason recorded on each window |
| `base-url` | no | `https://app.uptimewarden.online` | API base URL |

## Outputs

| Name | Description |
|---|---|
| `deploy-id` | Deploy marker publicId. Pass to `notify-deploy-finish` |
| `monitor-windows` | Csv of `monitorId:windowId` pairs. Pass to `notify-deploy-finish` |
