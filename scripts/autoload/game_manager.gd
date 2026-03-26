# scripts/autoload/game_manager.gd
# 플레이 중 휘발성 상태를 관리한다.
# 점수, 라이프, 현재 레벨, 파워업 상태를 추적한다.
extends Node

signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal game_over
signal stage_cleared

# 점수 상수
const SCORE_1HP := 100
const SCORE_2HP := 200
const SCORE_3HP := 300
const SCORE_CLEAR_BONUS_PER_LIFE := 500

var current_level: int = 1
var score: int = 0
var lives: int = 3
var is_playing: bool = false


# 새 게임을 시작할 때 상태를 초기화한다.
func start_level(level: int) -> void:
	current_level = level
	score = 0
	lives = 3
	is_playing = true
	score_changed.emit(score)
	lives_changed.emit(lives)


# 벽돌 파괴 시 HP에 따른 점수를 추가한다.
func add_brick_score(hp: int) -> void:
	match hp:
		1: score += SCORE_1HP
		2: score += SCORE_2HP
		3: score += SCORE_3HP
	score_changed.emit(score)


# 공을 잃었을 때 라이프를 감소시킨다.
func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		is_playing = false
		game_over.emit()


# 스테이지 클리어 시 보너스 점수를 추가하고 저장한다.
func clear_stage() -> void:
	is_playing = false
	var bonus := lives * SCORE_CLEAR_BONUS_PER_LIFE
	score += bonus
	score_changed.emit(score)
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.call("complete_stage", current_level, score, lives)
	stage_cleared.emit()
