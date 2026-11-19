extends KinematicBody

signal health_changed(current, maximum)
signal defeated(attacker)
signal attack_started(kind)
signal hit_received(blocked)

export(float, 0, 100) var strength = 1.0
export(float) var attack_damage = 10.0
export(float) var attack_reach = 2.5
export(float, 1, 10000) var max_health = 100.0
export(float, 0.0, 1.0) var block_damage_ratio = 0.25
export(bool) var is_boss = false
export(float, 0.1, 5.0) var stun_duration = 0.9
export(float, 0.5, 3.0) var attack_speed = 1.0
export(float, 0.25, 2.0) var hit_recovery_scale = 1.0

const HIT_TIMES = [0.26, 0.40, 0.48, 0.22]
const ATTACK_DURATIONS = [0.62, 0.80, 0.95, 0.58]
const BLOOD_EFFECT = preload("res://scenes/blood_hit.tscn")
var attack_time = -1.0
var attack_kind = 0
var next_attack = 0
var attack_cooldown = 0.0
var counter_time = 0.0
var hit_time = 0.0
var block_time = 0.0
var pilot_damage = 0.0
var health = 0.0
var combat_enabled = true
var stun_time = 0.0
var finisher_attacker = null
var finishing_contact = false
var finisher_travel = 0.0

func _ready():
    add_to_group("fighters")
    if is_boss:
        add_to_group("bosses")
    health = max_health
    emit_signal("health_changed", health, max_health)

func start_attack():
    if not combat_enabled or health <= 0.0 or stun_time > 0.0 or attack_time >= 0.0 or hit_time > 0.0 or block_time > 0.24:
        return false
    if can_counter():
        attack_kind = 3
    elif attack_cooldown <= 0.0:
        attack_kind = next_attack
        next_attack = (next_attack + 1) % 3
    else:
        return false
    counter_time = 0.0
    block_time = 0.0
    attack_time = 0.0
    emit_signal("attack_started", attack_kind)
    return true

func is_winding_up():
    return attack_time >= 0.0 and attack_time < HIT_TIMES[attack_kind] * 0.65

func can_counter():
    return combat_enabled and health > 0.0 and counter_time > 0.0 and attack_time < 0.0 and hit_time <= 0.0 and stun_time <= 0.0 and block_time <= 0.24

func combat_tick(delta):
    if not combat_enabled:
        return
    hit_time = max(0.0, hit_time - delta)
    stun_time = max(0.0, stun_time - delta)
    block_time = max(0.0, block_time - delta)
    counter_time = max(0.0, counter_time - delta)
    attack_cooldown = max(0.0, attack_cooldown - delta * attack_speed)
    if attack_time < 0.0:
        return
    var previous = attack_time
    attack_time += delta * attack_speed
    if previous < HIT_TIMES[attack_kind] and attack_time >= HIT_TIMES[attack_kind]:
        strike()
    if attack_time >= ATTACK_DURATIONS[attack_kind]:
        attack_time = -1.0
        attack_cooldown = 0.40

func facing_forward():
    return -$Pilot.global_transform.basis.z.normalized()

func strike():
    var origin = global_transform.origin + Vector3.UP * 1.45
    for other in get_tree().get_nodes_in_group("fighters"):
        if other == self or not other.combat_enabled:
            continue
        var offset = other.global_transform.origin - global_transform.origin
        if offset.length() > attack_reach or facing_forward().dot(offset.normalized()) < 0.5:
            continue
        var hit = get_world().direct_space_state.intersect_ray(
                origin, other.global_transform.origin + Vector3.UP * 1.45, [self])
        if hit.get("collider") == other:
            var damage_scale = 1.0
            if attack_kind == 2:
                damage_scale = 1.2
            elif attack_kind == 3:
                damage_scale = 1.4
            other.receive_hit(self, attack_damage * damage_scale)
            return

func receive_hit(attacker, amount, allow_block = true):
    if not combat_enabled or health <= 0.0 or amount <= 0.0:
        return false
    var toward = attacker.global_transform.origin - global_transform.origin
    var interrupted_windup = is_winding_up()
    var blocked = allow_block and attack_time < 0.0 and hit_time <= 0.0 and stun_time <= 0.0 and facing_forward().dot(toward.normalized()) > 0.2
    if blocked:
        amount *= block_damage_ratio
        block_time = 0.34
        counter_time = 0.65
        attacker.attack_time = -1.0
        attacker.counter_time = 0.0
        attacker.hit_time = 0.48 * attacker.hit_recovery_scale
        attacker.attack_cooldown = 0.75
    else:
        if interrupted_windup:
            stun_time = stun_duration
        show_blood(attacker.global_transform.origin)
        hit_time = 0.32 * hit_recovery_scale
        attack_time = -1.0
        counter_time = 0.0
        block_time = 0.0
        attack_cooldown = max(attack_cooldown, 0.45)
    var damage = min(health, amount)
    pilot_damage += damage
    health = max(0.0, health - damage)
    emit_signal("health_changed", health, max_health)
    emit_signal("hit_received", blocked)
    if health <= 0.0:
        disable_combat()
        emit_signal("defeated", attacker)
    return blocked

