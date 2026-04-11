# scripts/turn_game_scene.gd
# 턴제 벽돌깨기 메인 씬. 턴 루프, 벽돌 하강, 승리/패배 판정을 담당한다.
extends Node2D

enum State { AIMING, FIRING, WAITING, TURN_END }

const BALL_SCENE := preload("res://scenes/objects/ball.tscn")
const BRICK_SCENE := preload("res://scenes/objects/brick.tscn")
const BALL_ITEM_SCENE := preload("res://scenes/objects/ball_item.tscn")
const MISSILE_SCENE := preload("res://scenes/objects/missile.tscn")
const LASER_SHOOTER_SCENE := preload("res://scenes/objects/laser_shooter.tscn")
const CROSSHAIR_TEXTURE := preload("res://assets/images/items/effects/crosshair_red_large.png")
const MISSILE_COUNT := 5
const MISSILE_FIRE_INTERVAL := 0.05
const GRID_COLS := 10
const BRICK_MARGIN := 0.0
const GRID_TOP_OFFSET := 84.0
const DESCEND_DURATION := 0.3
const FLOOR_Y := 708.0
const SPEED_RAMP_DELAY_1 := 5.0
const SPEED_RAMP_DELAY_2 := 10.0
const SPEED_STAGE_1 := 2.0
const SPEED_STAGE_2 := 3.0

var _state: State = State.AIMING
var _waiting_elapsed := 0.0
var _remaining_bricks := 0
var _ball_speed := 400.0
var _balls_collected := 0
var _first_ball_x := 240.0
var _first_ball_landed := false
var _cell_height := 34.0
var _balls_returned := 0
var _landing_indicator: Node2D = null
var _launch_indicator: Node2D = null
var _stuck_timer: Timer = null

@onready var launcher: Node2D = $Launcher
@onready var brick_container: Node2D = $BrickContainer
@onready var item_container: Node2D = $ItemContainer
@onready var ball_container: Node2D = $BallContainer
@onready var floor_zone: Area2D = $Floor
@onready var hud := $HUD
@onready var pause_menu := $PauseMenu
@onready var game_over_menu := $GameOverMenu
@onready var shooter_container: Node2D = $ShooterContainer
@onready var speed_indicator := $SpeedIndicator


func _ready() -> void:
	GameManager.game_over.connect(_on_game_over)
	GameManager.stage_cleared.connect(_on_stage_cleared)
	floor_zone.body_entered.connect(_on_floor_body_entered)
	launcher.all_balls_fired.connect(_on_all_balls_fired)
	launcher.aiming_ended.connect(_on_aiming_ended)
	# 안전 타이머: 공이 끼였을 때 강제 회수
	_stuck_timer = Timer.new()
	_stuck_timer.wait_time = 15.0
	_stuck_timer.one_shot = true
	_stuck_timer.timeout.connect(_force_collect_balls)
	add_child(_stuck_timer)
	_load_level(GameManager.current_level)
	_start_aiming()


