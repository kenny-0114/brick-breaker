# Brick Breaker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Godot 4.6 기반 모바일 벽돌깨기 게임 구현 (TitleScreen → StageSelect → GameScene 플로우, 5개 스테이지, 물리 기반 공, 파워업 2종)

**Architecture:** 물리 기반 접근 — Ball은 RigidBody2D(bounce=1.0), Paddle은 AnimatableBody2D, Brick은 StaticBody2D. 3개 오토로드 싱글톤(GameManager, SaveManager, SoundManager)으로 상태/저장/사운드 분리 관리. 레벨 데이터는 JSON으로 관리하여 확장 용이.

**Tech Stack:** Godot 4.6, GDScript, Kenney Puzzle Pack 2 + UI Pack

**Spec:** `docs/superpowers/specs/2026-03-26-brick-breaker-design.md`

---

## File Map

### New Files

| Path | Responsibility |
|------|----------------|
| `scripts/autoload/save_manager.gd` | 영속 데이터 저장/로드 (해금, 점수, 별, 설정) |
| `scripts/autoload/game_manager.gd` | 게임 중 휘발성 상태 (점수, 라이프, 현재 레벨) |
| `scripts/autoload/sound_manager.gd` | BGM/SFX 재생, 볼륨 제어, AudioStreamPlayer 풀 |
| `scripts/objects/ball.gd` | 공 물리, 발사, 속도 클램핑, 각도 보정 |
| `scripts/objects/paddle.gd` | 터치 입력, X축 이동, 확장 파워업 |
| `scripts/objects/brick.gd` | HP 관리, 텍스처 교체, 파괴 시그널, 파티클 |
| `scripts/objects/power_up.gd` | 낙하, 패들 접촉 감지, 효과 타입 |
| `scripts/game_scene.gd` | 게임 메인 로직, 레벨 로드, 승리/패배 판정 |
| `scripts/title_screen.gd` | 타이틀 UI, 버튼 이벤트 |
| `scripts/stage_select.gd` | 스테이지 그리드 생성, 해금/별 표시 |
| `scenes/objects/ball.tscn` | Ball 씬 |
| `scenes/objects/brick.tscn` | Brick 씬 |
| `scenes/objects/paddle.tscn` | Paddle 씬 |
| `scenes/objects/power_up.tscn` | PowerUp 씬 |
| `scenes/game_scene.tscn` | 메인 게임 씬 |
| `scenes/title_screen.tscn` | 타이틀 화면 씬 |
| `scenes/stage_select.tscn` | 스테이지 선택 씬 |
| `scenes/ui/settings_popup.tscn` | 설정 팝업 씬 |
| `data/levels/level_1.json` ~ `level_5.json` | 레벨 데이터 |

### Modified Files

| Path | Change |
|------|--------|
| `project.godot` | 오토로드 등록, 메인 씬 설정, 오디오 버스, 화면 크기 |

---

## Task 1: 프로젝트 셋업 — 리소스 복사 및 폴더 구조

**Files:**
- Create: `assets/images/bricks/`, `assets/images/ball/`, `assets/images/paddle/`, `assets/images/particles/`, `assets/images/items/`, `assets/images/background/`, `assets/images/ui/`, `assets/fonts/`, `assets/sounds/`, `data/levels/`, `scripts/autoload/`, `scripts/objects/`, `scenes/objects/`, `scenes/ui/`
- Modify: `project.godot`

- [ ] **Step 1: 폴더 구조 생성**

```bash
cd /mnt/e/project/godot/brick-breaker
mkdir -p assets/images/{bricks,ball,paddle,particles,items,background,ui}
mkdir -p assets/fonts assets/sounds
mkdir -p data/levels
mkdir -p scripts/autoload scripts/objects
mkdir -p scenes/objects scenes/ui
```

- [ ] **Step 2: Kenney Puzzle Pack 2에서 필요한 리소스 복사**

```bash
# 벽돌
cp "kenney_puzzle-pack-2/PNG/Tiles green/tileGreen_14.png" assets/images/bricks/
cp "kenney_puzzle-pack-2/PNG/Tiles orange/tileOrange_14.png" assets/images/bricks/
cp "kenney_puzzle-pack-2/PNG/Tiles red/tileRed_14.png" assets/images/bricks/
cp "kenney_puzzle-pack-2/PNG/Tiles grey/tileGrey_14.png" assets/images/bricks/

# 공
cp "kenney_puzzle-pack-2/PNG/Balls/Blue/ballBlue_01.png" assets/images/ball/

# 패들
cp "kenney_puzzle-pack-2/PNG/Paddles/paddle_04.png" assets/images/paddle/

# 파티클
cp kenney_puzzle-pack-2/PNG/Particles\ white/particleWhite_*.png assets/images/particles/

# 아이템
cp "kenney_puzzle-pack-2/PNG/Coins/coin_01.png" assets/images/items/

# 배경
cp "kenney_puzzle-pack-2/PNG/Back tiles/BackTile_01.png" assets/images/background/
```

- [ ] **Step 3: Kenney UI Pack에서 필요한 리소스 복사**

```bash
# 별
cp "kenney_ui-pack/PNG/Yellow/Default/star.png" assets/images/ui/
cp "kenney_ui-pack/PNG/Yellow/Default/star_outline.png" assets/images/ui/

# UI 요소
cp "kenney_ui-pack/PNG/Extra/Default/input_rectangle.png" assets/images/ui/
cp "kenney_ui-pack/PNG/Blue/Default/button_rectangle_depth_flat.png" assets/images/ui/
cp "kenney_ui-pack/PNG/Extra/Default/icon_play_dark.png" assets/images/ui/
cp "kenney_ui-pack/PNG/Extra/Default/icon_repeat_dark.png" assets/images/ui/
cp "kenney_ui-pack/PNG/Extra/Default/divider.png" assets/images/ui/

# 폰트
cp "kenney_ui-pack/Font/Kenney Future.ttf" assets/fonts/
cp "kenney_ui-pack/Font/Kenney Future Narrow.ttf" assets/fonts/

# 사운드
cp kenney_ui-pack/Sounds/click-a.ogg assets/sounds/
cp kenney_ui-pack/Sounds/tap-a.ogg assets/sounds/
```

- [ ] **Step 4: project.godot 업데이트 — 화면 크기, 오디오 버스**

`project.godot`에 모바일 세로 해상도, 오디오 버스 설정 추가:

```ini
[application]
config/name="Brick-Breaker"
config/features=PackedStringArray("4.6", "Mobile")
config/icon="res://icon.svg"
run/main_scene="res://scenes/title_screen.tscn"

[autoload]
SaveManager="*res://scripts/autoload/save_manager.gd"
GameManager="*res://scripts/autoload/game_manager.gd"
SoundManager="*res://scripts/autoload/sound_manager.gd"

[display]
window/size/viewport_width=480
window/size/viewport_height=854
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
window/handheld/orientation=1

[input_devices]
pointing/emulate_touch_from_mouse=true

[physics]
3d/physics_engine="Jolt Physics"

[rendering]
rendering_device/driver.windows="d3d12"
renderer/rendering_method="mobile"
```

