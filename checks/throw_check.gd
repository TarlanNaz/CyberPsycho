extends SceneTree
var failures = 0
func check(ok, message):
    if ok: print("PASS: ", message)
    else:
        failures += 1
        printerr("FAIL: ", message)
func _init():
    call_deferred("run")
func run():
    var arena = load("res://scenes/arena.tscn").instance()
    get_root().add_child(arena)
    current_scene = arena
    yield(self, "idle_frame")
    yield(self, "idle_frame")
    var player = arena.get_node("PlayerStart/Player")
    var boss = player.get_node("HUD").boss
    player.get_node("HUD").start_battle()
    player.set_physics_process(false)
    boss.set_physics_process(false)
    boss.face_point(player.global_transform.origin)
    boss.hit_time = 0
    for i in range(3):
        boss.attack_time = 0
        boss.receive_hit(player, 10)
        if i < 2: check(not boss.throws_enabled, "До третьего попадания бросков нет")
    check(boss.full_hits == 3 and boss.throws_enabled, "Третье полное попадание включает броски")
    boss.hit_time = 0
    boss.stun_time = 0
    var car = get_nodes_in_group("throwable_cars")[0]
    boss.global_transform.origin = Vector3(0,0,0)
    car.global_transform.origin = Vector3(0,0,-3)
    boss.selected_car = null
    player.global_transform.origin = Vector3(0,0,5)
    player.view_pivot.global_transform.origin = Vector3(0,1,3)
    boss._physics_process(0.3)
    check(car.holder == boss and car.collision_layer == 0, "Босс поднимает настоящую машину")
    boss._physics_process(0.8)
    check(car.global_transform.origin.y > 1.5, "Машина поднята над головой")
    yield(self, "idle_frame")
    yield(VisualServer, "frame_post_draw")
    var image = get_root().get_texture().get_data()
    image.flip_y()
    image.save_png("res://checks/car_lift.png")
    for index in range(180):
        if car.flying: break
        boss._physics_process(1.0 / 60.0)
    check(car.flying and car.holder == null and boss.throw_cooldown > 0, "После подготовки машина летит, включается перерыв")
    # Отдельный бросок по неподвижной цели, без блока.
    car.flying = false
    car.thrower = null
    car.global_transform.origin = Vector3(0,3.3,0)
    player.global_transform.origin = Vector3(0,0,6)
    car.pick_up(boss)
    car.launch(player.global_transform.origin)
    player.set_physics_process(true)
    var health = player.health
    yield(create_timer(2.5), "timeout")
    check(player.health == health - 20, "Машина наносит один полный удар даже в защиту")
    check(not car.flying and car.collision_layer != 0, "Машина приземляется и остаётся препятствием")
    car.global_transform.origin = Vector3(0,3.3,0)
    car.pick_up(boss)
    car.launch(player.global_transform.origin)
    player.global_transform.origin = Vector3(8,0,6)
    health = player.health
    yield(create_timer(2.5), "timeout")
    check(player.health == health, "Уход с траектории позволяет избежать машины")
    car.pick_up(boss)
    boss.throw_recovery = -1.0
    boss.selected_car = car
    boss.hit_time = 0.24
    boss._physics_process(0.01)
    check(car.holder == null and car.flying, "Попадание прерывает подъём и роняет машину")
    car.flying = false
    car.holder = null
    car.pick_up(boss)
    boss.throw_recovery = -1.0
    boss.selected_car = car
    boss.disable_combat()
    check(car.holder == null and car.flying, "Поражение босса освобождает машину")
    print("THROW_CHECK_FAILURES=", failures)
    quit(failures)









