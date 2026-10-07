extends RefCounted

const CONTENT := preload("res://scripts/systems/notebook_content.gd")
var errors := PackedStringArray()
var checks := 0


func run() -> Dictionary:
	var specs := {"a":"string", "n":"int", "phase":"enum:phase"}
	var enums := {"phase":{"ko-KR":{"p":"{a} 한국어"}, "en-US":{"p":"English {n}"}}}
	var variables := {"a":"{n}🙂", "n":3.0, "phase":"p"}
	var frozen := JSON.stringify([variables, specs, enums])
	for locale in ["ko-KR", "en-US"]:
		for template in ["{a}:{n}:{phase}:{a}", "접두🙂{a}\n{n}!", "{{a}} {미정} {0} {a_x}", "literal", "{n}{a}"]:
			var declared := specs.duplicate()
			var values := variables.duplicate()
			if template.contains("{a_x}"):
				declared.a_x = "string"
				values.a_x = "literal {phase}"
			_expect(CONTENT._substitute(template, values, declared, enums, locale) == _oracle(template, values, declared, enums, locale), "exact single-pass parity " + locale)
	_expect(JSON.stringify([variables, specs, enums]) == frozen, "values, specs and enum translations are not changed")
	var unique := "SUBSTITUTION_REUSE_CHECK:{a}"
	CONTENT._substitute(unique, {"a":"first"}, {"a":"string"})
	var built: int = CONTENT.substitution_diagnostics().builds
	_expect(CONTENT._substitute(unique, {"a":"second {a}"}, {"a":"string"}) == "SUBSTITUTION_REUSE_CHECK:second {a}", "no previous values or recursive expansion")
	_expect(CONTENT.substitution_diagnostics().builds == built, "identical template reuses parsed parts")
	var parts := CONTENT._compiled_template(unique)
	_expect(parts.is_read_only() and parts.all(func(part: Array) -> bool: return part.is_read_only()), "both token array and nested pairs are read-only")
	var before := CONTENT.substitution_diagnostics()
	_expect(CONTENT._substitute("{a}", {}, {}) == "{a}", "empty specs preserve literal template")
	_expect(CONTENT.substitution_diagnostics() == before, "empty specs skip cache work")
	var oversized := "x".repeat(CONTENT.SUBSTITUTION_TEMPLATE_LIMIT + 1) + "{a}"
	CONTENT._substitute(oversized, {"a":"ok"}, {"a":"string"})
	_expect(CONTENT.substitution_diagnostics().entries == before.entries and CONTENT.substitution_diagnostics().characters == before.characters, "oversized templates are not retained")
	for index in range(CONTENT.SUBSTITUTION_CACHE_LIMIT + 5):
		var template := "EVICTION_%d:" % index + "x".repeat(4096) + "{a}"
		_expect(CONTENT._substitute(template, {"a":"ok"}, {"a":"string"}) == template.trim_suffix("{a}") + "ok", "eviction retains exact output")
	var bounded := CONTENT.substitution_diagnostics()
	_expect(bounded.entries <= CONTENT.SUBSTITUTION_CACHE_LIMIT and bounded.characters <= CONTENT.SUBSTITUTION_CHARACTER_LIMIT, "entry and template-character limits hold")
	var workers: Array[Thread] = []
	for index in range(8):
		var worker := Thread.new()
		_expect(worker.start(_threaded.bind(index)) == OK, "worker starts")
		workers.append(worker)
	for worker in workers: _expect(worker.wait_to_finish(), "concurrent cache consumers keep their own values and locale")
	var timings: Array = []
	var expected: Array = []
	for mode in ["oracle", "cache", "cache", "oracle"]:
		var output: Array = []
		var start := Time.get_ticks_usec()
		for index in range(2000):
			var template := "BENCH:{a}:{n}:{a}"
			var values := {"a":"{n}🙂-%d" % index, "n":float(index)}
			var declared := {"a":"string", "n":"int"}
			output.append(_oracle(template, values, declared, {}, "ko-KR") if mode == "oracle" else CONTENT._substitute(template, values, declared))
		timings.append({"mode":mode,"rows":2000,"ms":(Time.get_ticks_usec() - start) / 1000.0})
		if expected.is_empty(): expected = output
		else: _expect(output == expected, "paired path measurements preserve every value")
	print("NOTEBOOK_SUBSTITUTION_TIMING: ", JSON.stringify(timings))
	print("NOTEBOOK_SUBSTITUTION_CHECKS: ", checks)
	return {"ok":errors.is_empty(), "errors":errors}


func _threaded(index: int) -> bool:
	for iteration in range(100):
		var template := "THREAD_SHARED:{a}:{n}"
		var values := {"a":"{n}-%d" % index, "n":float(iteration)}
		if CONTENT._substitute(template, values, {"a":"string", "n":"int"}) != "THREAD_SHARED:{n}-%d:%d" % [index, iteration]: return false
	return true


func _oracle(template: String, variables: Dictionary, specs: Dictionary, enums: Dictionary, locale: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\{([A-Za-z][A-Za-z0-9_]*)\\}")
	var text := ""
	var offset := 0
	for found in regex.search_all(template):
		var key := found.get_string(1)
		var value: Variant = int(variables[key]) if specs[key] == "int" else variables[key]
		if String(specs[key]).begins_with("enum:"): value = enums[String(specs[key]).trim_prefix("enum:")][locale][variables[key]]
		text += template.substr(offset, found.get_start() - offset) + str(value)
		offset = found.get_end()
	return text + template.substr(offset)


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)
