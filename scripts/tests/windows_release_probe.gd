extends Node

const MAIN := preload("res://scenes/main/main.tscn")
const ROLLOUT := preload("res://scripts/systems/notebook_rollout.gd")
const MIGRATION := preload("res://scripts/systems/notebook_migration.gd")
const SLOT := "slot_01"
var errors: Array[String] = []
var checks := 0
var stages: Array[String] = []
var locale := "ko-KR"

func _ready() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--release-probe-locale="): locale = argument.trim_prefix("--release-probe-locale=")
    TranslationServer.set_locale(locale)
    await _run()
    print("WINDOWS_RELEASE_PROBE: ", JSON.stringify({"schema_version":1,"ok":errors.is_empty(),"debug_build":OS.is_debug_build(),"locale":locale,"checks":checks,"stages":stages,"errors":errors}))
    get_tree().quit(0 if errors.is_empty() else 1)

func _expect(value: bool, message: String) -> void:
    checks += 1
    if not value: errors.append(message)

func _frames() -> void:
    for _frame in range(4): await get_tree().process_frame

func _run() -> void:
    _expect(not OS.is_debug_build(), "Actual release executable is required")
    _expect(not ROLLOUT.enabled(), "Developer notebook CLI cannot enable release rollout")
    if not errors.is_empty(): return
    var app = MAIN.instantiate()
    add_child(app)
    await _frames()
    _expect(app._start_screen.visible and not is_instance_valid(app._developer_panel), "Release title cannot honor developer jump")
    stages.append("title_and_developer_gate")
    app._start_screen.new_game_requested.emit(SLOT)
    await _frames()
    var controller = app._prologue
    _expect(is_instance_valid(controller), "Actual new-game signal launches prologue")
    if not is_instance_valid(controller): return
    var locale_key := "en" if locale.begins_with("en") else "ko"
    _expect(TranslationServer.get_locale().begins_with(locale_key), "Requested locale remains active")
    for _line in range(40):
        if not controller._dialogue_active: break
        controller._advance_dialogue()
    _expect(not controller._dialogue_active, "Initial real dialogue completes")
    var loaded: Dictionary = SaveManager.load_slot(SLOT)
    _expect(loaded.ok, "Release new game and dialogue saved")
    if not loaded.ok: return
    var original: Dictionary = loaded.snapshot.meta_progress.dialogue_history
    _expect(not original.has("schema_version") and not original.entries.is_empty(), "Rollout-OFF release writes ordinary observed history")
    var rendered: Dictionary = DialogueRepository.new().render_history(original, locale)
    _expect(rendered.ok and rendered.entries.size() == original.entries.size(), "Ordinary saved history displays")
    stages.append("ordinary_new_game_and_history")
    await _read_modal(controller)
    var adapted: Dictionary = MIGRATION.adapt_verified(loaded.snapshot, loaded.header.checksum)
    _expect(adapted.ok and adapted.migrated, "Verified legacy source can supply a v2 compatibility fixture")
    if not adapted.ok: return
    var state: Dictionary = adapted.snapshot
    var v2: Dictionary = state.meta_progress.dialogue_history
    _expect(v2.schema_version == 2 and v2.entries.size() == original.entries.size(), "V2 conversion preserves every observed row")
    var promoted: Dictionary = DialogueRepository.new().render_history(v2, locale)
    _expect(promoted.ok and promoted.entries == rendered.entries, "V2 display equals retained original")
    var point := String(loaded.header.save_point_id)
    var saved: Dictionary = SaveManager.save_snapshot(SLOT, point, state, GameState.revision, "RELEASE_V2_COMPATIBILITY")
    _expect(saved.ok, "Release can persist an already-v2 source without rollout")
    if not saved.ok: return
    var v2loaded: Dictionary = SaveManager.load_slot(SLOT)
    _expect(v2loaded.ok and v2loaded.snapshot.meta_progress.dialogue_history == v2, "V2 disk reload never downgrades observations")
    _expect(LoadCoordinator.new(GameState, SaveManager).load_and_install(SLOT).ok, "Release load installs validated v2")
    controller.queue_free()
    await _frames()
    app._prologue = null
    app._start_screen.load_game_requested.emit(SLOT)
    await _frames()
    controller = app._prologue
    _expect(is_instance_valid(controller) and not controller._unified_notebook_enabled(), "Actual continue preserves release UI gate")
    if not is_instance_valid(controller): return
    if controller._dialogue_active:
        for _line in range(40):
            if not controller._dialogue_active: break
            controller._advance_dialogue()
    _expect(not controller._dialogue_active, "V2 resumed intro is not blocked")
    var retained: Dictionary = GameState.get_value("meta_progress.dialogue_history")
    for entry in v2.entries:
        _expect(retained.entries.any(func(candidate: Dictionary): return candidate == entry), "Original UID and payload survive actual continue")
    stages.append("v2_continue_and_original_retention")
    await _read_modal(controller)
    app.queue_free()
    await _frames()

func _read_modal(controller) -> void:
    var state := GameState.get_snapshot()
    var revision: int = GameState.revision
    var epoch: int = GameState.load_epoch
    var path: String = SaveManager._slot_paths(SLOT).main
    var bytes := FileAccess.get_file_as_bytes(path)
    controller._open_dialogue_history()
    await _frames()
    _expect(controller._modal_active and not is_instance_valid(controller._notebook_host), "Release history opens its ordinary read-only modal")
    controller._close_modal()
    await _frames()
    _expect(GameState.get_snapshot() == state and GameState.revision == revision and GameState.load_epoch == epoch, "History review does not observe or mutate gameplay")
    _expect(FileAccess.get_file_as_bytes(path) == bytes, "History review never rewrites durable source")
    stages.append("ordinary_history_read_only")
