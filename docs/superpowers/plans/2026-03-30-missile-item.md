# Missile Item Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 미사일 속성이 내장된 특수 벽돌을 파괴하면 랜덤 5개 벽돌에 미사일이 락온되어 HP 무시 즉시 파괴하는 아이템 시스템 구현

**Architecture:** `brick.gd`에 `item` 속성을 추가하고, 아이템 상자 외형(item_box_frame.png + spaceMissiles_007)으로 렌더링한다. 파괴 시 `turn_game_scene.gd`에서 미사일 발동 로직을 실행하며, `missile.gd`(신규)가 비행/이펙트를 담당한다. 모든 연출은 비동기로 게임 진행을 방해하지 않는다.

**Tech Stack:** Godot 4.6, GDScript, Tween, GPUParticles2D, AnimatedSprite2D

**Spec:** `docs/superpowers/specs/2026-03-30-missile-item-design.md`

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `scripts/objects/brick.gd` | `item` 속성 추가, 아이템 상자 렌더링 |
| Create | `scripts/objects/missile.gd` | 미사일 비행 + 연기 + 폭발 + 자동 소멸 |
| Create | `scenes/objects/missile.tscn` | 미사일 씬 (Sprite2D + GPUParticles2D) |
| Modify | `scripts/turn_game_scene.gd` | 미사일 발동 로직, 락온 마커, 타겟 선정 |
| Modify | `data/levels/level_1.json` | 테스트용 미사일 벽돌 배치 |

---

### Task 1: brick.gd — item 속성 추가 + 시그널 확장

**Files:**
- Modify: `scripts/objects/brick.gd:6` (시그널), `:50` (변수), `:62-70` (setup), `:75-141` (setup_triangle), `:144-156` (hit)

- [ ] **Step 1: brick_destroyed 시그널에 item 정보 추가**

`scripts/objects/brick.gd` 상단 시그널을 변경한다:

```gdscript
signal brick_destroyed(position: Vector2, item: String)
```

- [ ] **Step 2: item 변수 추가**

`var _hit_tween: Tween = null` 아래에 추가:

```gdscript
var item: String = ""
```

- [ ] **Step 3: hit() 함수에서 시그널에 item 전달**

`hit()` 함수의 `brick_destroyed.emit` 호출을 변경:

```gdscript
func hit() -> void:
	if hp == -1 or _is_destroyed:
		return
	hp -= 1
	if hp <= 0:
		_is_destroyed = true
		brick_destroyed.emit(global_position, item)
		queue_free()
	else:
		_update_color_by_hp()
		_update_hp_label()
		_play_hit_effect()
```

- [ ] **Step 4: 미사일에 의한 즉시 파괴 함수 추가**

`hit()` 함수 아래에 추가. 미사일이 HP를 무시하고 즉시 파괴할 때 사용:

```gdscript
# 미사일에 의한 즉시 파괴. HP를 무시하고 파괴한다.
func destroy_by_missile() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	brick_destroyed.emit(global_position, item)
	queue_free()
```

- [ ] **Step 5: Commit**

```
git add scripts/objects/brick.gd
git commit -m "기능: brick.gd에 item 속성 및 destroy_by_missile 추가"
```

---

### Task 2: brick.gd — 아이템 상자 렌더링

**Files:**
- Modify: `scripts/objects/brick.gd` (setup 함수들, 신규 함수)

- [ ] **Step 1: 아이템 상자 텍스처 상수 추가**

`TILE_SIZE` 상수 아래에 추가:

```gdscript
const ITEM_BOX_TEXTURE := preload("res://assets/images/items/item_box_frame.png")
const MISSILE_ICON_TEXTURE := preload("res://kenney_space-shooter-extension/PNG/Sprites X2/Missiles/spaceMissiles_007.png")
```

- [ ] **Step 2: 아이템 상자 셋업 함수 추가**

`_play_hit_effect()` 함수 아래에 추가:

```gdscript
# 아이템 상자 외형으로 렌더링한다. 일반 벽돌 스프라이트를 숨기고 아이템 상자를 표시한다.
func _setup_item_box(cell_size: Vector2) -> void:
	# 일반 벽돌 스프라이트를 아이템 상자 프레임으로 교체한다.
	sprite.texture = ITEM_BOX_TEXTURE
	var tex_size: Vector2 = ITEM_BOX_TEXTURE.get_size()
	sprite.scale = Vector2(cell_size.x / tex_size.x, cell_size.y / tex_size.y)

	# 미사일 아이콘을 45도 기울여서 중앙에 배치한다.
	var icon := Sprite2D.new()
	icon.texture = MISSILE_ICON_TEXTURE
	var icon_tex_size := MISSILE_ICON_TEXTURE.get_size()
	var icon_scale := min(cell_size.x * 0.55 / icon_tex_size.x, cell_size.y * 0.55 / icon_tex_size.y)
	icon.scale = Vector2(icon_scale, icon_scale)
	icon.rotation_degrees = 45.0
	icon.position = Vector2(0, -2)
	add_child(icon)

	# HP 라벨을 아이콘 위에 표시한다.
	move_child(hp_label, -1)
```

