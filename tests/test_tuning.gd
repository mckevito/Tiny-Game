extends RefCounted
## Milestone 0: tuning tables load, read typed values and fall back on missing keys.


func test_walk_speed_is_a_positive_number() -> String:
	Tuning.reload()
	var v := Tuning.num("tuning", "movement.walk_speed_mps", -1.0)
	return "" if v > 0.0 else "walk_speed_mps is %s" % v


func test_missing_key_returns_fallback() -> String:
	var v: Variant = Tuning.value("tuning", "movement.no_such_key", "fallback")
	return "" if v == "fallback" else "got %s" % v


func test_missing_table_is_empty() -> String:
	var t := Tuning.table("no_such_table")
	return "" if t.is_empty() else "expected an empty table"


func test_text_reads_a_string() -> String:
	var s := Tuning.text("sandbox.hint")
	return "" if s != "sandbox.hint" and s.length() > 0 else "sandbox.hint text missing"
