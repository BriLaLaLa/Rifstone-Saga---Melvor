class_name NodeArt
extends Control
## Animated picture of the node resource: an `AnimatedSprite2D` ("NodeSprite") fed by the frames of
## `assets/nodes/<skill>/frame_N.svg` (docs/04_DATA_SCHEMA_M25.md §30.3) and a `CPUParticles2D` ("NodeParticles").
## Without the files a placeholder drawn by code is used. Presentation only; stops with "Effetti visivi ridotti".

const ASSET_DIR: String = "res://assets/nodes/%s/"
const FRAME_FILE: String = "frame_%d.svg"
const RICH_FILE: String = "ricco.svg"
const MAX_FRAMES: int = 8
const PLACEHOLDER_FRAMES: int = 4
const PLACEHOLDER_SIZE: int = 48
const FRAME_FPS: float = 4.0
const ART_SIZE: Vector2 = Vector2(160, 120)
const SPRITE_SCALE: float = 2.0
const PARTICLE_AMOUNT: int = 10

var _sprite: AnimatedSprite2D = null
var _particles: CPUParticles2D = null
var _skill: StringName = &""


func _ready() -> void:
	custom_minimum_size = ART_SIZE
	clip_contents = true
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "NodeSprite"
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	add_child(_sprite)
	_particles = CPUParticles2D.new()
	_particles.name = "NodeParticles"
	_particles.amount = PARTICLE_AMOUNT
	_particles.lifetime = 1.6
	_particles.direction = Vector2.UP
	_particles.spread = 40.0
	_particles.gravity = Vector2.ZERO
	_particles.initial_velocity_min = 12.0
	_particles.initial_velocity_max = 28.0
	_particles.scale_amount_min = 2.0
	_particles.scale_amount_max = 4.0
	_particles.color = UiStyle.GOLD_LIGHT
	add_child(_particles)
	resized.connect(_on_resized)
	_on_resized()


## SpriteFrames of the skill from the files by convention; a placeholder drawn by code when there are none.
static func build_frames(skill_id: StringName) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", FRAME_FPS)
	var dir: String = ASSET_DIR % String(skill_id)
	for i: int in MAX_FRAMES:
		var path: String = dir + FRAME_FILE % i
		if not ResourceLoader.exists(path):
			break
		frames.add_frame(&"default", load(path) as Texture2D)
	if frames.get_frame_count(&"default") == 0:
		for i: int in PLACEHOLDER_FRAMES:
			frames.add_frame(&"default", _placeholder(skill_id, i))
	return frames


## Path of the "rich" icon of the skill, or "" when the file does not exist.
static func rich_icon_path(skill_id: StringName) -> String:
	var path: String = (ASSET_DIR % String(skill_id)) + RICH_FILE
	return path if ResourceLoader.exists(path) else ""


static func _placeholder(skill_id: StringName, index: int) -> Texture2D:
	var img := Image.create(PLACEHOLDER_SIZE, PLACEHOLDER_SIZE, false, Image.FORMAT_RGBA8)
	var hue: float = float(String(skill_id).hash() % 360) / 360.0
	var inset: int = 6 + index * 2
	img.fill_rect(Rect2i(inset, inset, PLACEHOLDER_SIZE - 2 * inset, PLACEHOLDER_SIZE - 2 * inset), Color.from_hsv(hue, 0.5, 0.85))
	return ImageTexture.create_from_image(img)


## Shows the art of `skill_id` (frames rebuilt only when the skill changes).
func set_skill(skill_id: StringName) -> void:
	if skill_id == _skill or _sprite == null:
		return
	_skill = skill_id
	_sprite.sprite_frames = build_frames(skill_id)
	var moving: bool = not CombatFx.reduced()
	if moving:
		_sprite.play(&"default")
	else:
		_sprite.stop()
	_particles.emitting = moving


## Makes the art `factor` times bigger than the default (area and sprite).
func set_zoom(factor: float) -> void:
	custom_minimum_size = ART_SIZE * factor
	if _sprite != null:
		_sprite.scale = Vector2.ONE * SPRITE_SCALE * factor


## Tint of the particles (the colour of the node).
func set_tint(color: Color) -> void:
	if _particles != null:
		_particles.color = color


func _on_resized() -> void:
	if _sprite != null:
		_sprite.position = size * 0.5
		_particles.position = Vector2(size.x * 0.5, size.y * 0.8)
