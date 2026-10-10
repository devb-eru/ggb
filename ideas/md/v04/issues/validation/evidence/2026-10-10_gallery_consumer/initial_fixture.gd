extends Node

const VIEW := preload("res://scripts/chapters/basement_controller.gd")
const CHECKPOINTS := preload("res://scripts/systems/developer_checkpoints.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const CONTENT := preload("res://scripts/systems/notebook_content.gd")
const FACTS := preload("res://scripts/systems/dialogue_observed_facts.gd")
const PAGES := preload("res://scripts/systems/ending_gallery_pages.gd")
const TEXTS := preload("res://scripts/ui/ending_gallery_texts.gd")
const WAKE_TEXTS := preload("res://scripts/ui/reality_wake_texts.gd")
const MIGRATION := preload("res://scripts/systems/notebook_migration.gd")
const HOST := preload("res://scripts/systems/notebook_gallery_host.gd")
const VIEWS := preload("res://scripts/systems/notebook_view_store.gd")
const SLOT := "__test_gallery_consumer"
var errors: Array = []
var checks := 0
var cases: Array = []
var writes: Array = []
var view
var serial := 0
var root_path := "user://__test_gallery_consumer"

class ControlledSave extends Node:
    var reject := false
    var lose_ack := false
    func get_build_flavor() -> String: return SaveManager.get_build_flavor()
    func inspect_slot(slot: String) -> Dictionary: return SaveManager.inspect_slot(slot)
    func save_snapshot(slot: String, point: String, state: Dictionary, revision: int, transaction: String) -> Dictionary:
        if reject and transaction.begins_with("HISTORY_"): return {"ok":false,"error_ids":["TEST_BODY_SAVE"]}
        var saved := SaveManager.save_snapshot(slot,point,state,revision,transaction)
        if saved.ok and lose_ack and transaction.begins_with("HISTORY_"): return {"ok":false,"error_ids":["TEST_BODY_ACK"]}
        return saved
    func confirm_snapshot_commit(slot: String, transaction: String) -> Dictionary:
        return SaveManager.confirm_snapshot_commit(slot,transaction)
    func capture_f3_reselect(slot: String) -> Dictionary: return SaveManager.capture_f3_reselect(slot)

func _ready() -> void:
    await _run()
    var result := {"schema_version":1,"suite_id":"gallery-consumer","ok":errors.is_empty(),"checks":checks,"errors":errors,"required_cases":128,"cases":cases,"required_writes":18,"writes":writes}
    print("NOTEBOOK_GALLERY_CONSUMER_AUDIT: ",JSON.stringify(result))
    print("NOTEBOOK_GALLERY_CONSUMER_SMOKE:","PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
    checks += 1
    if not ok: errors.append(message)

func _run() -> void:
    var caller := GameState.get_snapshot()
    var old_locale := TranslationServer.get_locale()
    var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
    ProjectSettings.set_setting("ggb/build_flavor","full")
    var store := EndingGalleryStore.new(root_path.path_join("captures"))
    for locale in ["ko-KR","en-US"]:
        TranslationServer.set_locale(locale)
        for object in FACTS.BODY_IDS:
            for policy in ["normal","reject_retry","lost_ack"]: await _write_case(object,locale,policy)
        for format in ["legacy","authored"]:
            for mask in range(8):
                await _install_body(format)
                for object in FACTS.BODY_IDS: _read(object)
                var first := GameState.get_snapshot()
                for object in FACTS.BODY_IDS: _expect(not FACTS.has_body_repeat(first,object),"first reads do not grant repeat: "+object)
                for index in range(3):
                    if mask & (1 << index): _read(FACTS.BODY_IDS[index])
                var observed := GameState.get_snapshot()
                for index in range(3): _expect(FACTS.has_body_repeat(observed,FACTS.BODY_IDS[index]) == bool(mask & (1 << index)),"actual repeat subset")
                var complete := _completed_fixture(observed)
                var source_copy := JSON.stringify(complete,"",true)
                var captured := store.capture(complete)
                _expect(captured.ok,"consumer capture succeeds")
                _expect(JSON.stringify(complete,"",true) == source_copy,"capture leaves caller candidate unchanged")
                if not captured.ok: continue
                var path := store.root_path.path_join(captured.id+".json")
                var bytes := FileAccess.get_file_as_bytes(path)
                var loaded := store.read_entry(captured.id)
                _expect(loaded.ok and loaded.id == captured.id,"same immutable capture identity")
                if not loaded.ok: continue
                var pruned := _maintained(loaded.state)
                if pruned.is_empty(): continue
                for representation in ["captured","maintained"]:
                    var candidate: Dictionary = loaded.state if representation == "captured" else pruned
                    for display in ["ko-KR","en-US"]:
                        _page_case(candidate,format,locale,mask,representation,display)
                _expect(FileAccess.get_file_as_bytes(path) == bytes,"read/prune projections never rewrite capture")
                var live := GameState.get_snapshot()
                var revision: int = GameState.revision
                var epoch: int = GameState.load_epoch
                var owner := Control.new()
                add_child(owner)
                var host := HOST.new()
                host.view_store = VIEWS.new(root_path.path_join("views"))
                add_child(host)
                _expect(host.begin(owner,store,captured.id,locale,1.0),"actual gallery host opens consumer source")
                if host._active():
                    for key in host.model._order:
                        _expect(host.model.detail(key,host.model.cache_key()).ok,"captured row resolves without observing gameplay")
                    host.refresh()
                    host.request_close()
                else: host.queue_free()
                await _settle()
                _expect(GameState.get_snapshot() == live and GameState.revision == revision and GameState.load_epoch == epoch and FileAccess.get_file_as_bytes(path) == bytes,"host remains consumer only")
                owner.queue_free()
                await _settle()
    if is_instance_valid(view): view.queue_free()
    await _settle()
    SaveManager.delete_test_slot(SLOT)
    GameState.reset_for_test()
    _expect(StateWriter.new(GameState).install_snapshot(caller,GameState.revision,&"BODY_CONSUMER_RESTORE").ok,"caller snapshot restored")
    TranslationServer.set_locale(old_locale)
    ProjectSettings.set_setting("ggb/build_flavor",flavor)
    _expect(cases.size() == 128 and writes.size() == 18,"independent matrix denominators")

func _install_body(format: String) -> void:
    if is_instance_valid(view):
        view.queue_free()
        await _settle()
    var loaded := CHECKPOINTS.new().snapshot_for("EDR_BODY_CHECK")
    _expect(loaded.ok,"body checkpoint")
    if not loaded.ok: return
    var state: Dictionary = loaded.snapshot
    state.meta_progress.dialogue_history = ARCHIVE.create() if format == "authored" else {"next_sequence":0,"entries":[]}
    state.meta_progress.knowledge_entries.erase(FACTS.KNOWLEDGE_KEY)
    state.meta_progress.knowledge_entries.erase(KNOWLEDGE.KEY)
    state.meta_progress.knowledge_entries.erase("chapter_notebook")
    state.meta_progress.knowledge_entries.erase("prologue_notebook")
    state.ending_run.required_interactions_seen = []
    GameState.reset_for_test()
    serial += 1
    var transaction := "BODY_CONSUMER_SEED_%d" % serial
    _expect(StateWriter.new(GameState).install_snapshot(state,GameState.revision,StringName(transaction)).ok,"body install")
    _expect(SaveManager.save_snapshot(SLOT,"SAVE_BROKEN_RESET_COMPLETE",GameState.get_snapshot(),GameState.revision,transaction).ok,"body seed persists")
    view = VIEW.new()
    view.configure_session(SLOT,"EDR_BODY_CHECK")
    add_child(view)
    await _settle()
    view._dismiss_dialogue_for_test()
    _present()

func _present() -> void:
    view._render_room()
    _expect(view._notebook_surface_allowed(),"actual body surface captures")
    view.set_process(false)

func _press(object: String) -> void:
    var button := view._hotspot_layer.get_node_or_null(NodePath(object)) as Button
    _expect(button != null,"actual body button "+object)
    if button != null: button.pressed.emit()

func _read(object: String) -> void:
    var repeated: bool = object in GameState.get_snapshot().ending_run.required_interactions_seen
    var data: Array = WAKE_TEXTS.body(object,TranslationServer.get_locale())
    _press(object)
    _expect(view._dialogue_label.text == data[2 if repeated else 1],"shown first/repeat body text")
    _drain()
    _present()

func _drain() -> void:
    for _step in range(40):
        if not view._dialogue_active: return
        view._advance_dialogue()
    _expect(false,"body dialogue remains blocked")

func _write_case(object: String, locale: String, policy: String) -> void:
    var start := errors.size()
    await _install_body("authored")
    _read(object)
    var first := GameState.get_snapshot()
    _expect(not FACTS.has_body_repeat(first,object),"first reading is not repeated reading")
    var save := ControlledSave.new()
    view.session._save = save
    save.reject = policy == "reject_retry"
    save.lose_ack = policy == "lost_ack"
    var disk: Dictionary = SaveManager.load_slot(SLOT)
    var before := GameState.get_snapshot()
    _press(object)
    if save.reject:
        _expect(GameState.get_snapshot() == before and SaveManager.load_slot(SLOT).snapshot == disk.snapshot,"failed repeat preserves both live and durable facts/history")
        _expect(not FACTS.has_body_repeat(GameState.get_snapshot(),object),"failed repeat cannot disclose gallery rereading")
        save.reject = false
        view._advance_dialogue()
    _drain()
    view.session._save = SaveManager
    var after := GameState.get_snapshot()
    _expect(FACTS.has_body_repeat(after,object),"successful retry/ack records independent repeat evidence")
    _expect(LoadCoordinator.new(GameState,SaveManager).load_and_install(SLOT).ok,"repeat evidence reloads")
    _expect(FACTS.has_body_repeat(GameState.get_snapshot(),object),"disk has same repeat evidence")
    var content_id := "NB_REALITY_BODY_%s_REPEAT" % object
    var repeats := 0
    for entry in after.meta_progress.dialogue_history.entries:
        if entry.record_class == "authored" and entry.observation.content_id == content_id: repeats += 1
    _expect(repeats == 1,"failed retry/lost ack never duplicates repeat record")
    for other in FACTS.BODY_IDS:
        _expect(FACTS.has_body_repeat(after,other) == (other == object),"repeat evidence is object-specific")
    writes.append({"key":object+"/"+locale+"/"+policy,"passed":errors.size()==start,"repeat_records":repeats})
    save.free()

func _completed_fixture(observed: Dictionary) -> Dictionary:
    var loaded := CHECKPOINTS.new().snapshot_for("EDR_FINAL_FRAME")
    _expect(loaded.ok,"completed frame checkpoint")
    var state: Dictionary = loaded.snapshot
    state.meta_progress = observed.meta_progress.duplicate(true)
    state.ending_run.required_interactions_seen = observed.ending_run.required_interactions_seen.duplicate()
    _expect(StateSnapshotValidator.new().validate(state).ok,"completed fixture carries actual observations")
    return state

func _maintained(source: Dictionary) -> Dictionary:
    var state := source.duplicate(true)
    var archive: Dictionary = state.meta_progress.dialogue_history
    _expect(archive.get("schema_version") == 2,"verified read adapter gives current archive")
    var template := _filler()
    var originals: Array = archive.entries.map(func(entry: Dictionary): return entry.entry_uid)
    for _index in range(2001):
        var observation := template.duplicate(true)
        observation.presentation_token = ARCHIVE.new_uid()
        archive.entries.append({"entry_uid":ARCHIVE.new_uid(),"source_origin_id":archive.source_origin_id,"sequence":int(archive.next_sequence),"record_class":"authored","observation":observation,"protection_reasons":[]})
        archive.next_sequence += 1
    var maintained := ARCHIVE.maintain(archive,int(archive.revision))
    _expect(maintained.ok,"normal quota maintenance")
    if not maintained.ok: return {}
    state.meta_progress.dialogue_history = maintained.archive
    for entry in source.meta_progress.dialogue_history.entries:
        if entry.record_class == "legacy": _expect(maintained.archive.entries.any(func(current: Dictionary): return current.entry_uid == entry.entry_uid),"legacy original not discarded")
        elif entry.protection_reasons.is_empty(): _expect(not maintained.archive.entries.any(func(current: Dictionary): return current.entry_uid == entry.entry_uid),"old unprotected observed line really pruned")
    _expect(not originals.is_empty() and StateSnapshotValidator.new().validate(state).ok,"maintained state is valid")
    return state

func _filler() -> Dictionary:
    var descriptor := CONTENT.descriptor("NB_PR_DUTY_1",1,{"body":{}})
    var shown := CONTENT.presentation(descriptor,"ko-KR")
    var context := {"node_id":"P1","location_id":"M2_BEDROOM","chapter_id":"PROLOGUE","event_occurrence_id":ARCHIVE.new_uid(),"conversation_session_id":ARCHIVE.new_uid(),"presentation_token":ARCHIVE.new_uid()}
    var observed := CONTENT.observe(descriptor,context,shown.speaker,shown.text,"ko-KR","displayed")
    _expect(observed.ok,"valid normal filler")
    return observed.observation if observed.ok else {}

func _page_case(state: Dictionary, format: String, read_locale: String, mask: int, representation: String, display: String) -> void:
    var start := errors.size()
    var before := JSON.stringify(state,"",true)
    var live := GameState.get_snapshot()
    var pages := PAGES.build(state,display)
    var bodies := []
    for index in range(3):
        var object: String = FACTS.BODY_IDS[index]
        var data := WAKE_TEXTS.body(object,display)
        var title: String = TEXTS.text("body",display) % data[0]
        var selected: Array = pages.filter(func(page: Dictionary): return page.title == title)
        var repeated := bool(mask & (1 << index))
        var expected: String = data[1]+("\n"+data[2] if repeated else "")
        _expect(selected.size() == 1 and selected[0].text == expected,"exact first/repeat public body page")
        bodies.append({"object_id":object,"repeated":repeated,"title":title,"text_sha256":expected.sha256_text()})
    var no_ack := state.duplicate(true)
    no_ack.ending_run.required_interactions_seen = []
    var hidden := PAGES.build(no_ack,display)
    _expect(not hidden.any(func(page: Dictionary): return page.title in bodies.map(func(body: Dictionary): return body.title)),"facts alone never acknowledge gameplay")
    var incomplete := state.duplicate(true)
    incomplete.ending_run.completed_nodes.erase("EDR_FINAL_FRAME")
    _expect(PAGES.build(incomplete,display).is_empty(),"uncompleted ending has no gallery pages")
    var stay: Dictionary = CHECKPOINTS.new().snapshot_for("EDS_FINAL_FRAME").snapshot
    stay.meta_progress.dialogue_history = state.meta_progress.dialogue_history.duplicate(true)
    if state.meta_progress.knowledge_entries.has(FACTS.KNOWLEDGE_KEY): stay.meta_progress.knowledge_entries[FACTS.KNOWLEDGE_KEY] = state.meta_progress.knowledge_entries[FACTS.KNOWLEDGE_KEY].duplicate(true)
    _expect(not PAGES.build(stay,display).any(func(page: Dictionary): return page.title in bodies.map(func(body: Dictionary): return body.title)),"other ending cannot import body pages")
    _expect(JSON.stringify(state,"",true) == before and GameState.get_snapshot() == live,"page consumer is immutable and cannot observe gameplay")
    cases.append({"key":format+"/"+read_locale+"/"+str(mask)+"/"+representation+"/"+display,"passed":errors.size()==start,"bodies":bodies})

func _settle() -> void:
    for _frame in range(3): await get_tree().process_frame
