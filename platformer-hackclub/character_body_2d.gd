extends CharacterBody2D

# --- JOUW INSTELLINGEN ---
const SPEED = 70.0
const JUMP_VELOCITY = -230.0

# --- VARIABELEN ---
var aangeraakte_tiles = []
var count = 0

# onready vars
@onready var label = get_node("../UI/TileCounterLabel")
@onready var popup = get_node("/root/Main/UI/WinPopup")
@onready var teller_label = get_node("/root/Main/UI/TileCounterLabel")
@onready var _animated_sprite = $AnimatedSprite2D
@onready var idle_timer = $IdleTimer

func _ready():
	if popup: popup.visible = false
	if teller_label: teller_label.visible = true
	
	# Start direct met wachten als het spel begint
	_animated_sprite.play("idle")
	_animated_sprite.frame = 0
	idle_timer.start(3.0)

func _physics_process(delta: float) -> void:
	# 1. Zwaartekracht
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Springen
	if (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_accept")) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 3. Beweging links/rechts
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	# 4. ANIMATIE LOGICA
	if not is_on_floor():
		idle_timer.stop() # Geen idle timer tijdens springen/vallen
		
		if velocity.y < 0:
			_animated_sprite.play("jump")
		else:
			_animated_sprite.play("fall")
	else:
		if velocity.x != 0:
			_animated_sprite.play("walk")
			idle_timer.stop()
			if velocity.x < 0:
				_animated_sprite.flip_h = false
			else:
				_animated_sprite.flip_h = true
		else:
	# Alleen als we NET gestopt zijn met lopen
			if _animated_sprite.animation == "walk":
				_animated_sprite.play("idle")
				_animated_sprite. frame = 0
				idle_timer.start(3.0)
			if _animated_sprite.animation == "fall":
				_animated_sprite.play("idle")
				_animated_sprite. frame = 0
				idle_timer.start(3.0)
	# Als we al in idle zijn, doe NIETS - laat de timer zijn werk doen

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
