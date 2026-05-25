# CODEBASE_MAP.md — ShotLog

## Точка входу

| Файл | Роль |
|---|---|
| `lib/main.dart` | `runApp(ShotLogApp())` |
| `lib/app.dart` | `ShotLogApp` — `MultiProvider` + `MaterialApp`, визначення теми |

**Тема:** темна, акцент `#E87722` (помаранчевий), фон `#1A1210`.

---

## Моделі (`lib/models/`)

| Файл | Клас | Ключові поля |
|---|---|---|
| `app_settings.dart` | `AppSettings` (immutable) | `countdownSec`, `timeoutSec`, `postRollSec`, `preRollSec`, `detectionDbfs` (-20.0), `triggerMode`, `selectedCameraId` (""), `cameraZoomMin` (0.0), `cameraZoomMax` (0.0) |
| `app_settings.dart` | `TriggerMode` (enum) | `button`, `bluetooth` |
| `session.dart` | `Session` | `id`, `name`, `createdAt`, `endedAt`, `shotCount`, `rifleId`, `bulletId`, `distanceM`, `weather`, `notes`, `detectionDbfs` |
| `shot.dart` | `Shot` | `id`, `sessionId`, `shotNumber`, `detectedAt`, `clipPath`, `shotOffsetMs`, `thumbnailPath`, `triggerDbfs` |
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
| `startSession(session, settings)` | Ініціалізує камеру, вставляє сесію в БД, запускає BT якщо потрібно |
| `continueSession(session, settings)` | Завантажує існуючі постріли, продовжує сесію |
| `triggerButton()` | Емуляція кнопки (запускає відлік) |
| `endSession()` | Зупиняє запис, закриває сесію в БД |
| `setZoom(zoom)` | Передає зум у `VideoRecordingService` |
| `updateDetectionThreshold(v)` | Оновлює поріг та зберігає в налаштуваннях |

**Геттери:** `state`, `activeSession`, `shots`, `countdownRemaining`, `hasCameraPreview`, `detectionThreshold`, `amplitudeStream`, `cameraController`

**Внутрішня логіка:**
- `_onButtonPressed` → `_startCountdown` → `_startRecording` → `_onShotDetected` → `_finishRecording`
- `_onTimeout` — скасовує запис без пострілу
- `_scheduleWarningBeeps()` — короткі звукові сигнали кожну секунду за 5 с до кінця таймауту
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
| `sound_feedback_service.dart` | `SoundFeedbackService` | Звукові сигнали: `playCountdownBeep()`, `playStartRecording()` (довгий), `playTimeoutWarning()` (короткий низький), `playReady()`, `playCancel()` |
| `settings_service.dart` | `SettingsService` | `load()` / `save()` налаштувань через `SharedPreferences` |
| `physical_camera_service.dart` | `PhysicalCameraService` | `getBackCameras()` — перераховує фізичні камери через method channel `shotlog/physical_camera`; повертає `PhysicalCameraInfo` із оціночним зум-діапазоном на основі фокусних відстаней |
| `weather_service.dart` | `WeatherService` | `fetchWeatherString()` — GPS + Open-Meteo API, повертає рядок `'Т: +12°C · Вітер: 3.2 м/с ПнЗх · Вол.: 65% · Тиск: 1013 гПа'` |

**`AudioDetectionService` деталі:**
- `amplitudeStream` — broadcast Stream<double> (dBFS)
- `lastDbfs` — останнє значення
- `updateThreshold(v)` — оновити поріг без перезапуску
- Дебаунс 2 с після виявлення пострілу
- Тимчасовий WAV-файл видаляється при `stop()`

**`VideoRecordingService` деталі:**
- `initialize({cameraId})` — відкриває камеру за Android Camera2 ID (строка); якщо ID не в `availableCameras()`, пробує відкрити фізичну камеру напряму; при помилці — fallback на першу задню логічну
- Зберігає кліпи: `getApplicationDocumentsDirectory()/shots/<timestamp>.mp4`
- `stopRecording({delete: true})` — видаляє файл (таймаут/скасування)
- `setZoom(zoom)` — передає `setZoomLevel` у `CameraController`

---

