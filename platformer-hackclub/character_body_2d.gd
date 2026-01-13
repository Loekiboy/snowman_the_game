extends CharacterBody2D
# max tiles level 1: 605
# --- JOUW INSTELLINGEN ---
const SPEED = 70.0
const JUMP_VELOCITY = -230.0
const COYOTE_TIME = 0.13
const CLIMB_SPEED = -70

# --- VARIABELEN ---
var aangeraakte_tiles = []
var count = 0
var coyote_timer = 0.0  
var is_on_ladder = false
var just_jumped = false 

# Idle animatie variabelen
var idle_target_frame = 0
var idle_in_transition = false
var first_idle = true  # Track of dit de eerste idle is

# onready vars
@onready var label = get_node("../UI/TileCounterLabel")
@onready var popup = get_node("/root/Main/UI/WinPopup")
@onready var teller_label = get_node("/root/Main/UI/TileCounterLabel")
@onready var restart_button = get_node("/root/Main/UI/WinPopup/Button")
@onready var tilemap_layer = get_node("../TileMapLayer2")
@onready var _animated_sprite = $AnimatedSprite2D
@onready var idle_timer = $IdleTimer

func _ready():
	if popup:  popup.visible = false
	if teller_label: teller_label.visible = true
	
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	
	_animated_sprite.play("idle")
	_animated_sprite.frame = 0
	# NIET hier starten, wachten tot speler stilstaat
	
	RenderingServer.set_default_clear_color(Color("#c2e3e8"))

func _physics_process(delta:   float) -> void:
	
	# Check of we op een ladder staan
	is_on_ladder = false
	
	var parent = get_parent()
	if parent: 
		for child in parent.get_children():
			if child is TileMapLayer: 
				var check_positions = [
					global_position,
					global_position + Vector2(0, 8),
					global_position + Vector2(0, -8),
				]
			
				for check_pos in check_positions:
					var tile_pos = child.local_to_map(check_pos)
					var tile_data = child.get_cell_tile_data(tile_pos)
				
					if tile_data: 
						var is_climbable = tile_data.get_custom_data("is_climbable")
						if is_climbable:
							is_on_ladder = true
							break
			
				if is_on_ladder:  
					break

	# 1. Zwaartekracht & Coyote Reset
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		just_jumped = false
	
	if not is_on_floor():
		if is_on_ladder and not just_jumped:
			velocity.y = 0
		else:  
			velocity += get_gravity() * delta
			coyote_timer -= delta

	# 2. SPRINGEN
	if (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_accept")) and (coyote_timer > 0 or is_on_ladder):
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0
		just_jumped = true
		
	if (Input.is_action_just_released("ui_up") or Input.is_action_just_released("ui_accept")) and velocity.y < 0:
		velocity.y = velocity.y * 0.5

	# 3. KLIMMEN
	if is_on_ladder and not just_jumped:
		if Input.is_action_pressed("ui_up"):
			velocity.y = CLIMB_SPEED
		elif Input.is_action_pressed("ui_down"):
			velocity.y = -CLIMB_SPEED
		else:
			velocity.y = 0

	if just_jumped and velocity.y > 0:
		just_jumped = false

	# 4. Beweging links/rechts
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	# 5. ANIMATIE LOGICA
	if not is_on_floor():
		idle_timer. stop()
		idle_in_transition = false
		first_idle = true
		if velocity.y < 0:
			_animated_sprite.play("jump")
		else:
			_animated_sprite.play("fall")
	else:
		if velocity.x != 0:
			_animated_sprite.play("walk")
			idle_timer.stop()
			idle_in_transition = false
			first_idle = true
			if velocity.x < 0:
				_animated_sprite.flip_h = false
			else:  
				_animated_sprite. flip_h = true
		
		elif Input.is_action_pressed("ui_down"):
			_animated_sprite. play("crouch")
			idle_timer.stop()
			idle_in_transition = false
			first_idle = true
		
		else:
			# Speler staat stil -> start idle animatie
			if _animated_sprite.animation != "idle":
				_animated_sprite.play("idle")
				_animated_sprite.frame = 0
				idle_in_transition = false
				first_idle = true
				idle_timer.start(3.0)  # EERSTE keer 3 seconden
			elif first_idle and not idle_timer.is_stopped():
				# Idle is al aan het lopen, doe niets
				pass

	# 6. Bewegen
	move_and_slide()

	# 7. Tile detectie
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
	
		if collider is TileMapLayer:
			var normal = collision.get_normal()
			
			if normal.y < -0.5:
				var botspunt = collider.to_local(collision.get_position() - normal * 1)
				var tile_coord = collider.local_to_map(botspunt)
				
				if collider.get_cell_source_id(tile_coord) != -1:
					if not tile_coord in aangeraakte_tiles: 
						aangeraakte_tiles. append(tile_coord)
						count += 1
						update_ui()
						var snow_layer = get_node("../SnowLayer")
						if snow_layer: 
							snow_layer. set_cell(tile_coord, 2, Vector2i(16, 7))

func _on_idle_timer_timeout() -> void:
	# Stop als speler beweegt
	if velocity.x != 0:
		idle_in_transition = false
		first_idle = true
		return

	var frame_nu = _animated_sprite.frame
	
	# Als we in een transitie zitten, ga naar het doel frame
	if idle_in_transition:
		_animated_sprite.frame = idle_target_frame
		idle_in_transition = false
		idle_timer.start(randf_range(1.0, 3.0))
		return
	
	# EERSTE keer (3 sec omhoog gekeken) -> kies nu links of rechts
	if first_idle: 
		first_idle = false
		var keuzes = [1, 2]  # Links of rechts
		_animated_sprite.frame = keuzes. pick_random()
		idle_timer.start(randf_range(1.0, 3.0))
		return
	
	# We kijken naar links (1) of rechts (2)
	if frame_nu == 1 or frame_nu == 2:
		var keuzes = [0, 1, 2]
		keuzes.erase(frame_nu)  # Verwijder huidige frame uit keuzes
		var nieuw_frame = keuzes.pick_random()
		
		# Als we van links naar rechts gaan (of andersom), eerst via midden
		if (frame_nu == 1 and nieuw_frame == 2) or (frame_nu == 2 and nieuw_frame == 1):
			_animated_sprite.frame = 0
			idle_target_frame = nieuw_frame
			idle_in_transition = true
			idle_timer.start(0.2)  # Korte pauze in het midden
		else:
			_animated_sprite.frame = nieuw_frame
			idle_timer.start(randf_range(1.0, 3.0))
	
	# We kijken naar voren (frame 0) -> wacht nog niet, kies volgende
	else:
		var keuzes = [1, 2]
		_animated_sprite.frame = keuzes.pick_random()
		idle_timer.start(randf_range(1.0, 3.0))

func update_ui():
	if label:
		label.text = "Tiles touched: " + str(count)

func _on_finish_flag_body_entered(body: Node2D) -> void:
	if body.name == "CharacterBody2D":
		if teller_label: teller_label.visible = false
		if popup: 
			var win_label = popup.get_node("TextEdit")
			if win_label: win_label.text = "Tiles touched: " + str(count)
			popup.visible = true
			
func _on_restart_button_pressed():
	get_tree().reload_current_scene()
