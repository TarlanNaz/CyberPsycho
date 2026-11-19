extends SceneTree
var failures = 0
var attacks = 0
func check(ok, message):
    if ok: print("PASS: ", message)
    else:
        failures += 1
        printerr("FAIL: ", message)
func attack_started(_kind):
    attacks += 1
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
    player.set_physics_process(false)
    boss.global_transform.origin = Vector3(0,0,0)
    player.global_transform.origin = Vector3(0,0,-5)
    boss.chasing = true
    boss.rotation.y = 0
    var camera = Camera.new()
    arena.add_child(camera)
    camera.global_transform.origin = Vector3(10,6,8)
    camera.look_at(Vector3(0,1.4,-1.5),Vector3.UP)
    camera.projection = Camera.PROJECTION_ORTHOGONAL
    camera.size = 10
    camera.current = true
    var origin = boss.global_transform.origin
    yield(frames(30),"completed")
    var displacement = boss.global_transform.origin.distance_to(origin)
    check(displacement > 0.1 and displacement < 0.9, "Ослабленный босс движется медленно в реальном игровом цикле")
    check(boss.combat_phase == boss.CombatPhase.WEAKENED and boss.attack_damage == 4 and boss.attack_speed == 0.55, "Явное ослабленное состояние")
    player.global_transform.origin = boss.global_transform.origin + Vector3(0,0,-1.8)
    boss.connect("attack_started",self,"attack_started")
    boss.attack_decision_in = 0
    yield(frames(2),"completed")
    var initial_time = boss.attack_time
    var initial_frame = Engine.get_physics_frames()
    yield(frames(6),"completed")
    check(attacks > 0 and boss.attack_time > initial_time, "Обычный ИИ начинает и проигрывает ослабленную атаку")
    var expected_time = (Engine.get_physics_frames() - initial_frame) * 0.55 / Engine.iterations_per_second
    check(abs(boss.attack_time - initial_time - expected_time) < 0.003, "Таймер атаки обновляется один раз за физический кадр")
    check(boss.get_node("Pilot").left_shoulder.rotation.x != 0.65 or boss.get_node("Pilot").right_shoulder.rotation.x != 0.65, "Поза атаки не перезаписывается другим обработчиком")
    yield(shot("res://checks/live-weakened-attack.png"),"completed")
    for _i in range(3):
        boss.receive_hit(player,10)
    check(boss.combat_phase == boss.CombatPhase.ACTIVE, "Три попадания меняют фазу")
    check(boss.throws_enabled, "В активной фазе доступны машины")
    check(is_equal_approx(boss.walk_speed, 3.4), "Восстановлена обычная скорость")
    boss.hit_time = 0
    boss.stun_time = 0
    boss.attack_time = -1
    boss.attack_cooldown = 0
    player.global_transform.origin = Vector3(-10,0,0)
    boss.global_transform.origin = Vector3.ZERO
    boss.rotation.y = 0
    var car = get_nodes_in_group("throwable_cars")[0]
    car.global_transform.origin = Vector3(0,0,-6)
    boss.selected_car = car
    boss.throw_cooldown = 0
    var stopped_at = Vector3.ZERO
    var saw_stop = false
    for _i in range(240):
        yield(frames(1),"completed")
        if boss.pickup_wait > 0 and not saw_stop:
            stopped_at = boss.global_transform.origin
            saw_stop = true
        if car.holder == boss:
            break
    check(saw_stop and car.holder == boss, "Подбор: подход, отдельная остановка, затем захват")
    check(boss.global_transform.origin.distance_to(stopped_at) < 0.05, "Босс не движется во время остановки перед захватом")
    var held_at = boss.global_transform.origin
    var health = player.health
    yield(frames(50),"completed")
    check(boss.global_transform.origin.distance_to(held_at) < 0.05, "Родительский ИИ не двигает босса во время подъёма")
    check(car.holder == boss and boss.get_node("Pilot").left_shoulder.rotation.x > 2, "Подъём сохраняется между настоящими физическими кадрами")
    check(player.health == health, "Во время подъёма не запускаются параллельные удары")
    yield(shot("res://checks/live-pickup.png"),"completed")
    var idle_car = get_nodes_in_group("throwable_cars")[1]
    check(idle_car.moving_shadow == null, "Для стоящих машин не создаются и не обновляются динамические тени")
    print("LIVE_BOSS_FAILURES=",failures)
    quit(failures)





