class_name GameEvents
extends Node
## Game signal bus (autoload `EventBus`): signals only, no state.
##
## The list and the parameters are the contract of docs/05_INTERFACES.md §3. Systems emit on `session.events`,
## which in the game is this autoload and in the tests a private `GameEvents.new()`.
## M6/M7 signals (`hint_triggered`, `fracture_opened`, `fracture_closed`) are added by their tasks.

# Session
signal session_started(slot: int, is_new: bool)
signal session_ended(slot: int)

# Actions
signal action_started(lane: StringName, skill_id: StringName, action_id: StringName)
signal action_completed(lane: StringName, skill_id: StringName, action_id: StringName, outputs: Dictionary)
signal action_stopped(lane: StringName, skill_id: StringName, reason: StringName)

# Skills and mastery
signal xp_gained(skill_id: StringName, amount: int)
signal level_up(skill_id: StringName, new_level: int)
signal mastery_xp_gained(skill_id: StringName, action_id: StringName, amount: int)
signal mastery_level_up(skill_id: StringName, action_id: StringName, new_level: int)
signal mastery_pool_changed(skill_id: StringName, pool_xp: int)
signal mastery_node_purchased(skill_id: StringName, node_id: StringName)

# Character
signal character_xp_gained(amount: int)
signal character_level_up(new_level: int)

# Bank, wallet, equipment, modifiers
signal bank_changed(item_id: StringName, new_count: int, delta: int)
signal bank_capacity_changed(used: int, capacity: int)
signal bank_rejected(item_id: StringName, qty: int)
signal gold_changed(new_amount: int, delta: int)
signal equipment_changed(slot_id: StringName, uid: int)
signal food_changed(item_id: StringName)
signal armory_changed(uid: int, change: StringName)
signal armory_capacity_changed(used: int, capacity: int)
signal armory_rejected(base_id: StringName, qty: int)
signal modifiers_changed()

# Combat
signal combat_started(area_id: StringName)
signal combat_stopped(reason: StringName)
signal encounter_started(monster_ids: Array[StringName])
signal encounter_cleared()
signal combat_hit(attacker: int, target: int, hit: bool, damage: int, blocked: bool)
signal player_hp_changed(hp: int, max_hp: int)
signal monster_hp_changed(index: int, hp: int, max_hp: int)
signal monster_killed(index: int, monster_id: StringName)
signal player_died()
signal food_eaten(item_id: StringName, healed: int)
signal loot_bag_changed(used: int, capacity: int)
signal loot_lost(item_id: StringName, qty: int)

# Shop and Rift Altar
signal shop_purchased(entry_id: StringName, count: int)
signal item_sold(item_id: StringName, qty: int, gold: int)
signal infusion_socketed(socket_index: int, item_id: StringName)
signal infusion_removed(socket_index: int, item_id: StringName)

# Offline
signal offline_started(elapsed_ms: int, capped: bool)
signal offline_progress(done_ms: int, total_ms: int)
# Contract type is OfflineSummary (core/offline/offline_summary.gd, task M6-01). That class does not exist yet,
# so the parameter is typed with its base class RefCounted until it does.
signal offline_completed(summary: RefCounted)

# Save and notifications
signal save_completed(slot: int)
signal save_failed(slot: int, reason: StringName)
signal notification_requested(text: String, kind: StringName)
