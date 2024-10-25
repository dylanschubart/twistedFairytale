extends CharacterBody3D

enum {
	IDLE,
	WALKING,
	TALKING,
	STANDING,
	CHASE,
}

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var state = IDLE

var target_vector: Vector3
var last_target_vector: Vector3 
var radiusx1 = -360
var radiusx2 = -280
var radiusz1 = -570
var radiusz2 = -415
var TOLERANCE = 4.0

var interacted = false
var dialogue_ended = false
var randomTime
var cutscene = false
var cutscene2 = false
var repos = false

@export var SPEED = 3
@export var CHASE_SPEED = 18

@onready var animPlayer = get_child(0).get_node("AnimationPlayer")
@onready var nav_agent = $NavigationAgent3D
@onready var idle_Walking_timer = $Idle_Walking

func _ready():
	nav_agent.velocity_computed.connect(_on_nav_velocity_computed)
	$StaticBodyInteraction.connect("Interacted", interaction)
#	DialogueManager.connect("dialogue_started", interaction)
	DialogueManager.connect("dialogue_ended", interaction_ended)
	update_target_position()
	idle_Walking_timer.start(randomTime)
	
	$"../../../Triggers".connect("WeirdGuySceneStart", CutsceneStart)
	$"../../../Triggers".connect("WeirdGuySceneEnd", CutsceneEnd)
	$"../../../Triggers".connect("WeirdGuyScene2Start", Cutscene2Start)
	$"../../../Triggers".connect("WeirdGuyScene2End", Cutscene2End)
	
func CutsceneStart():
	cutscene = true
func CutsceneEnd():
	cutscene = false
	state = WALKING

func Cutscene2Start():
	cutscene2 = true
func Cutscene2End():
	cutscene2 = false

func _process(delta):
	velocity = Vector3.ZERO
	setGravity(delta)
	if cutscene or ObjectiveManager.day_part_count == 3:
		state = STANDING
	
	if cutscene and ObjectiveManager.day_part_count == 7:
		state = CHASE
	
	if cutscene2 and ObjectiveManager.day_part_count == 7:
		state = STANDING
		
	match state:
		IDLE:
			animPlayer.play("Idle")	
			await idle_Walking_timer.timeout
			state = WALKING

		WALKING:
			animPlayer.play("DrunkWalk")
			random_roaming()
			if nav_agent.is_navigation_finished():
				idle_Walking_timer.start(randomTime)
				update_target_position()
				state = IDLE

		TALKING:
			var player = get_tree().root.get_node("/root/ViewportShaders/PSXLayer/BlurPostProcess/SubViewport/LCDOverlay/SubViewport/DitherBanding/SubViewport/World/Player")
			look_at(player.global_transform.origin, Vector3.UP)
			animPlayer.play("Idle")
			if !interacted:
				update_target_position()
				idle_Walking_timer.start(randomTime)
				state = IDLE
		STANDING:
			animPlayer.play("Idle")
			if !repos:
				repos = true
				get_tree().root.get_node("/root/ViewportShaders/PSXLayer/BlurPostProcess/SubViewport/LCDOverlay/SubViewport/DitherBanding/SubViewport/World/CutscenePlayer").play("WeirdGuyRepos1")
		CHASE:
			SoundManager.playSound("Forest_Footsteps")
			SoundManager.playVoice("WeirdGuyLaughing")
			animPlayer.play("Walking")
			chase()
			
func setGravity(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

func _on_nav_velocity_computed(safe_velocity: Vector3) -> void:
	if !interacted and state == WALKING:
		velocity = safe_velocity
		move_and_slide()
	if global_transform.origin != nav_agent.get_next_path_position():
		look_at(nav_agent.get_next_path_position())
	
func update_target_position():
	randomTime = randi_range(0, 20)
	if target_vector == last_target_vector:
		target_vector = Vector3(randi_range(radiusx1, radiusx2),  0, randi_range(radiusz1, radiusz2))

func random_roaming():
	last_target_vector = target_vector 
	nav_agent.set_target_position(target_vector)
	var direction = (nav_agent.get_next_path_position() - global_transform.origin).normalized()
	
	var intended_velocity = direction * SPEED
	nav_agent.set_velocity(intended_velocity)
	
func chase():
	var player = get_tree().root.get_node("/root/ViewportShaders/PSXLayer/BlurPostProcess/SubViewport/LCDOverlay/SubViewport/DitherBanding/SubViewport/World/Player")
	nav_agent.set_target_position(player.global_transform.origin)
	var next_nav_point = nav_agent.get_next_path_position()
	velocity = (next_nav_point - global_transform.origin).normalized() * CHASE_SPEED
	look_at(global_transform.origin + velocity)
	move_and_slide()

func is_at_target_position(): 
	# Stop moving when at target +/- tolerance
	return (target_vector - global_position).length() < TOLERANCE

func interaction():
	interacted = true
	state = TALKING

func interaction_ended():
	interacted = false
