extends SceneTree

var failures = 0
var arena
var player
var hud
var boss

func check(value, message):
    if not value:
        failures += 1
        printerr("FAIL: ", message)
    else:
        print("PASS: ", message)

func _init():
    call_deferred("run")

func frame():
    yield(self, "idle_frame")
    yield(self, "idle_frame")

func screenshot(path):
    yield(self, "idle_frame")
    yield(VisualServer, "frame_post_draw")
    var image = get_root().get_texture().get_data()
    image.flip_y()
    image.save_png(path)

func run():
    arena = load("res://scenes/arena.tscn").instance()
    get_root().add_child(arena)
    current_scene = arena
    yield(frame(), "completed")
    player = get_nodes_in_group("fighters")[0]
    for fighter in get_nodes_in_group("fighters"):
        if fighter.has_node("HUD"):
            player = fighter
    hud = player.get_node("HUD")
    boss = hud.boss
    check(paused and hud.mode == "menu", "Стартовое меню останавливает уровень")
    yield(screenshot("res://checks/menu.png"), "completed")
    hud.show_help()
    yield(screenshot("res://checks/help.png"), "completed")
    hud.back_from_help()
    hud.start_tutorial()
    yield(frame(), "completed")
    check(not paused and not boss.is_physics_processing(), "Обучение: враг ждёт, мир доступен")
    var start = player.global_transform.origin
    # Неверное направление не должно закрывать первую реплику.
    player.global_translate(Vector3.RIGHT * 0.5)
    hud._process(0.01)
    check(hud.movement_step == 0 and hud.step == 0, "Неверное направление не засчитывается")
    for index in range(4):
        var actions = ["walk_left", "walk_right", "walk_forward", "walk_back"]
        Input.action_press(actions[index])
        yield(create_timer(0.4), "timeout")
        Input.action_release(actions[index])
        yield(frame(), "completed")
        if index < 3:
            check(hud.step == 0 and hud.movement_step == index + 1, "Отдельный шаг направления " + str(index + 1))
    check(hud.step == 1, "Четыре направления завершены до поворота")
    player.get_node("Pilot").rotation.y += 1.0
    hud._process(0.01)
    check(hud.step == 2, "Поворот открывает урок удара")
    player.start_attack()
    check(hud.step == 3, "Настоящее начало атаки открывает рывок")
    player.attack_time = -1
    player.request_dash(Vector2.LEFT)
    check(hud.step == 4 and boss.is_physics_processing(), "Рывок включает врага и урок блока")
    player.dash_time = 0
    # Реальный блок и контратака через существующие боевые методы.
    player.global_transform.origin = Vector3(0, 0, 0)
    boss.global_transform.origin = Vector3(0, 0, -2)
    player.face_point(boss.global_transform.origin)
    boss.face_point(player.global_transform.origin)
    boss.full_hits = 3
    boss.throws_enabled = true
    player.receive_hit(boss, 10)
    check(hud.step == 5, "Фронтальный блок открывает урок контратаки")
    player.block_time = 0.2
    player.start_attack()
    check(hud.step == 6 and player.attack_kind == 3, "Реальная контратака завершает обучение")
    hud._process(6.1)
    check(hud.step == -1 and not hud.lesson_panel.visible, "После последней реплики диалог закрывается")
    hud.pause_battle()
    check(paused and hud.mode == "pause", "Пауза останавливает мир")
    yield(screenshot("res://checks/pause.png"), "completed")
    hud.continue_battle()
    hud.step = 0
    hud.movement_step = 0
    hud.mobile = true
    player.get_node("HUD/TouchControls").show()
    hud.update_lesson()
    hud.lesson_panel.show()
    boss.set_physics_process(false)
    yield(screenshot("res://checks/dialogue.png"), "completed")
    var touch = player.get_node("HUD/TouchControls")
    var press = InputEventScreenTouch.new()
    press.index = 0
    press.position = touch.stick_center() + Vector2.RIGHT * 48
    press.pressed = true
    touch._unhandled_input(press)
    check(touch.direction.x > 0.5, "Сенсорный стик принимает направление")
    var aim = InputEventScreenTouch.new()
    aim.index = 1
    aim.position = touch.aim_center()
    aim.pressed = true
    touch._unhandled_input(aim)
    player.attack_time = -1
    hud.pause_battle()
    check(touch.direction == Vector2.ZERO and touch.look_finger == -1 and player.attack_time < 0, "Пауза сбрасывает оба пальца без удара")
    hud.continue_battle()
    check(touch.direction == Vector2.ZERO and player.touch_aim == Vector2.ZERO, "Продолжение не восстанавливает удержание")
    hud.start_battle()
    check(hud.step == -1 and boss.is_physics_processing(), "Пропуск обучения запускает бой")
    player.health = 1
    player.attack_time = -1
    player.receive_hit(boss, 100)
    check(hud.finished and hud.mode == "finishing", "Результат ждёт анимацию поражения")
    yield(create_timer(2.2), "timeout")
    check(hud.mode == "result" and hud.overlay.visible, "Экран поражения после анимации")
    yield(screenshot("res://checks/result.png"), "completed")
    hud.replay_battle()
    yield(frame(), "completed")
    yield(frame(), "completed")
    player = current_scene.get_node("PlayerStart/Player")
    hud = player.get_node("HUD")
    boss = hud.boss
    check(hud.mode == "play" and player.health == player.max_health and boss.health == boss.max_health, "Повтор пересоздаёт бой без меню со свежим здоровьем")
    boss.receive_hit(player, 10000)
    yield(create_timer(2.2), "timeout")
    check(hud.mode == "result" and hud.content.get_child(1).text == "Босс побеждён", "Экран победы после падения босса")
    hud.return_to_menu()
    yield(frame(), "completed")
    yield(frame(), "completed")
    check(paused and current_scene.get_node("PlayerStart/Player/HUD").mode == "menu", "Возврат открывает главное меню")
    player = current_scene.get_node("PlayerStart/Player")
    hud = player.get_node("HUD")
    hud.mobile = true
    hud.start_tutorial()
    yield(frame(), "completed")
    yield(screenshot("res://checks/dialogue.png"), "completed")
    touch = player.get_node("HUD/TouchControls")
    for index in range(4):
        var finger = InputEventScreenTouch.new()
        finger.index = 0
        finger.pressed = true
        finger.position = touch.stick_center() + hud.MOVE_DIRECTIONS[index] * 60
        touch._unhandled_input(finger)
        yield(create_timer(0.4), "timeout")
        finger.pressed = false
        touch._unhandled_input(finger)
        yield(frame(), "completed")
    check(hud.step == 1, "Сенсорный стик проходит все четыре направления")
    Input.action_press("walk_right")
    hud.pause_battle()
    hud.continue_battle()
    var held_position = player.global_transform.origin
    yield(create_timer(0.15), "timeout")
    check(player.global_transform.origin.distance_to(held_position) < 0.05, "После паузы зажатая клавиша не двигает игрока")
    Input.action_release("walk_right")
    hud.pause_battle()
    hud.restart_level()
    yield(frame(), "completed")
    yield(frame(), "completed")
    hud = current_scene.get_node("PlayerStart/Player/HUD")
    check(hud.mode == "play" and hud.step == 0 and hud.movement_step == 0, "Перезапуск обучения возвращает первый диалог")
    print("UI_CHECK_FAILURES=", failures)
    quit(failures)

