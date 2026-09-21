# PostHog HTTP Adapter

**Status:** Accepted for implementation (owner chose HTTP without SDK,
2026-09-21); owner review pending\
**Task:** ANL-001\
**Contracts:** [`0002-analytics-service.md`](0002-analytics-service.md),
[`0003-logging.md`](0003-logging.md),
[`0021-analytics-boundary.md`](0021-analytics-boundary.md),
[`../operations/analytics.md`](../operations/analytics.md),
[`../operations/telemetry-contract.md`](../operations/telemetry-contract.md)

## Context

ADR 0021 (ENG-002) left `AnalyticsClient.send(_:)` as the provider seam, a
consent gate that is off by default, and an owner question on the consent
model. ADR 0002 selected PostHog and planned `ANL-001` as an SDK vertical
slice, which needed owner approval for a new package.

Owner decision (2026-09-21, in chat): implement the PostHog adapter **without
the SDK**, over HTTP with `URLSession`, and add no dependency. No PostHog
project, API key, or region exists yet.

## PostHog API facts used

Checked on 2026-09-21 against PostHog's documentation:

| Fact | Source |
| --- | --- |
| `POST /batch/` takes `{"api_key", "historical_migration", "batch": [...]}`; each entry has `event`, `distinct_id`, optional `properties` and ISO 8601 `timestamp`; the whole body must stay under 20 MB | [Capture and batch API](https://posthog.com/docs/api/capture) |
| Hosts: `https://us.i.posthog.com` (US Cloud), `https://eu.i.posthog.com` (EU Cloud) | [Capture and batch API](https://posthog.com/docs/api/capture) |
| Capture endpoints are public POST-only endpoints authenticated by the project token, and return no project data; personal API keys are for private endpoints only | [API overview](https://posthog.com/docs/api), [Capture and batch API](https://posthog.com/docs/api/capture) |
| API events are identified by default; `"$process_person_profile": false` captures an anonymous event without a person profile | [Capture and batch API, "Anonymous event capture"](https://posthog.com/docs/api/capture), [Anonymous vs identified events](https://posthog.com/docs/data/anonymous-vs-identified-events) |
| GeoIP enrichment reads `$ip` or else the IP of the client that sent the request; `"$geoip_disable": true` skips it for that event | [posthog-plugin-geoip README](https://github.com/PostHog/posthog-plugin-geoip/blob/main/README.md) (PostHog's own plugin), [posthog-go `$geoip_disable` field](https://pkg.go.dev/github.com/posthog/posthog-go) |
| Client IP capture is a project setting (**Settings > Project > Privacy > IP data capture configuration**); EU organizations default to discarding it | [Privacy controls](https://posthog.com/docs/product-analytics/privacy), [Controlling data collection](https://posthog.com/docs/privacy/data-collection) |

`$geoip_disable` is documented in PostHog's plugin and SDK sources, not on
the capture API page. No client-side property stops PostHog from seeing the
request's IP address, so discarding it is an owner action in the project
settings (below), not something the app can guarantee.

## Decision

### Shape

```text
AnalyticsTracker<FeatureEvent>
    ↓ AnalyticsClient
ConsentGatedAnalyticsClient ── AnalyticsConsentStore (UserDefaults behind AnalyticsPreferenceStorage)
    ↓ AnalyticsClient
PostHogAnalyticsClient ── AnalyticsHTTPTransport (URLSessionAnalyticsTransport | test fake)
```

All code is in `Pitstop/Infrastructure/Analytics/`:

- `PostHogAnalyticsClient` implements `AnalyticsClient` and
  `AnalyticsPipelineControlling` (`flush()`, `discardPending()`). `send`
  stamps the event with the anonymous ID and the time, appends it to an
  in-memory queue under a `Mutex`, and returns. Flushes run in detached
  utility tasks (including the one on entering the background), so encoding
  and networking stay off the main actor.
- `PostHogPayload` builds the batch body; `PostHogConfiguration` reads the key
  and host from Info.plist.
- `AnalyticsHTTPTransport` is the only network seam. The default is an
  ephemeral `URLSession` (no cookies, cache, or stored credentials); it
  replaces the default `User-Agent` (app build, CFNetwork and Darwin
  versions) with `PitStop` and `Accept-Language` with `*`.
- `AnalyticsConsentStore` persists consent and the anonymous ID through
  `AnalyticsPreferenceStorage`, injected by initializer.
- `AnalyticsSharing` is the one place consent changes: Settings calls it, and
  a withdrawal also discards the pipeline's queue.

### Delivery policy

| Rule | Value |
| --- | --- |
| Batch size | 20 events: reaching it starts a flush |
| Flush interval | 30 s after the first event of a quiet queue |
| App background | `RootView` flushes when the scene enters `.background` |
| Queue bound | 200 events; the oldest is dropped for the newest |
| Retry | up to 3 attempts per flush; backoff 2 s, 4 s, doubling, capped at 60 s |
| Transient | thrown transport error, no status, 408, 429, 5xx |
| Refused | any other non-2xx (400, 401, 413 …): the batch is dropped and logged |
| Exhausted | the batch returns to the front of the queue; for 60 s (`maxBackoff`) a full batch no longer starts a flush, so an outage does not turn every new event into three requests; the interval timer and the background flush still try |

Only one flush runs at a time; it drains the queue in batches. Failures are
logged to the `analytics` OSLog category with the status and the event count
only, and never reach the caller: `send` is synchronous and cannot throw.

Flushing on background uses a detached task, not a background-task assertion.
If iOS suspends the app before the request finishes, the batch stays in
memory and goes out on the next flush after the app resumes; if the process
is killed, it is lost (see "No disk persistence").

### Privacy measures

- **Consent first.** Nothing is queued or sent unless consent is `granted`
  (ADR 0021 gate). Without a configured project no provider client exists.
- **Anonymous ID.** On opt-in the store generates a random UUID and keeps it
  in `UserDefaults`. It is not derived from the device, the vendor ID, the
  IDFA, or anything the user typed. Withdrawal deletes it; a later opt-in gets
  a new one, so the two periods cannot be joined by ID.
- **Withdrawal drops unsent events.** `AnalyticsSharing.setEnabled(false)`
  records `declined`, deletes the ID, and discards the queue. Every batch is
  also filtered by the current ID when it is taken and before every attempt,
  so an event queued under a withdrawn ID is not sent or retried once the
  withdrawal is observed, including one queued concurrently with it. A
  request already on the network when the user withdraws cannot be recalled.
- **Anonymous events, no person profiles.** Every event carries
  `$process_person_profile: false`. The adapter never sends `$identify`,
  `$set`, `$set_once`, aliases, or group events.
- **No location.** Every event carries `$geoip_disable: true`, and the app
  never sets `$ip`.
- **Neutral headers.** Requests carry no app version, OS version, or locale
  in `User-Agent` or `Accept-Language`.
- **Closed values only.** The payload holds the event name, its properties
  from ENG-002's closed `AnalyticsValue` types, the anonymous ID, the
  timestamp, and the two flags above. The adapter adds no device model, OS,
  app version, locale, screen, or network property; tests fail if a `$ip`,
  `$set`, `$device…`, `$os…`, `$app…`, or `$lib…` key appears.
- **No disk persistence.** Events live only in memory (see trade-off below).
- **No key in the repository.** See "Configuration".
- **Privacy manifest.** `Pitstop/Resources/PrivacyInfo.xcprivacy` declares
  the first `UserDefaults` use with reason `CA92.1` (the app reads and writes
  its own defaults) and no tracking
  ([Apple: NSPrivacyAccessedAPITypeReasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)).
  It declares no collected data types, because a build without a key
  collects nothing; see owner actions.

Boolean properties are sent as the strings `"true"` and `"false"`, as ENG-002
encodes them; the adapter does not reinterpret them.

### Configuration

- `Config/Analytics.xcconfig` is the project-level base configuration for
  Debug and Release. It sets `POSTHOG_PROJECT_API_KEY` and `POSTHOG_HOST` to
  empty values and then `#include?`s `Config/Analytics.local.xcconfig`, which
  `.gitignore` excludes.
- `Config/Info.plist` (merged into the generated Info.plist through
  `INFOPLIST_FILE`) maps them to `PostHogProjectAPIKey` and `PostHogHost`.
- `PostHogConfiguration` returns `nil` for an empty or unexpanded value, a key
  with whitespace, or a non-HTTPS host. `AppEnvironment.makeAnalytics` then
  composes the consent-gated `NoAnalyticsClient` from ADR 0021: no network
  client exists.
- `POSTHOG_HOST` is a bare host (`eu.i.posthog.com`), because `//` starts a
  comment in an xcconfig file. An `https://` value set elsewhere is accepted.

A project API key is write-only and ships inside the app binary by design, so
it is not a secret in the credential sense. It stays out of the public
repository anyway, so forks and clones do not send events into the owner's
project.

### Consent model (ADR 0021, owner question 1)

Implemented as recommended there, pending owner review: a Settings switch
"Share anonymous usage data" (en/ru/uk), off by default, with a one-line
footer saying what is sent. There is no first-launch prompt and no one-time
ask during the beta; `notAsked` stays equal to "no". The DEBUG
`-pitstop-analytics-log` argument keeps its fixed `granted` consent and ignores
the switch.

## Tests

`PitstopTests/Analytics/PostHogAnalyticsClientTests.swift`, tagged `ADR-0021`
or `ADR-0022`, with `FakeAnalyticsTransport` and `RecordingSleeper` in
`PitstopTests/Support/`:

- payload for every event in the ENG-002 catalog: exact top-level and entry
  keys, closed property values only, the anonymous ID, the timestamp format,
  `$process_person_profile: false`, `$geoip_disable: true`, and no other `$`
  key; a second test rejects IP, device, person, and set keys;
- consent `notAsked` or `declined`: no request, nothing queued;
- opt-in creates a UUID; withdrawal empties the queue, deletes the ID, sends
  nothing, and a new opt-in gets a new ID; events queued under an earlier ID
  are never sent under a later one;
- no request below the batch size, one request for a full batch to
  `https://<host>/batch/`, and a partial batch after the flush interval;
- the bounded queue keeps the newest events;
- transient failures retry with 2 s and 4 s backoff; exhausted retries keep
  the batch in memory and pause size-triggered flushes for 60 s; 400, 401, and 413 drop it without retry; backoff cap;
- a failing transport never reaches a feature tracker;
- empty, unexpanded, and insecure configurations give no client; bare and
  `https://` hosts give the batch URL; `AppEnvironment.makeAnalytics`
  composes the no-op without a configuration and the adapter with one.

## Rejected alternatives

- **PostHog iOS SDK.** Owner decision: no new dependency. The SDK would also
  bring autocapture, session replay, feature flags, and device properties
  that ADR 0002 keeps off and that would need auditing per release.
- **Persist the queue to disk.** It would keep offline events across launches,
  but leave analytics data on the device after the user opts out unless every
  file is found and deleted, and it adds a file lifecycle to a five-car beta.
  Trade-off accepted: events not delivered before the process ends are lost.
- **Single-event endpoint `/i/v0/e/`.** One request per event costs more
  radio time; `/batch/` sends the same fields in one request.
- **An IDFA, `identifierForVendor`, or install-time ID.** Each outlives a
  consent withdrawal or links to other data; the consent-scoped UUID does
  neither.
- **Send `$ip` as null or a placeholder.** Undocumented behaviour; the
  project setting is the documented control.
- **Retry forever inside a flush.** It would hold the flush and grow the
  queue; bounded attempts plus retry on the next flush keep memory and
  battery bounded.
- **Commit the key.** The repository is public; a committed key would receive
  events from every build of every fork.

## Owner actions

1. Create a PostHog Cloud project and choose the region: EU
   (`eu.i.posthog.com`) or US (`us.i.posthog.com`). The EU region defaults to
   discarding client IP data.
2. In the project, set **Settings > Project > Privacy > IP data capture
   configuration** to discard client IP data, and keep autocapture, session
   replay, and surveys off (ADR 0002).
3. Supply the project API key (project token, `phc_…`) and host:
   - locally, create the untracked `Config/Analytics.local.xcconfig`:

     ```text
     POSTHOG_PROJECT_API_KEY = phc_your_project_token
     POSTHOG_HOST = eu.i.posthog.com
     ```

   - for Xcode Cloud, add both as workflow environment variables (the key as
     a secret) and write the same file from a `ci_scripts/ci_pre_xcodebuild.sh`
     step; this step is not added yet, because `ci_scripts/ci_post_clone.sh`
     is installed by the Runtime and a new script is a pipeline change for
     the owner to approve.
4. Before the first build with a key reaches testers: answer App Store
   Connect App Privacy for "Product Interaction" (not linked to the user, not
   used for tracking), add the matching `NSPrivacyCollectedDataTypes` entry
   to `PrivacyInfo.xcprivacy`, and run the analytics smoke checklist in
   `../operations/analytics.md`.
5. Review the consent model above and decide whether a one-time beta ask is
   still wanted.
6. Decide after the spike: ADOPT, ADOPT WITH BOUNDARY, or FALL BACK TO
   TELEMETRYDECK (ADR 0002). Launch-time and binary impact are negligible by
   construction (no SDK); dashboard and funnel setup time can only be measured
   once a project exists.
