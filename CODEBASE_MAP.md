# CODEBASE_MAP.md — ShotLog

## Точка входу

| Файл | Роль |
|---|---|
| `lib/main.dart` | `runApp(ShotLogApp())` |
| `lib/app.dart` | `ShotLogApp` — `MultiProvider` + `MaterialApp`, визначення теми |

**Тема:** темна, акцент `#E87722` (amber), фон `#1A1210`.

---

## Моделі (`lib/models/`)

| Файл | Клас | Ключові поля |
|---|---|---|
| `app_settings.dart` | `AppSettings` (immutable) | `countdownSec`, `timeoutSec`, `postRollSec`, `preRollSec`, `detectionDbfs` (-20.0), `triggerMode`, `selectedCameraId` (""), `cameraZoomMin` (0.0), `cameraZoomMax` (0.0) |
| `app_settings.dart` | `TriggerMode` (enum) | `button`, `bluetooth` |
| `session.dart` | `Session` | `id`, `name`, `createdAt`, `endedAt`, `shotCount`, `rifleId`, `bulletId`, `distanceM`, `weather`, `notes`, `detectionDbfs`, **`durationSec`** (nullable int — акумульований час активних сегментів) |
| `shot.dart` | `Shot` | `id`, `sessionId`, `shotNumber`, `detectedAt`, `clipPath`, `shotOffsetMs`, `thumbnailPath`, `triggerDbfs`, **`durationMs`** (nullable int — тривалість кліпу в мс) |
| `rifle.dart` | `Rifle` | `id`, `name`, `caliber`, `notes` |
| `bullet.dart` | `Bullet` | `id`, `name`, `weightGr`, `caliber`, `velocityMs`, `notes` |

Всі моделі мають `toMap()`, `fromMap()`, `copyWith()`.

---

## Провайдери (`lib/providers/`)

### `SessionProvider` (головний — `ChangeNotifier`)
Файл: `providers/session_provider.dart`

**Стани (`SessionState`):** `idle → ready → countdown → recordingArmed → recordingPost → processing → ready`

| Метод | Дія |
|---|---|
| `startSession(session, settings)` | Ініціалізує камеру, вставляє сесію в БД, запускає BT якщо потрібно. Встановлює `_sessionStartTime = DateTime.now()` |
| `continueSession(session, settings)` | Завантажує існуючі постріли, продовжує сесію. Встановлює `_sessionStartTime = DateTime.now()` |
| `triggerButton()` | Емуляція кнопки (запускає відлік) |
| `endSession()` | Зупиняє запис, акумулює `durationSec` (`existing + elapsed`), закриває сесію в БД |
| `setZoom(zoom)` | Передає зум у `VideoRecordingService` |
| `updateDetectionThreshold(v)` | Оновлює поріг та зберігає в налаштуваннях |

**Геттери:** `state`, `activeSession`, `shots`, `countdownRemaining`, `hasCameraPreview`, `detectionThreshold`, `amplitudeStream`, `cameraController`

**Внутрішня логіка:**
- `_onButtonPressed` → `_startCountdown` → `_startRecording` → `_onShotDetected` → `_finishRecording`
- `_finishRecording`: зберігає `Shot` з `durationMs = finalOffsetMs + postRollSec * 1000`, генерує thumbnail через `video_thumbnail`
- `_onTimeout` — скасовує запис без пострілу
- `_scheduleWarningBeeps()` — короткі звукові сигнали кожну секунду за 5 с до кінця таймауту
- `_sessionStartTime` — `DateTime?` для точного відстеження тривалості сегменту
- Дебаунс 2 с між пострілами (`AudioDetectionService`)

### `EquipmentProvider` (`ChangeNotifier`)
Файл: `providers/equipment_provider.dart`
Управляє списками `Rifle` і `Bullet` через репозиторії.

---

## Сервіси (`lib/services/`)

| Файл | Клас | Відповідальність |
|---|---|---|
| `audio_detection_service.dart` | `AudioDetectionService` | Мікрофон (WAV, 44100 Гц), стрім амплітуди кожні 50 мс, виклик `onShotDetected` при перевищенні порогу |
| `video_recording_service.dart` | `VideoRecordingService` | `CameraController` (висока якість, без аудіо), запис у `documents/shots/*.mp4` |
| `bluetooth_button_service.dart` | `BluetoothButtonService` | Підключення BT-брелока, колбек `onButtonPressed` |
| `sound_feedback_service.dart` | `SoundFeedbackService` | Звукові сигнали: `playCountdownBeep()`, `playStartRecording()`, `playTimeoutWarning()`, `playReady()`, `playCancel()` |
| `settings_service.dart` | `SettingsService` | `load()` / `save()` налаштувань через `SharedPreferences`; `saveCameraZoomRange` / `loadCameraZoomRange` |
| `physical_camera_service.dart` | `PhysicalCameraService` | `getBackCameras()` — перераховує фізичні камери через method channel `shotlog/physical_camera`; повертає `PhysicalCameraInfo` із оціночним зум-діапазоном |
| `weather_service.dart` | `WeatherService` | `fetchWeatherString()` — GPS + Open-Meteo API, повертає рядок погоди |
| `video_trim_service.dart` | `VideoTrimService` | Обрізання відеокліпів |

