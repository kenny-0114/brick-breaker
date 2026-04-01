# scripts/pause_menu.gd
# 일시정지 메뉴. 재개, 설정, 스테이지 선택 버튼을 제공한다.
extends CanvasLayer

@onready var dimmer: ColorRect = $Dimmer
@onready var panel: Control = $Panel
@onready var settings_popup: Control = $SettingsPopup


func _ready() -> void:
	dimmer.visible = false
	panel.visible = false


# 게임오버 상태이거나 설정 팝업이 열려있으면 ESC를 무시한다.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not GameManager.is_playing or settings_popup.visible:
			return
		toggle_pause()


# 일시정지 상태를 토글한다.
func toggle_pause() -> void:
	var is_paused := not get_tree().paused
	get_tree().paused = is_paused
	dimmer.visible = is_paused
	panel.visible = is_paused


# Resume 클릭이 Launcher 입력으로 전파되지 않도록 해제를 지연한다.
func _on_resume_pressed() -> void:
	dimmer.visible = false
	panel.visible = false
	await get_tree().process_frame
	get_tree().paused = false


func _on_stage_select_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func _on_settings_pressed() -> void:
	settings_popup.show_popup()
