# scripts/autoload/game_manager.gd
# 턴제 게임의 휘발성 상태를 관리한다.
# 턴 수, 공 개수, 현재 레벨을 추적한다.
extends Node

signal turn_changed(new_turn: int)
signal ball_count_changed(new_count: int)
signal game_over
signal stage_cleared

var current_level: int = 1
var turn_count: int = 0
var ball_count: int = 1
var is_playing: bool = false
var _star_thresholds: Array = [20, 15, 10]


# 새 레벨을 시작할 때 상태를 초기화한다.
func start_level(level: int, initial_balls: int, star_thresholds: Array) -> void:
	current_level = level
	turn_count = 0
	ball_count = initial_balls
	_star_thresholds = star_thresholds
	is_playing = true
	turn_changed.emit(turn_count)
	ball_count_changed.emit(ball_count)


# 턴 종료 시 턴 카운터를 증가시킨다.
func advance_turn() -> void:
	turn_count += 1
	turn_changed.emit(turn_count)


# 공 아이템 수집 시 공 개수를 증가시킨다.
func add_balls(count: int) -> void:
	ball_count += count
	ball_count_changed.emit(ball_count)


# 턴 수 기준으로 별 개수를 계산한다.
# star_thresholds = [1성 기준, 2성 기준, 3성 기준] (턴 수 이하면 획득)
func _calculate_stars() -> int:
	if _star_thresholds.is_empty():
		return 0
	var stars := 0
	for i in _star_thresholds.size():
		if turn_count <= int(_star_thresholds[i]):
			stars = i + 1
	return stars


# 스테이지 클리어 시 결과를 저장한다.
func clear_stage() -> void:
	is_playing = false
	var stars := _calculate_stars()
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.call("complete_stage", current_level, turn_count, stars)
	stage_cleared.emit()


# 벽돌이 발사 라인에 도달하면 게임오버를 발생시킨다.
func trigger_game_over() -> void:
	is_playing = false
	game_over.emit()
