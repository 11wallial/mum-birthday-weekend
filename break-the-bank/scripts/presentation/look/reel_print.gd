## Bakes the printed reel strip, once per process, on the GPU.
##
## A real drum wears a printed paper strip: ten cells, each a bordered plate
## with a symbol inked on it. This builds that strip as a texture — one cell
## per symbol from the content set, composed by [code]reel_plate.gdshader[/code]
## from the instruction lists in [SymbolArt] — by rendering a [SubViewport] for
## a single frame at boot and keeping the grab.
##
## One bake serves everything that shows a symbol on the machine: the drum
## wraps the whole strip, and the landed plates over the payline window are the
## same texture addressed one cell at a time, which is what makes a dynamic
## plate indistinguishable from the drum's own printing.
##
## The bake is asynchronous by nature — a viewport needs a frame — so callers
## hand [method bake] a callable and get it back when the strip exists. Both
## in-tree callers tolerate the wait: the drums boot wearing plain paper and
## are dressed a frame later.
class_name ReelPrint
extends RefCounted

## Cells around the drum. Ten divides TAU into the band pitch the window
## geometry is built on; MachineFrame.BAND_ANGLE is TAU over this.
const CELLS: int = 10
## One cell in texels: x along the drum's axis, y around its circumference.
## 1072 texels per metre on both axes, so print density is isotropic.
const CELL_PX: Vector2i = Vector2i(416, 256)

const PLATE_SHADER: String = "res://assets/shaders/reel_plate.gdshader"

## The printed order around the drum. Cosmetic — the simulation draws symbols
## by weight, not by strip position — so it is chosen for looks: values spread
## out, the skull deep in the run of fruit, and the classic repeated cherry
## filling the tenth cell. Cell 0 is the seven, so a machine at rest shows its
## best face on the payline.
const PREFERRED: Array = [&"seven", &"cherry", &"bar", &"bell", &"lemon",
		&"skull", &"wild", &"cherry", &"double_bar", &"diamond"]

static var _strip: ImageTexture = null
static var _order: Array[StringName] = []
static var _pending: Array[Callable] = []
static var _baking: bool = false


## The baked strip, or null while the bake is still in flight.
static func strip() -> ImageTexture:
	return _strip


## The strip cell printed with [param symbol_id], or -1 when the symbol has no
## cell — in which case the caller falls back to the glyph label, exactly as it
## would for a symbol with no drawn art.
static func cell_of(symbol_id: StringName) -> int:
	return _order.find(symbol_id)


## Calls [param on_ready] once the strip exists: immediately when a previous
## bake is cached, otherwise after the one-frame render.
static func bake(host: Node, on_ready: Callable) -> void:
	if _strip != null:
		on_ready.call()
		return
	# A headless process has no rendering device, so the viewport grab comes
	# back null and the bake cannot happen at all. Callers already cope with a
	# strip that never arrives — the drums keep their plain paper and every
	# symbol falls back to its glyph — so the run boots instead of dying on the
	# grab. This is the path CI, the balance batch and the tests take.
	if DisplayServer.get_name() == "headless":
		on_ready.call()
		return
	_pending.append(on_ready)
	if _baking:
		return
	_baking = true
	_bake_async(host)


static func _bake_async(host: Node) -> void:
	_order = _strip_order()
	var viewport: SubViewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.size = Vector2i(CELL_PX.x, CELL_PX.y * CELLS)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var shader: Shader = load(PLATE_SHADER) as Shader
	var content: ContentDB = ContentDB.shared()
	for k: int in _order.size():
		viewport.add_child(_cell(k, content.symbol_by_id(_order[k]), shader))
	host.add_child(viewport)
	# One frame queues the render, the second guarantees it has been drawn on
	# every driver this ships on — including the web export, where a same-frame
	# grab returns an empty target.
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var target: ViewportTexture = viewport.get_texture()
	var image: Image = target.get_image() if target != null else null
	viewport.queue_free()
	if image != null:
		# The strip is read at grazing angles around the whole drum, so it needs
		# the mip chain a render target does not carry.
		image.generate_mipmaps()
		_strip = ImageTexture.create_from_image(image)
	else:
		# A driver that cannot hand back the target leaves the machine on plain
		# paper rather than taking the run down with it; clearing the order is
		# what makes cell_of say so, so callers fall back to the glyph.
		_order.clear()
	_baking = false
	var callbacks: Array[Callable] = _pending.duplicate()
	_pending.clear()
	for callback: Callable in callbacks:
		callback.call()


## One cell: a rect running the plate shader, plus the glyph as printed text
## when the symbol has no instruction list — new content lands legible.
static func _cell(index: int, def: SymbolDef, shader: Shader) -> Control:
	var rect: ColorRect = ColorRect.new()
	rect.position = Vector2(0.0, float(index * CELL_PX.y))
	rect.size = Vector2(CELL_PX)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	var ops: PackedFloat32Array = PackedFloat32Array()
	var tint: Color = Color.WHITE
	if def != null:
		ops = SymbolArt.ops_for(def.id)
		tint = def.color
	material.set_shader_parameter(&"op_count", ops.size() / SymbolArt.FLOATS_PER_OP)
	material.set_shader_parameter(&"ops", _pack_ops(ops))
	material.set_shader_parameter(&"ink", SymbolArt.plate_ink(tint))
	material.set_shader_parameter(&"line_ink", SymbolArt.INK)
	material.set_shader_parameter(&"cell_px", Vector2(CELL_PX))
	material.set_shader_parameter(&"seed", float(index) * 7.31)
	rect.material = material
	if ops.is_empty() and def != null:
		var label: Label = Label.new()
		label.text = def.glyph
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", 130)
		label.add_theme_color_override(&"font_color", SymbolArt.plate_ink(tint))
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.add_child(label)
	return rect


## The shader takes a fixed-size vec4 array; ops are padded out to it.
static func _pack_ops(ops: PackedFloat32Array) -> PackedVector4Array:
	var packed: PackedVector4Array = PackedVector4Array()
	packed.resize(SymbolArt.MAX_OPS * 3)
	for i: int in mini(ops.size() / 4, packed.size()):
		packed[i] = Vector4(ops[i * 4], ops[i * 4 + 1], ops[i * 4 + 2],
				ops[i * 4 + 3])
	return packed


## The preferred order, filtered to symbols that exist, extended with anything
## the content set has that the list does not know, and cycled to fill the
## drum. More symbols than cells leaves the excess plateless — they fall back
## to glyph labels — because the drum's cell count is geometry, not content.
static func _strip_order() -> Array[StringName]:
	var content: ContentDB = ContentDB.shared()
	var order: Array[StringName] = []
	for id: StringName in PREFERRED:
		if order.size() < CELLS and content.symbol_by_id(id) != null:
			order.append(id)
	for def: SymbolDef in content.symbols:
		if order.size() < CELLS and not order.has(def.id):
			order.append(def.id)
	var unique: int = order.size()
	while order.size() < CELLS and unique > 0:
		order.append(order[order.size() % unique])
	return order
