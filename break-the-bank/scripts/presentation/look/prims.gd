## The handful of shapes everything in the set is built from.
##
## [MachineFrame], [RoomSet] and [ModuleFactory] all assemble their geometry
## from boxes, cylinders and struts. Each grew its own private copy of these
## first; the third copy is where that stops being reasonable, so they live here.
##
## Nothing in here knows what it is building. It is deliberately dumb: give it a
## size, a place and a material, and it hands back a node.
class_name Prims
extends RefCounted


static func group(parent: Node3D, node_name: StringName) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = node_name
	parent.add_child(node)
	return node


static func box(parent: Node3D, size: Vector3, at: Vector3,
		material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _instance(parent, mesh, at, material)


static func cylinder(parent: Node3D, radius: float, height: float, at: Vector3,
		euler: Vector3, material: Material, segments: int = 16) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 0
	var instance: MeshInstance3D = _instance(parent, mesh, at, material)
	instance.rotation = euler
	return instance


static func cone(parent: Node3D, top: float, bottom: float, height: float,
		at: Vector3, euler: Vector3, material: Material) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 0
	var instance: MeshInstance3D = _instance(parent, mesh, at, material)
	instance.rotation = euler
	return instance


static func sphere(parent: Node3D, radius: float, at: Vector3,
		material: Material) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _instance(parent, mesh, at, material)


static func quad(parent: Node3D, size: Vector2, at: Vector3,
		material: Material) -> MeshInstance3D:
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = size
	return _instance(parent, mesh, at, material)


## A cylinder spanning two points — the workhorse for pipes, hoses and struts,
## since placing those by centre-and-euler by hand is where mistakes live.
static func segment(parent: Node3D, from: Vector3, to: Vector3, radius: float,
		material: Material) -> MeshInstance3D:
	var delta: Vector3 = to - from
	var length: float = delta.length()
	if length < 0.0001:
		return null
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	mesh.rings = 0
	var instance: MeshInstance3D = _instance(parent, mesh, (from + to) * 0.5, material)
	# A cylinder points along +Y; aim that at the segment, picking a reference
	# axis that is never parallel to it so the basis stays well-conditioned.
	var up: Vector3 = delta / length
	var reference: Vector3 = (Vector3.RIGHT if absf(up.dot(Vector3.UP)) > 0.99
			else Vector3.UP)
	var right: Vector3 = reference.cross(up).normalized()
	instance.transform.basis = Basis(right, up, right.cross(up).normalized())
	return instance


## A ring of [param count] shapes about the Z axis, as gear teeth or dial marks
## are. Returns the angles used, so a caller can decorate the same positions.
static func ring(parent: Node3D, count: int, radius: float, size: Vector3,
		depth: float, material: Material) -> PackedFloat32Array:
	var angles: PackedFloat32Array = PackedFloat32Array()
	for i: int in count:
		var angle: float = TAU * float(i) / float(count)
		var tooth: MeshInstance3D = box(parent, size,
				Vector3(cos(angle) * radius, sin(angle) * radius, depth), material)
		tooth.rotation.z = angle
		angles.append(angle)
	return angles


static func _instance(parent: Node3D, mesh: Mesh, at: Vector3,
		material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	instance.position = at
	return instance
