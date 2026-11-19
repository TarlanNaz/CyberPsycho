extends Control

signal aim_changed(direction)
signal attack_requested
signal dash_requested(direction)

const RADIUS = 60.0
const INSET = 34.0
const DEAD_ZONE = 0.12

var direction = Vector2.ZERO
var move_finger = -1
var look_finger = -1
var stick_engaged = false
var last_tap_direction = Vector2.ZERO
var last_tap_ms = -1000
var aim_origin = Vector2.ZERO
var aim_direction = Vector2.ZERO

func track_direction(value):
    if value.length() < 0.25:
        stick_engaged = false
    elif value.length() >= 0.65 and not stick_engaged:
        stick_engaged = true
        var now = OS.get_ticks_msec()
        var same_direction = last_tap_direction.dot(value.normalized()) > 0.85
        if now - last_tap_ms <= 320 and same_direction:
            emit_signal("dash_requested", value.normalized())
            last_tap_ms = -1000
        else:
            last_tap_ms = now
            last_tap_direction = value.normalized()

func _ready():
    visible = OS.has_touchscreen_ui_hint() or OS.has_feature("mobile") or OS.get_name().to_lower() == "sailfish"

func stick_center():
    return Vector2(INSET + RADIUS, rect_size.y - INSET - RADIUS)

func aim_center():
    return Vector2(rect_size.x - INSET - RADIUS, rect_size.y - INSET - RADIUS)

func _draw():
    var center = stick_center()
    draw_circle(center, RADIUS, Color(0.08, 0.11, 0.14, 0.42))
    draw_arc(center, RADIUS, 0, TAU, 64, Color(1, 1, 1, 0.52), 2.0, true)
    draw_circle(center + direction * RADIUS * 0.65, RADIUS * 0.35, Color(1, 1, 1, 0.72))
    var right_center = aim_origin if look_finger != -1 else aim_center()
    draw_circle(right_center, RADIUS, Color(0.08, 0.11, 0.14, 0.42))
    draw_arc(right_center, RADIUS, 0, TAU, 64, Color(1, 0.65, 0.45, 0.7), 2.0, true)
    draw_circle(right_center + aim_direction * RADIUS * 0.65, RADIUS * 0.3, Color(1, 0.7, 0.5, 0.8))

func update_stick(position):
    direction = ((position - stick_center()) / RADIUS).limit_length(1.0)
    if direction.length() < DEAD_ZONE:
        direction = Vector2.ZERO
    track_direction(direction)
    update()

func _unhandled_input(event):
    if event is InputEventScreenTouch:
        if event.pressed:
            show()
            if move_finger == -1 and event.position.distance_to(stick_center()) <= RADIUS * 1.25:
                move_finger = event.index
                update_stick(event.position)
            elif look_finger == -1 and event.position.x >= rect_size.x * 0.5:
                look_finger = event.index
                aim_origin = event.position
                aim_direction = Vector2.ZERO
                update()
            else:
                return
        elif event.index == move_finger:
            move_finger = -1
            direction = Vector2.ZERO
            track_direction(direction)
            update()
        elif event.index == look_finger:
            look_finger = -1
            aim_direction = Vector2.ZERO
            emit_signal("aim_changed", Vector2.ZERO)
            emit_signal("attack_requested")
            update()
        else:
            return
    elif event is InputEventScreenDrag:
        if event.index == move_finger:
            update_stick(event.position)
        elif event.index == look_finger:
            aim_direction = ((event.position - aim_origin) / RADIUS).limit_length(1.0)
            emit_signal("aim_changed", aim_direction)
            update()
        else:
            return
    else:
        return
    get_tree().set_input_as_handled()

func _notification(what):
    if what == MainLoop.NOTIFICATION_WM_FOCUS_OUT or what == NOTIFICATION_PAUSED:
        move_finger = -1
        look_finger = -1
        direction = Vector2.ZERO
        stick_engaged = false
        last_tap_ms = -1000
        aim_direction = Vector2.ZERO
        emit_signal("aim_changed", Vector2.ZERO)
        update()
