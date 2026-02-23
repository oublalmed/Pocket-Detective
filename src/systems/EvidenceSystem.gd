## EvidenceSystem — Evidence Discovery & Validation
##
## Manages the discovery of evidence from all sources: photo hotspots,
## highlighted message text, call transcripts, and documents. Handles
## unlock conditions (some evidence only appears after other clues are found)
## and coordinates with StateManager for persistence and EventBus for
## cross-system notification.
##
## This is NOT an AutoLoad. It is instantiated by scenes or systems that need
## evidence discovery logic (e.g., PhotosApp, MessagesApp).
##
## Usage:
##   var evidence_system := EvidenceSystem.new()
##   add_child(evidence_system)
##   evidence_system.try_discover_clue("clue_marc_car")
##   evidence_system.is_evidence_unlocked("photo_002")
extends Node


# ---------------------------------------------------------------------------
# Public API — Clue Discovery
# ---------------------------------------------------------------------------

## Attempts to discover a clue by its ID.
## Validates that the clue exists in the case data and has not already been
## discovered. On success, updates StateManager and emits EventBus signals.
##
## Returns [code]true[/code] if the clue was newly discovered.
## [param clue_id] The unique identifier of the clue to discover.
func try_discover_clue(clue_id: String) -> bool:
	if not StateManager.has_active_case():
		push_warning("EvidenceSystem: No active case when trying to discover clue '%s'." % clue_id)
		return false

	# Already discovered?
	if StateManager.is_clue_discovered(clue_id):
		return false

	# Verify the clue exists in case data.
	var case_loader: RefCounted = StateManager.get_case_loader()
	var clue: Dictionary = case_loader.get_clue(clue_id)
	if clue.is_empty():
		push_warning("EvidenceSystem: Clue '%s' not found in case data." % clue_id)
		return false

	# Discover it through StateManager (which handles persistence + signal).
	var success: bool = StateManager.discover_clue(clue_id)
	if success:
		_check_notification_triggers(clue_id)
		_check_unlock_chains(clue_id)

	return success


## Attempts to discover a clue from a photo hotspot tap.
## Validates that the hotspot belongs to the photo and the photo is unlocked.
##
## Returns [code]true[/code] if the hotspot clue was newly discovered.
## [param photo_id] The photo containing the hotspot.
## [param hotspot_id] The specific hotspot tapped.
func try_discover_hotspot(photo_id: String, hotspot_id: String) -> bool:
	if not StateManager.has_active_case():
		return false

	var case_loader: RefCounted = StateManager.get_case_loader()
	var photo: Dictionary = case_loader.get_photo(photo_id)
	if photo.is_empty():
		push_warning("EvidenceSystem: Photo '%s' not found in case data." % photo_id)
		return false

	# Check if photo is unlocked.
	if not is_evidence_unlocked_by_condition(photo.get("unlock_condition", "")):
		push_warning("EvidenceSystem: Photo '%s' is still locked." % photo_id)
		return false

	# Find the hotspot and its clue_id.
	for hotspot: Dictionary in photo.get("hotspots", []):
		if hotspot.get("id", "") == hotspot_id:
			var clue_id: String = hotspot.get("clue_id", "")
			if clue_id.is_empty():
				return false
			return try_discover_clue(clue_id)

	push_warning("EvidenceSystem: Hotspot '%s' not found in photo '%s'." % [hotspot_id, photo_id])
	return false


## Attempts to discover a clue from tapping highlighted text in a message.
##
## Returns [code]true[/code] if the message clue was newly discovered.
## [param thread_id] The message thread ID.
## [param message_id] The specific message ID containing the clue.
func try_discover_message_clue(thread_id: String, message_id: String) -> bool:
	if not StateManager.has_active_case():
		return false

	var case_loader: RefCounted = StateManager.get_case_loader()
	var thread: Dictionary = case_loader.get_thread(thread_id)
	if thread.is_empty():
		push_warning("EvidenceSystem: Thread '%s' not found in case data." % thread_id)
		return false

	# Check if thread is unlocked.
	if not is_evidence_unlocked_by_condition(thread.get("unlock_condition", "")):
		return false

	# Find the message and its clue_id.
	for msg: Dictionary in thread.get("messages", []):
		if msg.get("id", "") == message_id:
			var clue_id: String = msg.get("clue_id", "")
			if clue_id.is_empty():
				return false  # Message has no clue.
			return try_discover_clue(clue_id)

	push_warning("EvidenceSystem: Message '%s' not found in thread '%s'." % [message_id, thread_id])
	return false


