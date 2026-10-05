extends RefCounted


# Opening is accepted synchronously, but records are published on a later frame.
static func ready(tree: SceneTree, host) -> bool:
	var start := Time.get_ticks_msec()
	while is_instance_valid(host) and host._opening and not host._refresh_job.is_empty():
		if Time.get_ticks_msec() - start > 60000: return false
		await tree.process_frame
	return is_instance_valid(host) and not host._opening and not host._closing and host.model.diagnostics().ready
