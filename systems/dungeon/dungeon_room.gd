class_name DungeonRoom
extends RefCounted
## A room of the hidden map of a dungeon (docs/05_INTERFACES.md §5.29, F-137): plain data, produced by DungeonGenerator.

const KIND_ENTRANCE: StringName = &"entrance"
const KIND_BOSS: StringName = &"boss"

var layer: int = 0
var index: int = 0
## Position across the level, 0..1: `(k + 0.5) / width` of the level as first drawn. A room that survives the removal of
## the rooms without entrance (F-137 point 2) keeps its `x` while its `index` is renumbered.
var x: float = 0.5
## `&"entrance"`, `&"pack"`, `&"horde"`, `&"elite"`, `&"miniboss"`, `&"trap"`, `&"rest"` or `&"boss"`.
var kind: StringName = &""
var trap_kind: StringName = &""  # a trap only (`rooms.trap.kinds`)
var hint: bool = false  # a hint exists (F-137 point 4); its phrase is the one of the type (F-138)
var exits: Array[int] = []  # indices in the next level, from left to right (2-4; [0] for the last fork level; [] for the boss)
