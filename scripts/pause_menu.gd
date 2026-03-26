# scripts/pause_menu.gd
# 일시정지 메뉴. 재개, 설정, 스테이지 선택 버튼을 제공한다.
extends CanvasLayer

@onready var panel: Control = $Panel


func _ready() -> void:
	panel.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()


# 일시정지 상태를 토글한다.
func toggle_pause() -> void:
	var is_paused := not get_tree().paused
	get_tree().paused = is_paused
	panel.visible = is_paused


func _on_resume_pressed() -> void:
	toggle_pause()


func _on_stage_select_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func _on_settings_pressed() -> void:
	$SettingsPopup.show_popup()
