class_name Health extends Node
## Health is used to track an entity's health, death, and revival.

## Affect an action will have on [Health].
enum Affect { NONE, DAMAGE, HEAL }

## Emitted after damage is applied.
signal damaged(entity: Node, type: HealthActionType.Enum, amount: int, incrementer: int, multiplier: float, applied: int)
## Emitted after damage is applied when death has occured.
signal died(entity: Node)

## Emitted after healing is applied.
signal healed(entity: Node, type: HealthActionType.Enum, amount: int, incrementer: int, multiplier: float, applied: int)
## Emitted after healing is applied when dead.
signal revived(entity: Node)

## Emitted after damage or healing is applied.
signal action_applied(action: HealthModifiedAction, applied: int)

## Emitted when damaged and entity had full health.
signal first_hit(entity: Node)
## Emitted when trying to damage an entity that is not damageable.
signal not_damageable(entity: Node)
## Emitted when damaging and current health is already zero.
signal already_dead(entity: Node)
## Emitted when trying to apply enough damage to an enemy to kill them and they cannot be.
signal not_killable(entity: Node)

## Emitted when trying to heal and entity is not healable.
signal not_healable(entity: Node)
## Emitted when enity is healed and health is now full.
signal full(entity: Node)
## Emitted when healing and current health is already full.
signal already_full(entity: Node)
## Emitted when trying to heal a dead entity that is not revivable
signal not_revivable(entity: Node)

const DEFAULT_MAX = 100

## The current amount of health.[br]
## Value is clamped [0, max].
@export var current: int = DEFAULT_MAX:
	set(curr):
		current = clampi(curr, 0, max)

## The maximum amount of health.[br]
## Will not allow values < 1.
## Will reduce current if greater than updated max.[br]
@export var max: int = DEFAULT_MAX:
	set(new_max):
		var old_max = max
		max = maxi(new_max, 1)
		if Engine.is_editor_hint() and current == old_max:
			current = max
		else:
			current = mini(current, max)

@export_group("Conditions")
@export var damageable: bool = true
@export var healable: bool = true
@export var killable: bool = true
@export var revivable: bool = true

@export_group("Advanced")
@export var entity: Node:
	get():
		return entity if entity else owner

@export var modifiers: Dictionary[HealthActionType.Enum, HealthModifier] = {}

func is_dead() -> bool:
	return current == 0 and killable

func is_alive() -> bool:
	return not is_dead()

func is_full() -> bool:
	return current == max

func percent() -> float:
	return clampf(float(current) / float(max), 0.0, 1.0)

func kill(type: HealthActionType.Enum = HealthActionType.Enum.NONE) -> void:
	var mod_ac := HealthModifiedAction.new(HealthAction.new(Affect.DAMAGE, type, current), HealthModifier.new())
	_damage(mod_ac)

func fill(type: HealthActionType.Enum = HealthActionType.Enum.NONE) -> void:
	var mod_ac := HealthModifiedAction.new(HealthAction.new(Affect.HEAL, type, max - current), HealthModifier.new())
	_heal(mod_ac)

func apply_all_actions(actions: Array[HealthAction]) -> void:
	for action in actions:
		apply_action(action)

func apply_action(action: HealthAction) -> void:
	var modified_action := HealthModifiedAction.new(action, HealthModifier.new())
	apply_modified_action(modified_action)

func apply_all_modified_actions(actions: Array[HealthModifiedAction]) -> void:
	for action in actions:
		apply_modified_action(action)

func apply_modified_action(action: HealthModifiedAction) -> void:
	if not action:
		return
	var modifier := _get_modifier(action.type)
	var affect: Affect = modifier.convert_affect if modifier.convert_affect else action.affect
	var type: HealthActionType.Enum = modifier.convert_type if modifier.convert_type else action.type
	var ac := HealthAction.new(affect, type, action.amount)
	var mod := HealthModifier.new(action.incrementer + modifier.incrementer, action.multiplier * modifier.multiplier)
	var mod_ac := HealthModifiedAction.new(ac, mod)

	match affect:
		Affect.DAMAGE:
			_damage(mod_ac)
		Affect.HEAL:
			_heal(mod_ac)

func damage(amount: int, incrementer: int = 0, multiplier: float = 1.0, type: HealthActionType.Enum = HealthActionType.Enum.NONE) -> void:
	var action := HealthAction.new(Affect.DAMAGE, type, amount)
	var modifier := HealthModifier.new(incrementer, multiplier)
	var modified_action := HealthModifiedAction.new(action, modifier)
	apply_modified_action(modified_action)

func heal(amount: int, incrementer: int = 0, multiplier: float = 1.0, type: HealthActionType.Enum = HealthActionType.Enum.NONE) -> void:
	var action := HealthAction.new(Affect.HEAL, type, amount)
	var modifier := HealthModifier.new(incrementer, multiplier)
	var modified_action := HealthModifiedAction.new(action, modifier)
	apply_modified_action(modified_action)

func _damage(mod_ac: HealthModifiedAction) -> void:
	if not damageable:
		not_damageable.emit(entity)
		return
	
	if is_dead():
		already_dead.emit(entity)
		return
	
	var applied := clampi(roundi((mod_ac.amount + mod_ac.incrementer) * mod_ac.multiplier), 0, current)
	if applied == current and not killable:
		not_killable.emit(entity)
		return

	var is_first_hit := is_full() and applied > 0
	current -= applied
	
	print(entity.name, " took damage! Current Health: ", current, "/", max)

	damaged.emit(entity, mod_ac.type, mod_ac.amount, mod_ac.incrementer, mod_ac.multiplier, applied)
	action_applied.emit(mod_ac, applied)
	
	if is_first_hit:
		first_hit.emit(entity)
	
	if is_dead():
		died.emit(entity)

func _heal(mod_ac: HealthModifiedAction) -> void:
	if not healable:
		not_healable.emit(entity)
		return
	
	if is_full():
		already_full.emit(entity)
		return
	
	if is_dead() and not revivable:
		not_revivable.emit(entity)
		return
	
	var notify_revived := is_dead() and mod_ac.amount > 0
	var applied := clampi(roundi((mod_ac.amount + mod_ac.incrementer) * mod_ac.multiplier), 0, max - current)
	current += applied
	
	print(entity.name, " was healed! Current Health: ", current, "/", max)

	healed.emit(entity, mod_ac.type, mod_ac.amount, mod_ac.incrementer, mod_ac.multiplier, applied)
	action_applied.emit(mod_ac, applied)
	
	if current == max and applied > 0:
		full.emit(entity)
	
	if notify_revived:
		revived.emit(entity)

func _get_modifier(type: HealthActionType.Enum) -> HealthModifier:
	return modifiers.get(type, HealthModifier.new())
