extends SceneTree
var failures = 0
func check(ok, message):
    if ok: print("PASS: ",message)
    else:
        failures += 1
        printerr("FAIL: ",message)
func frames(count):
    for _i in range(count):
        yield(self,"physics_frame")
        yield(self,"idle_frame")
func shot(path):
    yield(self,"idle_frame")
    yield(VisualServer,"frame_post_draw")
    var picture = get_root().get_texture().get_data()
    picture.flip_y()
    picture.save_png(path)
func _init():
    call_deferred("run")
func run():
    var arena = load("res://scenes/arena.tscn").instance()
    get_root().add_child(arena)
    current_scene = arena
    yield(self,"idle_frame")
    yield(self,"idle_frame")
    var player = arena.get_node("PlayerStart/Player")
    var hud = player.get_node("HUD")
    var boss = hud.boss
    hud.start_battle()
    boss.activate_combat()
    boss.global_transform.origin = Vector3.ZERO
    boss.rotation.y = 0
    player.global_transform.origin = Vector3(0,0,-2)
    var car = get_nodes_in_group("throwable_cars")[0]
    car.global_transform.origin = Vector3(0,2.6,-0.5)
    car.pick_up(boss)
    boss.selected_car = car
    boss.lift_time = 1.4
    for _i in range(150):
        yield(frames(1),"completed")
        if car.flying: break
    boss.set_physics_process(false)
    check(car.flying and car.holder == null, "Вблизи босс всё равно выпускает машину")
    var near_health = player.max_health
    yield(frames(150),"completed")
    check(player.health == near_health and not car.flying, "Близкая цель остаётся невредимой, машина перелетает её")
    check(car.global_transform.origin.distance_to(boss.global_transform.origin) > 5, "Машина не падает под ноги босса")
    # Настоящее попадание при включённой физике игрока.
    player.global_transform.origin = Vector3(0,0,6)
    player.vertical_speed = 0
    car.global_transform.origin = Vector3(0,2.6,0)
    yield(frames(2),"completed")
    car.pick_up(boss)
    car.launch(player.global_transform.origin)
    var before = player.global_transform.origin
    var health = player.health
    for _i in range(120):
        yield(frames(1),"completed")
        if player.car_recoil_time > 0: break
    check(player.car_recoil_time > 0 and player.health == health - 20, "Попадание включает отталкивание и один полный урон")
    check(not player.start_attack(), "При отталкивании атака недоступна")
    player.request_dash(Vector2.RIGHT)
    check(player.dash_time == 0, "При отталкивании рывок недоступен")
    yield(frames(8),"completed")
    check(player.get_node("Pilot").rotation.x > 0.1, "Во время отталкивания виден наклон и пошатывание")
    player.view_pivot.global_transform.origin = player.global_transform.origin + Vector3.UP
    yield(shot("res://checks/car-knockback.png"),"completed")
    yield(frames(120),"completed")
    check(player.global_transform.origin.distance_to(before) > 1.5, "Игрок физически отталкивается с коллизиями")
    check(not car.flying and car.global_transform.origin.y < 0.3, "После удара машина опускается на землю")
    check(player.health == health - 20 and player.car_recoil_time == 0, "Повторного урона нет, отталкивание завершается")
    yield(shot("res://checks/car-knockback-landed.png"),"completed")
    # У стены выбирается свободная сторона для отталкивания.
    player.global_transform.origin = Vector3(0,0,17.5)
    player.vertical_speed = 0
    car.global_transform.origin = Vector3(0,2.6,12)
    yield(frames(2),"completed")
    car.pick_up(boss)
    car.launch(player.global_transform.origin)
    for _i in range(120):
        yield(frames(1),"completed")
        if player.car_recoil_time > 0: break
    yield(frames(120),"completed")
    check(abs(player.global_transform.origin.x) > 1, "У стены игрок отталкивается в свободную сторону")
    check(not car.flying and car.global_transform.origin.y < 0.3, "У стены машина также приземляется на землю")
    player.health = 10
    player.global_transform.origin = Vector3(0,0,6)
    player.vertical_speed = 0
    car.global_transform.origin = Vector3(0,2.6,0)
    yield(frames(2),"completed")
    car.pick_up(boss)
    car.launch(player.global_transform.origin)
    yield(frames(180),"completed")
    check(player.health == 0 and hud.mode == "result", "Смертельное попадание сохраняет исход боя")
    check(not car.flying and car.global_transform.origin.y < 0.3, "После смертельного попадания машина также падает на землю")
    print("RECOIL_FAILURES=",failures)
    quit(failures)


