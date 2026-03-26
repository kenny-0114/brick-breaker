# scripts/autoload/sound_manager.gd
# BGM/SFX 재생 및 볼륨을 제어한다.
# AudioStreamPlayer 풀로 동시 다발 SFX를 처리한다.
extends Node

const SFX_POOL_SIZE := 5

var _bgm_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

# 프리로드할 UI 사운드
var sfx_click: AudioStream = preload("res://assets/sounds/click-a.ogg")
var sfx_tap: AudioStream = preload("res://assets/sounds/tap-a.ogg")


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


# BGM과 SFX 오디오 버스를 생성한다.
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
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("BGM"), db)


func set_sfx_volume(volume: float) -> void:
	var db := linear_to_db(clampf(volume, 0.0, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db)


# 저장된 볼륨 설정을 적용한다.
func _apply_saved_volume() -> void:
	var settings: Dictionary = SaveManager.data.get("settings", {})
	set_bgm_volume(settings.get("bgm_volume", 1.0))
	set_sfx_volume(settings.get("sfx_volume", 1.0))
