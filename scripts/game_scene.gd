# scripts/game_scene.gd
# 메인 게임 씬. 레벨 로드, 벽돌 생성, 승리/패배 판정, 파워업 처리를 담당한다.
extends Node2D

const BRICK_SCENE := preload("res://scenes/objects/brick.tscn")
const BALL_SCENE := preload("res://scenes/objects/ball.tscn")
const POWERUP_SCENE := preload("res://scenes/objects/power_up.tscn")
const PARTICLE_TEXTURE := preload("res://assets/images/particles/particleWhite_1.png")

const GRID_COLS := 7
const BRICK_MARGIN := 4.0
const GRID_TOP_OFFSET := 80.0
const POWERUP_DROP_CHANCE := 0.2

# 파티클용 공유 머티리얼 (매번 생성하지 않고 재사용)
static var _particle_material: ParticleProcessMaterial

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
	if _particle_material == null:
		_particle_material = ParticleProcessMaterial.new()
		_particle_material.direction = Vector3(0, -1, 0)
		_particle_material.spread = 180.0
		_particle_material.initial_velocity_min = 50.0
		_particle_material.initial_velocity_max = 150.0
		_particle_material.gravity = Vector3(0, 200, 0)
		_particle_material.scale_min = 0.5
		_particle_material.scale_max = 1.0
	GameManager.game_over.connect(_on_game_over)
	GameManager.stage_cleared.connect(_on_stage_cleared)
	_load_level(GameManager.current_level)
	_spawn_ball()


func _input(event: InputEvent) -> void:
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
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("GameScene: Failed to parse level JSON: %s" % json.get_error_message())
		return
	var data: Dictionary = json.data

	GameManager.start_level(level)
	_ball_speed = float(data.get("ball_speed", 300.0))
	_remaining_bricks = 0

	var viewport_width := get_viewport_rect().size.x
	var brick_width := (viewport_width - BRICK_MARGIN * (GRID_COLS + 1)) / GRID_COLS

	var bricks_array: Array = data.get("bricks", [])
	for brick_data: Dictionary in bricks_array:
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


func _spawn_ball() -> void:
	var ball: RigidBody2D = BALL_SCENE.instantiate()
	ball_container.add_child(ball)
	ball.setup(paddle, _ball_speed)


func _launch_all_balls() -> void:
	for ball: RigidBody2D in ball_container.get_children():
		ball.launch()


func _on_brick_destroyed(pos: Vector2, hp: int) -> void:
	GameManager.add_brick_score(hp)
	_remaining_bricks -= 1
	_spawn_particles(pos)
	if randf() < POWERUP_DROP_CHANCE:
		_spawn_powerup(pos)
	if _remaining_bricks <= 0:
		GameManager.clear_stage()


# 파괴 파티클을 생성한다. 공유 머티리얼을 재사용한다.
func _spawn_particles(pos: Vector2) -> void:
	var particles := GPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.4
	particles.process_material = _particle_material
	particles.texture = PARTICLE_TEXTURE
	add_child(particles)
	particles.finished.connect(particles.queue_free)


func _spawn_powerup(pos: Vector2) -> void:
	var powerup: Area2D = POWERUP_SCENE.instantiate()
	powerup.position = pos
	var powerup_types: Array = [0, 1]
	var type: int = powerup_types.pick_random()
	item_container.add_child(powerup)
	powerup.setup(type)
	powerup.collected.connect(_on_powerup_collected)


func _on_powerup_collected(type: int) -> void:
	match type:
		0:
			paddle.expand()
		1:
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
		var rotated_vel := ref_ball.linear_velocity.rotated(deg_to_rad(angle_offset))
		new_ball.launch_with_velocity(rotated_vel)


func _on_death_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		body.queue_free()
		# 모든 공이 사라졌는지 다음 프레임에서 체크 (queue_free 반영 대기)
		await get_tree().process_frame
		if ball_container.get_child_count() == 0:
			GameManager.lose_life()
			if GameManager.is_playing:
				_spawn_ball()


func _on_game_over() -> void:
	game_over_menu.show_game_over()


func _on_stage_cleared() -> void:
	game_over_menu.show_clear()
