extends SceneTree

const Bindings := preload("res://scripts/systems/key_bindings.gd")
const Store := preload("res://scripts/systems/accessibility_profile_store.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var store := Store.new("user://__test_key_restart")
	if "--write-key-profile" in OS.get_cmdline_user_args():
		store.delete_test_profile()
		var profile := store.default_profile()
		profile.key_bindings.cancel = [KEY_F8]
		profile.key_bindings.next = [KEY_F9]
		profile.key_bindings.previous = [KEY_F10]
		if not store.save_profile(profile).get("ok", false):
			_fail("write profile")
			return
		print("KEY_BINDING_WRITE_SMOKE: PASS")
		quit(0)
		return
	var loaded := store.load_profile()
	if loaded.get("source") != "primary":
		_fail("read prior process profile")
		return
	if not Bindings.apply_bindings(loaded.profile.key_bindings):
		_fail("apply restarted profile")
		return
	for pair in [["ui_cancel", KEY_F8], ["ui_focus_next", KEY_F9], ["focus_previous", KEY_F10]]:
		if not InputMap.action_has_event(pair[0], Bindings.key_event(pair[1])):
			_fail("missing restored action: " + pair[0])
			return
	if InputMap.action_has_event("ui_cancel", Bindings.key_event(KEY_ESCAPE)):
		_fail("old cancel binding survived")
		return
	store.delete_test_profile()
	print("KEY_BINDING_RESTART_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("KEY_BINDING_RESTART_SMOKE: " + message)
	quit(1)
