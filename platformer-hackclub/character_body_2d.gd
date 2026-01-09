extends CharacterBody2D

# --- JOUW INSTELLINGEN ---
const SPEED = 70.0
const JUMP_VELOCITY = -230.0

# --- VARIABELEN VOOR DE TELLER ---
var aangeraakte_tiles = []
var count = 0


# Zorg dat dit pad exact klopt met de naam van je Label!
@onready var label = get_node("../UI/TileCounterLabel")
@onready var popup = get_node("/root/Main/UI/WinPopup")
@onready var teller_label = get_node("/root/Main/UI/TileCounterLabel")

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

	# 3. Beweging links/rechts
	var direction := Input.get_axis("ui_left", "ui_right")
	
	if direction > 0:
		$Sprite2D.flip_h = true # Kijkt naar rechts
	elif direction < 0:
		$Sprite2D.flip_h = false  # Kijkt naar links
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
			
