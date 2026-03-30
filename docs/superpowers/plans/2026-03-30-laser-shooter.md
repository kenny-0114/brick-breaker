# Laser Shooter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 그리드에 배치된 레이저 슈터가 공 통과 시 트리거되어 지정 방향으로 직선 레이저를 발사, 경로상 벽돌에 데미지를 주는 아이템 시스템 구현

**Architecture:** `laser_shooter.gd`(Area2D)가 공 통과를 감지하고, 각 방향으로 `laser_beam.gd`(Node2D)를 생성하여 경로상 벽돌에 데미지를 적용한다. `turn_game_scene.gd`에 ShooterContainer를 추가하여 배치/하강을 관리한다.

**Tech Stack:** Godot 4.6, GDScript, Area2D, Tween

**Spec:** `docs/superpowers/specs/2026-03-30-laser-shooter-design.md`

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `scripts/objects/laser_shooter.gd` | 슈터 로직: 트리거 감지, 레이저 발사, uses 관리, 소멸 |
| Create | `scenes/objects/laser_shooter.tscn` | Area2D + Sprite2D + UsesLabel + CollisionShape2D |
| Create | `scripts/objects/laser_beam.gd` | 빔 연출: 경로 탐색, 데미지 적용, 번쩍+페이드아웃 |
| Create | `scenes/objects/laser_beam.tscn` | Sprite2D (laser.png) |
| Modify | `scripts/turn_game_scene.gd` | ShooterContainer, 레벨 로딩, 하강 처리 |
| Copy   | `kenney-assets/.../laser.png` → `assets/images/items/laser/laser.png` | 레이저 빔 텍스처 |
| Modify | `data/levels/level_1.json` | 테스트용 슈터 배치 |
| Modify | `mockup/level_editor.html` | 레벨 에디터에 슈터 도구 추가 |

---

### Task 1: 레이저 빔 에셋 복사 + laser_beam.tscn/gd 생성

**Files:**
- Copy: `kenney-assets/kenney_rolling-ball-assets/PNG/Retina/laser.png` → `assets/images/items/laser/laser.png`
- Create: `scripts/objects/laser_beam.gd`
- Create: `scenes/objects/laser_beam.tscn`

- [ ] **Step 1: 레이저 빔 텍스처 복사**

```bash
mkdir -p assets/images/items/laser
cp kenney-assets/kenney_rolling-ball-assets/PNG/Retina/laser.png assets/images/items/laser/laser.png
```

- [ ] **Step 2: laser_beam.gd 작성**

```gdscript
# scripts/objects/laser_beam.gd
# 레이저 빔 연출. 지정 방향으로 빔을 표시하고 경로상 벽돌에 데미지를 적용한다.
extends Node2D

const FLASH_DURATION := 0.1
const FADE_DURATION := 0.1

var _damage: int = 1

@onready var beam_sprite: Sprite2D = $BeamSprite


# 빔을 초기화한다. 방향, 길이, 데미지를 설정하고 즉시 데미지를 적용한다.
func setup(direction: int, beam_length: float, damage: int, bricks_in_path: Array) -> void:
	_damage = damage

	# 방향에 따라 회전 (0=위, 1=오른쪽, 2=아래, 3=왼쪽)
	rotation_degrees = direction * 90.0

	# 빔 길이 설정 (laser.png는 세로 256px, y스케일로 길이 조절)
	var tex_height: float = beam_sprite.texture.get_size().y
	beam_sprite.scale.y = beam_length / tex_height
	# 빔을 슈터에서 바깥쪽으로 배치 (피벗이 하단이 되도록)
	beam_sprite.position.y = -beam_length / 2.0

	# 경로상 벽돌에 데미지 적용
	for brick in bricks_in_path:
		if is_instance_valid(brick) and not brick._is_destroyed:
			for i in range(_damage):
				brick.hit()

	# 번쩍 + 페이드아웃 연출
	_play_flash()


# 번쩍 효과 후 페이드아웃하여 소멸한다.
func _play_flash() -> void:
	beam_sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	var tween := create_tween()
	tween.tween_property(beam_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), FLASH_DURATION)
	tween.tween_property(beam_sprite, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(queue_free)
```

- [ ] **Step 3: laser_beam.tscn 작성**

```tscn
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/objects/laser_beam.gd" id="1_beam"]
[ext_resource type="Texture2D" path="res://assets/images/items/laser/laser.png" id="2_laser_tex"]

[node name="LaserBeam" type="Node2D"]
z_index = 40
script = ExtResource("1_beam")

[node name="BeamSprite" type="Sprite2D" parent="."]
texture = ExtResource("2_laser_tex")
```

- [ ] **Step 4: Commit**

```
git add assets/images/items/laser/ scripts/objects/laser_beam.gd scenes/objects/laser_beam.tscn
git commit -m "기능: 레이저 빔 씬 생성 (연출 + 데미지 적용)"
```

---

### Task 2: laser_shooter.tscn/gd 생성

**Files:**
- Create: `scripts/objects/laser_shooter.gd`
- Create: `scenes/objects/laser_shooter.tscn`

