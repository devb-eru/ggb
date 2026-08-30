extends SceneTree

const PRACTICE_SCENE := preload("res://signal_practice.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors := PackedStringArray()
	for starting_index in [0, 1, 2]:
		var instance := PRACTICE_SCENE.instantiate()
		var background: PracticeBackground = instance.get_node("background")
		background.background_index = starting_index
		root.add_child(instance)
		await process_frame

		var drawer: PracticeDrawer = instance.get_node("drawer")
		var key: PracticeKey = instance.get_node("key")
		var lock: PracticeLock = instance.get_node("lock")
		var inventory: PracticeInventory = instance.get_node("inventory")
		_expect(drawer.visible == (starting_index == 0), "drawer mismatch at index %d" % starting_index, errors)
		_expect(lock.visible == (starting_index == 0), "lock mismatch at index %d" % starting_index, errors)
		_expect(not key.visible, "closed drawer exposed key at index %d" % starting_index, errors)

		if starting_index == 0:
			drawer.pressed.emit()
			_expect(key.visible, "open drawer did not expose key", errors)
			background.next_page()
			_expect(not key.visible, "key remained visible outside target background", errors)
			background.previous_page()
			_expect(key.visible, "key did not return with open drawer", errors)
			key.pressed.emit()
			_expect(inventory.has_item(PracticeKey.KEY_ITEM_ID), "key was not added to inventory", errors)
			_expect(key.disabled and not key.visible, "acquired key remained interactive", errors)

		instance.queue_free()
		await process_frame

	if errors.is_empty():
		print("PRACTICE_SCENE_SMOKE: PASS")
		quit(0)
	else:
		push_error("PRACTICE_SCENE_SMOKE: FAIL %s" % errors)
		quit(1)


func _expect(condition: bool, message: String, errors: PackedStringArray) -> void:
	if not condition:
		errors.append(message)
