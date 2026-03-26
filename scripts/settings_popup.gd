# scripts/settings_popup.gd
# BGM/SFX 볼륨 조절 팝업. TitleScreen과 PauseMenu에서 사용한다.
extends Control

@onready var panel: Control = $Panel
@onready var bgm_slider: HSlider = $Panel/VBoxContainer/BGMSlider
@onready var sfx_slider: HSlider = $Panel/VBoxContainer/SFXSlider


func _ready() -> void:
	visible = false
	var settings: Dictionary = SaveManager.data.get("settings", {}) as Dictionary
	bgm_slider.value = float(settings.get("bgm_volume", 1.0))
	sfx_slider.value = float(settings.get("sfx_volume", 1.0))


# 팝업을 연다.
func show_popup() -> void:
	visible = true


func _on_bgm_slider_value_changed(value: float) -> void:
	SoundManager.set_bgm_volume(value)


func _on_sfx_slider_value_changed(value: float) -> void:
	SoundManager.set_sfx_volume(value)


func _on_close_pressed() -> void:
	SaveManager.save_settings(bgm_slider.value, sfx_slider.value)
	visible = false
