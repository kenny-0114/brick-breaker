# scripts/objects/ball.gd
# 물리 기반 공. 패들 위에서 대기 후 터치로 발사한다.
# 속도 클램핑과 각도 보정으로 안정적인 움직임을 보장한다.
extends RigidBody2D

const MIN_SPEED := 350.0
const MAX_SPEED := 800.0
const MIN_ANGLE_RAD := deg_to_rad(15.0)
const MAX_ANGLE_RAD := deg_to_rad(165.0)
const TRAIL_MIN := 12
const TRAIL_MAX := 35

var _is_launched := false
var _paddle: Node2D = null
var _initial_speed := 300.0
var _trail: Line2D


func _ready() -> void:
	_trail = Line2D.new()
	# 공 지름(14px)에서 시작해서 0으로 좁아지는 꼬리 형태
	_trail.width_curve = Curve.new()
	_trail.width_curve.add_point(Vector2(0.0, 0.0))
	_trail.width_curve.add_point(Vector2(1.0, 1.0))
	_trail.width = 14.0
	_trail.default_color = Color(0.5, 0.85, 1.0, 0.6)
	_trail.gradient = Gradient.new()
	_trail.gradient.set_color(0, Color(0.5, 0.85, 1.0, 0.0))
	_trail.gradient.set_color(1, Color(0.5, 0.85, 1.0, 0.6))
	_trail.top_level = true
	add_child(_trail)


# 패들에 붙어서 대기 상태로 초기화한다.
func setup(paddle: Node2D, speed: float) -> void:
	_paddle = paddle
	_initial_speed = speed
	_is_launched = false
	freeze = true


func _physics_process(_delta: float) -> void:
	if not _is_launched and _paddle:
		global_position = _paddle.global_position + Vector2(0, -30)
		_trail.clear_points()
		return
	if _is_launched:
		_clamp_and_correct()
		_update_trail()


# 속도에 비례하여 트레일 길이를 조절한다.
func _update_trail() -> void:
	_trail.add_point(global_position)
	var speed_ratio := clampf(linear_velocity.length() / MAX_SPEED, 0.0, 1.0)
	var trail_len: int = int(lerpf(TRAIL_MIN, TRAIL_MAX, speed_ratio))
	while _trail.get_point_count() > trail_len:
		_trail.remove_point(0)


# 외부에서 속도를 지정하여 발사 상태로 전환한다. (멀티볼용)
func launch_with_velocity(vel: Vector2) -> void:
	_is_launched = true
	freeze = false
	linear_velocity = vel


# 터치 시 공을 발사한다. 45도 부근 랜덤 각도로 위쪽으로 쏜다.
func launch() -> void:
	if _is_launched:
		return
	_is_launched = true
	freeze = false
	var angle := randf_range(deg_to_rad(35), deg_to_rad(55))
	var direction := Vector2.UP.rotated(angle if randf() > 0.5 else -angle)
	linear_velocity = direction * _initial_speed


# 속도 클램핑과 각도 보정을 한 번에 처리하여 length() 중복 계산을 방지한다.
func _clamp_and_correct() -> void:
	var vel := linear_velocity
	var speed := vel.length()
	if speed < 1.0:
		return
	speed = clampf(speed, MIN_SPEED, MAX_SPEED)
	var dir := vel / vel.length()
	var angle := absf(dir.angle_to(Vector2.UP))
	if angle < MIN_ANGLE_RAD:
		var sign_x: float = signf(dir.x) if dir.x != 0.0 else 1.0
		dir.x = abs(dir.y) * tan(MIN_ANGLE_RAD) * sign_x
		dir = dir.normalized()
	elif angle > MAX_ANGLE_RAD:
		var sign_y: float = signf(dir.y) if dir.y != 0.0 else -1.0
		dir.y = abs(dir.x) * tan(MIN_ANGLE_RAD) * sign_y
		dir = dir.normalized()
	linear_velocity = dir * speed


func is_launched() -> bool:
	return _is_launched


func _on_body_entered(body: Node) -> void:
	if body.has_method("hit"):
		body.hit()
	if body.is_in_group("paddle"):
		var hit_factor: float = body.get_hit_factor(global_position.x)
		var speed := linear_velocity.length()
		var max_angle := deg_to_rad(75.0)
		var angle := hit_factor * max_angle
		linear_velocity = Vector2(sin(angle), -cos(angle)).normalized() * speed
