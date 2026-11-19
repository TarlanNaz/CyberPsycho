extends CanvasLayer

const UI = preload("res://scenes/interface_style.gd")
onready var player = get_parent()
var boss = null
var finished = false
var mode = "menu"
var overlay
var content
var pause_button
var lesson_panel
var lesson_title
var lesson_quote
var lesson_hint
var objective
var step = -1
var step_origin = Vector3.ZERO
var turn_origin = 0.0
var mobile = false
var last_device_mobile = false
var lesson_elapsed = 0.0
var movement_step = 0
var movement_progress = 0.0
var previous_position = Vector3.ZERO
const MOVE_DIRECTIONS = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]

func _ready():
    pause_mode = Node.PAUSE_MODE_PROCESS
    mobile = OS.has_touchscreen_ui_hint() or OS.has_feature("mobile") or OS.get_name().to_lower() == "sailfish"
    last_device_mobile = mobile
    build_interface()
    $TouchControls.pause_mode = Node.PAUSE_MODE_STOP
    call_deferred("bind_fighters")

func build_interface():
    UI.label($BossVitals, "ПРОТИВНИК / ЭКЗОКОСТЮМ", 13, UI.MUTED)
    var player_name = UI.label($PlayerVitals, "ПИЛОТ / БЕЗ КОСТЮМА", 13, UI.MUTED)
    player_name.set_anchors_and_margins_preset(Control.PRESET_TOP_RIGHT)
    objective = UI.label($TouchControls, "ПАРКОВКА  /  ПЕРВЫЙ БОЙ", 13, UI.GOLD)
    objective.rect_position = Vector2(24, 82)
    pause_button = UI.button($TouchControls, "", self, "pause_battle")
    pause_button.set_script(preload("res://scenes/pause_icon.gd"))
    pause_button.hint_tooltip = "Пауза"
    pause_button.set_anchors_and_margins_preset(Control.PRESET_CENTER_TOP)
    pause_button.rect_position.y = 20
    pause_button.rect_min_size.x = 64
    # Кнопка паузы остаётся видимой и на ПК, где стики скрыты.
    $TouchControls.remove_child(pause_button)
    add_child(pause_button)
    $TouchControls.remove_child(objective)
    add_child(objective)
    lesson_panel = PanelContainer.new()
    add_child(lesson_panel)
    lesson_panel.set_anchors_and_margins_preset(Control.PRESET_CENTER_BOTTOM)
    lesson_panel.margin_left = -270
    lesson_panel.margin_right = 270
    lesson_panel.margin_top = -186
    lesson_panel.margin_bottom = -22
    lesson_panel.add_stylebox_override("panel", UI.box(Color("101d27"), Color("736044")))
    var column = VBoxContainer.new()
    column.add_constant_override("separation", 6)
    lesson_panel.add_child(column)
    lesson_title = UI.label(column, "", 13, UI.GOLD)
    lesson_quote = UI.label(column, "", 19)
    lesson_quote.autowrap = true
    lesson_quote.rect_min_size.y = 58
    lesson_hint = UI.label(column, "", 14, UI.MUTED)
    lesson_hint.autowrap = true
    lesson_hint.rect_min_size.y = 38
    overlay = ColorRect.new()
    overlay.color = Color(0.025, 0.045, 0.065, 0.88)
    overlay.set_anchors_and_margins_preset(Control.PRESET_WIDE)
    add_child(overlay)
    var margin = MarginContainer.new()
    margin.set_anchors_and_margins_preset(Control.PRESET_WIDE)
    margin.add_constant_override("margin_left", 54)
    margin.add_constant_override("margin_right", 54)
    margin.add_constant_override("margin_top", 28)
    margin.add_constant_override("margin_bottom", 28)
    overlay.add_child(margin)
    var center = CenterContainer.new()
    margin.add_child(center)
    content = VBoxContainer.new()
    content.rect_min_size.x = 680
    content.add_constant_override("separation", 12)
    center.add_child(content)
    lesson_panel.hide()

