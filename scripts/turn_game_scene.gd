# scripts/turn_game_scene.gd
# 턴제 벽돌깨기 메인 씬. 턴 루프, 벽돌 하강, 승리/패배 판정을 담당한다.
extends Node2D

enum State { AIMING, FIRING, WAITING, TURN_END }

const BALL_SCENE := preload("res://scenes/objects/ball.tscn")
const BRICK_SCENE := preload("res://scenes/objects/brick.tscn")
const BALL_ITEM_SCENE := preload("res://scenes/objects/ball_item.tscn")
const BRICK_TEXTURES := {
	"green": preload("res://assets/images/bricks/tileGreen_14.png"),
	"orange": preload("res://assets/images/bricks/tileOrange_14.png"),
	"red": preload("res://assets/images/bricks/tileRed_14.png"),
}
const DEBRIS_TEXTURES := {
	"green": preload("res://assets/images/bricks/tileGreen_01.png"),
	"orange": preload("res://assets/images/bricks/tileOrange_27.png"),
	"red": preload("res://assets/images/bricks/tileRed_01.png"),
}

const GRID_COLS := 7
const BRICK_MARGIN := 4.0
const GRID_TOP_OFFSET := 80.0
const DESCEND_AMOUNT := 36.0
const DESCEND_DURATION := 0.3
const FLOOR_Y := 800.0

var _state: State = State.AIMING
var _remaining_bricks := 0
var _ball_speed := 400.0
var _balls_collected := 0
var _first_ball_x := 240.0
var _first_ball_landed := false
var _active_ball_count := 0

@onready var launcher: Node2D = $Launcher
@onready var brick_container: Node2D = $BrickContainer
@onready var item_container: Node2D = $ItemContainer
@onready var ball_container: Node2D = $BallContainer
@onready var floor_zone: Area2D = $Floor
@onready var hud := $HUD
@onready var pause_menu := $PauseMenu
@onready var game_over_menu := $GameOverMenu


func _ready() -> void:
	GameManager.game_over.connect(_on_game_over)
	GameManager.stage_cleared.connect(_on_stage_cleared)
	floor_zone.body_entered.connect(_on_floor_body_entered)
	launcher.all_balls_fired.connect(_on_all_balls_fired)
	_load_level(GameManager.current_level)
	_start_aiming()


# JSON에서 레벨 데이터를 읽어 벽돌과 공 아이템을 배치한다.
func _load_level(level: int) -> void:
	var path := "res://data/levels/level_%d.json" % level
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("TurnGameScene: Level file not found: %s" % path)
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("TurnGameScene: Failed to parse level JSON: %s" % json.get_error_message())
		return
	var data: Dictionary = json.data

	_ball_speed = float(data.get("ball_speed", 400.0))
	var initial_balls: int = int(data.get("initial_balls", 1))
	var star_thresholds: Array = data.get("star_thresholds", [20, 15, 10]) as Array

	GameManager.start_level(level, initial_balls, star_thresholds)
	_remaining_bricks = 0
	_first_ball_x = 240.0

	var viewport_width := get_viewport_rect().size.x
	var brick_width := (viewport_width - BRICK_MARGIN * (GRID_COLS + 1)) / GRID_COLS

	# 벽돌 배치
	var bricks_array: Array = data.get("bricks", []) as Array
	for brick_data: Dictionary in bricks_array:
		var brick: StaticBody2D = BRICK_SCENE.instantiate()
		var row: int = int(brick_data["row"])
		var col: int = int(brick_data["col"])
		var hp: int = int(brick_data["hp"])
		brick.position = Vector2(
			BRICK_MARGIN + col * (brick_width + BRICK_MARGIN) + brick_width * 0.5,
			GRID_TOP_OFFSET + row * (brick_width * 0.5 + BRICK_MARGIN)
		)
		brick_container.add_child(brick)
		brick.setup(hp)
		if hp != -1:
			_remaining_bricks += 1
			brick.brick_destroyed.connect(_on_brick_destroyed)

	# 공 아이템 배치
	var items_array: Array = data.get("ball_items", []) as Array
	for item_data: Dictionary in items_array:
		var item: Area2D = BALL_ITEM_SCENE.instantiate()
		var row: int = int(item_data["row"])
		var col: int = int(item_data["col"])
		item.position = Vector2(
			BRICK_MARGIN + col * (brick_width + BRICK_MARGIN) + brick_width * 0.5,
			GRID_TOP_OFFSET + row * (brick_width * 0.5 + BRICK_MARGIN)
		)
		item_container.add_child(item)
		item.collected.connect(_on_ball_item_collected)

	# Launcher 설정
	launcher.setup(BALL_SCENE, _ball_speed, ball_container)
	launcher.global_position = Vector2(0, FLOOR_Y)
	launcher.set_launch_x(_first_ball_x)


