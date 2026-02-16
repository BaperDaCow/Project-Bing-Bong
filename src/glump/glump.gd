extends CharacterBody2D

@export var hop_force: float = -300.0  
@export var speed: float = 150.0       
@export var gravity: float = 900.0

var player: Node2D = null
@onready var health_node: Health = $Health
@onready var visual: ColorRect = $ColorRect
@onready var timer: Timer = $HopTimer

func _ready() -> void:
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	
	if health_node:
		if not health_node.died.is_connected(_on_died):
			health_node.died.connect(_on_died)
	
	if timer:
		if timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.disconnect(_on_timer_timeout)
		timer.timeout.connect(_on_timer_timeout)
		timer.wait_time = randf_range(1.0, 2.0)
		timer.start()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.x = move_toward(velocity.x, 0, 15)
		visual.scale.y = move_toward(visual.scale.y, 1.0, 0.08)
		visual.scale.x = move_toward(visual.scale.x, 1.0, 0.08)

	move_and_slide()

func _on_timer_timeout() -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")

	if is_on_floor() and player and health_node.is_alive():
		visual.scale.y = 0.5
		visual.scale.x = 1.3
		
		await get_tree().create_timer(0.1).timeout
		
		var dir = sign(player.global_position.x - global_position.x)
		velocity.y = hop_force
		velocity.x = dir * speed
		
		timer.wait_time = randf_range(0.8, 1.5)

func _on_died(_entity: Node) -> void:
	set_physics_process(false)
	timer.stop()
	if has_node("HitBox2D/CollisionShape2D"):
		$HitBox2D/CollisionShape2D.set_deferred("disabled", true)
	
	visual.scale.y = 0.1
	visual.color = Color.DARK_SLATE_GRAY
	await get_tree().create_timer(0.3).timeout
	queue_free()
