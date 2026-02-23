## StateManager — Current Investigation State Tracker (AutoLoad Singleton)
##
## Central state store for the active investigation. Tracks discovered clues,
## made connections, interrogation/dialogue progress, viewed threads, photos,
## and calls. Provides query methods for all subsystems and emits changes
## through EventBus for reactive UI updates.
##
## StateManager owns the CaseLoader instance and the current case progress
## dictionary. All systems should read game data through StateManager rather
## than loading case JSON directly.
##
## Usage:
##   StateManager.load_case("case_001")
##   StateManager.discover_clue("clue_marc_car")
##   if StateManager.is_clue_discovered("clue_marc_car"): ...
extends Node


# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

## The CaseLoader instance used to parse and access case data.
var _case_loader: RefCounted = null  # CaseLoader (loaded lazily)

## The full case data dictionary for the active case.
var _case_data: Dictionary = {}

## Per-case progress dictionary mirroring the save format.
var _case_progress: Dictionary = {}

## The case_id of the currently loaded case.
var _current_case_id: String = ""


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# CaseLoader is a RefCounted script, not an AutoLoad. Load it here.
	var CaseLoaderScript: GDScript = load("res://src/core/CaseLoader.gd")
	_case_loader = CaseLoaderScript.new()


# ---------------------------------------------------------------------------
# Case Loading
# ---------------------------------------------------------------------------

## Loads a case and its saved progress (if any) into memory.
## Returns [code]true[/code] if the case was loaded successfully.
## [param case_id] The unique case identifier.
func load_case(case_id: String) -> bool:
	var result: Dictionary = _case_loader.load_case(case_id)
	if not result.get("success", false):
		push_error("StateManager: Failed to load case '%s': %s" % [case_id, result.get("errors", [])])
		return false

	_case_data = result["data"]
	_current_case_id = case_id

	# Load or create case progress.
	var saved_progress: Dictionary = SaveManager.load_case_progress(case_id)
	if saved_progress.is_empty():
		_case_progress = _create_default_progress(case_id)
	else:
		_case_progress = saved_progress

	EventBus.case_loaded.emit(case_id)
	return true


## Unloads the current case from memory.
func unload_case() -> void:
	_case_data = {}
	_case_progress = {}
	_current_case_id = ""


## Returns [code]true[/code] if a case is currently loaded.
func has_active_case() -> bool:
	return not _current_case_id.is_empty()


## Returns the case_id of the currently loaded case.
func get_current_case_id() -> String:
	return _current_case_id


# ---------------------------------------------------------------------------
# Case Data Accessors
# ---------------------------------------------------------------------------

## Returns the full case data dictionary. UI and systems read data through this.
func get_current_case() -> Dictionary:
	return _case_data


## Returns the CaseLoader instance for direct helper access.
func get_case_loader() -> RefCounted:
	return _case_loader


## Returns the case progress dictionary for the active case.
func get_case_progress() -> Dictionary:
	return _case_progress


# ---------------------------------------------------------------------------
# Clue State
# ---------------------------------------------------------------------------

## Marks a clue as discovered.
## Returns [code]true[/code] if the clue was newly discovered (not a duplicate).
## [param clue_id] The unique clue identifier.
func discover_clue(clue_id: String) -> bool:
	if is_clue_discovered(clue_id):
		return false

	var discovered: Array = _case_progress.get("discovered_clues", [])
	discovered.append(clue_id)
	_case_progress["discovered_clues"] = discovered

	# Update global statistics.
	_increment_stat("total_clues_found")

	save_progress()
	EventBus.clue_discovered.emit(clue_id)
	return true


## Returns [code]true[/code] if the given clue has been discovered.
func is_clue_discovered(clue_id: String) -> bool:
	return clue_id in _case_progress.get("discovered_clues", [])


## Returns the full list of discovered clue IDs.
func get_discovered_clues() -> Array:
	return _case_progress.get("discovered_clues", [])


## Returns the number of discovered clues.
func get_discovered_clue_count() -> int:
	return get_discovered_clues().size()


## Returns the total number of clues defined in the case.
func get_total_clue_count() -> int:
	return _case_data.get("clues", []).size()


# ---------------------------------------------------------------------------
# Connection State
# ---------------------------------------------------------------------------

## Records a connection on the evidence board.
## [param from_id] The source clue identifier.
## [param to_id] The target clue identifier.
## [param valid] Whether the connection is valid per case data.
func record_connection(from_id: String, to_id: String, valid: bool) -> void:
	var board: Dictionary = _case_progress.get("board_state", {})
	var connections: Array = board.get("connections", [])

	# Avoid duplicates.
	for existing: Dictionary in connections:
		var ef: String = existing.get("from", "")
		var et: String = existing.get("to", "")
		if (ef == from_id and et == to_id) or (ef == to_id and et == from_id):
			return

	connections.append({"from": from_id, "to": to_id, "valid": valid})
	board["connections"] = connections
	_case_progress["board_state"] = board

	# Update global statistics.
	_increment_stat("total_connections_made")

	save_progress()


