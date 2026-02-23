## GameManager — Global State & Lifecycle Manager (AutoLoad Singleton)
##
## Manages the overall game state, player profile, case lifecycle, and
## detective rank progression. Coordinates with SaveManager for persistence
## and communicates state changes through EventBus signals.
##
## Game States:
##   MAIN_MENU   — Player is on the main/home screen, no case active.
##   CASE_ACTIVE  — Player is actively investigating a case.
##   CASE_COMPLETE — Case has been solved; showing resolution screen.
##   DAILY_PUZZLE  — Player is doing the daily puzzle mini-game.
##
## Usage:
##   GameManager.start_case("case_001")
##   GameManager.get_player_profile()
##   GameManager.get_game_state()
extends Node


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

## The possible high-level game states.
enum GameState {
	MAIN_MENU,
	CASE_ACTIVE,
	CASE_COMPLETE,
	DAILY_PUZZLE,
}

## Detective ranks ordered from lowest to highest.
enum DetectiveRank {
	ROOKIE,
	JUNIOR,
	DETECTIVE,
	SENIOR,
	INSPECTOR,
	CHIEF,
	LEGENDARY,
}


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Maps DetectiveRank values to their string identifiers used in save data.
const RANK_NAMES: Dictionary = {
	DetectiveRank.ROOKIE: "rookie",
	DetectiveRank.JUNIOR: "junior",
	DetectiveRank.DETECTIVE: "detective",
	DetectiveRank.SENIOR: "senior",
	DetectiveRank.INSPECTOR: "inspector",
	DetectiveRank.CHIEF: "chief",
	DetectiveRank.LEGENDARY: "legendary",
}

## Cases-completed thresholds required to reach each rank.
const RANK_THRESHOLDS: Dictionary = {
	DetectiveRank.ROOKIE: 0,
	DetectiveRank.JUNIOR: 2,
	DetectiveRank.DETECTIVE: 5,
	DetectiveRank.SENIOR: 10,
	DetectiveRank.INSPECTOR: 20,
	DetectiveRank.CHIEF: 35,
	DetectiveRank.LEGENDARY: 50,
}

## Number of hint coins awarded on case completion.
const CASE_COMPLETE_COINS: int = 5

## Bonus hint coins for a perfect 3-star completion.
const PERFECT_BONUS_COINS: int = 3

## Maximum energy capacity.
const MAX_ENERGY: int = 5

## Energy regeneration interval in seconds (30 minutes).
const ENERGY_REGEN_SECONDS: int = 1800


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## The current high-level game state.
var _game_state: GameState = GameState.MAIN_MENU

## The loaded player profile dictionary. Mirrors the save format.
var _player_profile: Dictionary = {}

## The case_id of the currently active case, or empty string if none.
var _active_case_id: String = ""


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_load_player_profile()
	_regenerate_energy()


# ---------------------------------------------------------------------------
# Game State
# ---------------------------------------------------------------------------

## Returns the current [enum GameState].
func get_game_state() -> GameState:
	return _game_state


## Returns [code]true[/code] if the current state matches the given state.
func is_state(state: GameState) -> bool:
	return _game_state == state


## Returns the case_id of the active case, or an empty string.
func get_active_case_id() -> String:
	return _active_case_id


# ---------------------------------------------------------------------------
# Player Profile
# ---------------------------------------------------------------------------

## Returns the full player profile dictionary (read-only copy preferred for UI).
func get_player_profile() -> Dictionary:
	return _player_profile


## Returns the player's detective rank as a human-readable string.
func get_rank_name() -> String:
	return _player_profile.get("rank", "rookie")


## Returns the player's current hint-coin balance.
func get_coins() -> int:
	return _player_profile.get("hint_coins", 0) as int


## Attempts to spend [param amount] hint coins.
## Returns [code]true[/code] if the player had enough coins and the spend succeeded.
func spend_coins(amount: int) -> bool:
	var current: int = get_coins()
	if current < amount:
		return false
	_player_profile["hint_coins"] = current - amount
	_save_profile()
	EventBus.coins_changed.emit(_player_profile["hint_coins"] as int)
	return true


## Awards [param amount] hint coins to the player.
func award_coins(amount: int) -> void:
	_player_profile["hint_coins"] = (get_coins() + amount)
	_save_profile()
	EventBus.coins_changed.emit(_player_profile["hint_coins"] as int)


## Returns the player's current energy as a dictionary with "current" and "max" keys.
func get_energy() -> Dictionary:
	return _player_profile.get("energy", {"current": MAX_ENERGY, "max": MAX_ENERGY})


## Consumes one unit of energy. Returns [code]true[/code] on success.
func spend_energy() -> bool:
	var energy: Dictionary = get_energy()
	var current: int = energy.get("current", 0) as int
	if current <= 0:
		return false
	energy["current"] = current - 1
	energy["last_regen_time"] = Time.get_datetime_string_from_system(true)
	_player_profile["energy"] = energy
	_save_profile()
	EventBus.energy_changed.emit(energy["current"] as int, energy.get("max", MAX_ENERGY) as int)
	return true


