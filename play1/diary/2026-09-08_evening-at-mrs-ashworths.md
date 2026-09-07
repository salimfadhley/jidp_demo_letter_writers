# Development Diary Entry - 2026-09-08

## Context
- **Date**: 2026-09-08 00:10 UTC
- **Branch**: master
- **Contributors**: Claude Code + User

## Problem Statement
A second demo beside `letters1/`: the same characters in one room at an evening party, speaking beats (a line plus a stage action) rather than writing letters, with each character playing a UCB-style "game", output as a screenplay. The user chose the games interactively: everything is a sign (Helena), never the jealous man (Pembroke), the convenient impression (Clara), the connoisseur of fraud (Strake), the introducer (Mrs. Ashworth). A sixth character, modelled on Lucky in *Waiting for Godot*, appears once mid-play with a near-meaningless monologue that affects everyone; his game is disruption.

## Our Approach
Reuse the letters1 pattern: one Jido agent per character with private state, two actions (take a beat, hear a beat), a director that is camera and postmaster only. The game is state (premise, ladder, rung, last move) and the discipline (no heighten twice running, one rung per heighten) is enforced in `TakeBeat`, not merely requested in the prompt. One conversation is on camera at a time; the curtain rises on two, others join on a schedule, people may withdraw or leave with any beat. The interlude gathers everyone for the monologue and four reaction beats.

## Implementation
Beat struct, Room (pure), Cast with warm relationships (everyone likes everyone), Prompts (own state only, aware of who is present and who is out of earshot), Stage, Report in screenplay columns, stub with fixed choices, 16 tests.

## Outcomes
- First cut had arrivals at the door and a roving camera over several groups; the user then asked for one room, one conversation at a time, opening on two people, so the director was rewritten around a single focus and scheduled joins.
- "Cocktail party" is anachronistic for 1891; staged as an evening at home with champagne cup, claret cup and ices.

## Next Steps
- First real performance; keep it under `plays/`.
- Consider letting off-camera characters decide for themselves whether to join.
