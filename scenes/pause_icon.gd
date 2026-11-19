extends Button

func _draw():
    var center = rect_size * 0.5
    var color = Color("efbd63") if is_hovered() else Color("edf2f4")
    draw_rect(Rect2(center + Vector2(-9, -10), Vector2(6, 20)), color)
    draw_rect(Rect2(center + Vector2(3, -10), Vector2(6, 20)), color)
