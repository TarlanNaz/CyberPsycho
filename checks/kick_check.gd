extends SceneTree
var failures = 0
func check(ok, message):
    if ok: print("PASS: ", message)
    else:
        failures += 1
        printerr("FAIL: ", message)
func _init():
    call_deferred("run")
func frame():
    yield(self,"physics_frame")
    yield(self,"idle_frame")
    yield(self,"physics_frame")
    yield(self,"idle_frame")
func shot(path):
    yield(self,"idle_frame")
    yield(VisualServer,"frame_post_draw")
    var picture = get_root().get_texture().get_data()
    picture.flip_y()
    picture.save_png(path)
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
    player.set_physics_process(false)
    boss.set_physics_process(false)
    boss.throws_enabled = true
    boss.full_hits = 3
    boss.global_transform.origin = Vector3(0,0,0)
    player.global_transform.origin = Vector3(0,0,8)
    player.view_pivot.global_transform.origin = Vector3(0,1,4)
    var car = get_nodes_in_group("throwable_cars")[0]
    car.global_transform.origin = Vector3(0,0,3.3)
    yield(frame(),"completed")
    check(boss.opposite_sides(car), "Машина разделяет бойцов")
    boss._physics_process(0.01)
    check(boss.kick_car == car and car.holder == null, "Враг выбирает пинок вместо подъёма")
    boss._physics_process(0.4)
    check(car.sliding and not car.flying, "Пинок запускает машину по земле")
    var health = player.health
    yield(create_timer(2),"timeout")
    check(player.health == health - 14, "Пинок наносит один удар машиной")
    check(not car.sliding, "Трение останавливает машину")
    car.global_transform.origin = Vector3(0,0,3.3)
    player.global_transform.origin = Vector3(3,0,0)
    yield(frame(),"completed")
    check(not boss.opposite_sides(car), "Положение сбоку не считается противоположной стороной")
    car.finish_motion()
    boss.kick_car = null
    boss.selected_car = null
    player.set_physics_process(true)
    player.global_transform.origin = Vector3(0,0,9)
    car.global_transform.origin = Vector3(0,3.3,1.5)
    car.pick_up(boss)
    car.launch(player.global_transform.origin)
    yield(create_timer(0.25),"timeout")
    check(car.moving_shadow.visible and car.get_node("Body").cast_shadow == GeometryInstance.SHADOW_CASTING_SETTING_OFF, "В полёте одна проекция тени на поверхности")
    yield(shot("res://checks/car-flight-shadow.png"),"completed")
    yield(create_timer(2),"timeout")
    check(not car.moving_shadow.visible and car.get_node("Body").cast_shadow == GeometryInstance.SHADOW_CASTING_SETTING_ON, "После приземления возвращается штатная тень")
    yield(shot("res://checks/car-landed-shadow.png"),"completed")
    print("KICK_CHECK_FAILURES=", failures)
    quit(failures)



