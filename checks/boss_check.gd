extends SceneTree
var failures = 0
func check(value, message):
    if value: print("PASS: ", message)
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
    check(abs(boss.walk_speed - 1.4) < 0.001 and boss.turn_speed_degrees == 150 and boss.dash_speed == 0, "Ослабленная подвижность без рывка")
    check(boss.max_health == 300 and boss.attack_damage == 4 and boss.attack_speed == 0.55 and boss.block_damage_ratio == 0.25, "Здоровье сохранено, вводные атаки ослаблены")
    check(boss.counter_chance == 0 and boss.counter_reaction == 0.18 and boss.counter_on_counter, "Контратаки отключены в ослабленном состоянии")
    check(boss.start_attack(), "В ослабленном состоянии доступна настоящая атака")
    boss.face_point(player.global_transform.origin)
    for i in range(3):
        var health = boss.health
        boss.receive_hit(player, 10)
        check(boss.health == health - 10 and boss.full_hits == i + 1, "Вводный удар наносит полный урон " + str(i + 1))
    check(boss.throws_enabled and boss.combat_phase == boss.CombatPhase.ACTIVE and is_equal_approx(boss.walk_speed, 3.4) and boss.attack_damage == 10, "Третий удар восстанавливает боевые параметры")
    boss.hit_time = 0
    boss.stun_time = 0
    boss.attack_time = -1
    var health = boss.health
    boss.receive_hit(player, 10)
    check(abs(health - boss.health - 2.5) < 0.001 and boss.full_hits == 3, "После перехода блок работает и не увеличивает счётчик")
    print("BOSS_CHECK_FAILURES=", failures)
    quit(failures)