# 조준 상태로 전환한다.
func _start_aiming() -> void:
	_state = State.AIMING
	_balls_collected = 0
	_first_ball_landed = false
	_active_ball_count = 0
	launcher.set_launch_x(_first_ball_x)
	launcher.enable_aiming()


# Launcher가 모든 공을 발사 완료했을 때 호출된다.
func _on_all_balls_fired() -> void:
	_state = State.WAITING
	_active_ball_count = ball_container.get_child_count()


# 공이 바닥에 닿았을 때 호출된다.
func _on_floor_body_entered(body: Node2D) -> void:
	if not body.is_in_group("ball"):
		return
	# 첫 번째 공의 X 위치를 다음 턴 발사 지점으로 저장
	if not _first_ball_landed:
		_first_ball_landed = true
		_first_ball_x = clampf(body.global_position.x, 20.0, 460.0)
	# 공을 발사 지점으로 이동 후 제거
	var tween := create_tween()
	body.freeze = true
	body.set_deferred("linear_velocity", Vector2.ZERO)
	tween.tween_property(body, "global_position", Vector2(_first_ball_x, FLOOR_Y), 0.15)
	tween.tween_callback(body.queue_free)
	# 모든 공이 회수되었는지 다음 프레임에서 확인
	tween.tween_callback(_check_all_balls_returned)


# 모든 공이 회수되었는지 확인한다.
func _check_all_balls_returned() -> void:
	# 아직 날아다니는 공이 있으면 대기
	await get_tree().process_frame
	if ball_container.get_child_count() > 0:
		return
	if _state == State.WAITING or _state == State.FIRING:
		_end_turn()


# 턴을 종료한다: 벽돌 하강, 게임오버/클리어 체크, 아이템 정산.
func _end_turn() -> void:
	_state = State.TURN_END
	GameManager.advance_turn()

	# 벽돌 하강
	await _descend_bricks()

	# 게임오버 체크 — 벽돌이 발사 라인에 도달했는지
	if _check_game_over():
		GameManager.trigger_game_over()
		return

	# 클리어 체크
	if _remaining_bricks <= 0:
		GameManager.clear_stage()
		return

	# 공 아이템 정산
	if _balls_collected > 0:
		GameManager.add_balls(_balls_collected)

	# 다음 턴
	_start_aiming()


# 모든 벽돌을 한 칸 아래로 이동시킨다.
func _descend_bricks() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	for brick in brick_container.get_children():
		tween.tween_property(brick, "position:y", brick.position.y + DESCEND_AMOUNT, DESCEND_DURATION)
	# 공 아이템도 함께 하강
	for item in item_container.get_children():
		tween.tween_property(item, "position:y", item.position.y + DESCEND_AMOUNT, DESCEND_DURATION)
	await tween.finished


# 벽돌이 발사 라인에 도달했는지 확인한다.
func _check_game_over() -> bool:
	for brick in brick_container.get_children():
		if brick.position.y >= FLOOR_Y - DESCEND_AMOUNT:
			return true
	return false


# 벽돌 파괴 시 호출된다.
func _on_brick_destroyed(pos: Vector2) -> void:
	_remaining_bricks -= 1
	_spawn_particles(pos)


# 공 아이템 수집 시 호출된다.
func _on_ball_item_collected() -> void:
	_balls_collected += 1


# 벽돌 파괴 파티클을 생성한다.
func _spawn_particles(pos: Vector2) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 120.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 120.0
	mat.gravity = Vector3(0, 300, 0)
	mat.scale_min = 0.06
	mat.scale_max = 0.12
	mat.angular_velocity_min = -200.0
	mat.angular_velocity_max = 200.0
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(25, 8, 0)
	var particles := GPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 6
	particles.lifetime = 0.6
	particles.process_material = mat
	particles.texture = preload("res://assets/images/bricks/tileGreen_01.png")
	add_child(particles)
	particles.finished.connect(particles.queue_free)


func _on_game_over() -> void:
	game_over_menu.show_game_over()


func _on_stage_cleared() -> void:
	game_over_menu.show_clear()
