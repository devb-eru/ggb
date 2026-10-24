extends RefCounted


static func enabled() -> bool:
	# The integrated notebook is the normal UI. Verified legacy saves are adapted
	# by SaveManager; browsing never manufactures undisclosed observations.
	return true


static func new_history() -> Dictionary:
	return preload("res://scripts/systems/notebook_archive.gd").create() if enabled() else {"next_sequence": 0, "entries": []}


static func fork_history(history: Dictionary) -> Dictionary:
	return preload("res://scripts/systems/notebook_archive.gd").fork(history).archive if history.has("schema_version") else history.duplicate(true)
