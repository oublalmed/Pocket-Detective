## AccusationSystem — Accusation Validation
##
## Validates the player's final accusation (suspect selection + evidence
## presentation) against the case data. Calculates the star rating based
## on hints used, evidence found, and wrong accusations. Returns a
## comprehensive AccusationResult for the resolution screen.
##
## Accusation Flow:
##   1. Player completes all required connections on the evidence board.
##   2. "Accuse" button appears. Player selects a suspect.
##   3. Player selects key evidence pieces to support the accusation.
##   4. This system validates correctness and calculates the star rating.
##   5. On success, GameManager.complete_case() is called.
##   6. On failure, the player may retry (wrong attempts affect rating).
##
## This is NOT an AutoLoad. It is instantiated by the AccusationScreen.
##
## Usage:
##   var accusation := AccusationSystem.new()
##   add_child(accusation)
##   var result := accusation.submit_accusation("suspect_marc", ["clue_marc_car", ...])
extends Node


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Result status values.
const STATUS_CORRECT: String = "correct"
const STATUS_WRONG_SUSPECT: String = "wrong_suspect"
const STATUS_WRONG_EVIDENCE: String = "wrong_evidence"


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Submits an accusation against a suspect with supporting evidence.
## Returns an AccusationResult dictionary with:
##   [code]status[/code] (String) — STATUS_CORRECT, STATUS_WRONG_SUSPECT, or STATUS_WRONG_EVIDENCE.
##   [code]correct_suspect[/code] (bool) — whether the right suspect was chosen.
##   [code]correct_evidence[/code] (bool) — whether sufficient required evidence was presented.
##   [code]stars[/code] (int) — star rating (1-3), only meaningful when status == STATUS_CORRECT.
##   [code]message[/code] (String) — narrative text or hint for the player.
##   [code]evidence_breakdown[/code] (Dictionary) — details of matched/missing evidence.
##   [code]case_id[/code] (String) — the case being resolved.
##
## [param suspect_id] The suspect the player is accusing.
## [param evidence_ids] Array of clue IDs the player presents as proof.
func submit_accusation(suspect_id: String, evidence_ids: Array) -> Dictionary:
	if not StateManager.has_active_case():
		push_warning("AccusationSystem: No active case for accusation.")
		return _build_error_result("No active case loaded.")

	var case_data: Dictionary = StateManager.get_current_case()
	var accusation_data: Dictionary = case_data.get("accusation", {})
	var case_id: String = case_data.get("meta", {}).get("case_id", "")

	var culprit: String = accusation_data.get("culprit", "")
	var required_evidence: Array = accusation_data.get("required_evidence", [])
	var min_evidence: int = accusation_data.get("min_evidence_count", required_evidence.size()) as int

	# Check suspect.
	var is_correct_suspect: bool = (suspect_id == culprit)

	if not is_correct_suspect:
		# Wrong suspect — record and return hint.
		StateManager.record_wrong_accusation()

		EventBus.accusation_submitted.emit(suspect_id, evidence_ids)

		return {
			"status": STATUS_WRONG_SUSPECT,
			"correct_suspect": false,
			"correct_evidence": false,
			"stars": 0,
			"message": accusation_data.get("wrong_accusation_hint", "The evidence doesn't support this accusation."),
			"evidence_breakdown": _build_evidence_breakdown(evidence_ids, required_evidence),
			"case_id": case_id,
		}

	# Correct suspect — now validate evidence.
	var matching_evidence: Array[String] = []
	var extra_evidence: Array[String] = []
	var missing_evidence: Array[String] = []

	for ev_id: String in evidence_ids:
		if ev_id in required_evidence:
			matching_evidence.append(ev_id)
		else:
			extra_evidence.append(ev_id)

	for req_id: String in required_evidence:
		if req_id not in evidence_ids:
			missing_evidence.append(req_id)

	var has_enough_evidence: bool = matching_evidence.size() >= min_evidence

	if not has_enough_evidence:
		# Right suspect but insufficient evidence.
		EventBus.accusation_submitted.emit(suspect_id, evidence_ids)

		return {
			"status": STATUS_WRONG_EVIDENCE,
			"correct_suspect": true,
			"correct_evidence": false,
			"stars": 0,
			"message": accusation_data.get("wrong_evidence_hint", "Your evidence isn't convincing enough."),
			"evidence_breakdown": {
				"matching": matching_evidence,
				"extra": extra_evidence,
				"missing": missing_evidence,
				"required_count": min_evidence,
				"matched_count": matching_evidence.size(),
			},
			"case_id": case_id,
		}

	# CASE SOLVED — calculate star rating.
	var stars: int = _calculate_stars(case_data)

	# Complete the case through GameManager.
	GameManager.complete_case(case_id, stars)

	# The case_completed signal is emitted by GameManager.complete_case().
	EventBus.accusation_submitted.emit(suspect_id, evidence_ids)

	var resolution: Dictionary = case_data.get("resolution", {})

	return {
		"status": STATUS_CORRECT,
		"correct_suspect": true,
		"correct_evidence": true,
		"stars": stars,
		"message": resolution.get("arrest_narrative", "Case solved!"),
		"evidence_summary": resolution.get("evidence_summary", ""),
		"epilogue": resolution.get("epilogue", ""),
		"next_case_teaser": resolution.get("next_case_teaser", {}),
		"evidence_breakdown": {
			"matching": matching_evidence,
			"extra": extra_evidence,
			"missing": missing_evidence,
			"required_count": min_evidence,
			"matched_count": matching_evidence.size(),
		},
		"case_stats": _build_case_stats(),
		"case_id": case_id,
	}


