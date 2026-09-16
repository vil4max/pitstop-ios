# App Icon Strategy

**Status:** immediate product identity task

## Problem

The current blue `A` icon is inherited from the Arteon/Volkswagen
experiment.

It does not communicate PitStop and does not create ownership
recognition for the developer/user.

## Immediate decision

Create a PitStop primary icon now.

Objective:

> Max sees the icon on the Home Screen and immediately recognizes: this
> is my PitStop app.

The icon should not use Volkswagen branding or a Volkswagen blue as its
identity.

## Icon concept

Primary direction:

``` text
simple rounded route/service mark
+
subtle P / pit-stop association
+
calm cloud-blue field
+
warm maintenance accent
```

Avoid: - car silhouette clip art; - wrench + car cliché; - racing
flag; - speedometer; - VW-like geometry; - letter `A`; - text; - fine
mechanical detail.

Apple's app-icon guidance favors simplicity and recognition; fine detail
becomes hard to read at small sizes.

## P0 icon variants to design

1.  **Primary --- Calm Blue**
2.  **Soft Graphite**
3.  **Warm Garage**

The primary icon is selected before the next dogfood build.

## Alternate app icons

iOS supports alternate app icon sets and runtime switching through
`setAlternateIconName`.

P1 product capability:

``` text
Settings
→ App Icon
→ Default
→ Graphite
→ Warm
```

Do not auto-switch icon by vehicle make.

## Vehicle-make icon hypothesis

Interesting, but risky.

Problems: - trademark/brand usage; - false implication of manufacturer
affiliation; - exploding asset matrix; - the app identity disappears; -
multi-car future conflicts.

Rejected for P1:

``` text
Volkswagen icon
BMW icon
Audi icon
...
```

## Better future hypothesis

Vehicle-inspired accent icons:

``` text
Ocean
Graphite
Forest
Warm
```

The user selects a mood/accent, potentially suggested from their
car/photo later.

No manufacturer logos.

## Metrics

Track only if icon selection ships:

``` text
app_icon_picker_opened
app_icon_changed
```

Parameters:

``` text
icon_variant = default | graphite | warm
```

No vehicle make in event.

## Acceptance criteria

-   no Volkswagen mark/color dependency;
-   recognizable at Home Screen size;
-   works with current iOS icon rendering/treatments;
-   no text/fine detail;
-   primary icon visible in next dogfood build;
-   alternate icon architecture is documented but not required to block
    core product work.

## Task

`ICON-001 — Replace Arteon A icon with PitStop primary icon`

This is a small product-identity task and should not wait for the full
design-system migration.
