extends Spatial

var age = 0.0

func _ready():
    add_to_group("hit_effects")
    var effects = get_tree().get_nodes_in_group("hit_effects")
    if effects.size() > 24:
        effects[0].queue_free()
    $Drops.emitting = true

func _process(delta):
    age += delta
    $Stain.scale = Vector3.ONE * min(1.0, 0.3 + age * 5.0)
    if age >= 2.4:
        queue_free()
