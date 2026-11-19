# Design for Memory Matching Game

## Features to Implement
A Memory Matching Game inside a Salesforce Experience Cloud portal. Authenticated portal users flip cards two at a time to find matching pairs, finish a game, earn a server-validated score, and see their own stats and a per-game leaderboard. Administrators configure games, cards, and scoring through standard Salesforce UI.

Scope (confirmed in interview): full spec sections 2–10 of the use case. Section 11 (difficulty levels, themes, daily challenges, multiplayer, etc.) is deferred; the data model keeps `Game__c` as the extension point.

## Source
- Use case: `Use Case.docx` (Memory Matching Game), attached by the user.
- No ticket was named; `.slalom/ticketing.json` is absent, so no ticket retrieval was run.
- Branch: `feature/memory-matching-game` from `main`.

## Technical Notes

### Findings
| Fact | Source | Checked at (UTC) | Confidence |
|---|---|---|---|
| Org `Hackaton2026Org` is connected, API 68.0, `https://orgfarm-eda6c23bba-dev-ed.develop.my.salesforce.com` | `sf org display` | 2026-11-18T01:44Z | high |
| `Network` (Experience Cloud) is not queryable; Experience Cloud appears not enabled | `sf data query ... FROM Network` returned "sObject type 'Network' is not supported" | 2026-11-18T01:44Z | medium-high |
| No custom objects, Apex, LWC, or Experience sites in `force-app/main/default` | `architecture/architecture.md`, local tree | 2026-11-18 | high |
| `sfdx-project.json` `sourceApiVersion` is 67.0; org runs 68.0 | `sfdx-project.json`, org display | 2026-11-18 | high |
| Standard Contact has no Nickname field (decision: not used; name = first name + last initial) | interview | 2026-11-18 | high |

### Assumptions
| Assumption | Consequence if wrong | Verification / owner |
|---|---|---|
| Developer Edition org has (or can be given) Experience Cloud and a Customer Community / Customer Community Plus license for players | Players cannot log in; the feature cannot be used through the portal | Check in Setup (Digital Experiences, Company Information licenses) before Phase 7. Owner: user |
| Enabling Digital Experiences and creating the site cannot be completed purely through metadata deployment in this org | Site step becomes manual | Attempt `DigitalExperienceSettings`/`Network` deploy in Phase 7; fall back to documented Setup steps. Owner: user confirms |
| Each `Pair_Identifier__c` has exactly two active `Game_Card__c` records | A pair with a different count is excluded from the board and the admin sees a validation error on start | Enforced in Apex at session start |
| The client (LWC) can see the card layout (pair keys) at game start | A player could read the layout in browser devtools and play optimally; scores stay server-validated, but the layout is not secret | Accepted trade-off for a client-side matching game; document in the portal instructions |
| API version 68.0 is used for new metadata | Using 67.0 (`sfdx-project.json`) would still deploy but miss newer behavior | Use 68.0 to match the org; the project rule says "latest" |

