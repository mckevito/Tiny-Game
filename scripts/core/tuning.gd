class_name Tuning
extends RefCounted
## Every number and string lives in a JSON table under res://data (CLAUDE.md). Tables load once and are cached.
## Read a value with a dotted path: Tuning.num("tuning", "movement.walk_speed_mps").

static var _tables: Dictionary = {}


## Loads (or returns the cached) table res://data/<name>.json. A missing or broken table is an empty Dictionary
## and an error in the log, so a check can fail loudly instead of the game crashing.
static func table(name: String) -> Dictionary:
	if _tables.has(name):
		return _tables[name]
	var path := "res://data/%s.json" % name
	var data: Variant = null
	if FileAccess.file_exists(path):
		data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("Tuning: could not read %s" % path)
		data = {}
	_tables[name] = data
	return data


## The value at a dotted path in a table, or `fallback` when any part of the path is missing.
static func value(name: String, path: String, fallback: Variant = null) -> Variant:
	var node: Variant = table(name)
	for key in path.split("."):
		if not (node is Dictionary and node.has(key)):
			return fallback
		node = node[key]
	return node


static func num(name: String, path: String, fallback: float = 0.0) -> float:
	var v: Variant = value(name, path, fallback)
	return float(v) if (v is float or v is int) else fallback


static func text(path: String) -> String:
	return str(value("text", path, path))


## Drops the cache, so edited tables are read again (tests and the dev menu use this).
static func reload() -> void:
	_tables.clear()