- [ ] **Step 5: 커밋**

```bash
git add -A
git commit -m "chore: project setup - copy resources, create folder structure, configure project.godot"
```

---

## Task 2: SaveManager — 영속 데이터 저장/로드

**Files:**
- Create: `scripts/autoload/save_manager.gd`

- [ ] **Step 1: SaveManager 스크립트 작성**

```gdscript
# scripts/autoload/save_manager.gd
# 영속 데이터를 user://save_data.json에 저장/로드한다.
# 해금 레벨, 최고 점수, 별, 설정값을 관리한다.
extends Node

const SAVE_PATH := "user://save_data.json"

# 기본값
var data := {
	"unlocked_level": 1,
	"high_scores": {},
	"stars": {},
	"settings": {
		"bgm_volume": 1.0,
		"sfx_volume": 1.0
	}
}


func _ready() -> void:
	load_data()


# 파일에서 저장 데이터를 읽는다.
func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Failed to open save file: %s" % error_string(FileAccess.get_open_error()))
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("SaveManager: Failed to parse save file: %s" % json.get_error_message())
		return
	var parsed: Variant = json.data
	if parsed is Dictionary:
		_merge_data(parsed)


# 현재 데이터를 파일에 저장한다.
func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Failed to write save file: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))


# 스테이지 클리어 시 결과를 반영한다.
func complete_stage(level: int, score: int, stars_earned: int) -> void:
	var level_key := str(level)
	# 해금 레벨 갱신
	if level + 1 > data["unlocked_level"]:
		data["unlocked_level"] = level + 1
	# 최고 점수 갱신
	var current_high: int = data["high_scores"].get(level_key, 0)
	if score > current_high:
		data["high_scores"][level_key] = score
	# 별 갱신
	var current_stars: int = data["stars"].get(level_key, 0)
	if stars_earned > current_stars:
		data["stars"][level_key] = stars_earned
	save_data()


# 설정값을 저장한다.
func save_settings(bgm_volume: float, sfx_volume: float) -> void:
	data["settings"]["bgm_volume"] = bgm_volume
	data["settings"]["sfx_volume"] = sfx_volume
	save_data()


# 파싱된 데이터를 기본값 위에 안전하게 병합한다.
func _merge_data(parsed: Dictionary) -> void:
	for key in data.keys():
		if parsed.has(key):
			data[key] = parsed[key]
```

- [ ] **Step 2: Godot 에디터에서 프로젝트 열어서 오토로드 확인**

Godot 에디터에서 프로젝트 열기 → Project > Project Settings > Autoload 탭에서 SaveManager가 등록되어 있는지 확인.

- [ ] **Step 3: 커밋**

```bash
git add scripts/autoload/save_manager.gd
git commit -m "feat: add SaveManager autoload - persistent save/load system"
```

---

## Task 3: GameManager — 게임 상태 관리

**Files:**
- Create: `scripts/autoload/game_manager.gd`

- [ ] **Step 1: GameManager 스크립트 작성**

```gdscript
# scripts/autoload/game_manager.gd
# 플레이 중 휘발성 상태를 관리한다.
# 점수, 라이프, 현재 레벨, 파워업 상태를 추적한다.
extends Node

signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal game_over
signal stage_cleared

# 점수 상수
const SCORE_1HP := 100
const SCORE_2HP := 200
const SCORE_3HP := 300
const SCORE_CLEAR_BONUS_PER_LIFE := 500

var current_level: int = 1
var score: int = 0
var lives: int = 3
var is_playing: bool = false


# 새 게임을 시작할 때 상태를 초기화한다.
func start_level(level: int) -> void:
	current_level = level
	score = 0
	lives = 3
	is_playing = true
	score_changed.emit(score)
	lives_changed.emit(lives)


# 벽돌 파괴 시 HP에 따른 점수를 추가한다.
func add_brick_score(hp: int) -> void:
	match hp:
		1: score += SCORE_1HP
		2: score += SCORE_2HP
		3: score += SCORE_3HP
	score_changed.emit(score)


# 공을 잃었을 때 라이프를 감소시킨다.
func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		is_playing = false
		game_over.emit()


# 스테이지 클리어 시 보너스 점수를 추가하고 저장한다.
func clear_stage() -> void:
	is_playing = false
	var bonus := lives * SCORE_CLEAR_BONUS_PER_LIFE
	score += bonus
	score_changed.emit(score)
	SaveManager.complete_stage(current_level, score, lives)
	stage_cleared.emit()
```

- [ ] **Step 2: 커밋**

```bash
git add scripts/autoload/game_manager.gd
git commit -m "feat: add GameManager autoload - score, lives, level state management"
```

---

## Task 4: SoundManager — 사운드 관리

**Files:**
- Create: `scripts/autoload/sound_manager.gd`

- [ ] **Step 1: SoundManager 스크립트 작성**

```gdscript
# scripts/autoload/sound_manager.gd
# BGM/SFX 재생 및 볼륨을 제어한다.
# AudioStreamPlayer 풀로 동시 다발 SFX를 처리한다.
extends Node

const SFX_POOL_SIZE := 5

var _bgm_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

# 프리로드할 UI 사운드
var sfx_click: AudioStream = preload("res://assets/sounds/click-a.ogg")
var sfx_tap: AudioStream = preload("res://assets/sounds/tap-a.ogg")


func _ready() -> void:
	# BGM 버스와 SFX 버스를 추가한다.
	_setup_audio_buses()
	# BGM Player 생성
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "BGM"
	add_child(_bgm_player)
	# SFX Pool 생성
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)
	# 저장된 볼륨 설정을 적용한다.
	_apply_saved_volume()


# BGM과 SFX 오디오 버스를 생성한다.
func _setup_audio_buses() -> void:
	if AudioServer.get_bus_index("BGM") == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(idx, "BGM")
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")


# SFX를 풀에서 하나 골라 재생한다.
func play_sfx(stream: AudioStream) -> void:
	var player := _sfx_pool[_sfx_index]
	player.stream = stream
	player.play()
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE


# BGM을 재생한다.
func play_bgm(stream: AudioStream) -> void:
	if _bgm_player.stream == stream and _bgm_player.playing:
		return
	_bgm_player.stream = stream
	_bgm_player.play()


# BGM을 멈춘다.
func stop_bgm() -> void:
	_bgm_player.stop()


# 볼륨을 설정하고 저장한다. volume은 0.0~1.0 범위이다.
func set_bgm_volume(volume: float) -> void:
	var db := linear_to_db(clampf(volume, 0.0, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("BGM"), db)


func set_sfx_volume(volume: float) -> void:
	var db := linear_to_db(clampf(volume, 0.0, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db)


# 저장된 볼륨 설정을 적용한다.
func _apply_saved_volume() -> void:
	var settings: Dictionary = SaveManager.data.get("settings", {})
	set_bgm_volume(settings.get("bgm_volume", 1.0))
	set_sfx_volume(settings.get("sfx_volume", 1.0))
```