## Restores one unit of energy (e.g., from a rewarded ad).
func restore_energy(amount: int = 1) -> void:
	var energy: Dictionary = get_energy()
	var current: int = energy.get("current", 0) as int
	var max_val: int = energy.get("max", MAX_ENERGY) as int
	energy["current"] = mini(current + amount, max_val)
	_player_profile["energy"] = energy
	_save_profile()
	EventBus.energy_changed.emit(energy["current"] as int, max_val)


## Returns the number of completed cases.
func get_cases_completed() -> int:
	return _player_profile.get("cases_completed", 0) as int


## Returns the total accumulated star count across all cases.
func get_total_stars() -> int:
	return _player_profile.get("total_stars", 0) as int


## Returns the array of completed case IDs.
func get_completed_cases() -> Array:
	return _player_profile.get("completed_cases", [])


## Returns [code]true[/code] if the given case has already been completed.
func is_case_completed(case_id: String) -> bool:
	return case_id in get_completed_cases()


## Updates the player's detective name.
func set_detective_name(new_name: String) -> void:
	_player_profile["detective_name"] = new_name
	_save_profile()


## Updates a setting in the player profile.
func update_setting(key: String, value: Variant) -> void:
	if _player_profile.has("settings"):
		_player_profile["settings"][key] = value
		_save_profile()


# ---------------------------------------------------------------------------
# Case Lifecycle
# ---------------------------------------------------------------------------

## Starts a new case (or resumes an existing one).
## Returns [code]true[/code] if the case was started successfully.
## [param case_id] The unique case identifier (e.g., "case_001").
func start_case(case_id: String) -> bool:
	if _game_state == GameState.CASE_ACTIVE and _active_case_id == case_id:
		push_warning("GameManager: Case '%s' is already active." % case_id)
		return true

	# New cases require energy (unless resuming an in-progress case).
	var has_existing_progress: bool = SaveManager.has_case_progress(case_id)
	if not has_existing_progress:
		# First 3 cases are energy-free (onboarding).
		var completed_count: int = get_cases_completed()
		if completed_count >= 3:
			if not spend_energy():
				push_warning("GameManager: Not enough energy to start case '%s'." % case_id)
				return false

	_active_case_id = case_id
	_game_state = GameState.CASE_ACTIVE
	_player_profile["current_case"] = case_id
	_save_profile()

	EventBus.case_loaded.emit(case_id)
	return true


## Marks the current case as completed with the given star rating.
## Awards coins and updates rank progression.
## [param case_id] The identifier of the completed case.
## [param stars] The star rating earned (1-3).
func complete_case(case_id: String, stars: int) -> void:
	stars = clampi(stars, 1, 3)

	var already_completed: bool = is_case_completed(case_id)

	if not already_completed:
		_player_profile.get("completed_cases", []).append(case_id)
		_player_profile["cases_completed"] = get_cases_completed() + 1
		_player_profile["total_stars"] = get_total_stars() + stars

		# Award coins.
		var bonus: int = CASE_COMPLETE_COINS
		if stars == 3:
			bonus += PERFECT_BONUS_COINS
			_player_profile["statistics"]["perfect_cases"] = (
				_player_profile.get("statistics", {}).get("perfect_cases", 0) as int + 1
			)
		award_coins(bonus)

		# Update rank.
		_update_rank()
	else:
		# Replay — only update stars if improved.
		var previous_stars: int = _get_best_stars(case_id)
		if stars > previous_stars:
			_player_profile["total_stars"] = get_total_stars() + (stars - previous_stars)

	_player_profile["current_case"] = ""
	_active_case_id = ""
	_game_state = GameState.CASE_COMPLETE
	_save_profile()

	EventBus.case_completed.emit(case_id, stars)


## Sets up a case replay by clearing saved progress and restarting.
## [param case_id] The identifier of the case to replay.
func replay_case(case_id: String) -> bool:
	SaveManager.delete_case_progress(case_id)
	return start_case(case_id)


## Returns to the main menu, clearing the active case reference.
func return_to_menu() -> void:
	_active_case_id = ""
	_game_state = GameState.MAIN_MENU
	_player_profile["current_case"] = ""
	_save_profile()


## Enters the daily puzzle mode.
func start_daily_puzzle() -> void:
	_game_state = GameState.DAILY_PUZZLE


## Marks the daily puzzle as completed, awarding coins and updating the streak.
func complete_daily_puzzle() -> void:
	var daily: Dictionary = _player_profile.get("daily_puzzle", {})
	var today: String = Time.get_date_string_from_system()
	var last_completed: String = daily.get("last_completed", "")

	if last_completed == today:
		push_warning("GameManager: Daily puzzle already completed today.")
		_game_state = GameState.MAIN_MENU
		return

	# Calculate streak: if last completion was yesterday, increment; otherwise reset.
	var streak: int = daily.get("streak", 0) as int
	if _is_yesterday(last_completed):
		streak += 1
	else:
		streak = 1

	daily["last_completed"] = today
	daily["streak"] = streak
	_player_profile["daily_puzzle"] = daily

	# Daily puzzle awards 2 coins.
	award_coins(2)

	_game_state = GameState.MAIN_MENU
	_save_profile()


