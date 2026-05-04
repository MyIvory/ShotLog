# ShotLog — UI Redesign Plan

> Generated after analysis of all 30 Dart source files in the project.

---

## Summary of Findings from Code Analysis

### Files Analyzed
- `lib/app.dart` — `ColorScheme.fromSeed(deepOrange, dark)`, Material 3, Provider
- `lib/screens/home_screen.dart` — `_SessionTile` (raw `ListTile`), plain empty state text, bare spinner
- `lib/screens/new_session_sheet.dart` — `InputDecorator`+`DropdownButton` anti-pattern, no keyboard inset, grey[300] drag handle (invisible on dark)
- `lib/screens/session_screen.dart` — hardcoded `Colors.black`/`Colors.grey[900]`, debug "BT тест" button, tiny threshold ±5 buttons (8dp padding), 12dp amplitude bar
- `lib/screens/session_detail_screen.dart` — dense 13dp metadata table, no summary row, 56×56 thumbnails
- `lib/screens/settings_screen.dart` — explicit "Зберегти" button (not auto-save), hardcoded `Colors.grey` section headers
- `lib/screens/equipment_screen.dart` — double `Scaffold` anti-pattern inside `TabBarView`, delete-without-confirm, widget-instantiated-to-call-method anti-pattern
- `lib/widgets/threshold_picker.dart` — hardcoded navy `Color(0xFF1A1A2E)`, 9dp axis labels, 18dp drag handle (below 48dp minimum), duplicate left+right tooltip
- `lib/widgets/session_state_overlay.dart` — state chip 14dp font, green/amber chips fail WCAG AA contrast with white text
- `lib/widgets/shot_list_item.dart` — 56×56 thumbnail, dBFS not labeled
- `lib/widgets/video_player_overlay.dart` — no `SafeArea`, no shot marker on progress bar, no time display
- `lib/widgets/audio_level_bar.dart` — 4dp height (unused, `_AmplitudePanel` in session_screen re-implements it at 12dp)
- `lib/providers/session_provider.dart` — `SessionState` enum: idle/ready/countdown/recordingArmed/recordingPost/processing
- `lib/models/{session,shot,rifle,bullet,app_settings}.dart` — data shapes
- All service and repository files — for understanding data flow

---

## 1. Design System

### 1.1 Color Palette

```dart
// lib/theme/app_colors.dart
const Color kSeedColor = Color(0xFFE87722); // "Amber Range"

// Semantic state colors (map 1:1 to SessionState enum)
const Color kStateReady        = Color(0xFF2E7D32); // dark green — WCAG AA with black text
const Color kStateCountdown    = Color(0xFFF57F17); // dark amber — WCAG AA with black text
const Color kStateArmed        = Color(0xFFB71C1C); // dark red — WCAG AA with white text
const Color kStateProcessing   = Color(0xFF0D47A1); // dark blue — WCAG AA with white text
const Color kStatePost         = Color(0xFFBF360C); // deep-orange — post-roll

const Color kThresholdLine     = Color(0xFFFFC107); // amber
const Color kAudioBelowThresh  = Color(0xFF66BB6A); // soft green
const Color kAudioAboveThresh  = Color(0xFFEF5350); // soft red

// Surface hierarchy (warm-dark, not cold blue-grey default)
const Color kSurface0 = Color(0xFF1A1210); // Scaffold
const Color kSurface1 = Color(0xFF261E1A); // Cards, sheets
const Color kSurface2 = Color(0xFF322820); // Dialogs
const Color kSurface3 = Color(0xFF3E3028); // Selected items
```

**Key rationale:** The current `Colors.green` / `Colors.amber` state chip backgrounds fail WCAG AA contrast with white text (green: 2.5:1, amber: ~2.9:1). The proposed darker shades (`#2E7D32`, `#F57F17`) with **black** foreground text achieve 4.5:1+.

### 1.2 Typography