- [ ] **Step 2: 커밋**

```bash
git add scripts/autoload/sound_manager.gd
git commit -m "feat: add SoundManager autoload - BGM/SFX playback with audio bus control"
```

---

## Task 5: Ball — 물리 기반 공

**Files:**
- Create: `scenes/objects/ball.tscn`, `scripts/objects/ball.gd`

- [ ] **Step 1: Ball 스크립트 작성**

```gdscript
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
```

- [ ] **Step 2: Ball 씬 파일 작성**

`scenes/objects/ball.tscn` — RigidBody2D + CircleShape2D + Sprite2D 구성.
Godot 에디터에서 생성:
1. 새 씬 > RigidBody2D (루트, 이름: Ball)
2. 자식으로 Sprite2D 추가 → texture = `res://assets/images/ball/ballBlue_01.png`
3. 자식으로 CollisionShape2D 추가 → shape = CircleShape2D (공 이미지 크기에 맞춤)
4. RigidBody2D 설정: gravity_scale=0, contact_monitor=true, max_contacts_reported=4
5. PhysicsMaterial: bounce=1.0, friction=0.0
6. Script 연결: `res://scripts/objects/ball.gd`
7. 씬 저장

- [ ] **Step 3: 에디터에서 Ball 씬 실행하여 노드 구성 확인**

- [ ] **Step 4: 커밋**

```bash
git add scripts/objects/ball.gd scenes/objects/ball.tscn
git commit -m "feat: add Ball scene - physics-based ball with launch, speed clamp, angle correction"
```

---

## Task 6: Paddle — 터치 입력 패들

**Files:**
- Create: `scenes/objects/paddle.tscn`, `scripts/objects/paddle.gd`

- [ ] **Step 1: Paddle 스크립트 작성**

```gdscript
# scripts/objects/paddle.gd
# 터치/드래그로 X축 이동하는 패들.
# 공의 패들 타격 위치에 따라 반사각을 조정한다.
extends AnimatableBody2D

signal paddle_hit(hit_position: float)

const EXPAND_SCALE := 1.5
const EXPAND_DURATION := 10.0

var _screen_width: float
var _half_width: float
var _is_expanded := false
var _expand_tween: Tween = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_screen_width = get_viewport_rect().size.x
	_update_half_width()


func _input(event: InputEvent) -> void:
	# 터치/마우스 드래그로 패들을 X축으로 이동시킨다.
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if event is InputEventMouseMotion and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return
		var target_x: float = event.position.x
		target_x = clampf(target_x, _half_width, _screen_width - _half_width)
		position.x = target_x


# 공이 패들의 어느 위치를 맞았는지 -1.0~1.0으로 반환한다.
# -1.0은 왼쪽 끝, 0.0은 중앙, 1.0은 오른쪽 끝이다.
func get_hit_factor(ball_x: float) -> float:
	var diff := ball_x - global_position.x
	return clampf(diff / _half_width, -1.0, 1.0)


# 패들 확장 파워업을 적용한다.
func expand() -> void:
	# 이미 확장 중이면 타이머만 리셋한다.
	if _expand_tween and _expand_tween.is_running():
		_expand_tween.kill()
	if not _is_expanded:
		_is_expanded = true
		scale.x = EXPAND_SCALE
		_update_half_width()
	# 지속 시간 후 원복
	_expand_tween = create_tween()
	_expand_tween.tween_interval(EXPAND_DURATION)
	_expand_tween.tween_property(self, "scale:x", 1.0, 0.3)
	_expand_tween.tween_callback(_on_expand_ended)


func _on_expand_ended() -> void:
	_is_expanded = false
	_update_half_width()


# 패들의 실제 반폭을 갱신한다.
func _update_half_width() -> void:
	if collision and collision.shape:
		_half_width = collision.shape.size.x * 0.5 * scale.x
```

- [ ] **Step 2: Paddle 씬 생성**

Godot 에디터에서:
1. 새 씬 > AnimatableBody2D (루트, 이름: Paddle)
2. 자식으로 Sprite2D 추가 → texture = `res://assets/images/paddle/paddle_04.png`
3. 자식으로 CollisionShape2D 추가 → shape = RectangleShape2D (패들 이미지 크기에 맞춤)
4. Script 연결: `res://scripts/objects/paddle.gd`
5. 씬 저장

- [ ] **Step 3: 커밋**

```bash
git add scripts/objects/paddle.gd scenes/objects/paddle.tscn
git commit -m "feat: add Paddle scene - touch input, hit factor, expand powerup"
```

---

## Task 7: Brick — HP 벽돌

**Files:**
- Create: `scenes/objects/brick.tscn`, `scripts/objects/brick.gd`

- [ ] **Step 1: Brick 스크립트 작성**

```gdscript
# scripts/objects/brick.gd
# HP를 가진 벽돌. 공에 맞으면 HP가 감소하고 텍스처가 바뀐다.
# HP가 0이 되면 파괴되며 점수와 아이템 드롭 시그널을 발생시킨다.
extends StaticBody2D

signal brick_destroyed(position: Vector2, hp: int)

const TEXTURES := {
	1: preload("res://assets/images/bricks/tileGreen_14.png"),
	2: preload("res://assets/images/bricks/tileOrange_14.png"),
	3: preload("res://assets/images/bricks/tileRed_14.png"),
	-1: preload("res://assets/images/bricks/tileGrey_14.png"),
}

var hp: int = 1
var max_hp: int = 1
var is_indestructible: bool = false

@onready var sprite: Sprite2D = $Sprite2D


# 벽돌의 HP와 텍스처를 초기화한다.
func setup(brick_hp: int) -> void:
	hp = brick_hp
	if hp == -1:
		is_indestructible = true
		max_hp = -1
	else:
		max_hp = hp
	_update_texture()


# 공에 맞았을 때 호출된다. HP를 감소시키고 파괴 여부를 판정한다.
func hit() -> void:
	if is_indestructible:
		return
	hp -= 1
	if hp <= 0:
		brick_destroyed.emit(global_position, max_hp)
		queue_free()
	else:
		_update_texture()
		_play_hit_effect()


# HP에 맞는 텍스처로 교체한다.
func _update_texture() -> void:
	if sprite and TEXTURES.has(hp):
		sprite.texture = TEXTURES[hp]


# 피격 시 흰색 플래시 효과를 재생한다.
func _play_hit_effect() -> void:
	var tween := create_tween()
	sprite.modulate = Color.WHITE * 2.0
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
```

- [ ] **Step 2: Brick 씬 생성**