## Returns [code]true[/code] if a connection between the two clues has been made.
func is_connection_made(from_id: String, to_id: String) -> bool:
	var connections: Array = _case_progress.get("board_state", {}).get("connections", [])
	for conn: Dictionary in connections:
		var cf: String = conn.get("from", "")
		var ct: String = conn.get("to", "")
		if (cf == from_id and ct == to_id) or (cf == to_id and ct == from_id):
			return true
	return false


## Returns all connections made on the evidence board.
func get_made_connections() -> Array:
	return _case_progress.get("board_state", {}).get("connections", [])


## Returns the number of valid connections made.
func get_valid_connection_count() -> int:
	var count: int = 0
	for conn: Dictionary in get_made_connections():
		if conn.get("valid", false):
			count += 1
	return count


# ---------------------------------------------------------------------------
# Board / Pin State
# ---------------------------------------------------------------------------

## Pins a clue to the evidence board.
func pin_clue(clue_id: String) -> void:
	var board: Dictionary = _case_progress.get("board_state", {})
	var pinned: Array = board.get("pinned_clues", [])
	if clue_id not in pinned:
		pinned.append(clue_id)
		board["pinned_clues"] = pinned
		_case_progress["board_state"] = board
		save_progress()


## Unpins a clue from the evidence board.
func unpin_clue(clue_id: String) -> void:
	var board: Dictionary = _case_progress.get("board_state", {})
	var pinned: Array = board.get("pinned_clues", [])
	pinned.erase(clue_id)
	board["pinned_clues"] = pinned
	_case_progress["board_state"] = board
	save_progress()


## Returns [code]true[/code] if the clue is pinned to the board.
func is_clue_pinned(clue_id: String) -> bool:
	return clue_id in _case_progress.get("board_state", {}).get("pinned_clues", [])


## Returns all pinned clue IDs.
func get_pinned_clues() -> Array:
	return _case_progress.get("board_state", {}).get("pinned_clues", [])


# ---------------------------------------------------------------------------
# Interrogation / Dialogue State
# ---------------------------------------------------------------------------

## Records that a dialogue node has been visited for a suspect.
func visit_dialogue_node(suspect_id: String, node_id: String) -> void:
	var dialogue_state: Dictionary = _case_progress.get("dialogue_state", {})
	if not dialogue_state.has(suspect_id):
		dialogue_state[suspect_id] = {"nodes_visited": [], "current_node": ""}

	var suspect_state: Dictionary = dialogue_state[suspect_id]
	var visited: Array = suspect_state.get("nodes_visited", [])
	if node_id not in visited:
		visited.append(node_id)
	suspect_state["nodes_visited"] = visited
	suspect_state["current_node"] = node_id

	dialogue_state[suspect_id] = suspect_state
	_case_progress["dialogue_state"] = dialogue_state
	save_progress()


## Returns [code]true[/code] if the given dialogue node has been visited.
func is_dialogue_node_visited(suspect_id: String, node_id: String) -> bool:
	var suspect_state: Dictionary = _case_progress.get("dialogue_state", {}).get(suspect_id, {})
	return node_id in suspect_state.get("nodes_visited", [])


## Returns all visited node IDs for a suspect.
func get_visited_nodes(suspect_id: String) -> Array:
	return _case_progress.get("dialogue_state", {}).get(suspect_id, {}).get("nodes_visited", [])


## Returns the current node ID in the dialogue with a suspect.
func get_current_dialogue_node(suspect_id: String) -> String:
	return _case_progress.get("dialogue_state", {}).get(suspect_id, {}).get("current_node", "")


## Records that an interrogation has been started (for statistics).
func record_interrogation_started(suspect_id: String) -> void:
	var unlocked: Array = _case_progress.get("interrogations_unlocked", [])
	if suspect_id not in unlocked:
		unlocked.append(suspect_id)
		_case_progress["interrogations_unlocked"] = unlocked
	_increment_stat("total_interrogations")
	save_progress()


## Returns [code]true[/code] if the given suspect's interrogation is unlocked.
func is_interrogation_unlocked(suspect_id: String) -> bool:
	return suspect_id in _case_progress.get("interrogations_unlocked", [])


# ---------------------------------------------------------------------------
# Viewed Content Tracking
# ---------------------------------------------------------------------------

## Marks a message thread as viewed.
func mark_thread_viewed(thread_id: String) -> void:
	_mark_viewed("viewed_threads", thread_id)


