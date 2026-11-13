class_name CombatFx
extends RefCounted
## Visual weight of the combat page (M17-07): area atmosphere, breathing icon, Monolith halo, shake and bar easing.
## Presentation only: no game state. Every looping or moving effect checks `reduced()` (setting "Effetti visivi
## ridotti") and does nothing when it is on; the callers never start effects in the compact view.


static func reduced() -> bool:
	return bool(GameSettings.get_value(GameSettings.KEY_REDUCED_FX))


## Tint of an area from its rank in the ordered list of areas (golden-ratio hue steps: neighbours look different).
static func area_tint(rank: int) -> Color:
	var hue: float = fposmod(UiStyle.COMBAT_AREA_HUE_START + float(rank) * UiStyle.COMBAT_AREA_HUE_STEP, 1.0)
	return Color.from_hsv(hue, UiStyle.COMBAT_AREA_SATURATION, UiStyle.COMBAT_AREA_VALUE)


## Mouse-transparent vertical gradient (tint at the top, the card background at the bottom) to put behind the zone.
static func make_backdrop() -> TextureRect:
	var rect := TextureRect.new()
	rect.name = "AreaBackdrop"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture = backdrop_texture(UiStyle.COMBAT_ENEMY_BG)
	return rect


static func backdrop_texture(top: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([top, UiStyle.COMBAT_ENEMY_BG])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 4
	tex.height = 64
	return tex


static func kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


## Slow scale loop of `icon` (it pivots on its centre).
static func breathe(icon: Control) -> Tween:
	if reduced():
		return null
	var tween: Tween = icon.create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(icon, "scale", Vector2.ONE * UiStyle.COMBAT_BREATH_SCALE, UiStyle.COMBAT_BREATH_SEC)
	tween.tween_property(icon, "scale", Vector2.ONE, UiStyle.COMBAT_BREATH_SEC)
	return tween


## Pulsing alpha loop of a halo behind a Monolith (steady when reduced).
static func pulse(halo: CanvasItem) -> Tween:
	if reduced():
		halo.modulate.a = UiStyle.COMBAT_HALO_ALPHA_MAX
		return null
	var tween: Tween = halo.create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(halo, "modulate:a", UiStyle.COMBAT_HALO_ALPHA_MAX, UiStyle.COMBAT_HALO_SEC)
	tween.tween_property(halo, "modulate:a", UiStyle.COMBAT_HALO_ALPHA_MIN, UiStyle.COMBAT_HALO_SEC)
	return tween


## Brief rotation shake of a control (containers do not override `rotation`).
static func shake(node: Control) -> Tween:
	if reduced():
		return null
	node.pivot_offset = node.size / 2.0
	var tween: Tween = node.create_tween()
	var angle: float = deg_to_rad(UiStyle.COMBAT_SHAKE_DEGREES)
	tween.tween_property(node, "rotation", angle, UiStyle.COMBAT_SHAKE_SEC)
	tween.tween_property(node, "rotation", -angle, UiStyle.COMBAT_SHAKE_SEC * 2.0)
	tween.tween_property(node, "rotation", 0.0, UiStyle.COMBAT_SHAKE_SEC)
	return tween


## Red pulse of an HP bar (steady red when reduced); with `low` false it only restores the colour.
static func low_hp_pulse(bar: Control, low: bool) -> Tween:
	bar.modulate = Color.WHITE
	if not low:
		return null
	if reduced():
		bar.modulate = UiStyle.COMBAT_LOW_HP_COLOR
		return null
	var tween: Tween = bar.create_tween().set_loops()
	tween.tween_property(bar, "modulate", UiStyle.COMBAT_LOW_HP_COLOR, UiStyle.COMBAT_LOW_HP_SEC)
	tween.tween_property(bar, "modulate", Color.WHITE, UiStyle.COMBAT_LOW_HP_SEC)
	return tween


## Next value of an eased bar: moves `shown` towards `target` with `delta`; snaps when reduced or `shown` < 0 (first draw).
static func ease_bar(shown: float, target: float, delta: float) -> float:
	if reduced() or shown < 0.0:
		return target
	var weight: float = clampf(delta * UiStyle.COMBAT_BAR_EASE_SPEED, 0.0, 1.0)
	var next: float = lerpf(shown, target, weight)
	return target if absf(next - target) < 0.5 else next
