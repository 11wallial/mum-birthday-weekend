Artifact modules that bolt onto the machine frame. An artifact points at one of
these through `ArtifactDef.module_scene_path`; `SlotView3D` instances it under
`ModuleAnchor` when the artifact is acquired.

`brass_gearbox.tscn` and `entropy_engine.tscn` are primitive-mesh placeholders
that show the wiring end to end. Replace them with GLTF imports; nothing in the
simulation needs to change.