- [ ] **Step 1: laser_shooter.gd 작성**

```gdscript
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

@onready var shooter_sprite: Sprite2D = $Sprite2D
@onready var uses_label: Label = $UsesLabel


# 슈터를 초기화한다. uses, damage, dirs를 설정하고 텍스처를 선택한다.
func setup(shooter_uses: int, shooter_damage: int, shooter_dirs: Array, cell_size: Vector2, brick_cont: Node2D) -> void:
	uses = shooter_uses
	damage = shooter_damage
	dirs = shooter_dirs
	_brick_container = brick_cont
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
	# 1방향/2방향은 dirs[0]에 맞게 회전
	if dir_count == 1:
		shooter_sprite.rotation_degrees = DIR_ROTATIONS.get(dirs[0], 0.0)
	elif dir_count == 2:
		# 2방향: 첫 번째 방향 기준 회전 (0,2=세로 기본, 1,3=가로 90도)
		if 1 in dirs or 3 in dirs:
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
	for dir in dirs:
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
	var cell_size: float = 48.0
	# 벽 경계
	var max_dist: float = 800.0

	var bricks_hit: Array = []
	var scan_pos: Vector2 = global_position + step * cell_size * 0.5
	var total_dist: float = cell_size * 0.5

	# 셀 단위로 스캔
	for i in range(20):
		scan_pos += step * cell_size
		total_dist += cell_size
		# 화면 밖 체크
		if scan_pos.x < 0 or scan_pos.x > 480 or scan_pos.y < 68 or scan_pos.y > 748:
			break
		# 해당 위치에 벽돌이 있는지 확인
		var found_brick: Node = _find_brick_at(scan_pos, cell_size * 0.4)
		if found_brick:
			bricks_hit.append(found_brick)
			# 파괴불가 벽돌이면 여기서 멈춤
			if found_brick.hp == -1:
				break

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
```

- [ ] **Step 2: laser_shooter.tscn 작성**

```tscn
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/objects/laser_shooter.gd" id="1_shooter"]
[ext_resource type="Texture2D" path="res://assets/images/items/missile/laser_shooter_4dir.png" id="2_shooter_tex"]
[ext_resource type="FontFile" path="res://assets/fonts/Kenney Future.ttf" id="3_font"]

[sub_resource type="CircleShape2D" id="SubResource_shape"]
radius = 18.0

[node name="LaserShooter" type="Area2D"]
collision_layer = 0
collision_mask = 2
monitorable = false
script = ExtResource("1_shooter")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2_shooter_tex")

[node name="UsesLabel" type="Label" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -25.0
offset_top = -12.0
offset_right = 25.0
offset_bottom = 12.0
grow_horizontal = 2
grow_vertical = 2
theme_override_fonts/font = ExtResource("3_font")
theme_override_font_sizes/font_size = 11
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 3
text = "10"
horizontal_alignment = 1
vertical_alignment = 1

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("SubResource_shape")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]
```

- [ ] **Step 3: Commit**

```
git add scripts/objects/laser_shooter.gd scenes/objects/laser_shooter.tscn
git commit -m "기능: 레이저 슈터 씬 생성 (트리거 감지, 방향별 텍스처, 레이저 발사)"
```

---

### Task 3: turn_game_scene.gd — 슈터 배치 및 하강

**Files:**
- Modify: `scripts/turn_game_scene.gd`

- [ ] **Step 1: LASER_SHOOTER_SCENE preload 추가**

상단 const 블록에 추가 (MISSILE_SCENE 아래):

```gdscript
const LASER_SHOOTER_SCENE := preload("res://scenes/objects/laser_shooter.tscn")
```

- [ ] **Step 2: shooter_container 변수 추가**

`@onready` 블록에 추가:

```gdscript
@onready var shooter_container: Node2D = $ShooterContainer
```

NOTE: `turn_game_scene.tscn`에 `ShooterContainer` Node2D 노드를 추가해야 한다. `ItemContainer` 노드 아래에 추가.

- [ ] **Step 3: _load_level()에 레이저 슈터 배치 로직 추가**

`_load_level()` 함수의 공 아이템 배치 루프 아래에 추가:

```gdscript
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
```

- [ ] **Step 4: _descend_bricks()에 슈터 하강 추가**

`_descend_bricks()` 함수에서 공 아이템 하강 루프 아래에 추가:

```gdscript
	# 레이저 슈터도 함께 하강
	for shooter in shooter_container.get_children():
		tween.tween_property(shooter, "position:y", shooter.position.y + _cell_height, DESCEND_DURATION)
```

또한 함수 시작 부분의 빈 컨테이너 체크를 수정:

기존:
```gdscript
	if brick_container.get_child_count() == 0 and item_container.get_child_count() == 0:
		return
```

변경:
```gdscript
	if brick_container.get_child_count() == 0 and item_container.get_child_count() == 0 and shooter_container.get_child_count() == 0:
		return
```

- [ ] **Step 5: turn_game_scene.tscn에 ShooterContainer 노드 추가**

`scenes/turn_game_scene.tscn` 파일에 `ItemContainer` 노드 아래에 추가해야 한다. 에디터에서 추가하거나, tscn 파일에 직접:

