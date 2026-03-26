# Turn-Based Brick Breaker Conversion - Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기존 실시간 패들 벽돌깨기를 Ballz 스타일 턴제 벽돌깨기로 전환한다 (Phase 1: 사각형 벽돌, 스테이지 클리어 모드).

**Architecture:** 기존 GameScene을 보존하고 새 TurnGameScene을 생성한다. Launcher(조준/발사), BallItem(공 수집), 턴 상태 머신이 핵심 신규 컴포넌트다. GameManager/SaveManager는 턴제에 맞게 수정하고, Ball/Brick은 새 메카닉에 맞게 리팩토링한다.

**Tech Stack:** Godot 4.6, GDScript, RigidBody2D (공 물리), RayCast2D (조준선), Tween (애니메이션)

**Spec:** `docs/superpowers/specs/2026-03-26-turn-based-conversion-design.md`

---

## File Structure

### 신규 파일

| 파일 | 역할 |
|------|------|
| `scenes/turn_game_scene.tscn` | 턴제 메인 씬 (Walls, Floor, Launcher, Containers, HUD, 메뉴) |
| `scripts/turn_game_scene.gd` | 턴 루프 상태 머신, 벽돌 하강, 레벨 로드, 게임오버/클리어 판정 |
| `scenes/objects/launcher.tscn` | 조준선(Line2D) + 발사 지점(Marker2D) |
| `scripts/objects/launcher.gd` | 터치 조준, 각도 제한, 연사 발사, 발사 지점 이동 |
| `scenes/objects/ball_item.tscn` | 공 수집 아이템 (Area2D + 원형 스프라이트) |
| `scripts/objects/ball_item.gd` | 공 접촉 시 수집 시그널 발생 |

### 수정 파일

| 파일 | 변경 내용 |
|------|----------|
| `scripts/autoload/game_manager.gd` | score→turn_count, lives→ball_count, 시그널 변경, clear_stage 턴 기반 별 계산 |
| `scripts/autoload/save_manager.gd` | complete_stage에서 최저 턴 비교 (`<`) |
| `scripts/objects/ball.gd` | 패들 의존 제거, setup 간소화, 속도 정규화, 패들 반사 제거 |
| `scripts/objects/brick.gd` | HP 라벨 추가, HP 구간별 색상 변경, 높은 HP 지원 |
| `scripts/hud.gd` | Turn/Balls 표시로 변경 |
| `scripts/game_over_menu.gd` | 턴 수 표시, 턴 기반 별 |
| `scripts/stage_select.gd` | turn_game_scene으로 전환, 최저 턴 표시 |
| `data/levels/level_1~5.json` | 턴제용 데이터 리뉴얼 |
| `project.godot` | main_scene을 title_screen 유지 (변경 없음 확인) |

---

## Task 1: GameManager — 턴제 상태 관리로 전환

**Files:**
- Modify: `scripts/autoload/game_manager.gd` (전체 재작성)

- [ ] **Step 1: GameManager를 턴제 상태로 재작성**

`scripts/autoload/game_manager.gd` 전체를 다음으로 교체:

```gdscript
# scripts/autoload/game_manager.gd
# 턴제 게임의 휘발성 상태를 관리한다.
# 턴 수, 공 개수, 현재 레벨을 추적한다.
extends Node

signal turn_changed(new_turn: int)
signal ball_count_changed(new_count: int)
signal game_over
signal stage_cleared

var current_level: int = 1
var turn_count: int = 0
var ball_count: int = 1
var is_playing: bool = false
var _star_thresholds: Array = [20, 15, 10]


# 새 레벨을 시작할 때 상태를 초기화한다.
func start_level(level: int, initial_balls: int, star_thresholds: Array) -> void:
	current_level = level
	turn_count = 0
	ball_count = initial_balls
	_star_thresholds = star_thresholds
	is_playing = true
	turn_changed.emit(turn_count)
	ball_count_changed.emit(ball_count)


# 턴 종료 시 턴 카운터를 증가시킨다.
func advance_turn() -> void:
	turn_count += 1
	turn_changed.emit(turn_count)


# 공 아이템 수집 시 공 개수를 증가시킨다.
func add_balls(count: int) -> void:
	ball_count += count
	ball_count_changed.emit(ball_count)


# 턴 수 기준으로 별 개수를 계산한다.
# star_thresholds = [1성 기준, 2성 기준, 3성 기준] (턴 수 이하면 획득)
func _calculate_stars() -> int:
	if _star_thresholds.is_empty():
		return 0
	var stars := 0
	for i in _star_thresholds.size():
		if turn_count <= int(_star_thresholds[i]):
			stars = i + 1
	return stars


# 스테이지 클리어 시 결과를 저장한다.
func clear_stage() -> void:
	is_playing = false
	var stars := _calculate_stars()
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.call("complete_stage", current_level, turn_count, stars)
	stage_cleared.emit()


# 벽돌이 발사 라인에 도달하면 게임오버를 발생시킨다.
func trigger_game_over() -> void:
	is_playing = false
	game_over.emit()
```

- [ ] **Step 2: 변경 확인 및 커밋**

```bash
git add scripts/autoload/game_manager.gd
git commit -m "refactor: convert GameManager to turn-based state (turn_count, ball_count, star thresholds)"
```

---

## Task 2: SaveManager — 최저 턴 비교 로직

**Files:**
- Modify: `scripts/autoload/save_manager.gd:52-65` (complete_stage 함수)

- [ ] **Step 1: complete_stage를 최저 턴 비교로 수정**

`scripts/autoload/save_manager.gd`의 `complete_stage` 함수를 다음으로 교체:

