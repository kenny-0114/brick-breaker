# scripts/objects/launcher.gd
# 조준선을 표시하고 공을 연사로 발사한다.
# 터치 드래그로 방향을 조준하고, 터치를 떼면 발사한다.
extends Node2D

signal all_balls_fired
signal aiming_started
signal aiming_ended

const FIRE_INTERVAL := 0.05
const MIN_AIM_ANGLE := deg_to_rad(10.0)
const MAX_AIM_ANGLE := deg_to_rad(170.0)
const AIM_LINE_LENGTH := 1200.0
const AIM_LINE_DASH := 8.0
const AIM_LINE_GAP := 6.0

var _is_aiming := false
var _aim_direction := Vector2.UP
var _balls_to_fire: int = 0
var _ball_scene: PackedScene = null
var _ball_speed: float = 400.0
var _ball_container: Node2D = null

@onready var aim_line: Line2D = $AimLine
@onready var launch_point: Marker2D = $LaunchPoint
@onready var fire_timer: Timer = $FireTimer


func _ready() -> void:
	aim_line.visible = false
	fire_timer.wait_time = FIRE_INTERVAL
	fire_timer.one_shot = false
	fire_timer.timeout.connect(_on_fire_timer_timeout)


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
	aim_line.visible = false
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


# 조준 방향을 갱신한다. 터치 위치의 반대 방향으로 조준선을 표시한다.
func _update_aim(touch_pos: Vector2) -> void:
	if not _is_aiming:
		return
	var launch_global := launch_point.global_position
	var raw_dir := (launch_global - touch_pos).normalized()
	# 위쪽 방향만 허용 (y < 0)
	if raw_dir.y >= 0:
		raw_dir = Vector2(-signf(raw_dir.x) if raw_dir.x != 0.0 else -1.0, -0.01).normalized()
	# 각도 제한
	var angle := raw_dir.angle_to(Vector2.UP)
	if absf(angle) > MAX_AIM_ANGLE * 0.5:
		var clamped := signf(angle) * MAX_AIM_ANGLE * 0.5
		raw_dir = Vector2.UP.rotated(clamped)
	_aim_direction = raw_dir
	_draw_aim_line(launch_global)


# 점선 조준선을 그린다.
func _draw_aim_line(from: Vector2) -> void:
	aim_line.clear_points()
	aim_line.visible = true
	var step := AIM_LINE_DASH + AIM_LINE_GAP
	var total := AIM_LINE_LENGTH
	var pos := from
	var drawn := 0.0
	while drawn < total:
		var end := pos + _aim_direction * AIM_LINE_DASH
		aim_line.add_point(pos - global_position)
		aim_line.add_point(end - global_position)
		pos = end + _aim_direction * AIM_LINE_GAP
		drawn += step


# 조준을 해제하고 발사를 시작한다.
func _release_aim() -> void:
	if not _is_aiming:
		return
	_is_aiming = false
	aim_line.visible = false
	aiming_ended.emit()
	start_firing(GameManager.ball_count)


# 공을 연사로 발사한다.
func start_firing(ball_count: int) -> void:
	_balls_to_fire = ball_count
	disable_aiming()
	_fire_one_ball()
	if _balls_to_fire > 0:
		fire_timer.start()


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