func bind_fighters():
    player.connect("health_changed", self, "update_player_health")
    player.connect("defeated", self, "finish_battle", [false])
    player.connect("attack_started", self, "on_player_attack")
    player.connect("hit_received", self, "on_player_hit")
    player.connect("dashed", self, "on_player_dash")
    update_player_health(player.health, player.max_health)
    var bosses = get_tree().get_nodes_in_group("bosses")
    if not bosses.empty():
        boss = bosses[0]
        boss.connect("health_changed", self, "update_boss_health")
        boss.connect("defeated", self, "finish_battle", [true])
        update_boss_health(boss.health, boss.max_health)
    else:
        $BossVitals.hide()
    if get_tree().has_meta("parking_start"):
        var start_mode = get_tree().get_meta("parking_start")
        get_tree().remove_meta("parking_start")
        if start_mode == "tutorial":
            start_tutorial()
        else:
            start_battle()
    else:
        show_menu()

func clear_content(kicker, title, subtitle):
    for child in content.get_children():
        content.remove_child(child)
        child.queue_free()
    UI.label(content, kicker, 14, UI.GOLD)
    UI.label(content, title, 40)
    UI.label(content, subtitle, 17, UI.MUTED)
    var separator = HSeparator.new()
    content.add_child(separator)
    overlay.show()
    pause_button.hide()
    lesson_panel.hide()
    objective.hide()
    $PlayerVitals.hide()
    $BossVitals.hide()

func show_menu():
    mode = "menu"
    freeze_world()
    clear_content("ПЕРВЫЙ УРОВЕНЬ  /  01", "Парковка", "Ты без костюма. Напротив — противник в экзокостюме.")
    var card = PanelContainer.new()
    card.add_stylebox_override("panel", UI.box(Color("15232e")))
    content.add_child(card)
    var column = VBoxContainer.new()
    card.add_child(column)
    UI.label(column, "ОСВОЙ УПРАВЛЕНИЕ. ВЫДЕРЖИ БОЙ.", 14, UI.GOLD)
    UI.label(column, "Противник объяснит основы — и проверит их в деле.", 17)
    UI.button(content, "Начать с обучения", self, "start_tutorial", true).grab_focus()
    UI.button(content, "Сразу в бой", self, "start_battle")
    UI.button(content, "Управление", self, "show_help")
    UI.danger_button(content, "Выйти из игры", self, "quit_game")

func freeze_world():
    reset_input()
    get_tree().paused = true

func reset_input():
    $TouchControls.notification(NOTIFICATION_PAUSED)
    player.notification(NOTIFICATION_PAUSED)
    player.mouse_aim = false

func resume_world():
    overlay.hide()
    reset_input()
    get_tree().paused = false
    pause_button.show()
    objective.show()
    $PlayerVitals.show()
    $BossVitals.visible = is_instance_valid(boss)
    $TouchControls.set_process_unhandled_input(true)
    $TouchControls.visible = mobile
    lesson_panel.visible = step >= 0

func start_tutorial():
    mode = "play"
    step = 0
    step_origin = player.global_transform.origin
    previous_position = step_origin
    movement_step = 0
    movement_progress = 0.0
    if is_instance_valid(boss):
        boss.set_physics_process(false)
    update_lesson()
    resume_world()

func start_battle():
    mode = "play"
    step = -1
    if is_instance_valid(boss):
        boss.set_physics_process(true)
    resume_world()
    objective.text = "ПАРКОВКА  /  ПОБЕДИ ПРОТИВНИКА"

func pause_battle():
    if mode != "play" or finished:
        return
    mode = "pause"
    freeze_world()
    clear_content("ПАРКОВКА  /  ПАУЗА", "Передышка", "Бой продолжится с того же места.")
    UI.button(content, "Продолжить", self, "continue_battle", true).grab_focus()
    UI.button(content, "Управление", self, "show_help")
    if step >= 0:
        UI.button(content, "Пропустить обучение", self, "start_battle")
    UI.button(content, "Начать заново", self, "restart_level")
    UI.button(content, "В главное меню", self, "return_to_menu")

func continue_battle():
    mode = "play"
    resume_world()

