extends RefCounted

const HOST := preload("res://scripts/systems/notebook_host.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const VIEWS := preload("res://scripts/systems/notebook_view_store.gd")
const COMMANDS := preload("res://scripts/systems/notebook_commands.gd")
var errors := PackedStringArray()
var checks := 0

class ScopeGame extends Node:
	var load_epoch := 1
	var archive := ARCHIVE.create()
	var source := ""
	func get_value(path: String, fallback: Variant = null) -> Variant:
		match path:
			"meta_progress.dialogue_history": return archive
			"meta_progress.dialogue_history.source_origin_id": return archive.source_origin_id
			"meta_progress.dialogue_history.branch_id": return archive.branch_id
			"meta_progress.knowledge_entries.reselect_source_slot_id": return source
		return fallback

class ScopeSaves extends Node:
	var flavor := "full"
	func get_build_flavor() -> String: return flavor
	func inspect_slot(_slot: String) -> Dictionary: return {"run_id": "scope-run"}

class ScopeOwner extends Control:
	var _slot_id := "reselect_scope_fixture"

func run(tree: SceneTree) -> Dictionary:
	var game := ScopeGame.new()
	var saves := ScopeSaves.new()
	var owner := ScopeOwner.new()
	tree.current_scene.add_child(owner)
	var host := HOST.new()
	host.game = game
	host.saves = saves
	host._controller = weakref(owner)
	var archive_before := game.archive.duplicate(true)
	for flavor in ["demo", "full"]:
		saves.flavor = flavor
		for slot in ["__dev_checkpoint", "reselect_scope_fixture"]:
			owner._slot_id = slot
			host._slot = slot
			for source in ["", "slot_01", "__dev_checkpoint", "__dev_checkpoint_old"]:
				game.source = source
				var expected: String = "development" if slot.begins_with("__dev_") or source.begins_with("__dev_checkpoint") else flavor
				host._scope = host._current_scope()
				_expect(host._scope.namespace == expected, "namespace " + flavor + "/" + slot + "/" + source)
				_expect(COMMANDS.scope(game, saves, slot).begins_with(expected + ":"), "command namespace agrees with view namespace")
				_expect(host._same_live_scope(), "scope recognizes its initial namespace")
				_expect(host._scope.slot == slot and host._scope.source_origin_id == game.archive.source_origin_id and host._scope.branch_id == game.archive.branch_id, "provenance does not replace slot or observation identity")
	owner._slot_id = "reselect_scope_fixture"
	host._slot = owner._slot_id
	game.source = "__dev_checkpoint"
	host._scope = host._current_scope()
	var development := VIEWS.persistent_scope(host._scope)
	game.source = "slot_01"
	_expect(not host._same_live_scope(), "changed developer provenance invalidates cached host")
	var product := VIEWS.persistent_scope(host._current_scope())
	var store := VIEWS.new("user://__test_scope_paths")
	_expect(store.paths(development).main != store.paths(product).main, "same slot and observation identities remain namespace-isolated")
	host._scope = host._current_scope()
	game.source = "__dev_checkpoint"
	_expect(not host._same_live_scope(), "changed product provenance invalidates cached host")
	_expect(game.archive == archive_before, "classification never appends or forks observations")
	host.free()
	owner.free()
	game.free()
	saves.free()
	print("NOTEBOOK_SCOPE_CHECKS: %d" % checks)
	return {"ok": errors.is_empty(), "errors": errors}

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors.append(message)
		print("NB_SCOPE_FAIL: " + message)
