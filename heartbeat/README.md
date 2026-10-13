# UptimeWarden Heartbeat Action

Send a heartbeat ping to UptimeWarden from any GitHub Actions step.

Pair with a **Heartbeat monitor** in UptimeWarden — the monitor expects
a ping every `interval + grace` seconds. If your CI doesn't ping in
time, an incident opens automatically.

## Usage

```yaml
- name: Notify UptimeWarden after deploy
  uses: uptimewarden/actions/heartbeat@v1
  with:
    token: ${{ secrets.UW_HEARTBEAT_TOKEN }}
    state: success
    message: "Deploy ${{ github.sha }} done"
```

### Reporting a failure

The heartbeat endpoint records every ping as a success; it cannot record a
failure yet. `state: failure` therefore fails the step **without sending a
ping**, instead of reporting a failed job as healthy.

To report a failure today, skip the ping: run the step only when the job
succeeded (the default for a step without `if:`), and the monitor alerts when
the heartbeat is overdue.

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `token` | yes | — | Heartbeat token from the monitor's settings page |
| `state` | no | `success` | `success`. `failure` is not supported yet and fails the step without sending a ping |
| `message` | no | `""` | Human-readable note attached to the ping |
| `base-url` | no | `https://app.uptimewarden.online` | API base URL |

## Outputs

| Name | Description |
|---|---|
| `status` | HTTP status code from the ping endpoint |

## Dependencies

The action makes a single `curl POST` to the heartbeat endpoint. It needs
bash and curl, nothing else.
