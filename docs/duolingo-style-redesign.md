# takt: Duolingo-Style Redesign — Design Document

**Status:** All phases (1–6) implemented 2026-08-02 — see §10.
**Scope:** Gamification loop, skill-tree curriculum, multi-device sync hardening, responsive layout (fold / phone / tablet / desktop).

---

## 1. Goals

1. Turn the existing streak/SRS foundation into a full Duolingo-style loop: XP, hearts/lives, streak freezes, a daily word goal, and a skill-tree lesson path.
2. Keep the current pull-based sync model, but harden auth so gamification state (XP, hearts, streak freezes) survives across devices reliably.
3. Make every screen work well on four form factors: phone (compact), foldable (both folded and unfolded), tablet, and desktop.

## 2. Current State (verified against the codebase)

This matters because two assumptions are easy to get wrong:

- **There is no curriculum/unit model today.** `LessonService` is misleadingly named — it manages imported articles and processed videos (media immersion content), not lessons or exercises. A skill-tree needs a brand-new data model and service, not a repurposing of `LessonService`.
- **XP is cosmetic, not a currency.** `ProfileService.calculateTotalXp()` computes a display number on the fly from streak length, saved-word count, and review count (`150 + streak*50 + words*25 + activeDays*40 + reviews*10`). It isn't stored, isn't earned per-action, and nothing spends it. A real gamification loop needs XP to be an event-sourced, persisted value.
- **Spaced repetition is already correct.** `SavedWord.calculateNextReview()` implements SM-2 properly (interval, ease factor, repetitions). Don't reinvent this — surface it inside the new loop instead.
- **Streaks exist but nothing protects them.** `ProfileService` computes `currentStreak` from activity dates and tracks `bestStreak`, but there's no streak-freeze inventory or grace mechanic.
- **Responsive layout has exactly one breakpoint.** `main_scaffold.dart` switches at `screenWidth > 800` (bottom nav → nav rail) and `>= 900` (rail → extended rail). Nothing accounts for foldable hinges, and inner screens (practice screens, dictionary, video player) don't reflow for wide layouts — they just stretch.
- **Auth is too weak to trust for cross-device state.** Passwords are unsalted SHA-256; session tokens are deterministic (`token_{user_id}_{sha256(username)[:10]}`), never expire, and can't be revoked. Before gamification state becomes something users care about not losing, this needs fixing — see §6.

## 3. Gamification System

### 3.1 XP & Levels
- New model: `XpEvent { id, userId, source, amount, timestamp }`. Sources: `exercise_correct` (+10), `lesson_complete` (+25 bonus), `daily_goal_met` (+20), `review_completed` (+5 per SRS review), `streak_milestone` (+50 at 7/30/100 days).
- `ProfileService` gains a persisted `totalXp` counter derived from summed events (cached, not recomputed from unrelated stats like it is today), plus a level curve (e.g. `level = floor(sqrt(totalXp / 100))`) shown on the profile screen.
- XP events sync to the backend as an append-only log so merges across devices are additive, not last-write-wins (see §6).

### 3.2 No Hearts / Lives (rejected)
**Decision (2026-08-02): hearts/lives are cut from scope entirely.** Practice is unlimited — users should never be blocked from exercising by a depleted resource or a wait timer. This is a deliberate divergence from Duolingo, not an oversight: the app's dual identity (immersion + drills) is better served by removing friction from the drill side than by gating it.
- Wrong answers in the four practice screens still matter for learning signal (they affect SM-2 scheduling per §3.5, and can reduce/withhold the per-question XP award in §3.1) but never end a session early or lock the user out.
- This removes `HeartsState`, the hearts sync payload field, and the hearts indicator widget from everything below — see §8/§9 for the resulting file-list changes.

### 3.3 Streak Freezes
- New inventory field on `ProfileService`: `streakFreezes: int` (start with 1, earn 1 per 10-day streak milestone, cap at 2).
- On the daily streak-check (already computed in `currentStreak`), if a day was missed and a freeze is available, auto-consume it and preserve the streak instead of resetting to 0. Surface this as a small notification/banner ("Streak Freeze used!") on next open.

### 3.4 Daily Word Goal ("daily words")
- New: a curated set of N words/day (reuse the existing `/api/dictionary/frequency` backend endpoint, which already supports frequency-ranked, POS-filtered, randomized word sets — no backend work needed here, just a new client flow).
- Home screen gets a "Today's Words" card: N new words (default 5, user-configurable in settings) pulled via that endpoint, saved to vocabulary on tap, feeding directly into the existing SM-2 queue.
- Completing the daily word goal is one of the `dailyGoal` components alongside reviews and story reading (`isDailyGoalAchieved` in `ProfileService` already checks `dailyTasksCompleted >= 3` — extend that counter to include "daily words met").

