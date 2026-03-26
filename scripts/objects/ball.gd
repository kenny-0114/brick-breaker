# scripts/objects/ball.gd
# 물리 기반 공. 패들 위에서 대기 후 터치로 발사한다.
# 속도 클램핑과 각도 보정으로 안정적인 움직임을 보장한다.
extends RigidBody2D

signal ball_lost

const MIN_SPEED := 200.0
const MAX_SPEED := 600.0
const MIN_ANGLE_DEG := 15.0

var _is_launched := false
var _paddle: Node2D = null
var _initial_speed := 300.0


# 패들에 붙어서 대기 상태로 초기화한다.
func setup(paddle: Node2D, speed: float) -> void:
	_paddle = paddle
	_initial_speed = speed
	_is_launched = false
	freeze = true


func _physics_process(_delta: float) -> void:
	# 발사 전: 패들 위에 따라다닌다.
	if not _is_launched and _paddle:
		global_position = _paddle.global_position + Vector2(0, -30)
		return
	# 발사 후: 속도 클램핑과 각도 보정
	if _is_launched:
		_clamp_speed()
		_correct_angle()


# 터치 시 공을 발사한다. 45도 부근 랜덤 각도로 위쪽으로 쏜다.
func launch() -> void:
	if _is_launched:
		return
	_is_launched = true
	freeze = false
	var angle := randf_range(deg_to_rad(35), deg_to_rad(55))
	var direction := Vector2.UP.rotated(angle if randf() > 0.5 else -angle)
	linear_velocity = direction * _initial_speed


# 속도가 너무 느리거나 빠르지 않도록 보정한다.
func _clamp_speed() -> void:
	var speed := linear_velocity.length()
	if speed < MIN_SPEED:
		linear_velocity = linear_velocity.normalized() * MIN_SPEED
	elif speed > MAX_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_SPEED


# 수평/수직에 너무 가까운 각도를 보정하여 무한 반복을 방지한다.
func _correct_angle() -> void:
	var vel := linear_velocity
	if vel.length() < 1.0:
		return
	var angle := abs(vel.angle_to(Vector2.UP))
	var min_rad := deg_to_rad(MIN_ANGLE_DEG)
	# 수직에 너무 가까운 경우 (좌우로 살짝 틀어준다)
	if angle < min_rad:
		var sign_x := signf(vel.x) if vel.x != 0.0 else 1.0
		vel.x = abs(vel.y) * tan(min_rad) * sign_x
		linear_velocity = vel.normalized() * linear_velocity.length()
	# 수평에 너무 가까운 경우 (위아래로 살짝 틀어준다)
	elif angle > deg_to_rad(180.0 - MIN_ANGLE_DEG):
		var sign_y := signf(vel.y) if vel.y != 0.0 else -1.0
		vel.y = abs(vel.x) * tan(min_rad) * sign_y
		linear_velocity = vel.normalized() * linear_velocity.length()


func is_launched() -> bool:
	return _is_launched