## Returns [code]true[/code] if the accusation phase is unlocked
## (all required connections have been made).
func is_accusation_unlocked() -> bool:
	return StateManager.is_accusation_ready()


## Returns the list of suspects available for accusation.
## Each entry is a dictionary from the case data suspects array.
func get_accusable_suspects() -> Array:
	var case_data: Dictionary = StateManager.get_current_case()
	return case_data.get("suspects", [])


## Returns the list of discovered clues that can be presented as evidence.
## Each entry is the full clue dictionary from case data.
func get_presentable_evidence() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var case_loader: RefCounted = StateManager.get_case_loader()
	for clue_id: String in StateManager.get_discovered_clues():
		var clue: Dictionary = case_loader.get_clue(clue_id)
		if not clue.is_empty():
			result.append(clue)
	return result


## Returns the minimum number of evidence pieces required for a conviction.
func get_min_evidence_count() -> int:
	var case_data: Dictionary = StateManager.get_current_case()
	var accusation_data: Dictionary = case_data.get("accusation", {})
	var required: Array = accusation_data.get("required_evidence", [])
	return accusation_data.get("min_evidence_count", required.size()) as int


## Returns the number of wrong accusations made so far in this case.
func get_wrong_accusation_count() -> int:
	return StateManager.get_wrong_accusations()


# ---------------------------------------------------------------------------
# Star Rating Calculation
# ---------------------------------------------------------------------------

## Calculates the star rating based on case performance.
##
## 3 Stars: No hints used AND all evidence discovered.
## 2 Stars: Hints used within the two-star threshold.
## 1 Star:  Everything else (case still solved).
##
## [param case_data] The full case data dictionary.
func _calculate_stars(case_data: Dictionary) -> int:
	var progress: Dictionary = StateManager.get_case_progress()
	var hints_used: int = progress.get("hints_used", 0) as int
	var wrong_accusations: int = progress.get("wrong_accusations", 0) as int
	var discovered_count: int = StateManager.get_discovered_clue_count()
	var total_clues: int = StateManager.get_total_clue_count()
	var all_evidence_found: bool = discovered_count >= total_clues

	var stars_config: Dictionary = case_data.get("meta", {}).get("stars_config", {})

	# Three-star check.
	var three_star: Dictionary = stars_config.get("three_star", {})
	var three_max_hints: int = three_star.get("max_hints", 0) as int
	var three_needs_all: bool = three_star.get("all_evidence", true)

	if hints_used <= three_max_hints and (not three_needs_all or all_evidence_found) and wrong_accusations == 0:
		return 3

	# Two-star check.
	var two_star: Dictionary = stars_config.get("two_star", {})
	var two_max_hints: int = two_star.get("max_hints", 2) as int

	if hints_used <= two_max_hints:
		return 2

	# Default to 1 star (case still solved).
	return 1


# ---------------------------------------------------------------------------
# Case Statistics
# ---------------------------------------------------------------------------

## Builds a statistics dictionary for the resolution screen.
func _build_case_stats() -> Dictionary:
	var progress: Dictionary = StateManager.get_case_progress()
	var started_at: String = progress.get("started_at", "")
	var last_played: String = progress.get("last_played", "")

	return {
		"clues_discovered": StateManager.get_discovered_clue_count(),
		"total_clues": StateManager.get_total_clue_count(),
		"connections_made": StateManager.get_valid_connection_count(),
		"hints_used": progress.get("hints_used", 0),
		"wrong_accusations": progress.get("wrong_accusations", 0),
		"started_at": started_at,
		"completed_at": last_played,
	}


## Builds a breakdown of how the player's evidence compares to required evidence.
func _build_evidence_breakdown(presented: Array, required: Array) -> Dictionary:
	var matching: Array[String] = []
	var extra: Array[String] = []
	var missing: Array[String] = []

	for ev_id in presented:
		if ev_id in required:
			matching.append(ev_id as String)
		else:
			extra.append(ev_id as String)

	for req_id in required:
		if req_id not in presented:
			missing.append(req_id as String)

	return {
		"matching": matching,
		"extra": extra,
		"missing": missing,
		"required_count": required.size(),
		"matched_count": matching.size(),
	}


## Builds an error result for when accusations cannot be processed.
func _build_error_result(reason: String) -> Dictionary:
	return {
		"status": "error",
		"correct_suspect": false,
		"correct_evidence": false,
		"stars": 0,
		"message": reason,
		"evidence_breakdown": {},
		"case_id": "",
	}