### Resolved decisions
| Decision | Rationale | Date (UTC) |
|---|---|---|
| Build full spec sections 2–10; defer section 11 | User selected `full_minus_future` | 2026-11-18 |
| Enable/create Experience Cloud by automation attempt (fall back to manual Setup) | User chose `enable_for_me`; feasibility is verified in Phase 7 | 2026-11-18 |
| Result validation: server stores the board layout; client submits its flip sequence; server replays flips and computes the score | Spec requires server-side score validation; replay prevents client-chosen scores. The interview answer was empty, so the recommended default is recorded here | 2026-11-18 |
| Leaderboard computed from completed `Game_Session__c` records; no `Game_Leaderboard__c` | User selected `computed_from_sessions`; avoids duplicate data | 2026-11-18 |
| Leaderboard is per game; each player appears once with their best completed score | Scores from different game configurations are not comparable | 2026-11-18 |
| Player display name = first name + last initial (`Contact.FirstName` + `LastName` initial) | User selected `first_name_last_initial_only` | 2026-11-18 |
| Scoring fields on `Game__c`; add `Time_Penalty_Interval_Seconds__c` (default 5) | Spec puts scoring rules on configuration; the 5-second interval was missing | 2026-11-18 |
| `Maximum_Time__c` = time limit in seconds; 0 = no limit; exceeding it marks the session Abandoned with score 0 | User selected `time_limit_seconds` | 2026-11-18 |
| Card images: `Image_URL__c` with emoji fallback from `Display_Symbol__c` | User selected `url_with_emoji_fallback` | 2026-11-18 |
| No Flow in this build; completion is handled in Apex | User selected `no_flow` | 2026-11-18 |
| No custom Contact field; no required custom fields | Keeps Permission Set field grants valid (required fields cannot have field permissions) | 2026-11-18 |
| Players are Experience users linked to a `Contact` via `User.ContactId`; guest users are rejected | Spec requires authenticated users; Player__c is a Contact lookup | 2026-11-18 |
| `Game_Session__c` OWD = Private; owner = the player; players have Read only and no Edit on score fields; all writes happen in Apex | Spec: users cannot see others' sessions or change scores | 2026-11-18 |

### Open questions
| Question | Recommended answer | Needed by |
|---|---|---|
| Does the org have a Customer Community (or Plus) license available for portal players? | Yes; confirm in Setup | Phase 7 (deploy) |
| Should the player be able to restart mid-game without the attempt being recorded as Abandoned? | Restart marks the current session Abandoned and starts a new one (spec: restart resets game state) | Phase 4 (build) |

## Architecture

### Data model
**Game__c** (custom object)
| Field | Type | Notes |
|---|---|---|
| Name | Auto/Text (standard) | Game name |
| Description__c | Long Text Area | How-to-play copy shown on home screen |
| Is_Active__c | Checkbox | Default false |
| Number_of_Pairs__c | Number(2,0) | 2–18; validated in Apex |
| Maximum_Time__c | Number(6,0) | Seconds; 0 = no limit |
| Base_Score__c | Number(6,0) | Default 1000 |
| Move_Penalty__c | Number(4,0) | Default 10 per move beyond Number_of_Pairs |
| Time_Penalty__c | Number(4,0) | Default 2 per interval |
| Time_Penalty_Interval_Seconds__c | Number(4,0) | Default 5 |
| Completion_Bonus__c | Number(4,0) | Default 100 |

**Game_Card__c** (custom object)
| Field | Type | Notes |
|---|---|---|
| Name | Text (standard) | Card label |
| Game__c | Lookup(Game__c) | Optional; relationship name `Game_Cards` |
| Pair_Identifier__c | Text(50) | Two cards with the same identifier form a pair |
| Image_URL__c | URL | Optional |
| Display_Symbol__c | Text(10) | Emoji/symbol fallback when Image_URL__c is blank |
| Is_Active__c | Checkbox | Default true |

**Game_Session__c** (custom object)
| Field | Type | Notes |
|---|---|---|
| Name | Auto Number `GS-{0000}` | |
| Game__c | Lookup(Game__c) | |
| Player__c | Lookup(Contact) | Player's Contact |
| Start_Date__c | DateTime | Set when the session starts |
| Completion_Date__c | DateTime | Set on completion or abandonment |
| Duration_Seconds__c | Number(6,0) | Validated client-reported elapsed time |
| Total_Moves__c | Number(4,0) | Attempts (pairs of flips) |
| Matched_Pairs__c | Number(2,0) | |
| Final_Score__c | Number(6,0) | Server-calculated only |
| Status__c | Picklist | In Progress, Completed, Abandoned |
| Card_Layout__c | Long Text Area | Server-only JSON: ordered pair keys per board position |

`Card_Layout__c` is server-only: it's read in Apex during submission and never placed in a field the player can see; the player's permission set does not grant read on it.

