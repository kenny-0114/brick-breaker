# scripts/title_screen.gd
# 게임 타이틀 화면. Play 버튼으로 스테이지 선택, Settings 버튼으로 설정 팝업을 연다.
extends Control


func _on_play_pressed() -> void:
	SoundManager.play_sfx(SoundManager.sfx_click)
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func _on_settings_pressed() -> void:
	SoundManager.play_sfx(SoundManager.sfx_click)
	$SettingsPopup.show_popup()
