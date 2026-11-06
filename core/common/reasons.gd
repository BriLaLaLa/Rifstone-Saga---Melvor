class_name Reasons
extends RefCounted
## Closed list of failure and stop reasons used by CommandResult and by the EventBus signals.
##
## Only constants live here; a new reason is added through docs/05_INTERFACES.md first.

const NO_SESSION := &"no_session"
const SLOT_NOT_SELECTED := &"slot_not_selected"
const UNKNOWN_ID := &"unknown_id"
const INVALID_AMOUNT := &"invalid_amount"
const LEVEL_TOO_LOW := &"level_too_low"
const REQUIREMENT_NOT_MET := &"requirement_not_met"
const MISSING_INPUTS := &"missing_inputs"
const BANK_FULL := &"bank_full"
const NOT_ENOUGH_ITEMS := &"not_enough_items"
const NOT_ENOUGH_GOLD := &"not_enough_gold"
const MAX_PURCHASES := &"max_purchases"
const ITEM_LOCKED := &"item_locked"
const NOT_SELLABLE := &"not_sellable"
const NOT_EQUIPPABLE := &"not_equippable"
const NOT_FOOD := &"not_food"
const SLOT_EMPTY := &"slot_empty"
const COMBAT_ACTIVE := &"combat_active"
const SLOT_LOCKED := &"slot_locked"  # M6: trait/ability slot not open yet (docs/05_INTERFACES.md §2)
const LANE_UNAVAILABLE := &"lane_unavailable"
const SKILL_IN_OTHER_LANE := &"skill_in_other_lane"
const SOCKET_LOCKED := &"socket_locked"
const SOCKET_OCCUPIED := &"socket_occupied"
const POOL_INSUFFICIENT := &"pool_insufficient"
const NODE_PREREQ_MISSING := &"node_prereq_missing"
const NODE_OWNED := &"node_owned"
const MASTERY_MAX := &"mastery_max"
const NO_FOOD := &"no_food"
const PLAYER_DIED := &"player_died"
const STOPPED_BY_USER := &"stopped_by_user"
const REPLACED := &"replaced" # stopped because another activity started
const IO_ERROR := &"io_error"
const CORRUPTED := &"corrupted"
const VERSION_UNSUPPORTED := &"version_unsupported"
const SLOT_ACTIVE := &"slot_active"
const INVALID_NAME := &"invalid_name"
const NOT_RUNNING := &"not_running"
const ARMORY_FULL := &"armory_full"  # M4: the Armory has no free slot (docs/01_GDD.md §21)
const NOT_STACKABLE := &"not_stackable"  # M4: equipment and tools are rejected by the bank
const ITEM_EQUIPPED := &"item_equipped"  # M4: a worn piece cannot be sold or salvaged