Owner of each `Game_Session__c` = the portal user. OWD = Private.

### Apex
| Class | Sharing | Responsibility |
|---|---|---|
| `MemoryGameController` | `with sharing` | `@AuraEnabled` entry points: `getActiveGames`, `startSession`, `submitSession`, `abandonSession`, `getPlayerStats`, `getLeaderboard`. Maps DTOs; no scoring logic. |
| `MemoryGameService` | `with sharing` | Current-user contact resolution; pair selection and shuffle; layout storage; replay validation; `calculateScore` (public static, pure); completion and abandonment. |
| `MemoryLeaderboardService` | `without sharing` | Read-only aggregated query on completed sessions for one game; returns best score per player, top N, and the requesting player's rank. Exposes only display name, score, duration, moves. |
| `MemoryGameServiceTest` | `@isTest` | Scoring formula (includes the spec example = 944), replay validation (match, mismatch, duplicates, duplicate submission), time limit. |
| `MemoryGameControllerTest` | `@isTest` | Guest/no-contact rejection, start-session layout size, leaderboard and stats shape. |

Scoring (`calculateScore`):
- `extraMoves = max(0, moves - numberOfPairs)`
- `timePenalty = floor(duration / interval) * timePenaltyPerInterval`
- `score = max(0, base - extraMoves * movePenalty - timePenalty + bonus)`
- Example: 8 pairs, 20 moves, 90 s → 1000 − 120 − 36 + 100 = 944.

Submission flow (`submitSession`):
1. Resolve current user's Contact; reject guests and users without a Contact.
2. `SELECT ... FROM Game_Session__c WHERE Id = :sessionId AND Player__c = :contactId FOR UPDATE` (sharing enforced). Reject if not found or Status ≠ In Progress (duplicate submission protection).
3. Load `Game__c` scoring config from the server (never from the client).
4. Validate client-reported duration: must be ≤ server elapsed time (now − Start_Date__c) + 10 s grace, and ≥ 0.
5. If `Maximum_Time__c > 0` and duration > limit → Status Abandoned, score 0.
6. Replay attempts against `Card_Layout__c`: positions must be distinct and in range; a match marks both positions matched; a flip of an already matched position is rejected. Require all pairs matched at the end.
7. Set Status Completed, Total_Moves, Matched_Pairs, Duration, Completion_Date, Final_Score; return score breakdown.

### Lightning Web Components (Experience Cloud)
| Component | Role |
|---|---|
| `memoryGameApp` | Container and state machine (home → playing → complete). Exposed to Experience Cloud pages. Shows loading and friendly error states. |
| `memoryGameHome` | Title, how-to-play, Start, personal best, games played/completed, leaderboard entry. |
| `memoryGameBoard` | Header (timer, moves, matched/total, Restart, Exit) and responsive grid. Client-side matching (2 cards max, 1 s mismatch delay, input lock during evaluation, no re-selecting matched or same card, timer starts on first flip, stops on completion). |
| `memoryCard` | Single card: flip animation (CSS 3D transform), image/symbol face, matched styling. |
| `memoryGameComplete` | Time, moves, final score, personal-best indicator, Play Again, Return Home. |
| `memoryLeaderboard` | Tabs: Top 10 / All / My rank. |
| `memoryGameEngine` | Plain JS module (no template): board state, match evaluation, timer formatting, score breakdown display. Jest-testable. |

Apex calls are limited to start, submit, abandon, and home/leaderboard loads; no Apex during flips.

Duplicate-submission protection: the client disables the submit action after the first call; the server enforces it with the Status check above under `FOR UPDATE`.

### Security
- Players: object permissions Read on `Game__c`, `Game_Card__c`, `Game_Session__c`; no Edit/Create on `Game_Session__c` (all writes via Apex); no read on `Card_Layout__c`; `Final_Score__c` read-only.
- Admins: System Administrator profile or a `Memory_Game_Admin` Permission Set with CRUD on the three objects and all fields.
- Experience Cloud site: Memory game page is available to authenticated Customer users only (guest access off).

