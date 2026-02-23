## HintManager — Hint Logic & Economy (AutoLoad Singleton)
##
## Implements the three-tier hint system for clues and connections.
## Manages hint costs, tracks usage per case (which affects star rating),
## and integrates with GameManager for the coin economy.
##
## Hint Tiers:
##   nudge  — Vague directional hint. Free (first hint in a case) or 1 coin.
##   push   — Specific pointer to relevant evidence. Costs 1 coin.
##   reveal — Direct answer with full explanation. Costs 2 coins.
##
## The first hint in every case is always free, regardless of tier.
## Hint text is authored in the case JSON under the "hints" key.
##
## Usage:
##   var result := HintManager.get_hint("clue_marc_car", "nudge")
##   if result.success:
##       show_hint_popup(result.text)
extends Node


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Available hint tiers from least to most informative.
const TIER_NUDGE: String = "nudge"
const TIER_PUSH: String = "push"
const TIER_REVEAL: String = "reveal"

## Coin costs for each hint tier.
const TIER_COSTS: Dictionary = {
	TIER_NUDGE: 0,
	TIER_PUSH: 1,
	TIER_REVEAL: 2,
}

## Ordered list of tiers from least to most informative.
const TIER_ORDER: Array[String] = [TIER_NUDGE, TIER_PUSH, TIER_REVEAL]


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Tracks which hints have been used per target in the current case.
## Key = target_id (clue or connection ID), Value = Array of tier strings used.
var _hints_used_this_case: Dictionary = {}

## Tracks whether the free first hint has been consumed this case.
var _first_hint_used: bool = false


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	EventBus.case_loaded.connect(_on_case_loaded)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Attempts to provide a hint for the given target at the specified tier.
## Returns a result dictionary with:
##   [code]success[/code] (bool) — whether the hint was delivered.
##   [code]text[/code] (String) — the hint text (empty on failure).
##   [code]cost[/code] (int) — the coins charged.
##   [code]tier[/code] (String) — the tier provided.
##   [code]error[/code] (String) — reason for failure (empty on success).
##
## [param target_id] The clue_id or connection_id to get a hint for.
## [param tier] One of "nudge", "push", or "reveal".
func get_hint(target_id: String, tier: String) -> Dictionary:
	# Validate tier.
	if tier not in TIER_ORDER:
		return _fail("Invalid hint tier: '%s'." % tier)

	# Ensure a case is loaded.
	if not StateManager.has_active_case():
		return _fail("No active case loaded.")

	# Look up hint data from the case.
	var case_loader: RefCounted = StateManager.get_case_loader()
	var hint_data: Dictionary = case_loader.get_hint_data(target_id)
	if hint_data.is_empty():
		return _fail("No hints available for target '%s'." % target_id)

	# Ensure the requested tier text exists.
	var hint_text: String = hint_data.get(tier, "")
	if hint_text.is_empty():
		return _fail("No '%s' hint text defined for target '%s'." % [tier, target_id])

	# Check if this exact tier was already used for this target.
	if _is_tier_used(target_id, tier):
		# Return the text again for free (re-reading a used hint).
		return {"success": true, "text": hint_text, "cost": 0, "tier": tier, "error": ""}

	# Determine actual cost.
	var cost: int = _calculate_cost(tier)

	# Attempt to spend coins (if cost > 0).
	if cost > 0:
		if not GameManager.spend_coins(cost):
			return _fail("Not enough coins. Need %d, have %d." % [cost, GameManager.get_coins()])

	# Record usage.
	_record_hint_usage(target_id, tier)
	StateManager.record_hint_used()

	# Emit signal through EventBus.
	EventBus.hint_used.emit(tier, cost)

	return {"success": true, "text": hint_text, "cost": cost, "tier": tier, "error": ""}


## Returns the next available (unused) hint tier for a target.
## Returns an empty string if all tiers have been used.
## [param target_id] The clue_id or connection_id.
func get_next_available_tier(target_id: String) -> String:
	var used: Array = _hints_used_this_case.get(target_id, [])
	for tier: String in TIER_ORDER:
		if tier not in used:
			return tier
	return ""


## Returns [code]true[/code] if a specific hint tier has been used for a target.
func is_hint_used(target_id: String, tier: String) -> bool:
	return _is_tier_used(target_id, tier)


## Returns how many total hints have been used in the current case.
func get_hints_used_count() -> int:
	return StateManager.get_hints_used()


## Returns the coin cost for the given tier, considering the free first hint.
## [param tier] One of "nudge", "push", or "reveal".
func get_cost_for_tier(tier: String) -> int:
	return _calculate_cost(tier)


## Returns [code]true[/code] if the first-hint-free bonus is still available.
func is_first_hint_free() -> bool:
	return not _first_hint_used


## Returns a dictionary of all hint tiers and whether they have been used
## for a given target. Useful for building the hint UI.
## [param target_id] The clue or connection ID.
func get_hint_status(target_id: String) -> Dictionary:
	var case_loader: RefCounted = StateManager.get_case_loader()
	var hint_data: Dictionary = case_loader.get_hint_data(target_id)
	var used: Array = _hints_used_this_case.get(target_id, [])

	var status: Dictionary = {}
	for tier: String in TIER_ORDER:
		status[tier] = {
			"available": not hint_data.get(tier, "").is_empty(),
			"used": tier in used,
			"cost": _calculate_cost(tier) if tier not in used else 0,
		}
	return status


# ---------------------------------------------------------------------------
# Internal Helpers
# ---------------------------------------------------------------------------

## Calculates the effective coin cost for a hint tier.
## The first hint in every case is free regardless of tier.
func _calculate_cost(tier: String) -> int:
	if not _first_hint_used:
		return 0
	return TIER_COSTS.get(tier, 0) as int


## Records that a hint tier was used for a target.
func _record_hint_usage(target_id: String, tier: String) -> void:
	if not _hints_used_this_case.has(target_id):
		_hints_used_this_case[target_id] = []
	var used: Array = _hints_used_this_case[target_id]
	if tier not in used:
		used.append(tier)

	# Mark first hint as consumed.
	if not _first_hint_used:
		_first_hint_used = true


## Returns [code]true[/code] if the tier has been used for the target.
func _is_tier_used(target_id: String, tier: String) -> bool:
	var used: Array = _hints_used_this_case.get(target_id, [])
	return tier in used


## Builds a failure result dictionary.
func _fail(error_message: String) -> Dictionary:
	return {"success": false, "text": "", "cost": 0, "tier": "", "error": error_message}


## Resets per-case hint tracking when a new case is loaded.
func _on_case_loaded(_case_id: String) -> void:
	_hints_used_this_case.clear()
	_first_hint_used = false

	# Restore hint state from saved progress if resuming a case.
	var progress: Dictionary = StateManager.get_case_progress()
	var saved_hints_used: int = progress.get("hints_used", 0) as int
	if saved_hints_used > 0:
		_first_hint_used = true