| Role | Size | Font | Usage |
|---|---|---|---|
| `displayLarge` | 57dp | Roboto Condensed Bold | Countdown numeral overlay |
| `headlineMedium` | 28dp | Roboto Medium | Sheet titles |
| `titleLarge` | 22dp | Roboto Medium | AppBar |
| `titleMedium` | 16dp | Roboto Medium | Card titles |
| `bodyMedium` | 14dp | Roboto Regular | Metadata, subtitles |
| `bodySmall` | 12dp | Roboto Regular | Timestamps, hints |
| `monoDbfs` | 14dp | **RobotoMono Regular** | All dBFS numerics — prevents layout jitter |

All dBFS displays (`triggerDbfs`, live `_dbfs`, threshold) must use monospace. Current non-monospace numerics cause layout jitter in the amplitude panel as values change.

### 1.3 Spacing Scale

```dart
class Sp {
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 16.0;  // screen padding
  static const double lg  = 24.0;  // sheet padding
  static const double xl  = 32.0;
  static const double xxl = 48.0;

  static const double cardPadding   = md;  // was: 12 → fix to 16
  static const double formFieldGap  = md;  // was: 12 → fix to 16
  static const double sectionGap    = lg;
}
```

### 1.4 Elevation (M3 Tonal)

| Component | M3 Level | Token |
|---|---|---|
| Scaffold | 0 | `kSurface0` |
| Cards, ListTiles | 1 | `kSurface1` |
| Bottom sheets | 1 | `kSurface1` |
| Dialogs | 3 | `kSurface2` |
| Bottom bar (SessionScreen) | 2 | `colorScheme.surfaceContainerHighest` |
| VU meter background | 0 | `kSurface0` (not hardcoded `#1A1A2E`) |

### 1.5 Motion

| Interaction | Current | Proposed |
|---|---|---|
| State chip | Instant | `AnimatedSwitcher` fade+scale 200ms |
| Countdown number | Text swap | `AnimatedSwitcher` scale 200ms |
| Record dot | Static "●" | Pulse opacity 800ms repeat |
| Shot detection | No visual | Full-screen white flash 200ms |
| Amplitude bar | `AnimatedContainer` 50ms | Keep |
| VU tooltip | Instant appear | `AnimatedOpacity` 150ms |

---

## 2. Navigation Architecture

### Current Issues
1. NewSessionSheet → SessionScreen uses `push` — back from SessionScreen goes to half-constructed state
2. "Продовжити сесію" creates a confusing navigation stack (detail screen → session screen, back → detail screen needs manual reload)
3. Debug "BT тест" button is still in the session screen (marked `// TODO: remove`)
4. Settings accessible only from HomeScreen AppBar

### Proposed Fixes

```dart
// Fix 1: HomeScreen._startNewSession() — use pushReplacement
Navigator.pushReplacement(context,
  MaterialPageRoute(builder: (_) => SessionScreen(settings: settings)));

// Fix 2: SessionDetailScreen._continueSession() — clean stack
await Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(builder: (_) => SessionScreen(settings: settings)),
  (route) => route.isFirst,
);

// Fix 3: Remove BT debug button entirely from _BottomBar
```

---

## 3. Per-Screen Redesign

### 3.1 HomeScreen

**Problems:** Plain empty state; `ListTile` with no card separation; date in title row clutter; shot-count CircleAvatar same accent color whether 0 or 12 shots.

**Proposed `SessionCard`:**
```dart
class SessionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasShots = session.shotCount > 0;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: hasShots
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              child: Text('${session.shotCount}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: hasShots
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.name ?? 'Сесія', style: theme.textTheme.titleMedium),
                if (equipLine.isNotEmpty)
                  Text(equipLine, style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant))
                else
                  Text('Спорядження не вказано',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic)),
                Row(children: [
                  Expanded(child: Text(_formatDate(session.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant))),
                  if (session.distanceM != null)
                    Text('${session.distanceM!.toStringAsFixed(0)} м',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                ]),
              ],
            )),
            if (hasShots)
              Icon(Icons.play_circle_outline,
                color: theme.colorScheme.primary, size: 28),
          ]),
        ),
      ),
    );
  }
}
```

