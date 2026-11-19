extends SceneTree
var failures = 0
var arena
var player
var boss
var car
var blocker
var second
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
func setup():
    if is_instance_valid(arena):
        current_scene = null
        arena.free()
    paused = false
    arena = load("res://scenes/arena.tscn").instance()
    get_root().add_child(arena)
    current_scene = arena
    yield(self,"idle_frame")
    yield(self,"idle_frame")
    player = arena.get_node("PlayerStart/Player")
    player.get_node("HUD").start_battle()
    boss = player.get_node("HUD").boss
    boss.activate_combat()
    boss.global_transform.origin = Vector3(1.9,0,0)
    player.global_transform.origin = Vector3(-1.9,0,0)
    player.view_pivot.global_transform.origin = Vector3(0,1,0)
    boss.throw_cooldown = 8
    var cars = get_nodes_in_group("throwable_cars")
    car = cars[0]
    blocker = cars[1]
    second = cars[2]
    car.global_transform = Transform(Basis.IDENTITY,Vector3.ZERO)
    blocker.global_transform = Transform(Basis.IDENTITY,Vector3(-3.2,0,-5.7))
    second.global_transform.origin = Vector3(20,0,-15)
    yield(frames(2),"completed")
func wait_for_hit():
    for _i in range(120):
        yield(frames(1),"completed")
        if player.car_recoil_time > 0:
            return
func overlaps_other_car():
    var query = PhysicsShapeQueryParameters.new()
    query.set_shape(player.get_node("Collider").shape)
    query.transform = player.global_transform * player.get_node("Collider").transform
    query.transform.origin.y += 0.03
    query.exclude = [player,car]
    for hit in get_root().get_world().direct_space_state.intersect_shape(query,32):
        if hit.collider == blocker or hit.collider == second:
            return true
    return false
func _init():
    call_deferred("run")
func run():
    yield(setup(),"completed")
    check(boss.opposite_sides(car), "Позиция как на скриншоте определяется по разные стороны машины")
    yield(wait_for_hit(),"completed")
    boss.set_physics_process(false)
    check(car.sliding and car.holder == null, "Босс пинает с земли во время восстановления броска")
    check(player.health == 86 and player.car_recoil_time > 0, "Пинок включает отталкивание с одним уроном")
    check(abs(player.car_recoil_direction.z) > 0.9 and abs(player.car_recoil_direction.x) < 0.1, "Игрок отталкивается поперёк движения машины")
    check(player.car_recoil_direction.z > 0, "Проверка формы коллайдера выбирает сторону без соседней машины")
    var clean = true
    for _i in range(110):
        yield(frames(1),"completed")
        clean = clean and not overlaps_other_car()
    check(clean, "При отталкивании нет пересечения с соседней машиной")
    check(car.global_transform.origin.x < -3.5, "После освобождения прохода машина движется дальше игрока")
    check(player.health == 86, "Проезжающая машина не наносит повторный урон")
    yield(shot("res://checks/side-kick-cleared.png"),"completed")
    yield(setup(),"completed")
    second.global_transform = Transform(Basis.IDENTITY,Vector3(-3.2,0,5.7))
    yield(frames(2),"completed")
    yield(wait_for_hit(),"completed")
    boss.set_physics_process(false)
    clean = true
    for _i in range(110):
        yield(frames(1),"completed")
        clean = clean and not overlaps_other_car()
    check(clean, "Две соседние машины ограничивают отталкивание без пересечения")
    check(not car.sliding, "Если проход не освобождён, машина останавливается")
    yield(setup(),"completed")
    blocker.global_transform.origin = Vector3(20,0,10)
    yield(frames(2),"completed")
    yield(wait_for_hit(),"completed")
    boss.set_physics_process(false)
    var sign_z = sign(player.car_recoil_direction.z)
    blocker.global_transform = Transform(Basis.IDENTITY,Vector3(-3.2,0,sign_z * 3.5))
    clean = true
    for _i in range(110):
        yield(frames(1),"completed")
        clean = clean and not overlaps_other_car()
    check(clean, "Новая машина на пути останавливает отталкивание без проникновения")
    print("SIDE_KICK_FAILURES=",failures)
    quit(failures)
