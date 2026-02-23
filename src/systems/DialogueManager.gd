## DialogueManager — Conversation Tree Traversal
##
## Navigates dialogue trees from interrogation data in the case JSON.
## Handles evidence-gated choices (only showing options when the player
## has discovered the required evidence), tracks visited nodes, and
## reveals clues embedded in dialogue responses.
##
## This is NOT an AutoLoad. It is instantiated by the InterrogationScreen
## or any system that needs dialogue traversal.
##
## Usage:
##   var dialogue := DialogueManager.new()
##   add_child(dialogue)
##   var opening := dialogue.start_interrogation("suspect_sophie")
##   var response := dialogue.select_choice("q1")
extends Node


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## The suspect_id currently being interrogated.
var _current_suspect_id: String = ""

## The current dialogue node ID within the tree.
var _current_node_id: String = ""

## Whether an interrogation is in progress.
var _active: bool = false


# ---------------------------------------------------------------------------
# Public API — Interrogation Flow
# ---------------------------------------------------------------------------

## Starts an interrogation with the given suspect.
## Returns a DialogueResult dictionary with the opening node data and
## available choices filtered by evidence.
##
## Returns an empty dictionary if the suspect has no interrogation data.
## [param suspect_id] The unique suspect identifier.
func start_interrogation(suspect_id: String) -> Dictionary:
	if not StateManager.has_active_case():
		push_warning("DialogueManager: No active case for interrogation.")
		return {}

	var case_loader: RefCounted = StateManager.get_case_loader()
	var interrogation: Dictionary = case_loader.get_interrogation(suspect_id)
	if interrogation.is_empty():
		push_warning("DialogueManager: No interrogation data for '%s'." % suspect_id)
		return {}

	# Check unlock condition.
	var unlock_condition: Variant = interrogation.get("unlock_condition", null)
	if unlock_condition is String and not (unlock_condition as String).is_empty():
		if not StateManager.is_clue_discovered(unlock_condition as String):
			push_warning("DialogueManager: Interrogation for '%s' is locked (requires '%s')." % [suspect_id, unlock_condition])
			return {}

	_current_suspect_id = suspect_id
	_current_node_id = "start"
	_active = true

	var dialogue_tree: Dictionary = interrogation.get("dialogue_tree", {})
	var node: Dictionary = dialogue_tree.get("start", {})
	if node.is_empty():
		push_warning("DialogueManager: No 'start' node in dialogue tree for '%s'." % suspect_id)
		_active = false
		return {}

	# Record the interrogation start.
	StateManager.record_interrogation_started(suspect_id)
	StateManager.visit_dialogue_node(suspect_id, "start")

	# Filter choices based on evidence the player has.
	var available_choices: Array = _filter_choices_by_evidence(node.get("choices", []))

	EventBus.interrogation_started.emit(suspect_id)

	return _build_result(node, available_choices, false)


## Selects a dialogue choice and advances to the next node.
## Returns a DialogueResult dictionary with the response data and new choices.
##
## Returns an empty dictionary if the choice is invalid.
## [param choice_id] The unique identifier of the selected choice.
func select_choice(choice_id: String) -> Dictionary:
	if not _active:
		push_warning("DialogueManager: No active interrogation.")
		return {}

	var case_loader: RefCounted = StateManager.get_case_loader()
	var interrogation: Dictionary = case_loader.get_interrogation(_current_suspect_id)
	var dialogue_tree: Dictionary = interrogation.get("dialogue_tree", {})
	var current_node: Dictionary = dialogue_tree.get(_current_node_id, {})

	# Find the selected choice in the current node.
	var selected_choice: Dictionary = {}
	for choice: Dictionary in current_node.get("choices", []):
		if choice.get("id", "") == choice_id:
			selected_choice = choice
			break

	if selected_choice.is_empty():
		push_warning("DialogueManager: Choice '%s' not found in node '%s'." % [choice_id, _current_node_id])
		return {}

	# Validate evidence requirement (in case UI allowed a gated choice).
	var requires: Variant = selected_choice.get("requires_evidence", null)
	if requires is String and not (requires as String).is_empty():
		if not StateManager.is_clue_discovered(requires as String):
			push_warning("DialogueManager: Choice '%s' requires evidence '%s' not yet discovered." % [choice_id, requires])
			return {}

	# Advance to the next node.
	var next_node_id: String = selected_choice.get("next", "")
	if next_node_id.is_empty():
		push_warning("DialogueManager: Choice '%s' has no 'next' node." % choice_id)
		return {}

	var next_node: Dictionary = dialogue_tree.get(next_node_id, {})
	if next_node.is_empty():
		push_warning("DialogueManager: Target node '%s' not found in dialogue tree." % next_node_id)
		return {}

	_current_node_id = next_node_id

	# Track the visited node.
	StateManager.visit_dialogue_node(_current_suspect_id, next_node_id)

	# Reveal clue if the node defines one.
	var clue_revealed: Variant = next_node.get("clue_revealed", null)
	if clue_revealed is String and not (clue_revealed as String).is_empty():
		StateManager.discover_clue(clue_revealed as String)

	# Emit dialogue choice signal.
	EventBus.dialogue_choice_made.emit(next_node_id, choice_id)

	# Determine if this node ends the conversation.
	var is_end: bool = next_node.get("end", false)
	if is_end:
		_active = false

	var available_choices: Array = _filter_choices_by_evidence(next_node.get("choices", []))

	return _build_result(next_node, available_choices, is_end)


