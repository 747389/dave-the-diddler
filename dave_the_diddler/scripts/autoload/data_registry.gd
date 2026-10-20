extends Node

const UPGRADES_PATH: String = "res://data/upgrades/"
const UNLOCKS_PATH: String = "res://data/unlocks/"
const STAGES_PATH: String = "res://data/stages/"

var upgrades: Dictionary = {}
var unlocks: Dictionary = {}
var stages: Dictionary = {}


func _ready() -> void:
	load_data_registry()


func load_data_registry() -> void:
	# Each resource folder uses the same key-based loading path.
	_load_folder(UPGRADES_PATH, upgrades)
	_load_folder(UNLOCKS_PATH, unlocks)
	_load_folder(STAGES_PATH, stages)


## Loads keyed custom resources from one folder and reports entries without a valid key.
func _load_folder(path: String, registry: Dictionary) -> void:
	# Ignore files without a key so callers only receive usable custom resources.
	var directory := DirAccess.open(path)
	if directory == null:
		push_error("DataRegistry: could not open path: " + path)
		return

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := path + file_name
			var resource := load(full_path) as Resource
			var key: Variant = resource.get("key") if resource != null else null
			if key == null or str(key).is_empty():
				push_error("DataRegistry: invalid resource at path: " + full_path)
			else:
				registry[key] = resource
		file_name = directory.get_next()
	directory.list_dir_end()
