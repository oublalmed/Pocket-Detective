## SaveManager — Persistent Save/Load System (AutoLoad Singleton)
##
## Handles all file I/O for player profile and case progress data.
## Save files are stored under user://saves/ which persists across app updates
## on Android. All writes create directories as needed and include error handling.
##
## Save triggers are automatic on every significant action. There is no manual
## save button; the game always feels current.
extends Node


## Base path for all save data under the user data directory.
const SAVE_BASE_PATH: String = "user://saves/"

## Filename for the player profile save.
const PROFILE_FILENAME: String = "player_profile.json"

## Subdirectory for per-case progress files.
const CASE_PROGRESS_DIR: String = "case_progress/"

## Current save format version for migration support.
const SAVE_VERSION: String = "1.0"


# ---------------------------------------------------------------------------
# Player Profile
# ---------------------------------------------------------------------------

## Saves the player profile dictionary to disk.
## [param profile] The complete player profile dictionary.
## Returns [code]true[/code] on success, [code]false[/code] on failure.
func save_profile(profile: Dictionary) -> bool:
	var path: String = SAVE_BASE_PATH + PROFILE_FILENAME
	return _write_json(path, profile)


## Loads the player profile from disk. Returns the default profile if no
## save file exists or if loading fails.
func load_profile() -> Dictionary:
	var path: String = SAVE_BASE_PATH + PROFILE_FILENAME
	if FileAccess.file_exists(path):
		var data: Dictionary = _read_json(path)
		if not data.is_empty():
			return data
		push_warning("SaveManager: Profile file corrupted, returning default profile.")
	return _create_default_profile()


## Checks whether a saved player profile exists on disk.
func has_saved_profile() -> bool:
	return FileAccess.file_exists(SAVE_BASE_PATH + PROFILE_FILENAME)


# ---------------------------------------------------------------------------
# Case Progress
# ---------------------------------------------------------------------------

## Saves the progress for a specific case.
## [param case_id] The unique case identifier (e.g., "case_001").
## [param progress] The complete case progress dictionary.
## Returns [code]true[/code] on success, [code]false[/code] on failure.
func save_case_progress(case_id: String, progress: Dictionary) -> bool:
	var path: String = SAVE_BASE_PATH + CASE_PROGRESS_DIR + "%s_save.json" % case_id
	return _write_json(path, progress)


## Loads the progress for a specific case. Returns an empty dictionary if
## no save exists or if loading fails.
## [param case_id] The unique case identifier.
func load_case_progress(case_id: String) -> Dictionary:
	var path: String = SAVE_BASE_PATH + CASE_PROGRESS_DIR + "%s_save.json" % case_id
	if FileAccess.file_exists(path):
		var data: Dictionary = _read_json(path)
		if not data.is_empty():
			return data
		push_warning("SaveManager: Case progress file corrupted for %s." % case_id)
	return {}


## Checks whether saved progress exists for a specific case.
## [param case_id] The unique case identifier.
func has_case_progress(case_id: String) -> bool:
	var path: String = SAVE_BASE_PATH + CASE_PROGRESS_DIR + "%s_save.json" % case_id
	return FileAccess.file_exists(path)


## Deletes the saved progress for a specific case (e.g., for replaying).
## [param case_id] The unique case identifier.
## Returns [code]true[/code] on success, [code]false[/code] on failure.
func delete_case_progress(case_id: String) -> bool:
	var path: String = SAVE_BASE_PATH + CASE_PROGRESS_DIR + "%s_save.json" % case_id
	if FileAccess.file_exists(path):
		var err: Error = DirAccess.remove_absolute(path)
		if err != OK:
			push_error("SaveManager: Failed to delete case progress at %s (error %d)." % [path, err])
			return false
		return true
	return true  # Nothing to delete is still a success.


# ---------------------------------------------------------------------------
# Default Profile
# ---------------------------------------------------------------------------

## Creates and returns the default player profile for new players.
## Includes 10 starter hint coins, 5 energy, and rookie rank.
func _create_default_profile() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"detective_name": "Detective",
		"rank": "rookie",
		"cases_completed": 0,
		"total_stars": 0,
		"hint_coins": 10,
		"energy": {
			"current": 5,
			"max": 5,
			"last_regen_time": Time.get_datetime_string_from_system(true),
		},
		"completed_cases": [],
		"current_case": "",
		"daily_puzzle": {
			"last_completed": "",
			"streak": 0,
		},
		"settings": {
			"sfx_volume": 0.8,
			"music_volume": 0.5,
			"language": "en",
			"notifications_enabled": true,
		},
		"premium": {
			"detective_pass": false,
		},
		"unlocked_wallpapers": ["default"],
		"statistics": {
			"total_clues_found": 0,
			"total_connections_made": 0,
			"total_interrogations": 0,
			"perfect_cases": 0,
		},
	}


# ---------------------------------------------------------------------------
# JSON I/O Helpers
# ---------------------------------------------------------------------------

## Writes a dictionary as pretty-printed JSON to the given path.
## Creates parent directories as needed.
## Returns [code]true[/code] on success.
func _write_json(path: String, data: Dictionary) -> bool:
	# Ensure the directory exists.
	var dir_path: String = path.get_base_dir()
	var dir_err: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		push_error("SaveManager: Failed to create directory '%s' (error %d)." % [dir_path, dir_err])
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Failed to open '%s' for writing (error %d)." % [path, FileAccess.get_open_error()])
		return false

	var json_string: String = JSON.stringify(data, "  ")
	file.store_string(json_string)
	file.close()
	return true


## Reads and parses a JSON file at the given path.
## Returns the parsed dictionary, or an empty dictionary on failure.
func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Failed to open '%s' for reading (error %d)." % [path, FileAccess.get_open_error()])
		return {}

	var text: String = file.get_as_text()
	file.close()

	if text.is_empty():
		push_warning("SaveManager: File '%s' is empty." % path)
		return {}

	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(text)
	if parse_err != OK:
		push_error("SaveManager: JSON parse error in '%s' at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}

	if json.data is Dictionary:
		return json.data

	push_error("SaveManager: JSON root in '%s' is not a Dictionary." % path)
	return {}