---

## Бази даних (`lib/database/`)

**Хелпер:** `DatabaseHelper` — синглтон, SQLite **v7**, файл `shotlog.db`

### Таблиці

```sql
rifles    (id, name, caliber, notes)
bullets   (id, name, weight_gr, caliber, velocity_ms, notes)
sessions  (id, name, created_at, ended_at, shot_count, rifle_id, bullet_id,
           distance_m, weather, notes, detection_dbfs, duration_sec)
shots     (id, session_id, shot_number, detected_at, clip_path,
           shot_offset_ms, thumbnail_path, trigger_dbfs, duration_ms)
```

**Міграції:**
- v1→v2: `trigger_dbfs`, `detection_dbfs`
- v2→v3: `sessions.name`
- v3→v4: виправлення схеми через PRAGMA
- v4→v5: `bullets.velocity_ms`
- v5→v6: `shots.duration_ms INTEGER`
- v6→v7: `sessions.duration_sec INTEGER`

| Репозиторій | Основні методи |
|---|---|
| `SessionRepository` | `insert`, `update`, `getAll`, `getById` |
| `ShotRepository` | `insert`, `getBySession`, **`updateDuration(shotId, durationMs)`** |
| `RifleRepository` | `insert`, `update`, `delete`, `getAll` |
| `BulletRepository` | `insert`, `update`, `delete`, `getAll` |

---

## Екрани (`lib/screens/`)

| Файл | Клас | Навігація |
|---|---|---|
| `splash_screen.dart` | `SplashScreen` | Стартовий екран → `MainShell` |
| `onboarding_screen.dart` | `OnboardingScreen` | Перший запуск |
| `main_shell.dart` | `MainShell` | `NavigationBar` з 3 вкладками: Сесії, Галерея, Статистика. Налаштування → `Navigator.push` |
| `home_screen.dart` | `HomeScreen` | Glass header, список сесій, FAB "Нова сесія". Фон: `ParallaxBg(bg_range.png)` + темний градієнт |
| `new_session_sheet.dart` | `showNewSessionScreen(context)` | Відкриває `NewSessionScreen` через `Navigator.push<Session>` |
| `new_session_sheet.dart` | `NewSessionScreen` | Повноекранний екран створення сесії. `ParallaxBg(bg_range.png)`. Glass header з `←` та `▶` (accent). 4 glass-картки: назва · спорядження · умови · нотатки. `_SelectorRow` для гвинтівки/набою — glass tile + `+` кнопка; тап відкриває `_GlassPickerSheet` (glass bottom sheet зі списком і checkmark для поточного вибору) |
| `session_screen.dart` | `SessionScreen` | Активна сесія: камера + оверлей стану + амплітуда |
| `session_detail_screen.dart` | `SessionDetailScreen` | Glass header (`[←][ℹ][▷]`), список пострілів (`ShotListItem`), `ParallaxBg(bg_range.png)`. `_InfoSheet` — glass bottom sheet з метаданими сесії + кнопка видалення. `_generateMissingThumbnails()` — lazy міграція thumbnail і `durationMs` для старих записів |
| `settings_screen.dart` | `SettingsScreen` | Фото-фон `ParallaxBg(bg_rifle.webp)` + frosted glass картки. Секції: "До пострілу", "Після пострілу", "Активація" (поріг гучності — синя іконка), "Камера", "Спорядження". `_CameraPickerSheet` — **повноекранний push** (`Navigator.push`), glass header з `←` та `✓` |
| `equipment_screen.dart` | `EquipmentScreen` | Повноекранний push (`showEquipmentSheet` → `Navigator.push`). `ParallaxBg(bg_rifle.webp)`. Glass header з табами Гвинтівки/Набої |

### Спільний патерн екранів

```
Scaffold(backgroundColor: transparent)
  Stack:
    ParallaxBg(asset)          ← паралакс фон
    Positioned.fill gradient   ← темний overlay
    ListView / Column          ← контент (padding: top + 76 + 8)
    Positioned(top:0) header   ← ClipRect → BackdropFilter blur:20
                                  → Container(transparent)
                                  → title + subtitle + glass buttons
```

---

## Віджети (`lib/widgets/`)