## Attempts to discover a clue from a call transcript line.
##
## Returns [code]true[/code] if the call clue was newly discovered.
## [param call_id] The call record ID.
## [param line_index] The index of the transcript line with the clue.
func try_discover_call_clue(call_id: String, line_index: int) -> bool:
	if not StateManager.has_active_case():
		return false

	var case_loader: RefCounted = StateManager.get_case_loader()
	var call_data: Dictionary = case_loader.get_call(call_id)
	if call_data.is_empty():
		push_warning("EvidenceSystem: Call '%s' not found in case data." % call_id)
		return false

	# Check unlock condition.
	if not is_evidence_unlocked_by_condition(call_data.get("unlock_condition", "")):
		return false

	var transcript: Array = call_data.get("transcript", [])
	if line_index < 0 or line_index >= transcript.size():
		return false

	var line: Dictionary = transcript[line_index]
	var clue_id: String = line.get("clue_id", "")
	if clue_id.is_empty():
		return false
	return try_discover_clue(clue_id)


## Attempts to discover a clue from a document.
##
## Returns [code]true[/code] if the document clue was newly discovered.
## [param document_id] The document evidence ID.
func try_discover_document_clue(document_id: String) -> bool:
	if not StateManager.has_active_case():
		return false

	var case_data: Dictionary = StateManager.get_current_case()
	for doc: Dictionary in case_data.get("evidence", {}).get("documents", []):
		if doc.get("id", "") == document_id:
			if not is_evidence_unlocked_by_condition(doc.get("unlock_condition", "")):
				return false
			var clue_id: String = doc.get("clue_id", "")
			if clue_id.is_empty():
				return false
			return try_discover_clue(clue_id)

	push_warning("EvidenceSystem: Document '%s' not found in case data." % document_id)
	return false


# ---------------------------------------------------------------------------
# Unlock Conditions
# ---------------------------------------------------------------------------

## Checks whether an evidence item is unlocked based on its unlock_condition.
## An empty or null condition means the item is always available.
## Otherwise, the condition is a clue_id that must have been discovered.
##
## Returns [code]true[/code] if the evidence is accessible.
## [param condition] The unlock_condition value from case data.
func is_evidence_unlocked_by_condition(condition: Variant) -> bool:
	if condition == null or (condition is String and (condition as String).is_empty()):
		return true
	if condition is String:
		return StateManager.is_clue_discovered(condition as String)
	return true


## Returns [code]true[/code] if a specific photo is currently accessible.
## [param photo_id] The photo evidence ID.
func is_photo_unlocked(photo_id: String) -> bool:
	var case_loader: RefCounted = StateManager.get_case_loader()
	var photo: Dictionary = case_loader.get_photo(photo_id)
	if photo.is_empty():
		return false
	return is_evidence_unlocked_by_condition(photo.get("unlock_condition", ""))


## Returns [code]true[/code] if a specific message thread is accessible.
## [param thread_id] The thread ID.
func is_thread_unlocked(thread_id: String) -> bool:
	var case_loader: RefCounted = StateManager.get_case_loader()
	var thread: Dictionary = case_loader.get_thread(thread_id)
	if thread.is_empty():
		return false
	return is_evidence_unlocked_by_condition(thread.get("unlock_condition", ""))


## Returns [code]true[/code] if a specific call record is accessible.
## [param call_id] The call ID.
func is_call_unlocked(call_id: String) -> bool:
	var case_loader: RefCounted = StateManager.get_case_loader()
	var call_data: Dictionary = case_loader.get_call(call_id)
	if call_data.is_empty():
		return false
	return is_evidence_unlocked_by_condition(call_data.get("unlock_condition", ""))


# ---------------------------------------------------------------------------
# Query Helpers
# ---------------------------------------------------------------------------

## Returns all photos that are currently unlocked (visible to the player).
func get_unlocked_photos() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var case_data: Dictionary = StateManager.get_current_case()
	for photo: Dictionary in case_data.get("evidence", {}).get("photos", []):
		if is_evidence_unlocked_by_condition(photo.get("unlock_condition", "")):
			result.append(photo)
	return result


