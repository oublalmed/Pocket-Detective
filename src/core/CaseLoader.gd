## CaseLoader — Loads & Parses Case JSON Files
##
## Responsible for discovering available cases, loading full case data from
## [code]res://cases/{case_id}/case.json[/code], validating referential integrity,
## and providing convenient accessors for case sub-elements (suspects, clues,
## connections, etc.).
##
## This is NOT an AutoLoad singleton. It is instantiated by systems that need to
## load case data (primarily StateManager and GameManager).
##
## Usage:
##   var loader := CaseLoader.new()
##   var result := loader.load_case("case_001")
##   if result.success:
##       var case_data: Dictionary = result.data
##       var sophie := loader.get_suspect("suspect_sophie")
extends RefCounted


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Base path where case folders are located.
const CASES_BASE_PATH: String = "res://cases/"


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## The currently loaded case data dictionary. Empty if no case is loaded.
var _case_data: Dictionary = {}

## The case_id of the currently loaded case.
var _loaded_case_id: String = ""

## Indexed lookup tables built after loading for fast access.
var _clues_by_id: Dictionary = {}
var _suspects_by_id: Dictionary = {}
var _connections_by_id: Dictionary = {}
var _threads_by_id: Dictionary = {}
var _photos_by_id: Dictionary = {}
var _calls_by_id: Dictionary = {}


# ---------------------------------------------------------------------------
# Case Discovery
# ---------------------------------------------------------------------------

## Scans [code]res://cases/[/code] for available case folders and returns an
## array of metadata dictionaries sorted by display order.
## Each entry contains: case_id, title, subtitle, description, difficulty, order.
func discover_cases() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(CASES_BASE_PATH)
	if dir == null:
		push_error("CaseLoader: Cannot open cases directory at '%s'." % CASES_BASE_PATH)
		return cases

	dir.list_dir_begin()
	var folder: String = dir.get_next()
	while folder != "":
		if dir.current_is_dir() and folder.begins_with("case_"):
			var case_path: String = CASES_BASE_PATH + folder + "/case.json"
			if FileAccess.file_exists(case_path):
				var metadata: Dictionary = _load_case_metadata(case_path, folder)
				if not metadata.is_empty():
					cases.append(metadata)
		folder = dir.get_next()
	dir.list_dir_end()

	cases.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.get("order", 999) as int) < (b.get("order", 999) as int)
	)
	return cases


# ---------------------------------------------------------------------------
# Case Loading
# ---------------------------------------------------------------------------

## Loads and validates a full case from disk.
## Returns a result dictionary with keys:
##   [code]success[/code] (bool), [code]data[/code] (Dictionary), [code]errors[/code] (Array[String]).
## [param case_id] The unique case identifier (e.g., "case_001").
func load_case(case_id: String) -> Dictionary:
	var path: String = CASES_BASE_PATH + case_id + "/case.json"

	if not FileAccess.file_exists(path):
		return {"success": false, "data": {}, "errors": ["Case file not found: %s" % path]}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"success": false, "data": {}, "errors": [
			"Failed to open case file: %s (error %d)" % [path, FileAccess.get_open_error()]
		]}

	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(text)
	if parse_err != OK:
		return {"success": false, "data": {}, "errors": [
			"JSON parse error in '%s' at line %d: %s" % [path, json.get_error_line(), json.get_error_message()]
		]}

	if not (json.data is Dictionary):
		return {"success": false, "data": {}, "errors": ["JSON root is not a Dictionary in '%s'." % path]}

	var case_data: Dictionary = json.data

	# Resolve asset paths.
	_resolve_asset_paths(case_data, case_id)

	# Validate referential integrity.
	var errors: Array[String] = validate_case(case_data)
	if not errors.is_empty():
		for err in errors:
			push_warning("CaseLoader: Validation warning for '%s': %s" % [case_id, err])

	# Store and index.
	_case_data = case_data
	_loaded_case_id = case_id
	_build_indices()

	return {"success": true, "data": case_data, "errors": errors}


## Returns the currently loaded case data dictionary.
func get_case_data() -> Dictionary:
	return _case_data


## Returns the case_id of the currently loaded case.
func get_loaded_case_id() -> String:
	return _loaded_case_id


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