# 대기 중 실시간 경과를 추적하여 점진적 배속을 적용한다.
func _process(delta: float) -> void:
	if _state != State.WAITING:
		return
	# delta는 time_scale 적용 후이므로 실시간으로 환산한다.
	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0 else delta
	_waiting_elapsed += real_delta
	# 경과 시간에 따라 배속 단계를 올린다.
	var prev_scale := Engine.time_scale
	if _waiting_elapsed >= SPEED_RAMP_DELAY_2 and Engine.time_scale < SPEED_STAGE_2:
		Engine.time_scale = SPEED_STAGE_2
	elif _waiting_elapsed >= SPEED_RAMP_DELAY_1 and Engine.time_scale < SPEED_STAGE_1:
		Engine.time_scale = SPEED_STAGE_1
	# 배속이 변경되었으면 인디케이터를 갱신한다.
	if Engine.time_scale != prev_scale:
		speed_indicator.show_speed(Engine.time_scale)


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
	var cell_width := viewport_width / GRID_COLS
	var cell_height := cell_width
	_cell_height = cell_height

	# 벽돌 배치
	var cell_size := Vector2(cell_width, cell_height)
	var bricks_array: Array = data.get("bricks", []) as Array
	for brick_data: Dictionary in bricks_array:
		var brick: StaticBody2D = BRICK_SCENE.instantiate()
		var row: int = int(brick_data["row"])
		var col: int = int(brick_data["col"])
		var hp: int = int(brick_data["hp"])
		var brick_type: String = str(brick_data.get("type", "rect"))
		brick.position = Vector2(
			(col + 0.5) * cell_width,
			GRID_TOP_OFFSET + (row + 0.5) * cell_height
		)
		# 아이템 속성 파싱
		var item_type: String = str(brick_data.get("item", ""))
		brick.item = item_type
		brick_container.add_child(brick)
		if brick_type == "tri":
			# 직각삼각형 벽돌
			var dir: int = int(brick_data.get("dir", 0))
			brick.setup_triangle(hp, dir, cell_size)
		else:
			# 사각형 벽돌 — 스프라이트와 충돌체를 셀 크기에 맞게 조정한다.
			var tex_size: Vector2 = brick.sprite.texture.get_size()
			brick.sprite.scale = Vector2(cell_width / tex_size.x, cell_height / tex_size.y)
			var col_shape: CollisionShape2D = brick.get_node("CollisionShape2D")
			col_shape.shape = col_shape.shape.duplicate()
			col_shape.shape.size = Vector2(cell_width, cell_height)
			brick.setup(hp, cell_size)
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
			(col + 0.5) * cell_width,
			GRID_TOP_OFFSET + (row + 0.5) * cell_height
		)
		item_container.add_child(item)
		item.collected.connect(_on_ball_item_collected)

	# 레이저 슈터 배치
	var shooters_array: Array = data.get("laser_shooters", []) as Array
	for shooter_data: Dictionary in shooters_array:
		var shooter: Area2D = LASER_SHOOTER_SCENE.instantiate()
		var row: int = int(shooter_data["row"])
		var col: int = int(shooter_data["col"])
		var shooter_uses: int = int(shooter_data.get("uses", 10))
		var shooter_damage: int = int(shooter_data.get("damage", 1))
		var shooter_dirs: Array = shooter_data.get("dirs", [0]) as Array
		shooter.position = Vector2(
			(col + 0.5) * cell_width,
			GRID_TOP_OFFSET + (row + 0.5) * cell_height
		)
		shooter_container.add_child(shooter)
		shooter.setup(shooter_uses, shooter_damage, shooter_dirs, cell_size, brick_container)

	# Launcher 설정
	launcher.setup(BALL_SCENE, _ball_speed, ball_container)
	launcher.global_position = Vector2(0, FLOOR_Y)
	launcher.set_launch_x(_first_ball_x)


# 조준 상태로 전환한다. 콤보를 리셋한다.
func _start_aiming() -> void:
	_state = State.AIMING
	_balls_collected = 0
	_balls_returned = 0
	_first_ball_landed = false
	GameManager.reset_combo()
	_hide_landing_indicator()
	_show_launch_indicator()
	launcher.set_launch_x(_first_ball_x)
	launcher.enable_aiming()


# 조준 해제 시 발사 상태로 전환한다.
func _on_aiming_ended() -> void:
	_state = State.FIRING
	_hide_launch_indicator()


# Launcher가 모든 공을 발사 완료했을 때 호출된다.
# 발사 완료 시 자동으로 빨리감기를 활성화한다.
func _on_all_balls_fired() -> void:
	_state = State.WAITING
	_waiting_elapsed = 0.0
	Engine.time_scale = 1.0
	# 안전 타이머: 20초 실시간 (배속 올라가면 게임시간으로 더 빨리 흐름)
	_stuck_timer.wait_time = 60.0
	_stuck_timer.start()


# 공이 바닥에 닿았을 때 호출된다. 위로 올라가는 공은 무시한다.
func _on_floor_body_entered(body: Node2D) -> void:
	if not body.is_in_group("ball"):
		return
	if body is RigidBody2D and body.linear_velocity.y < 0:
		return
	# 첫 번째 공의 X 위치를 다음 턴 발사 지점으로 저장
	if not _first_ball_landed:
		_first_ball_landed = true
		_first_ball_x = clampf(body.global_position.x, 20.0, 460.0)
		_create_landing_indicator()
	# 회수 카운터 증가 및 표시 갱신
	_balls_returned += 1
	_update_landing_indicator()
	# 공을 바닥 라인에서 수평 이동 후 제거
	var tween := create_tween()
	body.freeze = true
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
	Engine.time_scale = 1.0
	speed_indicator.show_speed(1.0)
	_stuck_timer.stop()
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
	if brick_container.get_child_count() == 0 and item_container.get_child_count() == 0 and shooter_container.get_child_count() == 0:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	for brick in brick_container.get_children():
		tween.tween_property(brick, "position:y", brick.position.y + _cell_height, DESCEND_DURATION)
	# 공 아이템도 함께 하강
	for item in item_container.get_children():
		tween.tween_property(item, "position:y", item.position.y + _cell_height, DESCEND_DURATION)
	# 레이저 슈터도 함께 하강
	for shooter in shooter_container.get_children():
		tween.tween_property(shooter, "position:y", shooter.position.y + _cell_height, DESCEND_DURATION)
	await tween.finished