## Бази даних (`lib/database/`)

**Хелпер:** `DatabaseHelper` — синглтон, SQLite v5, файл `shotlog.db`

### Таблиці

```sql
rifles    (id, name, caliber, notes)
bullets   (id, name, weight_gr, caliber, velocity_ms, notes)
sessions  (id, name, created_at, ended_at, shot_count, rifle_id, bullet_id,
           distance_m, weather, notes, detection_dbfs)
shots     (id, session_id, shot_number, detected_at, clip_path,
           shot_offset_ms, thumbnail_path, trigger_dbfs)
```

**Міграції:** v1→v2: `trigger_dbfs`, `detection_dbfs`; v2→v3: `sessions.name`; v3→v4: виправлення схеми через PRAGMA; v4→v5: `bullets.velocity_ms`

| Репозиторій | Основні методи |
|---|---|
| `SessionRepository` | `insert`, `update`, `getAll`, `getById` |
| `ShotRepository` | `insert`, `getBySession` |
| `RifleRepository` | `insert`, `update`, `delete`, `getAll` |
| `BulletRepository` | `insert`, `update`, `delete`, `getAll` |

---

## Екрани (`lib/screens/`)

| Файл | Клас | Навігація |
|---|---|---|
| `splash_screen.dart` | `SplashScreen` | Стартовий екран → `MainShell` |
| `main_shell.dart` | `MainShell` | `NavigationBar` з 3 вкладками |
| `home_screen.dart` | `HomeScreen` | Список сесій, кнопка нової сесії |
| `new_session_sheet.dart` | `NewSessionSheet` | Bottom sheet вибору гвинтівки/набою/дистанції |
| `session_screen.dart` | `SessionScreen` | Активна сесія: камера + оверлей стану + амплітуда |
| `session_detail_screen.dart` | `SessionDetailScreen` | Перегляд пострілів сесії |
| `settings_screen.dart` | `SettingsScreen` | Таймінги, тригер, поріг, камера (вибір об'єктива), спорядження |
| `equipment_screen.dart` | `EquipmentScreen` | CRUD гвинтівок та набоїв |
| `onboarding_screen.dart` | `OnboardingScreen` | Перший запуск |

**`SessionScreen` внутрішні віджети:**
- `_CameraView` — `CameraPreview` + zoom gesture
- `_AmplitudePanel` — горизонтальна шкала амплітуди 14 px з порогом
- `_BottomBar` — кнопка тригера / стан / лічильник

---

## Віджети (`lib/widgets/`)

| Файл | Клас | Опис |
|---|---|---|
| `threshold_picker.dart` | `showThresholdPicker()` | Модальний VU-метр −80…0 dBFS; поріг перетягуванням |
| `threshold_picker.dart` | `_VuMeterPainter` | `CustomPainter`: фон, сітка, рівень-бар, пунктирна лінія, кружок-хендл |
| `threshold_picker.dart` | `_DbLabels` | Підписи dB на шкалі |
| `audio_level_bar.dart` | `AudioLevelBar` | Компактна горизонтальна шкала 4 px (зелений/червоний + помаранчева лінія порогу) |
| `session_state_overlay.dart` | `SessionStateOverlay` | Оверлей поверх камери: стан, відлік, кнопки |
| `video_player_overlay.dart` | `VideoPlayerOverlay` — | Вбудований плеєр кліпу |
| `shot_list_item.dart` | `ShotListItem` | Елемент списку пострілу з мініатюрою |

**`threshold_picker.dart` нюанс:**
`_kMeterTopPad = 24.0` — відступ зверху (половина висоти смуги перетягування 48 px).
Без нього при рівні 0 dBFS кружок-хендл виходить за межі віджета.

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
                                         ├── ShotRepository.insert()
                                         └── SessionRepository.update()
```

---

## Зберігання файлів

| Що | Де |
|---|---|
| Відеокліпи | `getApplicationDocumentsDirectory()/shots/<timestamp>.mp4` |
| БД | SQLite `shotlog.db` у стандартній директорії SQLite |
| Налаштування | `SharedPreferences` |
| Тимчасові WAV | `getTemporaryDirectory()` — видаляються після запису |