**Empty state:**
```dart
EmptyState(
  icon: Icons.fiber_smart_record_outlined,
  title: 'Жодної сесії',
  body: 'Натисніть кнопку нижче, щоб розпочати перше тренування',
  actionLabel: 'Нова сесія',
  onAction: _startNewSession,
)
```

---

### 3.2 NewSessionSheet

**P0 fixes:**
1. Drag handle: change `Colors.grey[300]` → `Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4)`
2. Keyboard inset: add `padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom)` to the ListView
3. Replace `InputDecorator`+`DropdownButton` with `DropdownMenu<T>` (M3 native)

```dart
// Fix keyboard awareness:
ListView(
  controller: scroll,
  padding: EdgeInsets.fromLTRB(24, 24, 24,
    24 + MediaQuery.of(context).viewInsets.bottom), // KEY FIX
  children: [ ... ],
)

// Fix drag handle:
Container(
  width: 40, height: 4,
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
    borderRadius: BorderRadius.circular(2)),
)
```

---

### 3.3 SessionScreen (Live Recording)

**P0 fix:** Remove "BT тест" debug button:
```dart
// DELETE this block entirely:
// if (sp.state == SessionState.ready)
//   ElevatedButton.icon(
//     style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
//     icon: const Icon(Icons.radio_button_on, color: Colors.white),
//     label: const Text('BT тест', style: TextStyle(color: Colors.white)),
//     onPressed: () => context.read<SessionProvider>().triggerButton(),
//   ),
```

**Countdown overlay:**
```dart
if (sp.state == SessionState.countdown)
  Positioned.fill(
    child: Container(
      color: Colors.black54,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
          child: Text(
            '${sp.countdownRemaining}',
            key: ValueKey(sp.countdownRemaining),
            style: const TextStyle(fontSize: 96,
              color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    ),
  ),
```

**Shot flash:**
```dart
// Add to _CameraView Stack — listen to shots.length changes:
if (_flashVisible)
  Positioned.fill(
    child: AnimatedOpacity(
      opacity: _flashVisible ? 0.3 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(color: Colors.white),
    ),
  ),
```

**Threshold buttons — fix touch target:**
```dart
// Replace _ThresholdButton GestureDetector with OutlinedButton:
OutlinedButton(
  style: OutlinedButton.styleFrom(
    minimumSize: const Size(48, 44),
    side: const BorderSide(color: Colors.orange),
    foregroundColor: Colors.orange,
    padding: const EdgeInsets.symmetric(horizontal: 12),
  ),
  onPressed: onTap,
  child: Text(label),
)
```

**Themed bottom bar:**
```dart
// Replace Colors.grey[900]:
Container(
  color: Theme.of(context).colorScheme.surfaceContainerHighest,
  padding: EdgeInsets.fromLTRB(16, 12, 16,
    12 + MediaQuery.of(context).padding.bottom),
  ...
)
```

---

### 3.4 SessionDetailScreen

**Replace `_MetaCard` dense table** with chip-based summary:
```dart
// SessionSummaryCard uses Wrap for chips:
Wrap(
  spacing: 8, runSpacing: 8,
  children: [
    if (rifle != null)
      Chip(avatar: Icon(Icons.precision_manufacturing_outlined, size: 16),
           label: Text(rifle!.displayName)),
    if (bullet != null)
      Chip(avatar: Icon(Icons.circle_outlined, size: 16),
           label: Text(bullet!.displayName)),
    if (session!.distanceM != null)
      Chip(label: Text('${session!.distanceM!.toStringAsFixed(0)} м')),
    if (session!.detectionDbfs != null)
      Chip(avatar: Icon(Icons.graphic_eq, size: 16),
           label: Text('Поріг: ${session!.detectionDbfs!.toStringAsFixed(0)} dBFS')),
  ],
)
```

