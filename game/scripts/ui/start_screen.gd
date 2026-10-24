class_name StartScreen
extends Control

const GALLERY_TEXTS := preload("res://scripts/ui/ending_gallery_texts.gd")

signal new_game_requested(slot_id: String)
signal load_game_requested(slot_id: String)
signal quit_requested
signal audio_settings_changed(settings: Dictionary)

const SLOT_IDS := ["slot_01", "slot_02", "slot_03"]
const TEXT_SCALE_VALUES := [1.0, 1.25, 1.5, 2.0]
const SIGNATURE_VALUES := ["color_pattern_label", "pattern_label", "label_only"]
const MOTION_VALUES := ["standard", "reduced", "static"]

@export var paper_modal_dimmer_color := Color(0.005, 0.008, 0.015, 0.22)

@onready var _title_background: TextureRect = %TitleBackground
@onready var _logo_stack: Control = %LogoStack
@onready var _logo: Label = %Logo
@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _load_button: Button = %LoadButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _content_button: Button = %ContentButton
@onready var _menu_container: VBoxContainer = %Menu
@onready var _title_buttons: Array[GothicTitleButton] = [
	%ContinueButton as GothicTitleButton,
	%NewGameButton as GothicTitleButton,
	%LoadButton as GothicTitleButton,
	%SettingsButton as GothicTitleButton,
	%QuitButton as GothicTitleButton,
	%ContentButton as GothicTitleButton,
]
@onready var _temporary_badge: Label = %TemporaryBadge
@onready var _version_label: Label = %VersionLabel
@onready var _status_label: Label = %TitleStatus
@onready var _dimmer: ColorRect = %ModalDimmer
@onready var _default_dimmer_color: Color = _dimmer.color
@onready var _slot_panel: Control = %SlotPanel
@onready var _new_slot_panel: Control = $ModalLayer/SlotPanel/NewGamePanel
@onready var _load_slot_panel: Control = $ModalLayer/SlotPanel/LoadGamePanel
var _slot_buttons: Array[Button] = []
var _slot_back_button: Button
var _active_slot_ui: Control
@onready var _first_run_panel: PanelContainer = %FirstRunPanel
@onready var _settings_panel: PanelContainer = %SettingsPanel
@onready var _first_text_option = _first_run_panel.text_size
@onready var _first_signature_option = _first_run_panel.signature
@onready var _first_motion_option = _first_run_panel.motion
@onready var _first_captions = _first_run_panel.captions
@onready var _first_preview: Label = _first_run_panel.get_node("Surface/ContentScroll/Pages/Accessibility/Preview/Margin/Body/Sample")
@onready var _first_default_button: Button = _first_run_panel.restore
@onready var _first_apply_button: Button = _first_run_panel.apply
@onready var _settings_text_option = _settings_panel.text_size
@onready var _settings_signature_option = _settings_panel.signature
@onready var _settings_motion_option = _settings_panel.motion
@onready var _settings_captions = _settings_panel.captions
@onready var _settings_back_button: Button = _settings_panel.back
@onready var _settings_apply_button: Button = _settings_panel.apply
@onready var _content_panel: PanelContainer = %ContentPanel
@onready var _content_title: Label = %ContentTitle
@onready var _content_body: Label = %ContentBody
@onready var _content_close_button: Button = %ContentCloseButton
@onready var _quit_panel: PanelContainer = %QuitPanel
@onready var _quit_title: Label = %QuitTitle
@onready var _quit_body: Label = %QuitBody
@onready var _quit_cancel_button: Button = %QuitCancelButton
@onready var _quit_confirm_button: Button = %QuitConfirmButton
@onready var _overwrite_panel: PanelContainer = %OverwritePanel
@onready var _overwrite_title: Label = %OverwriteTitle
@onready var _overwrite_body: Label = %OverwriteBody
@onready var _overwrite_cancel_button: Button = %OverwriteCancelButton
@onready var _overwrite_confirm_button: Button = %OverwriteConfirmButton
@onready var _launch_panel: PanelContainer = %LaunchPanel
@onready var _launch_title: Label = %LaunchTitle
@onready var _launch_body: Label = %LaunchBody
@onready var _launch_return_button: Button = %LaunchReturnButton