```
[node name="ShooterContainer" type="Node2D" parent="."]
```

- [ ] **Step 6: Commit**

```
git add scripts/turn_game_scene.gd scenes/turn_game_scene.tscn
git commit -m "기능: 레이저 슈터 레벨 배치 및 하강 처리"
```

---

### Task 4: 테스트 레벨 + 에셋 복사

**Files:**
- Modify: `data/levels/level_1.json`

- [ ] **Step 1: level_1.json에 레이저 슈터 추가**

기존 JSON에 `laser_shooters` 배열을 추가:

```json
"laser_shooters": [
  {"row": 2, "col": 5, "uses": 5, "damage": 1, "dirs": [0, 2]},
  {"row": 6, "col": 3, "uses": 10, "damage": 1, "dirs": [0, 1, 2, 3]}
]
```

- [ ] **Step 2: Godot 에디터에서 수동 테스트**

F5로 실행하여 확인:

1. 레이저 슈터가 그리드에 올바른 텍스처로 표시되는지 (2방향/4방향)
2. uses 라벨이 표시되는지
3. 공이 슈터를 통과할 때 반사 없이 지나가는지
4. 통과 시 레이저 빔이 발사되는지
5. 경로상 벽돌에 데미지가 적용되는지
6. 파괴불가 벽돌에서 레이저가 멈추는지
7. uses 소진 시 슈터가 소멸하는지
8. 매 턴 슈터가 벽돌과 함께 하강하는지

- [ ] **Step 3: Commit**

```
git add data/levels/level_1.json
git commit -m "기능: level_1에 레이저 슈터 배치 (테스트용)"
```

---

### Task 5: 레벨 에디터에 슈터 도구 추가

**Files:**
- Modify: `mockup/level_editor.html`

- [ ] **Step 1: Tools 패널에 Laser Shooter 버튼 추가**

기존 Missile 버튼 아래에 추가:

```html
<button class="tool-btn" data-tool="laser">⚡ Laser</button>
```

- [ ] **Step 2: applyTool()에 laser 도구 처리 추가**

```javascript
} else if (currentTool === 'laser') {
  if (existing) { selectCell(row, col); return; }
  grid[row][col] = { type: 'laser_shooter', uses: 10, damage: 1, dirs: [0, 2] };
  markDirty();
}
```

- [ ] **Step 3: render()에 레이저 슈터 렌더링 추가**

`cell.item === 'missile'` 분기 위에 추가:

```javascript
} else if (cell.type === 'laser_shooter') {
  // 슈터 배경
  ctx.fillStyle = '#555F69';
  ctx.beginPath();
  ctx.roundRect(x + 1, y + 1, cellSize - 2, cellSize - 2, 4);
  ctx.fill();
  ctx.fillStyle = '#D8E1EC';
  ctx.beginPath();
  ctx.roundRect(x + 3, y + 3, cellSize - 6, cellSize - 6, 3);
  ctx.fill();
  // 방향 화살표
  ctx.fillStyle = '#e74c3c';
  ctx.font = `bold ${cellSize * 0.3}px sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  const dirSymbols = {0:'↑', 1:'→', 2:'↓', 3:'←'};
  const dirText = (cell.dirs || [0]).map(d => dirSymbols[d]).join('');
  ctx.fillText(dirText, x + cellSize/2, y + cellSize/2 - 4);
  // uses 텍스트
  drawHpText(x + cellSize/2, y + cellSize - 8, cell.uses);
```

- [ ] **Step 4: gridToJson()에 슈터 내보내기 추가**

`ball_items.push` 아래에 추가:

```javascript
const laser_shooters = [];
```

루프 내에 추가:
```javascript
if (cell.type === 'laser_shooter') {
  laser_shooters.push({ row: r, col: c, uses: cell.uses, damage: cell.damage, dirs: cell.dirs });
}
```

return 객체에 추가:
```javascript
laser_shooters
```

- [ ] **Step 5: jsonToGrid()에 슈터 가져오기 추가**

ball_items 파싱 아래에 추가:

```javascript
for (const s of (data.laser_shooters || [])) {
  if (s.row < ROWS && s.col < COLS) {
    grid[s.row][s.col] = { type: 'laser_shooter', uses: s.uses || 10, damage: s.damage || 1, dirs: s.dirs || [0] };
  }
}
```

- [ ] **Step 6: 선택 UI에 슈터 타입 표시**

`updateSelectionUI()`에서 타입 표시 부분에 추가:

```javascript
if (cell.type === 'laser_shooter') {
  document.getElementById('selType').textContent = 'Laser Shooter';
}
```

- [ ] **Step 7: 키보드 단축키 추가**

```javascript
if (e.key === '5') { currentTool = 'laser'; updateToolUI(); }
if (e.key === '6' || e.key === 'e') { currentTool = 'eraser'; updateToolUI(); }
```

기존 '5'/e → eraser를 '6'/e로 변경.

- [ ] **Step 8: Commit**

```
git add mockup/level_editor.html
git commit -m "기능: 레벨 에디터에 레이저 슈터 도구 추가"
```
