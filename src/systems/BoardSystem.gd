## BoardSystem — Evidence Board Connections
##
## Manages the evidence board where discovered clues are pinned and connected.
## Validates connections against the case JSON definition, distinguishes
## required from optional connections, and tracks overall board progress
## toward unlocking the accusation phase.
##
## Connection Results:
##   correct    — Green line. The connection matches a defined link in case data.
##   key        — Gold line. A required connection that moves the case forward.
##   incorrect  — Red line that fades. The clues are not related.
##   duplicate  — The connection already exists on the board.
##
## This is NOT an AutoLoad. It is instantiated by the BoardApp scene.
##
## Usage:
##   var board := BoardSystem.new()
##   add_child(board)
##   var result := board.try_connect("clue_marc_schedule", "clue_marc_car")
##   if result.valid: show_confirmation(result.description)
extends Node


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Connection result types for UI feedback.
const RESULT_CORRECT: String = "correct"
const RESULT_KEY: String = "key"
const RESULT_INCORRECT: String = "incorrect"
const RESULT_DUPLICATE: String = "duplicate"


# ---------------------------------------------------------------------------
# Public API — Pinning
# ---------------------------------------------------------------------------

## Pins a discovered clue to the evidence board.
## Returns [code]true[/code] if the clue was newly pinned.
## [param clue_id] The clue to pin. Must already be discovered.
func pin_clue(clue_id: String) -> bool:
	if not StateManager.has_active_case():
		return false

	if not StateManager.is_clue_discovered(clue_id):
		push_warning("BoardSystem: Cannot pin undiscovered clue '%s'." % clue_id)
		return false

	if StateManager.is_clue_pinned(clue_id):
		return false  # Already pinned.

	StateManager.pin_clue(clue_id)
	return true


## Removes a clue from the evidence board.
## Also removes any connections involving this clue.
## [param clue_id] The clue to unpin.
func unpin_clue(clue_id: String) -> void:
	if not StateManager.is_clue_pinned(clue_id):
		return

	# Remove connections involving this clue.
	_remove_connections_for_clue(clue_id)
	StateManager.unpin_clue(clue_id)


## Returns all clue IDs currently pinned to the board.
func get_pinned_clues() -> Array:
	return StateManager.get_pinned_clues()


## Returns [code]true[/code] if the clue is on the board.
func is_pinned(clue_id: String) -> bool:
	return StateManager.is_clue_pinned(clue_id)


# ---------------------------------------------------------------------------
# Public API — Connections
# ---------------------------------------------------------------------------

## Attempts to draw a connection between two pinned clues.
## Validates the connection against the case data and returns a result
## dictionary with:
##   [code]valid[/code] (bool) — whether the connection matches case data.
##   [code]result_type[/code] (String) — RESULT_CORRECT, RESULT_KEY, RESULT_INCORRECT, or RESULT_DUPLICATE.
##   [code]connection_id[/code] (String) — the matched connection ID (empty if invalid).
##   [code]description[/code] (String) — the connection description from case data.
##   [code]type[/code] (String) — the connection type (e.g., "contradiction", "confirmation").
##   [code]required[/code] (bool) — whether this is a required connection.
##   [code]unlocks[/code] (Array) — IDs of notifications/content unlocked by this connection.
##
## [param from_clue] Source clue ID.
## [param to_clue] Target clue ID.
func try_connect(from_clue: String, to_clue: String) -> Dictionary:
	if not StateManager.has_active_case():
		return _build_invalid_result("No active case.")

	# Validate both clues are pinned.
	if not StateManager.is_clue_pinned(from_clue):
		return _build_invalid_result("Clue '%s' is not pinned to the board." % from_clue)
	if not StateManager.is_clue_pinned(to_clue):
		return _build_invalid_result("Clue '%s' is not pinned to the board." % to_clue)

	# Cannot connect a clue to itself.
	if from_clue == to_clue:
		return _build_invalid_result("Cannot connect a clue to itself.")

	# Check for duplicate.
	if StateManager.is_connection_made(from_clue, to_clue):
		return {
			"valid": true,
			"result_type": RESULT_DUPLICATE,
			"connection_id": "",
			"description": "This connection has already been made.",
			"type": "",
			"required": false,
			"unlocks": [],
		}

	# Look up in case data (check both directions).
	var case_data: Dictionary = StateManager.get_current_case()
	var matched_conn: Dictionary = {}
	for conn: Dictionary in case_data.get("connections", []):
		var cf: String = conn.get("from", "")
		var ct: String = conn.get("to", "")
		if (cf == from_clue and ct == to_clue) or (cf == to_clue and ct == from_clue):
			matched_conn = conn
			break

	if matched_conn.is_empty():
		# Invalid connection — emit signal and return.
		EventBus.connection_made.emit(from_clue, to_clue, false)
		return _build_invalid_result("These clues don't seem related.")

	# Valid connection found.
	var is_required: bool = matched_conn.get("required", false)
	var result_type: String = RESULT_KEY if is_required else RESULT_CORRECT
	var unlocks: Array = matched_conn.get("unlocks", [])
	var conn_id: String = matched_conn.get("id", "")

	# Record the connection in StateManager.
	StateManager.record_connection(from_clue, to_clue, true)

	# Emit the connection signal.
	EventBus.connection_made.emit(from_clue, to_clue, true)

	# Process unlocks (fire notification signals).
	for unlock_id: String in unlocks:
		if not unlock_id.is_empty():
			EventBus.notification_fired.emit(unlock_id)

	# Check if all required connections are now met.
	if is_required and are_all_required_connections_met():
		EventBus.connection_required_met.emit()

	return {
		"valid": true,
		"result_type": result_type,
		"connection_id": conn_id,
		"description": matched_conn.get("description", ""),
		"type": matched_conn.get("type", ""),
		"required": is_required,
		"unlocks": unlocks,
	}


