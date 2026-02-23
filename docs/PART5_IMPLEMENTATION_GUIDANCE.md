# POCKET DETECTIVE — Implementation Guidance

**Version:** 1.0
**Date:** 2026-02-23
**Engine:** Godot 4.x (GDScript)

---

## 1. DEVELOPMENT ENVIRONMENT SETUP

### 1.1 Requirements

| Tool | Version | Purpose |
|---|---|---|
| Godot Engine | 4.2+ | Game engine |
| Android SDK | API 21+ | Android export |
| Git | Latest | Version control |
| VS Code + Godot extension | Latest | Code editing (optional) |

### 1.2 Project Settings (project.godot)

```ini
[application]
config/name="Pocket Detective"
run/main_scene="res://src/ui/phone/PhoneFrame.tscn"
config/features=PackedStringArray("4.2")

[display]
window/size/viewport_width=1080
window/size/viewport_height=1920
window/stretch/mode="canvas_items"
window/stretch/aspect="keep_width"
window/handheld/orientation="portrait"

[autoload]
EventBus="*res://src/core/EventBus.gd"
GameManager="*res://src/core/GameManager.gd"
SaveManager="*res://src/core/SaveManager.gd"
StateManager="*res://src/core/StateManager.gd"
HintManager="*res://src/core/HintManager.gd"

[input]
touch_tap={
"deadzone": 0.5,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":1,"position":Vector2(0,0),"global_position":Vector2(0,0),"factor":1.0,"button_index":1,"canceled":false,"pressed":true,"double_click":false)]
}

[rendering]
renderer/rendering_method="mobile"
textures/vram_compression/import_etc2_astc=true
```

---

## 2. AUTOLOAD SINGLETONS — IMPLEMENTATION ORDER

Build in this order. Each step builds on the previous.

### Step 1: EventBus (no dependencies)
### Step 2: SaveManager (no dependencies)
### Step 3: StateManager (depends on SaveManager, EventBus)
### Step 4: HintManager (depends on StateManager, EventBus)
### Step 5: GameManager (depends on all above)

---

## 3. CORE IMPLEMENTATION PATTERNS

### 3.1 Signal-Driven Architecture

Every system communicates via EventBus signals. Never call methods directly between systems.

```gdscript
# WRONG — tight coupling
func _on_clue_found():
    BoardSystem.add_clue(clue)
    NotificationSystem.show("New clue!")

# RIGHT — decoupled via signals
func _on_clue_found():
    EventBus.clue_discovered.emit(clue_id)
    # BoardSystem and NotificationSystem listen independently
```

### 3.2 Data Access Pattern

All game data flows through StateManager. UI never accesses case JSON directly.

```gdscript
# WRONG
func show_messages():
    var case_json = CaseLoader.load("case_001")
    var messages = case_json.evidence.messages

# RIGHT
func show_messages():
    var messages = StateManager.get_current_case().evidence.messages
```

### 3.3 UI Update Pattern

UI listens to EventBus signals and updates reactively.

```gdscript
# In any UI component
func _ready():
    EventBus.clue_discovered.connect(_on_clue_discovered)
    EventBus.coins_changed.connect(_on_coins_changed)
    _refresh_display()

func _on_clue_discovered(clue_id: String):
    _refresh_display()
```

---

## 4. PHONE FRAME ARCHITECTURE

The PhoneFrame is the root scene that never changes. Apps swap inside it.

### 4.1 PhoneFrame Scene Structure

```
PhoneFrame (Control - full screen)
├── Background (TextureRect - phone wallpaper)
├── StatusBar (HBoxContainer)
│   ├── SignalIcon (TextureRect)
│   ├── TimeLabel (Label)
│   └── BatteryIcon (TextureRect)
├── AppContainer (Control - app content area)
│   └── [Active App Scene]
├── BottomNav (HBoxContainer)
│   ├── HomeButton (TextureButton)
│   ├── BoardButton (TextureButton)
│   └── BackButton (TextureButton)
├── NotificationOverlay (Control)
│   └── NotificationPopup (PanelContainer)
└── HintOverlay (Control)
    └── HintPopup (PanelContainer)
```

### 4.2 Screen Manager Implementation