### 3.5 Tying SRS into the loop
- Add a "Review" node type to the skill-tree (§4) that shows a live badge with the count of SM-2-due words (query already possible via existing `VocabularyService` data). Completing a review batch awards XP per 3.1 and counts toward the daily goal.

## 4. Skill-Tree Lesson Path

### Data model (new)
```
Unit { id, title, order, iconAsset, colorSeed }
LessonNode { id, unitId, order, type: [vocab | gender | compound | sentence | review | story], targetId, xpReward, unlocked, completed }
```
- `type` maps directly to the four existing practice screens plus a `review` node (§3.5) and a `story` node (opens `story_reader_screen.dart` for a specific article).
- Unlock rule: a node unlocks when the previous node in the same unit is completed; a unit unlocks when the prior unit's last node is completed. Keep it linear for v1 — no branching — to match Duolingo's simplicity and avoid over-engineering the graph.
- New service: `CurriculumService extends ChangeNotifier`, following the existing pattern (SharedPreferences-backed locally, synced via the extended `/api/sync` payload).

### Content generation (decided)
**Decision (2026-08-02): generate units/nodes from dictionary frequency data — no hand-authored curriculum.**
- Vocab/gender/compound/sentence nodes: partition the `/api/dictionary/frequency` frequency-ranked word list into fixed-size bands (e.g. 500 words/unit, ordered by rank) and generate one node per practice type per band. No manual curation of which words go in which unit.
- Story nodes: point at existing imported articles (Library content, §4 UI below) rather than newly authored copy — the tree references media that already exists, it doesn't require new stories to be written for it.
- Unit titles/icon/colorSeed can be derived mechanically from the frequency band for v1 (e.g. "Unit 3 · Words 1000–1500"); a hand-named polish pass is optional and non-blocking.
- This removes an open-ended content-authoring workstream from the roadmap entirely — `CurriculumService` can generate the full tree from data the app already has.

