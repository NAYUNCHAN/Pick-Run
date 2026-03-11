extends RefCounted
class_name SaveSystem

const SAVE_PATH: String = "user://save.json"
const VERSION: int = 2

static func save(data: Dictionary) -> bool:
	var payload: Dictionary = data.duplicate(true)
	payload["version"] = VERSION

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[SaveSystem] 저장 파일 열기 실패")
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true

static func load_or_init(default_data: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		save(default_data)
		return default_data.duplicate(true)

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[SaveSystem] 저장 파일 읽기 실패. 기본값 복구")
		save(default_data)
		return default_data.duplicate(true)

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[SaveSystem] 손상된 save.json 감지. 기본값 복구")
		save(default_data)
		return default_data.duplicate(true)

	var loaded: Dictionary = parsed as Dictionary
	if int(loaded.get("version", -1)) != VERSION:
		push_warning("[SaveSystem] 버전 불일치. 기본값 복구")
		save(default_data)
		return default_data.duplicate(true)

	var merged: Dictionary = default_data.duplicate(true)
	for key in default_data.keys():
		if loaded.has(key):
			merged[key] = loaded[key]
	return merged