# 벽돌이 발사 라인에 도달했는지 확인한다.
func _check_game_over() -> bool:
	for brick in brick_container.get_children():
		if brick.position.y >= FLOOR_Y - _cell_height:
			return true
	return false


# 벽돌 파괴 시 호출된다. 점수를 추가하고 아이템 효과를 발동한다.
func _on_brick_destroyed(pos: Vector2, item: String = "") -> void:
	_remaining_bricks -= 1
	var points := GameManager.add_brick_score()
	_spawn_particles(pos)
	_spawn_score_popup(pos, points, GameManager.combo)
	# 미사일 아이템 발동
	if item == "missile":
		_activate_missile(pos)
	if _remaining_bricks <= 0 and (_state == State.WAITING or _state == State.FIRING):
		_recall_all_balls.call_deferred()


# 미사일 아이템을 발동한다. 랜덤 벽돌에 락온 후 미사일을 순차 발사한다.
func _activate_missile(origin_pos: Vector2) -> void:
	# 파괴 가능 벽돌 중 랜덤 최대 5개 선택
	var targets: Array = _select_missile_targets()
	if targets.is_empty():
		return

	# 락온 마커 표시
	for i in range(targets.size()):
		var target: StaticBody2D = targets[i]
		_spawn_lockon_marker(target, i * 0.06)

	# 미사일 순차 발사
	for i in range(targets.size()):
		var target: StaticBody2D = targets[i]
		_spawn_missile(origin_pos, target, i * MISSILE_FIRE_INTERVAL + 0.1)


# 파괴 가능 벽돌 중 랜덤으로 최대 MISSILE_COUNT개를 선택한다.
func _select_missile_targets() -> Array:
	var candidates: Array = []
	for brick in brick_container.get_children():
		if brick.hp > 0 and brick.hp != -1 and not brick._is_destroyed:
			candidates.append(brick)
	candidates.shuffle()
	return candidates.slice(0, MISSILE_COUNT)


# 타겟 벽돌 위에 락온 마커를 표시한다. 스케일 펀치 + 회전 애니메이션.
func _spawn_lockon_marker(target: Node2D, delay: float) -> void:
	var marker := Sprite2D.new()
	marker.texture = CROSSHAIR_TEXTURE
	marker.scale = Vector2.ZERO
	marker.z_index = 60
	# 셀 크기에 맞게 마커 크기 조절
	var tex_size: Vector2 = CROSSHAIR_TEXTURE.get_size()
	var target_scale: float = _cell_height * 1.2 / tex_size.x
	brick_container.get_parent().add_child(marker)
	marker.global_position = target.global_position

	# 지연 후 스케일 펀치 등장 + 회전
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(marker, "scale", Vector2(target_scale, target_scale), 0.15)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# 지속 회전
	tween.tween_property(marker, "rotation_degrees", 360.0, 2.0)
	# 0.8초 후 자동 소멸
	var cleanup_tween := create_tween()
	cleanup_tween.tween_interval(delay + 0.8)
	cleanup_tween.tween_property(marker, "modulate:a", 0.0, 0.15)
	cleanup_tween.tween_callback(marker.queue_free)


# 지연 후 미사일을 발사한다.
func _spawn_missile(origin: Vector2, target: StaticBody2D, delay: float) -> void:
	var missile: Node2D = MISSILE_SCENE.instantiate()
	missile.global_position = origin
	missile.setup(target, target.global_position)
	add_child(missile)

	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(missile.launch)


# 스테이지 클리어 시 모든 공을 즉시 회수 지점으로 직선 이동시킨다.
func _recall_all_balls() -> void:
	_stuck_timer.stop()
	launcher.fire_timer.stop()
	# 첫 번째 착지 기록이 없으면 현재 위치 기준으로 설정
	if not _first_ball_landed:
		_first_ball_landed = true
		if ball_container.get_child_count() > 0:
			_first_ball_x = clampf(ball_container.get_child(0).global_position.x, 20.0, 460.0)
	var target := Vector2(_first_ball_x, FLOOR_Y)
	var balls := ball_container.get_children().duplicate()
	if balls.is_empty():
		return
	# 바닥 감지 방지를 위해 그룹 제거 후 물리 정지
	for ball in balls:
		ball.remove_from_group("ball")
		ball.freeze = true
	# 모든 공을 동시에 회수 지점으로 직선 이동
	var tween := create_tween().set_parallel(true)
	for ball in balls:
		tween.tween_property(ball, "global_position", target, 0.15)
	await tween.finished
	# 공 제거 후 턴 종료
	for ball in balls:
		if is_instance_valid(ball):
			ball.queue_free()
	await get_tree().process_frame
	if _state == State.WAITING or _state == State.FIRING:
		_end_turn()


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
	particles.texture = preload("res://assets/images/bricks/tile_brick_white.png")
	add_child(particles)
	particles.finished.connect(particles.queue_free)


