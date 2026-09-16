# Pit Behavior and Motion Specification

**Status:** P0 product hypothesis

Core: P1, P2, P3, P5, C2, C3

## Role

Pit is a persistent helper.

Pit helps with:
1. capture;
2. clarification;
3. progressive discovery.

Pit is not:
- navigation;
- a chat tab;
- the only input mechanism;
- a generic AI assistant;
- an AI mechanic by default;
- a source of unsolicited technical advice.

The app remains useful without Pit.

## Personality contract

Pit is simple, tactful, brief, and restrained.

Internal rules:

> Pit speaks briefly.  
> Pit reacts before he explains.  
> Pit asks one thing at a time.  
> Pit never pretends to know what he does not know.  
> Pit uses restrained situational humour.  
> Pit does not evaluate the user.  
> Pit accepts silence.  
> Pit disappears when his job is done.

Avoid:
- “I respect that”;
- “good job”;
- “nice one”;
- “bro”;
- praise after ordinary answers;
- forced familiarity;
- jokes on every interaction.

Pit may use rare situational humour. Never joke about safety or serious failures.

## Visual hypothesis

**Pit Eyes / Behind the UI.**

The eyes are the character.

Pit has no required body, mouth, hands, or mechanic costume.

Pit visually lives behind the interface.

> Pit waits nearby.

Behavioural metaphor:

> Pit is sitting on a bench, quietly waiting. Sometimes he looks around. When he remembers something useful, he perks up and gently knocks.

## Availability

Pit is persistent on primary and detail screens in the bottom-trailing utility position.

Pit may hide visual detail when inactive but the affordance remains discoverable and reachable.

Pit is not a tab.

## Motion language

Motion is semantic.

| State/action | Meaning |
|---|---|
| hidden | not visually active |
| resting | available and waiting |
| blink | alive / idle |
| double blink | rare natural variation |
| look left/right | idle observation |
| look up | idle wandering thought |
| glance at object | noticed UI context |
| fixed gaze | listening |
| side gaze | thinking |
| startle | remembered something |
| knock | requests permission to interrupt |
| close eyes | completion / leaving |

Blink is the baseline idle action.

## Idle policy

Do not use a fixed “every N seconds” animation timer.

Use irregular weighted scheduling with cooldowns.

A normal session may contain no visible idle animation.

Idle motion must stop or reduce during:
- fast scrolling;
- text editing;
- active capture;
- focused modal tasks;
- Reduce Motion;
- recent Pit dismissal.

Pit generally blinks less while listening.

Candidate transition after voice input:

```text
fixed gaze → blink → side gaze → proposal
```

## Attention policy

> Pit may look alive without permission. Pit may interrupt only for measurable value.

A Pit question requires:
- idle UI;
- relevant current context;
- a high-value unresolved question;
- answer unlocks defined behaviour/value;
- cooldown compliance;
- no recent dismissal.

Example:

Known:
- current mileage;
- last oil change.

Unknown:
- user's oil interval.

If the interval changes Service/Road behaviour:

```text
resting → startle → knock
```

Pit:

> Кстати. Масло через сколько обычно меняешь?

Choices:

```text
5 000
7 500
10 000
Не знаю
```

This is in-app behaviour. It is not a push notification.

## Interruption budget

Exact values require investigation.

The implementation must model:
- last interruption time;
- last dismissal time;
- question identity;
- question priority;
- context;
- answered/deferred state.

Do not repeatedly ask the same deferred question.

## Capture

Tapping Pit opens the Pit Capture Surface.

Primary capability: Remember.

Voice may be prominent but cannot be mandatory.

Pit may:
- listen;
- show interpretation;
- ask one clarification;
- confirm completion;
- preserve raw input.

Pit must not trap the user in chat history.

## Accessibility

Reduce Motion:
- remove idle wandering motion;
- replace startle/knock with restrained state change;
- preserve affordance and semantic labels.

VoiceOver:
- Pit control has a clear action label;
- motion states are not continuously announced;
- interruption questions use normal accessible controls.

## Analytics questions

- Is Pit used for capture?
- Are Pit questions answered, deferred, or dismissed?
- Does a Pit answer unlock Road/Service value?
- Does idle motion correlate with dismissal or reduced engagement?
- How often does Pit need clarification?
- How often is raw capture preserved?

Never log raw speech or note text.

## Test-first scenarios

1. Pit remains reachable on primary/detail screens;
2. app navigation works without Pit;
3. fixed interval idle animation is absent;
4. interruption blocked during editing;
5. interruption blocked after dismissal cooldown;
6. deferred question is not immediately repeated;
7. question requires declared value unlock;
8. Reduce Motion removes idle wandering;
9. AI unavailable preserves capture path;
10. one clarification at a time.

## Failure criteria

- Pit becomes navigation;
- Pit behaves like a chatbot tab;
- Pit praises ordinary user answers;
- idle animation is constant;
- Pit interrupts without value;
- Pit repeatedly asks deferred questions;
- Pit claims technical certainty without evidence.

## Requirements

Status `proposed` means derived from the contract text above and awaiting owner approval.