## Returns all message threads that are currently unlocked.
func get_unlocked_threads() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var case_data: Dictionary = StateManager.get_current_case()
	for thread: Dictionary in case_data.get("evidence", {}).get("messages", []):
		if is_evidence_unlocked_by_condition(thread.get("unlock_condition", "")):
			result.append(thread)
	return result


## Returns all call records that are currently unlocked.
func get_unlocked_calls() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var case_data: Dictionary = StateManager.get_current_case()
	for call_data: Dictionary in case_data.get("evidence", {}).get("calls", []):
		if is_evidence_unlocked_by_condition(call_data.get("unlock_condition", "")):
			result.append(call_data)
	return result


## Returns all undiscovered hotspot IDs for a given photo.
func get_undiscovered_hotspots(photo_id: String) -> Array[String]:
	var result: Array[String] = []
	var case_loader: RefCounted = StateManager.get_case_loader()
	var photo: Dictionary = case_loader.get_photo(photo_id)
	for hotspot: Dictionary in photo.get("hotspots", []):
		var clue_id: String = hotspot.get("clue_id", "")
		if not clue_id.is_empty() and not StateManager.is_clue_discovered(clue_id):
			result.append(hotspot.get("id", ""))
	return result


## Returns the total number of discoverable clues across all evidence types.
func get_total_discoverable_clues() -> int:
	return StateManager.get_total_clue_count()


## Returns how many clues the player has discovered so far.
func get_discovered_clue_count() -> int:
	return StateManager.get_discovered_clue_count()


# ---------------------------------------------------------------------------
# Internal Helpers
# ---------------------------------------------------------------------------

## Checks if discovering a clue should trigger any case notifications.
func _check_notification_triggers(clue_id: String) -> void:
	var case_data: Dictionary = StateManager.get_current_case()
	for notif: Dictionary in case_data.get("notifications", []):
		var trigger: Variant = notif.get("trigger", null)
		if trigger is Dictionary:
			var trigger_dict: Dictionary = trigger as Dictionary
			if trigger_dict.has("clue_discovered"):
				if trigger_dict["clue_discovered"] == clue_id:
					if not StateManager.is_notification_seen(notif.get("id", "")):
						EventBus.notification_fired.emit(notif.get("id", ""))


## Checks if discovering a clue unlocks new evidence (photo, thread, etc.)
## by satisfying unlock_condition fields on other evidence items.
func _check_unlock_chains(clue_id: String) -> void:
	var case_data: Dictionary = StateManager.get_current_case()

	# Check photos that might now be unlocked.
	for photo: Dictionary in case_data.get("evidence", {}).get("photos", []):
		var condition: Variant = photo.get("unlock_condition", "")
		if condition is String and condition == clue_id:
			# Photo is now unlocked — fire a notification if one exists for it.
			_fire_unlock_notification("photo_unlocked", photo.get("id", ""))

	# Check threads that might now be unlocked.
	for thread: Dictionary in case_data.get("evidence", {}).get("messages", []):
		var condition: Variant = thread.get("unlock_condition", "")
		if condition is String and condition == clue_id:
			_fire_unlock_notification("thread_unlocked", thread.get("thread_id", ""))

	# Check calls that might now be unlocked.
	for call_data: Dictionary in case_data.get("evidence", {}).get("calls", []):
		var condition: Variant = call_data.get("unlock_condition", "")
		if condition is String and condition == clue_id:
			_fire_unlock_notification("call_unlocked", call_data.get("id", ""))

	# Check documents that might now be unlocked.
	for doc: Dictionary in case_data.get("evidence", {}).get("documents", []):
		var condition: Variant = doc.get("unlock_condition", "")
		if condition is String and condition == clue_id:
			_fire_unlock_notification("document_unlocked", doc.get("id", ""))


## Fires a notification for newly unlocked evidence if applicable.
## This checks the notifications list for any trigger matching the unlock event.
func _fire_unlock_notification(_unlock_type: String, _item_id: String) -> void:
	# Unlock notifications are typically handled through clue_discovered triggers
	# in the case JSON. This is a hook for future custom unlock notifications.
	pass