| Файл | Клас | Опис |
|---|---|---|
| `parallax_bg.dart` | `ParallaxBg` | Фоновий віджет з паралакс-ефектом від акселерометра. `ClipRect + Transform.translate + Transform.scale(1.12)`. Low-pass filter α=0.88, shift=18px. Параметри: `asset`, `fit`, `baseAlignment` |
| `threshold_picker.dart` | `showThresholdPicker(context, threshold)` | Відкриває `ThresholdScreen` через `Navigator.push<double>`. Повертає обраний dBFS або null |
| `threshold_picker.dart` | `ThresholdScreen` | Повноекранний екран налаштування порогу. `ParallaxBg(bg_rifle.webp)`. Glass header (`Поріг детекції` + `Тягніть від центру`). Радіальний drag-жест (`onPanUpdate` → `_handleRadialDrag`): компонента руху вздовж радіуса від центру змінює поріг. `←` скасовує, `✓` зберігає |
| `threshold_picker.dart` | `_RadialPainter` | `CustomPainter`: 7 шарів плавних замкнутих кривих з multi-harmonic spatial variation та 4-pass graduated stroke glow (без `MaskFilter`). Поточний рівень в центрі (велике число + "dB"). Поріг — frosted glass коло (1 glow pass з `MaskFilter.blur` + thin core). Chip з порогом на 11 годині на колі (frosted glass, рухається з колом). Колір: синій (запас > 15 dB) → amber → червоний (над порогом) |
| `audio_level_bar.dart` | `AudioLevelBar` | Компактна горизонтальна шкала 4 px |
| `session_state_overlay.dart` | `SessionStateOverlay` | Оверлей поверх камери: стан, відлік, кнопки |
| `video_player_overlay.dart` | `VideoPlayerOverlay` | Full-screen плеєр. Auto-hide controls (3 с): `AnimatedOpacity` + `AnimatedSlide`. Toggle: тап на відео-зону → `_toggleControls()`. `Listener(onPointerDown)` скидає таймер при будь-якому торканні поки контролі видимі. `IgnorePointer` для прозорих контролів |
| `shot_list_item.dart` | `ShotListItem` | Glass card (bg `0x26FFFFFF`, border `0x28FFFFFF`, radius 14). Thumbnail 96×64. Chips: `#N` (amber solid), time, duration mm:ss. `_showGlassConfirm` top-level для видалення |

### `_RadialPainter` деталі

- **Variation formula:** `0.46·sin(θ·2+φ) + 0.28·sin(θ·3+φ) + 0.16·sin(θ·5+φ) + 0.10·sin(θ·8+φ)` — per-layer phase offset `li * 0.55`
- **Glow passes per layer:** outer halo 28px/α0.04 → mid 10px/α0.10 → inner 3.5px/α0.20 → core 0.8px/α0.50
- **Threshold ring:** `MaskFilter.blur(normal, 12)` на 20px stroke + thin core 0.8px — обидва neutral white
- **Chip at 11 o'clock:** `angle = -π/2 - π/6`, center at `threshR + chipH/2 + 10`, offset -6px left/up
- **Drag:** `onPanUpdate` → dot product of delta and radial direction → `dbDelta = (radialDelta / maxR) * 80`
- **shouldRepaint:** перевіряє `phase`, `threshDb`, `history.last`

---

## Паралакс (`ParallaxBg`)

| Екран | Asset | `baseAlignment` |
|---|---|---|
| HomeScreen | `bg_range.png` | `Alignment.topCenter` |
| NewSessionScreen | `bg_range.png` | `Alignment.topCenter` |
| SessionDetailScreen | `bg_range.png` | `Alignment.topCenter` |
| SettingsScreen | `bg_rifle.webp` | `Alignment(0.2, -1.0)` |
| EquipmentScreen | `bg_rifle.webp` | `Alignment(0.2, -1.0)` |
| ThresholdScreen | `bg_rifle.webp` | `Alignment(0.2, -1.0)` |

---

## Потік даних

```
BluetoothButtonService ──onButtonPressed──► SessionProvider
                                                │
                          triggerButton()  ◄────┘ (UI кнопка)
                                                │
                               _startCountdown()
                                                │
                               _startRecording()
                               ├── VideoRecordingService.startRecording()
                               └── AudioDetectionService.start()
                                        │
                              onShotDetected ──► _onShotDetected()
                                                      │
                                         _finishRecording()
                                         ├── VideoRecordingService.stopRecording()
                                         ├── ShotRepository.insert(shot w/ durationMs)
                                         ├── VideoThumbnail.thumbnailFile(...)
                                         └── SessionRepository.update()
                                                      │
                               endSession()
                               ├── durationSec += DateTime.now() - _sessionStartTime
                               └── SessionRepository.update(durationSec)
```

---

## Зберігання файлів

| Що | Де |
|---|---|
| Відеокліпи | `getApplicationDocumentsDirectory()/shots/<timestamp>.mp4` |
| Thumbnails | `getApplicationDocumentsDirectory()/thumbs/<shotId>.jpg` |
| БД | SQLite `shotlog.db` у стандартній директорії SQLite |
| Налаштування | `SharedPreferences` |
| Тимчасові WAV (аудіо детекція) | `getTemporaryDirectory()` — видаляються після запису |
| Тимчасові WAV (threshold picker) | `getTemporaryDirectory()/thresh_<timestamp>.wav` — видаляються в `dispose()` |

---

## Активи (`assets/`)

| Шлях | Призначення |
|---|---|
| `assets/icons/active/` | Іконки навігаційної панелі (активний стан) |
| `assets/icons/inactive/` | Іконки навігаційної панелі (неактивний стан) |
| `assets/images/bg_rifle.webp` | Фото гвинтівки — фон Settings, Equipment, ThresholdScreen |
| `assets/images/bg_range.png` | Фото стрільбища — фон HomeScreen, SessionDetailScreen |