```gdscript
# 스테이지 클리어 시 결과를 반영한다. score는 턴 수 (낮을수록 좋음).
func complete_stage(level: int, turn_count: int, stars_earned: int) -> void:
	var level_key := str(level)
	# 해금 레벨 갱신
	if level + 1 > data["unlocked_level"]:
		data["unlocked_level"] = level + 1
	# 최저 턴 기록 갱신 (낮을수록 좋음, 0은 미플레이 의미)
	var current_best: int = int(data["high_scores"].get(level_key, 0))
	if current_best == 0 or turn_count < current_best:
		data["high_scores"][level_key] = turn_count
	# 별 갱신
	var current_stars: int = int(data["stars"].get(level_key, 0))
	if stars_earned > current_stars:
		data["stars"][level_key] = stars_earned
	save_data()
```

- [ ] **Step 2: 커밋**

```bash
git add scripts/autoload/save_manager.gd
git commit -m "refactor: SaveManager uses lowest turn count comparison for high scores"
```

---

## Task 3: Brick — HP 라벨 오버레이 및 색상 구간

**Files:**
- Modify: `scripts/objects/brick.gd` (전체 재작성)
- Modify: `scenes/objects/brick.tscn` (Label 노드 추가)

- [ ] **Step 1: brick.gd를 턴제용으로 재작성**

`scripts/objects/brick.gd` 전체를 다음으로 교체:

```gdscript
# scripts/objects/brick.gd
# HP를 가진 벽돌. 공에 맞으면 HP가 1 감소한다.
# HP에 따라 텍스처 색상이 바뀌고, 중앙에 HP 숫자를 표시한다.
extends StaticBody2D

signal brick_destroyed(position: Vector2)

const TEXTURES := {
	"green": preload("res://assets/images/bricks/tileGreen_14.png"),
	"orange": preload("res://assets/images/bricks/tileOrange_14.png"),
	"red": preload("res://assets/images/bricks/tileRed_14.png"),
	"grey": preload("res://assets/images/bricks/tileGrey_14.png"),
}

# HP 구간별 색상 키
const HP_COLOR_THRESHOLDS := [
	[11, "green"],
	[31, "orange"],
	[999999, "red"],
]

var hp: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var hp_label: Label = $HPLabel


# 벽돌의 HP와 텍스처를 초기화한다.
func setup(brick_hp: int) -> void:
	hp = brick_hp
	if hp == -1:
		_update_texture("grey")
		hp_label.visible = false
	else:
		_update_color_by_hp()
		_update_hp_label()


# 공에 맞았을 때 호출된다. HP를 1 감소시키고 파괴 여부를 판정한다.
func hit() -> void:
	if hp == -1:
		return
	hp -= 1
	if hp <= 0:
		brick_destroyed.emit(global_position)
		queue_free()
	else:
		_update_color_by_hp()
		_update_hp_label()
		_play_hit_effect()


# HP 구간에 따른 색상 키를 반환한다.
func _get_color_key() -> String:
	for threshold in HP_COLOR_THRESHOLDS:
		if hp < int(threshold[0]):
			return threshold[1] as String
	return "red"


# HP에 따라 텍스처 색상을 갱신한다.
func _update_color_by_hp() -> void:
	_update_texture(_get_color_key())


# 텍스처를 교체한다.
func _update_texture(color_key: String) -> void:
	if sprite and TEXTURES.has(color_key):
		sprite.texture = TEXTURES[color_key]


# HP 라벨을 갱신한다.
func _update_hp_label() -> void:
	if hp_label:
		hp_label.text = str(hp)


# 피격 시 흰색 플래시 효과를 재생한다.
func _play_hit_effect() -> void:
	var tween := create_tween()
	sprite.modulate = Color.WHITE * 2.0
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
```

- [ ] **Step 2: brick.tscn에 HPLabel 노드 추가**

`scenes/objects/brick.tscn`을 다음으로 교체:

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/objects/brick.gd" id="1_brick"]
[ext_resource type="Texture2D" path="res://assets/images/bricks/tileGreen_14.png" id="2_brick"]
[ext_resource type="FontFile" path="res://assets/fonts/Kenney Future.ttf" id="3_font"]

[sub_resource type="RectangleShape2D" id="SubResource_shape"]
size = Vector2(60, 28)

[node name="Brick" type="StaticBody2D"]
script = ExtResource("1_brick")

[node name="Sprite2D" type="Sprite2D" parent="."]
scale = Vector2(0.32, 0.32)
texture = ExtResource("2_brick")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("SubResource_shape")

