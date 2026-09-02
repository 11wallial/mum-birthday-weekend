## A build the player can discover and chase, named.
##
## An archetype is not a rule: nothing in the simulation reads one. It is the
## label a set of artifacts share so the lab can measure the build's win rate
## as a thing in itself, the automated player can lean towards finishing what
## it started, and the interface can tell the player what they are making. A
## build needs enablers on the early floors, amplifiers in the middle and a
## capstone late — the content suite holds every archetype to that — and the
## counter-pressure is written here so nobody forgets to give it one.
class_name ArchetypeDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## What the build does, in the House's voice.
@export_multiline var brief: String = ""
## What pushes back against it. A build with no counter is a shopping list.
@export_multiline var counter: String = ""
