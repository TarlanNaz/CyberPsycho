tool
extends KinematicBody

export(Color) var paint_color = Color("#397e8c") setget set_paint_color
export(float, 0, 100) var required_strength = 3.0
export(float) var push_speed = 1.2

# Учитываем допуск столкновений Bullet у края кузова.
const PUSH_CLEARANCE = 0.06

func try_push(fighter, direction, inward_speed, delta):
    if not available() or fighter.strength < required_strength:
        return false
    var step = direction * min(push_speed, inward_speed) * delta
    add_collision_exception_with(fighter)
    var blocked = test_move(global_transform, step + direction * PUSH_CLEARANCE)
    if not blocked:
        global_translate(step)
    remove_collision_exception_with(fighter)
    return not blocked

func set_paint_color(value):
    paint_color = value
    if is_inside_tree():
        apply_paint()

func _ready():
    apply_paint()
    if not Engine.editor_hint:
        add_to_group("throwable_cars")

func apply_paint():
    var paint = SpatialMaterial.new()
    paint.albedo_color = paint_color
    $Body.material_override = paint
    $Roof.material_override = paint

var holder = null
var thrower = null
var flying = false
var flight_velocity = Vector3.ZERO
var saved_layer = 1
var saved_mask = 1
var hit_fighters = []
var sliding = false
var ground_velocity = Vector3.ZERO
var moving_shadow = null
var shadow_active = false
var pending_ground_velocity = Vector3.ZERO
var ground_wait = 0.0

func available():
    return holder == null and not flying and not sliding

func pick_up(fighter):
    if not available() or fighter.strength < required_strength:
        return false
    holder = fighter
    thrower = fighter
    saved_layer = collision_layer
    saved_mask = collision_mask
    collision_layer = 0
    collision_mask = 0
    return true

func launch(goal):
    holder = null
    collision_layer = saved_layer
    collision_mask = saved_mask
    add_collision_exception_with(thrower)
    var offset = goal - global_transform.origin
    var duration = clamp(Vector2(offset.x, offset.z).length() / 10.0, 0.8, 1.8)
    flight_velocity = Vector3(offset.x / duration, (offset.y + 0.4) / duration + 10.0 * duration, offset.z / duration)
    flying = true
    hit_fighters.clear()

func kick(fighter, direction):
    if not available() or fighter.strength < required_strength or direction.length_squared() < 0.01:
        return false
    thrower = fighter
    hit_fighters.clear()
    add_collision_exception_with(fighter)
    ground_velocity = Vector3(direction.x, 0, direction.z).normalized() * 10.0
    pending_ground_velocity = Vector3.ZERO
    sliding = true
    return true

func finish_motion():
    flying = false
    sliding = false
    pending_ground_velocity = Vector3.ZERO
    if is_instance_valid(thrower):
        remove_collision_exception_with(thrower)
    for fighter in hit_fighters:
        if is_instance_valid(fighter):
            remove_collision_exception_with(fighter)
    hit_fighters.clear()
    thrower = null

func impact_fighter(other, damage):
    if other.has_method("receive_hit") and not other in hit_fighters:
        hit_fighters.append(other)
        if is_instance_valid(thrower) and thrower.combat_enabled:
            if other.has_method("receive_car_hit"):
                other.receive_car_hit(self, thrower, damage, flight_velocity if flying else ground_velocity)
            else:
                other.receive_hit(thrower, damage, false)

func update_moving_shadow():
    var active = holder != null or flying or sliding
    if not active and not shadow_active:
        return
    if active != shadow_active:
        for child in get_children():
            if child is MeshInstance and child != moving_shadow:
                child.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF if active else GeometryInstance.SHADOW_CASTING_SETTING_ON
    shadow_active = active
    if moving_shadow == null:
        moving_shadow = MeshInstance.new()
        var footprint = QuadMesh.new()
        footprint.size = Vector2(2.1, 5.2)
        moving_shadow.mesh = footprint
        var material = SpatialMaterial.new()
        material.flags_transparent = true
        material.flags_unshaded = true
        material.params_cull_mode = SpatialMaterial.CULL_DISABLED
        material.albedo_color = Color(0, 0, 0, 0.25)
        moving_shadow.material_override = material
        moving_shadow.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
        add_child(moving_shadow)
        moving_shadow.set_as_toplevel(true)
    moving_shadow.visible = false
    if active:
        var excluded = [self]
        for fighter in get_tree().get_nodes_in_group("fighters"):
            excluded.append(fighter)
        if is_instance_valid(holder):
            excluded.append(holder)
        if is_instance_valid(thrower) and not thrower in excluded:
            excluded.append(thrower)
        var origin = global_transform.origin + Vector3.UP * 0.1
        var ground = get_world().direct_space_state.intersect_ray(origin, origin + Vector3.DOWN * 30, excluded)
        if not ground.empty():
            moving_shadow.global_transform = Transform(Basis(Vector3.UP, global_transform.basis.get_euler().y) * Basis(Vector3.RIGHT, -PI / 2), ground.position + Vector3.UP * 0.025)
            moving_shadow.visible = true

func release_drop():
    launch(global_transform.origin + Vector3.DOWN * 0.5)
    flight_velocity = Vector3.DOWN

func _physics_process(delta):
    if Engine.editor_hint:
        return
    update_moving_shadow()
    if holder != null:
        if not is_instance_valid(holder) or not holder.combat_enabled:
            release_drop()
        return
    if sliding:
        if pending_ground_velocity.length_squared() > 0.01:
            ground_wait += delta
            if ground_wait >= 0.8:
                finish_motion()
                return
            var contact_ahead = move_and_collide(pending_ground_velocity * delta, true, true, true)
            if contact_ahead != null and contact_ahead.collider.has_method("receive_car_hit"):
                return
            ground_velocity = pending_ground_velocity
            pending_ground_velocity = Vector3.ZERO
        var before_contact = ground_velocity
        var next_velocity = move_and_slide(ground_velocity + Vector3.DOWN * 2, Vector3.UP)
        for index in range(get_slide_count()):
            var other = get_slide_collision(index).collider
            var fresh_contact = not other in hit_fighters
            impact_fighter(other, 14.0)
            if other.has_method("receive_car_hit"):
                if not other.combat_enabled:
                    add_collision_exception_with(other)
                pending_ground_velocity = before_contact
                if fresh_contact:
                    ground_wait = 0.0
        if pending_ground_velocity.length_squared() > 0.01:
            return
        ground_velocity = Vector3(next_velocity.x, 0, next_velocity.z).move_toward(Vector3.ZERO, 6.0 * delta)
        if ground_velocity.length() < 0.2:
            finish_motion()
        return
    if not flying:
        return
    flight_velocity.y -= 20.0 * delta
    var contact = move_and_collide(flight_velocity * delta)
    if contact == null:
        return
    var other = contact.collider
    if other.has_method("receive_hit"):
        if not other in hit_fighters:
            impact_fighter(other, 20.0)
        if not other.combat_enabled:
            add_collision_exception_with(other)
        flight_velocity.x = 0.0
        flight_velocity.z = 0.0
        flight_velocity.y = min(flight_velocity.y, -1.0)
    else:
        flight_velocity = flight_velocity.slide(contact.normal)
        if contact.normal.y > 0.5:
            finish_motion()



