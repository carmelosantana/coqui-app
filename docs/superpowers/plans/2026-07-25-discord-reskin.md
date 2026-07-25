# Coqui App Discord Reskin — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reskin and reshell the Coqui Flutter client into a Discord-style "Habitat" interface over the existing Provider/API layer, then delete the dropped features.

**Architecture:** New four-column shell (`lib/Pages/shell/`) replaces `ChatDrawer + ChatPage`, driven by the existing `ProfileProvider`, `ChatProvider`, `LoopProvider`, `InstanceProvider`. A single `CoquiTokens` design-token source feeds a rewritten dark-first theme. Dropped features are removed in an analyze-gated phase. Verified end-to-end against a local Docker `coqui-api` + Ollama in Chrome.

**Tech Stack:** Flutter 3.44.8 / Dart 3.12.2, `provider` 6.x, existing `coqui_api_service` (SSE), Geist/Geist Mono (bundled), `responsive_framework`.

## Global Constraints

- Dart SDK floor: `^3.5.4` (per `pubspec.yaml`); do not raise.
- State management: **`provider` only** — no new state libraries.
- No changes to the Coqui core API contract. Base path `/api/v1` is auto-prepended by `coqui_api_service`.
- All colors/type/radii come from `CoquiTokens` — **no hardcoded hex in widgets**.
- Fonts: `Geist` (body), `GeistMono` (labels/meta/models/roles/timestamps/section headers) — already bundled.
- Dark-first. Token values are verbatim from `docs/Flutter app Discord redesign/coqui-design-spec.json`.
- Every task ends: `flutter analyze` clean **and** `flutter test` green, then commit on `feat/discord-redesign`.
- Identity for all commits: `Carmelo Santana <me@carmelosantana.com>` (global default; do not override).
- Primary target: **web/Chrome**. Do not break desktop/mobile buildability, but they are not sign-off targets.

## Verified existing APIs (consume, do not reinvent)

**Providers** (all `ChangeNotifier`, registered in `lib/main.dart` `MultiProvider`):
- `ProfileProvider`: `Future<void> fetchProfiles()`, `List<CoquiProfile> get profiles` (via field), `Future<CoquiProfile?> fetchProfileDetail(String name)`, `createProfile({...})`, `updateProfile(...)`, `deleteProfile(String)`.
- `ChatProvider`: `List<CoquiSession> get sessions`, `List<CoquiSession> get archivedSessions`, `CoquiSession? get currentSession`, `bool get isCurrentSessionStreaming`, `Future<void> openSession(String)`, `Future<void> refreshSessions()`, `Future<void> createNewSession(...)`, `Future<void> resolveSessionScope(CoquiRole role, {String? profile})`, `bool isSessionStreaming(String)`.
- `LoopProvider`: `CoquiLoop? loopById(String)`, `List<CoquiLoopIteration> iterationsForLoop(String)`, `Future<void> fetchLoops({String? status})`, `Future<void> fetchDefinitions({bool force})`, `Future<CoquiLoopDetail?> createLoop({...})`, `Future<CoquiLoopDetail?> loadLoopDetail(String id, ...)`.
- `InstanceProvider`: `Future<void> addInstance(CoquiInstance)`, `Future<void> setActiveInstance(String id)`, `Future<void> refreshHealth()`, plus active-instance getter.

**Models:**
- `CoquiProfile { String name, displayName, description; bool isDefault; String? model, soul; List<String> allowedRoles; }`
- `CoquiSession { String id, modelRole, model; String? profile; bool groupEnabled, isClosed, isArchived; String? title; int tokenCount; DateTime createdAt, updatedAt; }`
- `CoquiLoop { String id, definitionName, goal, status; String? sessionId; int currentIteration, currentStage; int? maxIterations; }` and `CoquiLoopDefinition { String name, description; List<CoquiLoopRoleStep> roles; }`
- `CoquiInstance { String id, name, baseUrl, apiKey, apiVersion; bool isActive; }`

**Theme layer (rewrite target):** `lib/Theme/{coqui_colors,coqui_color_scheme,coqui_typography,coqui_theme,theme}.dart`. `CoquiTheme.dark()` builds `ThemeData`; `CoquiBrandColors` is a `ThemeExtension`.

---

## File structure (created/modified)

