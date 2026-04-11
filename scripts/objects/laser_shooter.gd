# scripts/objects/laser_shooter.gd
# 레이저 슈터. 공이 통과하면 트리거되어 지정 방향으로 레이저를 발사한다.
extends Area2D

signal shooter_fired(shooter: Area2D)

const LASER_BEAM_SCENE := preload("res://scenes/objects/laser_beam.tscn")
const TEXTURES := {
	1: preload("res://assets/images/items/missile/laser_shooter_1dir.png"),
	2: preload("res://assets/images/items/missile/laser_shooter_2dir.png"),
	4: preload("res://assets/images/items/missile/laser_shooter_4dir.png"),
}
# 방향별 회전 각도 (0=위, 1=오른쪽, 2=아래, 3=왼쪽)
const DIR_ROTATIONS := { 0: 0.0, 1: 90.0, 2: 180.0, 3: 270.0 }

var uses: int = 10
var damage: int = 1
var dirs: Array = [0]
var _brick_container: Node2D = null
var _cell_size: float = 48.0

@onready var shooter_sprite: Sprite2D = $Sprite2D
@onready var uses_label: Label = $UsesLabel


# 슈터를 초기화한다. uses, damage, dirs를 설정하고 텍스처를 선택한다.
func setup(shooter_uses: int, shooter_damage: int, shooter_dirs: Array, cell_size: Vector2, brick_cont: Node2D) -> void:
	uses = shooter_uses
	damage = shooter_damage
	dirs = shooter_dirs
	_brick_container = brick_cont
	_cell_size = cell_size.x
	_update_texture(cell_size)
	_update_uses_label()


# dirs 개수에 따라 텍스처를 선택하고 방향에 맞게 회전한다.
func _update_texture(cell_size: Vector2) -> void:
	var dir_count: int = dirs.size()
	var tex_key: int = 4 if dir_count >= 3 else dir_count
	var tex: Texture2D = TEXTURES[tex_key]
	shooter_sprite.texture = tex
	# 셀 크기에 맞게 스케일
	var tex_size: Vector2 = tex.get_size()
	var scale_val: float = min(cell_size.x / tex_size.x, cell_size.y / tex_size.y) * 0.9
	shooter_sprite.scale = Vector2(scale_val, scale_val)
	# dirs를 int로 변환 (JSON 파싱 시 float으로 들어올 수 있음)
	var int_dirs: Array[int] = []
	for d in dirs:
		int_dirs.append(int(d))
	# 1방향: 해당 방향으로 회전
	if dir_count == 1:
		shooter_sprite.rotation_degrees = float(int_dirs[0]) * 90.0
	elif dir_count == 2:
		# 2방향: 좌우(1,3)이면 90도 회전, 상하(0,2)는 기본
		if 1 in int_dirs or 3 in int_dirs:
			shooter_sprite.rotation_degrees = 90.0


# uses 라벨을 갱신한다.
func _update_uses_label() -> void:
	if uses_label:
		uses_label.text = str(uses)


# 공이 슈터 영역에 들어왔을 때 호출된다.
func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("ball"):
		return
	if uses <= 0:
		return
	uses -= 1
	_update_uses_label()
	_fire_lasers()
	shooter_fired.emit(self)
	if uses <= 0:
		_die()


# 각 방향으로 레이저를 발사한다.
func _fire_lasers() -> void:
	for d in dirs:
		var dir: int = int(d)
		var result: Dictionary = _scan_direction(dir)
		var beam: Node2D = LASER_BEAM_SCENE.instantiate()
		beam.global_position = global_position
		get_parent().add_child(beam)
		beam.setup(dir, result["length"], damage, result["bricks"])


# 지정 방향으로 벽돌을 탐색한다. 경로상 벽돌 목록과 빔 길이를 반환한다.
func _scan_direction(dir: int) -> Dictionary:
	if _brick_container == null:
		return {"bricks": [], "length": 100.0}
	# 방향 벡터 (0=위, 1=오른쪽, 2=아래, 3=왼쪽)
	var dir_vectors := {0: Vector2(0, -1), 1: Vector2(1, 0), 2: Vector2(0, 1), 3: Vector2(-1, 0)}
	var step: Vector2 = dir_vectors[dir]
	# setup()에서 전달받은 셀 크기를 사용한다.
	var cs: float = _cell_size
	var viewport_width: float = get_viewport_rect().size.x

	var bricks_hit: Array = []
	# 슈터 위치에서 1셀 떨어진 곳부터 스캔 시작 (셀 중앙을 정확히 지남)
	var scan_pos: Vector2 = global_position + step * cs
	var total_dist: float = cs

	# 셀 단위로 스캔
	for i in range(20):
		# 화면 밖 체크
		if scan_pos.x < 0 or scan_pos.x > viewport_width or scan_pos.y < 68 or scan_pos.y > 748:
			break
		# 해당 위치에 벽돌이 있는지 확인
		var found_brick: Node = _find_brick_at(scan_pos, cs * 0.4)
		if found_brick:
			bricks_hit.append(found_brick)
			if found_brick.hp == -1:
				break
		# 다음 셀로 이동
		scan_pos += step * cs
		total_dist += cs

	return {"bricks": bricks_hit, "length": total_dist}


# 지정 위치 근처에 있는 벽돌을 찾는다.
func _find_brick_at(pos: Vector2, radius: float) -> Node:
	if _brick_container == null:
		return null
	for brick in _brick_container.get_children():
		if brick.global_position.distance_to(pos) < radius:
			return brick
	return null


# 슈터가 소멸한다. 축소 + 페이드아웃 연출.
func _die() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.3).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
