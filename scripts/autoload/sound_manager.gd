# scripts/autoload/sound_manager.gd
# BGM/SFX 재생 및 볼륨을 제어한다.
# AudioStreamPlayer 풀로 동시 다발 SFX를 처리한다.
extends Node

const SFX_POOL_SIZE := 5

var _bgm_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _bgm_bus_idx: int = -1
var _sfx_bus_idx: int = -1

# 프리로드할 UI 사운드
var sfx_click: AudioStream = preload("res://assets/sounds/click-a.ogg")
var sfx_tap: AudioStream = preload("res://assets/sounds/tap-a.ogg")
var sfx_ball_hit: AudioStream = preload("res://assets/sounds/sfx_ball_hit.ogg")
var sfx_laser: AudioStream = preload("res://assets/sounds/sfx_laser.ogg")
var sfx_explosion: AudioStream = preload("res://assets/sounds/sfx_explosion.ogg")


func _ready() -> void:
	# BGM 버스와 SFX 버스를 추가한다.
	_setup_audio_buses()
	# BGM Player 생성
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "BGM"
	add_child(_bgm_player)
	# SFX Pool 생성
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)
	# 저장된 볼륨 설정을 적용한다.
	_apply_saved_volume()


# BGM과 SFX 오디오 버스를 생성하고 인덱스를 캐싱한다.
func _setup_audio_buses() -> void:
	if AudioServer.get_bus_index("BGM") == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(idx, "BGM")
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")
	_bgm_bus_idx = AudioServer.get_bus_index("BGM")
	_sfx_bus_idx = AudioServer.get_bus_index("SFX")


# SFX를 풀에서 하나 골라 재생한다.
func play_sfx(stream: AudioStream) -> void:
	var player := _sfx_pool[_sfx_index]
	player.stream = stream
	player.play()
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE


# BGM을 재생한다.
func play_bgm(stream: AudioStream) -> void:
	if _bgm_player.stream == stream and _bgm_player.playing:
		return
	_bgm_player.stream = stream
	_bgm_player.play()


# BGM을 멈춘다.
func stop_bgm() -> void:
	_bgm_player.stop()


# 볼륨을 설정하고 저장한다. volume은 0.0~1.0 범위이다.
func set_bgm_volume(volume: float) -> void:
	var db := linear_to_db(clampf(volume, 0.0, 1.0))
	AudioServer.set_bus_volume_db(_bgm_bus_idx, db)


func set_sfx_volume(volume: float) -> void:
	var db := linear_to_db(clampf(volume, 0.0, 1.0))
	AudioServer.set_bus_volume_db(_sfx_bus_idx, db)


# 저장된 볼륨 설정을 적용한다.
func _apply_saved_volume() -> void:
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr == null:
		return
	var data: Dictionary = save_mgr.get("data") as Dictionary
	if data.is_empty():
		return
	var settings: Dictionary = data.get("settings", {}) as Dictionary
	set_bgm_volume(float(settings.get("bgm_volume", 1.0)))
	set_sfx_volume(float(settings.get("sfx_volume", 1.0)))