[node name="HPLabel" type="Label" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -30.0
offset_top = -14.0
offset_right = 30.0
offset_bottom = 14.0
grow_horizontal = 2
grow_vertical = 2
theme_override_fonts/font = ExtResource("3_font")
theme_override_font_sizes/font_size = 12
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 3
text = "1"
horizontal_alignment = 1
vertical_alignment = 1
```

- [ ] **Step 3: 커밋**

```bash
git add scripts/objects/brick.gd scenes/objects/brick.tscn
git commit -m "refactor: Brick supports high HP with label overlay and color thresholds"
```

---

## Task 4: Ball — 턴제용 리팩토링

**Files:**
- Modify: `scripts/objects/ball.gd` (전체 재작성)

- [ ] **Step 1: ball.gd를 턴제용으로 재작성**

`scripts/objects/ball.gd` 전체를 다음으로 교체:

```gdscript
# scripts/objects/ball.gd
# 턴제 벽돌깨기의 공. 일정 속도로 직선 이동하고 벽/벽돌에 반사된다.
# 바닥 도달 시 회수 시그널을 발생시킨다.
extends RigidBody2D

signal ball_returned(ball_position: Vector2)

const MIN_ANGLE_RAD := deg_to_rad(15.0)
const MAX_ANGLE_RAD := deg_to_rad(165.0)
const TRAIL_MIN := 12
const TRAIL_MAX := 35

var _target_speed := 400.0
var _is_active := false
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
	_normalize_speed()
	_correct_angle()
	_update_trail()


# 속도를 목표 속도로 정규화한다. 물리 반사로 인한 속도 변화를 방지한다.
func _normalize_speed() -> void:
	var speed := linear_velocity.length()
	if speed < 1.0:
		return
	linear_velocity = linear_velocity.normalized() * _target_speed


# 너무 수평에 가까운 각도를 보정한다.
func _correct_angle() -> void:
	var vel := linear_velocity
	var speed := vel.length()
	if speed < 1.0:
		return
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


# 벽돌에 충돌했을 때 hit()을 호출한다.
func _on_body_entered(body: Node) -> void:
	if body.has_method("hit"):
		body.hit()
```

- [ ] **Step 2: 커밋**

```bash
git add scripts/objects/ball.gd
git commit -m "refactor: Ball removes paddle dependency, adds speed normalization for turn-based mode"
```

---

## Task 5: BallItem — 공 수집 아이템

**Files:**
- Create: `scripts/objects/ball_item.gd`
- Create: `scenes/objects/ball_item.tscn`

- [ ] **Step 1: ball_item.gd 작성**

```gdscript
# scripts/objects/ball_item.gd
# 필드에 배치되는 공 수집 아이템. 공이 접촉하면 수집된다.
extends Area2D

signal collected


# 공이 접촉하면 수집 시그널을 발생시키고 사라진다.
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("ball"):
		collected.emit()
		queue_free()
```

- [ ] **Step 2: ball_item.tscn 작성**

`scenes/objects/ball_item.tscn`:

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/objects/ball_item.gd" id="1_item"]
[ext_resource type="Texture2D" path="res://assets/images/ball/ballBlue_01.png" id="2_ball"]

[sub_resource type="CircleShape2D" id="SubResource_shape"]
radius = 10.0

[node name="BallItem" type="Area2D"]
collision_layer = 0
collision_mask = 1
monitorable = false
script = ExtResource("1_item")

[node name="Sprite2D" type="Sprite2D" parent="."]
scale = Vector2(0.08, 0.08)
texture = ExtResource("2_ball")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("SubResource_shape")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]
```

- [ ] **Step 3: 커밋**

```bash
git add scripts/objects/ball_item.gd scenes/objects/ball_item.tscn
git commit -m "feat: add BallItem pickup for turn-based ball collection"
```

---

## Task 6: Launcher — 조준선 및 연사 발사

**Files:**
- Create: `scripts/objects/launcher.gd`
- Create: `scenes/objects/launcher.tscn`

- [ ] **Step 1: launcher.gd 작성**

```gdscript
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
		# 투명 갭을 위해 같은 점 2개 추가 (Line2D에서 끊김 효과)
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
```

- [ ] **Step 2: launcher.tscn 작성**

`scenes/objects/launcher.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/objects/launcher.gd" id="1_launcher"]

[node name="Launcher" type="Node2D"]
script = ExtResource("1_launcher")

[node name="AimLine" type="Line2D" parent="."]
width = 2.0
default_color = Color(1, 1, 1, 0.5)

[node name="LaunchPoint" type="Marker2D" parent="."]
position = Vector2(0, 0)

[node name="FireTimer" type="Timer" parent="."]
wait_time = 0.05
one_shot = false
```

- [ ] **Step 3: 커밋**

```bash
git add scripts/objects/launcher.gd scenes/objects/launcher.tscn
git commit -m "feat: add Launcher with aim line and sequential ball firing"
```

---

## Task 7: TurnGameScene — 메인 턴 루프

**Files:**
- Create: `scripts/turn_game_scene.gd`
- Create: `scenes/turn_game_scene.tscn`

- [ ] **Step 1: turn_game_scene.gd 작성**

```gdscript
# scripts/turn_game_scene.gd
# 턴제 벽돌깨기 메인 씬. 턴 루프, 벽돌 하강, 승리/패배 판정을 담당한다.
extends Node2D

enum State { AIMING, FIRING, WAITING, TURN_END }

const BALL_SCENE := preload("res://scenes/objects/ball.tscn")
const BRICK_SCENE := preload("res://scenes/objects/brick.tscn")
const BALL_ITEM_SCENE := preload("res://scenes/objects/ball_item.tscn")
const BRICK_TEXTURES := {
	"green": preload("res://assets/images/bricks/tileGreen_14.png"),
	"orange": preload("res://assets/images/bricks/tileOrange_14.png"),
	"red": preload("res://assets/images/bricks/tileRed_14.png"),
}
const DEBRIS_TEXTURES := {
	"green": preload("res://assets/images/bricks/tileGreen_01.png"),
	"orange": preload("res://assets/images/bricks/tileOrange_27.png"),
	"red": preload("res://assets/images/bricks/tileRed_01.png"),
}

const GRID_COLS := 7
const BRICK_MARGIN := 4.0
const GRID_TOP_OFFSET := 80.0
const DESCEND_AMOUNT := 36.0
const DESCEND_DURATION := 0.3
const FLOOR_Y := 800.0

var _state: State = State.AIMING
var _remaining_bricks := 0
var _ball_speed := 400.0
var _balls_collected := 0
var _first_ball_x := 240.0
var _first_ball_landed := false
var _active_ball_count := 0

@onready var launcher: Node2D = $Launcher
@onready var brick_container: Node2D = $BrickContainer
@onready var item_container: Node2D = $ItemContainer
@onready var ball_container: Node2D = $BallContainer
@onready var floor_zone: Area2D = $Floor
@onready var hud := $HUD
@onready var pause_menu := $PauseMenu
@onready var game_over_menu := $GameOverMenu


func _ready() -> void:
	GameManager.game_over.connect(_on_game_over)
	GameManager.stage_cleared.connect(_on_stage_cleared)
	floor_zone.body_entered.connect(_on_floor_body_entered)
	launcher.all_balls_fired.connect(_on_all_balls_fired)
	_load_level(GameManager.current_level)
	_start_aiming()


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
	var brick_width := (viewport_width - BRICK_MARGIN * (GRID_COLS + 1)) / GRID_COLS

	# 벽돌 배치
	var bricks_array: Array = data.get("bricks", []) as Array
	for brick_data: Dictionary in bricks_array:
		var brick: StaticBody2D = BRICK_SCENE.instantiate()
		var row: int = int(brick_data["row"])
		var col: int = int(brick_data["col"])
		var hp: int = int(brick_data["hp"])
		brick.position = Vector2(
			BRICK_MARGIN + col * (brick_width + BRICK_MARGIN) + brick_width * 0.5,
			GRID_TOP_OFFSET + row * (brick_width * 0.5 + BRICK_MARGIN)
		)
		brick_container.add_child(brick)
		brick.setup(hp)
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
			BRICK_MARGIN + col * (brick_width + BRICK_MARGIN) + brick_width * 0.5,
			GRID_TOP_OFFSET + row * (brick_width * 0.5 + BRICK_MARGIN)
		)
		item_container.add_child(item)
		item.collected.connect(_on_ball_item_collected)

	# Launcher 설정
	launcher.setup(BALL_SCENE, _ball_speed, ball_container)
	launcher.global_position = Vector2(0, FLOOR_Y)
	launcher.set_launch_x(_first_ball_x)


# 조준 상태로 전환한다.
func _start_aiming() -> void:
	_state = State.AIMING
	_balls_collected = 0
	_first_ball_landed = false
	_active_ball_count = 0
	launcher.set_launch_x(_first_ball_x)
	launcher.enable_aiming()


# Launcher가 모든 공을 발사 완료했을 때 호출된다.
func _on_all_balls_fired() -> void:
	_state = State.WAITING
	_active_ball_count = ball_container.get_child_count()


# 공이 바닥에 닿았을 때 호출된다.
func _on_floor_body_entered(body: Node2D) -> void:
	if not body.is_in_group("ball"):
		return
	# 첫 번째 공의 X 위치를 다음 턴 발사 지점으로 저장
	if not _first_ball_landed:
		_first_ball_landed = true
		_first_ball_x = clampf(body.global_position.x, 20.0, 460.0)
	# 공을 발사 지점으로 이동 후 제거
	var tween := create_tween()
	body.freeze = true
	body.set_deferred("linear_velocity", Vector2.ZERO)
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
	var tween := create_tween()
	tween.set_parallel(true)
	for brick in brick_container.get_children():
		tween.tween_property(brick, "position:y", brick.position.y + DESCEND_AMOUNT, DESCEND_DURATION)
	# 공 아이템도 함께 하강
	for item in item_container.get_children():
		tween.tween_property(item, "position:y", item.position.y + DESCEND_AMOUNT, DESCEND_DURATION)
	await tween.finished


# 벽돌이 발사 라인에 도달했는지 확인한다.
func _check_game_over() -> bool:
	for brick in brick_container.get_children():
		if brick.position.y >= FLOOR_Y - DESCEND_AMOUNT:
			return true
	return false


# 벽돌 파괴 시 호출된다.
func _on_brick_destroyed(pos: Vector2) -> void:
	_remaining_bricks -= 1
	_spawn_particles(pos)


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
	particles.texture = preload("res://assets/images/bricks/tileGreen_01.png")
	add_child(particles)
	particles.finished.connect(particles.queue_free)


func _on_game_over() -> void:
	game_over_menu.show_game_over()


func _on_stage_cleared() -> void:
	game_over_menu.show_clear()
```

- [ ] **Step 2: turn_game_scene.tscn 작성**

기존 `game_scene.tscn`을 기반으로 Paddle을 Launcher로 교체하고, DeathZone을 Floor로 교체한다. `scenes/turn_game_scene.tscn`:

```
[gd_scene load_steps=14 format=3]

[ext_resource type="Script" path="res://scripts/turn_game_scene.gd" id="1_game"]
[ext_resource type="Script" path="res://scripts/hud.gd" id="2_hud"]
[ext_resource type="Script" path="res://scripts/pause_menu.gd" id="3_pause"]
[ext_resource type="Script" path="res://scripts/game_over_menu.gd" id="4_gameover"]
[ext_resource type="PackedScene" path="res://scenes/objects/launcher.tscn" id="5_launcher"]
[ext_resource type="PackedScene" path="res://scenes/ui/settings_popup.tscn" id="6_settings"]
[ext_resource type="FontFile" path="res://assets/fonts/Kenney Future.ttf" id="7_font"]
[ext_resource type="FontFile" path="res://assets/fonts/Kenney Future Narrow.ttf" id="8_font_narrow"]

[sub_resource type="RectangleShape2D" id="wall_h"]
size = Vector2(480, 20)

[sub_resource type="RectangleShape2D" id="wall_v"]
size = Vector2(20, 854)

[sub_resource type="RectangleShape2D" id="floor_shape"]
size = Vector2(480, 20)

[sub_resource type="StyleBoxFlat" id="panel_style"]
bg_color = Color(0.1, 0.12, 0.22, 0.95)
corner_radius_top_left = 12
corner_radius_top_right = 12
corner_radius_bottom_right = 12
corner_radius_bottom_left = 12
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.3, 0.4, 0.6, 0.5)

[sub_resource type="StyleBoxFlat" id="btn_style"]
bg_color = Color(0.31, 0.66, 0.87, 1)
corner_radius_top_left = 6
corner_radius_top_right = 6
corner_radius_bottom_right = 6
corner_radius_bottom_left = 6

[node name="TurnGameScene" type="Node2D"]
script = ExtResource("1_game")

[node name="Background" type="ColorRect" parent="."]
offset_right = 480.0
offset_bottom = 854.0
color = Color(0.1, 0.1, 0.24, 1)

[node name="WallTop" type="StaticBody2D" parent="."]
position = Vector2(240, -10)

[node name="CollisionShape2D" type="CollisionShape2D" parent="WallTop"]
shape = SubResource("wall_h")

[node name="WallLeft" type="StaticBody2D" parent="."]
position = Vector2(-10, 427)

[node name="CollisionShape2D" type="CollisionShape2D" parent="WallLeft"]
shape = SubResource("wall_v")

[node name="WallRight" type="StaticBody2D" parent="."]
position = Vector2(490, 427)

[node name="CollisionShape2D" type="CollisionShape2D" parent="WallRight"]
shape = SubResource("wall_v")

[node name="Floor" type="Area2D" parent="."]
position = Vector2(240, 820)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Floor"]
shape = SubResource("floor_shape")

[node name="Launcher" parent="." instance=ExtResource("5_launcher")]
position = Vector2(0, 800)

[node name="BrickContainer" type="Node2D" parent="."]

[node name="ItemContainer" type="Node2D" parent="."]

[node name="BallContainer" type="Node2D" parent="."]

[node name="HUD" type="CanvasLayer" parent="."]
script = ExtResource("2_hud")

[node name="MarginContainer" type="MarginContainer" parent="HUD"]
anchors_preset = 10
anchor_right = 1.0
grow_horizontal = 2
offset_bottom = 44.0
theme_override_constants/margin_left = 12
theme_override_constants/margin_top = 10
theme_override_constants/margin_right = 12

[node name="HBoxContainer" type="HBoxContainer" parent="HUD/MarginContainer"]
layout_mode = 2
theme_override_constants/separation = 10

[node name="TurnLabel" type="Label" parent="HUD/MarginContainer/HBoxContainer"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_fonts/font = ExtResource("8_font_narrow")
theme_override_font_sizes/font_size = 16
theme_override_colors/font_color = Color(1, 0.84, 0, 1)
text = "Turn: 0"

[node name="LevelLabel" type="Label" parent="HUD/MarginContainer/HBoxContainer"]
layout_mode = 2
theme_override_fonts/font = ExtResource("8_font_narrow")
theme_override_font_sizes/font_size = 14
theme_override_colors/font_color = Color(0.67, 0.67, 0.67, 1)
text = "Level 1"
horizontal_alignment = 1

[node name="BallsLabel" type="Label" parent="HUD/MarginContainer/HBoxContainer"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_fonts/font = ExtResource("8_font_narrow")
theme_override_font_sizes/font_size = 16
theme_override_colors/font_color = Color(0.5, 0.85, 1.0, 1)
text = "Balls: 1"
horizontal_alignment = 2

[node name="PauseButton" type="Button" parent="HUD/MarginContainer/HBoxContainer"]
layout_mode = 2
custom_minimum_size = Vector2(36, 36)
theme_override_fonts/font = ExtResource("8_font_narrow")
theme_override_font_sizes/font_size = 14
theme_override_colors/font_color = Color(0.8, 0.8, 0.8, 1)
text = "| |"

[node name="PauseMenu" type="CanvasLayer" parent="."]
process_mode = 3
script = ExtResource("3_pause")

[node name="Panel" type="Panel" parent="PauseMenu"]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -130.0
offset_top = -110.0
offset_right = 130.0
offset_bottom = 110.0
grow_horizontal = 2
grow_vertical = 2
theme_override_styles/panel = SubResource("panel_style")

[node name="VBoxContainer" type="VBoxContainer" parent="PauseMenu/Panel"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 20.0
offset_top = 15.0
offset_right = -20.0
offset_bottom = -15.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 12
alignment = 1

[node name="PauseLabel" type="Label" parent="PauseMenu/Panel/VBoxContainer"]
layout_mode = 2
theme_override_fonts/font = ExtResource("7_font")
theme_override_font_sizes/font_size = 24
theme_override_colors/font_color = Color(1, 1, 1, 1)
text = "PAUSED"
horizontal_alignment = 1

[node name="ResumeButton" type="Button" parent="PauseMenu/Panel/VBoxContainer"]
layout_mode = 2
custom_minimum_size = Vector2(0, 38)
theme_override_fonts/font = ExtResource("7_font")
theme_override_font_sizes/font_size = 14
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_styles/normal = SubResource("btn_style")
theme_override_styles/hover = SubResource("btn_style")
theme_override_styles/pressed = SubResource("btn_style")
text = "Resume"

[node name="SettingsButton" type="Button" parent="PauseMenu/Panel/VBoxContainer"]
layout_mode = 2
custom_minimum_size = Vector2(0, 38)
theme_override_fonts/font = ExtResource("7_font")
theme_override_font_sizes/font_size = 14
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_styles/normal = SubResource("btn_style")
theme_override_styles/hover = SubResource("btn_style")
theme_override_styles/pressed = SubResource("btn_style")
text = "Settings"

[node name="StageSelectButton" type="Button" parent="PauseMenu/Panel/VBoxContainer"]
layout_mode = 2
custom_minimum_size = Vector2(0, 38)
theme_override_fonts/font = ExtResource("7_font")
theme_override_font_sizes/font_size = 14
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_styles/normal = SubResource("btn_style")
theme_override_styles/hover = SubResource("btn_style")
theme_override_styles/pressed = SubResource("btn_style")
text = "Stage Select"

[node name="SettingsPopup" parent="PauseMenu" instance=ExtResource("6_settings")]

[node name="GameOverMenu" type="CanvasLayer" parent="."]
process_mode = 3
script = ExtResource("4_gameover")

[node name="Panel" type="Panel" parent="GameOverMenu"]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -150.0
offset_top = -140.0
offset_right = 150.0
offset_bottom = 140.0
grow_horizontal = 2
grow_vertical = 2
theme_override_styles/panel = SubResource("panel_style")

[node name="VBoxContainer" type="VBoxContainer" parent="GameOverMenu/Panel"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 20.0
offset_top = 15.0
offset_right = -20.0
offset_bottom = -15.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 12
alignment = 1

[node name="TitleLabel" type="Label" parent="GameOverMenu/Panel/VBoxContainer"]
layout_mode = 2
theme_override_fonts/font = ExtResource("7_font")
theme_override_font_sizes/font_size = 26
theme_override_colors/font_color = Color(0.91, 0.27, 0.38, 1)
text = "GAME OVER"
horizontal_alignment = 1

[node name="ScoreLabel" type="Label" parent="GameOverMenu/Panel/VBoxContainer"]
layout_mode = 2
theme_override_fonts/font = ExtResource("8_font_narrow")
theme_override_font_sizes/font_size = 18
theme_override_colors/font_color = Color(1, 0.84, 0, 1)
text = "Turn: 0"
horizontal_alignment = 1

[node name="StarsContainer" type="HBoxContainer" parent="GameOverMenu/Panel/VBoxContainer"]
layout_mode = 2
alignment = 1

[node name="RetryButton" type="Button" parent="GameOverMenu/Panel/VBoxContainer"]
layout_mode = 2
custom_minimum_size = Vector2(0, 38)
theme_override_fonts/font = ExtResource("7_font")
theme_override_font_sizes/font_size = 14
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_styles/normal = SubResource("btn_style")
theme_override_styles/hover = SubResource("btn_style")
theme_override_styles/pressed = SubResource("btn_style")
text = "Retry"

[node name="StageSelectButton" type="Button" parent="GameOverMenu/Panel/VBoxContainer"]
layout_mode = 2
custom_minimum_size = Vector2(0, 38)
theme_override_fonts/font = ExtResource("7_font")
theme_override_font_sizes/font_size = 14
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_styles/normal = SubResource("btn_style")
theme_override_styles/hover = SubResource("btn_style")
theme_override_styles/pressed = SubResource("btn_style")
text = "Stage Select"

[connection signal="pressed" from="HUD/MarginContainer/HBoxContainer/PauseButton" to="HUD" method="_on_pause_pressed"]
[connection signal="pressed" from="PauseMenu/Panel/VBoxContainer/ResumeButton" to="PauseMenu" method="_on_resume_pressed"]
[connection signal="pressed" from="PauseMenu/Panel/VBoxContainer/SettingsButton" to="PauseMenu" method="_on_settings_pressed"]
[connection signal="pressed" from="PauseMenu/Panel/VBoxContainer/StageSelectButton" to="PauseMenu" method="_on_stage_select_pressed"]
[connection signal="pressed" from="GameOverMenu/Panel/VBoxContainer/RetryButton" to="GameOverMenu" method="_on_retry_pressed"]
[connection signal="pressed" from="GameOverMenu/Panel/VBoxContainer/StageSelectButton" to="GameOverMenu" method="_on_stage_select_pressed"]
```

- [ ] **Step 3: 커밋**

```bash
git add scripts/turn_game_scene.gd scenes/turn_game_scene.tscn
git commit -m "feat: add TurnGameScene with turn loop, brick descent, and game over detection"
```

---

## Task 8: HUD — 턴/공 표시로 변경

**Files:**
- Modify: `scripts/hud.gd` (전체 재작성)

- [ ] **Step 1: hud.gd를 턴제용으로 재작성**

`scripts/hud.gd` 전체를 다음으로 교체:

```gdscript
# scripts/hud.gd
# 게임 중 턴 수, 공 개수, 레벨을 표시한다.
extends CanvasLayer

@onready var turn_label: Label = $MarginContainer/HBoxContainer/TurnLabel
@onready var level_label: Label = $MarginContainer/HBoxContainer/LevelLabel
@onready var balls_label: Label = $MarginContainer/HBoxContainer/BallsLabel
@onready var pause_button: Button = $MarginContainer/HBoxContainer/PauseButton


func _ready() -> void:
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.ball_count_changed.connect(_on_ball_count_changed)
	_update_level()
	_on_turn_changed(GameManager.turn_count)
	_on_ball_count_changed(GameManager.ball_count)


func _on_turn_changed(new_turn: int) -> void:
	turn_label.text = "Turn: %d" % new_turn


func _on_ball_count_changed(new_count: int) -> void:
	balls_label.text = "Balls: %d" % new_count


func _update_level() -> void:
	level_label.text = "Level %d" % GameManager.current_level


# 일시정지 버튼을 눌렀을 때 PauseMenu를 토글한다.
func _on_pause_pressed() -> void:
	var pause_menu: Node = get_parent().get_node("PauseMenu")
	if pause_menu:
		pause_menu.toggle_pause()
```

- [ ] **Step 2: 커밋**

```bash
git add scripts/hud.gd
git commit -m "refactor: HUD displays turn count and ball count instead of score and lives"
```

---

## Task 9: GameOverMenu — 턴 수 기반 결과 표시

**Files:**
- Modify: `scripts/game_over_menu.gd` (전체 재작성)

- [ ] **Step 1: game_over_menu.gd를 턴제용으로 재작성**

`scripts/game_over_menu.gd` 전체를 다음으로 교체:

```gdscript
# scripts/game_over_menu.gd
# 게임오버/스테이지 클리어 메뉴. 턴 수 기반 결과를 표시한다.
extends CanvasLayer

@onready var panel: Control = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var score_label: Label = $Panel/VBoxContainer/ScoreLabel
@onready var stars_container: HBoxContainer = $Panel/VBoxContainer/StarsContainer


func _ready() -> void:
	panel.visible = false


# 게임오버 화면을 표시한다.
func show_game_over() -> void:
	title_label.text = "GAME OVER"
	score_label.text = "Turn: %d" % GameManager.turn_count
	_show_stars(0)
	panel.visible = true
	get_tree().paused = true


# 스테이지 클리어 화면을 표시한다.
func show_clear() -> void:
	title_label.text = "STAGE CLEAR!"
	score_label.text = "Turn: %d" % GameManager.turn_count
	var stars := GameManager._calculate_stars()
	_show_stars(stars)
	panel.visible = true
	get_tree().paused = true


# 별 개수를 표시한다.
func _show_stars(count: int) -> void:
	for child in stars_container.get_children():
		child.queue_free()
	var star_tex := preload("res://assets/images/ui/star.png")
	var star_outline_tex := preload("res://assets/images/ui/star_outline.png")
	for i in 3:
		var tex_rect := TextureRect.new()
		tex_rect.texture = star_tex if i < count else star_outline_tex
		tex_rect.custom_minimum_size = Vector2(40, 40)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		stars_container.add_child(tex_rect)


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_stage_select_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")
```

- [ ] **Step 2: 커밋**

```bash
git add scripts/game_over_menu.gd
git commit -m "refactor: GameOverMenu shows turn count and turn-based star rating"
```

---

## Task 10: StageSelect — turn_game_scene으로 전환

**Files:**
- Modify: `scripts/stage_select.gd:114-117` (씬 전환 경로 변경)

- [ ] **Step 1: stage_select.gd의 씬 전환 경로를 변경**

`scripts/stage_select.gd`의 `_on_stage_selected` 함수에서 씬 경로를 변경:

기존:
```gdscript
func _on_stage_selected(level: int) -> void:
	SoundManager.play_sfx(SoundManager.sfx_click)
	GameManager.current_level = level
	get_tree().change_scene_to_file("res://scenes/game_scene.tscn")
```

변경:
```gdscript
func _on_stage_selected(level: int) -> void:
	SoundManager.play_sfx(SoundManager.sfx_click)
	GameManager.current_level = level
	get_tree().change_scene_to_file("res://scenes/turn_game_scene.tscn")
```

- [ ] **Step 2: 커밋**

```bash
git add scripts/stage_select.gd
git commit -m "refactor: StageSelect navigates to TurnGameScene instead of GameScene"
```

---

## Task 11: 레벨 데이터 리뉴얼

**Files:**
- Modify: `data/levels/level_1.json` ~ `data/levels/level_5.json`

- [ ] **Step 1: level_1.json — 입문 (공 1개, 낮은 HP)**

```json
{
  "ball_speed": 400,
  "initial_balls": 1,
  "star_thresholds": [15, 10, 6],
  "bricks": [
    {"row": 0, "col": 1, "hp": 2}, {"row": 0, "col": 3, "hp": 3}, {"row": 0, "col": 5, "hp": 2},
    {"row": 1, "col": 0, "hp": 1}, {"row": 1, "col": 2, "hp": 2}, {"row": 1, "col": 4, "hp": 2}, {"row": 1, "col": 6, "hp": 1},
    {"row": 2, "col": 1, "hp": 1}, {"row": 2, "col": 3, "hp": 1}, {"row": 2, "col": 5, "hp": 1}
  ],
  "ball_items": [
    {"row": 1, "col": 1}, {"row": 1, "col": 5},
    {"row": 2, "col": 2}, {"row": 2, "col": 4}
  ]
}
```

- [ ] **Step 2: level_2.json — 밀집 배치**

```json
{
  "ball_speed": 400,
  "initial_balls": 1,
  "star_thresholds": [18, 12, 8],
  "bricks": [
    {"row": 0, "col": 0, "hp": 3}, {"row": 0, "col": 1, "hp": 5}, {"row": 0, "col": 2, "hp": 3}, {"row": 0, "col": 3, "hp": 5}, {"row": 0, "col": 4, "hp": 3}, {"row": 0, "col": 5, "hp": 5}, {"row": 0, "col": 6, "hp": 3},
    {"row": 1, "col": 0, "hp": 2}, {"row": 1, "col": 1, "hp": 3}, {"row": 1, "col": 2, "hp": 2}, {"row": 1, "col": 3, "hp": 3}, {"row": 1, "col": 4, "hp": 2}, {"row": 1, "col": 5, "hp": 3}, {"row": 1, "col": 6, "hp": 2},
    {"row": 2, "col": 1, "hp": 1}, {"row": 2, "col": 2, "hp": 2}, {"row": 2, "col": 3, "hp": 1}, {"row": 2, "col": 4, "hp": 2}, {"row": 2, "col": 5, "hp": 1}
  ],
  "ball_items": [
    {"row": 0, "col": 3}, {"row": 1, "col": 1}, {"row": 1, "col": 5},
    {"row": 2, "col": 0}, {"row": 2, "col": 6}
  ]
}
```

- [ ] **Step 3: level_3.json — 파괴불가 벽돌 등장**

```json
{
  "ball_speed": 420,
  "initial_balls": 1,
  "star_thresholds": [20, 14, 9],
  "bricks": [
    {"row": 0, "col": 0, "hp": 5}, {"row": 0, "col": 1, "hp": 8}, {"row": 0, "col": 2, "hp": 5}, {"row": 0, "col": 3, "hp": -1}, {"row": 0, "col": 4, "hp": 5}, {"row": 0, "col": 5, "hp": 8}, {"row": 0, "col": 6, "hp": 5},
    {"row": 1, "col": 0, "hp": 3}, {"row": 1, "col": 2, "hp": 5}, {"row": 1, "col": 4, "hp": 5}, {"row": 1, "col": 6, "hp": 3},
    {"row": 2, "col": 0, "hp": 2}, {"row": 2, "col": 1, "hp": 3}, {"row": 2, "col": 2, "hp": 2}, {"row": 2, "col": 3, "hp": 3}, {"row": 2, "col": 4, "hp": 2}, {"row": 2, "col": 5, "hp": 3}, {"row": 2, "col": 6, "hp": 2},
    {"row": 3, "col": 1, "hp": 1}, {"row": 3, "col": 3, "hp": 2}, {"row": 3, "col": 5, "hp": 1}
  ],
  "ball_items": [
    {"row": 1, "col": 1}, {"row": 1, "col": 3}, {"row": 1, "col": 5},
    {"row": 2, "col": 0}, {"row": 3, "col": 2}, {"row": 3, "col": 4}
  ]
}
```

- [ ] **Step 4: level_4.json — 고HP 벽돌**

```json
{
  "ball_speed": 440,
  "initial_balls": 2,
  "star_thresholds": [22, 16, 10],
  "bricks": [
    {"row": 0, "col": 0, "hp": 12}, {"row": 0, "col": 1, "hp": 15}, {"row": 0, "col": 2, "hp": 12}, {"row": 0, "col": 3, "hp": 20}, {"row": 0, "col": 4, "hp": 12}, {"row": 0, "col": 5, "hp": 15}, {"row": 0, "col": 6, "hp": 12},
    {"row": 1, "col": 0, "hp": 8}, {"row": 1, "col": 1, "hp": -1}, {"row": 1, "col": 2, "hp": 10}, {"row": 1, "col": 3, "hp": 8}, {"row": 1, "col": 4, "hp": 10}, {"row": 1, "col": 5, "hp": -1}, {"row": 1, "col": 6, "hp": 8},
    {"row": 2, "col": 0, "hp": 5}, {"row": 2, "col": 1, "hp": 8}, {"row": 2, "col": 2, "hp": 5}, {"row": 2, "col": 3, "hp": 8}, {"row": 2, "col": 4, "hp": 5}, {"row": 2, "col": 5, "hp": 8}, {"row": 2, "col": 6, "hp": 5},
    {"row": 3, "col": 0, "hp": 3}, {"row": 3, "col": 2, "hp": 5}, {"row": 3, "col": 4, "hp": 5}, {"row": 3, "col": 6, "hp": 3}
  ],
  "ball_items": [
    {"row": 0, "col": 1}, {"row": 0, "col": 5},
    {"row": 1, "col": 3}, {"row": 2, "col": 1}, {"row": 2, "col": 5},
    {"row": 3, "col": 1}, {"row": 3, "col": 3}, {"row": 3, "col": 5}
  ]
}
```

- [ ] **Step 5: level_5.json — 최고 난이도**

```json
{
  "ball_speed": 460,
  "initial_balls": 2,
  "star_thresholds": [25, 18, 12],
  "bricks": [
    {"row": 0, "col": 0, "hp": 20}, {"row": 0, "col": 1, "hp": 25}, {"row": 0, "col": 2, "hp": 30}, {"row": 0, "col": 3, "hp": 35}, {"row": 0, "col": 4, "hp": 30}, {"row": 0, "col": 5, "hp": 25}, {"row": 0, "col": 6, "hp": 20},
    {"row": 1, "col": 0, "hp": 15}, {"row": 1, "col": 1, "hp": -1}, {"row": 1, "col": 2, "hp": 20}, {"row": 1, "col": 3, "hp": -1}, {"row": 1, "col": 4, "hp": 20}, {"row": 1, "col": 5, "hp": -1}, {"row": 1, "col": 6, "hp": 15},
    {"row": 2, "col": 0, "hp": 10}, {"row": 2, "col": 1, "hp": 15}, {"row": 2, "col": 2, "hp": 10}, {"row": 2, "col": 3, "hp": 15}, {"row": 2, "col": 4, "hp": 10}, {"row": 2, "col": 5, "hp": 15}, {"row": 2, "col": 6, "hp": 10},
    {"row": 3, "col": 0, "hp": 5}, {"row": 3, "col": 1, "hp": 8}, {"row": 3, "col": 2, "hp": -1}, {"row": 3, "col": 3, "hp": 10}, {"row": 3, "col": 4, "hp": -1}, {"row": 3, "col": 5, "hp": 8}, {"row": 3, "col": 6, "hp": 5},
    {"row": 4, "col": 1, "hp": 3}, {"row": 4, "col": 2, "hp": 5}, {"row": 4, "col": 3, "hp": 3}, {"row": 4, "col": 4, "hp": 5}, {"row": 4, "col": 5, "hp": 3}
  ],
  "ball_items": [
    {"row": 0, "col": 3}, {"row": 1, "col": 0}, {"row": 1, "col": 3}, {"row": 1, "col": 6},
    {"row": 2, "col": 1}, {"row": 2, "col": 5},
    {"row": 3, "col": 3}, {"row": 4, "col": 0}, {"row": 4, "col": 4}, {"row": 4, "col": 6}
  ]
}
```

- [ ] **Step 6: 커밋**

```bash
git add data/levels/
git commit -m "feat: redesign all 5 levels for turn-based gameplay with ball items and star thresholds"
```

---

## Self-Review Checklist

1. **Spec coverage:**
   - Turn loop (AIMING→FIRING→WAITING→TURN_END): Task 7 (TurnGameScene) ✅
   - Launcher (aim + fire): Task 6 ✅
   - Ball (speed normalize, no paddle): Task 4 ✅
   - Brick (HP label, color thresholds): Task 3 ✅
   - Ball items: Task 5 ✅
   - Brick descent: Task 7 (_descend_bricks) ✅
   - Game over (brick at floor): Task 7 (_check_game_over) ✅
   - Star rating (turn-based): Task 1 (GameManager._calculate_stars) ✅
   - Save (lowest turn): Task 2 ✅
   - HUD (turn/balls): Task 8 ✅
   - GameOverMenu (turn display): Task 9 ✅
   - StageSelect (scene switch): Task 10 ✅
   - Level data format: Task 11 ✅

2. **Placeholder scan:** No TBD/TODO found. All code blocks are complete.

3. **Type consistency:**
   - `turn_count` / `ball_count` — consistent across GameManager, HUD, GameOverMenu ✅
   - `turn_changed` / `ball_count_changed` signals — consistent ✅
   - `brick_destroyed(position: Vector2)` — Brick emits, TurnGameScene connects ✅
   - `ball.setup(speed)` / `ball.launch(direction)` — consistent between Ball and Launcher ✅
   - `collected` signal — BallItem emits, TurnGameScene connects ✅
   - `all_balls_fired` signal — Launcher emits, TurnGameScene connects ✅
   - HUD node names: `TurnLabel`, `BallsLabel` — match both .gd and .tscn ✅