## Returns [code]true[/code] if the thread has been viewed.
func is_thread_viewed(thread_id: String) -> bool:
	return _is_viewed("viewed_threads", thread_id)


## Marks a photo as viewed.
func mark_photo_viewed(photo_id: String) -> void:
	_mark_viewed("viewed_photos", photo_id)


## Returns [code]true[/code] if the photo has been viewed.
func is_photo_viewed(photo_id: String) -> bool:
	return _is_viewed("viewed_photos", photo_id)


## Marks a call as viewed.
func mark_call_viewed(call_id: String) -> void:
	_mark_viewed("viewed_calls", call_id)


## Returns [code]true[/code] if the call has been viewed.
func is_call_viewed(call_id: String) -> bool:
	return _is_viewed("viewed_calls", call_id)


## Marks a notification as seen.
func mark_notification_seen(notification_id: String) -> void:
	var seen: Array = _case_progress.get("notifications_seen", [])
	if notification_id not in seen:
		seen.append(notification_id)
		_case_progress["notifications_seen"] = seen
		save_progress()


## Returns [code]true[/code] if the notification has been seen.
func is_notification_seen(notification_id: String) -> bool:
	return notification_id in _case_progress.get("notifications_seen", [])


# ---------------------------------------------------------------------------
# Hints & Accusations
# ---------------------------------------------------------------------------

## Increments the hint-used counter for the current case.
func record_hint_used() -> void:
	_case_progress["hints_used"] = get_hints_used() + 1
	save_progress()


## Returns how many hints have been used in the current case.
func get_hints_used() -> int:
	return _case_progress.get("hints_used", 0) as int


## Increments the wrong-accusations counter.
func record_wrong_accusation() -> void:
	_case_progress["wrong_accusations"] = get_wrong_accusations() + 1
	save_progress()


## Returns the number of wrong accusations made.
func get_wrong_accusations() -> int:
	return _case_progress.get("wrong_accusations", 0) as int


# ---------------------------------------------------------------------------
# Accusation Readiness
# ---------------------------------------------------------------------------

## Returns [code]true[/code] if the player has made all required connections
## and is ready to submit an accusation.
func is_accusation_ready() -> bool:
	var required_conns: Array = _case_data.get("connections", []).filter(
		func(c: Dictionary) -> bool: return c.get("required", false)
	)

	for req: Dictionary in required_conns:
		var from_id: String = req.get("from", "")
		var to_id: String = req.get("to", "")
		if not is_connection_made(from_id, to_id):
			return false

	return true


# ---------------------------------------------------------------------------
# Player Notes
# ---------------------------------------------------------------------------

## Updates the player's free-text notes for the current case.
func set_notes(text: String) -> void:
	_case_progress["notes"] = text
	save_progress()


## Returns the player's notes for the current case.
func get_notes() -> String:
	return _case_progress.get("notes", "")


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

## Saves the current case progress through SaveManager.
func save_progress() -> void:
	if _current_case_id.is_empty():
		return
	_case_progress["last_played"] = Time.get_datetime_string_from_system(true)
	SaveManager.save_case_progress(_current_case_id, _case_progress)


# ---------------------------------------------------------------------------
# Internal Helpers
# ---------------------------------------------------------------------------

## Creates the default (empty) progress dictionary for a new case.
func _create_default_progress(case_id: String) -> Dictionary:
	return {
		"case_id": case_id,
		"version": SaveManager.SAVE_VERSION,
		"started_at": Time.get_datetime_string_from_system(true),
		"last_played": Time.get_datetime_string_from_system(true),
		"phase": "investigation",
		"discovered_clues": [],
		"board_state": {
			"pinned_clues": [],
			"connections": [],
		},
		"dialogue_state": {},
		"interrogations_unlocked": [],
		"notifications_seen": [],
		"viewed_threads": [],
		"viewed_photos": [],
		"viewed_calls": [],
		"hints_used": 0,
		"wrong_accusations": 0,
		"notes": "",
	}


## Marks an item as viewed in the specified progress array.
func _mark_viewed(key: String, item_id: String) -> void:
	var viewed: Array = _case_progress.get(key, [])
	if item_id not in viewed:
		viewed.append(item_id)
		_case_progress[key] = viewed
		save_progress()


## Returns [code]true[/code] if the item is in the specified viewed array.
func _is_viewed(key: String, item_id: String) -> bool:
	return item_id in _case_progress.get(key, [])


## Increments a statistic counter in the player profile (through GameManager).
func _increment_stat(stat_key: String) -> void:
	var profile: Dictionary = GameManager.get_player_profile()
	var stats: Dictionary = profile.get("statistics", {})
	stats[stat_key] = (stats.get(stat_key, 0) as int) + 1
	profile["statistics"] = stats
	# Profile saving is handled by GameManager; we just mutate the reference.
