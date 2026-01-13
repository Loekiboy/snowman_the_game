extends CharacterBody2D

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
	idle_timer.start(3.0)
	
	RenderingServer.set_default_clear_color(Color("#c2e3e8"))

func _physics_process(delta:  float) -> void:
	
	# Check of we op een ladder staan
# Check of we op een ladder staan
	is_on_ladder = false
	
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child is TileMapLayer:
			# Check meerdere posities rond de speler voor betere detectie
				var check_positions = [
					global_position,  # Exact midden
					global_position + Vector2(0, 8),  # Iets onder (voor als speler niet precies op tile staat)
					global_position + Vector2(0, -8),  # Iets boven
				]
			
				for check_pos in check_positions:
					var tile_pos = child.local_to_map(check_pos)
					var tile_data = child.get_cell_tile_data(tile_pos)
				
					if tile_data:
						var is_climbable = tile_data.get_custom_data("is_climbable")
						if is_climbable:
							is_on_ladder = true
							print("🪜 Ladder gevonden op layer: ", child.name, " tile: ", tile_pos)
							break  # Stop als we een ladder gevonden hebben
			
				if is_on_ladder:
					break  # Stop met zoeken naar andere layers

	# 1. Zwaartekracht & Coyote Reset
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		just_jumped = false  # Reset als we weer op de grond staan
	
	if not is_on_floor():
		# Alleen ladder-zweven als we NIET net gesprongen zijn
		if is_on_ladder and not just_jumped:
			velocity.y = 0
		else:
			velocity += get_gravity() * delta
			coyote_timer -= delta

	# 2. SPRINGEN (EERST!)
	if (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_accept")) and (coyote_timer > 0 or is_on_ladder):
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0
		just_jumped = true  # Markeer dat we net gesprongen zijn
		
	# Sprong inkorten bij loslaten (Variable jump height)
	if (Input.is_action_just_released("ui_up") or Input.is_action_just_released("ui_accept")) and velocity.y < 0:
		velocity.y = velocity.y * 0.5

	# 3. KLIMMEN (NA SPRINGEN!)
	# Alleen klimmen als we NIET net gesprongen zijn
	if is_on_ladder and not just_jumped:
		if Input.is_action_pressed("ui_up"):
			velocity.y = CLIMB_SPEED
		elif Input.is_action_pressed("ui_down"):
			velocity.y = -CLIMB_SPEED
		else:
			velocity.y = 0

	# Reset just_jumped als we begonnen zijn te vallen (spring is voorbij de piek)
	if just_jumped and velocity.y > 0:
		just_jumped = false

	# 4. Beweging links/rechts
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity. x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	# 5. ANIMATIE LOGICA
	if not is_on_floor():
		idle_timer.stop() 
		if velocity.y < 0:
			_animated_sprite.play("jump")
		else:
			_animated_sprite. play("fall")
	else:
		# We staan op de grond
		if velocity.x != 0:
			_animated_sprite.play("walk")
			idle_timer.stop()
			if velocity.x < 0:
				_animated_sprite.flip_h = false
			else:
				_animated_sprite.flip_h = true
		
		# We staan stil op de grond:  Check voor bukken
		elif Input.is_action_pressed("ui_down"):
			_animated_sprite.play("crouch")
			idle_timer.stop()
		
		else:
			# We staan stil en we bukken niet:  Idle logica
			if _animated_sprite.animation == "walk" or \
			   _animated_sprite. animation == "fall" or \
			   _animated_sprite.animation == "crouch": 
				_animated_sprite.play("idle")
				_animated_sprite.frame = 0
				idle_timer.start(3.0)

	# 6. Bewegen
	move_and_slide()

	# 7. Tile detectie
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is TileMapLayer:
			var botspunt = collider.to_local(collision.get_position() - collision.get_normal() * 1)
			var tile_coord = collider.local_to_map(botspunt)
			if collider.get_cell_source_id(tile_coord) != -1:
				if not tile_coord in aangeraakte_tiles:
					aangeraakte_tiles.append(tile_coord)
					count += 1
					update_ui()
					var snow_layer = get_node("../SnowLayer")
					if snow_layer: 
						snow_layer.set_cell(tile_coord, 2, Vector2i(16, 7))

func _on_idle_timer_timeout() -> void:
	if velocity.x != 0:
		return

	var frame_nu = _animated_sprite.frame
	
	if frame_nu == 0:
		var keuzes = [1, 2]
		_animated_sprite.frame = keuzes. pick_random()
		idle_timer.start(randf_range(1.0, 3.0))
	else:
		_animated_sprite. frame = 0
		idle_timer.start(3.0)

func update_ui():
	if label:
		label.text = "Tiles touched: " + str(count)

func _on_finish_flag_body_entered(body: Node2D) -> void:
	if body.name == "CharacterBody2D":
		if teller_label: teller_label. visible = false
		if popup: 
			var win_label = popup.get_node("TextEdit")
			if win_label: win_label.text = "Tiles touched: " + str(count)
			popup.visible = true
			
func _on_restart_button_pressed():
	get_tree().reload_current_scene()