# 블럭 파괴 위치에 점수 팝업을 표시한다. 콤보가 높을수록 크고 밝다.
func _spawn_score_popup(pos: Vector2, points: int, combo: int) -> void:
	var label := Label.new()
	label.text = "+%d" % points
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = pos - Vector2(30, 15)
	label.size = Vector2(60, 30)
	# 콤보에 따라 크기와 색상 변화
	var font_size := clampi(14 + combo * 2, 14, 28)
	var color := Color(1.0, 1.0, 1.0)
	if combo >= 10:
		color = Color(1.0, 0.3, 0.3)  # 빨강
	elif combo >= 5:
		color = Color(1.0, 0.65, 0.15)  # 주황
	elif combo >= 3:
		color = Color(1.0, 0.85, 0.2)  # 노랑
	label.add_theme_font_override("font", preload("res://assets/fonts/Kenney Future.ttf"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	# 위로 떠오르며 사라짐
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 50, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)


# 발사 지점에 공 아이콘과 개수를 표시한다.
func _show_launch_indicator() -> void:
	_hide_launch_indicator()
	_launch_indicator = Node2D.new()
	_launch_indicator.z_index = 100
	_launch_indicator.position = Vector2(_first_ball_x, FLOOR_Y)
	var icon := Sprite2D.new()
	icon.texture = preload("res://assets/images/ball/ball_blue_large.png")
	icon.scale = Vector2(0.24, 0.24)
	icon.position = Vector2(0, -10)
	_launch_indicator.add_child(icon)
	var label := Label.new()
	label.name = "CountLabel"
	label.text = "x%d" % GameManager.ball_count
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-25, -32)
	label.size = Vector2(50, 20)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 3)
	_launch_indicator.add_child(label)
	add_child(_launch_indicator)


# 발사 지점 인디케이터를 제거한다.
func _hide_launch_indicator() -> void:
	if _launch_indicator != null:
		_launch_indicator.queue_free()
		_launch_indicator = null


# 공 착지 지점에 인디케이터(공 아이콘 + 회수 카운트)를 생성한다.
func _create_landing_indicator() -> void:
	_landing_indicator = Node2D.new()
	_landing_indicator.z_index = 100
	_landing_indicator.position = Vector2(_first_ball_x, FLOOR_Y)
	var icon := Sprite2D.new()
	icon.texture = preload("res://assets/images/ball/ball_blue_large.png")
	icon.scale = Vector2(0.24, 0.24)
	icon.position = Vector2(0, -10)
	_landing_indicator.add_child(icon)
	var label := Label.new()
	label.name = "CountLabel"
	label.text = "x1"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-25, -32)
	label.size = Vector2(50, 20)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 3)
	_landing_indicator.add_child(label)
	add_child(_landing_indicator)


# 인디케이터의 카운트를 갱신한다.
func _update_landing_indicator() -> void:
	if _landing_indicator == null:
		return
	var label: Label = _landing_indicator.get_node("CountLabel")
	if label:
		label.text = "x%d" % _balls_returned


# 인디케이터를 숨기고 제거한다.
func _hide_landing_indicator() -> void:
	if _landing_indicator != null:
		_landing_indicator.queue_free()
		_landing_indicator = null


# 안전 타이머 만료 시 남은 공을 강제 회수한다.
func _force_collect_balls() -> void:
	for ball in ball_container.get_children():
		ball.queue_free()
	# 다음 프레임에서 턴 종료 처리
	await get_tree().process_frame
	if _state == State.WAITING or _state == State.FIRING:
		_end_turn()


func _on_game_over() -> void:
	Engine.time_scale = 1.0
	speed_indicator.show_speed(1.0)
	await get_tree().create_timer(0.5).timeout
	game_over_menu.show_game_over()


func _on_stage_cleared() -> void:
	Engine.time_scale = 1.0
	speed_indicator.show_speed(1.0)
	await get_tree().create_timer(0.5).timeout
	game_over_menu.show_clear()
