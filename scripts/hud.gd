# scripts/hud.gd
# 게임 중 상단 HUD를 표시한다. 턴, 점수(별 아이콘), 공 개수.
extends CanvasLayer

@onready var turn_label: Label = $MarginContainer/HBoxContainer/TurnLabel
@onready var score_label: Label = $MarginContainer/HBoxContainer/LevelLabel
@onready var balls_label: Label = $MarginContainer/HBoxContainer/BallsLabel
@onready var pause_button: Button = $MarginContainer/HBoxContainer/PauseButton


func _ready() -> void:
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.ball_count_changed.connect(_on_ball_count_changed)
	GameManager.score_changed.connect(_on_score_changed)
	_on_turn_changed(GameManager.turn_count)
	_on_ball_count_changed(GameManager.ball_count)
	_on_score_changed(GameManager.score)


func _on_turn_changed(new_turn: int) -> void:
	turn_label.text = "T:%d" % new_turn


func _on_ball_count_changed(new_count: int) -> void:
	balls_label.text = "x%d" % new_count


func _on_score_changed(new_score: int) -> void:
	score_label.text = "%d" % new_score


# 일시정지 버튼을 눌렀을 때 PauseMenu를 토글한다.
func _on_pause_pressed() -> void:
	var pause_menu: Node = get_parent().get_node("PauseMenu")
	if pause_menu:
		pause_menu.toggle_pause()
