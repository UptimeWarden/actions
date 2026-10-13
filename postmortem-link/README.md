# UptimeWarden Postmortem Link

Auto-link merged PRs back to the UptimeWarden incidents they fix.

When a PR body contains `Fixes #incident-<publicId>` (or `Closes` /
`Resolves`), this action posts an update on each referenced incident's
timeline with the PR's URL, title, and merge author. Useful for
postmortem narrative ("incident inc_01HX… was resolved by PR #124")
without manual cross-linking.

## Usage

Trigger on PR close — the action no-ops if `merged` is false.

```yaml
name: Link postmortem on merge
on:
  pull_request:
    types: [closed]

jobs:
  link:
    runs-on: ubuntu-latest
    if: github.event.pull_request.merged == true
    steps:
      - uses: uptimewarden/actions/postmortem-link@v1
        with:
          api-token: ${{ secrets.UW_API_TOKEN }}
```

## Reference syntax

Recognised patterns in the PR body (case-insensitive):

```text
Fixes #incident-01HXYZ0AAAAAAAAAAAAAAAAAAA
Closes #incident-01HXYZ0BBBBBBBBBBBBBBBBBBB
Resolves #incident-01HXYZ0CCCCCCCCCCCCCCCCCCC
```

Multiple references in one PR body are all linked. Duplicates are
deduplicated.

`<publicId>` is the 26-character ULID UptimeWarden surfaces in URLs
and API responses (Crockford base32).

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `api-token` | yes | — | UW API token with `incidents:update` permission |
| `status` | no | `monitoring` | Status recorded on each timeline entry. Does NOT change the incident's own status |
| `base-url` | no | `https://app.uptimewarden.online` | API base URL |

## Outputs

| Name | Description |
|---|---|
| `matched-incidents` | Csv of incident publicIds extracted from the PR body |
| `linked-count` | How many of those the action successfully posted to (`<= matched count`) |

## What the action does NOT do

- **Does not resolve incidents.** A merged PR is a signal, not a
  verdict. UptimeWarden's incident lifecycle (`open` →
  `acknowledged` → `investigating` → `monitoring` → `resolved`)
  is owned by the on-call human; the action only adds a *timeline
  entry* with `status: monitoring` so it shows up in the incident
  feed without touching the incident's authoritative state.
- **Does not edit the postmortem document.** Postmortems are AI-
  generated + human-edited; this action stops short of mutating
  them. Future revision may extend `evidenceRefs` to record PR
  links there too.

## Failure modes (warnings, not errors)

The action never fails the workflow on individual incident
problems — each is logged with `::warning::` and the workflow
continues:

- 404: incident publicId doesn't exist or the token can't see it
- 403: token lacks editor access on the incident's monitor
- Other HTTP errors: surfaced with the response body for debug

The step itself only exits non-zero on misconfiguration
(missing `api-token`).