**ShotSummaryRow (new):**
```dart
Row(
  children: [
    Expanded(child: _StatTile(
      value: '${_shots.length}',
      label: 'пострілів',
      large: true)),
    if (_avgDbfs != null)
      Expanded(child: _StatTile(
        value: '${_avgDbfs!.toStringAsFixed(0)} dBFS',
        label: 'середній рівень',
        mono: true)),
  ],
)
```

**dBFS label fix in ShotListItem:**
```dart
// Change:
'${_formatTime(shot.detectedAt)}  ·  ${shot.triggerDbfs!.toStringAsFixed(0)} dBFS'
// To:
'${_formatTime(shot.detectedAt)}  ·  Рівень: ${shot.triggerDbfs!.toStringAsFixed(0)} dBFS'
```

---

### 3.5 VideoPlayerOverlay

**SafeArea fix:**
```dart
// Wrap entire Stack in SafeArea:
Material(
  color: Colors.black87,
  child: SafeArea(  // ADD THIS
    child: Stack(children: [ ... ]),
  ),
)
```

**Shot marker:**
```dart
LayoutBuilder(builder: (ctx, constraints) {
  final fraction = widget.shot.shotOffsetMs /
      widget.ctrl!.value.duration.inMilliseconds.toDouble();
  return Stack(clipBehavior: Clip.none, children: [
    VideoProgressIndicator(widget.ctrl!, allowScrubbing: true,
        colors: VideoProgressColors(
          playedColor: Theme.of(context).colorScheme.primary)),
    Positioned(
      left: (constraints.maxWidth * fraction.clamp(0, 1) - 8)
          .clamp(0, constraints.maxWidth - 16),
      top: -4,
      child: const Icon(Icons.arrow_drop_down,
          color: Color(0xFFFFC107), size: 20),
    ),
  ]);
})
```

---

### 3.6 SettingsScreen

**Auto-save with debounce:**
```dart
Timer? _saveDebounce;
void _onChanged(AppSettings s) {
  setState(() => _s = s);
  _saveDebounce?.cancel();
  _saveDebounce = Timer(const Duration(milliseconds: 500), () async {
    await _svc.save(_s);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Збережено'),
          duration: Duration(seconds: 1)));
  });
}
```

**Section header fix:**
```dart
// Replace:
Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey))
// With:
Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
  color: Theme.of(context).colorScheme.onSurfaceVariant))
```

---

### 3.7 ThresholdPicker

**VU meter background fix:**
```dart
// Replace hardcoded Color(0xFF1A1A2E) — pass theme color as parameter to _VuMeterPainter:
Paint()..color = Theme.of(context).colorScheme.surface
```

**dB label font size fix:**
```dart
// Change fontSize: 9 → 12:
style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1)
```

**Drag handle touch zone:**
```dart
// The current 9dp radius circle is way below 48dp minimum.
// Add a 48dp-tall transparent band to communicate the grab zone:
Positioned(
  top: (h * (1.0 - _thresholdFraction) - 24).clamp(0, h - 48),
  left: 0, right: 0,
  child: Container(
    height: 48,
    color: Colors.orange.withOpacity(0.12),
    alignment: Alignment.center,
    child: Container(height: 2, color: Colors.orange),
  ),
),
```

**Haptic feedback:**
```dart
void _handleTouch(double localY, double height) {
  final newFraction = (1.0 - localY / height).clamp(0.0, 1.0);
  final oldDb = _thresholdDbfs;
  setState(() => _thresholdFraction = newFraction);
  // Haptic on 10dB grid crossing:
  if ((_thresholdDbfs / 10).floor() != (oldDb / 10).floor()) {
    HapticFeedback.selectionClick();
  }
}
```

---

### 3.8 EquipmentScreen

**P0 — Remove double Scaffold:**
```dart
// _RifleTab and _BulletTab: remove inner Scaffold, use plain ListView.
// EquipmentScreen gets the single FAB:
floatingActionButton: FloatingActionButton(
  child: const Icon(Icons.add),
  onPressed: () => _currentTabIndex == 0
    ? _showRifleDialog(context)
    : _showBulletDialog(context),
),
```

