# scripts/settings_popup.gd
# 볼륨과 튜토리얼 반복 설정 팝업. TitleScreen과 PauseMenu에서 사용한다.
extends Control

@onready var panel: Control = $Panel
@onready var bgm_slider: HSlider = $Panel/BodyPanel/VBoxContainer/BGMSlider
@onready var sfx_slider: HSlider = $Panel/BodyPanel/VBoxContainer/SFXSlider
@onready var repeat_tutorials: CheckButton = $Panel/BodyPanel/VBoxContainer/RepeatTutorials


func _ready() -> void:
	visible = false
	var settings: Dictionary = SaveManager.data.get("settings", {}) as Dictionary
	bgm_slider.value = float(settings.get("bgm_volume", 1.0))
	sfx_slider.value = float(settings.get("sfx_volume", 1.0))
	repeat_tutorials.set_pressed_no_signal(settings.get("repeat_tutorials", false) == true)


# 팝업을 열고, 현재 볼륨 설정으로 슬라이더를 동기화한다.
func show_popup() -> void:
	var settings: Dictionary = SaveManager.data.get("settings", {}) as Dictionary
	bgm_slider.value = float(settings.get("bgm_volume", 1.0))
	sfx_slider.value = float(settings.get("sfx_volume", 1.0))
	repeat_tutorials.set_pressed_no_signal(settings.get("repeat_tutorials", false) == true)
	visible = true


func _on_bgm_slider_value_changed(value: float) -> void:
	SoundManager.set_bgm_volume(value)


func _on_sfx_slider_value_changed(value: float) -> void:
	SoundManager.set_sfx_volume(value)


func _on_close_pressed() -> void:
	SaveManager.save_settings(bgm_slider.value, sfx_slider.value)
	visible = false


# 다음 스테이지 진입부터 안내 반복 여부를 적용한다.
func _on_repeat_tutorials_toggled(enabled: bool) -> void:
	SaveManager.save_repeat_tutorials(enabled)
