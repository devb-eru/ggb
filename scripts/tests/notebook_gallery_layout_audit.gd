extends Node

const HOST := preload("res://scripts/systems/notebook_gallery_host.gd")
const PANEL := preload("res://scripts/ui/notebook_panel.gd")
const ARCHIVE := preload("res://scripts/systems/notebook_archive.gd")
const KNOWLEDGE := preload("res://scripts/systems/notebook_knowledge.gd")
const VIEWS := preload("res://scripts/systems/notebook_view_store.gd")
const FIXTURE := preload("res://scripts/tests/notebook_gallery_smoke.gd")
var errors: Array = []
var cases: Array = []
var checks := 0
var root_path := "user://__test_gallery_layout"

class CountedQuery extends "res://scripts/systems/notebook_query.gd":
    var page_calls := 0
    var preview_calls := 0
    var comparison_calls := 0
    func page(filters: Dictionary, page_index: int, expected_key: String) -> Dictionary:
        page_calls += 1
        return super.page(filters, page_index, expected_key)
    func preview(key: String, expected_key: String) -> Dictionary:
        preview_calls += 1
        return super.preview(key, expected_key)
    func comparison(expected_key: String) -> Dictionary:
        comparison_calls += 1
        return super.comparison(expected_key)
    func reset_calls() -> void:
        page_calls = 0; preview_calls = 0; comparison_calls = 0