```
lib/Theme/coqui_tokens.dart            NEW  — the single token source (CoquiTokens)
lib/Theme/coqui_theme.dart             MOD  — dark-first build from CoquiTokens
lib/Theme/coqui_typography.dart        MOD  — Geist/GeistMono scale per spec
lib/Pages/shell/coqui_shell.dart       NEW  — responsive 4-column scaffold
lib/Pages/shell/persona_rail/          NEW  — persona_rail.dart, persona_orb.dart
lib/Pages/shell/session_rail/          NEW  — session_rail.dart, session_tile.dart, session_section.dart
lib/Pages/shell/chat/                  NEW  — chat_column.dart, message_list.dart, composer.dart, loop_card.dart
lib/Pages/shell/loop_monitor/          NEW  — loop_monitor.dart
lib/Pages/shell/popovers/              NEW  — loop_launcher.dart, server_switcher.dart, persona_editor.dart
lib/Pages/shell/shell_controller.dart  NEW  — ChangeNotifier: active persona/session/loop-panel state
lib/main.dart                          MOD  — home = CoquiShell; register ShellController; drop deleted providers
test/shell/                            NEW  — widget tests + api mock
scripts/e2e/                           NEW  — docker+ollama harness scripts
```

---

# PHASE 1 — Design tokens + theme

### Task 1: `CoquiTokens` design-token source

**Files:**
- Create: `lib/Theme/coqui_tokens.dart`
- Test: `test/theme/coqui_tokens_test.dart`

**Interfaces:**
- Produces: `abstract final class CoquiTokens` with nested `Surface`, `Brand`, `StatusColors`, `TextColors`, `Borders`, `Radii`, `Personas` static groups; `static const double personaRailWidth = 74`, `sessionRailWidth = 250`, `loopPanelWidth = 300`, `footerBand = 74`, `channelHeader = 52`; `static Map<String, ({Color bg, Color fg})> personaTint`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';

