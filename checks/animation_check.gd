extends SceneTree
var failures = 0
var boss
var car
var player
var camera
func check(ok, message):
    if ok: print("PASS: ", message)
    else:
        failures += 1
        printerr("FAIL: ", message)
func _init():
    call_deferred("run")
func shot(name):
    yield(self,"idle_frame")
    yield(VisualServer,"frame_post_draw")
    var picture = get_root().get_texture().get_data()
    picture.flip_y()
    picture.save_png("res://checks/animation-" + name + ".png")
func run():
    var arena = load("res://scenes/arena.tscn").instance()
    get_root().add_child(arena)
    current_scene = arena
    yield(self,"idle_frame")
    yield(self,"idle_frame")
    player = arena.get_node("PlayerStart/Player")
    boss = player.get_node("HUD").boss
    player.get_node("HUD").start_battle()
    player.set_physics_process(false)
    boss.set_physics_process(false)
    boss.throws_enabled = true
    boss.full_hits = 3
    boss.global_transform.origin = Vector3(0,0,0)
    player.global_transform.origin = Vector3(0,0,-10)
    car = get_nodes_in_group("throwable_cars")[0]
    car.global_transform.origin = Vector3(0,0,3.3)
    camera = Camera.new()
    arena.add_child(camera)
    camera.global_transform.origin = Vector3(10,6,10)
    camera.look_at(Vector3(0,1.6,1.5),Vector3.UP)
    camera.projection = Camera.PROJECTION_ORTHOGONAL
    camera.size = 10
    camera.current = true
    boss.selected_car = car
    var source = car.global_transform.origin
    boss._physics_process(0.3)
    boss._physics_process(0.1)
    check(car.global_transform.origin.distance_to(source) < 0.01, "При захвате машина не перескакивает")
    yield(shot("grasp"),"completed")
    boss._physics_process(0.5)
    check(car.global_transform.origin.y > 0 and car.global_transform.origin.y < 3.3, "Подъём проходит через промежуточную высоту")
    yield(shot("lift"),"completed")
    boss._physics_process(0.5)
    check(boss.get_node("Pilot").left_shoulder.rotation.x > 2.5, "Руки поднимаются над головой")
    check(boss.get_node("Pilot").left_shoulder.rotation == boss.get_node("BasicExosuit").left_shoulder.rotation, "Пилот и костюм синхронны")
    yield(shot("hold"),"completed")
    boss._physics_process(0.5)
    yield(shot("throw"),"completed")
    for index in range(120):
        if boss.throw_recovery >= 0: break
        boss._physics_process(1.0 / 60.0)
    check(car.flying and boss.throw_recovery == 0, "Выпуск машины совпадает с завершением толчка")
    boss._physics_process(0.15)
    check(boss.throw_recovery > 0 and boss.get_node("Pilot").left_shoulder.rotation.x > 0.65, "После броска руки плавно возвращаются")
    yield(shot("recovery"),"completed")
    boss._physics_process(0.25)
    check(boss.throw_recovery < 0 and abs(boss.get_node("Pilot").left_shoulder.rotation.x - 0.65) < 0.001, "Восстановлена боевая стойка")
    car.finish_motion()
    car.global_transform.origin = Vector3(0,0,3.3)
    boss.rotation.y = 0
    boss.global_transform.origin = Vector3.ZERO
    boss.get_node("Pilot").rotation.y = 0
    boss.get_node("BasicExosuit").rotation.y = 0
    boss.start_car_kick(car)
    boss._physics_process(0.2)
    yield(shot("kick-windup"),"completed")
    boss._physics_process(0.2)
    check(car.sliding and boss.get_node("Pilot").right_hip.rotation.x > 1, "Машина движется при выносе ноги вперёд")
    var yaw = boss.rotation.y
    yield(shot("kick-contact"),"completed")
    car.global_translate(Vector3(2,0,0))
    boss._physics_process(0.2)
    check(boss.rotation.y == yaw, "После контакта босс не поворачивается за машиной")
    boss._physics_process(0.2)
    check(boss.kick_car == null and abs(boss.get_node("Pilot").right_hip.rotation.x) < 0.001, "Нога возвращается в стойку")
    yield(shot("kick-recovery"),"completed")
    print("ANIMATION_CHECK_FAILURES=", failures)
    quit(failures)


