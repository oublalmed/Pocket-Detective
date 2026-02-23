## EventBus — Global Signal Bus (AutoLoad Singleton)
##
## Central event system for decoupled communication between all game systems.
## Every system communicates through these signals. No system should directly
## reference another; instead, emit and listen to EventBus signals.
##
## Usage:
##   EventBus.clue_discovered.emit("clue_marc_car")
##   EventBus.clue_discovered.connect(_on_clue_discovered)
extends Node


# --- Evidence & Investigation Signals ---

## Emitted when the player discovers a new clue.
## [param clue_id] The unique identifier of the discovered clue.
signal clue_discovered(clue_id: String)

## Emitted when a connection is drawn between two clues on the evidence board.
## [param from_id] Source clue identifier.
## [param to_id] Target clue identifier.
## [param valid] Whether the connection is valid per the case data.
signal connection_made(from_id: String, to_id: String, valid: bool)

## Emitted when all required connections on the evidence board have been made.
## This unlocks the accusation phase.
signal connection_required_met()

# --- Interrogation & Dialogue Signals ---

## Emitted when the player begins interrogating a suspect.
## [param suspect_id] The unique identifier of the suspect being interrogated.
signal interrogation_started(suspect_id: String)

## Emitted when the player selects a dialogue choice during interrogation.
## [param node_id] The dialogue node the choice leads to.
## [param choice_id] The unique identifier of the selected choice.
signal dialogue_choice_made(node_id: String, choice_id: String)

# --- Accusation & Resolution Signals ---

## Emitted when the player submits an accusation against a suspect.
## [param suspect_id] The accused suspect's identifier.
## [param evidence] Array of evidence IDs presented as proof.
signal accusation_submitted(suspect_id: String, evidence: Array)

## Emitted when a case is fully completed (correct accusation accepted).
## [param case_id] The identifier of the completed case.
## [param stars] The star rating earned (1-3).
signal case_completed(case_id: String, stars: int)

# --- Hint System Signals ---

## Emitted when the player uses a hint.
## [param hint_type] The hint tier used: "nudge", "push", or "reveal".
## [param cost] The coin cost of the hint (0 if free).
signal hint_used(hint_type: String, cost: int)

# --- Notification Signals ---

## Emitted when an in-game phone notification should be shown.
## [param notification_id] The unique identifier of the notification from case data.
signal notification_fired(notification_id: String)

# --- Navigation Signals ---

## Emitted when the player opens an app on the simulated phone.
## [param app_name] The name of the app opened (e.g., "Messages", "Photos").
signal app_opened(app_name: String)

# --- Economy Signals ---

## Emitted when the player's energy amount changes.
## [param current] The current energy value after the change.
## [param max_val] The maximum energy capacity.
signal energy_changed(current: int, max_val: int)

## Emitted when the player's hint coin balance changes.
## [param amount] The new total coin balance.
signal coins_changed(amount: int)

# --- Case Management Signals ---

## Emitted when a case has been loaded into memory and is ready to play.
## [param case_id] The identifier of the loaded case.
signal case_loaded(case_id: String)
