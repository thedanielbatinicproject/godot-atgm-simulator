@tool
extends Control
class_name DistanceBar

# ============================================================================
# DISTANCE BAR
# ============================================================================
# Vertikalni bar koji prikazuje udaljenost od mete.
# Sredina bara = početna udaljenost (50% fill)
# Vrh = 0m (target reached), Dno = početna udaljenost
# Fill raste prema gore kako se projektil približava meti.
# ============================================================================

@export_category("Distance Bar")

@export_group("Appearance")
## Boja pozadine (transparentnija)
@export var background_color: Color = Color(1.0, 1.0, 1.0, 0.15)
## Boja ispune - bliže meti
@export var fill_color_close: Color = Color(0.0, 1.0, 0.3, 0.7)
## Boja ispune - dalje od mete
@export var fill_color_far: Color = Color(1.0, 0.3, 0.0, 0.7)
## Boja obruba
@export var border_color: Color = Color(1.0, 1.0, 1.0, 0.3)
## Debljina obruba
@export var border_width: float = 1.0
## Boja oznake početne udaljenosti
@export var midline_color: Color = Color(1.0, 1.0, 1.0, 0.4)

@export_group("Layout")
## Padding unutar containera (postotak)
@export_range(0.0, 0.5, 0.01) var padding_percent: float = 0.1

@export_group("Animation")
## Brzina animacije ispune (0 = instant)
@export var fill_speed: float = 8.0

@export_group("Label")
## Prikaži tekst ispod bara
@export var show_label: bool = true
## Tekst koji se prikazuje
@export var label_text: String = "DST"
## Custom font (ostavi prazno za default)
@export var label_font: Font = null
## Veličina fonta
@export var label_font_size: int = 10
## Boja teksta
@export var label_color: Color = Color(1.0, 1.0, 1.0, 0.6)
## Razmak između bara i teksta
@export var label_margin_top: float = 6.0

# Interne varijable
var initial_distance: float = 100.0  # Početna udaljenost (postavlja se pri startu)
var target_distance: float = 100.0   # Trenutna ciljna udaljenost
var current_distance: float = 100.0  # Animirana trenutna vrijednost

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float):
	# Glatka animacija
	if fill_speed > 0:
		current_distance = lerpf(current_distance, target_distance, fill_speed * delta)
	else:
		current_distance = target_distance
	
	# Ažuriraj prikaz
	queue_redraw()

func set_initial_distance(distance: float) -> void:
	"""Postavi početnu udaljenost (koristi se kao referentna točka - 50%)."""
	initial_distance = maxf(distance, 1.0)  # Minimum 1m to avoid division by zero
	current_distance = distance
	target_distance = distance

func set_current_distance(distance: float) -> void:
	"""Postavi trenutnu udaljenost od mete."""
	target_distance = maxf(distance, 0.0)

func _draw():
	var own_size = size
	if own_size.x <= 0 or own_size.y <= 0:
		return  # Skip if size not ready
	
	var padding_h = own_size.x * padding_percent
	var padding_v = own_size.y * padding_percent
	
	# Calculate bar dimensions within container
	var bar_w = own_size.x - (padding_h * 2.0)
	var bar_h = own_size.y - (padding_v * 2.0)
	var bar_x = padding_h
	var bar_y = padding_v
	
	# Reserve space for label if shown
	if show_label:
		var label_space = label_font_size + label_margin_top + 4.0
		bar_h -= label_space
	
	if bar_w <= 0 or bar_h <= 0:
		return  # Skip if invalid dimensions
	
	var bar_rect = Rect2(bar_x, bar_y, bar_w, bar_h)
	
	# 1. Nacrtaj pozadinu
	draw_rect(bar_rect, background_color, true)
	
	# 2. Izračunaj fill
	# initial_distance = 50% fill (midpoint)
	# 0 distance = 100% fill (top)
	# 2x initial_distance = 0% fill (bottom)
	# Formula: fill_percent = 1.0 - (current_distance / (initial_distance * 2.0))
	# Clamped to [0, 1]
	var fill_percent: float
	if initial_distance > 0:
		fill_percent = 1.0 - (current_distance / (initial_distance * 2.0))
		fill_percent = clampf(fill_percent, 0.0, 1.0)
	else:
		fill_percent = 0.5
	
	# 3. Nacrtaj ispunu (odozdo prema gore)
	var fill_height = bar_h * fill_percent
	var fill_rect = Rect2(
		bar_x,
		bar_y + bar_h - fill_height,  # Počinje odozdo
		bar_w,
		fill_height
	)
	
	# Interpoliraj boju ovisno o udaljenosti (bliže = zeleno, dalje = crveno)
	var color_t = clampf(current_distance / initial_distance, 0.0, 2.0) / 2.0
	var fill_color = fill_color_close.lerp(fill_color_far, color_t)
	draw_rect(fill_rect, fill_color, true)
	
	# 4. Nacrtaj obrub
	draw_rect(bar_rect, border_color, false, border_width)
	
	# 5. Nacrtaj horizontalnu liniju na 50% (početna udaljenost)
	var midline_y = bar_y + bar_h * 0.5
	draw_line(
		Vector2(bar_x, midline_y),
		Vector2(bar_x + bar_w, midline_y),
		midline_color,
		2.0
	)
	
	# 6. Oznake za 25%, 75%
	_draw_tick_marks(bar_x, bar_y, bar_h, bar_w)
	
	# 7. Tekst ispod bara
	if show_label:
		_draw_label(bar_x, bar_y + bar_h, bar_w)

func _draw_tick_marks(bar_x: float, bar_y: float, bar_height: float, bar_w: float):
	"""Nacrtaj male oznake na 25%, 75%."""
	var tick_color = Color(1.0, 1.0, 1.0, 0.2)
	var tick_width = bar_w * 0.4
	
	for percent in [0.25, 0.75]:
		var y_pos = bar_y + bar_height * (1.0 - percent)
		draw_line(
			Vector2(bar_x, y_pos),
			Vector2(bar_x + tick_width, y_pos),
			tick_color,
			1.0
		)

func _draw_label(bar_x: float, bar_bottom_y: float, bar_w: float):
	"""Nacrtaj tekst ispod bara."""
	var font: Font = label_font if label_font else ThemeDB.fallback_font
	
	var text_pos = Vector2(
		bar_x + bar_w / 2.0,
		bar_bottom_y + label_margin_top + label_font_size
	)
	
	# Centriraj tekst horizontalno
	var text_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, label_font_size)
	text_pos.x -= text_size.x / 2.0
	
	draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size, label_color)