Godot 에디터에서:
1. 새 씬 > StaticBody2D (루트, 이름: Brick)
2. 자식으로 Sprite2D 추가 → texture = `res://assets/images/bricks/tileGreen_14.png` (기본)
3. 자식으로 CollisionShape2D 추가 → shape = RectangleShape2D (벽돌 이미지 크기에 맞춤)
4. Script 연결: `res://scripts/objects/brick.gd`
5. 씬 저장

- [ ] **Step 3: 커밋**

```bash
git add scripts/objects/brick.gd scenes/objects/brick.tscn
git commit -m "feat: add Brick scene - HP system with texture swap, destroy signal"
```

---

## Task 8: PowerUp — 파워업 아이템

**Files:**
- Create: `scenes/objects/power_up.tscn`, `scripts/objects/power_up.gd`

- [ ] **Step 1: PowerUp 스크립트 작성**

```gdscript
# scripts/objects/power_up.gd
# 벽돌 파괴 시 드롭되는 파워업 아이템.
# 중력으로 낙하하며 패들에 닿으면 효과를 발동한다.
extends Area2D

enum Type { EXPAND, MULTI_BALL }

signal collected(type: Type)

const FALL_SPEED := 150.0
const TINT_EXPAND := Color(0.3, 0.9, 0.3)
const TINT_MULTI := Color(0.3, 0.6, 1.0)

var type: Type = Type.EXPAND

@onready var sprite: Sprite2D = $Sprite2D


# 파워업 타입을 설정하고 시각적 구분을 적용한다.
func setup(powerup_type: Type) -> void:
	type = powerup_type
	if sprite:
		match type:
			Type.EXPAND:
				sprite.modulate = TINT_EXPAND
			Type.MULTI_BALL:
				sprite.modulate = TINT_MULTI


func _physics_process(delta: float) -> void:
	position.y += FALL_SPEED * delta


# 패들과 접촉 시 수집 처리한다.
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("paddle"):
		collected.emit(type)
		SoundManager.play_sfx(SoundManager.sfx_tap)
		queue_free()


# 화면 밖으로 나가면 제거한다.
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
```

- [ ] **Step 2: PowerUp 씬 생성**

Godot 에디터에서:
1. 새 씬 > Area2D (루트, 이름: PowerUp)
2. 자식으로 Sprite2D 추가 → texture = `res://assets/images/items/coin_01.png`
3. 자식으로 CollisionShape2D 추가 → shape = CircleShape2D
4. 자식으로 VisibleOnScreenNotifier2D 추가
5. body_entered 시그널 → `_on_body_entered` 연결
6. VisibleOnScreenNotifier2D의 screen_exited 시그널 → `_on_visible_on_screen_notifier_2d_screen_exited` 연결
7. Script 연결: `res://scripts/objects/power_up.gd`
8. 씬 저장

- [ ] **Step 3: 커밋**

```bash
git add scripts/objects/power_up.gd scenes/objects/power_up.tscn
git commit -m "feat: add PowerUp scene - falling item with expand/multi-ball types"
```

---

## Task 9: Level Data — JSON 레벨 파일 5개

**Files:**
- Create: `data/levels/level_1.json` ~ `data/levels/level_5.json`

- [ ] **Step 1: Level 1 — 튜토리얼 (1HP 위주)**

```json
{
  "level": 1,
  "lives": 3,
  "ball_speed": 250,
  "bricks": [
    {"row": 0, "col": 0, "hp": 1}, {"row": 0, "col": 1, "hp": 1}, {"row": 0, "col": 2, "hp": 1}, {"row": 0, "col": 3, "hp": 1}, {"row": 0, "col": 4, "hp": 1}, {"row": 0, "col": 5, "hp": 1}, {"row": 0, "col": 6, "hp": 1},
    {"row": 1, "col": 0, "hp": 1}, {"row": 1, "col": 1, "hp": 1}, {"row": 1, "col": 2, "hp": 1}, {"row": 1, "col": 3, "hp": 1}, {"row": 1, "col": 4, "hp": 1}, {"row": 1, "col": 5, "hp": 1}, {"row": 1, "col": 6, "hp": 1},
    {"row": 2, "col": 1, "hp": 1}, {"row": 2, "col": 2, "hp": 1}, {"row": 2, "col": 3, "hp": 1}, {"row": 2, "col": 4, "hp": 1}, {"row": 2, "col": 5, "hp": 1}
  ]
}
```

- [ ] **Step 2: Level 2 — 1HP + 2HP 혼합**

```json
{
  "level": 2,
  "lives": 3,
  "ball_speed": 300,
  "bricks": [
    {"row": 0, "col": 0, "hp": 2}, {"row": 0, "col": 1, "hp": 1}, {"row": 0, "col": 2, "hp": 2}, {"row": 0, "col": 3, "hp": 1}, {"row": 0, "col": 4, "hp": 2}, {"row": 0, "col": 5, "hp": 1}, {"row": 0, "col": 6, "hp": 2},
    {"row": 1, "col": 0, "hp": 1}, {"row": 1, "col": 1, "hp": 2}, {"row": 1, "col": 2, "hp": 1}, {"row": 1, "col": 3, "hp": 2}, {"row": 1, "col": 4, "hp": 1}, {"row": 1, "col": 5, "hp": 2}, {"row": 1, "col": 6, "hp": 1},
    {"row": 2, "col": 0, "hp": 1}, {"row": 2, "col": 1, "hp": 1}, {"row": 2, "col": 2, "hp": 1}, {"row": 2, "col": 3, "hp": 1}, {"row": 2, "col": 4, "hp": 1}, {"row": 2, "col": 5, "hp": 1}, {"row": 2, "col": 6, "hp": 1},
    {"row": 3, "col": 1, "hp": 1}, {"row": 3, "col": 2, "hp": 1}, {"row": 3, "col": 4, "hp": 1}, {"row": 3, "col": 5, "hp": 1}
  ]
}
```

- [ ] **Step 3: Level 3 — 1~3HP + 파괴불가 등장**

```json
{
  "level": 3,
  "lives": 3,
  "ball_speed": 300,
  "bricks": [
    {"row": 0, "col": 0, "hp": -1}, {"row": 0, "col": 1, "hp": 3}, {"row": 0, "col": 2, "hp": 3}, {"row": 0, "col": 3, "hp": 3}, {"row": 0, "col": 4, "hp": 3}, {"row": 0, "col": 5, "hp": 3}, {"row": 0, "col": 6, "hp": -1},
    {"row": 1, "col": 0, "hp": 2}, {"row": 1, "col": 1, "hp": 2}, {"row": 1, "col": 2, "hp": 1}, {"row": 1, "col": 3, "hp": 2}, {"row": 1, "col": 4, "hp": 1}, {"row": 1, "col": 5, "hp": 2}, {"row": 1, "col": 6, "hp": 2},
    {"row": 2, "col": 0, "hp": 1}, {"row": 2, "col": 1, "hp": 1}, {"row": 2, "col": 2, "hp": 1}, {"row": 2, "col": 3, "hp": -1}, {"row": 2, "col": 4, "hp": 1}, {"row": 2, "col": 5, "hp": 1}, {"row": 2, "col": 6, "hp": 1},
    {"row": 3, "col": 1, "hp": 1}, {"row": 3, "col": 2, "hp": 1}, {"row": 3, "col": 4, "hp": 1}, {"row": 3, "col": 5, "hp": 1}
  ]
}
```