- [ ] **Step 3: setup() 함수에서 아이템 상자 분기 추가**

`setup()` 함수의 끝 부분(`_update_hp_label()` 이후)에 아이템 상자 분기를 추가. 기존 함수를 다음으로 교체:

```gdscript
# 사각형 벽돌 초기화.
func setup(brick_hp: int, cell_size: Vector2 = Vector2(48, 48)) -> void:
	hp = brick_hp
	_is_triangle = false
	if hp == -1:
		_update_texture("grey")
		hp_label.visible = false
	else:
		_update_color_by_hp()
		_update_hp_label()
	# 아이템이 있으면 아이템 상자 외형으로 교체한다.
	if item != "":
		_setup_item_box(cell_size)
```

- [ ] **Step 4: turn_game_scene.gd의 setup 호출부에 cell_size 전달**

`scripts/turn_game_scene.gd`의 `_load_level()` 내 사각형 벽돌 setup 호출을 변경:

기존:
```gdscript
			brick.setup(hp)
```

변경:
```gdscript
			brick.setup(hp, cell_size)
```

- [ ] **Step 5: Commit**

```
git add scripts/objects/brick.gd scripts/turn_game_scene.gd
git commit -m "기능: 아이템 상자 외형 렌더링 (item_box_frame + 미사일 아이콘)"
```

---

### Task 3: turn_game_scene.gd — 레벨 로딩에서 item 속성 파싱

**Files:**
- Modify: `scripts/turn_game_scene.gd:74-141` (_load_level)

- [ ] **Step 1: MISSILE_SCENE preload 추가**

`scripts/turn_game_scene.gd` 상단, `BALL_ITEM_SCENE` 아래에 추가:

```gdscript
const MISSILE_SCENE := preload("res://scenes/objects/missile.tscn")
const MISSILE_COUNT := 5
const MISSILE_FIRE_INTERVAL := 0.05
```

- [ ] **Step 2: _load_level()의 벽돌 배치에서 item 파싱**

`_load_level()` 함수의 벽돌 배치 루프에서, `brick_container.add_child(brick)` 바로 위에 item 속성을 파싱한다:

기존:
```gdscript
		brick_container.add_child(brick)
		if brick_type == "tri":
```

변경:
```gdscript
		# 아이템 속성 파싱
		var item_type: String = str(brick_data.get("item", ""))
		brick.item = item_type
		brick_container.add_child(brick)
		if brick_type == "tri":
```

- [ ] **Step 3: _on_brick_destroyed 시그널 핸들러 시그니처 변경**

시그널에 item 파라미터가 추가되었으므로 핸들러를 변경한다:

기존:
```gdscript
func _on_brick_destroyed(pos: Vector2) -> void:
	_remaining_bricks -= 1
	var points := GameManager.add_brick_score()
	_spawn_particles(pos)
	_spawn_score_popup(pos, points, GameManager.combo)
	if _remaining_bricks <= 0 and (_state == State.WAITING or _state == State.FIRING):
		_recall_all_balls.call_deferred()
```

변경:
```gdscript
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
```

- [ ] **Step 4: Commit**

```
git add scripts/turn_game_scene.gd
git commit -m "기능: 레벨 로딩에서 item 속성 파싱 및 brick_destroyed 핸들러 확장"
```

---

### Task 4: missile.tscn + missile.gd — 미사일 씬 생성

**Files:**
- Create: `scripts/objects/missile.gd`
- Create: `scenes/objects/missile.tscn`

- [ ] **Step 1: missile.gd 작성**

