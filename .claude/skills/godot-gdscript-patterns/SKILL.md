---
name: godot-gdscript-patterns
description: "Master Godot 4 GDScript patterns for game development: state machines, tween animations, NinePatch UI, physics, audio, JSON level data, particles, save/load, and optimization. Use this skill whenever building Godot games, implementing game systems, writing GDScript code, debugging physics or collision issues, creating UI with Kenney assets, or learning Godot best practices. Trigger on any Godot, GDScript, .tscn, .gd, or game development question."
---

# Godot 4 GDScript Patterns

Production patterns for Godot 4.x game development. Covers architecture, UI, physics, audio, data, and optimization.

## Core Architecture

```
Node: Base building block
├── Scene (.tscn): Reusable node tree
├── Resource (.tres): Data container
├── Signal: Event communication
├── Group: Node categorization
└── Autoload: Global singletons
```

## Pattern 1: Enum State Machine (Inline)

Simple state machine using enum + variable. Good for linear state flows.

```gdscript
enum State { AIMING, FIRING, WAITING, TURN_END }

var _state: State = State.AIMING

func _process(delta: float) -> void:
    if _state != State.WAITING:
        return
    # State-specific logic here

# State transition with guard
func _on_event() -> void:
    if _state == State.FIRING:
        _state = State.WAITING

# Conditional on multiple states
func _end_turn() -> void:
    if _state == State.WAITING or _state == State.FIRING:
        _state = State.TURN_END
```

For complex state machines with enter/exit/update per state, see [references/advanced-patterns.md](references/advanced-patterns.md) (Pattern 1: Class-based State Machine).

## Pattern 2: Tween Animations

Always kill previous tween before creating a new one. Use `set_parallel(true)` for simultaneous effects.

```gdscript
var _hit_tween: Tween = null

# Hit effect: flash + scale punch
func _play_hit_effect() -> void:
    if _hit_tween and _hit_tween.is_valid():
        _hit_tween.kill()
    scale = Vector2.ONE

    _hit_tween = create_tween()
    _hit_tween.set_parallel(true)

    # Flash: brightness up then back
    sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
    _hit_tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)

    # Scale punch: expand then return with bounce easing
    scale = Vector2(1.15, 1.15)
    _hit_tween.tween_property(self, "scale", Vector2.ONE, 0.12) \
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

# Sequential chain: wait → animate → callback
func _expand_then_shrink() -> void:
    var tween := create_tween()
    tween.tween_interval(10.0)                       # Wait 10 seconds
    tween.tween_property(self, "scale:x", 1.0, 0.3)  # Shrink back
    tween.tween_callback(_on_expand_ended)            # Callback when done

# Parallel multi-object animation with await
func _descend_all(nodes: Array, amount: float, duration: float) -> void:
    var tween := create_tween()
    tween.set_parallel(true)
    for node in nodes:
        tween.tween_property(node, "position:y", node.position.y + amount, duration)
    await tween.finished
```

## Pattern 3: NinePatch UI (StyleBoxTexture)

Use Kenney PNG assets as NinePatch for buttons and panels that scale to any size.

```gdscript
# Programmatic StyleBoxTexture for buttons
var style := StyleBoxTexture.new()
style.texture = preload("res://assets/images/ui/btn_green.png")
style.texture_margin_left = 12.0
style.texture_margin_top = 12.0
style.texture_margin_right = 12.0
style.texture_margin_bottom = 16.0  # Bottom larger for depth shadow
content_margin_left = 16.0
content_margin_top = 8.0
content_margin_right = 16.0
content_margin_bottom = 12.0

# Apply to all button states
btn.add_theme_stylebox_override("normal", style)
btn.add_theme_stylebox_override("hover", style)
btn.add_theme_stylebox_override("pressed", style)

# Runtime texture swap (duplicate to avoid modifying original)
func _set_header_texture(tex: Texture2D) -> void:
    var s := panel.get_theme_stylebox("panel").duplicate() as StyleBoxTexture
    s.texture = tex
    panel.add_theme_stylebox_override("panel", s)
```

In `.tscn` files:
```
[sub_resource type="StyleBoxTexture" id="btn_style"]
texture = ExtResource("btn_green_tex")
texture_margin_left = 12.0
texture_margin_top = 12.0
texture_margin_right = 12.0
texture_margin_bottom = 16.0
```

## Pattern 4: Audio SFX Pool

Round-robin AudioStreamPlayer pool for overlapping sound effects.

```gdscript
const SFX_POOL_SIZE := 5

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

func _ready() -> void:
    for i in SFX_POOL_SIZE:
        var player := AudioStreamPlayer.new()
        player.bus = "SFX"
        add_child(player)
        _sfx_pool.append(player)

# Play SFX — automatically cycles through pool
func play_sfx(stream: AudioStream) -> void:
    var player := _sfx_pool[_sfx_index]
    player.stream = stream
    player.play()
    _sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE

# Preloaded sounds
var sfx_hit: AudioStream = preload("res://assets/sounds/sfx_ball_hit.ogg")

# Usage from anywhere
SoundManager.play_sfx(SoundManager.sfx_hit)
```

## Pattern 5: JSON Level Data Loading

Load structured game data from JSON with fallback defaults.