var _dialogue := DialogueRepository.new()
var _profile_store := AccessibilityProfileStore.new()
var _profile: Dictionary = {}
@onready var _audio_panel: PanelContainer = _settings_panel
@onready var _key_panel: PanelContainer = _settings_panel
@onready var _display_panel: PanelContainer = _settings_panel
@onready var _language_panel: PanelContainer = _settings_panel
@onready var _audio_button: Button = _settings_panel.get_node("Surface/Tabs/Audio")
@onready var _key_button: Button = _settings_panel.get_node("Surface/Tabs/Controls")
@onready var _display_button: Button = _settings_panel.get_node("Surface/Tabs/Display")
@onready var _language_button: Button = _settings_panel.get_node("Surface/Tabs/Language")
@onready var _first_language_button: Button = _first_run_panel.get_node("Surface/Tabs/Language")
var _locale := "ko-KR"
var _slot_summaries: Dictionary = {}
var _latest_slot_id := ""
var _slot_mode := "load"
var _pending_overwrite_slot := ""
var _focus_before_modal: Control
var _input_suspended := false
var _focus_before_suspend: Control
@onready var _gallery_button: Button = %GalleryButton
var _gallery_controls: HBoxContainer
var _gallery_choices: OptionButton
var _gallery_previous: Button
var _gallery_next: Button
var _gallery_entries: Array[Dictionary] = []
var _gallery_pages: Array[Dictionary] = []
var _gallery_page_index := 0
var _gallery_scroll: ScrollContainer
var _gallery_notebook_button: Button
var _gallery_notebook_host
var _gallery_entry_index := -1
var gallery_store := EndingGalleryStore.new()
@onready var _import_button: Button = %ImportButton
var _import_controls: HBoxContainer
var _import_choices: OptionButton
var _import_confirm: Button
var _import_sources: Array[String] = []
var _title_base_fonts: Dictionary = {}
var _title_base_heights: Dictionary = {}
var _logo_base_height := 180.0
var _logo_base_font := 64
var _menu_base_separation := 8


func configure_profile_store(profile_store: AccessibilityProfileStore) -> void:
	if is_node_ready():
		push_error("The accessibility profile store must be configured before StartScreen enters the tree.")
		return
	_profile_store = profile_store


