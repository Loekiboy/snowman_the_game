extends CharacterBody2D

# --- JOUW INSTELLINGEN ---
const SPEED = 70.0
const JUMP_VELOCITY = -230.0
const COYOTE_TIME = 0.16
const CLIMB_SPEED = -70
const FOOTPRINT_DISTANCE = 8.0 # Hoeveel pixels lopen voor nieuwe sneeuw

# --- VARIABELEN ---
var aangeraakte_tiles = []
var count = 0
var coyote_timer = 0.0  
var is_on_ladder = false
var just_jumped = false 
var time_elapsed = 0.0
var level_active = true
var last_snow_pos = Vector2.ZERO

# Idle animatie variabelen
var idle_target_frame = 0
var idle_in_transition = false
var first_idle = true 

# onready vars
@onready var label = get_node("../UI/TileCounterLabel")
@onready var stopwatch_label = get_node("/root/Main/UI/StopwatchLabel")
@onready var popup = get_node("/root/Main/UI/WinPopup")
@onready var teller_label = get_node("/root/Main/UI/TileCounterLabel")
@onready var tilemap_layer = get_node("../TileMapLayer2")
@onready var snow_layer = get_node("../SnowLayer") # Je TileMapLayer voor de textures
@onready var _animated_sprite = $AnimatedSprite2D
@onready var idle_timer = $IdleTimer
@onready var snow_step_player = $SnowStepPlayer

# SFX lijst
var snow_step_sfx := [
	preload("res://sounds/snow step/1.wav"),
	preload("res://sounds/snow step/2.wav"),
	preload("res://sounds/snow step/3.wav"),
	preload("res://sounds/snow step/4.wav"),
	preload("res://sounds/snow step/5.wav"),
	preload("res://sounds/snow step/6.wav"),
]

func _ready():
	if popup: popup.visible = false
	if teller_label: teller_label.visible = true
	_animated_sprite.play("idle")
	RenderingServer.set_default_clear_color(Color("#c2e3e8"))
	randomize()

func _physics_process(delta: float) -> void:
	if level_active:
		time_elapsed += delta
		_update_stopwatch_ui()

	# 1. Ladder check (vereenvoudigd voor leesbaarheid)
	_check_ladder()

	# 2. Zwaartekracht
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		just_jumped = false
	
	if is_on_ladder and not just_jumped:
		velocity.y = 0
	else:  
		if not is_on_floor():
			velocity += get_gravity() * delta
			coyote_timer -= delta

	# 3. Springen & 4. Klimmen & 5. Beweging
	_handle_input()

	# 6. Animatie
	_handle_animations()

	# 7. Bewegen
	move_and_slide()

	# 8. DE PIXEL-PRECIES SNEEUW LOGICA
	_handle_snow_generation()

func _handle_snow_generation():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider is TileMapLayer:
			var normal = collision.get_normal()
			# Alleen als we op de grond staan
			if normal.y < -0.5:
				var collision_pos = collision.get_position()
				
				# Check of we ver genoeg bewogen hebben
				if collision_pos.distance_to(last_snow_pos) > FOOTPRINT_DISTANCE:
					_spawn_hybrid_snow(collision_pos, collider)
					last_snow_pos = collision_pos

func _spawn_hybrid_snow(pos: Vector2, original_tilemap: TileMapLayer):
	# 1. BEREKEN DE X OP HET GRID
	# We pakken de X van de tilemap en snappen de wereld-X daarop
	var local_pos = original_tilemap.to_local(pos)
	var map_coord = original_tilemap.local_to_map(local_pos)
	var snapped_x = original_tilemap.to_global(original_tilemap.map_to_local(map_coord)).x
	
	# 2. MAAK EEN SPRITE DIE LIJKT OP DE TILE
	var snow_sprite = Sprite2D.new()
	
	# We halen de texture uit je bestaande SnowLayer TileSet
	var tileset = snow_layer.tile_set
	var source = tileset.get_source(2) as TileSetAtlasSource # Jouw source ID 2
	
	snow_sprite.texture = source.texture
	# We pakken precies het vierkantje van de sneeuw-tile (Vector2i(16, 7))
	var region_size = tileset.tile_size
	snow_sprite.region_enabled = true
	snow_sprite.region_rect = Rect2(Vector2(16 * region_size.x, 7 * region_size.y), region_size)
	
	# 3. POSITIONERING
	# X is snapped naar het grid, Y is precies waar de collision was
	snow_sprite.global_position = Vector2(snapped_x, pos.y)
	snow_sprite.z_index = -1 # Achter de speler
	
	get_parent().add_child(snow_sprite)
	
	# 4. SCORE EN GELUID
	_update_score(map_coord)
	
	if snow_step_player and snow_step_sfx.size() > 0:
		snow_step_player.stream = snow_step_sfx.pick_random()
		snow_step_player.play()

func _update_score(tile_coord: Vector2i):
	if not tile_coord in aangeraakte_tiles:
		aangeraakte_tiles.append(tile_coord)
		count += 1
		update_ui()

# --- HULPFUNCTIES (De rest van je code) ---

func _check_ladder():
	is_on_ladder = false
	var parent = get_parent()
	if parent: 
		var tile_size = 18
		var ladder_offset = Vector2(14.5 * tile_size, 17.4 * tile_size)
		for child in parent.get_children():
			if child is TileMapLayer: 
				var check_pos = global_position + ladder_offset
				var tile_pos = child.local_to_map(check_pos)
				var tile_data = child.get_cell_tile_data(tile_pos)
				if tile_data and tile_data.get_custom_data("is_climbable"):
					is_on_ladder = true
					break

func _handle_input():
	if (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_accept")) \
		and coyote_timer > 0 and not is_on_ladder:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0
		just_jumped = true

	if is_on_ladder and not just_jumped:
		if Input.is_action_pressed("ui_up"): velocity.y = CLIMB_SPEED
		elif Input.is_action_pressed("ui_down"): velocity.y = -CLIMB_SPEED
		else: velocity.y = 0

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction: velocity.x = direction * SPEED
	else: velocity.x = move_toward(velocity.x, 0, SPEED)

func _handle_animations():
	if is_on_ladder and not is_on_floor():
		_animated_sprite.play("climb")
		if velocity.y == 0: _animated_sprite.stop()
		else: _animated_sprite.play()
	elif not is_on_floor():
		if velocity.y < 0: _animated_sprite.play("jump")
		else: _animated_sprite.play("fall")
	else:
		if velocity.x != 0:
			_animated_sprite.play("walk")
			_animated_sprite.flip_h = velocity.x > 0
		elif Input.is_action_pressed("ui_down"):
			_animated_sprite.play("crouch")
		else:
			if _animated_sprite.animation != "idle":
				_animated_sprite.play("idle")

func update_ui():
	if label: label.text = "Tiles touched: " + str(count)

func _update_stopwatch_ui():
	if stopwatch_label:
		var multiplier = time_elapsed / 10.0
		stopwatch_label.text = "x" + str(snapped(multiplier, 0.1))
