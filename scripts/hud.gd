# scripts/hud.gd
# 게임 중 점수, 라이프, 레벨을 표시한다.
extends CanvasLayer

@onready var score_label: Label = $MarginContainer/HBoxContainer/ScoreLabel
@onready var level_label: Label = $MarginContainer/HBoxContainer/LevelLabel
@onready var lives_label: Label = $MarginContainer/HBoxContainer/LivesLabel
@onready var pause_button: TextureButton = $MarginContainer/HBoxContainer/PauseButton


func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	_update_level()
	_on_score_changed(GameManager.score)
	_on_lives_changed(GameManager.lives)


func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score


func _on_lives_changed(new_lives: int) -> void:
	# 하트 문자로 라이프 표시
	lives_label.text = "♥ ".repeat(new_lives)


func _update_level() -> void:
	level_label.text = "Level %d" % GameManager.current_level


# 일시정지 버튼을 눌렀을 때 PauseMenu를 토글한다.
func _on_pause_pressed() -> void:
	var pause_menu := get_parent().get_node("PauseMenu")
	if pause_menu:
		pause_menu.toggle_pause()
