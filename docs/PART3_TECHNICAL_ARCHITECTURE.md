# POCKET DETECTIVE — Technical Architecture

**Version:** 1.0
**Date:** 2026-02-23
**Engine Recommendation:** Godot 4.x (GDScript) or Unity (C#)
**Architecture:** Data-Driven, Offline-First, Modular

---

## 1. FOLDER STRUCTURE

```
PocketDetective/
├── project.godot                    # Engine project file
│
├── assets/
│   ├── fonts/                       # UI fonts
│   ├── audio/
│   │   ├── sfx/                     # Sound effects (tap, notification, reveal)
│   │   └── music/                   # Background ambient tracks
│   ├── ui/
│   │   ├── icons/                   # App icons, status icons
│   │   ├── backgrounds/             # Phone wallpapers, board textures
│   │   └── components/              # Button styles, frames, bubbles
│   └── characters/
│       └── portraits/               # Suspect portraits by emotion
│           ├── suspect_001_calm.png
│           ├── suspect_001_nervous.png
│           └── ...
│
├── cases/                           # ★ DATA-DRIVEN CASE CONTENT ★
│   ├── case_001/
│   │   ├── case.json                # Complete case definition
│   │   ├── images/
│   │   │   ├── photo_001.png
│   │   │   ├── photo_002.png
│   │   │   └── ...
│   │   └── portraits/
│   │       ├── sophie_calm.png
│   │       ├── sophie_nervous.png
│   │       └── ...
│   ├── case_002/
│   │   ├── case.json
│   │   ├── images/
│   │   └── portraits/
│   └── case_003/
│       └── ...
│
├── src/
│   ├── core/                        # Core systems (always loaded)
│   │   ├── GameManager.gd           # Global state, lifecycle
│   │   ├── CaseLoader.gd            # Loads & parses case JSON
│   │   ├── SaveManager.gd           # Save/load player progress
│   │   ├── StateManager.gd          # Current investigation state
│   │   ├── EventBus.gd              # Global event system (signals)
│   │   └── HintManager.gd           # Hint logic & economy
│   │
│   ├── systems/                     # Game mechanic systems
│   │   ├── EvidenceSystem.gd        # Evidence discovery & validation
│   │   ├── DialogueManager.gd       # Conversation tree traversal
│   │   ├── InterrogationSystem.gd   # Interrogation logic
│   │   ├── BoardSystem.gd           # Evidence board connections
│   │   ├── AccusationSystem.gd      # Accusation validation
│   │   ├── NotificationSystem.gd    # In-game phone notifications
│   │   ├── EnergySystem.gd          # Stamina management
│   │   └── DailyPuzzleSystem.gd     # Daily mini-game logic
│   │
│   ├── ui/                          # UI scenes and scripts
│   │   ├── phone/
│   │   │   ├── PhoneFrame.tscn      # Main phone frame (always visible)
│   │   │   ├── HomeScreen.tscn      # App grid home screen
│   │   │   ├── StatusBar.tscn       # Top status bar
│   │   │   └── NotificationPopup.tscn
│   │   ├── apps/
│   │   │   ├── MessagesApp.tscn     # Chat list + thread view
│   │   │   ├── PhotosApp.tscn       # Photo gallery + inspection
│   │   │   ├── CallsApp.tscn        # Call log
│   │   │   ├── ContactsApp.tscn     # Contact profiles
│   │   │   ├── BoardApp.tscn        # Evidence board
│   │   │   ├── NotesApp.tscn        # Player notes
│   │   │   ├── CaseFileApp.tscn     # Case overview
│   │   │   └── DailyApp.tscn        # Daily puzzle
│   │   ├── interrogation/
│   │   │   ├── InterrogationScreen.tscn
│   │   │   └── SuspectPortrait.tscn
│   │   ├── accusation/
│   │   │   ├── AccusationScreen.tscn
│   │   │   └── ResolutionScreen.tscn
│   │   └── common/
│   │       ├── ChatBubble.tscn      # Reusable message bubble
│   │       ├── EvidenceCard.tscn    # Reusable evidence display
│   │       ├── SuspectCard.tscn     # Reusable suspect display
│   │       └── HintPopup.tscn       # Hint UI
│   │
│   └── data/                        # Static data & schemas
│       ├── detective_ranks.json     # Rank progression table
│       ├── daily_puzzles.json       # Daily puzzle pool
│       └── settings_defaults.json   # Default settings
│
├── saves/                           # Player save files (runtime)
│   ├── player_profile.json          # Rank, coins, settings
│   └── case_progress/
│       ├── case_001_save.json       # Per-case progress
│       └── ...
│
└── schemas/                         # JSON validation schemas
    ├── case_schema.json             # Case format specification
    └── save_schema.json             # Save format specification
```

---

## 2. SCREEN / SCENE MANAGEMENT

### 2.1 Scene Hierarchy

```
Root
└── GameManager (AutoLoad Singleton)
    ├── EventBus (AutoLoad Singleton)
    ├── SaveManager (AutoLoad Singleton)
    ├── StateManager (AutoLoad Singleton)
    └── PhoneFrame (Main Scene)
        ├── StatusBar (always visible)
        ├── AppContainer (swappable content area)
        │   ├── HomeScreen
        │   ├── MessagesApp
        │   ├── PhotosApp
        │   ├── ... (one active at a time)
        │   └── InterrogationScreen
        ├── NotificationOverlay
        └── HintOverlay
```

### 2.2 Screen Transitions

Instead of switching Godot scenes, we use a **single-scene architecture** with swappable content:

```gdscript
# ScreenManager logic (inside PhoneFrame)
var current_app: Control = null

func open_app(app_name: String) -> void:
    if current_app:
        current_app.queue_free()

    var app_scene = load("res://src/ui/apps/%sApp.tscn" % app_name)
    current_app = app_scene.instantiate()
    $AppContainer.add_child(current_app)

    EventBus.emit_signal("app_opened", app_name)

func go_home() -> void:
    open_app("HomeScreen")
```

### 2.3 App Lifecycle

Each app scene follows a standard lifecycle:

```gdscript
# Base pattern for all apps
func _ready():
    load_data()      # Pull relevant data from StateManager
    build_ui()       # Construct UI from data
    connect_events() # Listen for EventBus signals

func _exit_tree():
    save_state()     # Persist any changes before removal
```

---

## 3. SAVE & LOAD SYSTEM

### 3.1 Save Architecture

Two types of save data:

| Type | File | Contents |
|---|---|---|
| **Player Profile** | `player_profile.json` | Rank, hint coins, energy, settings, completed cases |
| **Case Progress** | `case_XXX_save.json` | Per-case: discovered clues, board state, dialogue progress |

### 3.2 Save Triggers

- **Auto-save** on every significant action (clue discovered, connection made, dialogue choice).
- **No manual save button** — the game always feels current.
- Save operations are **asynchronous** and **non-blocking**.

### 3.3 Player Profile Schema

```json
{
  "version": "1.0",
  "detective_name": "Player",
  "rank": "junior_detective",
  "cases_completed": 2,
  "total_stars": 5,
  "hint_coins": 12,
  "energy": {
    "current": 4,
    "max": 5,
    "last_regen_time": "2026-02-23T14:30:00Z"
  },
  "completed_cases": ["case_001", "case_002"],
  "current_case": "case_003",
  "daily_puzzle": {
    "last_completed": "2026-02-22",
    "streak": 3
  },
  "settings": {
    "sfx_volume": 0.8,
    "music_volume": 0.5,
    "language": "fr"
  },
  "unlocked_wallpapers": ["default", "noir"],
  "statistics": {
    "total_clues_found": 34,
    "total_connections_made": 18,
    "total_interrogations": 8,
    "perfect_cases": 1
  }
}
```

### 3.4 Case Progress Schema

```json
{
  "case_id": "case_003",
  "version": "1.0",
  "started_at": "2026-02-23T10:00:00Z",
  "last_played": "2026-02-23T14:30:00Z",
  "phase": "investigation",
  "discovered_clues": ["clue_001", "clue_003", "clue_005"],
  "board_state": {
    "pinned_clues": ["clue_001", "clue_003"],
    "connections": [
      {"from": "clue_001", "to": "clue_003", "valid": true}
    ]
  },
  "dialogue_state": {
    "suspect_001": {
      "nodes_visited": ["start", "q1", "q1a"],
      "current_node": "q1a"
    }
  },
  "interrogations_unlocked": ["suspect_001", "suspect_002"],
  "notifications_seen": ["notif_001", "notif_002"],
  "hints_used": 1,
  "wrong_accusations": 0,
  "notes": "Sophie lied about being home — GPS shows café"
}
```

### 3.5 Save Manager Implementation

```gdscript
# SaveManager.gd (AutoLoad Singleton)
const SAVE_PATH = "user://saves/"
const PROFILE_FILE = "player_profile.json"

func save_profile(profile: Dictionary) -> void:
    var path = SAVE_PATH + PROFILE_FILE
    _write_json(path, profile)

func load_profile() -> Dictionary:
    var path = SAVE_PATH + PROFILE_FILE
    if FileAccess.file_exists(path):
        return _read_json(path)
    return _default_profile()

func save_case_progress(case_id: String, progress: Dictionary) -> void:
    var path = SAVE_PATH + "case_progress/%s_save.json" % case_id
    _write_json(path, progress)

func load_case_progress(case_id: String) -> Dictionary:
    var path = SAVE_PATH + "case_progress/%s_save.json" % case_id
    if FileAccess.file_exists(path):
        return _read_json(path)
    return {}

func _write_json(path: String, data: Dictionary) -> void:
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var file = FileAccess.open(path, FileAccess.WRITE)
    file.store_string(JSON.stringify(data, "  "))
    file.close()

func _read_json(path: String) -> Dictionary:
    var file = FileAccess.open(path, FileAccess.READ)
    var text = file.get_as_text()
    file.close()
    var json = JSON.new()
    json.parse(text)
    return json.data
```

---

## 4. OFFLINE DATA STORAGE

### 4.1 Storage Strategy

| Data Type | Location | Format | Access |
|---|---|---|---|
| Case content | `res://cases/` | JSON + images | Read-only (bundled) |
| Player saves | `user://saves/` | JSON | Read/Write |
| Static data | `res://src/data/` | JSON | Read-only (bundled) |
| Settings | `user://saves/` | JSON | Read/Write |

### 4.2 Key Principles

1. **Case data is bundled** with the app. No downloads needed.
2. **Player data is in `user://`** which persists across app updates on Android.
3. **No encryption needed** for offline single-player (unless piracy concern — then simple XOR/base64 on save files).
4. **JSON parsing** is done at case load time, not at runtime. Data is held in memory as dictionaries.

### 4.3 Memory Management

For low-end devices (2GB RAM):
- Load only the **active case** into memory.
- Images are loaded **on-demand** when the player opens the Photos app.
- Portraits are loaded when entering an interrogation and freed when leaving.
- Case list screen shows only metadata (title, thumbnail) not full case data.

---

## 5. PLUG-AND-PLAY CASE LOADER

### 5.1 How It Works

The game scans the `res://cases/` directory for case folders. Each folder must contain a `case.json` file. No code changes needed.

```
cases/
├── case_001/case.json   ← Detected automatically
├── case_002/case.json   ← Detected automatically
├── case_003/case.json   ← Just drop it here, it works
└── case_004/case.json   ← New case added!
```

### 5.2 Case Discovery

```gdscript
# CaseLoader.gd
func discover_cases() -> Array:
    var cases = []
    var dir = DirAccess.open("res://cases/")
    if dir:
        dir.list_dir_begin()
        var folder = dir.get_next()
        while folder != "":
            if dir.current_is_dir() and folder.begins_with("case_"):
                var case_path = "res://cases/%s/case.json" % folder
                if FileAccess.file_exists(case_path):
                    var metadata = _load_case_metadata(case_path)
                    cases.append(metadata)
            folder = dir.get_next()
    cases.sort_custom(func(a, b): return a.order < b.order)
    return cases
```

### 5.3 Case Loading

```gdscript
func load_full_case(case_id: String) -> Dictionary:
    var path = "res://cases/%s/case.json" % case_id
    var json_text = FileAccess.open(path, FileAccess.READ).get_as_text()
    var json = JSON.new()
    json.parse(json_text)
    var case_data = json.data

    # Resolve image paths
    for photo in case_data.evidence.photos:
        photo.image_path = "res://cases/%s/images/%s" % [case_id, photo.filename]

    for suspect in case_data.suspects:
        for emotion in suspect.portraits:
            suspect.portraits[emotion] = "res://cases/%s/portraits/%s" % [case_id, suspect.portraits[emotion]]

    return case_data
```

### 5.4 Adding a New Case (Zero Code)

**Steps for a content creator:**

1. Create folder: `cases/case_004/`
2. Add `case.json` following the schema (see Part 4)
3. Add images to `cases/case_004/images/`
4. Add portraits to `cases/case_004/portraits/`
5. Rebuild the app (or, for testing, hot-reload)

**That's it.** The CaseLoader detects it, the UI lists it, the systems load it.

---

## 6. STATE MANAGEMENT

### 6.1 Global State Architecture

```
┌──────────────────┐
│   GameManager     │  ← Lifecycle, init, transitions
│   (Singleton)     │
└────────┬─────────┘
         │
    ┌────▼─────────────────────────┐
    │        StateManager          │  ← Central state store
    │        (Singleton)           │
    ├──────────────────────────────┤
    │  player_profile: Dictionary  │
    │  current_case: Dictionary    │
    │  case_progress: Dictionary   │
    │  ui_state: Dictionary        │
    └────────┬─────────────────────┘
             │ reads/writes
    ┌────────▼─────────────────────┐
    │        EventBus              │  ← Decoupled communication
    │        (Singleton)           │
    ├──────────────────────────────┤
    │  signal clue_discovered      │
    │  signal connection_made      │
    │  signal interrogation_start  │
    │  signal accusation_made      │
    │  signal hint_requested       │
    │  signal app_opened           │
    │  signal notification_fired   │
    │  signal case_completed       │
    │  signal energy_changed       │
    └──────────────────────────────┘
```

### 6.2 EventBus Pattern

All systems communicate through the EventBus. No system directly references another.

```gdscript
# EventBus.gd (AutoLoad Singleton)
signal clue_discovered(clue_id: String)
signal connection_made(from_id: String, to_id: String, valid: bool)
signal connection_required_met()
signal interrogation_started(suspect_id: String)
signal dialogue_choice_made(node_id: String, choice_id: String)
signal accusation_submitted(suspect_id: String, evidence: Array)
signal case_completed(case_id: String, stars: int)
signal hint_used(hint_type: String, cost: int)
signal notification_fired(notification_id: String)
signal app_opened(app_name: String)
signal energy_changed(current: int, max_val: int)
signal coins_changed(amount: int)
```

### 6.3 State Flow Example

```
Player taps highlighted text in a message
  → MessagesApp detects clue tap
  → MessagesApp calls: StateManager.discover_clue("clue_003")
  → StateManager updates case_progress.discovered_clues
  → StateManager calls: SaveManager.save_case_progress(...)
  → StateManager emits: EventBus.clue_discovered.emit("clue_003")
  → NotificationSystem hears signal → shows "New evidence found!"
  → BoardApp hears signal → adds clue to available pool
  → InterrogationSystem hears signal → unlocks new questions
  → HintManager hears signal → updates available hints
```

### 6.4 No Direct Dependencies

```
MessagesApp ──X──▶ BoardApp          ← WRONG (tight coupling)
MessagesApp ──▶ EventBus ──▶ BoardApp  ← RIGHT (decoupled)
```

This architecture means:
- Any app can be removed or replaced without breaking others.
- New systems can be added by simply listening to existing events.
- Case JSON drives the behavior — the code is generic.
