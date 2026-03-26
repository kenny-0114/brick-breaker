# scripts/objects/ball.gd
# 턴제 벽돌깨기의 공. 일정 속도로 직선 이동하고 벽/벽돌에 반사된다.
# 물리 엔진 반사 대신 충돌 노멀 기반 수동 반사로 결정적 동작을 보장한다.
extends RigidBody2D

const MIN_ANGLE_RAD := deg_to_rad(15.0)
const MAX_ANGLE_RAD := deg_to_rad(165.0)
const TRAIL_MIN := 12
const TRAIL_MAX := 35

var _target_speed := 400.0
var _is_active := false
var _trail: Line2D


func _ready() -> void:
	_trail = Line2D.new()
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


# 공의 속도를 설정한다.
func setup(speed: float) -> void:
	_target_speed = speed
	_is_active = false
	freeze = true


# 지정된 방향으로 공을 발사한다.
func launch(direction: Vector2) -> void:
	_is_active = true
	freeze = false
	linear_velocity = direction.normalized() * _target_speed


func _physics_process(_delta: float) -> void:
	if not _is_active:
		return
	_update_trail()


# 충돌 시 노멀 벡터로 수동 반사를 계산한다.
func _on_body_entered(body: Node) -> void:
	if body.has_method("hit"):
		body.hit()
	# 충돌 노멀을 구해 반사 방향을 직접 계산한다.
	var collision_normal := _get_collision_normal(body)
	if collision_normal == Vector2.ZERO:
		return
	var vel := linear_velocity
	var reflected := vel.bounce(collision_normal)
	reflected = reflected.normalized() * _target_speed
	reflected = _clamp_angle(reflected)
	linear_velocity = reflected


# 충돌 대상과의 노멀 벡터를 계산한다.
func _get_collision_normal(body: Node) -> Vector2:
	var space_state := get_world_2d().direct_space_state
	var body_pos: Vector2 = body.get("global_position") as Vector2
	var dir: Vector2 = (body_pos - global_position).normalized()
	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + dir * 50.0,
		collision_mask, [get_rid()]
	)
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		# Raycast 실패 시 위치 기반 근사 노멀 계산
		return -(body_pos - global_position).normalized()
	return result["normal"]


# 너무 수평에 가까운 각도를 보정한다.
func _clamp_angle(vel: Vector2) -> Vector2:
	var speed := vel.length()
	if speed < 1.0:
		return vel
	var dir := vel / speed
	var angle := absf(dir.angle_to(Vector2.UP))
	if angle < MIN_ANGLE_RAD:
		var sign_x: float = signf(dir.x) if dir.x != 0.0 else 1.0
		dir.x = abs(dir.y) * tan(MIN_ANGLE_RAD) * sign_x
		dir = dir.normalized()
	elif angle > MAX_ANGLE_RAD:
		var sign_y: float = signf(dir.y) if dir.y != 0.0 else -1.0
		dir.y = abs(dir.x) * tan(MIN_ANGLE_RAD) * sign_y
		dir = dir.normalized()
	return dir * _target_speed


# 속도에 비례하여 트레일 길이를 조절한다.
func _update_trail() -> void:
	_trail.add_point(global_position)
	var speed_ratio := clampf(linear_velocity.length() / 800.0, 0.0, 1.0)
	var trail_len: int = int(lerpf(TRAIL_MIN, TRAIL_MAX, speed_ratio))
	while _trail.get_point_count() > trail_len:
		_trail.remove_point(0)


func is_active() -> bool:
	return _is_active