void main() {
  test('brand + layout tokens match spec', () {
    expect(CoquiTokens.brand.primaryLime, const Color(0xFFCAE763));
    expect(CoquiTokens.surface.chatBg, const Color(0xFF0E110E));
    expect(CoquiTokens.personaRailWidth, 74);
    expect(CoquiTokens.sessionRailWidth, 250);
    expect(CoquiTokens.loopPanelWidth, 300);
    expect(CoquiTokens.footerBand, 74);
    expect(CoquiTokens.personaTint['nova']!.bg, const Color(0xFF3A2B52));
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `~/flutter/bin/flutter test test/theme/coqui_tokens_test.dart` → FAIL (`coqui_tokens.dart` not found).

- [ ] **Step 3: Write the token source** — create `lib/Theme/coqui_tokens.dart` with every value from `coqui-design-spec.json`:

```dart
import 'package:flutter/material.dart';

abstract final class CoquiTokens {
  static const surface = _Surface();
  static const brand = _Brand();
  static const status = _Status();
  static const text = _Text();
  static const border = _Border();
  static const radii = _Radii();

  static const double personaRailWidth = 74;
  static const double sessionRailWidth = 250;
  static const double loopPanelWidth = 300;
  static const double footerBand = 74;
  static const double channelHeader = 52;

  static const Map<String, ({Color bg, Color fg})> personaTint = {
    'caelum': (bg: Color(0xFF2B3A52), fg: Color(0xFFBCD3F0)),
    'nova':   (bg: Color(0xFF3A2B52), fg: Color(0xFFCBBCF0)),
    'iris':   (bg: Color(0xFF52342B), fg: Color(0xFFF0C9BC)),
    'muse':   (bg: Color(0xFF2B5245), fg: Color(0xFFBCF0DD)),
    'sol':    (bg: Color(0xFF4A4426), fg: Color(0xFFEFE3A8)),
  };
}

class _Surface {
  const _Surface();
  final Color personaRail = const Color(0xFF050705);
  final Color sessionRail = const Color(0xFF0A0C0A);
  final Color chatBg      = const Color(0xFF0E110E);
  final Color footerWell  = const Color(0xFF070907);
  final Color card        = const Color(0xFF0C0F0C);
  final Color input       = const Color(0xFF181B12);
  final Color chip        = const Color(0xFF171B12);
  final Color hover       = const Color(0xFF171B12);
}

class _Brand {
  const _Brand();
  final Color primaryLime  = const Color(0xFFCAE763);
  final Color gradientEnd  = const Color(0xFF74DA5C);
  final Color accentGreen  = const Color(0xFF37B880);
  final Color onPrimary    = const Color(0xFF0A0A0A);
  LinearGradient get limeGradient => const LinearGradient(colors: [Color(0xFFCAE763), Color(0xFF74DA5C)]);
}

class _Status {
  const _Status();
  final Color online  = const Color(0xFF37B880);
  final Color busy    = const Color(0xFFE0B34D);
  final Color idle    = const Color(0xFF5A5F52);
  final Color error   = const Color(0xFFE06A5A);
  final Color warning = const Color(0xFFE0B34D);
}

class _Text {
  const _Text();
  final Color high      = const Color(0xFFE8E8E8);
  final Color body      = const Color(0xFFCFD3C6);
  final Color secondary = const Color(0xFFC7CCBE);
  final Color muted     = const Color(0xFF8A8F80);
  final Color faint     = const Color(0xFF6B6F62);
}

class _Border {
  const _Border();
  final Color hairline      = const Color(0xFF16190F);
  final Color normal        = const Color(0xFF23261F);
  final Color control       = const Color(0xFF2A2E22);
  final Color controlActive = const Color(0xFF2C3020);
  final Color loopCard      = const Color(0xFF23301A);
}

class _Radii {
  const _Radii();
  final double sm = 6, md = 8, card = 10, input = 12, railOrb = 16, pill = 9999;
}
```

- [ ] **Step 4: Run test to verify it passes** — `~/flutter/bin/flutter test test/theme/coqui_tokens_test.dart` → PASS.
- [ ] **Step 5: Commit** — `git add lib/Theme/coqui_tokens.dart test/theme/coqui_tokens_test.dart && git commit -m "feat(theme): add CoquiTokens design-token source"`

### Task 2: Dark-first theme + typography from tokens

**Files:**
- Modify: `lib/Theme/coqui_theme.dart`, `lib/Theme/coqui_typography.dart`
- Test: `test/theme/coqui_theme_test.dart`

**Interfaces:**
- Consumes: `CoquiTokens`.
- Produces: `CoquiTheme.dark()` returns `ThemeData` whose `scaffoldBackgroundColor == CoquiTokens.surface.chatBg`, `colorScheme.primary == CoquiTokens.brand.primaryLime`, `textTheme` uses `Geist`; a `TextStyle CoquiTypography.mono({double size, FontWeight weight, Color color})` helper for mono labels.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coqui_app/Theme/coqui_theme.dart';
import 'package:coqui_app/Theme/coqui_typography.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';

void main() {
  test('dark theme wires tokens', () {
    final t = CoquiTheme.dark();
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, CoquiTokens.surface.chatBg);
    expect(t.colorScheme.primary, CoquiTokens.brand.primaryLime);
  });
  test('mono helper uses GeistMono', () {
    expect(CoquiTypography.mono(size: 10).fontFamily, 'GeistMono');
  });
}
```

- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** — add `static TextStyle mono({double size = 10.5, FontWeight weight = FontWeight.w400, Color? color, double letterSpacing = 0})` to `CoquiTypography` returning `TextStyle(fontFamily: monoFontFamily, fontSize: size, fontWeight: weight, color: color, letterSpacing: letterSpacing)`. In `coqui_theme.dart`, set `scaffoldBackgroundColor: CoquiTokens.surface.chatBg`, build `colorScheme` dark with `primary: CoquiTokens.brand.primaryLime`, `onPrimary: CoquiTokens.brand.onPrimary`, `surface: CoquiTokens.surface.card`, `error: CoquiTokens.status.error`. Keep existing `ThemeData` component themes but repoint their colors to tokens.
- [ ] **Step 4: Run** → PASS. Also run full `~/flutter/bin/flutter test` → green.
- [ ] **Step 5: Commit** — `git commit -m "feat(theme): dark-first theme + mono helper from CoquiTokens"`

---

# PHASE 2 — Nav-shell scaffold

### Task 3: `ShellController` (active persona/session/loop-panel state)

**Files:**
- Create: `lib/Pages/shell/shell_controller.dart`
- Test: `test/shell/shell_controller_test.dart`

**Interfaces:**
- Produces: `class ShellController extends ChangeNotifier { String? activePersona; String? activeSessionId; bool loopPanelOpen; String? activeLoopId; void selectPersona(String?); void selectSession(String?); void openLoopPanel(String loopId); void closeLoopPanel(); }` — each mutator calls `notifyListeners()`.

- [ ] **Step 1: Failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';

void main() {
  test('selecting persona notifies and stores', () {
    final c = ShellController();
    var n = 0; c.addListener(() => n++);
    c.selectPersona('caelum');
    expect(c.activePersona, 'caelum');
    expect(n, 1);
  });
  test('loop panel open/close toggles', () {
    final c = ShellController()..openLoopPanel('loop-1');
    expect(c.loopPanelOpen, true);
    expect(c.activeLoopId, 'loop-1');
    c.closeLoopPanel();
    expect(c.loopPanelOpen, false);
  });
}
```

- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** the class exactly as the interface block.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(shell): ShellController for shell navigation state"`

### Task 4: `CoquiShell` responsive scaffold (placeholder columns)

**Files:**
- Create: `lib/Pages/shell/coqui_shell.dart`
- Modify: `lib/main.dart` (home → `CoquiShell`, register `ShellController`)
- Test: `test/shell/coqui_shell_test.dart`

**Interfaces:**
- Consumes: `CoquiTokens`, `ShellController`, `responsive_framework` breakpoints already in `main.dart`.
- Produces: `class CoquiShell extends StatelessWidget`. Desktop (`width >= 1024`) renders a `Row` of four `Container`s keyed `persona-rail` (74), `session-rail` (250), `chat-column` (Expanded), and — when `ShellController.loopPanelOpen` — `loop-monitor` (300). Mobile (`< 640`) renders chat with a persona strip and drawer. Each column is a widget from later tasks; for now use `const _Placeholder(label)` children so the scaffold compiles.

- [ ] **Step 1: Failing test** (desktop lays out both rails)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:coqui_app/Pages/shell/coqui_shell.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';

void main() {
  testWidgets('desktop shell shows persona + session rails', (t) async {
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(ChangeNotifierProvider(
      create: (_) => ShellController(),
      child: const MaterialApp(home: CoquiShell()),
    ));
    expect(find.byKey(const ValueKey('persona-rail')), findsOneWidget);
    expect(find.byKey(const ValueKey('session-rail')), findsOneWidget);
    final w = t.getSize(find.byKey(const ValueKey('persona-rail'))).width;
    expect(w, CoquiTokens.personaRailWidth);
  });
}
```

- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** `CoquiShell` with a `LayoutBuilder`; render placeholders keyed as above; loop-monitor conditional on `context.watch<ShellController>().loopPanelOpen`. Wire `main.dart`: add `ChangeNotifierProvider(create: (_) => ShellController())` to the `MultiProvider` and set the home widget to `CoquiShell` (keep `MaterialApp` + theme intact).
- [ ] **Step 4: Run** → PASS; `~/flutter/bin/flutter analyze` clean.
- [ ] **Step 5: Commit** — `git commit -m "feat(shell): responsive four-column CoquiShell scaffold"`

---

# PHASE 3 — Personas + sessions wiring

### Task 5: Persona rail

**Files:** Create `lib/Pages/shell/persona_rail/persona_rail.dart`, `persona_orb.dart`; Test `test/shell/persona_rail_test.dart`.

**Interfaces:**
- Consumes: `ProfileProvider.profiles` (`List<CoquiProfile>`), `ShellController.activePersona`, `CoquiTokens.personaTint`, `InstanceProvider` (server orb).
- Produces: `PersonaRail` — vertical list: server orb → orchestrator home (pinned, `isDefault` profile, 4px lime left bar when active) → persona orbs (tint by `profile.name`, 2px lime ring when `activePersona == profile.name`, status dot) → dashed add-persona button that opens `PersonaEditor` (Task 12). `PersonaOrb(profile, active, onTap)`.

- [ ] **Step 1: Failing test** — pump `PersonaRail` with a fake `ProfileProvider` exposing two profiles (one `isDefault`); assert one orb per profile plus add button; assert tapping an orb calls `ShellController.selectPersona`.

```dart
// Uses a FakeProfileProvider extending ProfileProvider with an injected list.
testWidgets('persona rail renders an orb per profile + add button', (t) async {
  // pump with MultiProvider(FakeProfileProvider(two profiles), ShellController)
  expect(find.byType(PersonaOrb), findsNWidgets(2));
  expect(find.byKey(const ValueKey('add-persona')), findsOneWidget);
});
```

- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** `PersonaRail` + `PersonaOrb` binding to the real `CoquiProfile` fields; tint lookup `CoquiTokens.personaTint[profile.name.toLowerCase()]` with a neutral fallback; orchestrator = the `isDefault` profile rendered with `radii.railOrb` (square-ish) vs circular personas.
- [ ] **Step 4: Run** → PASS; analyze clean.
- [ ] **Step 5: Commit** — `git commit -m "feat(shell): persona rail bound to ProfileProvider"`

### Task 6: Session rail (header, search, sections, footer band)

**Files:** Create `lib/Pages/shell/session_rail/{session_rail,session_tile,session_section}.dart`; Test `test/shell/session_rail_test.dart`.

**Interfaces:**
- Consumes: `ChatProvider.sessions` (filtered by `ShellController.activePersona` via `session.profile`), `ChatProvider.isSessionStreaming`, `CoquiTokens`.
- Produces: `SessionRail` — persona header (avatar + name + `profile.model` in mono + chevron), search field, sections PINNED / SESSIONS / GROUP (GROUP = sessions with `groupEnabled`), `SessionTile(session, active, onTap)` with `#`/pinned/closed icon + live status dot, and a 74px footer band (server chip left, user avatar + gear right). Tapping a tile calls `ChatProvider.openSession(session.id)` + `ShellController.selectSession(session.id)`.

- [ ] **Step 1: Failing test** — fake `ChatProvider` with 3 sessions (1 groupEnabled, 1 isClosed); assert GROUP section shows the group session, SESSIONS shows the rest; assert footer band height == 74.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** binding to real `CoquiSession` fields (`title`, `model`, `groupEnabled`, `isClosed`, `profile`).
- [ ] **Step 4: Run** → PASS; analyze clean.
- [ ] **Step 5: Commit** — `git commit -m "feat(shell): session rail with sections + footer band"`

---

# PHASE 4 — Chat column + composer + SSE

### Task 7: Chat column + message list (reuse existing streaming)

**Files:** Create `lib/Pages/shell/chat/{chat_column,message_list}.dart`; Test `test/shell/chat_column_test.dart`.

**Interfaces:**
- Consumes: `ChatProvider.currentSession`, existing message/turn state on `ChatProvider`, `ChatProvider.isCurrentSessionStreaming`.
- Produces: `ChatColumn` — 52px channel header (session title + subtitle), scrolling `MessageList` (reuses the existing chat bubble widgets under `lib/Pages/chat_page/subwidgets/chat_bubble/` — import and reuse; do not reimplement bubbles), mono role tags + tool-call chips, and mounts the `Composer` (Task 8).

- [ ] **Step 1: Failing test** — pump `ChatColumn` with a fake `ChatProvider` exposing a `currentSession` with a title; assert the channel header renders the title and height == `CoquiTokens.channelHeader`.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**, reusing existing bubble widgets for message rendering.
- [ ] **Step 4: Run** → PASS; analyze clean.
- [ ] **Step 5: Commit** — `git commit -m "feat(shell): chat column + message list reusing chat bubbles"`

### Task 8: Composer (send-enable logic + attach + loop launcher trigger)

**Files:** Create `lib/Pages/shell/chat/composer.dart`; Test `test/shell/composer_test.dart`.

**Interfaces:**
- Consumes: `ChatProvider` (send prompt / existing submit method), `ShellController` (loop launcher open).
- Produces: `Composer` — `+` attach, `ϟ` loop-launcher button (monochrome `text.high`, lime fill when launcher open), text input, `↑` send. Send button fill is `CoquiTokens.brand.primaryLime` **only when the input is non-empty**, else `Color(0xFF22271B)` fg `text.muted`. Submitting calls the existing `ChatProvider` prompt-send path.

- [ ] **Step 1: Failing test**

```dart
testWidgets('send button turns lime only when input non-empty', (t) async {
  // pump Composer inside providers
  final sendFinder = find.byKey(const ValueKey('composer-send'));
  BoxDecoration deco() => t.widget<Container>(
    find.descendant(of: sendFinder, matching: find.byType(Container)).first).decoration as BoxDecoration;
  expect(deco().color, const Color(0xFF22271B)); // resting
  await t.enterText(find.byKey(const ValueKey('composer-input')), 'hi');
  await t.pump();
  expect(deco().color, CoquiTokens.brand.primaryLime); // ready
});
```

- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** with a `TextEditingController` listener driving the lime/resting state; `ϟ` toggles `ShellController` loop-launcher flag.
- [ ] **Step 4: Run** → PASS; analyze clean.
- [ ] **Step 5: Commit** — `git commit -m "feat(shell): composer with send-enable + loop launcher trigger"`

---

# PHASE 5 — Loops (launcher, cards, monitor)

### Task 9: Inline loop card (stage stepper)

**Files:** Create `lib/Pages/shell/chat/loop_card.dart`; Test `test/shell/loop_card_test.dart`.

**Interfaces:**
- Consumes: `CoquiLoop` (`definitionName`, `goal`, `status`, `currentIteration`, `maxIterations`, `currentStage`), `CoquiLoopDefinition.roles` for the role chain.
- Produces: `LoopCard(loop, definition)` — header (status dot + name + role chain in mono + `ITER n/N`), stage stepper (circles + 2px bars; done=green, active=lime, pending=outlined `border.loopCard`). Tapping opens the monitor via `ShellController.openLoopPanel(loop.id)`.

- [ ] **Step 1: Failing test** — build a `CoquiLoop` with `currentIteration: 2, maxIterations: 5, currentStage: 1` and a 3-role definition; assert `ITER 2/5` text present and 3 stage nodes render with node[0]=done, node[1]=active.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** the stepper deriving done/active/pending from `currentStage`.
- [ ] **Step 4: Run** → PASS; analyze clean.
- [ ] **Step 5: Commit** — `git commit -m "feat(shell): inline loop card with stage stepper"`

### Task 10: Loop launcher popover

**Files:** Create `lib/Pages/shell/popovers/loop_launcher.dart`; Test `test/shell/loop_launcher_test.dart`.

**Interfaces:**
- Consumes: `LoopProvider.fetchDefinitions()` + definitions list, `ChatProvider.currentSession`.
- Produces: `LoopLauncher` overlay (400 wide, anchored above composer left) — one row per definition (icon + name + role-chain mono), a goal text input, and a Run button (`primaryLime`/`onPrimary`) that calls `LoopProvider.createLoop(definition: name, goal: goal, sessionId: currentSession.id)` then closes.

- [ ] **Step 1: Failing test** — fake `LoopProvider` with 2 definitions; assert 2 rows; enter a goal, tap Run, assert `createLoop` called with that goal + definition.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**; fetch definitions on first open.
- [ ] **Step 4: Run** → PASS; analyze clean.
- [ ] **Step 5: Commit** — `git commit -m "feat(shell): loop launcher popover"`

### Task 11: Loop monitor (slide-in panel + live/events wiring)

**Files:** Create `lib/Pages/shell/loop_monitor/loop_monitor.dart`; Modify `lib/Services/coqui_api_service.dart` **only if** `/loops/{id}/live` + `/loops/{id}/events` are not already exposed (confirm first — the service references `'live'`); Test `test/shell/loop_monitor_test.dart`.

**Interfaces:**
- Consumes: `LoopProvider.loopById(activeLoopId)`, `LoopProvider.loadLoopDetail(id)`; SSE `/loops/{id}/events` for live stage updates; `LoopProvider` pause/resume/stop (add thin methods if missing, mapping to `/loops/{id}/{pause|resume|stop}` which already exist in the API surface).
- Produces: `LoopMonitor` (300 wide) — TOKENS + ELAPSED stats, a stage timeline (done/needs-changes/running), Pause + Stop controls bound to loop-control endpoints.

- [ ] **Step 1: Read** `lib/Services/coqui_api_service.dart` around the two `'live'` references and `LoopProvider` to confirm which loop-control/live methods exist. Add only the missing thin wrappers (`Future<void> pauseLoop(String id)` etc.) with a failing unit test each.
- [ ] **Step 2: Failing widget test** — fake `LoopProvider` + `ShellController.activeLoopId = 'loop-1'`; assert TOKENS/ELAPSED labels and Pause/Stop buttons render; tapping Stop calls the stop method.
- [ ] **Step 3: Run** → FAIL. **Step 4: Implement.** **Step 5: Run** → PASS; analyze clean.
- [ ] **Step 6: Commit** — `git commit -m "feat(shell): slide-in loop monitor with live controls"`

---

# PHASE 6 — Popovers + persona editor

### Task 12: Persona editor (soul.md)

**Files:** Create `lib/Pages/shell/popovers/persona_editor.dart`; Test `test/shell/persona_editor_test.dart`.

**Interfaces:**
- Consumes: `ProfileProvider.createProfile`/`updateProfile`, `RoleProvider` (allowed-roles list).
- Produces: `PersonaEditor({CoquiProfile? existing})` — avatar-tint swatches (keys of `CoquiTokens.personaTint`), name field, model field, allowed-roles multi-select chips, `soul.md` multiline textarea, Cancel + Create/Save. Save calls create or update with the edited fields.

- [ ] **Step 1: Failing test** — open editor, fill name/model/soul, select two roles, tap Create; assert `createProfile` called with those values.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS; analyze clean.
- [ ] **Step 5: Commit** — `git commit -m "feat(shell): persona editor with soul.md"`

### Task 13: Server switcher popover

**Files:** Create `lib/Pages/shell/popovers/server_switcher.dart`; Test `test/shell/server_switcher_test.dart`.

**Interfaces:**
- Consumes: `InstanceProvider` (instances list + active + health), `setActiveInstance`, `addInstance`.
- Produces: `ServerSwitcher` (300 wide, above footer left) — one row per `CoquiInstance` (orb + name + baseUrl + status dot from health), "Add a server" footer opening an add-instance form. Selecting a row calls `setActiveInstance(id)`.

- [ ] **Step 1: Failing test** — fake `InstanceProvider` with 2 instances; assert 2 rows + add button; tap a row → `setActiveInstance` called.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS; analyze clean.
- [ ] **Step 5: Commit** — `git commit -m "feat(shell): server switcher popover"`

---

# PHASE 7 — Responsive / mobile

### Task 14: Mobile persona strip + drawer

**Files:** Modify `lib/Pages/shell/coqui_shell.dart`; Create `lib/Pages/shell/persona_rail/persona_strip.dart`; Test `test/shell/mobile_shell_test.dart`.

**Interfaces:**
- Produces: at `width < 640`, `CoquiShell` renders `ChatColumn` full-bleed with a top `PersonaStrip` (horizontal personas) and a `Drawer` containing the `SessionRail`; the loop monitor becomes a full-screen route rather than a side panel.

- [ ] **Step 1: Failing test** — set `view.physicalSize = Size(390, 844)`; assert `PersonaStrip` present and side rails absent.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS; analyze clean.
- [ ] **Step 5: Commit** — `git commit -m "feat(shell): mobile persona strip + drawer"`

---

# PHASE 8 — Delete dropped features (analyze-gated)

> Order matters: remove UI entry points first, then providers, then services/models. Run `~/flutter/bin/flutter analyze` after EACH task; fix references in kept code before committing. Keep any shared model still referenced by chat/sessions/loops/profiles.

### Task 15: Remove Human/Machine toggle + dead nav entries

**Files:** Modify `lib/main.dart` (remove old page imports/routes now unused), delete any human/machine toggle widget. Test: existing suite stays green.

- [ ] **Step 1:** `grep -rn "Human\|Machine\|destinationSelected" lib` to locate the toggle; remove the widget + its references in the old chat page path that the shell replaced.
- [ ] **Step 2:** `~/flutter/bin/flutter analyze` → fix fallout. `~/flutter/bin/flutter test` → green.
- [ ] **Step 3: Commit** — `git commit -m "refactor: remove human/machine toggle"`

### Task 16: Delete Channels

**Files:** Delete `lib/Pages/channels_page/`, `lib/Providers/channel_provider.dart`, `lib/Services` channel bits, channel-only models; remove `ChannelProvider` from `main.dart`.

- [ ] **Step 1:** Remove `ChannelProvider` registration in `main.dart`. Delete the page dir + provider.
- [ ] **Step 2:** `~/flutter/bin/flutter analyze` → resolve references (e.g. `CoquiSession.channel` — keep the model field if referenced by kept code; only delete channel *pages/providers*, not fields other features read). `~/flutter/bin/flutter test` → green.
- [ ] **Step 3: Commit** — `git commit -m "refactor: delete channels feature"`

### Task 17: Delete MCP

**Files:** Delete `lib/Pages/mcp_page/`, `lib/Providers/mcp_provider.dart`, MCP models; remove `McpProvider` from `main.dart`.

- [ ] Steps mirror Task 16 (remove registration → delete → analyze → test → commit `refactor: delete MCP feature`).

### Task 18: Delete background/automation Tasks

**Files:** Delete `lib/Pages/tasks_page/`, `lib/Providers/task_provider.dart`, task models; remove `TaskProvider` from `main.dart`. **Note:** keep session-level *todos* (those are session sub-resources on `CoquiSession`, not the automation Tasks feature) — verify via grep before deleting.

- [ ] Steps mirror Task 16; commit `refactor: delete automation tasks feature`.

### Task 19: Delete Projects

**Files:** Delete `lib/Pages/*project*`, `lib/Providers/project_provider.dart`, project-only models; remove `ProjectProvider` from `main.dart`. **Note:** `CoquiSession.activeProjectId` and `LoopProvider` project methods may be referenced — keep the minimum fields kept features read; delete only the Projects *UI + provider*.

- [ ] Steps mirror Task 16; commit `refactor: delete projects feature`.

### Task 20: Delete Credentials

**Files:** Delete credentials page(s) + provider/service/models; remove any registration.

- [ ] Steps mirror Task 16; commit `refactor: delete credentials feature`.

### Task 21: Delete Scheduled tasks

**Files:** Delete `lib/Providers/schedule_provider.dart` + schedule pages/models; remove `ScheduleProvider` from `main.dart`.

- [ ] Steps mirror Task 16; commit `refactor: delete scheduled tasks feature`.

### Task 22: Delete Webhooks

**Files:** Delete `lib/Providers/webhook_provider.dart` + webhook models/pages; remove `WebhookProvider` from `main.dart`.

- [ ] Steps mirror Task 16; commit `refactor: delete webhooks feature`.

### Task 23: Delete Work

**Files:** Delete `lib/Pages/work_page/` (+ subwidgets), `lib/Providers/work_provider.dart`, work models; remove `WorkProvider` from `main.dart`.

- [ ] Steps mirror Task 16; commit `refactor: delete work feature`.

### Task 24: Prune orphaned models/services + final analyze sweep

**Files:** Whatever `~/flutter/bin/flutter analyze` flags as now-unused after Tasks 15–23.

- [ ] **Step 1:** `~/flutter/bin/flutter analyze`; delete unreferenced models/services surfaced by unused-import/dead-code hints. Re-run until clean.
- [ ] **Step 2:** `~/flutter/bin/flutter test` → green.
- [ ] **Step 3: Commit** — `git commit -m "refactor: prune orphaned models/services after deletions"`

---

# PHASE 9 — Docker + Ollama end-to-end smoke

### Task 25: E2E harness scripts

**Files:** Create `scripts/e2e/up.sh`, `scripts/e2e/seed.sh`, `scripts/e2e/README.md`.

**Interfaces:**
- Produces: `up.sh` starts Ollama in Docker (or reuses host), pulls `llama3.2:1b`, brings up `coqui-api` on `:3300` via `docker compose -f ../../Core/coqui/compose.yaml -f ../../Core/coqui/compose.api.yaml up -d coqui-api` with `OLLAMA_HOST` set; `seed.sh` creates one profile + one session through the API. Scripts are idempotent and print the base URL to point the app at.

- [ ] **Step 1:** Write `up.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
docker run -d --name coqui-ollama -p 11434:11434 -v ollama:/root/.ollama ollama/ollama || docker start coqui-ollama
docker exec coqui-ollama ollama pull llama3.2:1b
CORE=/home/carmelo/Projects/CoquiBot/Core/coqui
OLLAMA_HOST=http://host.docker.internal:11434 \
  docker compose -f "$CORE/compose.yaml" -f "$CORE/compose.api.yaml" up -d coqui-api
until curl -sf http://localhost:3300/api/v1/health >/dev/null; do sleep 1; done
echo "coqui-api ready at http://localhost:3300"
```

- [ ] **Step 2:** `bash scripts/e2e/up.sh` → prints "coqui-api ready" and `curl http://localhost:3300/api/v1/health` returns 200.
- [ ] **Step 3:** Write `seed.sh` (POST a profile, POST a session via `/api/v1/profiles` and `/api/v1/sessions`); run it; confirm `GET /api/v1/profiles` lists the seeded persona.
- [ ] **Step 4: Commit** — `git commit -m "chore(e2e): docker + ollama harness scripts"`

### Task 26: Live end-to-end run in Chrome

**Files:** none (verification task) — record results in `scripts/e2e/README.md`.

- [ ] **Step 1:** `bash scripts/e2e/up.sh && bash scripts/e2e/seed.sh`.
- [ ] **Step 2:** Configure the app's active instance to `http://localhost:3300` (via server switcher UI or seeded instance) and run `~/flutter/bin/flutter run -d chrome`.
- [ ] **Step 3:** In the running app: select the seeded persona, open/create a session, send a prompt (confirm SSE streaming renders), start a loop from the launcher, confirm the inline loop card stepper advances and the loop monitor shows live TOKENS/ELAPSED and Pause/Stop work.
- [ ] **Step 4:** Record pass/fail + screenshots in `scripts/e2e/README.md`; `git commit -m "docs(e2e): record end-to-end smoke results"`.

---

## Self-review notes

- **Spec coverage:** shell (T3–T6, T14), theme/tokens (T1–T2), chat/SSE (T7–T8), loops (T9–T11), persona editor/soul.md (T12), server switcher (T13), deletions (T15–T24), Docker+Ollama e2e (T25–T26). All spec sections map to tasks.
- **Types:** widget tasks bind only to the verified provider/model signatures listed in "Verified existing APIs"; any method a task needs but that doesn't exist (loop pause/resume/stop wrappers, live/events) is added under Task 11 with its own test.
- **Deletion safety:** each deletion task removes registration → files → analyze → test → commit, and explicitly preserves shared model fields (`CoquiSession.channel`, `activeProjectId`, session todos) that kept features read.
