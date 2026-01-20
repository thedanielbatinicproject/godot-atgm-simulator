@tool
extends Control
class_name ThrustBar

# ============================================================================
# THRUST BAR
# ============================================================================
# Vertikalni bar koji prikazuje trenutni thrust.
# Pozadina je transparentnija, ispuna se puni odozdo prema gore.
# ============================================================================

@export_category("Thrust Bar")

@export_group("Appearance")
## Boja pozadine (transparentnija)
@export var background_color: Color = Color(1.0, 1.0, 1.0, 0.15)
## Boja ispune (manje transparentna)
@export var fill_color: Color = Color(1.0, 0.5, 0.0, 0.7)
## Boja obruba
@export var border_color: Color = Color(1.0, 1.0, 1.0, 0.3)
## Debljina obruba
@export var border_width: float = 1.0

@export_group("Layout")
## Širina bara u pikselima (only used when not in container)
@export var bar_width: float = 12.0
## Padding unutar containera (postotak)
@export_range(0.0, 0.5, 0.01) var padding_percent: float = 0.1
## If true, use own size (from container). If false, calculate from viewport.
@export var use_container_size: bool = true

@export_group("Animation")
## Brzina animacije ispune (0 = instant)
@export var fill_speed: float = 8.0

@export_group("Label")
## Prikaži tekst ispod bara
@export var show_label: bool = true
## Tekst koji se prikazuje
@export var label_text: String = "THR"
## Custom font (ostavi prazno za default)
@export var label_font: Font = null
## Veličina fonta
@export var label_font_size: int = 10
## Boja teksta
@export var label_color: Color = Color(1.0, 1.0, 1.0, 0.6)
## Razmak između bara i teksta
@export var label_margin_top: float = 6.0

# Interne varijable
var target_thrust: float = 0.0
var current_thrust: float = 0.0

func _ready():
	# Postavi anchore za responsivnost
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float):
	# Glatka animacija
	if fill_speed > 0:
		current_thrust = lerpf(current_thrust, target_thrust, fill_speed * delta)
	else:
		current_thrust = target_thrust
	
	# Ažuriraj prikaz
	queue_redraw()

func set_thrust_value(value: float):
	"""Postavi ciljnu vrijednost thrusta (0.0 - 1.0)."""
	target_thrust = clampf(value, 0.0, 1.0)

func _draw():
	var bar_x: float
	var bar_y: float
	var bar_w: float
	var bar_h: float
	
	if use_container_size:
		# Render inside container using own size
		var own_size = size
		if own_size.x <= 0 or own_size.y <= 0:
			return  # Skip if size not ready yet
		
		var pad_pct = padding_percent if padding_percent != null else 0.1
		var padding_h = own_size.x * pad_pct
		var padding_v = own_size.y * pad_pct
		
		# Calculate bar dimensions within container
		bar_w = own_size.x - (padding_h * 2.0)
		bar_h = own_size.y - (padding_v * 2.0)
		bar_x = padding_h
		bar_y = padding_v
		
		# Reserve space for label if shown
		if show_label:
			var label_space = label_font_size + label_margin_top + 4.0
			bar_h -= label_space
		
		if bar_w <= 0 or bar_h <= 0:
			return  # Skip if invalid dimensions
	else:
		# Legacy: viewport-relative positioning (for backwards compatibility)
		var viewport_size = get_viewport_rect().size
		bar_h = viewport_size.y * 0.7  # Default 70% height
		bar_w = bar_width
		bar_x = viewport_size.x - 20.0 - bar_width
		bar_y = viewport_size.y * 0.15
	
	var bar_rect = Rect2(bar_x, bar_y, bar_w, bar_h)
	
	# 1. Nacrtaj pozadinu (transparentnija)
	draw_rect(bar_rect, background_color, true)
	
	# 2. Nacrtaj ispunu (odozdo prema gore)
	var fill_height = bar_h * current_thrust
	var fill_rect = Rect2(
		bar_x,
		bar_y + bar_h - fill_height,  # Počinje odozdo
		bar_w,
		fill_height
	)
	draw_rect(fill_rect, fill_color, true)
	
	# 3. Nacrtaj obrub
	draw_rect(bar_rect, border_color, false, border_width)
	
	# 4. Opcijski: oznake za 25%, 50%, 75%
	_draw_tick_marks(bar_x, bar_y, bar_h)
	
	# 5. Tekst ispod bara
	if show_label:
		_draw_label(bar_x, bar_y + bar_h, bar_w)

func _draw_tick_marks(bar_x: float, bar_y: float, bar_height: float):
	"""Nacrtaj male oznake na 25%, 50%, 75%."""
	var tick_color = Color(1.0, 1.0, 1.0, 0.2)
	# Use a fraction of bar width for tick marks
	var bar_w = size.x - (size.x * padding_percent * 2.0) if use_container_size else bar_width
	var tick_width = bar_w * 0.4
	
	for percent in [0.25, 0.5, 0.75]:
		var y_pos = bar_y + bar_height * (1.0 - percent)
		draw_line(
			Vector2(bar_x, y_pos),
			Vector2(bar_x + tick_width, y_pos),
			tick_color,
			1.0
		)

func _draw_label(bar_x: float, bar_bottom_y: float, bar_w: float = -1.0):
	"""Nacrtaj tekst ispod bara."""
	var font: Font = label_font if label_font else ThemeDB.fallback_font
	
	# Determine bar width for centering
	var actual_bar_width = bar_w if bar_w > 0 else bar_width
	
	var text_pos = Vector2(
		bar_x + actual_bar_width / 2.0,
		bar_bottom_y + label_margin_top + label_font_size
	)
	
	# Centriraj tekst horizontalno
	var text_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, label_font_size)
	text_pos.x -= text_size.x / 2.0
	
	draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size, label_color)
