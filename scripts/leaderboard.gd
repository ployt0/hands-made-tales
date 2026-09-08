class_name Leaderboard
extends CanvasLayer

@onready var info_label: Label = %InfoLabel
@onready var lbv_box: VBoxContainer = $PanelContainer/MarginContainer/LBVBox
@onready var leaderboard_label: Label = $PanelContainer/MarginContainer/LBVBox/LeaderboardLabel
@onready var panel_container: PanelContainer = $PanelContainer

var _entries_error: bool
var leaderboard_items: Array[Control] = []
var submitting: bool = false
var has_submitted_this_game: bool = false
var invalid_char_regex := RegEx.new()
var is_expanded_view: bool = false


func populate_lb() -> void:
    leaderboard_label.text = Constants.LEADERBOARD_NAME.capitalize()
    _load_entries()
    _set_info_text()

func expand() -> void:
    is_expanded_view = true
    populate_lb()

    var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.tween_property($PanelContainer, "position", Vector2(1120, 40), 0.4)
    tw.tween_property($PanelContainer, "size", Vector2(440, 820), 0.4)


func reset_hud_view(compact_pos: Vector2, compact_size: Vector2) -> void:
    is_expanded_view = false
    has_submitted_this_game = false

    var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.tween_property($PanelContainer, "position", compact_pos, 0.3)
    tw.tween_property($PanelContainer, "size", compact_size, 0.3)
    populate_lb()


func _create_entry(_pos: int, entry: TaloLeaderboardEntry) -> void:
    var hbox = HBoxContainer.new()
    hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var p_name = Label.new()
    var p_score = Label.new()

    p_name.text = entry.player_alias.identifier

    # Decode composite score for clean label display
    var raw_val = int(entry.score)
    if raw_val >= Constants.MAX_TIME_S:
        var decoded = Constants.decode_composite_score(raw_val)
        var mins = decoded.seconds / 60
        var secs = decoded.seconds % 60
        p_score.text = "%d (%02d:%02d)" % [decoded.matches, mins, secs]
    else:
        p_score.text = str(raw_val)

    p_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    p_name.add_theme_font_size_override("font_size", 18)
    p_score.add_theme_font_size_override("font_size", 18)
    p_score.modulate = Color.GOLD

    hbox.add_child(p_name)
    hbox.add_child(p_score)
    lbv_box.add_child(hbox)
    leaderboard_items.append(hbox)

func _build_entries(entries: Array[TaloLeaderboardEntry]) -> void:
    for child in lbv_box.get_children().slice(3):
        child.queue_free()

    if len(entries) != 0:
        info_label.text = ""
        info_label.visible = false

    for entry in entries:
        entry.position = entries.find(entry)
        _create_entry(entry.position, entry)

func _load_entries() -> void:
    var page = 0
    var done = false
    var entries_page: LeaderboardsAPI.EntriesPage

    while !done:
        var options: LeaderboardsAPI.GetEntriesOptions = Talo.leaderboards.GetEntriesOptions.new()
        options.page = page

        entries_page = await Talo.leaderboards.get_entries(Constants.LEADERBOARD_NAME, options)

        if not is_instance_valid(entries_page):
            _entries_error = true
            return

        if entries_page.is_last_page:
            done = true
        else:
            page += 1

    _build_entries(entries_page.entries)
    _set_info_text()

func _set_info_text() -> void:
    if lbv_box.get_child_count() == 3:
        if _entries_error:
            info_label.text = "Failed loading leaderboard %s." % Constants.LEADERBOARD_NAME
        else:
            info_label.text = "No entries yet!"
    else:
        info_label.text = "%d leaders" % (lbv_box.get_child_count() - 3)
