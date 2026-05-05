# ShotLog — CLAUDE.md

## Мова спілкування

Завжди відповідай українською мовою.

## Карта кодової бази

**Перед виконанням будь-якого завдання прочитай `CODEBASE_MAP.md`** — там описані всі файли, класи, методи та потік даних. Це економить токени: не потрібно досліджувати структуру з нуля.

**Після внесення змін у код оновлюй `CODEBASE_MAP.md`** — якщо додано новий файл, клас, метод, поле моделі, залежність або змінено архітектуру, відповідний розділ карти має бути оновлений одразу в тому самому кроці.

## Про проєкт

Flutter-застосунок для спортивних стрільців. Записує відео кожного пострілу, зберігає статистику, підтримує кілька режимів запуску запису.

- **Платформа:** Android (iOS не підтримується)
- **Flutter SDK:** ^3.9.2
- **Мінімальний Android SDK:** 21

## Архітектура

```
lib/
  main.dart
  app.dart
  models/          # AppSettings, Session, Shot, Rifle, Bullet
  providers/       # SessionProvider, EquipmentProvider (ChangeNotifier)
  services/        # AudioDetectionService, VideoRecordingService,
                   # BluetoothButtonService, SoundFeedbackService, SettingsService
  screens/         # SessionScreen, SettingsScreen, HomeScreen, …
  widgets/         # ThresholdPicker, AudioLevelBar, SessionStateOverlay, …
  database/        # SQLite через sqflite (RifleRepository, SessionRepository, …)
```

## Ключові залежності

| Пакет | Призначення |
|---|---|
| `camera` | Запис відео |
| `record` | Захоплення аудіо та детекція амплітуди |
| `sqflite` | Локальна база даних |
| `provider` | Управління станом |
| `audioplayers` | Звуковий зворотній зв'язок |
| `shared_preferences` | Зберігання налаштувань |

## Режими запуску запису (`TriggerMode`)

- `button` — кнопка в застосунку
- `bluetooth` — Bluetooth-брелок

## Налаштування (`AppSettings`)

Зберігаються через `SettingsService` (shared_preferences).
Ключові поля: `countdownSec`, `timeoutSec`, `postRollSec`, `preRollSec`, `detectionDbfs`, `triggerMode`.

## VU-метр / поріг детекції

`threshold_picker.dart` — модальне вікно з VU-метром.
Шкала: −80…0 dBFS. Зверху є відступ `_kMeterTopPad = 24.0` (половина висоти смуги перетягування), щоб індикатор не виходив за межі при рівні 0 dBFS.
