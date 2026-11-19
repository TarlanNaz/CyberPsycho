extends "res://scenes/fighter.gd"

signal dashed

const WALK_SPEED = 4.0
const GRAVITY = 18.0
onready var view_pivot = $ViewPivot
onready var camera = $ViewPivot/Camera
onready var touch_controls = $HUD/TouchControls

var vertical_speed = 0.0
var dash_time = 0.0
var dash_cooldown = 0.0
var dash_direction = Vector3.ZERO
var touch_aim = Vector2.ZERO
var mouse_aim = false
var ignore_mouse_until = 0
var waiting_for_neutral = false
var car_recoil_time = 0.0
var car_recoil_direction = Vector3.ZERO
var car_recoil_distance = 0.0
var car_recoil_remaining = 0.0
var recoil_car = null
const CAR_RECOIL_DURATION = 0.6

func _ready():
    ._ready()
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event):
    if event is InputEventMouse and (event.device == -1 or OS.get_ticks_msec() < ignore_mouse_until):
        return
    if event.is_action_pressed("ui_cancel"):
        mouse_aim = false
    elif event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
        mouse_aim = true
        aim_at_screen(event.position)
        start_attack()
    elif event is InputEventMouseMotion:
        mouse_aim = true
    elif event is InputEventScreenTouch or event is InputEventScreenDrag:
        mouse_aim = false

func _input(event):
    if event is InputEventScreenTouch or event is InputEventScreenDrag:
        mouse_aim = false
        ignore_mouse_until = OS.get_ticks_msec() + 500

func set_touch_aim(direction):
    mouse_aim = false
    if direction.length() > 0.2:
        touch_aim = direction

func aim_at_screen(position):
    var plane = Plane(Vector3.UP, global_transform.origin.y + 1.2)
    var point = plane.intersects_ray(camera.project_ray_origin(position), camera.project_ray_normal(position))
    if point != null and car_recoil_time <= 0.0 and combat_enabled and stun_time <= 0.0 and attack_time < 0.0 and hit_time <= 0.0:
        var offset = point - global_transform.origin
        if Vector2(offset.x, offset.z).length() > 0.2:
            $Pilot.rotation.y = atan2(-offset.x, -offset.z)

func _physics_process(delta):
    combat_tick(delta)
    if not combat_enabled:
        return
    if car_recoil_time > 0.0:
        var progress = 1.0 - car_recoil_time / CAR_RECOIL_DURATION
        vertical_speed -= GRAVITY * delta
        var speed = car_recoil_distance * 2.0 * (1.0 - progress) / CAR_RECOIL_DURATION
        var step = min(speed * delta, car_recoil_remaining)
        var safe_step = recoil_safe_distance(car_recoil_direction, step, recoil_car)
        var recoil_velocity = car_recoil_direction * safe_step / delta
        recoil_velocity.y = vertical_speed
        var recoil_start = global_transform.origin
        vertical_speed = move_and_slide(recoil_velocity, Vector3.UP).y
        var travel = global_transform.origin - recoil_start
        car_recoil_remaining = max(0.0, car_recoil_remaining - Vector2(travel.x, travel.z).length())
        $Pilot.advance_walk(0.0, delta)
        $Pilot.car_knockback_pose(progress)
        car_recoil_time = max(0.0, car_recoil_time - delta)
        return
    dash_time = max(0.0, dash_time - delta)
    dash_cooldown = max(0.0, dash_cooldown - delta)
    var keyboard_direction = Vector2(
        Input.get_action_strength("walk_right") - Input.get_action_strength("walk_left"),
        Input.get_action_strength("walk_back") - Input.get_action_strength("walk_forward")
    )
    if waiting_for_neutral:
        if keyboard_direction == Vector2.ZERO:
            waiting_for_neutral = false
        keyboard_direction = Vector2.ZERO
    var direction = (keyboard_direction + touch_controls.direction).limit_length(1.0)
    if touch_controls.move_finger == -1:
        touch_controls.track_direction(keyboard_direction.limit_length(1.0))
    var movement = view_pivot.transform.basis.xform(Vector3(direction.x, 0, direction.y))
    var facing = direction
    if touch_aim.length() > 0.2:
        facing = touch_aim
    if mouse_aim:
        aim_at_screen(get_viewport().get_mouse_position())
    elif facing != Vector2.ZERO and attack_time < 0.0 and hit_time <= 0.0 and stun_time <= 0.0:
        $Pilot.rotation.y = lerp_angle($Pilot.rotation.y, atan2(-facing.x, -facing.y),
                min(12.0 * delta, 1.0))

    vertical_speed -= GRAVITY * delta
    var velocity = movement * WALK_SPEED * combat_movement_scale()
    if dash_time > 0.0:
        velocity = dash_direction * 10.0
    if stun_time > 0.0:
        velocity = Vector3.ZERO
        dash_time = 0.0
    velocity.y = vertical_speed
    var start = global_transform.origin
    vertical_speed = move_and_slide(velocity, Vector3.UP).y
    push_contacted_car(velocity, delta)
    var travel = global_transform.origin - start
    $Pilot.advance_walk(Vector2(travel.x, travel.z).length(), delta)
    animate_combat()

