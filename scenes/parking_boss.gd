extends "res://scenes/enemy.gd"

enum CombatPhase { WEAKENED, ACTIVE }
var combat_phase = CombatPhase.WEAKENED
var active_settings = {}
var pickup_wait = 0.0

func _ready():
    for property in ["walk_speed", "attack_damage", "attack_speed", "counter_chance"]:
        active_settings[property] = get(property)
    walk_speed = 1.4
    attack_damage = 4.0
    attack_speed = 0.55
    counter_chance = 0.0

func activate_combat():
    for property in active_settings:
        set(property, active_settings[property])
    combat_phase = CombatPhase.ACTIVE
    throws_enabled = true

var full_hits = 0
var throws_enabled = false
var selected_car = null
var lift_time = 0.0
var throw_cooldown = 0.0
var kick_car = null
var kick_time = 0.0
var kick_contact = false
var pickup_car = null
var pickup_origin = Transform.IDENTITY
var throw_recovery = -1.0
var pickup_relative_basis = Basis.IDENTITY
var kick_approach_time = 0.0
var kick_cooldown = 0.0

func receive_hit(attacker, amount, allow_block = true):
    var before = health
    var blocked = .receive_hit(attacker, amount, allow_block and throws_enabled)
    if allow_block and attacker == target and not blocked and health < before:
        full_hits += 1
        var was_enabled = throws_enabled
        if full_hits >= 3:
            activate_combat()
        if throws_enabled and not was_enabled and target.has_node("HUD"):
            target.get_node("HUD").call_deferred("refresh_boss_lesson")
    return blocked

func enemy_tick(delta):
    throw_cooldown = max(0.0, throw_cooldown - delta)
    kick_cooldown = max(0.0, kick_cooldown - delta)
    if not combat_enabled or not is_instance_valid(target) or not target.combat_enabled:
        drop_car()
        return
    if not throws_enabled:
        normal_enemy_tick(delta)
        return
    if combat_phase == CombatPhase.WEAKENED:
        activate_combat()
    if throw_recovery >= 0.0:
        combat_tick(delta)
        if stun_time > 0.0 or hit_time > 0.0:
            throw_recovery = -1.0
            animate_walk(0.0, delta)
            animate_combat()
            return
        throw_recovery += delta
        animate_walk(0.0, delta)
        animate_combat()
        apply_car_pose("car_recover_pose", min(throw_recovery / 0.35, 1.0))
        if throw_recovery >= 0.35:
            throw_recovery = -1.0
        return
    if is_instance_valid(kick_car):
        combat_tick(delta)
        if stun_time > 0 or hit_time > 0 or (not kick_contact and not kick_car.available()):
            kick_car = null
            throw_cooldown = 3.0
            kick_cooldown = 3.0
            animate_walk(0.0, delta)
            animate_combat()
            return
        if not kick_contact and car_contact_gap(kick_car) > 1.3:
            kick_approach_time += delta
            face_throw_direction(kick_car.global_transform.origin)
            var toward_car = kick_car.global_transform.origin - global_transform.origin
            toward_car.y = 0
            var previous = global_transform.origin
            move_and_slide(toward_car.normalized() * walk_speed + Vector3.DOWN, Vector3.UP)
            animate_walk(global_transform.origin.distance_to(previous), delta)
            animate_combat()
            if kick_approach_time > 2.0:
                kick_car = null
                throw_cooldown = 3.0
                kick_cooldown = 3.0
            return
        kick_time += delta
        animate_walk(0.0, delta)
        animate_combat()
        $Pilot.kick_pose(kick_time / 0.8)
        $BasicExosuit.kick_pose(kick_time / 0.8)
        if kick_time >= 0.4 and not kick_contact:
            kick_contact = true
            var direction = target.global_transform.origin - kick_car.global_transform.origin
            var outward = kick_car.global_transform.origin - global_transform.origin
            direction.y = 0
            outward.y = 0
            if direction.normalized().dot(outward.normalized()) < 0.25:
                direction = outward
            kick_car.kick(self, direction)
        if kick_time >= 0.8:
            kick_car = null
            throw_cooldown = 5.0
            kick_cooldown = 3.0
        return
    if is_instance_valid(selected_car) and selected_car.holder == self:
        combat_tick(delta)
        if stun_time > 0 or hit_time > 0:
            drop_car()
            animate_walk(0.0, delta)
            animate_combat()
            return
        if pickup_car != selected_car:
            pickup_car = selected_car
            pickup_origin = selected_car.global_transform
            pickup_relative_basis = global_transform.basis.inverse() * selected_car.global_transform.basis
        var distance_to_player = global_transform.origin.distance_to(target.global_transform.origin)
        lift_time += delta
        var aimed = true
        if lift_time >= 0.95:
            aimed = turn_with_car(target.global_transform.origin, delta)
        if lift_time > 1.45 and not aimed:
            lift_time = 1.45
        var rise = smoothstep(0.25, 0.8, lift_time)
        var extension = smoothstep(1.45, 1.8, lift_time)
        selected_car.global_transform.basis = global_transform.basis * pickup_relative_basis
        animate_walk(0.0, delta)
        animate_combat()
        if lift_time < 0.25:
            apply_car_pose("car_grasp_pose", lift_time / 0.25)
        elif lift_time < 1.45:
            apply_car_pose("lift_pose", clamp((lift_time - 0.25) / 0.7, 0.0, 1.0))
        else:
            apply_car_pose("car_throw_pose", extension)
        var hand_anchor = $BasicExosuit.car_hand_anchor() - Vector3.UP * 0.12
        var carry_position = pickup_origin.origin.linear_interpolate(hand_anchor, smoothstep(0.85, 1.15, lift_time))
        carry_position.y = lerp(pickup_origin.origin.y, hand_anchor.y, rise)
        selected_car.global_transform.origin = carry_position
        if lift_time >= 1.8:
            var goal = target.global_transform.origin
            if distance_to_player < 4.5:
                var beyond = goal - global_transform.origin
                beyond.y = 0
                if beyond.length_squared() < 0.01:
                    beyond = facing_forward()
                goal = global_transform.origin + beyond.normalized() * 8.0
            selected_car.launch(goal)
            selected_car = null
            pickup_car = null
            throw_recovery = 0.0
            throw_cooldown = 8.0
        return
    if kick_cooldown <= 0 and stun_time <= 0 and hit_time <= 0 and attack_time < 0:
        for car in get_tree().get_nodes_in_group("throwable_cars"):
            if car.available() and strength >= car.required_strength and opposite_sides(car):
                start_car_kick(car)
                return
    if throws_enabled and throw_cooldown <= 0 and stun_time <= 0 and hit_time <= 0 and attack_time < 0:
        if not is_instance_valid(selected_car):
            var nearest = 100000.0
            for car in get_tree().get_nodes_in_group("throwable_cars"):
                var distance = global_transform.origin.distance_to(car.global_transform.origin)
                if car.available() and strength >= car.required_strength and distance < nearest:
                    nearest = distance
                    selected_car = car
        if is_instance_valid(selected_car):
            combat_tick(delta)
            dash_time = 0.0
            var offset = selected_car.global_transform.origin - global_transform.origin
            offset.y = 0
            face_throw_direction(selected_car.global_transform.origin)
            if car_contact_gap(selected_car) <= 1.15:
                pickup_wait += delta
                move_and_slide(Vector3.DOWN, Vector3.UP)
                animate_walk(0.0, delta)
                animate_combat()
                if pickup_wait < 0.25:
                    return
                if selected_car.pick_up(self):
                    lift_time = 0.0

                    pickup_car = selected_car
                    pickup_origin = selected_car.global_transform
                    pickup_relative_basis = global_transform.basis.inverse() * selected_car.global_transform.basis
                    animate_walk(0.0, delta)
                    apply_car_pose("car_grasp_pose", 0.0)
                    pickup_wait = 0.0
                else:
                    selected_car = null
                return
            pickup_wait = 0.0
            refresh_in -= delta
            if refresh_in <= 0.0:
                refresh_in = 0.3
                navigator.set_target_location(selected_car.global_transform.origin)
            var direction = navigator.get_next_location() - global_transform.origin
            direction.y = 0
            var start = global_transform.origin
            move_and_slide(direction.normalized() * walk_speed + Vector3.DOWN, Vector3.UP)
            animate_walk(global_transform.origin.distance_to(start), delta)
            animate_combat()
            return
    normal_enemy_tick(delta)

