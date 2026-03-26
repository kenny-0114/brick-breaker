# scripts/autoload/save_manager.gd
# 영속 데이터를 user://save_data.json에 저장/로드한다.
# 해금 레벨, 최고 점수, 별, 설정값을 관리한다.
extends Node

const SAVE_PATH := "user://save_data.json"

# 기본값
var data := {
	"unlocked_level": 1,
	"high_scores": {},
	"stars": {},
	"settings": {
		"bgm_volume": 1.0,
		"sfx_volume": 1.0
	}
}


func _ready() -> void:
	load_data()


# 파일에서 저장 데이터를 읽는다.
func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Failed to open save file: %s" % error_string(FileAccess.get_open_error()))
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("SaveManager: Failed to parse save file: %s" % json.get_error_message())
		return
	var parsed: Variant = json.data
	if parsed is Dictionary:
		_merge_data(parsed)


# 현재 데이터를 파일에 저장한다.
func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Failed to write save file: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))


# 스테이지 클리어 시 결과를 반영한다.
func complete_stage(level: int, score: int, stars_earned: int) -> void:
	var level_key := str(level)
	# 해금 레벨 갱신
	if level + 1 > data["unlocked_level"]:
		data["unlocked_level"] = level + 1
	# 최고 점수 갱신
	var current_high: int = data["high_scores"].get(level_key, 0)
	if score > current_high:
		data["high_scores"][level_key] = score
	# 별 갱신
	var current_stars: int = data["stars"].get(level_key, 0)
	if stars_earned > current_stars:
		data["stars"][level_key] = stars_earned
	save_data()


# 설정값을 저장한다.
func save_settings(bgm_volume: float, sfx_volume: float) -> void:
	data["settings"]["bgm_volume"] = bgm_volume
	data["settings"]["sfx_volume"] = sfx_volume
	save_data()


# 파싱된 데이터를 기본값 위에 안전하게 병합한다.
func _merge_data(parsed: Dictionary) -> void:
	for key in data.keys():
		if parsed.has(key):
			data[key] = parsed[key]
