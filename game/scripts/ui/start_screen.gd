class_name StartScreen
extends Control

signal new_game_requested(slot_id: String)
signal load_game_requested(slot_id: String)
signal quit_requested

const SLOT_IDS := ["slot_01", "slot_02", "slot_03"]
const TEXT_SCALE_VALUES := [1.0, 1.25, 1.5, 2.0]
const SIGNATURE_VALUES := ["color_pattern_label", "pattern_label", "label_only"]
const MOTION_VALUES := ["standard", "reduced", "static"]

@onready var _title_background: TextureRect = %TitleBackground
@onready var _placeholder_art: UITitlePlaceholderArt = %PlaceholderArt
@onready var _eyebrow: Label = %Eyebrow
@onready var _logo: Label = %Logo
@onready var _tagline: Label = %Tagline
@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _load_button: Button = %LoadButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _content_button: Button = %ContentButton
@onready var _temporary_badge: Label = %TemporaryBadge
@onready var _version_label: Label = %VersionLabel
@onready var _status_label: Label = %TitleStatus
@onready var _dimmer: ColorRect = %ModalDimmer
@onready var _slot_panel: PanelContainer = %SlotPanel
@onready var _slot_title: Label = %SlotTitle
@onready var _slot_buttons: Array[Button] = [%SlotButton1, %SlotButton2, %SlotButton3]
@onready var _slot_back_button: Button = %SlotBackButton
@onready var _first_run_panel: PanelContainer = %FirstRunPanel
@onready var _first_run_title: Label = %FirstRunTitle
@onready var _first_run_description: Label = %FirstRunDescription
@onready var _first_text_label: Label = %FirstTextLabel
@onready var _first_text_option: OptionButton = %FirstTextOption
@onready var _first_signature_label: Label = %FirstSignatureLabel
@onready var _first_signature_option: OptionButton = %FirstSignatureOption
@onready var _first_motion_label: Label = %FirstMotionLabel
@onready var _first_motion_option: OptionButton = %FirstMotionOption
@onready var _first_captions: CheckButton = %FirstCaptions
@onready var _first_preview: Label = %PreviewText
@onready var _first_default_button: Button = %FirstDefaultButton
@onready var _first_apply_button: Button = %FirstApplyButton
@onready var _settings_panel: PanelContainer = %SettingsPanel
@onready var _settings_title: Label = %SettingsTitle
@onready var _settings_text_label: Label = %SettingsTextLabel
@onready var _settings_text_option: OptionButton = %SettingsTextOption
@onready var _settings_signature_label: Label = %SettingsSignatureLabel
@onready var _settings_signature_option: OptionButton = %SettingsSignatureOption
@onready var _settings_motion_label: Label = %SettingsMotionLabel
@onready var _settings_motion_option: OptionButton = %SettingsMotionOption
@onready var _settings_captions: CheckButton = %SettingsCaptions
@onready var _settings_back_button: Button = %SettingsBackButton
@onready var _settings_apply_button: Button = %SettingsApplyButton
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
var _locale := "ko-KR"
var _slot_summaries: Dictionary = {}
var _latest_slot_id := ""
var _slot_mode := "load"
var _pending_overwrite_slot := ""
var _focus_before_modal: Control


func configure_profile_store(profile_store: AccessibilityProfileStore) -> void:
	if is_node_ready():
		push_error("The accessibility profile store must be configured before StartScreen enters the tree.")
		return
	_profile_store = profile_store