```gdscript
# PhoneFrame.gd
extends Control

var current_app: Control = null
var app_history: Array[String] = []

@onready var app_container = $AppContainer
@onready var status_bar = $StatusBar
@onready var notification_overlay = $NotificationOverlay

func _ready():
    EventBus.app_opened.connect(_log_app)
    open_app("HomeScreen")

func open_app(app_name: String) -> void:
    if current_app:
        current_app.queue_free()
        await current_app.tree_exited

    var scene_path = _get_app_scene_path(app_name)
    var scene = load(scene_path)
    if scene:
        current_app = scene.instantiate()
        app_container.add_child(current_app)
        app_history.push_back(app_name)
        EventBus.app_opened.emit(app_name)

func go_back() -> void:
    if app_history.size() > 1:
        app_history.pop_back()
        var previous = app_history.pop_back()
        open_app(previous)
    else:
        open_app("HomeScreen")

func _get_app_scene_path(app_name: String) -> String:
    var paths = {
        "HomeScreen": "res://src/ui/phone/HomeScreen.tscn",
        "Messages": "res://src/ui/apps/MessagesApp.tscn",
        "Photos": "res://src/ui/apps/PhotosApp.tscn",
        "Calls": "res://src/ui/apps/CallsApp.tscn",
        "Contacts": "res://src/ui/apps/ContactsApp.tscn",
        "Board": "res://src/ui/apps/BoardApp.tscn",
        "Notes": "res://src/ui/apps/NotesApp.tscn",
        "CaseFile": "res://src/ui/apps/CaseFileApp.tscn",
        "Daily": "res://src/ui/apps/DailyApp.tscn",
    }
    return paths.get(app_name, paths["HomeScreen"])

func _log_app(app_name: String) -> void:
    pass  # Analytics/logging hook
```

---

## 5. KEY SYSTEM IMPLEMENTATIONS

### 5.1 Evidence Discovery Flow

```gdscript
# EvidenceSystem.gd
extends Node

func try_discover_clue(clue_id: String) -> bool:
    var case_data = StateManager.get_current_case()
    var progress = StateManager.get_case_progress()

    # Already discovered?
    if clue_id in progress.discovered_clues:
        return false

    # Find clue definition
    var clue = _find_clue(case_data, clue_id)
    if not clue:
        return false

    # Discover it
    progress.discovered_clues.append(clue_id)
    StateManager.save_progress()
    EventBus.clue_discovered.emit(clue_id)

    # Check if discovery triggers notifications
    _check_notification_triggers(clue_id)

    return true

func _find_clue(case_data: Dictionary, clue_id: String) -> Dictionary:
    for clue in case_data.clues:
        if clue.id == clue_id:
            return clue
    return {}

func _check_notification_triggers(clue_id: String) -> void:
    var case_data = StateManager.get_current_case()
    for notif in case_data.notifications:
        if notif.trigger is Dictionary and notif.trigger.has("clue_discovered"):
            if notif.trigger.clue_discovered == clue_id:
                EventBus.notification_fired.emit(notif.id)
```

### 5.2 Board Connection Logic

```gdscript
# BoardSystem.gd
extends Node

func try_connect(from_clue: String, to_clue: String) -> Dictionary:
    var case_data = StateManager.get_current_case()
    var result = {"valid": false, "type": "none", "description": ""}

    # Check if this connection is defined
    for conn in case_data.connections:
        if (conn.from == from_clue and conn.to == to_clue) or \
           (conn.from == to_clue and conn.to == from_clue):
            result.valid = true
            result.type = conn.type
            result.description = conn.description

            # Save connection
            var progress = StateManager.get_case_progress()
            progress.board_state.connections.append({
                "from": from_clue,
                "to": to_clue,
                "valid": true
            })
            StateManager.save_progress()

            # Emit signal
            EventBus.connection_made.emit(from_clue, to_clue, true)

            # Check unlocks
            if conn.has("unlocks"):
                for unlock in conn.unlocks:
                    EventBus.notification_fired.emit(unlock)

            # Check if all required connections are met
            _check_required_connections()
            break

    if not result.valid:
        EventBus.connection_made.emit(from_clue, to_clue, false)

    return result

func _check_required_connections() -> void:
    var case_data = StateManager.get_current_case()
    var progress = StateManager.get_case_progress()

    var required = case_data.connections.filter(func(c): return c.required)
    var made_pairs = []
    for c in progress.board_state.connections:
        made_pairs.append([c.from, c.to])

    var all_met = true
    for req in required:
        var found = false
        for pair in made_pairs:
            if (pair[0] == req.from and pair[1] == req.to) or \
               (pair[0] == req.to and pair[1] == req.from):
                found = true
                break
        if not found:
            all_met = false
            break

    if all_met:
        EventBus.connection_required_met.emit()
```

### 5.3 Interrogation Dialogue Traversal

