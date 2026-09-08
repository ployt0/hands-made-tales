class_name ChipStackDisplay
extends Control

var amount: int
var base_colour: Color
var rim_colour: Color
var stack_count: int
var to_pot_pos: Vector2

func _init(p_amount: int, p_base: Color, p_rim: Color, p_count: int, p_to_pot_pos: Vector2) -> void:
    amount = p_amount
    base_colour = p_base
    rim_colour = p_rim
    stack_count = p_count
    to_pot_pos = p_to_pot_pos

func _draw() -> void:
    for i in range(stack_count):
        var center = Vector2(0, -i * 5.0)
        # Drop shadow
        draw_circle(center + Vector2(0, 2), 15.0, Color(0, 0, 0, 0.35))
        # Outer rim
        draw_circle(center, 14.0, rim_colour)
        # Chip body
        draw_circle(center, 12.0, base_colour)
        # Outer casino stripes
        for angle_idx in range(6):
            var angle = (TAU / 6.0) * angle_idx
            var spoke_start = center + Vector2(cos(angle), sin(angle)) * 8.0
            var spoke_end = center + Vector2(cos(angle), sin(angle)) * 14.0
            draw_line(spoke_start, spoke_end, rim_colour, 2.5)
        # Inner circle
        draw_circle(center, 7.0, base_colour.darkened(0.25))
        draw_arc(center, 7.0, 0, TAU, 16, rim_colour.lightened(0.2), 1.0)

static func animate_chip_bet(chip_holder: Control, pot_center_label: Node) -> void:
    var chips_visual: ChipStackDisplay = chip_holder.get_node("Visual")

    var travel_time: float = randf_range(0.35, 0.45)
    var tween = pot_center_label.create_tween().set_parallel(true)

    tween.tween_property(chip_holder, "position", chips_visual.to_pot_pos, travel_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(chip_holder, "scale", Vector2(1.1, 1.1), travel_time * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(chip_holder, "modulate:a", 1.0, travel_time * 0.4)
    tween.tween_property(chips_visual, "rotation", deg_to_rad(randf_range(-12.0, 12.0)), travel_time)

    # Fade & sink into pot
    tween.chain().tween_property(chip_holder, "modulate:a", 0.0, 0.25).set_delay(0.05)
    tween.tween_property(chip_holder, "scale", Vector2(0.7, 0.7), 0.25).set_delay(0.05)

    # Bounce pot label
    pot_center_label.pivot_offset = pot_center_label.size * 0.5
    var pot_tween = pot_center_label.create_tween()
    pot_tween.tween_property(pot_center_label, "scale", Vector2(1.18, 1.18), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    pot_tween.tween_property(pot_center_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

    tween.finished.connect(func():
        if is_instance_valid(chip_holder):
            chip_holder.queue_free()
    )


static func create_chip_holder(seat: SeatData, p_amount: int, pot_center_label: Label, rng: RandomNumberGenerator) -> Control:
    if p_amount <= 0 or not is_instance_valid(seat.ui):
        return

    var from_pos: Vector2 = seat.ui.global_position + (seat.ui.size * 0.5)
    if seat.ui.size == Vector2.ZERO:
        from_pos = seat.ui.position + Vector2(60, 60)

    var target_pot_position: Vector2 = pot_center_label.global_position + (pot_center_label.size * 0.5)
    if pot_center_label.size == Vector2.ZERO:
        target_pot_position = Vector2(800, 360)
    var to_pos: Vector2 = target_pot_position + Vector2(rng.randf_range(-35.0, 35.0), rng.randf_range(10.0, 35.0))

    var base_col: Color
    var rim_col: Color

    if p_amount < 25:
        base_col = Color(0.22, 0.45, 0.9)  # Blue ($10)
        rim_col = Color(0.95, 0.95, 1.0)
    elif p_amount < 100:
        base_col = Color(0.18, 0.68, 0.3)  # Green ($25)
        rim_col = Color(0.9, 0.95, 0.85)
    elif p_amount < 300:
        base_col = Color(0.18, 0.18, 0.22) # Black ($100)
        rim_col = Color(0.95, 0.8, 0.2)
    elif p_amount < 1000:
        base_col = Color(0.6, 0.15, 0.75)  # Purple ($500)
        rim_col = Color(1.0, 0.85, 0.4)
    else:
        base_col = Color(0.85, 0.65, 0.1)  # Gold ($1000+)
        rim_col = Color(1.0, 1.0, 1.0)

    var chip_holder = Control.new()
    chip_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    chip_holder.position = from_pos
    chip_holder.scale = Vector2(0.5, 0.5)
    chip_holder.modulate.a = 0.0

    var count: int = clampi(int(ceil(p_amount / 20.0)), 1, 6)
    var visual = ChipStackDisplay.new(p_amount, base_col, rim_col, count, to_pos)
    visual.name = "Visual"
    chip_holder.add_child(visual)

    var lbl = Label.new()
    lbl.text = "+$%d" % p_amount
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    lbl.position = Vector2(-50, 6)
    lbl.size = Vector2(100, 20)
    lbl.add_theme_font_size_override("font_size", 13)
    lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
    lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 0.95))
    lbl.add_theme_constant_override("outline_size", 5)
    chip_holder.add_child(lbl)
    return chip_holder
