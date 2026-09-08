extends Control

signal closed

const DEFAULT_FONT_SIZE := 24

## We can remove dependency on Advanced GUI; but we can't use FontVariant, or RichTextLabel.
@export var bold_font: Font

@onready var scroll_container: ScrollContainer = $MarginContainer/ScrollContainer
@onready var v_box_container: VBoxContainer = $MarginContainer/ScrollContainer/VBoxContainer

## This is increased to enlarge header font sizes when we don't have bold for it.
var _no_bold_compo: float = 1.0

func _ready():
    load_credits()
    $BackButton.grab_focus()

func _input(ev):
    if not visible:
        return
    if ev.is_action_pressed("ui_cancel"):
        _on_back_button_pressed()


const CREDITS_TEXT := """
[h1]A Game by 11bitbay[/h1]
[url]https://11bitbay.itch.io/[/url]

[h3]Music[/h3]
[url=https://pixabay.com/music/traditional-jazz-the-best-jazz-club-in-new-orleans-164472/]Best Jazz Club in New Orleans[/url], by Paolo Argento. Sep '23
[url=https://pixabay.com/music/upbeat-poker-player-392184/]Poker Player[/url], by Business Star. Aug '25


[h3]SFX contributions[/h3]
[h4]CC0:[/h4]
[url=https://freesound.org/people/SilverDubloons/packs/43992/]Clay chips[/url], by SilverDubloons.


[h3]Graphical resources[/h3]

[h4]Mandatory attribution:[/h4]
[url=https://opengameart.org/users/nubux]~50% of the portraits[/url], by Morgan Strauss. CC-BY 3.0


[h4]CC0:[/h4]
[url=https://opengameart.org/content/playing-cards-vector-png]Cards[/url] by Byron Knoll

"""

# [url=][/url], by
# [url=][/url], by
# [url=][/url], by



func map_header_size(def_size: int) -> Dictionary:
    return {
        "h1": int(def_size * 2 * _no_bold_compo),
        "h2": int(def_size * 1.7 * _no_bold_compo),
        "h3": int(def_size * 1.3 * _no_bold_compo),
        "h4": int(def_size * 1.15 * _no_bold_compo),
        "h5": int(def_size * 1.05 * _no_bold_compo),
    }


func load_credits():
    # Clear previous entries
    for old_node in v_box_container.get_children():
        old_node.queue_free()

    var base_font: Font = get_theme_font("font", "Label")

    # Check if a custom bold font is configured in the theme
    if bold_font == null:
        # Unless we have another ttf file, we cannot use FontVariation without "AdvancedGUI".
        bold_font = base_font
        _no_bold_compo = 1.1

    var headers = map_header_size(DEFAULT_FONT_SIZE)

    # Pre-compile regex patterns for parser
    var header_rx = RegEx.new()
    header_rx.compile("^\\[(h1|h2|h3|h4|h5)\\](.*)\\[/\\1\\]$")

    var url_with_text_rx = RegEx.new()
    url_with_text_rx.compile("\\[url=([^\\]]+)\\]([^\\[]+)\\[/url\\]")

    var url_plain_rx = RegEx.new()
    url_plain_rx.compile("\\[url\\]([^\\[]+)\\[/url\\]")

    var lines := CREDITS_TEXT.split("\n", true)

    for raw_line in lines:
        var line := raw_line.strip_edges()

        if line == "":
            # Blank line = vertical spacer
            var spacer := Control.new()
            spacer.custom_minimum_size.y = 16
            v_box_container.add_child(spacer)
            continue

        # Parse header properties
        var header_match = header_rx.search(line)
        var font_size = DEFAULT_FONT_SIZE
        var is_header = false
        var text_content = line

        if header_match:
            is_header = true
            var h_tag = header_match.get_string(1)
            text_content = header_match.get_string(2)
            if headers.has(h_tag):
                font_size = headers[h_tag]

        # Apply standard or bold font depending on line type
        var current_font: Font = bold_font if is_header else base_font

        # Parse URLs
        var url_target = ""
        var url_with_text_match = url_with_text_rx.search(text_content)
        var url_plain_match = url_plain_rx.search(text_content)

        if url_with_text_match:
            url_target = url_with_text_match.get_string(1)
            text_content = url_with_text_rx.sub(text_content, "$2", true)
        elif url_plain_match:
            url_target = url_plain_match.get_string(1)
            text_content = url_plain_rx.sub(text_content, "$1", true)

        # Instance control node
        if url_target != "":
            # Make a flat Button styled like a link
            var btn := Button.new()
            btn.text = text_content
            btn.flat = true
            btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
            btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
            btn.add_theme_font_size_override("font_size", font_size)
            btn.add_theme_font_override("font", current_font)

            # Link style colour overrides
            btn.add_theme_color_override("font_color", Color(0.3, 0.6, 0.9))
            btn.add_theme_color_override("font_hover_color", Color(0.5, 0.8, 1.0))
            btn.add_theme_color_override("font_pressed_color", Color(0.2, 0.4, 0.7))
            btn.add_theme_color_override("font_focus_color", Color(0.5, 0.8, 1.0))

            btn.pressed.connect(OS.shell_open.bind(url_target))
            v_box_container.add_child(btn)
        else:
            # Make a standard Label
            var label := Label.new()
            label.text = text_content
            label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
            label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            label.add_theme_font_size_override("font_size", font_size)
            label.add_theme_font_override("font", current_font)

            v_box_container.add_child(label)


func _on_back_button_pressed() -> void:
    closed.emit()
