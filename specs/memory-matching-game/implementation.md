# Implementation Evidence: Memory Matching Game

## Scope
Spec sections 2–10 from the requirements document. Difficulty levels, themes, daily challenges, and multiplayer (section 11) are deferred.

## Source Increments and Verification

| Increment | Files | Verification |
|---|---|---|
| Data model | `force-app/main/default/objects/{Game__c,Game_Card__c,Game_Session__c}` | Check-only deploy succeeded (37/37 components with Apex and LWC) |
| Apex services and controller | `force-app/main/default/classes/MemoryGameService.cls`, `MemoryLeaderboardService.cls`, `MemoryGameController.cls` (+ meta) | Included in check-only deploy above |
| LWC layer | `force-app/main/default/lwc/{memoryGameApp,memoryGameHome,memoryGameBoard,memoryCard,memoryGameComplete,memoryLeaderboard,memoryGameEngine}` | Included in check-only deploy above; no template errors reported. Runtime behavior not yet tested. |
| Permission sets | `force-app/main/default/permissionsets/{Memory_Game_Player,Memory_Game_Admin}.permissionset-meta.xml` | Check-only deploy succeeded after fixing `viewAllRecords`/`modifyAllRecords` tag names (44/44 components) |
| Seed script | `scripts/apex/seed-memory-game.apex` | Not yet run |
| Manifest | `specs/memory-matching-game/memory-matching-game-package.xml` (API 68.0) | Used for the dry-run equivalent; not yet run as a manifest |

## Deploy and Test Evidence
- Target: `Hackaton2026Org` (API 68.0). Deployed with `NoTestRun`: 40 components, 0 errors.
- Field-level security fix: `Memory_Game_Admin` now grants read and edit on every custom field. Before the fix, describe and Apex compile hid `Game__c` fields from the running admin user, and all test setup failed.
- Apex test run `MemoryGameServiceTest`: 11 of 11 pass (10 planned cases plus one controller wiring case).
- Coverage: `MemoryGameService` 86%, `MemoryLeaderboardService` 98%, `MemoryGameController` 47%. Org-wide 69%, mostly from pre-existing Site and password classes outside this feature.
- Root cause of the earlier test failures: `AuraHandledException.getMessage()` returns "Script-thrown exception" outside Aura context unless `setMessage` is called. All service errors now go through `userError`.
- Note: `sfdx-project.json` `sourceApiVersion` is 67.0 while the org and new metadata use 68.0.

## Pending Checks
- Jest tests for `memoryGameEngine`: not selected.
- Run the seed script in the org (`sf apex run --file scripts/apex/seed-memory-game.apex --target-org Hackaton2026Org`).
- Assign `Memory_Game_Player` (and `Memory_Game_Admin` for administrators) to users.
- Add the `memoryGameApp` component to an Experience Cloud page. Verify whether Experience Cloud (Network) is enabled first.
- End-to-end checks: start, flip, mismatch, match, completion, timeout, restart, leaderboard, and cross-user isolation.
- Confirm the score for the reference scenario (8 pairs, 20 moves, 90 s) equals 944.

## Open Items
- API version conflict: `sfdx-project.json` says 67.0; the project rule says 66; the org uses 68.0.
- Result validation default B was recorded from an empty answer. Confirm it.
- The docx mentions `Game_Leaderboard__c` and `Description`. The design computes the leaderboard from completed sessions and uses `Description__c`.
- Accepted trade-off: the client receives pair keys at start, so a player could read the layout in devtools. Scores remain server-validated.