```gdscript
# scripts/objects/missile.gd
# 미사일 비행 노드. 타겟까지 직선 비행 후 폭발 이펙트를 재생하고 소멸한다.
extends Node2D

const CROSSHAIR_TEXTURE := preload("res://kenney-res/crosshair_red_large.png")
const EXPLOSION_TEXTURES := [
	preload("res://kenney-res/explosion1.png"),
	preload("res://kenney-res/explosion2.png"),
	preload("res://kenney-res/explosion3.png"),
]
const SMOKE_TEXTURE := preload("res://kenney_space-shooter-extension/PNG/Sprites/Effects/spaceEffects_009.png")
const FLIGHT_DURATION := 0.35
const SMOKE_LIFETIME := 0.3

var _target_brick: Node = null
var _target_pos: Vector2 = Vector2.ZERO

@onready var missile_sprite: Sprite2D = $MissileSprite
@onready var smoke_particles: GPUParticles2D = $SmokeParticles


# 미사일을 초기화한다. 타겟 벽돌과 위치를 설정한다.
func setup(target_brick: Node, target_position: Vector2) -> void:
	_target_brick = target_brick
	_target_pos = target_position


# 타겟 방향으로 회전하고 비행을 시작한다.
func launch() -> void:
	# 타겟 방향으로 회전
	var angle := global_position.angle_to_point(_target_pos)
	missile_sprite.rotation = angle + PI / 2.0

	# 연기 파티클 시작
	smoke_particles.emitting = true

	# Tween으로 직선 비행
	var tween := create_tween()
	tween.tween_property(self, "global_position", _target_pos, FLIGHT_DURATION)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_on_arrived)


# 미사일이 타겟에 도착했을 때 호출된다.
func _on_arrived() -> void:
	# 연기 중지
	smoke_particles.emitting = false

	# 미사일 스프라이트 숨기기
	missile_sprite.visible = false

	# 타겟 벽돌이 아직 유효하면 즉시 파괴
	if is_instance_valid(_target_brick) and not _target_brick.is_queued_for_deletion():
		_target_brick.destroy_by_missile()

	# 폭발 이펙트 재생
	_play_explosion()


# 폭발 이펙트를 재생한다. explosion1~3을 순차 표시 후 자동 소멸한다.
func _play_explosion() -> void:
	var explosion_sprite := Sprite2D.new()
	explosion_sprite.scale = Vector2(0.8, 0.8)
	add_child(explosion_sprite)

	var tween := create_tween()
	for i in range(EXPLOSION_TEXTURES.size()):
		tween.tween_callback(func(): explosion_sprite.texture = EXPLOSION_TEXTURES[i])
		tween.tween_interval(0.08)

	# 마지막 프레임 후 페이드아웃 + 소멸
	tween.tween_property(explosion_sprite, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
```

- [ ] **Step 2: missile.tscn 작성**

```
scenes/objects/missile.tscn
```

```tscn
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/objects/missile.gd" id="1_missile"]
[ext_resource type="Texture2D" path="res://kenney_space-shooter-extension/PNG/Sprites X2/Missiles/spaceMissiles_007.png" id="2_missile_tex"]
[ext_resource type="Texture2D" path="res://kenney_space-shooter-extension/PNG/Sprites/Effects/spaceEffects_009.png" id="3_smoke_tex"]

[sub_resource type="ParticleProcessMaterial" id="SubResource_smoke_mat"]
direction = Vector3(0, 1, 0)
spread = 15.0
initial_velocity_min = 20.0
initial_velocity_max = 40.0
gravity = Vector3(0, 0, 0)
scale_min = 0.3
scale_max = 0.6
color = Color(0.85, 0.85, 0.9, 0.5)

[node name="Missile" type="Node2D"]
z_index = 50
script = ExtResource("1_missile")

[node name="MissileSprite" type="Sprite2D" parent="."]
scale = Vector2(0.5, 0.5)
texture = ExtResource("2_missile_tex")

[node name="SmokeParticles" type="GPUParticles2D" parent="."]
emitting = false
amount = 8
lifetime = 0.3
one_shot = false
process_material = SubResource("SubResource_smoke_mat")
texture = ExtResource("3_smoke_tex")
```

- [ ] **Step 3: Commit**

```
git add scripts/objects/missile.gd scenes/objects/missile.tscn
git commit -m "기능: 미사일 씬 생성 (비행 + 연기 트레일 + 폭발)"
```

---

### Task 5: turn_game_scene.gd — 미사일 발동 로직

**Files:**
- Modify: `scripts/turn_game_scene.gd`

- [ ] **Step 1: 락온 마커 텍스처 상수 추가**

상단 const 블록에 추가:

```gdscript
const CROSSHAIR_TEXTURE := preload("res://kenney-res/crosshair_red_large.png")
```

- [ ] **Step 2: _activate_missile 함수 추가**

`_on_ball_item_collected()` 함수 아래에 추가:

```gdscript
# 미사일 아이템을 발동한다. 랜덤 벽돌에 락온 후 미사일을 순차 발사한다.
func _activate_missile(origin_pos: Vector2) -> void:
	# 파괴 가능 벽돌 중 랜덤 최대 5개 선택
	var targets := _select_missile_targets()
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
```

- [ ] **Step 3: _select_missile_targets 함수 추가**

```gdscript
# 파괴 가능 벽돌 중 랜덤으로 최대 MISSILE_COUNT개를 선택한다.
func _select_missile_targets() -> Array:
	var candidates: Array = []
	for brick in brick_container.get_children():
		if brick.hp > 0 and brick.hp != -1 and not brick._is_destroyed:
			candidates.append(brick)
	candidates.shuffle()
	return candidates.slice(0, MISSILE_COUNT)
```

- [ ] **Step 4: _spawn_lockon_marker 함수 추가**

```gdscript
# 타겟 벽돌 위에 락온 마커를 표시한다. 스케일 펀치 + 회전 애니메이션.
func _spawn_lockon_marker(target: Node2D, delay: float) -> void:
	var marker := Sprite2D.new()
	marker.texture = CROSSHAIR_TEXTURE
	marker.scale = Vector2.ZERO
	marker.z_index = 60
	marker.position = target.position
	# 셀 크기에 맞게 마커 크기 조절
	var tex_size := CROSSHAIR_TEXTURE.get_size()
	var target_scale := _cell_height * 1.2 / tex_size.x
	brick_container.get_parent().add_child(marker)

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
```

- [ ] **Step 5: _spawn_missile 함수 추가**

```gdscript
# 지연 후 미사일을 발사한다. 미사일이 벽돌을 파괴하면 점수/콤보를 처리한다.
func _spawn_missile(origin: Vector2, target: StaticBody2D, delay: float) -> void:
	var missile: Node2D = MISSILE_SCENE.instantiate()
	missile.global_position = origin
	missile.setup(target, target.position)
	add_child(missile)

	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(missile.launch)
```

- [ ] **Step 6: Commit**

```
git add scripts/turn_game_scene.gd
git commit -m "기능: 미사일 발동 로직 (타겟 선정, 락온 마커, 순차 발사)"
```

---

### Task 6: 테스트용 레벨 데이터 + 수동 테스트

**Files:**
- Modify: `data/levels/level_1.json`

- [ ] **Step 1: level_1.json에 미사일 벽돌 추가**

기존 벽돌 배열에 미사일 벽돌 2개를 추가한다:

```json
{
  "ball_speed": 400,
  "initial_balls": 50,
  "star_thresholds": [10, 7, 4],
  "bricks": [
    {"row": 3, "col": 2, "hp": 10},
    {"row": 3, "col": 4, "hp": 10},
    {"row": 3, "col": 7, "hp": 10},
    {"row": 4, "col": 2, "hp": 10},
    {"row": 4, "col": 4, "hp": 5, "item": "missile"},
    {"row": 4, "col": 7, "hp": 10},
    {"row": 5, "col": 2, "hp": 10},
    {"row": 5, "col": 3, "hp": 10},
    {"row": 5, "col": 4, "hp": 10},
    {"row": 5, "col": 7, "hp": 10},
    {"row": 6, "col": 2, "hp": 10},
    {"row": 6, "col": 4, "hp": 10},
    {"row": 6, "col": 7, "hp": 3, "item": "missile"},
    {"row": 7, "col": 2, "hp": 10},
    {"row": 7, "col": 4, "hp": 10},
    {"row": 7, "col": 7, "hp": 10}
  ],
  "ball_items": []
}
```

- [ ] **Step 2: Godot 에디터에서 수동 테스트**

F5로 게임을 실행하여 다음을 확인:

1. 미사일 벽돌이 아이템 상자 외형(금속 프레임 + 유리 + 미사일 아이콘)으로 표시되는지
2. 미사일 벽돌의 HP를 깎아 파괴하면 락온 마커(빨간 크로스헤어)가 표시되는지
3. 미사일이 타겟으로 날아가는지 (연기 트레일 동반)
4. 미사일 도착 시 타겟 벽돌이 즉시 파괴되는지 (폭발 이펙트)
5. 점수 팝업이 표시되는지
6. 공이 멈추지 않고 계속 날아다니는지 (비동기)
7. 모든 벽돌 파괴 시 스테이지 클리어가 정상 작동하는지

- [ ] **Step 3: Commit**

```
git add data/levels/level_1.json
git commit -m "기능: level_1에 미사일 벽돌 배치 (테스트용)"
```