```gdscript
# DialogueManager.gd
extends Node

var current_suspect: String = ""
var current_node_id: String = ""

func start_interrogation(suspect_id: String) -> Dictionary:
    var case_data = StateManager.get_current_case()
    current_suspect = suspect_id
    current_node_id = "start"

    var interrogation = case_data.interrogations[suspect_id]
    var node = interrogation.dialogue_tree[current_node_id]

    # Filter choices by available evidence
    var available_choices = _filter_choices(node.choices)

    EventBus.interrogation_started.emit(suspect_id)

    return {
        "speaker": node.speaker,
        "text": node.text,
        "emotion": node.emotion,
        "choices": available_choices
    }

func select_choice(choice_id: String) -> Dictionary:
    var case_data = StateManager.get_current_case()
    var interrogation = case_data.interrogations[current_suspect]
    var current = interrogation.dialogue_tree[current_node_id]

    # Find the selected choice
    var selected = null
    for choice in current.choices:
        if choice.id == choice_id:
            selected = choice
            break

    if not selected:
        return {}

    # Move to next node
    current_node_id = selected.next
    var next_node = interrogation.dialogue_tree[current_node_id]

    # Track visited nodes
    var progress = StateManager.get_case_progress()
    if not progress.dialogue_state.has(current_suspect):
        progress.dialogue_state[current_suspect] = {"nodes_visited": [], "current_node": ""}
    progress.dialogue_state[current_suspect].nodes_visited.append(current_node_id)
    progress.dialogue_state[current_suspect].current_node = current_node_id

    # Reveal clue if node has one
    if next_node.has("clue_revealed") and next_node.clue_revealed:
        EventBus.clue_discovered.emit(next_node.clue_revealed)

    EventBus.dialogue_choice_made.emit(current_node_id, choice_id)
    StateManager.save_progress()

    var available_choices = _filter_choices(next_node.get("choices", []))
    return {
        "speaker": next_node.speaker,
        "text": next_node.text,
        "emotion": next_node.emotion,
        "choices": available_choices,
        "is_end": next_node.get("end", false)
    }

func _filter_choices(choices: Array) -> Array:
    var progress = StateManager.get_case_progress()
    var filtered = []
    for choice in choices:
        if choice.requires_evidence == null:
            filtered.append(choice)
        elif choice.requires_evidence in progress.discovered_clues:
            filtered.append(choice)
    return filtered
```

### 5.4 Accusation Validation

```gdscript
# AccusationSystem.gd
extends Node

func submit_accusation(suspect_id: String, evidence_ids: Array) -> Dictionary:
    var case_data = StateManager.get_current_case()
    var accusation = case_data.accusation
    var progress = StateManager.get_case_progress()

    var result = {
        "correct_suspect": suspect_id == accusation.culprit,
        "correct_evidence": false,
        "stars": 0,
        "message": ""
    }

    if not result.correct_suspect:
        progress.wrong_accusations += 1
        StateManager.save_progress()
        result.message = accusation.wrong_accusation_hint
        EventBus.accusation_submitted.emit(suspect_id, evidence_ids)
        return result

    # Check evidence
    var matching = 0
    for ev in evidence_ids:
        if ev in accusation.required_evidence:
            matching += 1

    if matching < accusation.min_evidence_count:
        result.message = accusation.wrong_evidence_hint
        return result

    # CASE SOLVED
    result.correct_evidence = true
    result.stars = _calculate_stars(progress, case_data)
    result.message = case_data.resolution.arrest_narrative

    # Update player profile
    _complete_case(case_data.meta.case_id, result.stars)

    EventBus.case_completed.emit(case_data.meta.case_id, result.stars)
    return result

func _calculate_stars(progress: Dictionary, case_data: Dictionary) -> int:
    var hints_used = progress.hints_used
    var total_clues = case_data.clues.size()
    var found_clues = progress.discovered_clues.size()
    var all_evidence = found_clues >= total_clues
    var stars_config = case_data.meta.stars_config

    if hints_used <= stars_config.three_star.max_hints and all_evidence:
        return 3
    elif hints_used <= stars_config.two_star.max_hints:
        return 2
    else:
        return 1

func _complete_case(case_id: String, stars: int) -> void:
    var profile = StateManager.get_player_profile()
    if case_id not in profile.completed_cases:
        profile.completed_cases.append(case_id)
        profile.cases_completed += 1
        profile.total_stars += stars
        profile.hint_coins += 5
        if stars == 3:
            profile.hint_coins += 3
        StateManager.update_rank()
        StateManager.save_profile()
```

---

## 6. UI IMPLEMENTATION GUIDELINES

### 6.1 Chat Bubble Component