- [ ] **Step 4: Level 4 — 2~3HP 위주 + 파괴불가**

```json
{
  "level": 4,
  "lives": 3,
  "ball_speed": 370,
  "bricks": [
    {"row": 0, "col": 0, "hp": -1}, {"row": 0, "col": 1, "hp": 3}, {"row": 0, "col": 2, "hp": 3}, {"row": 0, "col": 3, "hp": -1}, {"row": 0, "col": 4, "hp": 3}, {"row": 0, "col": 5, "hp": 3}, {"row": 0, "col": 6, "hp": -1},
    {"row": 1, "col": 0, "hp": 3}, {"row": 1, "col": 1, "hp": 2}, {"row": 1, "col": 2, "hp": 3}, {"row": 1, "col": 3, "hp": 2}, {"row": 1, "col": 4, "hp": 3}, {"row": 1, "col": 5, "hp": 2}, {"row": 1, "col": 6, "hp": 3},
    {"row": 2, "col": 0, "hp": 2}, {"row": 2, "col": 1, "hp": 2}, {"row": 2, "col": 2, "hp": 2}, {"row": 2, "col": 3, "hp": 2}, {"row": 2, "col": 4, "hp": 2}, {"row": 2, "col": 5, "hp": 2}, {"row": 2, "col": 6, "hp": 2},
    {"row": 3, "col": 0, "hp": 2}, {"row": 3, "col": 1, "hp": -1}, {"row": 3, "col": 2, "hp": 2}, {"row": 3, "col": 3, "hp": 2}, {"row": 3, "col": 4, "hp": 2}, {"row": 3, "col": 5, "hp": -1}, {"row": 3, "col": 6, "hp": 2},
    {"row": 4, "col": 1, "hp": 2}, {"row": 4, "col": 2, "hp": 2}, {"row": 4, "col": 3, "hp": 3}, {"row": 4, "col": 4, "hp": 2}, {"row": 4, "col": 5, "hp": 2}
  ]
}
```

- [ ] **Step 5: Level 5 — 3HP + 파괴불가 복합 (최종)**

```json
{
  "level": 5,
  "lives": 3,
  "ball_speed": 400,
  "bricks": [
    {"row": 0, "col": 0, "hp": -1}, {"row": 0, "col": 1, "hp": -1}, {"row": 0, "col": 2, "hp": 3}, {"row": 0, "col": 3, "hp": 3}, {"row": 0, "col": 4, "hp": 3}, {"row": 0, "col": 5, "hp": -1}, {"row": 0, "col": 6, "hp": -1},
    {"row": 1, "col": 0, "hp": -1}, {"row": 1, "col": 1, "hp": 3}, {"row": 1, "col": 2, "hp": 3}, {"row": 1, "col": 3, "hp": -1}, {"row": 1, "col": 4, "hp": 3}, {"row": 1, "col": 5, "hp": 3}, {"row": 1, "col": 6, "hp": -1},
    {"row": 2, "col": 0, "hp": 3}, {"row": 2, "col": 1, "hp": 3}, {"row": 2, "col": 2, "hp": 3}, {"row": 2, "col": 3, "hp": 3}, {"row": 2, "col": 4, "hp": 3}, {"row": 2, "col": 5, "hp": 3}, {"row": 2, "col": 6, "hp": 3},
    {"row": 3, "col": 0, "hp": -1}, {"row": 3, "col": 1, "hp": 3}, {"row": 3, "col": 2, "hp": 3}, {"row": 3, "col": 3, "hp": -1}, {"row": 3, "col": 4, "hp": 3}, {"row": 3, "col": 5, "hp": 3}, {"row": 3, "col": 6, "hp": -1},
    {"row": 4, "col": 0, "hp": 3}, {"row": 4, "col": 1, "hp": 3}, {"row": 4, "col": 2, "hp": -1}, {"row": 4, "col": 3, "hp": 3}, {"row": 4, "col": 4, "hp": -1}, {"row": 4, "col": 5, "hp": 3}, {"row": 4, "col": 6, "hp": 3},
    {"row": 5, "col": 1, "hp": 3}, {"row": 5, "col": 2, "hp": 3}, {"row": 5, "col": 3, "hp": 3}, {"row": 5, "col": 4, "hp": 3}, {"row": 5, "col": 5, "hp": 3}
  ]
}
```

- [ ] **Step 6: 커밋**

```bash
git add data/levels/
git commit -m "feat: add 5 level JSON files - progressive difficulty curve"
```

---

## Task 10: GameScene — 메인 게임 로직

**Files:**
- Create: `scenes/game_scene.tscn`, `scripts/game_scene.gd`

- [ ] **Step 1: GameScene 스크립트 작성**