### UI
- Replaces the current practice grid inside `discover_screen.dart` (which today mixes mock article data with practice entry points) with a dedicated "Path" tab: a vertically scrolling, gently zig-zagging column of circular lesson nodes (`CustomPainter` for the connecting line — no new package needed), each showing locked/active/completed state and an icon per `type`.
- Tapping an unlocked node pushes the corresponding existing practice screen with the node's `targetId`, and on completion pops back and marks the node done + awards XP.
- Article/video browsing (today's `discover_screen.dart` content) moves to the existing Home tab or a renamed "Library" section — it's immersion content, conceptually separate from the graded path.

## 5. Polish Layer

- **Mascot:** reuse the existing illustration style already in `assets/images/` (cat.png, etc.) rather than commissioning new art — pick or adapt one as a recurring character for empty states, streak-freeze banners, and level-up moments. `flutter_animate` (already a dependency) covers simple entrance/bounce animations without a new package.
- **Sound effects:** add `audioplayers` for short correct/incorrect/level-up cues (2-3 short local asset sounds — respect system mute/silent switch and add a settings toggle, since this app doesn't have sound today).
- **Celebrations:** add `confetti` for streak milestones, level-ups, and unit completion — small, focused package, easy to remove if it doesn't earn its keep.

## 6. Multi-Device Sync & Auth Hardening

Chosen model: **keep pull-based sync** (per your answer), but it needs to survive gamification state without corrupting it across devices. Two changes are required regardless of gamification:

### Auth (should happen before/alongside this work, not after)
- Replace unsalted SHA-256 with `passlib[bcrypt]` (or `argon2-cffi`) server-side.
- Replace deterministic tokens with random session tokens (`secrets.token_urlsafe(32)`), stored in a new `sessions` table (`token, user_id, created_at, expires_at, device_label`), with expiry (e.g. 30 days) and a `DELETE /api/auth/logout` to revoke.
- Client: move the token from `SharedPreferences` to `flutter_secure_storage`.
- Add basic rate limiting on `/api/auth/login` (even a simple in-memory sliding window keyed by IP/username is a big improvement over none).

### Sync payload extension
- Extend `POST/GET /api/sync` (currently `vocabulary`, `articles`, `stats`) with `xp_events` (append-only, dedupe by event id — additive merge, immune to last-write-wins clobbering), `streak_freezes`, and `curriculum_progress`. (No `hearts_state` — hearts are cut from scope, §3.2.)
- Keep the existing merge-by-id pattern for vocabulary/curriculum (already correct in `main.py`'s `post_sync`), but XP specifically should merge as a **union of events**, not a field overwrite — otherwise a device that syncs late can erase XP earned on another device.
- Trigger sync on: app resume, after completing a lesson node, and on a manual pull-to-refresh — no new real-time infrastructure needed per your answer.

## 7. Responsive Layout System

Adopt Material 3's window-size-class breakpoints (well-tested, and Flutter's `MediaQuery.of(context).displayFeatures` natively detects foldable hinges without extra packages):

| Class | Width | Target | Nav pattern |
|---|---|---|---|
| Compact | < 600 | Phone, folded foldable | Bottom nav bar (current mobile behavior) |
| Medium | 600–839 | Unfolded foldable, small tablet (portrait) | Nav rail (icons only) |
| Expanded | 840–1239 | Tablet (landscape), small desktop | Extended nav rail (icons + labels) |
| Large | ≥ 1240 | Desktop | Extended nav rail + secondary content pane (e.g. lesson path + detail side-by-side) |

- New `lib/theme/breakpoints.dart` utility (`WindowClass.of(context)`) replacing the two ad-hoc width checks in `main_scaffold.dart`, used consistently across all screens instead of each screen inventing its own threshold.
- **Foldable-specific:** use `MediaQuery.of(context).displayFeatures` to detect the hinge and avoid placing interactive content (buttons, text fields) across it — particularly relevant in `video_screen.dart` (video + subtitle panel could go side-by-side across the hinge when unfolded) and the new skill-tree path (single column when folded, two-pane path + detail when unfolded/expanded).
- **Practice screens:** currently likely stretch full-width on large screens. Cap exercise card width (~600px) and center it at Medium+ — small, mechanical fix across all four practice screens.
- **Dictionary screen:** at Expanded/Large, split into master-detail (word list left, definition detail right) instead of full-screen navigation push.

## 8. New/Changed Files (concrete)

New:
- `lib/models/xp_event.dart`, `lib/models/curriculum_unit.dart`, `lib/models/lesson_node.dart`
- `lib/services/curriculum_service.dart`, `lib/services/gamification_service.dart` (XP/streak-freezes — separate from `ProfileService` to avoid overloading it further; no hearts, see §3.2)
- `lib/theme/breakpoints.dart`
- `lib/screens/skill_tree_screen.dart`, `lib/widgets/lesson_node_widget.dart`

Changed:
- `lib/screens/main_scaffold.dart` — use `breakpoints.dart`, add Large-class layout
- `lib/screens/discover_screen.dart` — split into Path (new) + Library (existing article/video content)
- `lib/screens/practice/*.dart` (all 4) — capped width on wide screens (no hearts integration, see §3.2)
- `lib/services/profile_service.dart` — persisted XP, streak-freeze consumption logic
- `lib/services/auth_service.dart` — `flutter_secure_storage` instead of `SharedPreferences`
- `backend/main.py` — bcrypt hashing, session table + expiry/logout, extended sync payload, login rate limiting

Renamed:
- `lib/services/lesson_service.dart` → `lib/services/media_library_service.dart`, class `LessonService` → `MediaLibraryService` (decided 2026-08-02, §11). Update all references: `main.dart` provider registration, `home_screen.dart`, `discover_screen.dart`/Library split, and anywhere else `LessonService` is injected via `Provider`/`context.read`/`context.watch`.

## 9. New Dependencies

| Package | Purpose |
|---|---|
| `flutter_secure_storage` | Encrypted auth token storage (fixes existing gap, needed before gamification state is worth protecting) |
| `audioplayers` | SFX for correct/incorrect/level-up |
| `confetti` | Milestone celebrations |
| `passlib[bcrypt]` (backend) | Proper password hashing |

No new state-management or layout framework — Provider and hand-rolled breakpoints stay consistent with the existing architecture.

## 10. Phased Rollout

1. **Foundation (do first, low-risk):** breakpoints utility + `main_scaffold.dart` Large-class support; auth hardening (bcrypt, real sessions, secure storage); `LessonService` → `MediaLibraryService` rename — this de-risks everything after it.
2. **Gamification core (done 2026-08-02):** `XpEvent`/`XpSource` model, `GamificationService` (persisted event log + cached `totalXp` + level curve), streak-freeze inventory and auto-consume-on-missed-day logic in `ProfileService`, XP wired into all 4 practice screens on correct answers and into SRS review completion, streak-milestone (7/30/100) and daily-goal XP triggers, profile screen shows real level/XP instead of the old cosmetic `calculateTotalXp` (now removed). No hearts — cut from scope, §3.2. Local persistence only — sync payload extension is still Phase 5.
3. **Skill tree (done 2026-08-02):** `CurriculumUnit`/`LessonNode` models, `CurriculumService` (generates 10 linear units × 500-word frequency bands = ranks 1–5000, no network call needed since band boundaries are pure rank math; SharedPreferences-backed completed-node set; `unlocked`/`completed` derived, not stored), `SkillTreeScreen` + `LessonNodeWidget` (zig-zag column, `CustomPainter` connector, locked/unlocked/completed states, live due-count badge on Review nodes), `discover_screen.dart` split into "Path" and "Library" tabs via `DefaultTabController` (Library = the screen's prior content, unchanged; import FAB now only shows on Library). Tapping a node pushes the matching practice screen (or, for Story nodes, switches to the Library tab) and on return calls `CurriculumService.completeNode()`, which is idempotent and awards `lesson_complete` XP (+25) via `GamificationService`.
   **Known simplification vs. the original doc text:** nodes don't yet filter each practice screen's word deck down to their specific frequency band — `targetId` carries the band range but the four practice screens still pull from their existing (broader) sources. Wiring real per-band content into each screen is real, separate work per screen (each has its own bespoke deck-loading logic) and wasn't done here; the tree currently provides structure/progression/unlocking over the existing modes, not curated per-node word sets. Also: the doc said this phase "replaces the current practice grid inside `discover_screen.dart`" — that grid doesn't actually exist there (verified against the current codebase); the four practice-module shortcuts are on `home_screen.dart` instead and were left untouched, since removing them wasn't unambiguously part of this ask and doc's own §2 caveat is to verify assumptions like this against the code rather than follow them blindly. `iconAsset` (asset path) from the doc's model became `icon` (`IconData`) since generated units have no real per-unit artwork to reference.
4. **Daily words + polish (done 2026-08-02):**
   - **Daily words:** `ProfileService.dailyWordGoalCount` (persisted, default 5, editable in Settings → Practice & Learning). `TodayWordsCard` on Home fetches `dailyWordGoalCount × 4` candidates from the existing `/api/dictionary/frequency` endpoint (no backend work, confirmed live against production — read-only, no auth), filters out already-saved words client-side, and shows the first N. Tapping a word calls `VocabularyService.upsertWord` + `ProfileService.recordActivityToday(wordSaved: true)`, which was already the mechanism `dailyTasksCompleted`/`isDailyGoalAchieved` used — so this plugs straight into the existing daily-goal check and its `daily_goal_met` XP trigger from Phase 2, exactly as §3.4 asked ("extend that counter").
   - **Sound:** `audioplayers` + a new `SoundService` (persisted mute toggle in Settings, default on). The 3 cues (`correct.wav`/`incorrect.wav`/`level_up.wav`) are synthesized sine-tone WAVs generated with a small stdlib-only Python script (`wave`/`math`, no external deps or commissioned art) rather than sourced audio — a deliberate placeholder, since real sound design wasn't in reach here; swap the 3 files in `assets/sounds/` for anything nicer without touching code. Wired into all 4 practice screens' correct/incorrect hooks and into level-ups.
   - **Celebrations:** `confetti` + a new shared `CelebrationOverlay` wrapping `MainScaffold`, so a level-up or 7/30/100-day streak milestone celebrates (confetti burst + mascot dialog) no matter which tab triggered it — e.g. mid-practice-screen. `GamificationService.justLeveledUp` and `ProfileService.justHitStreakXpMilestone` follow the same ack'd-flag pattern as the Phase 2 streak-freeze banner.
   - **Mascot:** `cat.png` (existing asset, no new art) with a `flutter_animate` elastic entrance, used in the level-up/streak-milestone dialog, the streak-freeze SnackBar, and Today's Words' empty state — the three moments §5 named.
   - **Not done:** confetti on skill-tree unit completion (doc's third celebration trigger) — skipped to keep scope bounded; the shared `CelebrationOverlay` mechanism from this phase makes adding it cheap later.
5. **Sync extension (done 2026-08-02):**
   - `user_sync` gained `xp_events_json`, `streak_freezes`, `curriculum_progress_json`, with a safe `ALTER TABLE`-based migration for tables created before this phase (verified against a seeded pre-Phase-5 schema — existing rows survive untouched).
   - `xp_events`: additive union keyed by event id, exactly as §6 specified — verified with a two-simulated-device pytest (`test_sync_merges_xp_events_and_curriculum_progress_across_devices`): device A pushes, device B (never synced) pulls A's state, device B pushes its own disjoint events, and the final GET contains the union of both with no loss; re-pushing a stale payload doesn't duplicate anything.
   - `curriculum_progress`: sent as a plain `list[str]` of completed node ids (not the `{id, ...}` object shape vocabulary/articles use) — a completed node has no other mutable fields, so a plain string-set union on the server (`set(existing) | set(payload)`) gets the same additive safety without fabricating a `completedAt` timestamp the client doesn't actually track. Merged into `CurriculumService` via `mergeRemoteProgress`.
   - `streak_freezes`: a single int, last-write-wins on the server (same treatment as `stats`) — but the client (`ProfileService.mergeRemoteStreakFreezes`) takes `max(local, remote)` on GET *before* POSTing, so a locally-earned-but-not-yet-pushed freeze can't be clobbered by an older remote value. This wasn't specified in §6 beyond "extend the payload with streak_freezes"; the max-merge is this implementation's choice to keep it consistent with the "immune to last-write-wins clobbering" spirit stated for XP.
   - `GamificationService.mergeRemoteEvents` recomputes `totalXp` from the deduped merged set rather than adding remote's amount on top of local total (which would double-count already-synced events), and deliberately does not trigger the level-up celebration — that's reserved for XP earned live via `awardXp`, not passively merged in from another device.
   - Trigger points added exactly as §6 listed: app resume (`WidgetsBindingObserver` in `MainScaffold`), after completing a lesson node (`CurriculumService.completeNode`), and manual pull-to-refresh (`RefreshIndicator` on Home). The existing vocabulary-change and manual-dialog triggers from before this phase were left in place, not replaced.
   - All new Dart merge methods have unit tests (`gamification_test.dart`, `curriculum_test.dart`) alongside the backend pytest coverage.
6. **Responsive pass over remaining screens (done 2026-08-02):**
   - **Exercise-width capping:** new `lib/widgets/capped_width.dart` (centers content at `maxWidth` from `WindowClass.isAtLeastMedium` up) applied to all 4 practice screens. Verified with a dedicated widget test suite (`capped_width_test.dart`) that measures actual `RenderBox` size at both breakpoints plus a custom-`maxWidth` case — more reliable than eyeballing a screenshot for a pure layout constraint.
   - **Dictionary master-detail:** turned out to already exist in full (word list left, detail right, `_buildDesktopMasterDetailLayout`) — the doc's premise that this needed building was wrong for the current codebase. The actual gap was that it used its own ad-hoc `screenWidth > 800` check instead of the shared breakpoint utility from Phase 1; switched it to `WindowClass.isAtLeastExpanded` (840px) for consistency with the rest of the app. Verified live in-browser at 1400px width — no auth involved, so safe to test against production.
   - **Video/subtitle fold-aware layout:** `video_screen.dart` now detects a vertical hinge via `MediaQuery.displayFeatures` and lays the video out to its left and the transcript to its right (with an empty gap spanning the hinge itself, so no interactive content straddles it), falling back to the existing stacked layout otherwise. Not independently verifiable in this environment — no foldable emulation available — so this rests on correct use of the documented Flutter API and passing analyze/format, not a live check.
   - **Skipped:** the doc's other foldable-specific idea — a two-pane "path + detail" layout for the skill tree when unfolded — wasn't built, since no "detail" view exists for skill-tree nodes (tapping a node has always pushed straight to the target practice/review screen, per Phase 3). Inventing a detail pane that doesn't otherwise exist would be scope creep beyond what Phase 3 established.

## 11. Decisions (resolved 2026-08-02)

- **Daily word count:** fixed default of 5/day, user-configurable in settings. No level-scaling — keeps the goal predictable and avoids adding a scaling curve before the core loop ships.
- **Hearts/lives:** cut from scope entirely. Practice is unlimited on all four practice screens — no life pool, no wait timer, no regen mechanic. See §3.2 for the reasoning and the resulting removals from the data model, sync payload, and file list.
- **Skill-tree content:** generated from existing dictionary frequency data via `/api/dictionary/frequency`, not hand-authored. See §4 "Content generation" for the banding approach. Removes an open-ended content-authoring workstream.
- **`LessonService` rename:** yes — rename to `MediaLibraryService` to stop colliding conceptually with the new `CurriculumService`. See §8 "Renamed" for the concrete file/reference changes.