**P0 — Add delete confirmation:**
```dart
IconButton(
  icon: const Icon(Icons.delete_outline),
  onPressed: () async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Видалити гвинтівку?'),
        content: const Text('Ця дія незворотна.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Видалити')),
        ],
      ),
    );
    if (ok == true && context.mounted)
      context.read<EquipmentProvider>().deleteRifle(rifle.id!);
  },
)
```

---

## 4. Empty States / Loading States / Error States

### Empty State Widget
```dart
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({super.key, required this.icon,
    required this.title, required this.body,
    this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 96, color: theme.colorScheme.primaryContainer),
            const SizedBox(height: 24),
            Text(title, style: theme.textTheme.titleLarge,
                 textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, style: theme.textTheme.bodyMedium?.copyWith(
                 color: theme.colorScheme.onSurfaceVariant),
                 textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
```

### Error State Widget
```dart
class ErrorState extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64,
                 color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium,
                 textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, style: Theme.of(context).textTheme.bodySmall,
                 textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Спробувати знову'),
                onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}
```

| Scenario | Proposed Error UI |
|---|---|
| Camera init fails | `ErrorState('Камера недоступна', ...)` + "Відкрити налаштування" |
| Mic permission denied | `MaterialBanner` in sheet |
| Video file missing | `SnackBar` з дією "Видалити запис" |
| DB error | `ErrorState` з кнопкою повтору |
| Threshold picker — мік недоступний | Статичний VU meter + `Banner` |

---

## 5. Accessibility

### Touch Targets (minimum 48×48 dp)

| Widget | Current | Fix |
|---|---|---|
| `_ThresholdButton` (±5) | ~30×16 dp | `OutlinedButton(minimumSize: Size(48, 44))` |
| VU drag handle | 18 dp circle | 48 dp tall gesture zone |
| `ShotListItem` play icon | 32 dp | Wrap in `IconButton` |

### Contrast Fixes (WCAG AA: 4.5:1 for text)

| Element | Current BG | Current FG | Ratio | Fix |
|---|---|---|---|---|
| State chip "ГОТОВО" | `Colors.green` #4CAF50 | white | 2.5:1 FAIL | `#2E7D32` BG + **black** FG |
| State chip "ВІДЛІК" | `Colors.orange` #FF9800 | white | 2.9:1 FAIL | `#F57F17` BG + **black** FG |
| State chip "ЗАПИС" | `Colors.red` #F44336 | white | 3.0:1 FAIL | `#B71C1C` BG + white FG |

### Missing Semantics

```dart
// State chip:
Semantics(label: 'Стан: ЗАПИС', child: _StateChip(...))

// Amplitude bar:
Semantics(
  label: 'Рівень звуку ${_dbfs.toStringAsFixed(0)} dBFS, '
         'поріг ${threshold.toStringAsFixed(0)} dBFS',
  child: _AmplitudeBar(...))

// VU meter drag:
Semantics(
  slider: true,
  value: '${_thresholdDbfs.toStringAsFixed(0)} dBFS',
  child: _VuMeterGestureDetector(...))

// Shot count badge:
CircleAvatar(
  child: Semantics(
    label: '${session.shotCount} пострілів',
    child: Text('${session.shotCount}')))
```

### Text Scaling

Replace all hardcoded `fontSize` in business logic text with `Theme.of(context).textTheme.*` styles which respect the system font scale. The 9dp VU meter labels and 11dp amplitude panel text are especially problematic — both are below the 12dp minimum for readable text at 1× scale.

---

## 6. Priority Table