## Removes a specific connection from the board.
## [param from_clue] Source clue ID.
## [param to_clue] Target clue ID.
func remove_connection(from_clue: String, to_clue: String) -> void:
	var progress: Dictionary = StateManager.get_case_progress()
	var board: Dictionary = progress.get("board_state", {})
	var connections: Array = board.get("connections", [])

	var new_connections: Array = []
	for conn: Dictionary in connections:
		var cf: String = conn.get("from", "")
		var ct: String = conn.get("to", "")
		if not ((cf == from_clue and ct == to_clue) or (cf == to_clue and ct == from_clue)):
			new_connections.append(conn)

	board["connections"] = new_connections
	progress["board_state"] = board
	StateManager.save_progress()


# ---------------------------------------------------------------------------
# Public API — Progress Queries
# ---------------------------------------------------------------------------

## Returns the total number of valid connections defined in the case.
func get_total_connection_count() -> int:
	var case_data: Dictionary = StateManager.get_current_case()
	return case_data.get("connections", []).size()


## Returns the number of required connections defined in the case.
func get_required_connection_count() -> int:
	var case_data: Dictionary = StateManager.get_current_case()
	var required: Array = case_data.get("connections", []).filter(
		func(c: Dictionary) -> bool: return c.get("required", false)
	)
	return required.size()


## Returns the number of valid connections the player has made.
func get_made_connection_count() -> int:
	return StateManager.get_valid_connection_count()


## Returns the number of required connections the player has made.
func get_made_required_connection_count() -> int:
	var case_data: Dictionary = StateManager.get_current_case()
	var count: int = 0
	for conn: Dictionary in case_data.get("connections", []):
		if conn.get("required", false):
			var from_id: String = conn.get("from", "")
			var to_id: String = conn.get("to", "")
			if StateManager.is_connection_made(from_id, to_id):
				count += 1
	return count


## Returns [code]true[/code] if all required connections have been made.
func are_all_required_connections_met() -> bool:
	return StateManager.is_accusation_ready()


## Returns a progress dictionary summarizing board state for the UI.
## Contains "connections_made", "connections_required", "total_connections",
## "evidence_found", "total_evidence", "accusation_ready".
func get_board_progress() -> Dictionary:
	return {
		"connections_made": get_made_connection_count(),
		"connections_required": get_required_connection_count(),
		"required_met": get_made_required_connection_count(),
		"total_connections": get_total_connection_count(),
		"evidence_found": StateManager.get_discovered_clue_count(),
		"total_evidence": StateManager.get_total_clue_count(),
		"accusation_ready": are_all_required_connections_met(),
	}


## Returns all connections made on the board (both valid and invalid).
func get_all_made_connections() -> Array:
	return StateManager.get_made_connections()


## Returns a list of connection definitions from the case data that have
## NOT yet been made by the player (useful for hint targeting).
func get_unmade_connections() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var case_data: Dictionary = StateManager.get_current_case()
	for conn: Dictionary in case_data.get("connections", []):
		var from_id: String = conn.get("from", "")
		var to_id: String = conn.get("to", "")
		if not StateManager.is_connection_made(from_id, to_id):
			result.append(conn)
	return result


## Returns a list of required connections that have NOT yet been made.
func get_unmade_required_connections() -> Array[Dictionary]:
	var unmade: Array[Dictionary] = get_unmade_connections()
	var required_only: Array[Dictionary] = []
	for conn: Dictionary in unmade:
		if conn.get("required", false):
			required_only.append(conn)
	return required_only


# ---------------------------------------------------------------------------
# Internal Helpers
# ---------------------------------------------------------------------------

## Removes all connections involving a specific clue (used when unpinning).
func _remove_connections_for_clue(clue_id: String) -> void:
	var progress: Dictionary = StateManager.get_case_progress()
	var board: Dictionary = progress.get("board_state", {})
	var connections: Array = board.get("connections", [])

	var filtered: Array = []
	for conn: Dictionary in connections:
		var cf: String = conn.get("from", "")
		var ct: String = conn.get("to", "")
		if cf != clue_id and ct != clue_id:
			filtered.append(conn)

	board["connections"] = filtered
	progress["board_state"] = board
	StateManager.save_progress()


## Builds a standardized invalid-connection result dictionary.
func _build_invalid_result(reason: String) -> Dictionary:
	return {
		"valid": false,
		"result_type": RESULT_INCORRECT,
		"connection_id": "",
		"description": reason,
		"type": "",
		"required": false,
		"unlocks": [],
	}
