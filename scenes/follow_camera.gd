extends Spatial

func _ready():
    set_as_toplevel(true)
    global_transform.origin = get_parent().global_transform.origin + Vector3.UP

func _physics_process(delta):
    var target = get_parent().global_transform.origin + Vector3.UP
    global_transform.origin = global_transform.origin.linear_interpolate(target, 1.0 - exp(-10.0 * delta))