### REQ-PIT-001 — App navigation works without Pit
Status: proposed
Core: P3
Source: [Role](#role), [Availability](#availability), [Test-first scenarios](#test-first-scenarios), [Failure criteria](#failure-criteria)
Given the user never interacts with Pit
When the user moves between primary and detail screens
Then every screen is reachable through non-Pit controls

### REQ-PIT-002 — Pit does not present unknown facts as known
Status: proposed
Core: C2
Source: [Personality contract](#personality-contract), [Failure criteria](#failure-criteria)
Given a car fact that the user has not supplied or confirmed and deterministic logic has not derived
When Pit shows an interpretation, question, or confirmation involving that fact
Then Pit does not state the fact as known or claim technical certainty about it

### REQ-PIT-003 — One clarification at a time
Status: proposed
Core: C3
Source: [Personality contract](#personality-contract), [Capture](#capture), [Test-first scenarios](#test-first-scenarios)
Given Pit has more than one open clarification for the current capture or context
When Pit asks the user
Then only one question is presented, and the next is not shown until the current one is answered, deferred, or dismissed

### REQ-PIT-004 — Idle motion has no fixed interval
Status: proposed
Core: P5
Source: [Idle policy](#idle-policy), [Test-first scenarios](#test-first-scenarios), [Failure criteria](#failure-criteria)
Given Pit is resting and idle motion is allowed
When the idle scheduler produces idle actions over a session
Then the actions are chosen by irregular weighted scheduling with cooldowns, not by a fixed repeating timer, and idle animation is never constant

### REQ-PIT-005 — Idle motion yields to user activity
Status: proposed
Core: P5
Source: [Idle policy](#idle-policy)
Given the user is fast scrolling, editing text, actively capturing, in a focused modal task, or has recently dismissed Pit
When an idle action would otherwise be scheduled
Then idle motion is stopped or reduced

### REQ-PIT-006 — Questions require idle UI
Status: proposed
Core: C3
Source: [Attention policy](#attention-policy), [Test-first scenarios](#test-first-scenarios)
Given the UI is not idle, for example the user is editing text
When a Pit question is otherwise eligible
Then Pit does not interrupt with the question

### REQ-PIT-007 — Questions require relevant current context
Status: proposed
Core: C3
Source: [Attention policy](#attention-policy)
Given a pending Pit question whose context does not match the current screen context
When Pit evaluates whether to interrupt
Then the question is not asked

### REQ-PIT-008 — Only unresolved questions are asked
Status: proposed
Core: C3
Source: [Attention policy](#attention-policy), [Interruption budget](#interruption-budget)
Given a Pit question that the user has already answered
When Pit evaluates whether to interrupt
Then that question is not asked again

### REQ-PIT-009 — Questions require a declared value unlock
Status: proposed
Core: C3
Source: [Attention policy](#attention-policy), [Test-first scenarios](#test-first-scenarios), [Failure criteria](#failure-criteria)
Given a Pit question with no declared behaviour or value that its answer unlocks
When Pit evaluates whether to interrupt
Then the question is not asked

### REQ-PIT-010 — Interruption and dismissal cooldowns
Status: proposed
Core: C3
Source: [Attention policy](#attention-policy), [Interruption budget](#interruption-budget), [Test-first scenarios](#test-first-scenarios)
Given the last Pit interruption or the last Pit dismissal is within its cooldown
When a Pit question is otherwise eligible
Then Pit does not interrupt until the cooldown has passed

### REQ-PIT-011 — Questions are in-app, not push notifications
Status: proposed
Core: C3
Source: [Attention policy](#attention-policy)
Given a Pit question becomes eligible
When Pit asks it
Then the question appears inside the app and no push notification is scheduled for it

### REQ-PIT-012 — Deferred questions are not repeated
Status: proposed
Core: C3
Source: [Interruption budget](#interruption-budget), [Test-first scenarios](#test-first-scenarios), [Failure criteria](#failure-criteria)
Given the user deferred a Pit question
When Pit next evaluates questions
Then the same deferred question is not immediately or repeatedly asked again

### REQ-PIT-013 — Tapping Pit opens the capture surface
Status: proposed
Core: P3
Source: [Capture](#capture)
Given Pit is visible on a primary or detail screen
When the user taps Pit
Then the Pit Capture Surface opens with Remember as its primary capability

### REQ-PIT-014 — Voice is not mandatory for capture
Status: proposed
Core: P2
Source: [Capture](#capture)
Given the Pit Capture Surface is open and voice input is not used or not available
When the user enters a thought without voice
Then the thought can be captured

### REQ-PIT-015 — Raw capture input is preserved
Status: proposed
Core: P1
Source: [Capture](#capture)
Given the user submits input through the Pit Capture Surface
When Pit interprets, clarifies, or confirms it
Then the raw input is preserved unchanged

### REQ-PIT-016 — Capture works without AI
Status: proposed
Core: P3
Source: [Role](#role), [Test-first scenarios](#test-first-scenarios)
Given AI is unavailable
When the user captures a thought through Pit
Then the capture path completes and the thought is saved

### REQ-PIT-017 — Reduce Motion removes idle wandering
Status: proposed
Core: P5
Source: [Idle policy](#idle-policy), [Accessibility](#accessibility), [Test-first scenarios](#test-first-scenarios)
Given Reduce Motion is enabled
When Pit is resting or idle
Then no idle wandering motion is shown

### REQ-PIT-018 — Reduce Motion replaces startle and knock
Status: proposed
Core: P5
Source: [Accessibility](#accessibility)
Given Reduce Motion is enabled
When Pit would startle or knock to request attention
Then a restrained state change is shown instead of the startle or knock motion

### REQ-PIT-019 — Motion states are not continuously announced
Status: proposed
Core: P5
Source: [Accessibility](#accessibility)
Given VoiceOver is running
When Pit changes motion state
Then the motion state change is not continuously announced

### REQ-PIT-020 — Interruption questions use accessible controls
Status: proposed
Core: P5
Source: [Accessibility](#accessibility)
Given VoiceOver is running
When Pit presents an interruption question with choices
Then the question and each choice are exposed as normal accessible controls
