extends RefCounted

class_name ScenarioState

# ============================================================================
# SCENARIO STATE MACHINE
# ============================================================================
# Manages scenario lifecycle states and transitions.
# ============================================================================

enum State {
	NONE,           # No scenario active
	LOADING,        # Loading scenario assets
	STARTING,       # Scenario loaded, initializing
	RUNNING,        # Scenario in progress, player has control
	CUTSCENE,       # Final cutscene playing, no player control
	PAUSED,         # Scenario paused by player
	COMPLETED,      # Scenario ended successfully (projectile hit tank)
	FAILED,         # Scenario ended in failure (missed, timeout, out of bounds)
}

signal state_changed(old_state: State, new_state: State)

var current_state: State = State.NONE
var previous_state: State = State.NONE

# Valid state transitions
var _valid_transitions: Dictionary = {
	State.NONE: [State.LOADING],
	State.LOADING: [State.STARTING, State.NONE],
	State.STARTING: [State.RUNNING, State.NONE],
	State.RUNNING: [State.CUTSCENE, State.PAUSED, State.COMPLETED, State.FAILED, State.NONE],
	State.CUTSCENE: [State.COMPLETED, State.FAILED, State.NONE],
	State.PAUSED: [State.RUNNING, State.NONE],
	State.COMPLETED: [State.NONE],
	State.FAILED: [State.NONE],
}


func transition_to(new_state: State) -> bool:
	if not can_transition_to(new_state):
		push_warning("ScenarioState: Invalid transition from %s to %s" % [
			State.keys()[current_state], State.keys()[new_state]
		])
		return false
	
	previous_state = current_state
	current_state = new_state
	state_changed.emit(previous_state, current_state)
	return true


func can_transition_to(new_state: State) -> bool:
	if current_state == new_state:
		return false
	var valid = _valid_transitions.get(current_state, [])
	return new_state in valid


func is_state(state: State) -> bool:
	return current_state == state


func is_any_state(states: Array[State]) -> bool:
	return current_state in states


func is_active() -> bool:
	# Returns true if a scenario is currently in progress
	return current_state in [State.LOADING, State.STARTING, State.RUNNING, State.CUTSCENE, State.PAUSED]


func is_player_control_enabled() -> bool:
	return current_state == State.RUNNING


func get_state_name() -> String:
	return State.keys()[current_state]


func reset() -> void:
	previous_state = current_state
	current_state = State.NONE
