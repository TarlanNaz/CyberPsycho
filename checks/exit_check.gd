extends SceneTree
func _init():
    call_deferred("run")
func run():
    var arena = load("res://scenes/arena.tscn").instance()
    get_root().add_child(arena)
    current_scene = arena
    yield(self,"idle_frame")
    yield(self,"idle_frame")
    var hud = arena.get_node("PlayerStart/Player/HUD")
    if "return_menu" in OS.get_cmdline_args():
        hud.start_battle()
        hud.pause_button.emit_signal("pressed")
        if not paused or hud.mode != "pause":
            quit(1)
            return
        var found = false
        for child in hud.content.get_children():
            if child is Button and child.text == "В главное меню":
                child.emit_signal("pressed")
                found = true
                break
        yield(self,"idle_frame")
        yield(self,"idle_frame")
        yield(self,"idle_frame")
        hud = current_scene.get_node("PlayerStart/Player/HUD")
        if not found or not paused or hud.mode != "menu":
            quit(1)
            return
        print("PAUSE_RETURN_MENU_OK")
    if "pause_menu" in OS.get_cmdline_args():
        hud.start_tutorial()
        hud.pause_battle()
        var has_return = false
        for child in hud.content.get_children():
            if child is Button and child.text == "Выйти из игры":
                printerr("UNEXPECTED_EXIT_IN_PAUSE")
                quit(1)
                return
            if child is Button and child.text == "В главное меню":
                has_return = true
        if not has_return:
            quit(1)
            return
        print("PAUSE_HAS_RETURN_WITHOUT_EXIT")
    yield(self,"idle_frame")
    yield(VisualServer,"frame_post_draw")
    var image = get_root().get_texture().get_data()
    image.flip_y()
    image.save_png("res://checks/exit-pause.png" if hud.mode == "pause" else "res://checks/exit-menu.png")
    if hud.mode == "pause":
        quit()
        return
    for child in hud.content.get_children():
        if child is Button and child.text == "Выйти из игры":
            var color = child.get_stylebox("normal").bg_color
            if color.r < color.g * 2 or color.r < color.b * 2:
                printerr("EXIT_BUTTON_NOT_RED")
                quit(1)
                return
            if child.get_global_rect().end.y > 600:
                printerr("EXIT_BUTTON_CLIPPED")
                quit(1)
                return
            print("EXIT_BUTTON_FOUND: ",hud.mode)
            child.emit_signal("pressed")
            return
    printerr("EXIT_BUTTON_MISSING")
    quit(1)
