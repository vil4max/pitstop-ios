# Release and TestFlight Beta

## Beta purpose

Five real cars are a product research sample, not a growth launch.

The beta validates: - one-car onboarding; - status comprehension; -
notes/context recall; - natural input; - maintenance planning
composition; - history recording.

## Pre-beta release gate

### Data integrity

-   no known data-loss issue;
-   migration path tested;
-   partial service invariant tested;
-   unknown baseline behavior tested.

### Stability

-   Crashlytics integrated and symbolicated;
-   no release-blocking crash open;
-   critical flow smoke test passes.

### Analytics

-   provider smoke checklist passes for selected analytics adapter
    (`ANL-001` outcome applies);
-   event names/parameters match contract;
-   no raw private content observed.

### Logging

-   Tell PitStop pipeline diagnosable by stage/reason;
-   maintenance snapshot pipeline diagnosable;
-   no production `print` in new domain paths.

### Product

-   setup is lightweight;
-   photo is optional;
-   core use works without Foundation Models;
-   car-wash context is obvious;
-   status does not claim diagnostics.

## Beta cohort

Target: - Max / Arteon; - five friends; - different cars where possible.

Avoid collecting unnecessary demographic data.

## Research cadence

Day 0: - install/setup observation if possible.

Day 7: - 20--30 minute interview.

Day 21: - second interview.

Day 30: - product decision review.

## Interview questions

Do not lead with feature names.

Ask: - Tell me the last time you opened PitStop. Why? - What did you
expect to see? - Did PitStop remind you of something useful? - Did
anything feel like data entry? - Was any maintenance suggestion wrong or
unnecessary? - Did you remove anything from a service plan? Why? - Did
you want to record something but decide it was too much effort? - What
would you be afraid to trust PitStop with?

## Stop criteria

Pause beta rollout if: - maintenance status is materially wrong for a
tester; - a skipped operation is marked completed; - migration/data loss
occurs; - telemetry sends prohibited raw content; - onboarding blocks a
tester due to unsupported vehicle data.

## Phase decision after day 30

Choose one:

``` text
CONTINUE CORE
Notes/Status/History show recurring value.

FOCUS MAINTENANCE
Planner/status is valuable; memory contexts are weak.

FOCUS MEMORY
Notes/history are valuable; maintenance knowledge is not trustworthy enough.

REDESIGN
Core recurring value is not demonstrated.
```

Do not declare success because Foundation Models works.
