# UptimeWarden Notify Deploy (finish)

Closes the maintenance windows opened by
[`notify-deploy-start`](../notify-deploy-start/) and patches the deploy
marker with the final job status.

Run this with `if: always()` so it fires whether the deploy succeeded,
failed, or was cancelled.

## Usage

See [`notify-deploy-start`'s README](../notify-deploy-start/README.md)
for the full pairing example.

```yaml
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
| `api-token` | yes | — | UW API token (`uptw_…`). Use the same token as `notify-deploy-start` |
| `deploy-id` | yes | — | `deploy-id` output from `notify-deploy-start` |
| `monitor-windows` | no | `""` | `monitor-windows` output from `notify-deploy-start` |
| `status` | no | `success` | `${{ job.status }}` — one of `success`, `failure`, `cancelled` |
| `base-url` | no | `https://app.uptimewarden.online` | API base URL |

## Failure handling

This action is intentionally non-fatal: every API call absorbs its own
error and emits `::warning::` instead. The post-step must never fail
the workflow — that would mask the real outcome of the deploy.

If the close call fails, the `mute-ceiling` from `notify-deploy-start`
ensures the window auto-expires server-side after at most 4 hours.