```gdscript
func _load_level(level: int) -> void:
    var path := "res://data/levels/level_%d.json" % level
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Level file not found: %s" % path)
        return
    var json := JSON.new()
    var err := json.parse(file.get_as_text())
    if err != OK:
        push_error("JSON parse error: %s" % json.get_error_message())
        return
    var data: Dictionary = json.data

    # Access with defaults
    var speed: float = float(data.get("ball_speed", 400.0))
    var bricks: Array = data.get("bricks", []) as Array
    for brick_data: Dictionary in bricks:
        var hp: int = int(brick_data["hp"])
        var brick_type: String = str(brick_data.get("type", "rect"))
```

## Pattern 6: RigidBody2D Ball Physics

Constant-speed ball with post-collision angle correction.

```gdscript
const MIN_ANGLE_RAD := deg_to_rad(8.0)
var _target_speed := 400.0

# Maintain speed every frame
func _physics_process(_delta: float) -> void:
    var speed := linear_velocity.length()
    if speed > 0.1 and speed != _target_speed:
        linear_velocity = linear_velocity.normalized() * _target_speed
    elif speed <= 0.1:
        linear_velocity = Vector2(0, 1) * _target_speed  # Push down if stuck

# Post-collision: correct near-vertical angles
func _on_body_entered(body: Node) -> void:
    if body.has_method("hit"):
        body.hit()
    _correct_velocity.call_deferred()  # Deferred: wait for physics to settle

func _correct_velocity() -> void:
    var dir := linear_velocity.normalized()
    var angle_from_up := absf(dir.angle_to(Vector2.UP))
    if angle_from_up < MIN_ANGLE_RAD:
        var sign_x := signf(dir.x) if dir.x != 0.0 else 1.0
        dir = Vector2(sin(MIN_ANGLE_RAD) * sign_x, -cos(MIN_ANGLE_RAD))
    linear_velocity = dir * _target_speed
```

## Pattern 7: Dynamic Particles

Create GPU particles in code for one-shot effects.

```gdscript
func _spawn_particles(pos: Vector2) -> void:
    var mat := ParticleProcessMaterial.new()
    mat.direction = Vector3(0, 1, 0)
    mat.spread = 120.0
    mat.initial_velocity_min = 40.0
    mat.initial_velocity_max = 120.0
    mat.gravity = Vector3(0, 300, 0)
    mat.scale_min = 0.06
    mat.scale_max = 0.12
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    mat.emission_box_extents = Vector3(25, 8, 0)

    var particles := GPUParticles2D.new()
    particles.position = pos
    particles.emitting = true
    particles.one_shot = true
    particles.amount = 6
    particles.lifetime = 0.6
    particles.process_material = mat
    particles.texture = preload("res://assets/images/bricks/tile_brick_white.png")
    add_child(particles)
    particles.finished.connect(particles.queue_free)  # Auto-cleanup
```

## Pattern 8: Save/Load System

JSON-based persistent data with merge strategy.

```gdscript
const SAVE_PATH := "user://save_data.json"
var data := {"unlocked_level": 1, "high_scores": {}, "stars": {}, "settings": {}}

func save_data() -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(data, "\t"))

func load_data() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    var json := JSON.new()
    if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
        for key in data.keys():
            if json.data.has(key):
                data[key] = json.data[key]  # Merge: only overwrite existing keys
```

## Pattern 9: Deferred Callbacks & Time Scale

```gdscript
# Deferred: run after current physics frame
_correct_velocity.call_deferred()

# Await next frame
await get_tree().process_frame

# Time scale ramping (real time tracking)
func _process(delta: float) -> void:
    var real_delta := delta / Engine.time_scale if Engine.time_scale > 0 else delta
    _elapsed += real_delta
    if _elapsed >= 5.0:
        Engine.time_scale = 2.0  # 2x speed after 5 real seconds
    if _elapsed >= 10.0:
        Engine.time_scale = 3.0  # 3x speed after 10 real seconds
```

## Pattern 10: Collision Groups

Use groups for filtering instead of complex layer/mask setups.

```gdscript
# Check group in collision callback
func _on_floor_body_entered(body: Node2D) -> void:
    if not body.is_in_group("ball"):
        return
    _collect_ball(body)

# Remove from group to prevent detection during recall
func _recall_all_balls() -> void:
    for ball in ball_container.get_children():
        ball.remove_from_group("ball")
        ball.freeze = true
```

## Pattern 11: Touch + Mouse Input

Handle both input types in the same handler for mobile compatibility.

```gdscript
func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        _start(event.position)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _start(event.position)
    elif event is InputEventScreenDrag:
        _update(event.position)
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        _update(event.position)
```

## Pattern 12: Raycast Aiming Guide

Dotted line preview using PhysicsDirectSpaceState2D.

```gdscript
func _draw_guide(from: Vector2, dir: Vector2) -> void:
    var space := get_world_2d().direct_space_state
    var query := PhysicsRayQueryParameters2D.create(from, from + dir * 2000.0, 1)
    var hit := space.intersect_ray(query)
    var end: Vector2 = hit["position"] if not hit.is_empty() else from + dir * 2000.0
    # Place dot sprites along from → end at DOT_SPACING intervals
```

For more patterns, see [references/advanced-patterns.md](references/advanced-patterns.md):
- Class-based State Machine (enter/exit/update per state)
- Scene Management with threaded loading
- Resource-based data (WeaponData, CharacterStats)
- Object Pooling
- Component System (Health, Hitbox, Hurtbox)
- Performance Tips & Best Practices
