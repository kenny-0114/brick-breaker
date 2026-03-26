# scripts/game_over_menu.gd
# 게임오버/스테이지 클리어 메뉴. 결과에 따라 다른 메시지를 보여준다.
extends CanvasLayer

@onready var panel: Control = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var score_label: Label = $Panel/VBoxContainer/ScoreLabel
@onready var stars_container: HBoxContainer = $Panel/VBoxContainer/StarsContainer


func _ready() -> void:
	panel.visible = false


# 게임오버 화면을 표시한다.
func show_game_over() -> void:
	title_label.text = "GAME OVER"
	score_label.text = "Score: %d" % GameManager.score
	_show_stars(0)
	panel.visible = true
	get_tree().paused = true


# 스테이지 클리어 화면을 표시한다.
func show_clear() -> void:
	title_label.text = "STAGE CLEAR!"
	score_label.text = "Score: %d" % GameManager.score
	_show_stars(GameManager.lives)
	panel.visible = true
	get_tree().paused = true


# 별 개수를 표시한다.
func _show_stars(count: int) -> void:
	for child in stars_container.get_children():
		child.queue_free()
	var star_tex := preload("res://assets/images/ui/star.png")
	var star_outline_tex := preload("res://assets/images/ui/star_outline.png")
	for i in 3:
		var tex_rect := TextureRect.new()
		tex_rect.texture = star_tex if i < count else star_outline_tex
		tex_rect.custom_minimum_size = Vector2(40, 40)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		stars_container.add_child(tex_rect)


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_stage_select_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")
