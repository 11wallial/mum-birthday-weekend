## Loads the immutable content set (symbols, artifacts, floors, balance config).
##
## Loaded once per process and shared by every run in a batch — the simulation
## treats these resources as read-only, and per-run changes live on [RunState].
class_name ContentDB
extends RefCounted

const SYMBOL_DIR: String = "res://resources/symbols"
const ARTIFACT_DIR: String = "res://resources/artifacts"
const FLOOR_DIR: String = "res://resources/rules/floors"
const CONTRACT_DIR: String = "res://resources/contracts"
const BALANCE_PATH: String = "res://resources/rules/balance_config.tres"

var symbols: Array[SymbolDef] = []
var artifacts: Array[ArtifactDef] = []
var floors: Array[FloorDef] = []
var contracts: Array[ContractDef] = []
var balance: BalanceConfig = BalanceConfig.new()

static var _shared: ContentDB = null


## The process-wide content set, loaded on first use.
static func shared() -> ContentDB:
	if _shared == null:
		_shared = ContentDB.new()
		_shared.load_all()
	return _shared


func load_all() -> void:
	symbols.assign(_load_dir(SYMBOL_DIR))
	artifacts.assign(_load_dir(ARTIFACT_DIR))
	contracts.assign(_load_dir(CONTRACT_DIR))
	var loaded_floors: Array[FloorDef] = []
	loaded_floors.assign(_load_dir(FLOOR_DIR))
	loaded_floors.sort_custom(func(a: FloorDef, b: FloorDef) -> bool: return a.index < b.index)
	floors = loaded_floors
	if ResourceLoader.exists(BALANCE_PATH):
		balance = load(BALANCE_PATH) as BalanceConfig
	symbols.sort_custom(func(a: SymbolDef, b: SymbolDef) -> bool: return String(a.id) < String(b.id))
	artifacts.sort_custom(func(a: ArtifactDef, b: ArtifactDef) -> bool: return String(a.id) < String(b.id))
	contracts.sort_custom(func(a: ContractDef, b: ContractDef) -> bool: return String(a.id) < String(b.id))


func symbol_by_id(id: StringName) -> SymbolDef:
	for symbol: SymbolDef in symbols:
		if symbol.id == id:
			return symbol
	return null


func artifact_by_id(id: StringName) -> ArtifactDef:
	for artifact: ArtifactDef in artifacts:
		if artifact.id == id:
			return artifact
	return null


func contract_by_id(id: StringName) -> ContractDef:
	for contract: ContractDef in contracts:
		if contract.id == id:
			return contract
	return null


func floor_at(index: int) -> FloorDef:
	for floor_def: FloorDef in floors:
		if floor_def.index == index:
			return floor_def
	return null


## Every resource in [param dir], sorted by filename for load-order determinism.
func _load_dir(dir_path: String) -> Array:
	var out: Array = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_warning("ContentDB: missing content directory %s" % dir_path)
		return out
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		# Exported projects rewrite .tres to .res; strip either remap suffix.
		var clean: String = file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres") and not clean.ends_with(".res"):
			continue
		var resource: Resource = load(dir_path + "/" + clean)
		if resource != null:
			out.append(resource)
	return out