func disable_combat():
    combat_enabled = false
    attack_time = -1.0
    counter_time = 0.0
    hit_time = 0.0
    block_time = 0.0
    stun_time = 0.0
    set_physics_process(false)
    $Pilot.advance_walk(0.0, 1.0)
    animate_combat()

func show_blood(from_position, height = 1.4):
    var blood = BLOOD_EFFECT.instance()
    blood.transform.origin = global_transform.origin + Vector3.UP * height
    var away = global_transform.origin - from_position
    away.y = 0.0
    blood.get_node("Drops").direction = (away.normalized() + Vector3.UP * 0.6).normalized()
    blood.get_node("Stain").translation.y = -height + 0.02
    get_tree().get_root().add_child(blood)

func face_point(point):
    var offset = global_transform.basis.xform_inv(point - global_transform.origin)
    var angle = atan2(-offset.x, -offset.z)
    $Pilot.rotation.y = angle
    if has_node("BasicExosuit"):
        $BasicExosuit.rotation.y = angle

func play_defeat(attacker):
    finisher_attacker = attacker
    if is_instance_valid(attacker):
        face_point(attacker.global_transform.origin)
        attacker.face_point(global_transform.origin)
    var tween = Tween.new()
    add_child(tween)
    var duration = 1.8 if is_boss else 1.3
    tween.interpolate_method(self, "defeat_sequence", 0.0, 1.0, duration)
    tween.start()
    yield(tween, "tween_all_completed")
    tween.queue_free()

func defeat_sequence(progress):
    if is_instance_valid(finisher_attacker):
        var toward = global_transform.origin - finisher_attacker.global_transform.origin
        toward.y = 0.0
        var desired_travel = 0.75 * smoothstep(0.0, 0.35, progress)
        var step = min(desired_travel - finisher_travel, max(0.0, toward.length() - 1.2))
        finisher_attacker.move_and_collide(toward.normalized() * max(0.0, step))
        finisher_travel = desired_travel
        finisher_attacker.get_node("Pilot").finisher_pose(progress)
        if finisher_attacker.has_node("BasicExosuit"):
            finisher_attacker.get_node("BasicExosuit").finisher_pose(progress)
        if progress >= 0.42 and not finishing_contact:
            finishing_contact = true
            if toward.length() <= 2.7:
                show_blood(finisher_attacker.global_transform.origin, 1.95)
    if is_boss:
        $Pilot.boss_defeat_pose(progress)
        if has_node("BasicExosuit"):
            $BasicExosuit.boss_defeat_pose(progress)
    else:
        $Pilot.fall_pose(progress)
        if has_node("BasicExosuit"):
            $BasicExosuit.fall_pose(progress)

func combat_movement_scale():
    if stun_time > 0.0:
        return 0.0
    if hit_time > 0.0:
        return 0.2
    if attack_time >= 0.0:
        return 0.35
    return 1.0

func animate_combat():
    $Pilot.combat_pose(attack_time, hit_time, block_time, attack_kind,
            HIT_TIMES[attack_kind], ATTACK_DURATIONS[attack_kind])
    if has_node("BasicExosuit"):
        $BasicExosuit.combat_pose(attack_time, hit_time, block_time, attack_kind,
                HIT_TIMES[attack_kind], ATTACK_DURATIONS[attack_kind])
    if stun_time > 0.0:
        $Pilot.stun_pose(stun_time)
        if has_node("BasicExosuit"):
            $BasicExosuit.stun_pose(stun_time)

# Сдвиг возможен только при движении в боковую поверхность машины.
func push_contacted_car(velocity, delta):
    var motion = Vector3(velocity.x, 0, velocity.z)
    for index in range(get_slide_count()):
        var contact = get_slide_collision(index)
        if abs(contact.normal.y) > 0.3 or not contact.collider.has_method("try_push"):
            continue
        var inward_speed = -motion.dot(contact.normal)
        if inward_speed > 0.01:
            var direction = Vector3(-contact.normal.x, 0, -contact.normal.z).normalized()
            return contact.collider.try_push(self, direction, inward_speed, delta)
    return true
