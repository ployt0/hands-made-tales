class_name ResultScreen
extends CanvasLayer

signal restart_requested
signal continue_requested
signal leaderboard_updated

var score
var submitting : bool = false
var invalid_char_regex := RegEx.new()

@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var stats_label: Label = $Panel/Margin/VBox/StatsLabel
@onready var btn_restart: Button = $Panel/Margin/VBox/BtnHBox/BtnRestart
@onready var btn_continue: Button = $Panel/Margin/VBox/BtnHBox/BtnContinue
@onready var username: LineEdit = $Panel/Margin/VBox/BtnHBox/SubmissionVBox/Username
@onready var submit_score_button: Button = $Panel/Margin/VBox/BtnHBox/SubmissionVBox/SubmitScoreButton
@onready var submission_v_box: VBoxContainer = $Panel/Margin/VBox/BtnHBox/SubmissionVBox


func _ready() -> void:
    invalid_char_regex.compile("[^A-Za-z0-9 _-]")
    btn_restart.pressed.connect(func(): restart_requested.emit())
    btn_continue.pressed.connect(func(): continue_requested.emit())

func setup(stats: Dictionary, victory: bool) -> void:
    title_label.text = "TOURNAMENT CHAMPION!" if victory else "YOU WENT BUST!"
    title_label.modulate = Color.GOLD if victory else Color.RED
    btn_continue.visible = victory

    var win_rate: float = (float(stats.hands_won) / float(maxi(1, stats.hands_won + stats.hands_lost))) * 100.0
    var real_m: int = int(stats.real_time_secs) / 60
    var real_s: int = int(stats.real_time_secs) % 60
    var sim_m: int = stats.sim_time_secs / 60
    var sim_s: int = stats.sim_time_secs % 60

    var text = ""
    text += "Matches Won: %d\n" % (stats.matches_completed - 1)
    text += "Hands Dealt: %d\n" % stats.hands_dealt
    text += "Hands Won / Lost: %d / %d\n" % [stats.hands_won, stats.hands_lost]
    text += "Win Ratio: %.1f%%\n" % win_rate
    text += "Total Chips Won: $%d\n" % stats.chips_won
    text += "Simulated Time: %02d:%02d\n" % [sim_m, sim_s]
    text += "Speedrun Real Time: %02d:%02d\n\n" % [real_m, real_s]

    if victory:
        text += "You saw through every liar, rock, and the Chameleon himself!"
    elif stats.matches_completed > Game.MAX_MATCHES:
        text += "A legendary run in the high-stakes underground. Enter your name on the board!"
    else:
        text += "Trust no one at the table. Better luck next time."

    stats_label.text = text
    score = Constants.encode_composite_score(stats.matches_completed - 1, stats.real_time_secs)
    var recordable = stats.matches_completed > 1
    submission_v_box.visible = recordable
    username.editable = recordable
    submit_score_button.disabled = !recordable


func submit_name_score_pair():
    if submitting or username.text.is_empty():
        return

    submitting = true
    username.editable = false
    submit_score_button.disabled = true

    var leaderboards: Leaderboard = preload("res://scenes/leaderboard.tscn").instantiate()
    await Talo.players.identify("username", username.text)
    var res := await Talo.leaderboards.add_entry(Constants.LEADERBOARD_NAME, score)
    assert(is_instance_valid(res))
    leaderboard_updated.emit()

func _on_username_text_submitted(_new_text: String) -> void:
    submit_name_score_pair()

func _on_username_text_changed(new_text: String) -> void:
    var cleaned := invalid_char_regex.sub(new_text, "", true)
    if cleaned != new_text:
        username.text = cleaned
        username.caret_column = cleaned.length()
    var valid := cleaned.length() > 0 and cleaned.length() <= 24
    username.modulate = Color.WHITE if valid else Color(1, 0.6, 0.6)
