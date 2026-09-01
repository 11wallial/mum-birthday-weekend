## Renders every reel symbol to one PNG, so the set can be checked at a glance.
##
## Waiting for a symbol to land on a reel is a poor way to look at nine drawings
## — a run might not show a skull for a hundred spins. This draws the whole set
## against the reel strip's own colour, at roughly the size it appears on screen.
##
##   godot --headless --path . --script res://tools/visual_qa/symbol_sheet.gd \
##       -- --out=/tmp/symbols.png
extends SceneTree

## Drawn at the size a symbol occupies on a 1152-wide frame, so the sheet shows
## what a player actually sees rather than a flattering enlargement.
const CELL: int = 96
const PADDING: int = 12


func _initialize() -> void:
	var out_path: String = "user://symbols.png"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.substr(6)

	var symbols: Array[SymbolDef] = ContentDB.shared().symbols
	if symbols.is_empty():
		push_error("symbol_sheet: no symbols in the content set")
		quit(1)
		return

	var columns: int = 5
	var rows: int = int(ceil(float(symbols.size()) / float(columns)))
	var sheet: Image = Image.create_empty(
			columns * (CELL + PADDING) + PADDING,
			rows * (CELL + PADDING) + PADDING, false, Image.FORMAT_RGBA8)
	# The strip's own cream, so a pale symbol is judged against what it will
	# actually sit on rather than against a checkerboard.
	sheet.fill(Materials.ENAMEL)

	var missing: PackedStringArray = PackedStringArray()
	for i: int in symbols.size():
		var symbol: SymbolDef = symbols[i]
		var art: ImageTexture = SymbolArt.texture_for(symbol.id, symbol.color)
		if art == null:
			missing.append(String(symbol.id))
			continue
		var x: int = PADDING + (i % columns) * (CELL + PADDING)
		var y: int = PADDING + (i / columns) * (CELL + PADDING)
		var tile: Image = art.get_image()
		tile.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(x, y))
		print("  %-12s %s" % [symbol.id, symbol.color.to_html(false)])

	if not missing.is_empty():
		# Not a failure: a symbol with no drawing falls back to its glyph text.
		print("no drawing (falls back to glyph text): %s" % ", ".join(missing))
	var err: int = sheet.save_png(out_path)
	if err != OK:
		push_error("symbol_sheet: save failed (%d)" % err)
		quit(1)
		return
	print("sheet → %s" % out_path)
	quit(0)