# ---------------------------------------------------------------------------
# Rank Progression
# ---------------------------------------------------------------------------

## Recalculates the detective rank based on cases completed.
func _update_rank() -> void:
	var cases: int = get_cases_completed()
	var new_rank: DetectiveRank = DetectiveRank.ROOKIE

	# Walk thresholds in order; the highest satisfied threshold wins.
	for rank_value in RANK_THRESHOLDS:
		if cases >= (RANK_THRESHOLDS[rank_value] as int):
			new_rank = rank_value as DetectiveRank

	var new_rank_name: String = RANK_NAMES.get(new_rank, "rookie")
	var old_rank_name: String = _player_profile.get("rank", "rookie")

	if new_rank_name != old_rank_name:
		_player_profile["rank"] = new_rank_name
		# Rank-up refills energy.
		var energy: Dictionary = get_energy()
		energy["current"] = energy.get("max", MAX_ENERGY)
		_player_profile["energy"] = energy
		EventBus.energy_changed.emit(
			energy["current"] as int,
			energy.get("max", MAX_ENERGY) as int
		)
		_save_profile()


## Returns the [enum DetectiveRank] enum value for the given rank name string.
func _rank_name_to_enum(rank_name: String) -> DetectiveRank:
	for rank_value in RANK_NAMES:
		if RANK_NAMES[rank_value] == rank_name:
			return rank_value as DetectiveRank
	return DetectiveRank.ROOKIE


# ---------------------------------------------------------------------------
# Energy Regeneration
# ---------------------------------------------------------------------------

## Regenerates energy based on elapsed time since last regen timestamp.
func _regenerate_energy() -> void:
	var energy: Dictionary = get_energy()
	var current: int = energy.get("current", 0) as int
	var max_val: int = energy.get("max", MAX_ENERGY) as int

	if current >= max_val:
		return

	var last_regen_str: String = energy.get("last_regen_time", "")
	if last_regen_str.is_empty():
		return

	var now_unix: int = int(Time.get_unix_time_from_system())
	var last_dict: Dictionary = Time.get_datetime_dict_from_datetime_string(last_regen_str, true)
	if last_dict.is_empty():
		return
	var last_unix: int = int(Time.get_unix_time_from_datetime_dict(last_dict))

	var elapsed: int = now_unix - last_unix
	if elapsed <= 0:
		return

	@warning_ignore("integer_division")
	var units_to_regen: int = elapsed / ENERGY_REGEN_SECONDS
	if units_to_regen > 0:
		var new_energy: int = mini(current + units_to_regen, max_val)
		energy["current"] = new_energy
		energy["last_regen_time"] = Time.get_datetime_string_from_system(true)
		_player_profile["energy"] = energy
		_save_profile()
		EventBus.energy_changed.emit(new_energy, max_val)


# ---------------------------------------------------------------------------
# Persistence Helpers
# ---------------------------------------------------------------------------

## Loads (or creates) the player profile from SaveManager.
func _load_player_profile() -> void:
	_player_profile = SaveManager.load_profile()

	# Resume active case if one was in progress.
	var current_case: String = _player_profile.get("current_case", "")
	if not current_case.is_empty() and SaveManager.has_case_progress(current_case):
		_active_case_id = current_case
		_game_state = GameState.CASE_ACTIVE


## Persists the player profile through SaveManager.
func _save_profile() -> void:
	SaveManager.save_profile(_player_profile)


## Returns the best star rating previously earned for a case.
## Returns 0 if the case has not been completed.
func _get_best_stars(_case_id: String) -> int:
	# Star history is not stored per-case in the current save format,
	# so we return 0 (conservative). A future update may add per-case star tracking.
	return 0


## Returns [code]true[/code] if the given date string represents yesterday.
func _is_yesterday(date_string: String) -> bool:
	if date_string.is_empty():
		return false
	var today: Dictionary = Time.get_date_dict_from_system()
	var today_unix: int = int(Time.get_unix_time_from_datetime_dict(
		{"year": today["year"], "month": today["month"], "day": today["day"],
		 "hour": 0, "minute": 0, "second": 0}
	))
	var yesterday_unix: int = today_unix - 86400

	# Parse the stored date.
	var parts: PackedStringArray = date_string.split("-")
	if parts.size() < 3:
		return false
	var stored_unix: int = int(Time.get_unix_time_from_datetime_dict(
		{"year": parts[0].to_int(), "month": parts[1].to_int(), "day": parts[2].to_int(),
		 "hour": 0, "minute": 0, "second": 0}
	))
	return stored_unix >= yesterday_unix and stored_unix < today_unix