func _ready() -> void:
	_locale = "en-US" if TranslationServer.get_locale().begins_with("en") else "ko-KR"
	_logo_base_height = _logo_stack.custom_minimum_size.y
	_logo_base_font = _logo.get_theme_font_size("font_size")
	_menu_base_separation = _menu_container.get_theme_constant("separation")
	for button in [_continue_button, _new_game_button, _load_button, _settings_button, _quit_button, _content_button, _gallery_button, _import_button]:
		_title_base_fonts[button] = button.get_theme_font_size("font_size")
		_title_base_heights[button] = button.custom_minimum_size.y
	_bind_asset_ids()
	_active_slot_ui = _new_slot_panel
	_slot_buttons.assign(_new_slot_panel.rows)
	_slot_back_button = _new_slot_panel.back_button
	for panel in [_new_slot_panel, _load_slot_panel]:
		panel.confirm_requested.connect(_confirm_slot)
		panel.back_requested.connect(_close_modal)
	_connect_controls()
	_setup_gallery()
	_setup_import()
	_setup_settings()
	var profile_result := _profile_store.load_profile()
	_profile = profile_result.get("profile", _profile_store.default_profile()).duplicate(true)
	if _profile.has("locale"):
		_locale = _profile.locale
		TranslationServer.set_locale(_locale)
	_apply_initial_display()
	_apply_localized_text()
	_apply_profile()
	refresh_slots()
	get_node("HtmlTitleComposition").bind_screen(self)
	for child in get_node("ModalLayer").get_children():
		if child not in [_slot_panel, _settings_panel, _first_run_panel]: preload("res://scripts/ui/design_theme.gd").skin_tree(child)
	(_continue_button if not _continue_button.disabled else _new_game_button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel", false, true) and _active_modal() != null:
		_close_modal()
		get_viewport().set_input_as_handled()


func refresh_slots() -> void:
	set_slot_summaries(SaveManager.list_slot_summaries())


func set_slot_summaries(summaries: Array[Dictionary]) -> void:
	_slot_summaries.clear()
	_latest_slot_id = ""
	var latest_timestamp := -1
	for summary in summaries:
		var slot_id := String(summary.get("slot_id", ""))
		if slot_id.is_empty():
			continue
		var display := summary.duplicate(true)
		if bool(summary.get("available", false)):
			display.merge(preload("res://scripts/systems/save_presentation.gd").read(SaveManager.get_save_root(), summary), true)
		_slot_summaries[slot_id] = display
		if bool(summary.get("available", false)):
			var timestamp := int(summary.get("updated_at_utc", 0))
			if timestamp > latest_timestamp:
				latest_timestamp = timestamp
				_latest_slot_id = slot_id
	_continue_button.disabled = _latest_slot_id.is_empty()
	_continue_button.tooltip_text = _text(&"UI_TITLE_NO_SAVE") if _latest_slot_id.is_empty() else ""
	_load_button.disabled = _latest_slot_id.is_empty()
	_update_slot_buttons()


func show_launch_handoff(resume_id: String) -> void:
	refresh_slots()
	_launch_body.text = _text(&"UI_LAUNCH_BODY", {"resume": resume_id})
	_open_modal(_launch_panel, _launch_return_button)


func show_save_error(error_ids: PackedStringArray) -> void:
	_status_label.text = _text(&"UI_STATUS_SAVE_FAILED", {"errors": ", ".join(error_ids)})
	_status_label.visible = true


func show_load_error(error_ids: PackedStringArray) -> void:
	_status_label.text = _text(&"UI_STATUS_LOAD_FAILED", {"errors": ", ".join(error_ids)})
	_status_label.visible = true


func set_input_suspended(suspended: bool) -> void:
	if suspended and not _input_suspended:
		_focus_before_suspend = get_viewport().gui_get_focus_owner()
	_input_suspended = suspended
	_apply_input_scope()
	if suspended:
		get_viewport().gui_release_focus()
	else:
		_restore_scoped_focus(_focus_before_suspend)


func _apply_input_scope() -> void:
	var modal := _active_modal()
	for control in _all_interactive_controls():
		var allowed := not _input_suspended and (modal == null or modal.is_ancestor_of(control))
		control.mouse_filter = Control.MOUSE_FILTER_STOP if allowed else Control.MOUSE_FILTER_IGNORE
		control.focus_mode = Control.FOCUS_ALL if allowed else Control.FOCUS_NONE
		if not _key_panel.is_ancestor_of(control) and not _display_panel.is_ancestor_of(control):
			control.focus_next = NodePath()
			control.focus_previous = NodePath()
	_rebuild_modal_focus_cycle()
	if modal in [_settings_panel, _first_run_panel] and not _input_suspended:
		modal._set_preview_scope(modal.preview.pending)
		modal._focus_cycle()


func _rebuild_modal_focus_cycle() -> void:
	var modal := _active_modal()
	# These panels maintain their own cycles as capture/preview controls change.
	if modal == null or modal in [_settings_panel, _first_run_panel] or _input_suspended: return
	var controls: Array[Control] = []
	for child in modal.find_children("*", "Control", true, false):
		var control := child as Control
		if not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE: continue
		if control is BaseButton and control.disabled: continue
		controls.append(control)
	for index in controls.size():
		controls[index].focus_next = controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[(index - 1 + controls.size()) % controls.size()])


func _restore_scoped_focus(preferred: Control) -> void:
	if _input_suspended or not is_visible_in_tree(): return
	var modal := _active_modal()
	var candidates: Array[Control] = []
	if is_instance_valid(preferred): candidates.append(preferred)
	candidates.append(_continue_button if not _continue_button.disabled else _new_game_button)
	candidates.append_array(_all_interactive_controls())
	for control in candidates:
		if not is_ancestor_of(control) or (modal != null and not modal.is_ancestor_of(control)): continue
		if not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE: continue
		if control is BaseButton and control.disabled: continue
		control.grab_focus()
		return