func start_attack():
    if is_instance_valid(selected_car) or is_instance_valid(kick_car) or throw_recovery >= 0.0:
        return false
    return .start_attack()

func drop_car():
    if is_instance_valid(selected_car) and selected_car.holder == self:
        selected_car.release_drop()
        throw_cooldown = 5.0
    selected_car = null
    kick_car = null

    pickup_car = null
    throw_recovery = -1.0
    pickup_wait = 0.0

func opposite_sides(car):
    var to_car = car.global_transform.origin - global_transform.origin
    var to_player = target.global_transform.origin - car.global_transform.origin
    to_car.y = 0
    to_player.y = 0
    if to_car.length() > 3.8 or to_car.length() < 1.0 or to_player.length() > 10.0:
        return false
    if to_car.normalized().dot(to_player.normalized()) < 0.8:
        return false
    var hit = get_world().direct_space_state.intersect_ray(global_transform.origin + Vector3.UP, target.global_transform.origin + Vector3.UP, [self])
    return hit.get("collider") == car

func start_car_kick(car):
    selected_car = null
    pickup_car = null
    pickup_wait = 0.0
    kick_car = car
    kick_time = 0.0
    kick_contact = false
    kick_approach_time = 0.0
    face_throw_direction(car.global_transform.origin)

func car_contact_gap(car):
    var toward = car.global_transform.origin - global_transform.origin
    toward.y = 0
    var local_direction = car.global_transform.basis.xform_inv(toward.normalized())
    var edge = min(1.067 / max(abs(local_direction.x), 0.001), 2.622 / max(abs(local_direction.z), 0.001))
    return toward.length() - edge

func apply_car_pose(method, progress):
    $Pilot.call(method, progress)
    $BasicExosuit.call(method, progress)

func turn_with_car(point, delta):
    var offset = get_parent().global_transform.basis.xform_inv(point - global_transform.origin)
    var desired = atan2(-offset.x, -offset.z)
    rotation.y += clamp(wrapf(desired - rotation.y, -PI, PI), -deg2rad(turn_speed_degrees) * delta, deg2rad(turn_speed_degrees) * delta)
    return abs(wrapf(desired - rotation.y, -PI, PI)) < 0.08

func face_throw_direction(point):
    var offset = get_parent().global_transform.basis.xform_inv(point - global_transform.origin)
    rotation.y = atan2(-offset.x, -offset.z)
    $Pilot.rotation.y = 0.0
    $BasicExosuit.rotation.y = 0.0

func disable_combat():
    drop_car()
    .disable_combat()


