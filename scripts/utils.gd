class_name Utils


static func get_all_translation_keys() -> Dictionary:
    var result = {}
    var file = FileAccess.open("res://locale/en.po", FileAccess.READ)
    if file == null:
        push_error("Missing en.po")
        return result

    var current_id = ""
    while not file.eof_reached():
        var line = file.get_line().strip_edges()

        if line.begins_with("msgid "):
            current_id = line.substr(7, line.length() - 8) # strip quotes

        elif line.begins_with("msgstr "):
            var value = line.substr(8, line.length() - 9)
            result[current_id] = value

    return result


func validate_translations():
    var keys = get_all_translation_keys()

    for key in keys:
        var translated = tr(key)

        if translated == key:
            push_warning("Missing translation: \"%s\"" % key)

        # basic BBCode validation
        if translated.count("[") != translated.count("]"):
            push_warning("Broken BBCode in: " + key)

        if translated.count("[img") != translated.count("[/img]"):
            push_warning("Unclosed [img] in: " + key)


static func log(game_content: GameContent, msg: String, fallback_color: Color = Color(0.9, 0.9, 0.9)) -> void:
    var log_scroll: ScrollContainer = game_content.log_scroll
    var log_vbox: VBoxContainer = game_content.log_vbox

    var final_color = fallback_color

    if msg.contains("color=yellow"): final_color = Color(1.0, 0.85, 0.2)
    elif msg.contains("color=gold"): final_color = Color(1.0, 0.75, 0.0)
    elif msg.contains("color=green"): final_color = Color(0.3, 0.9, 0.4)
    elif msg.contains("color=red"): final_color = Color(1.0, 0.3, 0.3)
    elif msg.contains("color=cyan"): final_color = Color(0.3, 0.8, 1.0)
    elif msg.contains("color=orange"): final_color = Color(1.0, 0.6, 0.1)

    var regex = RegEx.new()
    regex.compile("\\[.*?\\]")
    var plain_text = regex.sub(msg, "", true)
    print("[GAME LOG] " + plain_text)

    var lbl = Label.new()
    lbl.text = plain_text
    lbl.modulate = final_color
    lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    lbl.add_theme_font_size_override("font_size", 13)
    log_vbox.add_child(lbl)

    if log_vbox.get_child_count() > 50:
        log_vbox.get_child(0).queue_free()

    # Wait for the layout to calculate the new label size, then scroll to true bottom
    var tree = game_content.get_tree()
    await tree.process_frame
    if is_instance_valid(log_scroll):
        log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)
