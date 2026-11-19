extends Reference

const INK = Color("101920")
const MUTED = Color("a4b3bd")
const GOLD = Color("efbd63")

static func font(size):
    var result = DynamicFont.new()
    result.font_data = preload("res://assets/fonts/NotoSans-Regular.ttf")
    result.size = size
    return result

static func box(color, border = Color("34434c")):
    var result = StyleBoxFlat.new()
    result.bg_color = color
    result.border_color = border
    result.set_border_width_all(1)
    result.set_corner_radius_all(10)
    result.content_margin_left = 20
    result.content_margin_right = 20
    result.content_margin_top = 14
    result.content_margin_bottom = 14
    return result

static func label(parent, text, size = 18, color = Color("edf2f4")):
    var result = Label.new()
    result.text = text
    result.add_font_override("font", font(size))
    result.add_color_override("font_color", color)
    result.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(result)
    return result

static func button(parent, text, target, method, primary = false):
    var result = Button.new()
    result.text = text
    result.rect_min_size.y = 52
    result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    result.add_font_override("font", font(18))
    result.add_stylebox_override("normal", box(GOLD if primary else Color("1a2832")))
    result.add_stylebox_override("hover", box(Color("f8d497") if primary else Color("2d424f"), GOLD))
    result.add_stylebox_override("pressed", box(Color("cda151") if primary else Color("101920"), GOLD))
    result.add_stylebox_override("focus", box(Color(0, 0, 0, 0), GOLD))
    result.add_color_override("font_color", INK if primary else Color("edf2f4"))
    result.add_color_override("font_color_hover", INK if primary else Color.white)
    result.add_color_override("font_color_pressed", INK if primary else Color.white)
    result.add_color_override("font_color_focus", INK if primary else Color.white)
    result.connect("pressed", target, method)
    parent.add_child(result)
    return result

static func danger_button(parent, text, target, method):
    var result = button(parent, text, target, method)
    result.add_stylebox_override("normal", box(Color("a8313e"), Color("d65361")))
    result.add_stylebox_override("hover", box(Color("c53e4d"), Color("f38a94")))
    result.add_stylebox_override("pressed", box(Color("802531"), Color("d65361")))
    result.add_stylebox_override("focus", box(Color(0, 0, 0, 0), Color("f38a94")))
    return result