## Metadata to Create/Modify and the order to create them
- Objects: `Game__c`, `Game_Card__c`, `Game_Session__c`
- Fields: as listed in the data model above (all optional, no required custom fields; Game_Session__c Name is an auto-number)
- Apex Classes: `MemoryGameController`, `MemoryGameService`, `MemoryLeaderboardService`, `MemoryGameServiceTest`, `MemoryGameControllerTest`
- Lightning Web Components: `memoryGameApp`, `memoryGameHome`, `memoryGameBoard`, `memoryCard`, `memoryGameComplete`, `memoryLeaderboard`, `memoryGameEngine` (module)
- Permission Sets: `Memory_Game_Player`, `Memory_Game_Admin`
- Data: `scripts/apex/seed-memory-game.apex` (sample game with 8 pairs and card data; not deployed metadata)
- Deployment package: `specs/memory-matching-game/memory-matching-game-package.xml` (deploy scope only)

Creation order: objects → fields → Apex classes (service, leaderboard, controller, tests) → LWC (engine, card, board, complete, leaderboard, home, app) → permission sets → package.xml.

## UI/UX Notes
No mockups were attached; the use case's UI section is the source of truth.
- Home: title, how-to-play, Start Game, personal stats, leaderboard entry.
- Game: header row (timer, moves, matched/total, Restart, Exit) above a responsive CSS grid (for example 4 columns on desktop, 3 on tablet, 2 on mobile).
- Cards: rounded corners, subtle shadow, 3D flip animation, emoji or image face, clear match highlight.
- Errors: friendly messages; spinners scoped to content regions (not whole template).
- Styling: SLDS utilities where practical; custom CSS only for card flip and grid.

## Steps to Implement Features
- [ ] Step 1: Create `Game__c`, `Game_Card__c`, `Game_Session__c` objects and their fields (API 68.0).
- [ ] Step 2: Write `MemoryGameService` (pair selection, shuffle, layout storage, replay validation, `calculateScore`, completion/abandonment) and its `.cls-meta.xml`.
- [ ] Step 3: Write `MemoryLeaderboardService` (without sharing, aggregated, top N, rank) and `.cls-meta.xml`.
- [ ] Step 4: Write `MemoryGameController` (`@AuraEnabled` entry points, guest and no-contact rejection) and `.cls-meta.xml`.
- [ ] Step 5: Write `MemoryGameServiceTest` and `MemoryGameControllerTest`. Run them after deploying tests (per project rule).
- [ ] Step 6: Build `memoryGameEngine` module and its `.js-meta.xml` (client-side matching rules, timer, score display).
- [ ] Step 7: Build `memoryCard` (flip animation) and `memoryGameBoard` (header, grid, input lock, 1 s mismatch delay).
- [ ] Step 8: Build `memoryGameComplete`, `memoryLeaderboard`, `memoryGameHome`, and `memoryGameApp` with their `.js-meta.xml` files; expose `memoryGameApp` to Experience Cloud pages.
- [ ] Step 9: Create `Memory_Game_Player` and `Memory_Game_Admin` Permission Sets and assign the player set to the test user (access review per create-metadata permissions guide).
- [ ] Step 10: Create the seed script `scripts/apex/seed-memory-game.apex` with one active 8-pair game and 16 cards.
- [ ] Step 11: Create `memory-matching-game-package.xml` and deploy to `Hackaton2026Org`.
- [ ] Step 12: Attempt Experience Cloud enablement and site creation via deployment. If blocked, document manual Setup steps and the publishing checklist (site, members, page, guest access off).
- [ ] Step 13: Verify end to end in the org: start, flip, match, complete, submit, duplicate submit rejected, time limit, leaderboard, stats, and a second user cannot read the first user's session.