```gdscript
# scripts/game_scene.gd
# 메인 게임 씬. 레벨 로드, 벽돌 생성, 승리/패배 판정, 파워업 처리를 담당한다.
extends Node2D

const BRICK_SCENE := preload("res://scenes/objects/brick.tscn")
const BALL_SCENE := preload("res://scenes/objects/ball.tscn")
const POWERUP_SCENE := preload("res://scenes/objects/power_up.tscn")

const GRID_COLS := 7
const BRICK_MARGIN := 4.0
const GRID_TOP_OFFSET := 80.0
const POWERUP_DROP_CHANCE := 0.2

var _ball_speed := 300.0
var _remaining_bricks := 0

@onready var paddle: AnimatableBody2D = $Paddle
@onready var brick_container: Node2D = $BrickContainer
@onready var item_container: Node2D = $ItemContainer
@onready var ball_container: Node2D = $BallContainer
@onready var death_zone: Area2D = $DeathZone
@onready var hud := $HUD
@onready var pause_menu := $PauseMenu
@onready var game_over_menu := $GameOverMenu


func _ready() -> void:
	GameManager.game_over.connect(_on_game_over)
	GameManager.stage_cleared.connect(_on_stage_cleared)
	_load_level(GameManager.current_level)
	_spawn_ball()


func _input(event: InputEvent) -> void:
	# 터치/클릭으로 공 발사
	if event is InputEventScreenTouch and event.pressed:
		_launch_all_balls()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_launch_all_balls()


# JSON에서 레벨 데이터를 읽어 벽돌을 배치한다.
func _load_level(level: int) -> void:
	var path := "res://data/levels/level_%d.json" % level
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameScene: Level file not found: %s" % path)
		return
	var json := JSON.new()
	json.parse(file.get_as_text())
	var data: Dictionary = json.data

	GameManager.start_level(level)
	_ball_speed = data.get("ball_speed", 300)
	_remaining_bricks = 0

	# 벽돌 크기 계산
	var viewport_width := get_viewport_rect().size.x
	var brick_width := (viewport_width - BRICK_MARGIN * (GRID_COLS + 1)) / GRID_COLS

	for brick_data: Dictionary in data["bricks"]:
		var brick: StaticBody2D = BRICK_SCENE.instantiate()
		var row: int = brick_data["row"]
		var col: int = brick_data["col"]
		var hp: int = brick_data["hp"]

		brick.position = Vector2(
			BRICK_MARGIN + col * (brick_width + BRICK_MARGIN) + brick_width * 0.5,
			GRID_TOP_OFFSET + row * (brick_width * 0.5 + BRICK_MARGIN)
		)
		brick_container.add_child(brick)
		brick.setup(hp)

		if hp != -1:
			_remaining_bricks += 1
			brick.brick_destroyed.connect(_on_brick_destroyed)


# 새 공을 생성하여 패들 위에 배치한다.
func _spawn_ball() -> void:
	var ball: RigidBody2D = BALL_SCENE.instantiate()
	ball_container.add_child(ball)
	ball.setup(paddle, _ball_speed)


# 대기 중인 모든 공을 발사한다.
func _launch_all_balls() -> void:
	for ball: Node in ball_container.get_children():
		if ball.has_method("launch"):
			ball.launch()


# 벽돌 파괴 시 점수 추가, 아이템 드롭, 클리어 판정을 처리한다.
func _on_brick_destroyed(pos: Vector2, hp: int) -> void:
	GameManager.add_brick_score(hp)
	_remaining_bricks -= 1
	_spawn_particles(pos)
	# 아이템 드롭
	if randf() < POWERUP_DROP_CHANCE:
		_spawn_powerup(pos)
	# 클리어 판정
	if _remaining_bricks <= 0:
		GameManager.clear_stage()


# 파괴 파티클을 생성한다.
func _spawn_particles(pos: Vector2) -> void:
	var particles := GPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.4
	# ParticleProcessMaterial로 간단한 폭발 효과
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 50.0
	mat.initial_velocity_max = 150.0
	mat.gravity = Vector3(0, 200, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.0
	particles.process_material = mat
	particles.texture = preload("res://assets/images/particles/particleWhite_1.png")
	add_child(particles)
	# 파티클 재생 완료 후 자동 제거
	get_tree().create_timer(0.5).timeout.connect(particles.queue_free)


# 파워업 아이템을 생성한다.
func _spawn_powerup(pos: Vector2) -> void:
	var powerup: Area2D = POWERUP_SCENE.instantiate()
	powerup.position = pos
	var type: int = randi() % 2  # 0: EXPAND, 1: MULTI_BALL
	item_container.add_child(powerup)
	powerup.setup(type)
	powerup.collected.connect(_on_powerup_collected)


# 파워업 수집 시 효과를 적용한다.
func _on_powerup_collected(type: int) -> void:
	match type:
		0:  # EXPAND
			paddle.expand()
		1:  # MULTI_BALL
			_spawn_multi_balls()


# 멀티볼: 기존 공 기준으로 ±30도 방향으로 2개를 추가 생성한다.
func _spawn_multi_balls() -> void:
	var existing_balls := ball_container.get_children()
	if existing_balls.is_empty():
		return
	var ref_ball: RigidBody2D = existing_balls[0]
	for angle_offset in [-30.0, 30.0]:
		var new_ball: RigidBody2D = BALL_SCENE.instantiate()
		ball_container.add_child(new_ball)
		new_ball.global_position = ref_ball.global_position
		new_ball.freeze = false
		new_ball._is_launched = true
		var rotated_vel := ref_ball.linear_velocity.rotated(deg_to_rad(angle_offset))
		new_ball.linear_velocity = rotated_vel


# DeathZone에 공이 들어오면 제거하고 라이프를 판정한다.
func _on_death_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		body.queue_free()
		# 모든 공이 사라졌는지 확인 (다음 프레임에서 체크)
		await get_tree().process_frame
		if ball_container.get_child_count() == 0:
			GameManager.lose_life()
			if GameManager.is_playing:
				_spawn_ball()


func _on_game_over() -> void:
	game_over_menu.show_game_over()


func _on_stage_cleared() -> void:
	game_over_menu.show_clear()
```

- [ ] **Step 2: GameScene 씬 생성**

Godot 에디터에서:
1. 새 씬 > Node2D (루트, 이름: GameScene)
2. 자식 노드 추가:
   - `ColorRect` (이름: Background) — 게임 배경색 또는 BackTile 텍스처
   - `StaticBody2D` (이름: WallLeft) + CollisionShape2D — 왼쪽 벽
   - `StaticBody2D` (이름: WallRight) + CollisionShape2D — 오른쪽 벽
   - `StaticBody2D` (이름: WallTop) + CollisionShape2D — 상단 벽
   - `Area2D` (이름: DeathZone) + CollisionShape2D — 하단 감지 영역
   - Paddle 씬 인스턴스 (이름: Paddle) — 화면 하단에 배치
   - `Node2D` (이름: BrickContainer)
   - `Node2D` (이름: ItemContainer)
   - `Node2D` (이름: BallContainer)
   - `CanvasLayer` (이름: HUD) — Task 11에서 구성
   - `CanvasLayer` (이름: PauseMenu) — Task 12에서 구성
   - `CanvasLayer` (이름: GameOverMenu) — Task 12에서 구성
3. Paddle을 "paddle" 그룹에 추가
4. DeathZone의 body_entered 시그널 → `_on_death_zone_body_entered` 연결
5. Wall들의 CollisionShape2D를 화면 가장자리에 맞게 배치
6. Script 연결: `res://scripts/game_scene.gd`
7. 씬 저장

- [ ] **Step 3: Ball 씬에 "ball" 그룹 추가**

Ball 씬 에디터에서 루트 노드에 "ball" 그룹 추가.

- [ ] **Step 4: 에디터에서 GameScene 실행하여 벽돌 생성, 공 발사, 벽돌 파괴 확인**

- [ ] **Step 5: 커밋**

```bash
git add scripts/game_scene.gd scenes/game_scene.tscn scenes/objects/ball.tscn
git commit -m "feat: add GameScene - level loading, brick spawning, game logic, powerup system"
```

---

## Task 11: HUD — 점수/라이프/레벨 표시

**Files:**
- Create: `scripts/hud.gd` (GameScene 내 HUD CanvasLayer에 연결)

- [ ] **Step 1: HUD 스크립트 작성**