func _ready() -> void:
	_locale = TranslationServer.get_locale()
	_bind_asset_ids()
	_connect_controls()
	_populate_options()
	var profile_result := _profile_store.load_profile()
	_profile = profile_result.get("profile", _profile_store.default_profile()).duplicate(true)
	_apply_localized_text()
	_apply_profile()
	refresh_slots()
	(_continue_button if not _continue_button.disabled else _new_game_button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _active_modal() != null:
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
		_slot_summaries[slot_id] = summary.duplicate(true)
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
	for control in _all_interactive_controls():
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE if suspended else Control.MOUSE_FILTER_STOP
		control.focus_mode = Control.FOCUS_NONE if suspended else Control.FOCUS_ALL
	if suspended:
		get_viewport().gui_release_focus()
	else:
		var modal := _active_modal()
		if modal == null:
			(_continue_button if not _continue_button.disabled else _new_game_button).grab_focus()


func _connect_controls() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_content_button.pressed.connect(_on_content_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	for index in range(_slot_buttons.size()):
		_slot_buttons[index].pressed.connect(_on_slot_pressed.bind(index))
	_slot_back_button.pressed.connect(_close_modal)
	_first_default_button.pressed.connect(_on_first_run_default)
	_first_apply_button.pressed.connect(_on_first_run_apply)
	_settings_back_button.pressed.connect(_close_modal)
	_settings_apply_button.pressed.connect(_on_settings_apply)
	_content_close_button.pressed.connect(_close_modal)
	_quit_cancel_button.pressed.connect(_close_modal)
	_quit_confirm_button.pressed.connect(func() -> void: quit_requested.emit())
	_overwrite_cancel_button.pressed.connect(_return_to_slot_panel)
	_overwrite_confirm_button.pressed.connect(_confirm_overwrite)
	_launch_return_button.pressed.connect(_close_modal)


func _populate_options() -> void:
	for option in [_first_text_option, _settings_text_option]:
		option.clear()
		for value in ["100%", "125%", "150%", "200%"]:
			option.add_item(value)
	for option in [_first_signature_option, _settings_signature_option]:
		option.clear()
		for line_id in [&"UI_SIGNATURE_COLOR_PATTERN", &"UI_SIGNATURE_PATTERN_LABEL", &"UI_SIGNATURE_LABEL_ONLY"]:
			option.add_item(_text(line_id))
	for option in [_first_motion_option, _settings_motion_option]:
		option.clear()
		for line_id in [&"UI_MOTION_STANDARD", &"UI_MOTION_REDUCED", &"UI_MOTION_STATIC"]:
			option.add_item(_text(line_id))


func _apply_localized_text() -> void:
	_eyebrow.text = _text(&"UI_TITLE_EYEBROW")
	_logo.text = _text(&"UI_TITLE_LOGO")
	_tagline.text = _text(&"UI_TITLE_TAGLINE")
	_continue_button.text = _text(&"UI_TITLE_CONTINUE")
	_new_game_button.text = _text(&"UI_TITLE_NEW_GAME")
	_load_button.text = _text(&"UI_TITLE_LOAD")
	_settings_button.text = _text(&"UI_TITLE_SETTINGS")
	_quit_button.text = _text(&"UI_TITLE_QUIT")
	_content_button.text = _text(&"UI_TITLE_CONTENT_DETAILS")
	_temporary_badge.text = _text(&"UI_TITLE_TEMP_ASSET")
	_version_label.text = _text(&"UI_TITLE_VERSION")
	_slot_back_button.text = _text(&"UI_COMMON_BACK")
	_first_run_title.text = _text(&"UI_FIRST_RUN_TITLE")
	_first_run_description.text = _text(&"UI_FIRST_RUN_DESCRIPTION")
	_first_text_label.text = _text(&"UI_ACCESS_TEXT_SCALE")
	_first_signature_label.text = _text(&"UI_ACCESS_SIGNATURE_MODE")
	_first_motion_label.text = _text(&"UI_ACCESS_MOTION_MODE")
	_first_captions.text = _text(&"UI_ACCESS_CAPTIONS")
	_first_preview.text = _text(&"UI_ACCESS_PREVIEW_SAMPLE")
	_first_default_button.text = _text(&"UI_ACCESS_DEFAULT_START")
	_first_apply_button.text = _text(&"UI_ACCESS_APPLY_START")
	_settings_title.text = _text(&"UI_SETTINGS_TITLE")
	_settings_text_label.text = _text(&"UI_ACCESS_TEXT_SCALE")
	_settings_signature_label.text = _text(&"UI_ACCESS_SIGNATURE_MODE")
	_settings_motion_label.text = _text(&"UI_ACCESS_MOTION_MODE")
	_settings_captions.text = _text(&"UI_ACCESS_CAPTIONS")
	_settings_back_button.text = _text(&"UI_COMMON_BACK")
	_settings_apply_button.text = _text(&"UI_SETTINGS_APPLY")
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


func _on_continue_pressed() -> void:
	if not _latest_slot_id.is_empty():
		load_game_requested.emit(_latest_slot_id)


func _on_new_game_pressed() -> void:
	if not bool(_profile.get("first_run_complete", false)):
		_sync_controls_from_profile(_first_text_option, _first_signature_option, _first_motion_option, _first_captions)
		_open_modal(_first_run_panel, _first_text_option)
		return
	_open_slot_panel("new")


func _on_load_pressed() -> void:
	_open_slot_panel("load")


func _on_settings_pressed() -> void:
	_sync_controls_from_profile(_settings_text_option, _settings_signature_option, _settings_motion_option, _settings_captions)
	_open_modal(_settings_panel, _settings_text_option)


func _on_content_pressed() -> void:
	_open_modal(_content_panel, _content_close_button)


func _on_quit_pressed() -> void:
	_open_modal(_quit_panel, _quit_cancel_button)


func _on_slot_pressed(index: int) -> void:
	var slot_id: String = String(SLOT_IDS[index])
	var summary: Dictionary = _slot_summaries.get(slot_id, {})
	if _slot_mode == "load":
		if bool(summary.get("available", false)):
			_close_modal()
			load_game_requested.emit(slot_id)
		return
	if bool(summary.get("available", false)):
		_pending_overwrite_slot = slot_id
		_overwrite_body.text = _text(&"UI_OVERWRITE_BODY", {"slot": index + 1})
		_open_modal(_overwrite_panel, _overwrite_cancel_button, false)
		return
	_close_modal()
	new_game_requested.emit(slot_id)


func _on_first_run_default() -> void:
	_profile = _profile_store.default_profile()
	_profile["first_run_complete"] = true
	if not _save_profile():
		return
	_apply_profile()
	_open_slot_panel("new", false)


func _on_first_run_apply() -> void:
	_profile = _profile_from_controls(_first_text_option, _first_signature_option, _first_motion_option, _first_captions)
	_profile["first_run_complete"] = true
	if not _save_profile():
		return
	_apply_profile()
	_open_slot_panel("new", false)


func _on_settings_apply() -> void:
	var first_run_complete := bool(_profile.get("first_run_complete", false))
	_profile = _profile_from_controls(_settings_text_option, _settings_signature_option, _settings_motion_option, _settings_captions)
	_profile["first_run_complete"] = first_run_complete
	if not _save_profile():
		return
	_apply_profile()
	_close_modal()


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
	_slot_title.text = _text(&"UI_SLOT_NEW_TITLE" if mode == "new" else &"UI_SLOT_LOAD_TITLE")
	_update_slot_buttons()
	_open_modal(_slot_panel, _slot_buttons[0], remember_focus)


func _update_slot_buttons() -> void:
	if not is_node_ready():
		return
	for index in range(SLOT_IDS.size()):
		var slot_id: String = String(SLOT_IDS[index])
		var summary: Dictionary = _slot_summaries.get(slot_id, {})
		var is_available := bool(summary.get("available", false))
		if is_available:
			_slot_buttons[index].text = _text(&"UI_SLOT_FILLED", {
				"slot": index + 1,
				"day": int(summary.get("day_index", 0)) + 1,
				"location": String(summary.get("location_id", "")),
			})
		else:
			_slot_buttons[index].text = _text(&"UI_SLOT_EMPTY", {"slot": index + 1})
		_slot_buttons[index].disabled = _slot_mode == "load" and not is_available


func _sync_controls_from_profile(
	text_option: OptionButton,
	signature_option: OptionButton,
	motion_option: OptionButton,
	captions: CheckButton
) -> void:
	text_option.select(maxi(0, TEXT_SCALE_VALUES.find(float(_profile.get("text_scale", 1.0)))))
	signature_option.select(maxi(0, SIGNATURE_VALUES.find(String(_profile.get("signature_mode", "color_pattern_label")))))
	motion_option.select(maxi(0, MOTION_VALUES.find(String(_profile.get("motion_mode", "standard")))))
	captions.button_pressed = bool(_profile.get("captions_enabled", true))


func _profile_from_controls(
	text_option: OptionButton,
	signature_option: OptionButton,
	motion_option: OptionButton,
	captions: CheckButton
) -> Dictionary:
	return {
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
	var title_theme := Theme.new()
	title_theme.default_font_size = int(round(18.0 * float(_profile.get("text_scale", 1.0))))
	theme = title_theme
	_placeholder_art.set_motion_mode(String(_profile.get("motion_mode", "standard")))


func _open_modal(panel: Control, focus_target: Control, remember_focus: bool = true) -> void:
	if remember_focus:
		var current_focus := get_viewport().gui_get_focus_owner()
		_focus_before_modal = current_focus if current_focus is Control else _new_game_button
	for modal in _modal_panels():
		modal.visible = modal == panel
	_dimmer.visible = true
	panel.visible = true
	focus_target.call_deferred("grab_focus")


func _close_modal() -> void:
	for modal in _modal_panels():
		modal.visible = false
	_dimmer.visible = false
	var focus_is_available := is_instance_valid(_focus_before_modal)
	if focus_is_available and _focus_before_modal is BaseButton:
		focus_is_available = not (_focus_before_modal as BaseButton).disabled
	if focus_is_available:
		_focus_before_modal.call_deferred("grab_focus")
	else:
		_new_game_button.call_deferred("grab_focus")


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
		_slot_back_button, _first_text_option, _first_signature_option, _first_motion_option, _first_captions,
		_first_default_button, _first_apply_button, _settings_text_option, _settings_signature_option,
		_settings_motion_option, _settings_captions, _settings_back_button, _settings_apply_button,
		_content_close_button, _quit_cancel_button, _quit_confirm_button, _overwrite_cancel_button,
		_overwrite_confirm_button, _launch_return_button,
	]
	for button in _slot_buttons:
		controls.append(button)
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