| # | Change | Screen | Priority | Effort |
|---|---|---|---|---|
| 1 | Remove "BT тест" debug button | SessionScreen | **P0** | XS |
| 2 | Fix keyboard inset in NewSessionSheet | NewSessionSheet | **P0** | XS |
| 3 | Fix drag handle color (invisible on dark) | NewSessionSheet | **P0** | XS |
| 4 | Add delete confirmation in EquipmentScreen | EquipmentScreen | **P0** | S |
| 5 | Fix double-Scaffold in EquipmentScreen | EquipmentScreen | **P0** | S |
| 6 | Fix widget-instantiated-to-call-method anti-pattern | EquipmentScreen | **P0** | S |
| 7 | Add SafeArea to VideoPlayerOverlay | VideoPlayerOverlay | **P0** | XS |
| 8 | Fix state chip contrast (WCAG AA) | SessionScreen | **P0** | XS |
| 9 | Increase `_ThresholdButton` to 48dp target | SessionScreen | **P1** | XS |
| 10 | Increase VU axis labels to 12dp | ThresholdPicker | **P1** | XS |
| 11 | Increase state chip font to 18–20dp | SessionScreen | **P1** | XS |
| 12 | Add countdown full-screen overlay | SessionScreen | **P1** | S |
| 13 | Add shot detection flash | SessionScreen | **P1** | S |
| 14 | Add shot marker on video progress bar | VideoPlayerOverlay | **P1** | M |
| 15 | Replace MetaCard with chip summary | SessionDetailScreen | **P1** | M |
| 16 | Add ShotSummaryRow (count + avg dBFS) | SessionDetailScreen | **P1** | S |
| 17 | Replace DropdownButton with DropdownMenu | NewSessionSheet | **P1** | S |
| 18 | Auto-save settings with debounce | SettingsScreen | **P1** | S |
| 19 | Add help text for pre-roll/post-roll | SettingsScreen | **P1** | XS |
| 20 | Themed color palette (remove all hardcoded colors) | All screens | **P1** | M |
| 21 | Implement EmptyState widget | All screens | **P1** | S |
| 22 | Add "Рівень:" label to ShotListItem dBFS | SessionDetailScreen | **P1** | XS |
| 23 | VU meter drag handle 48dp touch zone | ThresholdPicker | **P1** | S |
| 24 | Add Semantics wrappers | All screens | **P1** | M |
| 25 | Monospace font for dBFS displays | All screens | **P2** | S |
| 26 | AppBar two-line title in DetailScreen | SessionDetailScreen | **P2** | XS |
| 27 | Record dot pulse animation | SessionScreen | **P2** | S |
| 28 | AnimatedSwitcher on state chip | SessionScreen | **P2** | XS |
| 29 | AnimatedSwitcher on countdown numeral | SessionScreen | **P2** | XS |
| 30 | Haptic on shot detection | SessionScreen | **P2** | XS |
| 31 | Haptic on VU drag + grid crossing | ThresholdPicker | **P2** | XS |
| 32 | Inline numeric input for threshold | ThresholdPicker | **P2** | S |
| 33 | Fix "Продовжити" navigation stack | SessionDetailScreen | **P2** | S |
| 34 | Post-session SnackBar confirmation | SessionScreen | **P2** | XS |
| 35 | Auto-generate session name if blank | NewSessionSheet | **P2** | XS |
| 36 | Recently used rifle/bullet quick-pick | NewSessionSheet | **P2** | M |
| 37 | Shimmer skeleton loading for HomeScreen | HomeScreen | **P2** | M |
| 38 | SessionCard redesign (replace ListTile) | HomeScreen | **P2** | M |
| 39 | SliverAppBar.large for HomeScreen | HomeScreen | **P2** | S |
| 40 | Video auto-pause at end, seek back to shot | VideoPlayerOverlay | **P2** | XS |
| 41 | Tab icons in EquipmentScreen | EquipmentScreen | **P2** | XS |
| 42 | Show equipment notes in list tiles | EquipmentScreen | **P2** | XS |
| 43 | Persistent NavigationBar (Phase 2) | App-level | **P2** | L |
| 44 | Sort/filter sessions | HomeScreen | **P2** | M |

**Effort:** XS < 1h · S = 1–4h · M = 4–16h · L = 16–40h