```gdscript
# scripts/hud.gd
# 게임 중 점수, 라이프, 레벨을 표시한다.
extends CanvasLayer

@onready var score_label: Label = $MarginContainer/HBoxContainer/ScoreLabel
@onready var level_label: Label = $MarginContainer/HBoxContainer/LevelLabel
@onready var lives_label: Label = $MarginContainer/HBoxContainer/LivesLabel
@onready var pause_button: TextureButton = $MarginContainer/HBoxContainer/PauseButton


func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	_update_level()
	_on_score_changed(GameManager.score)
	_on_lives_changed(GameManager.lives)


func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score


func _on_lives_changed(new_lives: int) -> void:
	# 하트 문자로 라이프 표시
	lives_label.text = ""
	for i in new_lives:
		lives_label.text += "♥ "


func _update_level() -> void:
	level_label.text = "Level %d" % GameManager.current_level


# 일시정지 버튼을 눌렀을 때 PauseMenu를 토글한다.
func _on_pause_pressed() -> void:
	var pause_menu := get_parent().get_node("PauseMenu")
	if pause_menu:
		pause_menu.toggle_pause()
```

- [ ] **Step 2: GameScene 씬의 HUD CanvasLayer 내부 구성**

에디터에서 HUD CanvasLayer 하위:
1. `MarginContainer` 추가 (전체 화면 앵커)
2. `HBoxContainer` 추가 (상단 정렬)
3. `Label` (ScoreLabel), `Label` (LevelLabel), `Label` (LivesLabel), `TextureButton` (PauseButton) 추가
4. 폰트: `Kenney Future Narrow.ttf` 설정
5. PauseButton의 pressed 시그널 → `_on_pause_pressed` 연결
6. Script 연결: `res://scripts/hud.gd`

- [ ] **Step 3: 커밋**

```bash
git add scripts/hud.gd
git commit -m "feat: add HUD - score, lives, level display with GameManager signals"
```

---

## Task 12: PauseMenu & GameOverMenu

**Files:**
- Create: `scripts/pause_menu.gd`, `scripts/game_over_menu.gd`

- [ ] **Step 1: PauseMenu 스크립트 작성**

```gdscript
# scripts/pause_menu.gd
# 일시정지 메뉴. 재개, 설정, 스테이지 선택 버튼을 제공한다.
extends CanvasLayer

@onready var panel: Control = $Panel


func _ready() -> void:
	panel.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()


# 일시정지 상태를 토글한다.
func toggle_pause() -> void:
	var is_paused := not get_tree().paused
	get_tree().paused = is_paused
	panel.visible = is_paused


func _on_resume_pressed() -> void:
	toggle_pause()


func _on_stage_select_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func _on_settings_pressed() -> void:
	$SettingsPopup.show_popup()
```

- [ ] **Step 2: GameOverMenu 스크립트 작성**

```gdscript
# scripts/game_over_menu.gd
# 게임오버/스테이지 클리어 메뉴. 결과에 따라 다른 메시지를 보여준다.
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
	score_label.text = "Score: %d" % GameManager.score
	_show_stars(0)
	panel.visible = true
	get_tree().paused = true


# 스테이지 클리어 화면을 표시한다.
func show_clear() -> void:
	title_label.text = "STAGE CLEAR!"
	score_label.text = "Score: %d" % GameManager.score
	_show_stars(GameManager.lives)
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

- [ ] **Step 3: GameScene 씬에 PauseMenu/GameOverMenu UI 노드 구성**

에디터에서:
- PauseMenu CanvasLayer → Panel(Control) → VBoxContainer → ResumeButton, SettingsButton, StageSelectButton
- GameOverMenu CanvasLayer → Panel(Control) → VBoxContainer → TitleLabel, ScoreLabel, StarsContainer(HBox), RetryButton, StageSelectButton
- 버튼에 `NinePatchRect`(`input_rectangle.png`) 배경 적용
- `process_mode = PROCESS_MODE_ALWAYS` 설정 (pause 중에도 작동)

- [ ] **Step 4: 커밋**

```bash
git add scripts/pause_menu.gd scripts/game_over_menu.gd
git commit -m "feat: add PauseMenu and GameOverMenu with star display"
```

---

## Task 13: TitleScreen — 타이틀 화면

**Files:**
- Create: `scenes/title_screen.tscn`, `scripts/title_screen.gd`

- [ ] **Step 1: TitleScreen 스크립트 작성**

```gdscript
# scripts/title_screen.gd
# 게임 타이틀 화면. Play 버튼으로 스테이지 선택, Settings 버튼으로 설정 팝업을 연다.
extends Control


func _on_play_pressed() -> void:
	SoundManager.play_sfx(SoundManager.sfx_click)
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")


func _on_settings_pressed() -> void:
	SoundManager.play_sfx(SoundManager.sfx_click)
	$SettingsPopup.show_popup()
```

- [ ] **Step 2: TitleScreen 씬 생성**

에디터에서:
1. 새 씬 > Control (루트, 이름: TitleScreen, Full Rect 앵커)
2. `ColorRect` (배경색)
3. `VBoxContainer` (중앙 정렬)
   - `Label` (TitleLabel) — "BRICK BREAKER", Kenney Future 폰트, 큰 사이즈
   - `Label` (SubtitleLabel) — "A Classic Arcade Game"
   - `TextureButton` (PlayButton) — `button_rectangle_depth_flat.png`, "PLAY" 텍스트
   - `TextureButton` (SettingsButton) — 회색 버튼, "Settings" 텍스트
4. 버튼의 pressed 시그널 연결
5. Script 연결: `res://scripts/title_screen.gd`
6. 씬 저장

- [ ] **Step 3: 커밋**

```bash
git add scripts/title_screen.gd scenes/title_screen.tscn
git commit -m "feat: add TitleScreen - play and settings buttons"
```

---

## Task 14: StageSelect — 스테이지 선택 화면

**Files:**
- Create: `scenes/stage_select.tscn`, `scripts/stage_select.gd`

- [ ] **Step 1: StageSelect 스크립트 작성**