func _ready() -> void:
    await _run()
    var result := {"schema_version":1,"suite_id":"gallery-layout","ok":errors.is_empty(),"errors":errors,"checks":checks,"required_cases":48,"cases":cases}
    print("NOTEBOOK_GALLERY_LAYOUT_AUDIT: ", JSON.stringify(result))
    print("NOTEBOOK_GALLERY_LAYOUT_SMOKE:", "PASS" if errors.is_empty() else "FAIL")
    get_tree().quit(0 if errors.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition: errors.append(message)

func _settle() -> void:
    for _frame in range(4): await get_tree().process_frame

func _run() -> void:
    var before := GameState.get_snapshot()
    var revision: int = GameState.revision
    var epoch: int = GameState.load_epoch
    var old_locale := TranslationServer.get_locale()
    var flavor: Variant = ProjectSettings.get_setting("ggb/build_flavor")
    ProjectSettings.set_setting("ggb/build_flavor", "full")
    var fixture := FIXTURE.new()
    var store := EndingGalleryStore.new(root_path.path_join("gallery"))
    for branch in ["REALITY", "STAY"]:
        var state: Dictionary = fixture._fixture("CREDITS_" + branch, "NB_CH1_NOTE_B4")
        var archive: Dictionary = state.meta_progress.dialogue_history
        var second := ARCHIVE.set_reference(archive, "comparison", ARCHIVE.make_reference(archive.entries[1], "body"), true, int(archive.revision))
        _expect(second.ok, "fixture second comparison")
        state.meta_progress.dialogue_history = second.archive
        var captured: Dictionary = store.capture(state)
        _expect(captured.ok, "fixture captured: " + branch)
        if not captured.ok: continue
        for locale in ["ko-KR", "en-US"]:
            TranslationServer.set_locale(locale)
            for scale in [1.0, 2.0]:
                for mode in ["list", "detail", "comparison"]:
                    await _case(store, captured.id, branch, locale, scale, mode)
    for error in fixture.errors: _expect(false, "fixture: " + error)
    _expect(cases.size() == 48, "independent case denominator")
    _expect(GameState.get_snapshot() == before and GameState.revision == revision and GameState.load_epoch == epoch, "all gallery callbacks preserve live gameplay and load identity")
    ProjectSettings.set_setting("ggb/build_flavor", flavor)
    TranslationServer.set_locale(old_locale)

func _case(store: EndingGalleryStore, id: String, branch: String, locale: String, scale: float, mode: String) -> void:
    var source: Dictionary = store.read_entry(id)
    _expect(source.ok, "verified source")
    if not source.ok: return
    var query := CountedQuery.new()
    var meta: Dictionary = source.state.meta_progress
    var scope := {"namespace":"gallery","slot":id,"run_id":"gallery-adapter-1:"+id,"source_origin_id":meta.dialogue_history.source_origin_id,"branch_id":meta.dialogue_history.branch_id,"load_epoch":0}
    _expect(query.open(meta.dialogue_history, meta.knowledge_entries[KNOWLEDGE.KEY], scope, locale, meta.knowledge_entries).ok, "seed model opens")
    _expect(query.enable_gallery_comparison(), "seed temporary comparison")
    var rows: Dictionary = query.page({"tab":"dialogue"},0,query.cache_key())
    var selected: String = rows.items[1].key
    var seed := PANEL.new()
    seed.size = Vector2(1280,720)
    add_child(seed)
    _expect(seed.present(query,locale,"dialogue",scale), "seed view presents")
    seed.set_reference_editable(false,true)
    if mode != "list": _expect(seed.show_detail(selected), "seed detail")
    if mode == "comparison": seed.find_child("NotebookCompare",true,false).pressed.emit()
    await _settle()
    var view: Dictionary = seed.capture_view()
    var preferences := VIEWS.empty_state()
    preferences.general = view
    preferences.seen = [selected]
    preferences.groups = [query.review_group(selected)]
    var views := VIEWS.new(root_path.path_join("views_"+branch+locale+str(scale)+mode))
    _expect(views.save_view(VIEWS.persistent_scope(scope),query.view_frontier(),preferences).ok,"seed persisted view")
    seed.dismiss(); seed.queue_free()
    await _settle()
    var owner := Control.new()
    var focus := Button.new()
    focus.text = "Return target"
    owner.add_child(focus)
    add_child(owner)
    focus.grab_focus()
    var gameplay := GameState.get_snapshot()
    var path := store.root_path.path_join(id+".json")
    var original := FileAccess.get_file_as_bytes(path)
    var host := HOST.new()
    host.model = query
    host.view_store = views
    add_child(host)
    query.reset_calls()
    var opened: bool = host.begin(owner,store,id,locale,scale)
    _expect(opened,"actual host begins")
    if not opened:
        host.queue_free(); owner.queue_free()
        await _settle()
        return
    await _settle()
    _assert_presentation(host,query,branch,locale,scale,mode,"open",view,rows.items.size())
    var basket: Array = query.comparison(query.cache_key()).items
    var archive_before := JSON.stringify(host._source,"",true)
    var stale: String = query.cache_key()
    query.reset_calls()
    host.refresh()
    await _settle()
    _assert_presentation(host,query,branch,locale,scale,mode,"refresh",view,rows.items.size())
    _expect(query.comparison(query.cache_key()).items == basket,"refresh keeps temporary basket")
    _expect(not query.edit_gallery_comparison(rows.items[0].reference,true,stale).ok,"stale generation cannot edit comparison")
    host.panel.reference_requested.emit("bookmarks",rows.items[0].reference,false)
    _expect(JSON.stringify(host._source,"",true) == archive_before,"injected bookmark cannot mutate source")
    _expect(GameState.get_snapshot() == gameplay and FileAccess.get_file_as_bytes(path) == original,"open/refresh preserves live state and capture bytes")
    host.request_close()
    await _settle()
    _expect(not is_instance_valid(host) and owner.visible and owner.process_mode == Node.PROCESS_MODE_INHERIT and focus.has_focus(),"close restores owner and focus")
    owner.queue_free()
    await _settle()

func _assert_presentation(host, query, branch: String, locale: String, scale: float, mode: String, action: String, view: Dictionary, rows: int) -> void:
    var start := errors.size()
    var key := branch+"/"+locale+"/"+str(int(scale))+"/"+mode+"/"+action
    var counts := {"page":query.page_calls,"preview":query.preview_calls,"comparison":query.comparison_calls}
    _expect(counts.page == 2, key+" constructs only restored list")
    _expect(counts.preview == rows, key+" renders each row once")
    _expect(counts.comparison == (4 if action == "open" else 6),key+" constructs basket once")
    _expect(host.panel._filters == view.filters and host.panel._page == view.page, key+" filters and page restored")
    _expect(host.panel._selected == view.selected and host.panel._detail_visible == view.detail,key+" detail selection restored")
    _expect(host.panel.visible_pair() == view.pair and host.panel._comparison_mode == view.comparing,key+" pair and comparison mode restored")
    _expect(not host.panel._reference_editable and host.panel._temporary_comparison,key+" readonly before restoration")
    _expect(host.panel._seen.has(view.selected if not view.selected.is_empty() else host._view_state.seen[0]),key+" acquired review state remains visible")
    cases.append({"key":key,"passed":errors.size()==start,"calls":counts,"rows":rows,"expected_page":2,"expected_preview":rows,"expected_comparison":4 if action=="open" else 6})
