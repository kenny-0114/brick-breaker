# scripts/objects/launcher.gd
# 조준선을 표시하고 공을 연사로 발사한다.
# 터치 드래그로 방향을 조준하고, 터치를 떼면 발사한다.
# 가이드라인은 공 이미지 점선으로 1회 바운스 경로를 표시한다.
extends Node2D

signal all_balls_fired
signal aiming_started
signal aiming_ended

const FIRE_INTERVAL := 0.05
const MIN_AIM_ANGLE := deg_to_rad(10.0)
const MAX_AIM_ANGLE := deg_to_rad(170.0)
const DOT_SPACING := 20.0
const DOT_SCALE := Vector2(0.06, 0.06)
const MAX_DOTS := 60
const RAY_LENGTH := 2000.0

var _is_aiming := false
var _aim_direction := Vector2.UP
var _balls_to_fire: int = 0
var _ball_scene: PackedScene = null
var _ball_speed: float = 400.0
var _ball_container: Node2D = null
var _dot_pool: Array[Sprite2D] = []
var _ball_texture: Texture2D = preload("res://assets/images/ball/ballBlue_01.png")

@onready var launch_point: Marker2D = $LaunchPoint
@onready var fire_timer: Timer = $FireTimer


func _ready() -> void:
	fire_timer.wait_time = FIRE_INTERVAL
	fire_timer.one_shot = false
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	# 점 스프라이트 풀을 미리 생성한다.
	for i in MAX_DOTS:
		var dot := Sprite2D.new()
		dot.texture = _ball_texture
		dot.scale = DOT_SCALE
		dot.visible = false
		dot.modulate = Color(1, 1, 1, 0.5)
		add_child(dot)
		_dot_pool.append(dot)


# 발사에 필요한 참조를 설정한다.
func setup(ball_scene: PackedScene, ball_speed: float, ball_container: Node2D) -> void:
	_ball_scene = ball_scene
	_ball_speed = ball_speed
	_ball_container = ball_container


# 발사 지점의 X 위치를 변경한다.
func set_launch_x(x: float) -> void:
	launch_point.position.x = x - global_position.x


# 조준 입력을 활성화한다.
func enable_aiming() -> void:
	_is_aiming = false
	set_process_input(true)


# 조준 입력을 비활성화한다.
func disable_aiming() -> void:
	_is_aiming = false
	_hide_dots()
	set_process_input(false)


func _input(event: InputEvent) -> void:
	# 터치/마우스 시작
	if event is InputEventScreenTouch and event.pressed:
		_start_aiming(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_start_aiming(event.position)
	# 터치/마우스 드래그
	elif event is InputEventScreenDrag:
		_update_aim(event.position)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_aim(event.position)
	# 터치/마우스 해제 — 발사
	elif event is InputEventScreenTouch and not event.pressed:
		_release_aim()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_release_aim()


# 조준을 시작한다.
func _start_aiming(touch_pos: Vector2) -> void:
	_is_aiming = true
	_update_aim(touch_pos)
	aiming_started.emit()


# 조준 방향을 갱신한다. 터치 위치 방향으로 조준선을 표시한다.
func _update_aim(touch_pos: Vector2) -> void:
	if not _is_aiming:
		return
	var launch_global := launch_point.global_position
	var raw_dir := (touch_pos - launch_global).normalized()
	# 위쪽 방향만 허용 (y < 0)
	if raw_dir.y >= 0:
		raw_dir = Vector2(signf(raw_dir.x) if raw_dir.x != 0.0 else 1.0, -0.01).normalized()
	# 각도 제한
	var angle := raw_dir.angle_to(Vector2.UP)
	if absf(angle) > MAX_AIM_ANGLE * 0.5:
		var clamped := signf(angle) * MAX_AIM_ANGLE * 0.5
		raw_dir = Vector2.UP.rotated(clamped)
	_aim_direction = raw_dir
	_draw_dotted_guide(launch_global)


# Raycast로 1회 바운스 경로를 계산하고 점 이미지로 가이드라인을 그린다.
func _draw_dotted_guide(from: Vector2) -> void:
	_hide_dots()
	var space_state := get_world_2d().direct_space_state
	var dot_index := 0

	# 1구간: 발사 지점 → 첫 충돌
	var ray_from := from
	var ray_dir := _aim_direction
	var hit := _cast_ray(space_state, ray_from, ray_dir)

	var first_end: Vector2
	var bounce_normal: Vector2
	if hit.is_empty():
		first_end = ray_from + ray_dir * RAY_LENGTH
		bounce_normal = Vector2.ZERO
	else:
		first_end = hit["position"] as Vector2
		bounce_normal = hit["normal"] as Vector2

	dot_index = _place_dots_along(ray_from, first_end, dot_index)

	# 2구간: 바운스 후 경로 (충돌이 있었을 경우만)
	if bounce_normal != Vector2.ZERO and dot_index < MAX_DOTS:
		var bounce_dir := ray_dir.bounce(bounce_normal).normalized()
		var second_hit := _cast_ray(space_state, first_end + bounce_dir * 2.0, bounce_dir)
		var second_end: Vector2
		if second_hit.is_empty():
			second_end = first_end + bounce_dir * RAY_LENGTH
		else:
			second_end = second_hit["position"] as Vector2
		dot_index = _place_dots_along(first_end, second_end, dot_index)


# 두 점 사이에 DOT_SPACING 간격으로 점 스프라이트를 배치한다.
func _place_dots_along(from: Vector2, to: Vector2, start_index: int) -> int:
	var direction := (to - from).normalized()
	var total_dist := from.distance_to(to)
	var dist := 0.0
	var idx := start_index
	while dist < total_dist and idx < MAX_DOTS:
		var pos := from + direction * dist
		_dot_pool[idx].global_position = pos
		_dot_pool[idx].visible = true
		idx += 1
		dist += DOT_SPACING
	return idx


# 물리 Raycast를 실행한다.
func _cast_ray(space_state: PhysicsDirectSpaceState2D, from: Vector2, dir: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, from + dir * RAY_LENGTH, 1)
	return space_state.intersect_ray(query)


# 모든 점을 숨긴다.
func _hide_dots() -> void:
	for dot in _dot_pool:
		dot.visible = false


# 조준을 해제하고 발사를 시작한다.
func _release_aim() -> void:
	if not _is_aiming:
		return
	_is_aiming = false
	_hide_dots()
	aiming_ended.emit()
	start_firing(GameManager.ball_count)


# 공을 연사로 발사한다.
func start_firing(ball_count: int) -> void:
	_balls_to_fire = ball_count
	disable_aiming()
	_fire_one_ball()
	if _balls_to_fire > 0:
		fire_timer.start()
	else:
		all_balls_fired.emit()


# 공을 하나 생성하여 발사한다.
func _fire_one_ball() -> void:
	if _ball_scene == null or _ball_container == null:
		return
	var ball: RigidBody2D = _ball_scene.instantiate()
	_ball_container.add_child(ball)
	ball.global_position = launch_point.global_position
	ball.setup(_ball_speed)
	ball.launch(_aim_direction)
	_balls_to_fire -= 1


# 타이머 콜백. 남은 공이 있으면 하나 더 발사한다.
func _on_fire_timer_timeout() -> void:
	if _balls_to_fire <= 0:
		fire_timer.stop()
		all_balls_fired.emit()
		return
	_fire_one_ball()
