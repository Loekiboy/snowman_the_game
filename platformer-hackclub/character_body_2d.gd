extends CharacterBody2D

# max tiles level 1: 605
# --- INSTELLINGEN ---
const SPEED = 70.0
const JUMP_VELOCITY = -230.0
const COYOTE_TIME = 0.16
const CLIMB_SPEED = -70

# --- VARIABELEN ---
var aangeraakte_tiles = []
var count = 0
var coyote_timer = 0.0  
var is_on_ladder = false
var just_jumped = false 
var time_elapsed = 0.0
var level_active = true

# Idle animatie variabelen
var idle_target_frame = 0
var idle_in_transition = false
var first_idle = true 

# onready vars
@onready var label = get_node("../UI/TileCounterLabel")
@onready var stopwatch_label = get_node("/root/Main/UI/StopwatchLabel")
@onready var popup = get_node("/root/Main/UI/WinPopup")
@onready var teller_label = get_node("/root/Main/UI/TileCounterLabel")
@onready var restart_button = get_node("/root/Main/UI/WinPopup/Button")
@onready var next_level_button = get_node("/root/Main/UI/WinPopup/NextLevelButton")
@onready var tilemap_layer = get_node("../TileMapLayer2")
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
	if popup: 
		popup.visible = false
	if teller_label: 
		teller_label.visible = true

	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)

	if next_level_button:
		next_level_button.pressed.connect(_on_next_level_button_pressed)

	_animated_sprite.play("idle")
	_animated_sprite.frame = 0
	# NIET hier starten, wachten tot speler stilstaat

func _physics_process(delta: float) -> void:
	if level_active:
		time_elapsed += delta
		_update_stopwatch_ui()

	# 1. Ladder check
	is_on_ladder = false
	var parent = get_parent()
	if parent: 
		var tile_size = 18
		# De offset: 14.5 tiles naar rechts (+), 17.4 naar beneden (+)
		var ladder_offset = Vector2(14.5 * tile_size, 17.4 * tile_size)

		for child in parent.get_children():
			if child is TileMapLayer: 
				var check_positions = [
					global_position + ladder_offset,
					global_position + ladder_offset + Vector2(0, 8),
					global_position + ladder_offset + Vector2(0, -8),
				]
				for check_pos in check_positions:
					var tile_pos = child.local_to_map(check_pos)
					var tile_data = child.get_cell_tile_data(tile_pos)
					if tile_data and tile_data.get_custom_data("is_climbable"):
						is_on_ladder = true
						break
				if is_on_ladder:   
					break

	# 2. Zwaartekracht & Coyote Reset
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		just_jumped = false

	if is_on_ladder and not just_jumped:
		velocity.y = 0
	else:   
		if not is_on_floor():
			velocity += get_gravity() * delta
			coyote_timer -= delta

	# 3. SPRINGEN
	if (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_accept")) \
	and coyote_timer > 0 \
	and not is_on_ladder:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0
		just_jumped = true

	# 4. KLIMMEN
	if is_on_ladder and not just_jumped:
		if Input.is_action_pressed("ui_up"):
			velocity.y = CLIMB_SPEED
		elif Input.is_action_pressed("ui_down"):
			velocity.y = -CLIMB_SPEED
		else:
			velocity.y = 0

	if just_jumped and velocity.y > 0:
		just_jumped = false

	# 5. Beweging links/rechts
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# 6. ANIMATIE LOGICA
	if is_on_ladder and not is_on_floor():
		_animated_sprite.play("climb")
		# Pauzeer de animatie als de speler niet omhoog of omlaag beweegt
		if velocity.y == 0:
			_animated_sprite.stop() 
		else:
			_animated_sprite.play()

		idle_timer.stop()
		idle_in_transition = false
		first_idle = true

	elif not is_on_floor():
		idle_timer.stop()
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
				_animated_sprite.flip_h = true
		elif Input.is_action_pressed("ui_down"):
			_animated_sprite.play("crouch")
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

	# 7. Bewegen
	move_and_slide()
	
	# Achtergrondkleur aanpassen op basis van hoogte (Y-positie)
	if global_position.y < 0:
		RenderingServer.set_default_clear_color(Color("#DFF6F5"))
	else:
		RenderingServer.set_default_clear_color(Color("#c2e3e8"))

	# 8. Tile detectie
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
						aangeraakte_tiles.append(tile_coord)
						count += 1
						update_ui()
						var snow_layer = get_node("../SnowLayer")
						if snow_layer: 
							snow_layer.set_cell(tile_coord, 2, Vector2i(16, 7))

						# plays rondom snow effect
						if snow_step_player and snow_step_sfx.size() > 0:
							snow_step_player.stream = snow_step_sfx[randi_range(0, snow_step_sfx.size() - 1)]
							snow_step_player.play()

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
		_animated_sprite.frame = keuzes.pick_random()
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
	else:
		# We kijken naar voren (frame 0) -> wacht nog niet, kies volgende
		var keuzes = [1, 2]
		_animated_sprite.frame = keuzes.pick_random()
		idle_timer.start(randf_range(1.0, 3.0))

func update_ui():
	if label:
		label.text = "Tiles touched: " + str(count)

func _on_finish_flag_body_entered(body: Node2D) -> void:
	if body.name == "CharacterBody2D":
		level_active = false # Stop de timer
		
		if teller_label: 
			teller_label.visible = false
		if stopwatch_label: 
			stopwatch_label.visible = false
		
		if popup: 
			var win_label = popup.get_node("TextEdit")
			if win_label:
				# 1. Bereken de multiplier en de eindscore
				var multiplier = time_elapsed / 10.0
				var totaal_score = count * multiplier
				
				# 2. Rond de getallen af
				var afgeronde_mult = snapped(multiplier, 0.1)
				var afgeronde_score = snapped(totaal_score, 1)
				
				# 3. Zet alles in de tekst
				win_label.text = "Tiles: " + str(count) + " x " + str(afgeronde_mult) + \
								 "\nScore: " + str(afgeronde_score)
			
			popup.visible = true

func _on_restart_button_pressed():
	get_tree().reload_current_scene()

func _on_next_level_button_pressed():
	var next_level = "res://main2.tscn"
	if FileAccess.file_exists(next_level):
		get_tree().change_scene_to_file(next_level)
	else:
		print("Fout: Level 2 niet gevonden!")
	
func _update_stopwatch_ui():
	if stopwatch_label:
		var multiplier = time_elapsed / 10.0
		var multiplier_tekst = "x" + str(snapped(multiplier, 0.1))
		stopwatch_label.text = multiplier_tekst
