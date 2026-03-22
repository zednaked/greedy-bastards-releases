## ScreenFX — autoload singleton.
## Gerencia o post-process de tela (vignette, grain, chromatic aberration, hit flash).
## Acesso: ScreenFX.trigger_hit_flash() / ScreenFX.trigger_attack()
extends CanvasLayer

var _mat: ShaderMaterial = null
var _hit_timer     := 0.0
var _aberration    := 0.0
var _target_aber   := 0.0

func _ready() -> void:
	layer        = 127
	process_mode = Node.PROCESS_MODE_ALWAYS

	var shader := load("res://shaders/post_process.gdshader") as Shader
	if shader == null:
		push_warning("ScreenFX: post_process.gdshader não encontrado")
		return

	_mat        = ShaderMaterial.new()
	_mat.shader = shader

	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material     = _mat
	add_child(rect)

func _process(delta: float) -> void:
	if _mat == null:
		return

	_mat.set_shader_parameter("time", Time.get_ticks_msec() * 0.001)

	# Hit flash — decai em 0.55s
	if _hit_timer > 0.0:
		_hit_timer = maxf(0.0, _hit_timer - delta)
		_mat.set_shader_parameter("hit_flash", _hit_timer / 0.55)
	else:
		_mat.set_shader_parameter("hit_flash", 0.0)

	# Chromatic aberration — decai suavemente
	_aberration = lerpf(_aberration, _target_aber, delta * 7.0)
	_target_aber = lerpf(_target_aber, 0.0, delta * 4.5)
	_mat.set_shader_parameter("aberration", _aberration)

## Chamado quando o player toma dano. intensity 0–1.
func trigger_hit_flash(intensity: float = 1.0) -> void:
	_hit_timer   = maxf(_hit_timer, 0.55 * clampf(intensity, 0.0, 1.0))
	_target_aber = maxf(_target_aber, 0.005 * intensity)

## Chamado a cada ataque do player — leve aberração de ataque.
func trigger_attack() -> void:
	_target_aber = maxf(_target_aber, 0.002)

## Chamado em parry — aberração mais forte.
func trigger_parry() -> void:
	_target_aber = maxf(_target_aber, 0.004)