```gdscript
# scripts/stage_select.gd
# 스테이지 선택 화면. 해금 상태와 별을 표시하고 선택 시 게임을 시작한다.
extends Control

const TOTAL_LEVELS := 5

var star_tex := preload("res://assets/images/ui/star.png")
var star_outline_tex := preload("res://assets/images/ui/star_outline.png")

@onready var stage_grid: GridContainer = $VBoxContainer/StageGrid


func _ready() -> void:
	_build_stage_buttons()


# 스테이지 버튼을 동적으로 생성한다.
func _build_stage_buttons() -> void:
	var unlocked: int = SaveManager.data["unlocked_level"]
	var stars_data: Dictionary = SaveManager.data.get("stars", {})
	var high_scores: Dictionary = SaveManager.data.get("high_scores", {})

	for i in TOTAL_LEVELS:
		var level := i + 1
		var is_unlocked := level <= unlocked
		var btn := _create_stage_button(level, is_unlocked, stars_data, high_scores)
		stage_grid.add_child(btn)


# 개별 스테이지 버튼을 생성한다.
func _create_stage_button(level: int, is_unlocked: bool, stars_data: Dictionary, high_scores: Dictionary) -> Control:
	var container := VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.custom_minimum_size = Vector2(80, 90)

	# 버튼
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(70, 70)
	if is_unlocked:
		btn.text = str(level)
		btn.pressed.connect(_on_stage_selected.bind(level))
	else:
		btn.text = "🔒"
		btn.disabled = true
	container.add_child(btn)

	# 별 표시
	var stars_hbox := HBoxContainer.new()
	stars_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var earned_stars: int = stars_data.get(str(level), 0)
	for j in 3:
		var tex_rect := TextureRect.new()
		tex_rect.texture = star_tex if j < earned_stars else star_outline_tex
		tex_rect.custom_minimum_size = Vector2(18, 18)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		stars_hbox.add_child(tex_rect)
	container.add_child(stars_hbox)

	return container


func _on_stage_selected(level: int) -> void:
	SoundManager.play_sfx(SoundManager.sfx_click)
	GameManager.current_level = level
	get_tree().change_scene_to_file("res://scenes/game_scene.tscn")


func _on_back_pressed() -> void:
	SoundManager.play_sfx(SoundManager.sfx_click)
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
```

- [ ] **Step 2: StageSelect 씬 생성**

에디터에서:
1. 새 씬 > Control (루트, 이름: StageSelect, Full Rect 앵커)
2. `ColorRect` (배경색)
3. `VBoxContainer` (중앙 정렬)
   - `Label` (HeaderLabel) — "STAGE SELECT"
   - `GridContainer` (StageGrid) — columns=3
   - `Button` (BackButton) — "← Back"
4. 버튼 시그널 연결
5. Script 연결: `res://scripts/stage_select.gd`
6. 씬 저장

- [ ] **Step 3: 커밋**

```bash
git add scripts/stage_select.gd scenes/stage_select.tscn
git commit -m "feat: add StageSelect - dynamic stage grid with unlock and star display"
```

---

## Task 15: SettingsPopup — 설정 팝업

**Files:**
- Create: `scenes/ui/settings_popup.tscn`, `scripts/settings_popup.gd`

- [ ] **Step 1: SettingsPopup 스크립트 작성**

```gdscript
# scripts/settings_popup.gd
# BGM/SFX 볼륨 조절 팝업. TitleScreen과 PauseMenu에서 사용한다.
extends Control

@onready var panel: Control = $Panel
@onready var bgm_slider: HSlider = $Panel/VBoxContainer/BGMSlider
@onready var sfx_slider: HSlider = $Panel/VBoxContainer/SFXSlider


func _ready() -> void:
	visible = false
	var settings: Dictionary = SaveManager.data.get("settings", {})
	bgm_slider.value = settings.get("bgm_volume", 1.0)
	sfx_slider.value = settings.get("sfx_volume", 1.0)


# 팝업을 연다.
func show_popup() -> void:
	visible = true


func _on_bgm_slider_value_changed(value: float) -> void:
	SoundManager.set_bgm_volume(value)


func _on_sfx_slider_value_changed(value: float) -> void:
	SoundManager.set_sfx_volume(value)


func _on_close_pressed() -> void:
	SaveManager.save_settings(bgm_slider.value, sfx_slider.value)
	visible = false
```

- [ ] **Step 2: SettingsPopup 씬 생성**

에디터에서:
1. 새 씬 > Control (루트, 이름: SettingsPopup)
2. Panel (NinePatchRect + `input_rectangle.png`)
3. VBoxContainer
   - Label ("Settings")
   - Label ("BGM") + HSlider (0~1, step 0.05)
   - Label ("SFX") + HSlider (0~1, step 0.05)
   - Button (CloseButton — "Close")
4. 시그널 연결
5. Script 연결: `res://scripts/settings_popup.gd`
6. TitleScreen과 PauseMenu 씬 모두에 이 씬을 자식 인스턴스로 추가
7. PauseMenu의 SettingsButton pressed 시그널 → `_on_settings_pressed` 연결 확인

- [ ] **Step 3: 커밋**

```bash
git add scripts/settings_popup.gd scenes/ui/settings_popup.tscn
git commit -m "feat: add SettingsPopup - BGM/SFX volume control with save"
```

---

## Task 16: 패들 반사각 보정 및 통합 테스트

**Files:**
- Modify: `scripts/objects/ball.gd`, `scripts/game_scene.gd`

- [ ] **Step 1: Ball에 패들 타격 위치 반사각 보정 추가**

`ball.gd`에 패들 충돌 감지 추가:

```gdscript
# ball.gd에 추가할 함수
# 패들 타격 위치에 따라 반사 방향을 보정한다.
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("paddle"):
		var hit_factor: float = body.get_hit_factor(global_position.x)
		var speed := linear_velocity.length()
		var max_angle := deg_to_rad(75.0)
		var angle := hit_factor * max_angle
		linear_velocity = Vector2(sin(angle), -cos(angle)).normalized() * speed
```

Ball의 `body_entered` 시그널을 `_on_body_entered`에 연결. (Ball 씬에서 contact_monitor=true, max_contacts_reported=4 필요)

- [ ] **Step 2: 전체 게임 플로우 테스트**

에디터에서 프로젝트 실행:
1. TitleScreen → Play → StageSelect 이동 확인
2. Stage 1 선택 → GameScene 진입 확인
3. 터치/클릭으로 공 발사 확인
4. 공이 벽돌 파괴 시 점수 증가, 텍스처 변화 확인
5. 파괴불가 벽돌 충돌 시 HP 감소 없음 확인
6. 공이 DeathZone 도달 시 라이프 감소 확인
7. 라이프 0 → 게임오버 화면 확인
8. 전체 벽돌 파괴 → 클리어 화면 + 별 표시 확인
9. StageSelect로 돌아가면 해금/별 반영 확인
10. Settings에서 볼륨 변경 후 앱 재시작 시 유지 확인

- [ ] **Step 3: 커밋**

```bash
git add -A
git commit -m "feat: add paddle hit angle correction, complete game integration"
```

---

## Dependency Graph

```
Task 1 (Setup)
  └── Task 2 (SaveManager)
       └── Task 3 (GameManager)
       └── Task 4 (SoundManager)
            └── Task 5 (Ball)
            └── Task 6 (Paddle)
            └── Task 7 (Brick)
            └── Task 8 (PowerUp)
            └── Task 9 (Level Data)
                 └── Task 10 (GameScene)
                      └── Task 11 (HUD)
                      └── Task 12 (Pause/GameOver)
                           └── Task 15 (Settings)
            └── Task 13 (TitleScreen)
            └── Task 14 (StageSelect)
                 └── Task 16 (Integration)
```
