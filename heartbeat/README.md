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

Failure path:

```yaml
- name: Notify UptimeWarden on failure
  if: failure()
  uses: uptimewarden/actions/heartbeat@v1
  with:
    token: ${{ secrets.UW_HEARTBEAT_TOKEN }}
    state: failure
    message: "Deploy ${{ github.sha }} failed at ${{ github.job }}"
```

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `token` | yes | — | Heartbeat token from the monitor's settings page |
| `state` | no | `success` | `success` or `failure` |
| `message` | no | `""` | Human-readable note attached to the ping |
| `base-url` | no | `https://app.uptimewarden.online` | API base URL |

## Outputs

| Name | Description |
|---|---|
| `status` | HTTP status code from the ping endpoint |

## Dependencies

The action makes a single `curl POST` to the heartbeat endpoint. It needs
bash and curl, nothing else.
