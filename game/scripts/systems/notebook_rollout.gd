extends RefCounted


static func enabled() -> bool:
	# Remove this gate only after producer mapping and disclosure acceptance pass.
	return OS.is_debug_build() and ("--ggb-dev-notebook-v2" in OS.get_cmdline_user_args() or "--notebook-migration-smoke" in OS.get_cmdline_user_args())


static func new_history() -> Dictionary:
	return preload("res://scripts/systems/notebook_archive.gd").create() if enabled() else {"next_sequence": 0, "entries": []}


static func fork_history(history: Dictionary) -> Dictionary:
	return preload("res://scripts/systems/notebook_archive.gd").fork(history).archive if history.has("schema_version") else history.duplicate(true)
