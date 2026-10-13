# UptimeWarden Check

One-shot multi-region uptime check from any GitHub workflow. **No
UptimeWarden account required** — authentication uses your workflow's
GitHub OIDC token.

Useful for:

- CI smoke tests after a deploy ("does my prod URL come up from Asia?")
- Pre-merge gates ("don't merge if the staging endpoint is down")
- Cron-scheduled probes that don't justify a full UW monitor

## Usage

```yaml
jobs:
  smoke:
    runs-on: ubuntu-latest
    permissions:
      id-token: write          # required for OIDC
    steps:
      - uses: uptimewarden/actions/check@v1
        id: probe
        with:
          url: https://example.com   # no regions input: runs from gwc
          expect-status: 200
          timeout: 10s
          fail-on-down: true
      - run: |
          echo "All up: ${{ steps.probe.outputs.up }}"
          echo "Slowest region: ${{ steps.probe.outputs.slowest-region-ms }}ms"
```

With an API token, a check may name as many regions as your plan's
verification region limit (see Limits):

```yaml
      - uses: uptimewarden/actions/check@v1
        with:
          url: https://example.com
          regions: gwc,wus3,sea      # needs a limit of 3 or more
          api-token: ${{ secrets.UW_API_TOKEN }}
```

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `url` | yes | — | Target URL (http or https; public IPs only) |
| `regions` | no | `""` | Csv of regions (`ae`, `brs`, `gwc`, `sea`, `uaen`, `wus3`). Default: `gwc` |
| `expect-status` | no | `""` | Expected status code. Default: any 2xx is up |
| `timeout` | no | `30s` | Per-region probe timeout (`30s`, `5000ms`, `10s`) |
| `fail-on-down` | no | `true` | Whether the step fails when any region reports down |
| `api-token` | no | `""` | UW API token. Your plan's quota and region count apply (see Limits) |
| `audience` | no | `uptimewarden` | OIDC audience. Must match the UW server-side default |
| `base-url` | no | `https://app.uptimewarden.online` | API base URL |

## Outputs

| Name | Description |
|---|---|
| `up` | `"true"` if every region reported up, `"false"` otherwise |
| `regions-down` | Csv of regions that reported down. Empty if all up |
| `slowest-region-ms` | Highest responseTimeMs across all regions |
| `result-json` | Compact JSON — the full `checks` array from `/api/public/check` |

## Auth modes

**Anonymous via GitHub OIDC (default):** the action exchanges the
workflow's id-token for a JWT bound to the `uptimewarden` audience.
No UW signup, but limited to one region and 5 checks/day per
GitHub repository owner (user or org).

**With a UW API token:** set `api-token` (store it as a secret). The
token is verified, and your plan's limits apply to your account: its
daily check budget, which every token you own shares, and its
verification region limit as regions per check. An unknown or
revoked token answers 401 `invalid-token`, an expired one 401
`token-expired`. Results are returned to the workflow only; they are
not saved to a monitor's history.

## Limits

A check is one request: it counts once against the daily budget however
many regions it names. Without a `regions` input the check runs from
`gwc` only. Naming more regions than your tier allows answers 409
`too-many-regions` with the allowed `max`; an exhausted budget answers
429 `rate-limit-org` with `Retry-After` (the budget resets at 00:00 UTC).

| Caller | Checks per day | Regions per check |
|---|---|---|
| No account (GitHub OIDC) | 5 per repository owner | 1 |
| API token, Free | 100 | 2 |
| API token, Hobby | 250 | 3 |
| API token, Starter | 500 | 3 |
| API token, Professional | 2,000 | 5 |
| API token, Enterprise | 5,000 | 6 |
| API token, plan with no configured limits | 5 | 1 |

- **Regions per check** with a token are your plan's verification region
  limit, the same number that caps how many regions can confirm a
  monitor outage. There is no
  separate public-check region setting.
- **Checks per day** with a token come from your plan's public check
  limit. All tokens of one user share one budget.
- The table shows the seeded defaults. Both values are set per plan, so a
  custom or adjusted plan can differ.
- An unknown, revoked or expired token answers 401 and never falls back
  to the no-account tier.
- **Per-target hostname global cap:** 60 probes/min, across all
  callers. UptimeWarden won't probe a single hostname faster than
  this regardless of how many separate orgs request it. This is the
  load-bearing rule that prevents the action from being an
  amplifier; legitimate users will not hit it.

## Good citizenship

- The probe sends `User-Agent: uptimewarden-check/1.0
  (+mailto:support@uptimewarden.online)` so target ops can identify
  and block us if they want, and reach us at that address to report
  abuse.
- A target that returns `X-Uptime-Warden-Optout: true` is reported as
  `down` with error `target-opted-out` for that probe. There is no
  automatic exemption window yet: later checks still reach the target
  (within the 60/min hostname cap).
- Probes only reach public addresses. Private, loopback, link-local,
  cloud-metadata and similar addresses are refused when the request is
  validated (400) and again when the probe connects, so a hostname that
  switches to a private address in between reports `target-refused`.

## Requirements

- The calling job must declare `permissions: id-token: write` for
  OIDC mode.
- `jq` must be in PATH. Pre-installed on every GitHub-hosted runner
  (ubuntu / macos / windows-bash). Self-hosted runners need to
  install it.
