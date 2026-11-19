extends "res://scenes/fighter.gd"

export(NodePath) var target_path
export(float) var walk_speed = 3.4
export(float) var stopping_distance = 1.6
export(float) var turn_speed_degrees = 150.0
export(float, 0.0, 1.0) var counter_chance = 0.4
export(float, 0.1, 1.0) var counter_reaction = 0.32
export(bool) var counter_on_counter = false
export(float, 0.0, 20.0) var dash_speed = 0.0
export(float, 0.1, 1.0) var dash_duration = 0.2
export(float, 0.1, 3.0) var dash_interval = 0.55

onready var target = get_node_or_null(target_path)
onready var navigator = $Navigator

var chasing = false
var refresh_in = 0.0
var vertical_speed = 0.0
var push_shortcut = false
var detour_time = 0.0
var attack_decision_in = 0.55
var combat_random = RandomNumberGenerator.new()
var dash_time = 0.0
var dash_cooldown = 0.0
var dash_direction = Vector3.ZERO

func _ready():
    combat_random.randomize()

func receive_hit(attacker, amount, allow_block = true):
    var incoming_counter = attacker.attack_kind == 3
    var blocked = .receive_hit(attacker, amount, allow_block)
    if blocked and combat_enabled:
        var can_reply = counter_on_counter or not incoming_counter
        if can_reply and combat_random.randf() < counter_chance:
            attack_decision_in = counter_reaction
        else:
            counter_time = 0.0
            attack_decision_in = max(attack_decision_in, 0.7)
    return blocked

func obstacle_toward_target():
    var eye = Vector3.UP * 1.5
    var hit = get_world().direct_space_state.intersect_ray(
            global_transform.origin + eye, target.global_transform.origin + eye, [self])
    return hit.get("collider")

func _physics_process(delta):
    enemy_tick(delta)

func enemy_tick(delta):
    normal_enemy_tick(delta)

func normal_enemy_tick(delta):
    combat_tick(delta)
    if not combat_enabled:
        return
    dash_time = max(0.0, dash_time - delta)
    dash_cooldown = max(0.0, dash_cooldown - delta)
    if stun_time > 0.0 or hit_time > 0.0:
        dash_time = 0.0
    attack_decision_in = max(0.0, attack_decision_in - delta)
    if not is_instance_valid(target) or not target.combat_enabled:
        animate_walk(0.0, delta)
        animate_combat()
        return
    var goal = target.global_transform.origin
    detour_time = max(0.0, detour_time - delta)
    refresh_in -= delta
    if refresh_in <= 0.0:
        refresh_in = 0.3
        var obstacle = obstacle_toward_target()
        chasing = chasing or obstacle == target
        push_shortcut = obstacle != null and obstacle.has_method("try_push") and strength >= obstacle.required_strength
        if chasing:
            navigator.set_target_location(goal)

    var velocity = Vector3.ZERO
    if chasing and global_transform.origin.distance_to(goal) > stopping_distance:
        var waypoint = navigator.get_next_location()
        if push_shortcut and detour_time <= 0.0:
            waypoint = goal
        var offset = waypoint - global_transform.origin
        offset.y = 0
        velocity = offset.normalized() * min(walk_speed, offset.length() / delta)
    var facing = velocity
    if chasing and facing.length_squared() < 0.001:
        facing = goal - global_transform.origin
    if stun_time <= 0.0 and Vector2(facing.x, facing.z).length_squared() > 0.001:
        var local_facing = get_parent().global_transform.basis.xform_inv(facing)
        var desired_angle = atan2(-local_facing.x, -local_facing.z)
        var angle_left = wrapf(desired_angle - rotation.y, -PI, PI)
        var max_turn = deg2rad(turn_speed_degrees) * delta
        rotation.y += clamp(angle_left, -max_turn, max_turn)
        velocity *= max(0.0, cos(angle_left))
    vertical_speed -= 18.0 * delta
    var distance_to_target = global_transform.origin.distance_to(goal)
    if chasing and distance_to_target > 4.0 and distance_to_target < 12.0:
        request_dash(goal)
    if chasing and dash_time <= 0.0 and attack_decision_in <= 0.0 and global_transform.origin.distance_to(goal) <= attack_reach:
        var toward = (goal - global_transform.origin).normalized()
        if facing_forward().dot(toward) > 0.8 and obstacle_toward_target() == target:
            if start_attack():
                attack_decision_in = 0.35
    velocity *= combat_movement_scale()
    if dash_time > 0.0:
        velocity = dash_direction * dash_speed
    velocity.y = vertical_speed
    var start = global_transform.origin
    vertical_speed = move_and_slide(velocity, Vector3.UP).y
    if not push_contacted_car(velocity, delta):
        detour_time = 2.0
    var travel = global_transform.origin - start
    animate_walk(Vector2(travel.x, travel.z).length(), delta)
    animate_combat()

func request_dash(goal):
    if dash_speed <= 0.0 or dash_time > 0.0 or dash_cooldown > 0.0 or not combat_enabled:
        return false
    if stun_time > 0.0 or hit_time > 0.0 or attack_time >= 0.0 or block_time > 0.0:
        return false
    var toward = goal - global_transform.origin
    toward.y = 0.0
    if toward.length_squared() < 0.01:
        return false
    if facing_forward().dot(toward.normalized()) < 0.9 or obstacle_toward_target() != target:
        return false
    dash_direction = toward.normalized()
    dash_time = dash_duration
    dash_cooldown = dash_interval
    return true

func animate_walk(distance, delta):
    $Pilot.advance_walk(distance, delta)
    $BasicExosuit.advance_walk(distance, delta)
