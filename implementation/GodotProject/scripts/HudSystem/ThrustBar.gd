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
## Širina bara u pikselima
@export var bar_width: float = 12.0
## Razmak od desnog ruba ekrana
@export var margin_right: float = 20.0
## Razmak od vrha ekrana (postotak)
@export_range(0.0, 0.5, 0.01) var margin_top_percent: float = 0.15
## Razmak od dna ekrana (postotak)
@export_range(0.0, 0.5, 0.01) var margin_bottom_percent: float = 0.15

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
	var viewport_size = get_viewport_rect().size
	
	# Izračunaj dimenzije bara
	var bar_height = viewport_size.y * (1.0 - margin_top_percent - margin_bottom_percent)
	var bar_x = viewport_size.x - margin_right - bar_width
	var bar_y = viewport_size.y * margin_top_percent
	
	var bar_rect = Rect2(bar_x, bar_y, bar_width, bar_height)
	
	# 1. Nacrtaj pozadinu (transparentnija)
	draw_rect(bar_rect, background_color, true)
	
	# 2. Nacrtaj ispunu (odozdo prema gore)
	var fill_height = bar_height * current_thrust
	var fill_rect = Rect2(
		bar_x,
		bar_y + bar_height - fill_height,  # Počinje odozdo
		bar_width,
		fill_height
	)
	draw_rect(fill_rect, fill_color, true)
	
	# 3. Nacrtaj obrub
	draw_rect(bar_rect, border_color, false, border_width)
	
	# 4. Opcijski: oznake za 25%, 50%, 75%
	_draw_tick_marks(bar_x, bar_y, bar_height)
	
	# 5. Tekst ispod bara
	if show_label:
		_draw_label(bar_x, bar_y + bar_height)

func _draw_tick_marks(bar_x: float, bar_y: float, bar_height: float):
	"""Nacrtaj male oznake na 25%, 50%, 75%."""
	var tick_color = Color(1.0, 1.0, 1.0, 0.2)
	var tick_width = bar_width * 0.4
	
	for percent in [0.25, 0.5, 0.75]:
		var y_pos = bar_y + bar_height * (1.0 - percent)
		draw_line(
			Vector2(bar_x, y_pos),
			Vector2(bar_x + tick_width, y_pos),
			tick_color,
			1.0
		)

func _draw_label(bar_x: float, bar_bottom_y: float):
	"""Nacrtaj tekst ispod bara."""
	var font: Font = label_font if label_font else ThemeDB.fallback_font
	var text_pos = Vector2(
		bar_x + bar_width / 2.0,
		bar_bottom_y + label_margin_top + label_font_size
	)
	
	# Centriraj tekst horizontalno
	var text_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, label_font_size)
	text_pos.x -= text_size.x / 2.0
	
	draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size, label_color)