func show_help():
    clear_content("СПРАВКА  /  УПРАВЛЕНИЕ", "Держи направление", "Защита работает автоматически, пока ты смотришь на удар.")
    var row = HBoxContainer.new()
    row.add_constant_override("separation", 24)
    content.add_child(row)
    for device in ["ТЕЛЕФОН", "КЛАВИАТУРА И МЫШЬ"]:
        var panel = PanelContainer.new()
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        panel.add_stylebox_override("panel", UI.box(Color("15232e")))
        row.add_child(panel)
        var column = VBoxContainer.new()
        column.add_constant_override("separation", 12)
        panel.add_child(column)
        UI.label(column, device, 13, UI.GOLD)
        var lines = ["Движение — левый стик", "Направление — потяни справа", "Удар — отпусти правый палец", "Рывок — два отклонения стика"] if device == "ТЕЛЕФОН" else ["Движение — WASD / стрелки", "Направление — курсор мыши", "Удар — левая кнопка мыши", "Рывок — два нажатия направления"]
        for line in lines:
            UI.label(column, line, 16)
    UI.label(content, "Блок пропускает часть урона. После блока сразу ударь для контратаки.", 16, UI.MUTED)
    UI.label(content, "Рывок: отпусти направление между двумя быстрыми нажатиями. Пауза — Esc или кнопка сверху.", 14, UI.MUTED)
    UI.button(content, "Назад", self, "back_from_help", true).grab_focus()

func back_from_help():
    if mode == "menu":
        show_menu()
    else:
        mode = "play"
        pause_battle()

func return_to_menu():
    # Пересоздание уровня также сбрасывает здоровье, ИИ и этап обучения.
    retry()

func quit_game():
    reset_input()
    get_tree().quit()

func restart_level():
    get_tree().set_meta("parking_start", "tutorial" if step >= 0 else "battle")
    retry()

func retry():
    get_tree().paused = false
    for effect in get_tree().get_nodes_in_group("hit_effects"):
        effect.queue_free()
    get_tree().reload_current_scene()

func _input(event):
    if event is InputEventScreenTouch:
        mobile = true
    elif event is InputEventMouse and event.device != -1 and OS.get_ticks_msec() >= player.ignore_mouse_until:
        mobile = false
    if last_device_mobile != mobile:
        last_device_mobile = mobile
        if step >= 0:
            update_lesson()
    if event.is_action_pressed("ui_cancel"):
        get_tree().set_input_as_handled()
        if mode == "play":
            pause_battle()
        elif mode == "pause":
            continue_battle()

func _process(delta):
    if mode != "play" or get_tree().paused or step < 0:
        return
    lesson_elapsed += delta
    if step == 0:
        var travel = player.global_transform.origin - previous_position
        previous_position = player.global_transform.origin
        var local_travel = player.view_pivot.global_transform.basis.xform_inv(travel)
        var screen_travel = Vector2(local_travel.x, local_travel.z)
        movement_progress += max(0.0, screen_travel.dot(MOVE_DIRECTIONS[movement_step]))
        if movement_progress >= 1.0:
            movement_step += 1
            movement_progress = 0.0
            if movement_step == 4:
                advance_lesson()
            else:
                update_lesson()
    elif step == 1 and abs(wrapf(player.get_node("Pilot").rotation.y - turn_origin, -PI, PI)) > 0.65:
        advance_lesson()
    elif step == 6 and lesson_elapsed > 6.0:
        step = -1
        lesson_panel.hide()
        objective.text = "ПАРКОВКА  /  ПОБЕДИ ПРОТИВНИКА"

func advance_lesson():
    step += 1
    lesson_elapsed = 0.0
    turn_origin = player.get_node("Pilot").rotation.y
    if step == 4 and is_instance_valid(boss):
        boss.set_physics_process(true)
    update_lesson()

