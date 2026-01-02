extends Control
class_name StickController

# SIGNALI
signal gimbal_changed(gimbal: Vector2)

# KONFIGURACIJA
@export var config: ControlConfig

# TEKSTURE (opcionalno - može se postaviti iz editora)
@export var background_texture: Texture2D
@export var cursor_texture: Texture2D
@export var center_texture: Texture2D

# CHILD NODOVI (automatski se pronalaze ili kreiraju)
var background_node: TextureRect
var cursor_node: TextureRect
var center_node: TextureRect

# STATE - točne vrijednosti za simulaciju
var gimbal_x: float = 0.0
var gimbal_y: float = 0.0

# STATE - smoothed vrijednosti za vizualni prikaz
var display_x: float = 0.0
var display_y: float = 0.0
var visual_smoothing: float = 0.15

var is_dragging: bool = false
var is_keyboard_active: bool = false
var is_joystick_active: bool = false
var enabled: bool = true

# ANIMACIJA
var return_tween: Tween

# RESPONZIVNI PARAMETRI
@export var stick_radius_ratio: float = 0.4  # Radius kao % od manje dimenzije kontrole
@export var cursor_size_ratio: float = 0.15  # Cursor veličina kao % od kontrole
@export var center_size_ratio: float = 0.05  # Center dot kao % od kontrole

# Viewport responzivnost - ako true, veličina kontrole se računa prema viewportu
@export var responsive_to_viewport: bool = true
@export var viewport_size_ratio: float = 0.25  # Kontrola je 25% manje dimenzije viewporta

func _ready():
	_setup_nodes()
	set_process_input(true)
	set_process(true)
	
	# Reagiraj na promjenu veličine
	resized.connect(_on_resized)
	
	# Viewport responzivnost
	if responsive_to_viewport:
		get_tree().root.size_changed.connect(_on_viewport_resized)
		# Defer da se osigura da je sve učitano
		call_deferred("_on_viewport_resized")
	else:
		# Defer layout update ako nije viewport responsive
		call_deferred("_update_layout")

func _on_viewport_resized():
	if not responsive_to_viewport:
		return
	var viewport_size = get_viewport_rect().size
	var min_dim = min(viewport_size.x, viewport_size.y)
	var new_size = min_dim * viewport_size_ratio
	custom_minimum_size = Vector2(new_size, new_size)
	size = Vector2(new_size, new_size)
	
	# Ažuriraj offsets za centriranje (anchor je 0.5, 0.5)
	var half_size = new_size / 2.0
	offset_left = -half_size
	offset_top = -half_size
	offset_right = half_size
	offset_bottom = half_size
	
	_update_layout()

func _setup_nodes():
	# Pronađi ili kreiraj Background
	background_node = get_node_or_null("Background") as TextureRect
	if not background_node:
		background_node = TextureRect.new()
		background_node.name = "Background"
		add_child(background_node)
	
	# Pronađi ili kreiraj Center
	center_node = get_node_or_null("Center") as TextureRect
	if not center_node:
		center_node = TextureRect.new()
		center_node.name = "Center"
		add_child(center_node)
	
	# Pronađi ili kreiraj Cursor
	cursor_node = get_node_or_null("Cursor") as TextureRect
	if not cursor_node:
		cursor_node = TextureRect.new()
		cursor_node.name = "Cursor"
		add_child(cursor_node)
	
	# Postavi teksture ako su zadane
	if background_texture:
		background_node.texture = background_texture
	if cursor_texture:
		cursor_node.texture = cursor_texture
	if center_texture:
		center_node.texture = center_texture
	
	# Expand mode - dozvoli smanjivanje teksture
	background_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cursor_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	center_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	# Stretch mode - zadrži aspect ratio
	background_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cursor_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Postavi layout
	_update_layout()

func _on_resized():
	_update_layout()

