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
const ARCHETYPE_DIR: String = "res://resources/archetypes"
const BOSS_DIR: String = "res://resources/bosses"
const CHIT_DIR: String = "res://resources/chits"
const BALANCE_PATH: String = "res://resources/rules/balance_config.tres"

var symbols: Array[SymbolDef] = []
var artifacts: Array[ArtifactDef] = []
var floors: Array[FloorDef] = []
var contracts: Array[ContractDef] = []
var archetypes: Array[ArchetypeDef] = []
var bosses: Array[BossDef] = []
## The chits the draft may put in the pocket.
var chits: Array[ChitDef] = []
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
	archetypes.assign(_load_dir(ARCHETYPE_DIR))
	bosses.assign(_load_dir(BOSS_DIR))
	chits.assign(_load_dir(CHIT_DIR))
	var loaded_floors: Array[FloorDef] = []
	loaded_floors.assign(_load_dir(FLOOR_DIR))
	loaded_floors.sort_custom(func(a: FloorDef, b: FloorDef) -> bool: return a.index < b.index)
	floors = loaded_floors
	if ResourceLoader.exists(BALANCE_PATH):
		balance = load(BALANCE_PATH) as BalanceConfig
	symbols.sort_custom(func(a: SymbolDef, b: SymbolDef) -> bool: return String(a.id) < String(b.id))
	artifacts.sort_custom(func(a: ArtifactDef, b: ArtifactDef) -> bool: return String(a.id) < String(b.id))
	contracts.sort_custom(func(a: ContractDef, b: ContractDef) -> bool: return String(a.id) < String(b.id))
	archetypes.sort_custom(func(a: ArchetypeDef, b: ArchetypeDef) -> bool: return String(a.id) < String(b.id))
	bosses.sort_custom(func(a: BossDef, b: BossDef) -> bool: return String(a.id) < String(b.id))


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


func chit_by_id(id: StringName) -> ChitDef:
	for chit: ChitDef in chits:
		if chit.id == id:
			return chit
	return null


func contract_by_id(id: StringName) -> ContractDef:
	for contract: ContractDef in contracts:
		if contract.id == id:
			return contract
	return null


func archetype_by_id(id: StringName) -> ArchetypeDef:
	for archetype: ArchetypeDef in archetypes:
		if archetype.id == id:
			return archetype
	return null


## Every artifact that belongs to [param archetype_id].
func artifacts_of(archetype_id: StringName) -> Array[ArtifactDef]:
	var out: Array[ArtifactDef] = []
	for artifact: ArtifactDef in artifacts:
		if artifact.archetype == archetype_id:
			out.append(artifact)
	return out


func boss_by_id(id: StringName) -> BossDef:
	for boss: BossDef in bosses:
		if boss.id == id:
			return boss
	return null


## Everyone the House can send to floor [param index], in id order.
func bosses_for(index: int) -> Array[BossDef]:
	var out: Array[BossDef] = []
	for boss: BossDef in bosses:
		if boss.floor == index:
			out.append(boss)
	return out


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
