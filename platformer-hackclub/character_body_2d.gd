extends CharacterBody2D

# --- JOUW INSTELLINGEN ---
const SPEED = 70.0
const JUMP_VELOCITY = -230.0
const COYOTE_TIME = 0.13

# --- VARIABELEN ---
var aangeraakte_tiles = []
var count = 0
var coyote_timer = 0.0  

# onready vars
@onready var label = get_node("../UI/TileCounterLabel")
@onready var popup = get_node("/root/Main/UI/WinPopup")
@onready var teller_label = get_node("/root/Main/UI/TileCounterLabel")
@onready var restart_button = get_node("/root/Main/UI/WinPopup/Button")
@onready var _animated_sprite = $AnimatedSprite2D
@onready var idle_timer = $IdleTimer

func _ready():
	if popup: popup.visible = false
	if teller_label: teller_label.visible = true
	
	if restart_button:
		# Dit koppelt de klik-actie aan de functie hieronder
		restart_button.pressed.connect(_on_restart_button_pressed)
	
	# Start direct met wachten als het spel begint
	_animated_sprite.play("idle")
	_animated_sprite.frame = 0
	idle_timer.start(3.0)

func _physics_process(delta: float) -> void:
#	 1. Zwaartekracht
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		# Reset coyote timer als we op de grond staan
		coyote_timer = COYOTE_TIME

	# Verminder coyote timer als we in de lucht zijn
	if not is_on_floor():
		coyote_timer -= delta
		if coyote_timer < 0:
			coyote_timer = 0  # Zorg dat het niet negatief wordt

	# 2. Springen
	if (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_accept")) and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0  # Reset zodat je niet dubbel springt
		
		# De velocity word gehalveerd als je de up knop loslaat voordat hij weer daalt.
	if (Input.is_action_just_released("ui_up") or Input.is_action_just_released("ui_accept")and velocity.y <= 0):
		velocity.y = velocity.y * 0.5


	# 3. Beweging links/rechts
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	# 4. ANIMATIE LOGICA
	if not is_on_floor():
		idle_timer.stop() 
		if velocity.y < 0:
			_animated_sprite.play("jump")
		else:
			_animated_sprite.play("fall")
	else:
		# We staan op de grond
		if velocity.x != 0:
			_animated_sprite.play("walk")
			idle_timer.stop()
			if velocity.x < 0:
				_animated_sprite.flip_h = false
			else:
				_animated_sprite.flip_h = true
		
		# We staan stil op de grond: Check voor bukken
		elif Input.is_action_pressed("ui_down"):
			_animated_sprite.play("crouch")
			idle_timer.stop() # Stop de timer zodat hij niet gaat 'rondkijken' terwijl je bukt
		
		else:
			# We staan stil en we bukken niet: Idle logica
			
			# Reset naar idle als we net ergens anders vandaan komen (lopen, vallen of bukken)
			if _animated_sprite.animation == "walk" or \
			   _animated_sprite.animation == "fall" or \
			   _animated_sprite.animation == "crouch":
				_animated_sprite.play("idle")
				_animated_sprite.frame = 0
				idle_timer.start(3.0)

	# 5. Bewegen
	move_and_slide()

	# 6. Tile detectie
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

# --- DE SIMPELE IDLE LOGICA ---
# Deze functie wordt ALLEEN uitgevoerd als de Timer afloopt (timeout)
func _on_idle_timer_timeout() -> void:
	# Als we bewegen, doen we niks
	if velocity.x != 0:
		return

	# We kijken welk frame er NU aanstaat
	var frame_nu = _animated_sprite. frame
	
	if frame_nu == 0:
		# We kijken naar voren (0), kies nu een zijkant
		var keuzes = [1, 2]
		_animated_sprite.frame = keuzes.pick_random()
		# Wacht 1 tot 3 seconden op de zijkant
		idle_timer.start(randf_range(1.0, 3.0))
	else:
		# We keken opzij (1 of 2), ga nu terug naar het midden
		_animated_sprite.frame = 0
		# Wacht verplicht 3 seconden in het midden voor rust
		idle_timer.start(3.0)

# Functie om de tekst op je scherm aan te passen
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
	# Dit is het commando om de huidige scene opnieuw te laden
	get_tree().reload_current_scene()
