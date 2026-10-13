# UptimeWarden Heartbeat Action

Send a heartbeat signal to UptimeWarden from any GitHub Actions step: a ping
when the job succeeded, or a failure when it did not.

Pair with a **Heartbeat monitor** in UptimeWarden. The monitor expects a ping
every `interval + grace` seconds; if none arrives in time, an incident opens.
A failure signal opens the incident right away (within about 30 seconds)
instead of waiting for the interval and grace.

## Usage

```yaml
- name: Notify UptimeWarden after deploy
  uses: uptimewarden/actions/heartbeat@v1
  with:
    token: ${{ secrets.UW_HEARTBEAT_TOKEN }}
    message: "Deploy ${{ github.sha }} done"

- name: Report the failure to UptimeWarden
  if: failure()
  uses: uptimewarden/actions/heartbeat@v1
  with:
    token: ${{ secrets.UW_HEARTBEAT_TOKEN }}
    state: failure
    message: "Deploy ${{ github.sha }} failed at ${{ github.job }}"
```

`state: success` POSTs to `/api/heartbeat/<token>/ping`; `state: failure`
POSTs to `/api/heartbeat/<token>/fail`. On a failure the message becomes the
incident's error.

The token is the monitor's heartbeat token: from the monitor's page in the
dashboard, or `heartbeat_token` of an `uptimewarden_monitor` in Terraform.
Store it as a secret; the action never prints it.

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `token` | yes | — | Heartbeat token |
| `state` | no | `success` | `success` (ping) or `failure` (report a failure now) |
| `message` | no | `""` | Note sent with the signal; on failure, the incident error. The API keeps the first 500 characters; line breaks become spaces |
| `base-url` | no | `https://app.uptimewarden.online` | API base URL |

## Outputs

| Name | Description |
|---|---|
| `status` | HTTP status code from the heartbeat endpoint |

## Dependencies

The action makes a single `curl POST` to the heartbeat endpoint. It needs
bash and curl, nothing else.