## Validates the referential integrity of a case data dictionary.
## Returns an array of error/warning strings. An empty array means no issues.
## [param case_data] The full case dictionary to validate.
func validate_case(case_data: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	# Collect all clue IDs.
	var clue_ids: Array[String] = []
	for clue: Dictionary in case_data.get("clues", []):
		var cid: String = clue.get("id", "")
		if cid.is_empty():
			errors.append("Clue entry is missing 'id' field.")
		else:
			clue_ids.append(cid)

	# Collect all suspect IDs.
	var suspect_ids: Array[String] = []
	var culprit_found: bool = false
	for suspect: Dictionary in case_data.get("suspects", []):
		var sid: String = suspect.get("id", "")
		if sid.is_empty():
			errors.append("Suspect entry is missing 'id' field.")
		else:
			suspect_ids.append(sid)
		if suspect.get("is_culprit", false):
			culprit_found = true

	# Validate connections reference valid clues.
	for conn: Dictionary in case_data.get("connections", []):
		var conn_id: String = conn.get("id", "unknown")
		var from_id: String = conn.get("from", "")
		var to_id: String = conn.get("to", "")
		if from_id not in clue_ids:
			errors.append("Connection '%s' references unknown clue: '%s'." % [conn_id, from_id])
		if to_id not in clue_ids:
			errors.append("Connection '%s' references unknown clue: '%s'." % [conn_id, to_id])

	# Validate accusation section.
	var accusation: Dictionary = case_data.get("accusation", {})
	var culprit_id: String = accusation.get("culprit", "")
	if not culprit_id.is_empty():
		if culprit_id not in suspect_ids:
			errors.append("Accusation culprit '%s' not found in suspects." % culprit_id)
		# Verify the culprit is actually marked is_culprit in suspects.
		if not culprit_found:
			errors.append("No suspect has 'is_culprit: true' but accusation defines a culprit.")

	# Validate required evidence exists in clues.
	for ev_id: String in accusation.get("required_evidence", []):
		if ev_id not in clue_ids:
			errors.append("Required accusation evidence '%s' not found in clues." % ev_id)

	# Validate clue_id references in message evidence.
	for thread: Dictionary in case_data.get("evidence", {}).get("messages", []):
		for msg: Dictionary in thread.get("messages", []):
			var msg_clue: String = msg.get("clue_id", "")
			if not msg_clue.is_empty() and msg_clue not in clue_ids:
				errors.append("Message '%s' references unknown clue: '%s'." % [msg.get("id", "?"), msg_clue])

	# Validate clue_id references in photo hotspots.
	for photo: Dictionary in case_data.get("evidence", {}).get("photos", []):
		for hotspot: Dictionary in photo.get("hotspots", []):
			var hs_clue: String = hotspot.get("clue_id", "")
			if not hs_clue.is_empty() and hs_clue not in clue_ids:
				errors.append("Hotspot '%s' references unknown clue: '%s'." % [hotspot.get("id", "?"), hs_clue])

	# Validate clue_id references in call transcripts.
	for call: Dictionary in case_data.get("evidence", {}).get("calls", []):
		for line: Dictionary in call.get("transcript", []):
			var line_clue: String = line.get("clue_id", "")
			if not line_clue.is_empty() and line_clue not in clue_ids:
				errors.append("Call transcript in '%s' references unknown clue: '%s'." % [call.get("id", "?"), line_clue])

	# Validate interrogation suspect references.
	var interrogations: Dictionary = case_data.get("interrogations", {})
	for suspect_key: String in interrogations:
		if suspect_key not in suspect_ids:
			errors.append("Interrogation defined for unknown suspect: '%s'." % suspect_key)

	return errors


# ---------------------------------------------------------------------------
# Helper Accessors
# ---------------------------------------------------------------------------

## Returns the suspect dictionary for the given ID, or empty dict if not found.
func get_suspect(suspect_id: String) -> Dictionary:
	return _suspects_by_id.get(suspect_id, {})


## Returns the clue dictionary for the given ID, or empty dict if not found.
func get_clue(clue_id: String) -> Dictionary:
	return _clues_by_id.get(clue_id, {})


## Returns the connection dictionary for the given ID, or empty dict if not found.
func get_connection(connection_id: String) -> Dictionary:
	return _connections_by_id.get(connection_id, {})


## Returns the message thread dictionary for the given thread_id, or empty dict.
func get_thread(thread_id: String) -> Dictionary:
	return _threads_by_id.get(thread_id, {})


## Returns the photo dictionary for the given photo ID, or empty dict.
func get_photo(photo_id: String) -> Dictionary:
	return _photos_by_id.get(photo_id, {})


## Returns the call dictionary for the given call ID, or empty dict.
func get_call(call_id: String) -> Dictionary:
	return _calls_by_id.get(call_id, {})


## Returns the interrogation data for the given suspect, or empty dict.
func get_interrogation(suspect_id: String) -> Dictionary:
	return _case_data.get("interrogations", {}).get(suspect_id, {})


## Returns the hint data for a specific target (clue_id or connection_id).
func get_hint_data(target_id: String) -> Dictionary:
	return _case_data.get("hints", {}).get(target_id, {})


## Returns the full array of clue dictionaries.
func get_all_clues() -> Array:
	return _case_data.get("clues", [])


## Returns the full array of suspect dictionaries.
func get_all_suspects() -> Array:
	return _case_data.get("suspects", [])


## Returns the full array of connection dictionaries.
func get_all_connections() -> Array:
	return _case_data.get("connections", [])


## Returns only the required connections (needed to unlock accusation).
func get_required_connections() -> Array:
	var all_conns: Array = get_all_connections()
	return all_conns.filter(func(c: Dictionary) -> bool: return c.get("required", false))


## Returns the accusation definition dictionary.
func get_accusation_data() -> Dictionary:
	return _case_data.get("accusation", {})


## Returns the resolution/epilogue dictionary.
func get_resolution_data() -> Dictionary:
	return _case_data.get("resolution", {})


## Returns the meta section of the case.
func get_meta() -> Dictionary:
	return _case_data.get("meta", {})


## Returns the victim dictionary.
func get_victim() -> Dictionary:
	return _case_data.get("victim", {})


## Returns the notifications array.
func get_notifications() -> Array:
	return _case_data.get("notifications", [])


## Returns the stars_config from the meta section.
func get_stars_config() -> Dictionary:
	return get_meta().get("stars_config", {})


# ---------------------------------------------------------------------------
# Internal Helpers
# ---------------------------------------------------------------------------

## Resolves relative image/portrait filenames to full resource paths.
func _resolve_asset_paths(case_data: Dictionary, case_id: String) -> void:
	var base: String = CASES_BASE_PATH + case_id + "/"

	# Resolve photo image paths.
	for photo: Dictionary in case_data.get("evidence", {}).get("photos", []):
		var filename: String = photo.get("filename", "")
		if not filename.is_empty():
			photo["image_path"] = base + "images/" + filename

	# Resolve suspect portrait paths.
	for suspect: Dictionary in case_data.get("suspects", []):
		var portraits: Dictionary = suspect.get("portraits", {})
		for emotion: String in portraits:
			var portrait_file: String = portraits[emotion]
			if not portrait_file.is_empty():
				portraits[emotion] = base + "portraits/" + portrait_file

	# Resolve victim portrait path.
	var victim: Dictionary = case_data.get("victim", {})
	var victim_portrait: String = victim.get("portrait", "")
	if not victim_portrait.is_empty():
		victim["portrait"] = base + "portraits/" + victim_portrait

	# Resolve document filenames.
	for doc: Dictionary in case_data.get("evidence", {}).get("documents", []):
		var doc_filename: String = doc.get("filename", "")
		if not doc_filename.is_empty():
			doc["image_path"] = base + "images/" + doc_filename


## Builds indexed lookup dictionaries from the loaded case data for O(1) access.
func _build_indices() -> void:
	_clues_by_id.clear()
	_suspects_by_id.clear()
	_connections_by_id.clear()
	_threads_by_id.clear()
	_photos_by_id.clear()
	_calls_by_id.clear()

	for clue: Dictionary in _case_data.get("clues", []):
		var cid: String = clue.get("id", "")
		if not cid.is_empty():
			_clues_by_id[cid] = clue

	for suspect: Dictionary in _case_data.get("suspects", []):
		var sid: String = suspect.get("id", "")
		if not sid.is_empty():
			_suspects_by_id[sid] = suspect

	for conn: Dictionary in _case_data.get("connections", []):
		var conn_id: String = conn.get("id", "")
		if not conn_id.is_empty():
			_connections_by_id[conn_id] = conn

	for thread: Dictionary in _case_data.get("evidence", {}).get("messages", []):
		var tid: String = thread.get("thread_id", "")
		if not tid.is_empty():
			_threads_by_id[tid] = thread

	for photo: Dictionary in _case_data.get("evidence", {}).get("photos", []):
		var pid: String = photo.get("id", "")
		if not pid.is_empty():
			_photos_by_id[pid] = photo

	for call: Dictionary in _case_data.get("evidence", {}).get("calls", []):
		var cid: String = call.get("id", "")
		if not cid.is_empty():
			_calls_by_id[cid] = call


## Loads only the metadata section from a case JSON for the case list screen.
## Returns a lightweight dictionary with key display fields.
func _load_case_metadata(path: String, folder_name: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CaseLoader: Failed to open '%s' for metadata." % path)
		return {}

	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		push_error("CaseLoader: JSON parse error in '%s'." % path)
		return {}

	if not (json.data is Dictionary):
		return {}

	var data: Dictionary = json.data
	var meta: Dictionary = data.get("meta", {})

	return {
		"case_id": meta.get("case_id", folder_name),
		"title": meta.get("title", "Unknown Case"),
		"subtitle": meta.get("subtitle", ""),
		"description": meta.get("description", ""),
		"difficulty": meta.get("difficulty", "easy"),
		"order": meta.get("order", 999),
		"estimated_time_minutes": meta.get("estimated_time_minutes", 0),
		"tags": meta.get("tags", []),
	}