## Ends the current interrogation early (e.g., player presses back).
func end_interrogation() -> void:
	_active = false
	_current_suspect_id = ""
	_current_node_id = ""


# ---------------------------------------------------------------------------
# Query Methods
# ---------------------------------------------------------------------------

## Returns [code]true[/code] if an interrogation is currently in progress.
func is_active() -> bool:
	return _active


## Returns the suspect_id of the current interrogation.
func get_current_suspect_id() -> String:
	return _current_suspect_id


## Returns the current dialogue node ID.
func get_current_node_id() -> String:
	return _current_node_id


## Returns [code]true[/code] if the given dialogue node has been visited
## in any session (persisted across saves).
## [param suspect_id] The suspect being interrogated.
## [param node_id] The dialogue node to check.
func is_node_visited(suspect_id: String, node_id: String) -> bool:
	return StateManager.is_dialogue_node_visited(suspect_id, node_id)


## Returns all visited node IDs for a suspect across all sessions.
func get_visited_nodes(suspect_id: String) -> Array:
	return StateManager.get_visited_nodes(suspect_id)


## Returns [code]true[/code] if the interrogation for the given suspect
## is available (unlocked and has data).
## [param suspect_id] The suspect to check.
func is_interrogation_available(suspect_id: String) -> bool:
	var case_loader: RefCounted = StateManager.get_case_loader()
	var interrogation: Dictionary = case_loader.get_interrogation(suspect_id)
	if interrogation.is_empty():
		return false

	var unlock_condition: Variant = interrogation.get("unlock_condition", null)
	if unlock_condition == null:
		return true
	if unlock_condition is String:
		if (unlock_condition as String).is_empty():
			return true
		return StateManager.is_clue_discovered(unlock_condition as String)
	return true


## Returns the available (evidence-unlocked) choices for a given node
## without advancing the dialogue. Useful for previewing options in UI.
## [param suspect_id] The suspect whose dialogue tree to check.
## [param node_id] The node to get choices for.
func get_available_choices_for_node(suspect_id: String, node_id: String) -> Array:
	var case_loader: RefCounted = StateManager.get_case_loader()
	var interrogation: Dictionary = case_loader.get_interrogation(suspect_id)
	var dialogue_tree: Dictionary = interrogation.get("dialogue_tree", {})
	var node: Dictionary = dialogue_tree.get(node_id, {})
	return _filter_choices_by_evidence(node.get("choices", []))


## Returns the total number of dialogue nodes defined for a suspect.
func get_total_node_count(suspect_id: String) -> int:
	var case_loader: RefCounted = StateManager.get_case_loader()
	var interrogation: Dictionary = case_loader.get_interrogation(suspect_id)
	return interrogation.get("dialogue_tree", {}).size()


## Returns a progress ratio (0.0 to 1.0) representing how much of a
## suspect's dialogue tree has been explored.
func get_interrogation_progress(suspect_id: String) -> float:
	var total: int = get_total_node_count(suspect_id)
	if total == 0:
		return 0.0
	var visited: int = get_visited_nodes(suspect_id).size()
	return clampf(float(visited) / float(total), 0.0, 1.0)


# ---------------------------------------------------------------------------
# Internal Helpers
# ---------------------------------------------------------------------------

## Filters a list of dialogue choices, keeping only those whose evidence
## requirements are met (or that have no requirements).
func _filter_choices_by_evidence(choices: Array) -> Array:
	var filtered: Array = []
	for choice: Dictionary in choices:
		var requires: Variant = choice.get("requires_evidence", null)
		if requires == null:
			filtered.append(choice)
		elif requires is String:
			var req_str: String = requires as String
			if req_str.is_empty() or StateManager.is_clue_discovered(req_str):
				filtered.append(choice)
		else:
			# Unknown condition format — include by default.
			filtered.append(choice)
	return filtered


## Builds a standardized DialogueResult dictionary.
## [param node] The dialogue node data.
## [param choices] The filtered available choices.
## [param is_end] Whether this node ends the conversation.
func _build_result(node: Dictionary, choices: Array, is_end: bool) -> Dictionary:
	return {
		"speaker": node.get("speaker", ""),
		"text": node.get("text", ""),
		"emotion": node.get("emotion", "calm"),
		"choices": choices,
		"is_end": is_end,
		"clue_revealed": node.get("clue_revealed", ""),
		"node_id": _current_node_id,
	}
