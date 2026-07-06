# Pit Behavior and Motion Specification

**Status:** P0 product hypothesis

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
