extends RefCounted


# Opening is accepted synchronously, but records are published on a later frame.
static func ready(tree: SceneTree, host) -> bool:
	var start := Time.get_ticks_msec()
	while is_instance_valid(host) and host._opening and not host._refresh_job.is_empty():
		if Time.get_ticks_msec() - start > 60000: return false
		await tree.process_frame
	return is_instance_valid(host) and not host._opening and not host._closing and host.model.diagnostics().ready


# A requested close may still wait for the in-flight query or reference worker.
static func closed(tree: SceneTree, host) -> bool:
	var start := Time.get_ticks_msec()
	while is_instance_valid(host) and host._suspended:
		if Time.get_ticks_msec() - start > 60000: return false
		await tree.process_frame
	return not is_instance_valid(host) or not host._suspended