```gdscript
# ChatBubble.gd
extends PanelContainer

@export var is_sender: bool = false
@export var message_text: String = ""
@export var timestamp_text: String = ""
@export var has_clue: bool = false
@export var clue_highlight: String = ""
@export var clue_id: String = ""

@onready var label = $VBox/MessageLabel
@onready var time_label = $VBox/TimeLabel
@onready var clue_indicator = $ClueIndicator

func _ready():
    _setup_alignment()
    _setup_content()

func _setup_alignment():
    if is_sender:
        size_flags_horizontal = Control.SIZE_SHRINK_END
        add_theme_stylebox_override("panel", preload("res://assets/ui/components/bubble_sender.tres"))
    else:
        size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
        add_theme_stylebox_override("panel", preload("res://assets/ui/components/bubble_receiver.tres"))

func _setup_content():
    label.text = message_text
    time_label.text = timestamp_text
    clue_indicator.visible = has_clue

    if has_clue and clue_highlight != "":
        _highlight_clue_text()

func _highlight_clue_text():
    var rich_text = message_text.replace(
        clue_highlight,
        "[color=#FFD700][u]%s[/u][/color]" % clue_highlight
    )
    label.bbcode_enabled = true
    label.text = rich_text

func _gui_input(event: InputEvent):
    if event is InputEventMouseButton and event.pressed and has_clue:
        _on_clue_tapped()

func _on_clue_tapped():
    var evidence_system = get_node("/root/GameManager/EvidenceSystem")
    evidence_system.try_discover_clue(clue_id)
```

### 6.2 Theme & Visual Style

```
Color Palette:
- Background:     #1A1A2E (dark navy)
- Surface:        #16213E (card background)
- Primary:        #0F3460 (buttons, headers)
- Accent:         #E94560 (notifications, highlights)
- Text Primary:   #FFFFFF
- Text Secondary: #B0B0B0
- Success:        #4CAF50
- Warning:        #FF9800
- Clue Highlight: #FFD700 (gold)

Typography:
- Headers:  Roboto Bold, 24px
- Body:     Roboto Regular, 16px
- Caption:  Roboto Light, 12px
- Chat:     Roboto Regular, 14px

Spacing:
- Standard margin: 16px
- Card padding: 12px
- Button height: 48px (touch-friendly)
- Minimum tap target: 44x44px
```

---

## 7. ANDROID EXPORT SETTINGS

```
Minimum SDK: 21 (Android 5.0)
Target SDK: 34 (Android 14)
Orientation: Portrait only
Permissions: None (fully offline)
APK Size Target: <50MB (without cases), <100MB with 3 cases
Screen Sizes: Phone-optimized (16:9 to 20:9)
```

### 7.1 Performance Targets

| Device Tier | Example | Target FPS | Max Memory |
|---|---|---|---|
| Low-end | 2GB RAM, old SoC | 30 FPS | 150MB |
| Mid-range | 4GB RAM | 60 FPS | 250MB |
| High-end | 8GB+ RAM | 60 FPS | 300MB |

### 7.2 Optimization Strategies

1. **Lazy loading:** Only load case data when entering a case
2. **Image streaming:** Load photos only when the Photos app is opened
3. **Texture compression:** ETC2 for Android, max 1024x1024 for photos
4. **Object pooling:** Reuse chat bubbles in message lists
5. **Minimal draw calls:** Use atlased sprites for icons and UI elements

---

## 8. TESTING STRATEGY

### 8.1 Unit Tests

| System | Test |
|---|---|
| CaseLoader | Valid JSON parsing, missing fields, invalid references |
| EvidenceSystem | Clue discovery, duplicate prevention, unlock chains |
| BoardSystem | Valid/invalid connections, required connection tracking |
| DialogueManager | Tree traversal, evidence gating, state tracking |
| AccusationSystem | Correct/incorrect suspect, evidence validation, star calc |
| SaveManager | Save/load cycle, corruption recovery, migration |
| HintManager | Coin economy, hint levels, free hint logic |
| EnergySystem | Regen timing, cap, free activities |

### 8.2 Integration Tests

1. Full case playthrough — tutorial case solved with all 3 stars
2. Save/resume — quit mid-case, reopen, verify state preserved
3. Notification chain — verify clue → notification → unlock flow
4. Edge cases — wrong accusations, hint overuse, energy drain

### 8.3 Device Testing Matrix

| Category | Devices |
|---|---|
| Low-end | Samsung Galaxy A03, Xiaomi Redmi 9A |
| Mid-range | Samsung Galaxy A54, Pixel 6a |
| High-end | Samsung Galaxy S24, Pixel 8 Pro |
| Tablets | Samsung Galaxy Tab A8 (optional) |
