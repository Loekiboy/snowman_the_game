extends CharacterBody2D

# --- JOUW INSTELLINGEN ---
const SPEED = 70.0
const JUMP_VELOCITY = -230.0

# --- VARIABELEN VOOR DE TELLER ---
var aangeraakte_tiles = []
var count = 0


# onready vars
@onready var label = get_node("../UI/TileCounterLabel")
@onready var popup = get_node("/root/Main/UI/WinPopup")
@onready var teller_label = get_node("/root/Main/UI/TileCounterLabel")
@onready var _animated_sprite = $AnimatedSprite2D
@onready var idle_timer = $IdleTimer

var idle_stage = 0

func _ready():
	# Dit wordt één keer uitgevoerd als het spel start
	if popup:
		popup.visible = false
	
	# Zorg dat je teller aan het begin wel zichtbaar is
	if teller_label:
		teller_label.visible = true

func _physics_process(delta: float) -> void:
	# 1. Zwaartekracht toepassen
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Springen
	if (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_accept")) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 3. Beweging berekenen
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# 4. Animaties en Idle logica
	if velocity.x != 0:
		_animated_sprite.play("walk")
		idle_stage = 0
		idle_timer.stop()
		
		if velocity.x < 0:
			_animated_sprite.flip_h = true
		else:
			_animated_sprite.flip_h = false
	else:
		if idle_timer.is_stopped():
			_run_idle_logic()

	# 5. DAADWERKELIJK BEWEGEN (Moet altijd in physics_process staan!)
	move_and_slide()

	# 6. TILE DETECTIE (Na het bewegen)
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
						var snow_atlas_pos = Vector2i(16, 7)
						snow_layer.set_cell(tile_coord, 2, snow_atlas_pos)
	
	# Check of de speler beweegt
	if velocity.x != 0:
		# Als we lopen, resetten we alles
		_animated_sprite.play("walk")
		idle_stage = 0
		idle_timer.stop()
		
		if velocity.x < 0:
			_animated_sprite.flip_h = false
		else:
			_animated_sprite.flip_h = true
	else:
		# Als we stilstaan en de timer loopt nog niet, start de wacht-cyclus
		if idle_timer.is_stopped():
			_run_idle_logic()

func _run_idle_logic():
	if idle_stage == 0:
		# Toon alleen het eerste frame (index 0)
		_animated_sprite.play("idle")
		_animated_sprite.stop() # Stop direct op frame 0
		_animated_sprite.frame = 0
		idle_stage = 1
		idle_timer.start(3.0) # Wacht precies 3 seconden
	
	elif idle_stage == 1:
		# Speel de volgende 2 frames
		_animated_sprite.play("idle")
		# We wachten tot hij bij frame 2 is en stoppen hem dan
		# Dit doen we via een signaal of simpelweg na een korte tijd
		idle_stage = 2
		idle_timer.start(randf_range(1.0, 3.0)) # Wacht tussen 1 en 3 sec
		
	elif idle_stage == 2:
		# Volgende frames...
		# Je kunt hier herhalen wat je wilt
		idle_stage = 0 # Ga terug naar begin
		idle_timer.start(randf_range(1.0, 3.0))

	# 4. Bewegen
	move_and_slide()

	# 5. TILE DETECTIE
	# We checken alle botsingen die move_and_slide zojuist heeft gevonden
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider is TileMapLayer:
			# We kijken 4 pixels "in" de tegel om zeker te weten dat we hem raken
			var botspunt = collider.to_local(collision.get_position() - collision.get_normal() * 1)
			var tile_coord = collider.local_to_map(botspunt)
			
			# Check of de tegel niet leeg is
			if collider.get_cell_source_id(tile_coord) != -1:
				# Alleen tellen als we dit specifieke grid-vakje nog niet hebben gehad
				if not tile_coord in aangeraakte_tiles:
					aangeraakte_tiles.append(tile_coord)
					count += 1
					update_ui()
					
					var layer = get_node("../TileMapLayer")
					if layer:
						
						var snow_layer = get_node("../SnowLayer")
						if snow_layer:
							# We gebruiken tile_coord in plaats van (16, 18)
							# Zo komt de sneeuw onder je voeten terecht!
							var snow_atlas_pos = Vector2i(16, 7)
							snow_layer.set_cell(tile_coord, 2, snow_atlas_pos)
# Functie om de tekst op je scherm aan te passen
func update_ui():
	if label:
		label.text = "Tiles touched: " + str(count)
	else:
		# Dit verschijnt onderin in je 'Output' venster als het label niet gevonden wordt
		print("Fout: Ik kan de Label node niet vinden!")

func _on_finish_flag_body_entered(body: Node2D) -> void:
	# Check of het echt de speler is (CharacterBody2D) die de vlag raakt
	if body.name == "CharacterBody2D":

		if teller_label:
			teller_label.visible = false
			
		if popup:
			var win_label = popup.get_node("TextEdit") 
			if win_label:
				win_label.text = "Tiles touched: " + str(count)
			
			popup.visible = true
			


func _on_idle_timer_timeout() -> void:
	if velocity.x == 0:
		_run_idle_logic()