func _connect_controls() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_content_button.pressed.connect(_on_content_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_content_close_button.pressed.connect(_close_modal)
	_quit_cancel_button.pressed.connect(_close_modal)
	_quit_confirm_button.pressed.connect(func() -> void: quit_requested.emit())
	_overwrite_cancel_button.pressed.connect(_return_to_slot_panel)
	_overwrite_confirm_button.pressed.connect(_confirm_overwrite)
	_launch_return_button.pressed.connect(_close_modal)


func _apply_localized_text() -> void:
	_logo.text = "papa,\nwhere r u?" if _locale.begins_with("en") else "아빠,\n왜 안 와?"
	get_window().title = _logo.text.replace("\n", " ")
	_continue_button.text = _text(&"UI_TITLE_CONTINUE")
	_new_game_button.text = _text(&"UI_TITLE_NEW_GAME")
	_load_button.text = _text(&"UI_TITLE_LOAD")
	_settings_button.text = _text(&"UI_TITLE_SETTINGS")
	_quit_button.text = _text(&"UI_TITLE_QUIT")
	_content_button.text = _text(&"UI_TITLE_CONTENT_DETAILS")
	if is_instance_valid(_gallery_button): _gallery_button.text = _text(&"UI_TITLE_GALLERY")
	_import_button.text = _text(&"UI_TITLE_IMPORT_DEMO")
	_temporary_badge.text = _text(&"UI_TITLE_TEMP_ASSET")
	_version_label.text = _text(&"UI_TITLE_VERSION")
	_content_title.text = _text(&"UI_CONTENT_TITLE")
	_content_body.text = _text(&"UI_CONTENT_BODY")
	_content_close_button.text = _text(&"UI_COMMON_CLOSE")
	_quit_title.text = _text(&"UI_QUIT_TITLE")
	_quit_body.text = _text(&"UI_QUIT_BODY")
	_quit_cancel_button.text = _text(&"UI_QUIT_CANCEL")
	_quit_confirm_button.text = _text(&"UI_QUIT_CONFIRM")
	_overwrite_title.text = _text(&"UI_OVERWRITE_TITLE")
	_overwrite_cancel_button.text = _text(&"UI_QUIT_CANCEL")
	_overwrite_confirm_button.text = _text(&"UI_OVERWRITE_CONFIRM")
	_launch_title.text = _text(&"UI_LAUNCH_TITLE")
	_launch_return_button.text = _text(&"UI_LAUNCH_RETURN")


func _setup_import() -> void:
	_import_button.text = _text(&"UI_TITLE_IMPORT_DEMO")
	_import_button.visible = SaveManager.get_build_flavor() == "full"
	_import_button.pressed.connect(_open_demo_import)
	_import_controls = HBoxContainer.new()
	_launch_return_button.get_parent().add_child(_import_controls)
	_import_choices = OptionButton.new()
	_import_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_import_controls.add_child(_import_choices)
	_import_confirm = Button.new()
	_import_confirm.text = _text(&"UI_TITLE_IMPORT_CONFIRM")
	_import_controls.add_child(_import_confirm)
	_import_confirm.pressed.connect(_confirm_demo_import)
	_import_controls.hide()

func _open_demo_import() -> void:
	if SaveManager.get_build_flavor() != "full": return
	_import_sources.clear()
	_import_choices.clear()
	for id in SLOT_IDS:
		if SaveManager.inspect_demo_import(id).get("ok", false):
			_import_sources.append(id)
			_import_choices.add_item(_text(&"UI_IMPORT_SLOT", {"slot": id}))
	_open_modal(_launch_panel, _launch_return_button)
	_import_controls.show()
	_import_confirm.disabled = _import_sources.is_empty()
	_rebuild_modal_focus_cycle()
	_launch_title.text = _text(&"UI_IMPORT_TITLE")
	_launch_body.text = _text(&"UI_IMPORT_BODY" if not _import_sources.is_empty() else &"UI_IMPORT_EMPTY")
	_gallery_scroll.scroll_vertical = 0

func _confirm_demo_import() -> void:
	if SaveManager.get_build_flavor() != "full" or not _import_controls.visible: return
	var index := _import_choices.selected
	if index < 0 or index >= _import_sources.size(): return
	_import_confirm.disabled = true
	var result: Dictionary = SaveManager.import_demo_to_new_slot(_import_sources[index])
	if not result.get("ok", false):
		_launch_body.text = _text(&"UI_IMPORT_ERROR", {"error": str(result.get("error_id", "ERR_IMPORT"))})
		_import_confirm.disabled = false
		_rebuild_modal_focus_cycle()
		return
	_close_modal()
	refresh_slots()
	load_game_requested.emit(result["slot_id"])

func _setup_gallery() -> void:
	_gallery_button.text = _text(&"UI_TITLE_GALLERY")
	_gallery_button.pressed.connect(_open_gallery)
	var body_parent := _launch_body.get_parent()
	var body_index := _launch_body.get_index()
	var scroll := ScrollContainer.new()
	_gallery_scroll = scroll
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.gui_input.connect(_gallery_scroll_input)
	scroll.custom_minimum_size.y = 120
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_parent.remove_child(_launch_body)
	body_parent.add_child(scroll)
	body_parent.move_child(scroll, body_index)
	scroll.add_child(_launch_body)
	_launch_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_launch_body.size_flags_vertical = Control.SIZE_FILL
	_gallery_controls = HBoxContainer.new()
	_launch_return_button.get_parent().add_child(_gallery_controls)
	_gallery_choices = OptionButton.new()
	_gallery_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gallery_controls.add_child(_gallery_choices)
	_gallery_choices.item_selected.connect(_select_gallery_entry)
	_gallery_previous = Button.new()
	_gallery_previous.text = GALLERY_TEXTS.text("previous",_locale)
	_gallery_controls.add_child(_gallery_previous)
	_gallery_previous.pressed.connect(func(): _show_gallery_page(_gallery_page_index-1))
	_gallery_next = Button.new()
	_gallery_next.text = GALLERY_TEXTS.text("next",_locale)
	_gallery_controls.add_child(_gallery_next)
	_gallery_next.pressed.connect(func(): _show_gallery_page(_gallery_page_index+1))
	_gallery_controls.hide()
	_gallery_notebook_button = Button.new()
	_gallery_notebook_button.name = "GalleryNotebookButton"
	_gallery_notebook_button.text = GALLERY_TEXTS.text("notebook_open", _locale)
	_launch_return_button.get_parent().add_child(_gallery_notebook_button)
	_gallery_notebook_button.pressed.connect(_open_gallery_notebook)
	_gallery_notebook_button.hide()

func _gallery_scroll_input(event: InputEvent) -> void:
	if not _gallery_scroll.has_focus() or not _gallery_scroll.is_visible_in_tree(): return
	var down := event.is_action_pressed("ui_page_down", false, true)
	var up := event.is_action_pressed("ui_page_up", false, true)
	if not down and not up: return
	_gallery_scroll.scroll_vertical += (1 if down else -1) * maxi(40,int(_gallery_scroll.size.y * 0.8))
	_gallery_scroll.accept_event()

func _open_gallery() -> void:
	_gallery_previous.text = GALLERY_TEXTS.text("previous",_locale)
	_gallery_next.text = GALLERY_TEXTS.text("next",_locale)
	_gallery_entries = gallery_store.list_entries()
	_gallery_entry_index = -1
	_gallery_choices.clear()
	_gallery_scroll.scroll_vertical = 0
	_gallery_pages.clear()
	for index in range(_gallery_entries.size()):
		_gallery_choices.add_item(GALLERY_TEXTS.text("record",_locale) % [GALLERY_TEXTS.text(_gallery_entries[index]["branch"],_locale),index+1])
	_open_modal(_launch_panel, _launch_return_button)
	_gallery_controls.show()
	if _gallery_entries.is_empty():
		_launch_title.text = GALLERY_TEXTS.text("title",_locale)
		_launch_body.text = GALLERY_TEXTS.text("empty",_locale)
		_gallery_previous.disabled = true
		_gallery_next.disabled = true
	else: _select_gallery_entry(0)
	_rebuild_modal_focus_cycle()

func _select_gallery_entry(index: int) -> void:
	if index < 0 or index >= _gallery_entries.size(): return
	_gallery_entry_index = index
	_gallery_notebook_button.text = GALLERY_TEXTS.text("notebook_open", _locale)
	_gallery_notebook_button.visible = preload("res://scripts/systems/notebook_rollout.gd").enabled()
	_gallery_pages = preload("res://scripts/systems/ending_gallery_pages.gd").build(_gallery_entries[index]["state"],_locale)
	_show_gallery_page(0)

func _open_gallery_notebook() -> void:
	if not preload("res://scripts/systems/notebook_rollout.gd").enabled() or not _gallery_controls.visible or is_instance_valid(_gallery_notebook_host): return
	if _gallery_entry_index < 0 or _gallery_entry_index >= _gallery_entries.size(): return
	_gallery_notebook_host = preload("res://scripts/systems/notebook_gallery_host.gd").new()
	get_parent().add_child(_gallery_notebook_host)
	_gallery_notebook_host.closed.connect(func() -> void:
		_gallery_notebook_host = null
		if _gallery_controls.is_visible_in_tree(): _gallery_notebook_button.grab_focus())
	if not _gallery_notebook_host.begin(self, gallery_store, _gallery_entries[_gallery_entry_index].id, _locale, float(_profile.get("text_scale", 1.0))):
		_gallery_notebook_host.queue_free()
		_gallery_notebook_host = null
		_launch_body.text = GALLERY_TEXTS.text("notebook_unavailable", _locale)

func _show_gallery_page(index: int) -> void:
	if index < 0 or index >= _gallery_pages.size(): return
	_gallery_page_index = index
	_launch_title.text = "%s · %d/%d" % [_gallery_pages[index]["title"],index+1,_gallery_pages.size()]
	_launch_body.text = _gallery_pages[index]["text"]
	_gallery_scroll.scroll_vertical = 0
	_gallery_previous.disabled = index == 0
	_gallery_next.disabled = index == _gallery_pages.size()-1
	_rebuild_modal_focus_cycle()
	var focus := get_viewport().gui_get_focus_owner()
	if (focus == _gallery_previous and _gallery_previous.disabled) or (focus == _gallery_next and _gallery_next.disabled):
		_launch_return_button.grab_focus()

func _on_continue_pressed() -> void:
	if not _latest_slot_id.is_empty():
		load_game_requested.emit(_latest_slot_id)


func _on_new_game_pressed() -> void:
	if not bool(_profile.get("first_run_complete", false)):
		_first_run_panel.profile_store = _profile_store
		_first_run_panel.present(_profile, _locale, true)
		_open_modal(_first_run_panel, _first_run_panel.initial_focus())
		return
	_open_slot_panel("new")


func _on_load_pressed() -> void:
	_open_slot_panel("load")


func get_audio_settings() -> Dictionary:
	return _profile.get("audio", AccessibilityProfileStore.DEFAULT_AUDIO).duplicate()


func refresh_profile() -> void:
	_profile = _profile_store.load_profile().get("profile", _profile_store.default_profile()).duplicate(true)
	_locale = _profile.get("locale", _locale)
	TranslationServer.set_locale(_locale)
	_apply_localized_text()
	_apply_profile()


func _setup_settings() -> void:
	for panel in [_settings_panel, _first_run_panel]:
		panel.profile_store = _profile_store
		panel.profile_applied.connect(_on_settings_profile_applied)
		panel.back_requested.connect(_close_modal)
	_first_run_panel.first_run_completed.connect(func(): _open_slot_panel("new", false))


func _on_settings_profile_applied(profile: Dictionary, _section: String) -> void:
	_profile = profile.duplicate(true)
	_locale = profile.get("locale", _locale)
	TranslationServer.set_locale(_locale)
	_apply_localized_text()
	_apply_profile()
	refresh_slots()


func get_key_bindings() -> Dictionary:
	return _profile.get("key_bindings", preload("res://scripts/systems/key_bindings.gd").defaults()).duplicate(true)


func get_display_settings() -> Dictionary:
	return _profile.get("display", preload("res://scripts/systems/display_settings.gd").DEFAULT).duplicate()


func _apply_initial_display() -> void:
	var backend := preload("res://scripts/systems/display_settings.gd").WindowBackend.new(get_window())
	if not backend.apply(get_display_settings()): backend.apply(preload("res://scripts/systems/display_settings.gd").DEFAULT)


func _open_settings_page(page: String) -> void:
	var panel: PanelContainer = _first_run_panel if _first_run_panel.visible else _settings_panel
	panel.profile_store = _profile_store
	if not panel.visible: panel.present(_profile, _locale, false, page)
	else: panel.show_page(page, false)
	_open_modal(panel, panel.initial_focus(), _active_modal() == null)


func _open_display_settings() -> void:
	_open_settings_page("display")


func _open_key_settings() -> void:
	_open_settings_page("controls")


func _open_audio_settings() -> void:
	_open_settings_page("audio")


func _open_language_settings() -> void:
	_open_settings_page("language")


func _apply_key_settings(bindings: Dictionary) -> void:
	_settings_panel._draft.key_bindings = bindings.duplicate(true)
	_settings_panel._commit("controls")


func _apply_audio_settings(settings: Dictionary) -> void:
	_settings_panel._draft.audio = settings.duplicate()
	_settings_panel._commit("audio")


func _apply_language(locale: String) -> void:
	var panel: PanelContainer = _first_run_panel if _first_run_panel.visible else _settings_panel
	panel._draft.locale = locale
	panel._commit("language")


func _on_settings_pressed() -> void:
	_settings_panel.profile_store = _profile_store
	_settings_panel.present(_profile, _locale)
	_open_modal(_settings_panel, _settings_panel.initial_focus())


func _on_content_pressed() -> void:
	_open_modal(_content_panel, _content_close_button)


func _on_quit_pressed() -> void:
	_open_modal(_quit_panel, _quit_cancel_button)


func _on_slot_pressed(index: int) -> void:
	_active_slot_ui.select_row(_slot_buttons[index])


func _confirm_slot(slot_id: String) -> void:
	var summary: Dictionary = _slot_summaries.get(slot_id, {})
	if _slot_mode == "load":
		if bool(summary.get("available", false)):
			_close_modal()
			load_game_requested.emit(slot_id)
		return
	if bool(summary.get("available", false)):
		_pending_overwrite_slot = slot_id
		_overwrite_body.text = _text(&"UI_OVERWRITE_BODY", {"slot": SLOT_IDS.find(slot_id) + 1})
		_open_modal(_overwrite_panel, _overwrite_cancel_button, false)
		return
	_close_modal()
	new_game_requested.emit(slot_id)


func _on_first_run_default() -> void:
	_first_run_panel.restore_defaults()


func _on_first_run_apply() -> void:
	_first_run_panel.apply_current()


func _on_settings_apply() -> void:
	_settings_panel.apply_current()


func _confirm_overwrite() -> void:
	var slot_id := _pending_overwrite_slot
	_pending_overwrite_slot = ""
	_close_modal()
	if not slot_id.is_empty():
		new_game_requested.emit(slot_id)


func _return_to_slot_panel() -> void:
	_pending_overwrite_slot = ""
	_open_slot_panel(_slot_mode, false)


func _open_slot_panel(mode: String, remember_focus: bool = true) -> void:
	_slot_mode = mode
	_active_slot_ui = _new_slot_panel if mode == "new" else _load_slot_panel
	_new_slot_panel.visible = mode == "new"
	_load_slot_panel.visible = mode == "load"
	_slot_buttons.assign(_active_slot_ui.rows.filter(func(row): return not row.autosave))
	_slot_back_button = _active_slot_ui.back_button
	_active_slot_ui.present(_slot_summaries, _latest_slot_id, _locale, float(_profile.get("text_scale", 1.0)))
	_open_modal(_slot_panel, _active_slot_ui.initial_focus(), remember_focus)


func _update_slot_buttons() -> void:
	if not is_node_ready():
		return
	if is_instance_valid(_active_slot_ui):
		_active_slot_ui.present(_slot_summaries, _latest_slot_id, _locale, float(_profile.get("text_scale", 1.0)), false)


func _profile_from_controls(
	text_option,
	signature_option: OptionButton,
	motion_option,
	captions
) -> Dictionary:
	return {
		"audio": get_audio_settings(),
		"locale": _locale,
		"key_bindings": get_key_bindings(),
		"display": get_display_settings(),
		"accessibility_profile_version": AccessibilityProfileStore.PROFILE_VERSION,
		"first_run_complete": false,
		"text_scale": TEXT_SCALE_VALUES[text_option.selected],
		"signature_mode": SIGNATURE_VALUES[signature_option.selected],
		"motion_mode": MOTION_VALUES[motion_option.selected],
		"captions_enabled": captions.button_pressed,
	}


func _save_profile() -> bool:
	var result := _profile_store.save_profile(_profile)
	if bool(result.get("ok", false)):
		return true
	_status_label.text = _text(&"UI_STATUS_PROFILE_FAILED")
	_status_label.visible = true
	return false


func _apply_profile() -> void:
	preload("res://scripts/systems/key_bindings.gd").apply_bindings(get_key_bindings())
	audio_settings_changed.emit(get_audio_settings())
	var text_scale := float(_profile.get("text_scale", 1.0))
	var title_theme := preload("res://scripts/ui/design_theme.gd").make_theme()
	title_theme.default_font_size = int(round(18.0 * text_scale))
	theme = title_theme
	var logo_scale := minf(text_scale, 1.55)
	_logo_stack.custom_minimum_size.y = _logo_base_height * logo_scale
	_logo.add_theme_font_size_override("font_size", roundi(_logo_base_font * logo_scale))
	_menu_container.add_theme_constant_override("separation", maxi(5, roundi(_menu_base_separation - 3.0 * (text_scale - 1.0))))
	var motion_mode := String(_profile.get("motion_mode", "standard"))
	for button in _title_buttons:
		var base_font_size: float = _title_base_fonts[button]
		var base_height: float = _title_base_heights[button]
		button.add_theme_font_size_override("font_size", int(round(base_font_size * text_scale)))
		button.custom_minimum_size = Vector2(button.custom_minimum_size.x, base_height + 16.0 * (text_scale - 1.0))
		button.set_motion_mode(motion_mode)
	if is_instance_valid(_gallery_button):
		_gallery_button.add_theme_font_size_override("font_size", roundi(_title_base_fonts[_gallery_button] * text_scale))
		_gallery_button.custom_minimum_size.y = _title_base_heights[_gallery_button] + 16 * (text_scale - 1)


func _open_modal(panel: Control, focus_target: Control, remember_focus: bool = true) -> void:
	if is_instance_valid(_gallery_notebook_button): _gallery_notebook_button.hide()
	if is_instance_valid(_import_controls): _import_controls.hide()
	if is_instance_valid(_gallery_controls): _gallery_controls.hide()
	if remember_focus:
		var current_focus := get_viewport().gui_get_focus_owner()
		_focus_before_modal = current_focus if current_focus is Control else _new_game_button
	for modal in _modal_panels():
		modal.visible = modal == panel
	_dimmer.color = paper_modal_dimmer_color if panel in [_slot_panel, _settings_panel, _first_run_panel] else _default_dimmer_color
	_dimmer.visible = true
	panel.visible = true
	_apply_input_scope()
	_restore_scoped_focus.call_deferred(focus_target)


func _close_modal() -> void:
	if is_instance_valid(_gallery_notebook_button): _gallery_notebook_button.hide()
	if is_instance_valid(_import_controls): _import_controls.hide()
	if is_instance_valid(_gallery_controls): _gallery_controls.hide()
	for modal in _modal_panels():
		modal.visible = false
	_dimmer.visible = false
	_dimmer.color = _default_dimmer_color
	_apply_input_scope()
	_restore_scoped_focus.call_deferred(_focus_before_modal)


func _active_modal() -> Control:
	for modal in _modal_panels():
		if modal.visible:
			return modal
	return null


func _modal_panels() -> Array[Control]:
	return [
		_slot_panel,
		_first_run_panel,
		_settings_panel,
		_content_panel,
		_quit_panel,
		_overwrite_panel,
		_launch_panel,
	]


func _all_interactive_controls() -> Array[Control]:
	var controls: Array[Control] = [
		_continue_button, _new_game_button, _load_button, _settings_button, _quit_button, _content_button,
		_content_close_button, _quit_cancel_button, _quit_confirm_button, _overwrite_cancel_button,
		_overwrite_confirm_button, _launch_return_button,
	]
	for panel in [_new_slot_panel, _load_slot_panel]:
		controls.append_array(panel.rows)
		controls.append_array([panel.back_button, panel.close_button, panel.confirm_button])
	controls.append_array(_settings_panel.interactive_controls())
	controls.append_array(_first_run_panel.interactive_controls())
	if is_instance_valid(_gallery_button): controls.append_array([_gallery_button,_gallery_choices,_gallery_previous,_gallery_next,_gallery_notebook_button,_gallery_scroll])
	if is_instance_valid(_import_button): controls.append_array([_import_button,_import_choices,_import_confirm])
	return controls


func _bind_asset_ids() -> void:
	set_meta("asset_id", "UI_TITLE")
	set_meta("is_placeholder", true)
	_title_background.set_meta("asset_id", "UI_TITLE")
	_title_background.set_meta("resource_role", "background")
	_title_background.set_meta("is_generated", true)
	_title_background.set_meta("is_placeholder", true)
	_first_run_panel.set_meta("asset_id", "UI_FIRST_RUN_ACCESS")
	_first_run_panel.set_meta("is_placeholder", true)
	_settings_panel.set_meta("asset_id", "UI_SETTINGS")
	_settings_panel.set_meta("is_placeholder", true)
	_slot_panel.set_meta("asset_id", "UI_SAVE_SLOTS")
	_slot_panel.set_meta("is_placeholder", true)


func _text(line_id: StringName, variables: Dictionary = {}) -> String:
	return _dialogue.get_text(line_id, _locale, variables)
