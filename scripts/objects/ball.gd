# scripts/objects/ball.gd
# 턴제 벽돌깨기의 공. 일정 속도로 직선 이동하고 벽/벽돌에 반사된다.
# 물리 엔진(bounce=1.0)이 반사를 처리하고, 충돌 후 속도 정규화와 각도 보정만 수행한다.
extends RigidBody2D

const MIN_ANGLE_RAD := deg_to_rad(8.0)
# 수평에서 최소 기울기. 조준 한계(수평 위 5°)와 같아서 정상 발사 궤적은 바꾸지 않는다.
const MIN_HORIZONTAL_ANGLE_RAD := deg_to_rad(5.0)
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
	# 매 프레임 속도를 목표 속도로 유지한다. 물리 충돌로 감속된 공을 복구한다.
	var speed := linear_velocity.length()
	if speed > 0.1 and speed != _target_speed:
		linear_velocity = linear_velocity.normalized() * _target_speed
	elif speed <= 0.1 and _is_active:
		# 완전히 멈춘 공을 마지막 방향 또는 아래로 밀어준다.
		linear_velocity = Vector2(0, 1) * _target_speed
	_update_trail()


# 충돌 후 속도를 정규화하고 극단적 각도를 보정한다.
func _on_body_entered(body: Node) -> void:
	if body.has_method("hit"):
		body.hit()
		SoundManager.play_sfx(SoundManager.sfx_ball_hit)
	# 물리 엔진이 반사한 뒤 다음 프레임에서 속도를 보정한다.
	_correct_velocity.call_deferred()


# 무한 바운스를 만드는 극단적 각도를 보정한다.
# - 수직에 가까운 상향: 천장과 바닥 사이를 같은 자리에서 오가지 않도록 옆으로 튼다.
# - 수평에 가까운 이동: 좌우 벽 사이를 거의 내려오지 않고 왕복하지 않도록 위아래로 튼다.
func _correct_velocity() -> void:
	var vel := linear_velocity
	var speed := vel.length()
	if speed < 1.0:
		return
	var dir := vel / speed
	var angle_from_up := absf(dir.angle_to(Vector2.UP))
	if angle_from_up < MIN_ANGLE_RAD:
		var sign_x: float = signf(dir.x) if dir.x != 0.0 else 1.0
		dir = Vector2(sin(MIN_ANGLE_RAD) * sign_x, -cos(MIN_ANGLE_RAD))
	elif absf(dir.y) < sin(MIN_HORIZONTAL_ANGLE_RAD):
		# 완전 수평이면 바닥 쪽(아래)으로 틀어 회수를 앞당긴다.
		var sign_x: float = signf(dir.x) if dir.x != 0.0 else 1.0
		var sign_y: float = signf(dir.y) if dir.y != 0.0 else 1.0
		dir = Vector2(cos(MIN_HORIZONTAL_ANGLE_RAD) * sign_x, sin(MIN_HORIZONTAL_ANGLE_RAD) * sign_y)
	linear_velocity = dir * _target_speed


# 속도에 비례하여 트레일 길이를 조절한다.
func _update_trail() -> void:
	_trail.add_point(global_position)
	var speed_ratio := clampf(linear_velocity.length() / 800.0, 0.0, 1.0)
	var trail_len: int = int(lerpf(TRAIL_MIN, TRAIL_MAX, speed_ratio))
	while _trail.get_point_count() > trail_len:
		_trail.remove_point(0)


func is_active() -> bool:
	return _is_active