func update_lesson():
    var titles = ["ДВИЖЕНИЕ", "НАПРАВЛЕНИЕ", "УДАР", "РЫВОК", "БЛОК", "КОНТРАТАКА", "ТЕПЕРЬ ПО-НАСТОЯЩЕМУ"]
    var quotes = ["«Без костюма? Тогда хотя бы научись двигаться.»", "«Не отворачивайся. Держи меня перед собой.»", "«А бить умеешь? Покажи. Пока можно в воздух.»", "«Ногами работай! Резко смени позицию.»", "«Я иду. Смотри на меня и встреть удар защитой.»", "«Выдержал? Теперь отвечай сразу после блока!»", "«Основы знаешь. Посмотрим, надолго ли тебя хватит.»"]
    var hints = ["Пройди несколько шагов левым стиком.", "Потяни пальцем справа, чтобы развернуть бойца.", "Отпусти правый палец — один жест, один удар.", "Дважды отклони левый стик в одну сторону, возвращая в центр.", "Повернись к врагу и не атакуй. Блок автоматический; часть урона пройдёт.", "Прими удар в блок, затем сразу отпусти правый палец для ответа.", "Победи противника. Пауза и справка — по кнопке сверху."] if mobile else ["Пройди несколько шагов: WASD или стрелки.", "Переведи курсор в сторону — боец повернётся за ним.", "Нажми левую кнопку мыши. Можно ударить в воздух.", "Дважды быстро нажми одно направление, отпуская между нажатиями.", "Наведи курсор на врага и не атакуй. Блок автоматический; часть урона пройдёт.", "Прими удар в блок и сразу нажми левую кнопку мыши.", "Победи противника. Esc — пауза и справка."]
    lesson_title.text = "ПРОТИВНИК  /  %02d · %s" % [min(step + 1, 6), titles[step]]
    lesson_quote.text = quotes[step]
    lesson_hint.text = hints[step]
    if step == 4 and is_instance_valid(boss) and not boss.throws_enabled:
        lesson_quote.text = "«Ну же. Покажи три настоящих удара, пока у тебя есть шанс.»"
        lesson_hint.text = "Попади три раза. Враг пока медленный, слабо бьёт и не блокирует."
    if step == 0:
        var names = ["влево", "вправо", "вверх", "вниз"]
        var keys = ["A / ←", "D / →", "W / ↑", "S / ↓"]
        var opening = "Двигай левый джойстик, чтобы ходить." if mobile else "Двигайся клавишами WASD или стрелками."
        var movement_quotes = ["«%s Для начала пройди влево.»" % opening, "«Уже лучше. А теперь вправо.»", "«Хорошо. Теперь пройди вверх.»", "«И обратно — вниз. Не стой столбом.»"]
        lesson_quote.text = movement_quotes[movement_step]
        lesson_hint.text = "Направление %d из 4  ·  %s" % [movement_step + 1, "Отклони левый джойстик " + names[movement_step] if mobile else "Нажми " + keys[movement_step]]
    objective.text = "ОБУЧЕНИЕ  /  %s" % titles[step]

func refresh_boss_lesson():
    if step == 4:
        update_lesson()

func on_player_attack(kind):
    if mode != "play":
        return
    if step == 2 or (step == 5 and kind == 3):
        advance_lesson()

func on_player_dash():
    if mode == "play" and step == 3:
        advance_lesson()

func on_player_hit(blocked):
    if mode == "play" and step == 4 and blocked:
        advance_lesson()

func update_player_health(current, maximum):
    $PlayerVitals/Bar.max_value = maximum
    $PlayerVitals/Bar.value = current

func update_boss_health(current, maximum):
    $BossVitals/Bar.max_value = maximum
    $BossVitals/Bar.value = current

func finish_battle(attacker, victory):
    if finished:
        return
    finished = true
    mode = "finishing"
    lesson_panel.hide()
    pause_button.hide()
    objective.hide()
    for fighter in get_tree().get_nodes_in_group("fighters"):
        fighter.disable_combat()
    reset_input()
    $TouchControls.set_process_unhandled_input(false)
    $TouchControls.hide()
    var loser = boss if victory else player
    yield(loser.play_defeat(attacker), "completed")
    mode = "result"
    clear_content("ПАРКОВКА  /  ИТОГ БОЯ", "Босс побеждён" if victory else "Ты повержен", "Человек выстоял против машины." if victory else "Следи за замахом. Принимай удар в блок и отвечай.")
    UI.button(content, "Повторить бой", self, "replay_battle", true).grab_focus()
    UI.button(content, "В главное меню", self, "return_to_menu")

func replay_battle():
    # Следующий экземпляр открывается сразу в бою через одноразовый флаг дерева.
    get_tree().set_meta("parking_start", "battle")
    retry()

func _notification(what):
    if what == MainLoop.NOTIFICATION_WM_FOCUS_OUT and mode == "play":
        pause_battle()



