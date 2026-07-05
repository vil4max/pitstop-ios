# Investigation Register

An investigation is complete only when it ends with:

``` text
Question
Evidence
Options
Decision
Why
Rejected alternatives
Implementation impact
Follow-up tasks
```

## INV-001 Official maintenance data

Question: Can PitStop legally and reliably curate official manufacturer
maintenance recommendations?

Investigate: - source availability; - redistribution rights; - market
specificity; - model-year/powertrain applicability; - source revision; -
correction workflow.

Success: - at least one manufacturer can be represented with explicit
provenance and applicability.

Failure: - data requires guessing or prohibited redistribution.

## INV-002 Procedure composition

Question: Can official sources reliably identify required components of
procedures?

Example: - oil; - filter; - seal/plug where applicable.

Success: - procedure composition is sourced per applicability.

Failure: - global assumptions such as `DSG = fluid + filter` are needed.

## INV-003 Service grouping

Question: What grouping window matches real owner behavior?

Method: - dogfood Arteon; - five-car beta; - inspect
`service_plan_edited` telemetry; - interview users.

Success: - most due-nearby suggestions are accepted.

Failure: - users routinely remove grouped work.

## INV-004 Vehicle onboarding

Compare: - natural description; - minimal explicit fields; - VIN
scan/entry later.

Success: - median setup under two minutes; - no irrelevant mandatory
fields.

## INV-005 Vehicle hero image

Decision path: 1. neutral deliberate placeholder; 2. optional
PhotosPicker personal image; 3. exact model imagery only after
licensing/API investigation.

Failure: - wrong generation/model shown as user's car.

## INV-006 Foundation Models language quality

Evaluate real Russian input with Ukrainian/English automotive
vocabulary.

Success: - supported intent and critical numeric gates from AI spec.

Failure: - prompt tricks or repeated correction are required.

## INV-007 Engine-hours policy

Question: Is manual engine-hours tracking realistic for target users?

Success: - users can access and update the fact; - policy explanation is
understandable.

Failure: - input burden exceeds value.

## INV-008 Workload policy

Keep as advanced experiment.

Do not market as oil-life diagnosis.

## INV-009 Siri/App Intents

Investigate domain fit only after domain commands stabilize.

## INV-010 Document import

Pipeline: Vision/VisionKit recognition → structured extraction → draft →
confirmation.

Need real Ukrainian service orders.

## INV-011 CarPlay/driving signals

Separate: - signal feasibility; - CarPlay app entitlement/category fit.

Never infer exact mileage from session duration.

## INV-012 CloudKit/SwiftData sync

Investigate after schema direction stabilizes.

Need: - migration; - asset/document storage; - conflicts; - widget/App
Group interaction.

## INV-013 Firebase privacy and disclosure

Before external beta: - verify Firebase Apple-platform data collection
documentation; - update App Privacy answers; - verify Crashlytics custom
logs/keys; - verify Analytics collection controls; - document
opt-out/collection decision.