func _update_layout():
	# Provjeri da nodovi postoje
	if not background_node or not center_node or not cursor_node:
		return
	
	var control_size = size
	# Osiguraj da size nije 0
	if control_size.x <= 0 or control_size.y <= 0:
		return
	
	var min_dim = min(control_size.x, control_size.y)
	var center_pos = control_size / 2.0
	
	# Background - centriran, veličina prema ratio
	var bg_size = min_dim * 0.9
	background_node.size = Vector2(bg_size, bg_size)
	background_node.position = center_pos - Vector2(bg_size, bg_size) / 2.0
	background_node.visible = true
	
	# Center dot - centriran
	var center_size = min_dim * center_size_ratio
	center_node.size = Vector2(center_size, center_size)
	center_node.position = center_pos - Vector2(center_size, center_size) / 2.0
	center_node.visible = true
	
	# Cursor - početna pozicija u centru
	var cursor_size = min_dim * cursor_size_ratio
	cursor_node.size = Vector2(cursor_size, cursor_size)
	cursor_node.visible = true
	_update_cursor_position()
	
	print("StickController layout: size=", control_size, " bg_size=", bg_size)

func _update_cursor_position():
	var control_size = size
	var min_dim = min(control_size.x, control_size.y)
	var center_pos = control_size / 2.0
	var stick_radius = min_dim * stick_radius_ratio
	var cursor_size = min_dim * cursor_size_ratio
	
	# Pozicija kursora prema display vrijednostima
	var offset = Vector2(display_x, -display_y) * stick_radius
	cursor_node.position = center_pos + offset - Vector2(cursor_size, cursor_size) / 2.0

func _process(_delta):
	if not enabled:
		return
	
	var prev_x = gimbal_x
	var prev_y = gimbal_y
	var input_handled = false
	
	# JOYSTICK - desna gljivica
	if config.enable_gamepad_input:
		var joy_x = Input.get_axis("gimbal_left", "gimbal_right")
		var joy_y = Input.get_axis("gimbal_down", "gimbal_up")
		var joy_magnitude = sqrt(joy_x * joy_x + joy_y * joy_y)
		
		if joy_magnitude > config.deadzone_joystick:
			is_joystick_active = true
			# Normaliziraj na kružnicu ako prelazi 1.0
			if joy_magnitude > 1.0:
				joy_x /= joy_magnitude
				joy_y /= joy_magnitude
			gimbal_x = joy_x
			gimbal_y = joy_y
			_kill_tween()
			input_handled = true
		else:
			if is_joystick_active:
				is_joystick_active = false
				if not is_dragging and not is_keyboard_active:
					_animate_return_to_center()
	
	# TIPKOVNICA - strelice
	if config.enable_keyboard_input and not input_handled:
		var kb_active = Input.is_action_pressed("gimbal_left") or Input.is_action_pressed("gimbal_right") or \
					   Input.is_action_pressed("gimbal_up") or Input.is_action_pressed("gimbal_down")
		
		if kb_active:
			is_keyboard_active = true
			var kb_x = Input.get_axis("gimbal_left", "gimbal_right")
			var kb_y = Input.get_axis("gimbal_down", "gimbal_up")
			var kb_magnitude = sqrt(kb_x * kb_x + kb_y * kb_y)
			
			# Normaliziraj na kružnicu ako prelazi 1.0
			if kb_magnitude > 1.0:
				kb_x /= kb_magnitude
				kb_y /= kb_magnitude
			gimbal_x = kb_x
			gimbal_y = kb_y
			_kill_tween()
			input_handled = true
		else:
			if is_keyboard_active:
				is_keyboard_active = false
				if not is_dragging and not is_joystick_active:
					_animate_return_to_center()
	
	# Emit signal UVIJEK sa točnim podacima za simulaciju
	if input_handled or is_joystick_active:
		gimbal_changed.emit(get_gimbal())
	
	# Ako je tween aktivan, emitiraj signal i za animaciju povratka
	if return_tween and return_tween.is_running():
		gimbal_changed.emit(get_gimbal())
	
	# Smooth vizualni prikaz (lerp prema target vrijednostima)
	display_x = lerpf(display_x, gimbal_x, visual_smoothing)
	display_y = lerpf(display_y, gimbal_y, visual_smoothing)
	
	# Ažuriraj poziciju kursora
	_update_cursor_position()

