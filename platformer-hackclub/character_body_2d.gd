extends CharacterBody2D

# --- JOUW INSTELLINGEN ---
const SPEED = 70.0
const JUMP_VELOCITY = -230.0

# --- VARIABELEN VOOR DE TELLER ---
var aangeraakte_tiles = []
var count = 0

# Zorg dat dit pad exact klopt met de naam van je Label!
@onready var label = get_node("../UI/TileCounterLabel")

func _physics_process(delta: float) -> void:
	# 1. Zwaartekracht toepassen
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Springen
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 3. Beweging links/rechts
	var direction := Input.get_axis("ui_left", "ui_right")
	
	# --- HIER PAS JE DE KIJKRICHTING AAN ---
	# Vervang 'Sprite2D' door de exacte naam van de sprite van je sneeuwpop!
	if direction > 0:
		$Sprite2D.flip_h = false # Kijkt naar rechts
	elif direction < 0:
		$Sprite2D.flip_h = true  # Kijkt naar links
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# 4. Bewegen
	move_and_slide()

	# 5. TILE DETECTIE
	# We checken alle botsingen die move_and_slide zojuist heeft gevonden
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider is TileMapLayer:
			# We kijken 4 pixels "in" de tegel om zeker te weten dat we hem raken
			var botspunt = collider.to_local(collision.get_position() - collision.get_normal() * 4)
			var tile_coord = collider.local_to_map(botspunt)
			
			# Check of de tegel niet leeg is
			if collider.get_cell_source_id(tile_coord) != -1:
				# Alleen tellen als we dit specifieke grid-vakje nog niet hebben gehad
				if not tile_coord in aangeraakte_tiles:
					aangeraakte_tiles.append(tile_coord)
					count += 1
					update_ui()

# Functie om de tekst op je scherm aan te passen
func update_ui():
	if label:
		label.text = "Tiles aangeraakt: " + str(count)
	else:
		# Dit verschijnt onderin in je 'Output' venster als het label niet gevonden wordt
		print("Fout: Ik kan de Label node niet vinden!")