func request_dash(direction):
    if car_recoil_time > 0.0 or not combat_enabled or stun_time > 0.0 or dash_cooldown > 0.0 or attack_time >= 0.0 or hit_time > 0.0:
        return
    dash_direction = view_pivot.transform.basis.xform(Vector3(direction.x, 0, direction.y)).normalized()
    dash_time = 0.18
    dash_cooldown = 0.65
    emit_signal("dashed")

func start_attack():
    if dash_time > 0.0 or car_recoil_time > 0.0:
        return false
    var started = .start_attack()
    if started and not mouse_aim and touch_aim.length() > 0.2:
        $Pilot.rotation.y = atan2(-touch_aim.x, -touch_aim.y)
    return started

func receive_car_hit(car, attacker, amount, direction):
    var before = health
    receive_hit(attacker, amount, false)
    if health >= before or not combat_enabled:
        return
    direction.y = 0.0
    if direction.length_squared() < 0.01:
        direction = global_transform.origin - car.global_transform.origin
        direction.y = 0.0
    direction = direction.normalized()
    if direction.length_squared() < 0.01:
        direction = Vector3.FORWARD
    var side = direction.cross(Vector3.UP)
    car_recoil_direction = side
    car_recoil_distance = 0.0
    for candidate in [side, -side]:
        var free_distance = recoil_safe_distance(candidate, 4.2, car)
        if free_distance > car_recoil_distance:
            car_recoil_direction = candidate
            car_recoil_distance = free_distance
    car_recoil_remaining = car_recoil_distance
    recoil_car = car
    face_point(global_transform.origin - car_recoil_direction)
    car_recoil_time = CAR_RECOIL_DURATION
    dash_time = 0.0
    touch_controls.notification(NOTIFICATION_PAUSED)
    notification(NOTIFICATION_PAUSED)

func recoil_safe_distance(direction, distance, car):
    if distance <= 0.001:
        return 0.0
    var query = PhysicsShapeQueryParameters.new()
    query.set_shape($Collider.shape)
    query.transform = global_transform * $Collider.transform
    query.transform.origin.y += 0.06
    query.collision_mask = collision_mask
    query.margin = 0.04
    query.exclude = [self]
    if is_instance_valid(car):
        query.exclude = [self, car]
    var motion = direction * distance
    var fractions = get_world().direct_space_state.cast_motion(query, motion)
    if fractions.empty():
        return 0.0
    var safe = distance * fractions[0]
    if fractions[0] < 1.0:
        safe = max(0.0, safe - 0.06)
    return safe

func _notification(what):
    if what == MainLoop.NOTIFICATION_WM_FOCUS_OUT or what == NOTIFICATION_PAUSED:
        dash_time = 0.0
        mouse_aim = false
        touch_aim = Vector2.ZERO
        waiting_for_neutral = true