func _input(event: InputEvent):
	if not enabled or not config.enable_mouse_input:
		return
	
	# Izračunaj responzivne vrijednosti
	var control_size = size
	var min_dim = min(control_size.x, control_size.y)
	var center_pos = control_size / 2.0
	var stick_radius = min_dim * stick_radius_ratio
	
	# MIŠ - LMB drag
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Provjeri je li klik unutar stick područja
				var mouse_pos = get_local_mouse_position()
				var dist = (mouse_pos - center_pos).length()
				if dist <= stick_radius + 20:  # malo veće područje za lakši klik
					is_dragging = true
					_kill_tween()
			else:
				if is_dragging:
					is_dragging = false
					if not is_keyboard_active and not is_joystick_active:
						_animate_return_to_center()
	
	# Mouse motion
	elif event is InputEventMouseMotion and is_dragging:
		var mouse_pos = get_local_mouse_position()
		var offset = mouse_pos - center_pos
		
		# Ograniči na stick_radius
		if offset.length() > stick_radius:
			offset = offset.normalized() * stick_radius
		
		gimbal_x = offset.x / stick_radius
		gimbal_y = -offset.y / stick_radius  # Y invertiran (gore je pozitivno)
		
		gimbal_changed.emit(get_gimbal())
		_update_cursor_position()

func _kill_tween():
	if return_tween:
		return_tween.kill()
		return_tween = null

func _animate_return_to_center():
	_kill_tween()
	
	# Ne animiraj ako je već u centru
	if abs(gimbal_x) < 0.01 and abs(gimbal_y) < 0.01:
		gimbal_x = 0.0
		gimbal_y = 0.0
		display_x = 0.0
		display_y = 0.0
		gimbal_changed.emit(get_gimbal())
		queue_redraw()
		return
	
	return_tween = create_tween()
	return_tween.set_trans(config.return_animation_trans)
	return_tween.set_ease(config.return_animation_ease)
	
	# Animiraj i gimbal i display varijable zajedno
	return_tween.tween_property(self, "gimbal_x", 0.0, config.return_animation_duration)
	return_tween.parallel().tween_property(self, "gimbal_y", 0.0, config.return_animation_duration)
	return_tween.parallel().tween_property(self, "display_x", 0.0, config.return_animation_duration)
	return_tween.parallel().tween_property(self, "display_y", 0.0, config.return_animation_duration)
	
	# Tween method za kontinuirano emitiranje signala tijekom animacije
	return_tween.set_parallel(false)
	return_tween.tween_callback(_on_return_complete)

func _on_return_complete():
	gimbal_changed.emit(get_gimbal())
	_update_cursor_position()

# PUBLIC API

func get_gimbal() -> Vector2:
	"""Vrati normalizirani gimbal (u_x, u_y) na kružnicu."""
	var norm = sqrt(gimbal_x * gimbal_x + gimbal_y * gimbal_y)
	if norm > 1.0:
		return Vector2(gimbal_x / norm, gimbal_y / norm)
	return Vector2(gimbal_x, gimbal_y)

func get_input_vector() -> Vector3:
	"""Kompatibilnost sa BaseInputController."""
	var g = get_gimbal()
	return Vector3(0.0, g.x, g.y)

func reset_input() -> void:
	"""Reset na centar bez animacije."""
	gimbal_x = 0.0
	gimbal_y = 0.0
	display_x = 0.0
	display_y = 0.0
	is_dragging = false
	is_keyboard_active = false
	is_joystick_active = false
	_kill_tween()
	gimbal_changed.emit(get_gimbal())
	_update_cursor_position()

func enable() -> void:
	enabled = true

func disable() -> void:
	enabled = false
	reset_input()

func set_enabled(value: bool) -> void:
	if value:
		enable()
	else:
		disable()

func is_enabled() -> bool:
	return enabled

func set_config(new_config: ControlConfig) -> void:
	config = new_config
	_update_layout()
