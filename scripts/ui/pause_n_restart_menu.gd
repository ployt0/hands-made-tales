class_name PauseNRestartMenu extends CanvasLayer

@onready var credits_scene: Control = $CreditsScene
@onready var settings_v_box: Settings = $SettingsVBox
@onready var pause_menu_v_box: VBoxContainer = $PanelContainer/PauseMenuVBox
@onready var resume_button: Button = $PanelContainer/PauseMenuVBox/ResumeButton
@onready var settings_button: Button = $PanelContainer/PauseMenuVBox/SettingsButton
@onready var credits_button: Button = $PanelContainer/PauseMenuVBox/CreditsButton

func pause_in():
    pass

func pause_out():
    pass

func _ready() -> void:
    resume_button.grab_focus()

func _input(event: InputEvent) -> void:
    # If UI cancel is pressed, figure out what to close
    if event.is_action_pressed("ui_cancel"):
        if settings_v_box.visible:
            _on_settings_back_button_pressed()
        elif credits_scene.visible:
            _on_credits_scene_closed()
        else:
            _on_resume_button_pressed()

func _on_resume_button_pressed() -> void:
    await pause_out()  # waits until transition done
    get_tree().paused = false
    queue_free()  # remove this menu

func _on_settings_button_pressed() -> void:
    pause_menu_v_box.visible = false
    settings_v_box.visible = true

func _on_settings_back_button_pressed() -> void:
    pause_menu_v_box.visible = true
    if settings_v_box.visible:
        settings_v_box.visible = false
        settings_button.grab_focus()

func _on_credits_button_pressed() -> void:
    pause_menu_v_box.visible = false
    credits_scene.visible = true

func _on_credits_scene_closed() -> void:
    credits_scene.visible = false
    pause_menu_v_box.visible = true
    credits_button.grab_focus()


@onready var modal_confirm_dialog: CenterContainer = $ModalConfirmDialog


func _on_cancel_button_pressed() -> void:
    modal_confirm_dialog.visible = false


func _on_restart_button_pressed() -> void:
    get_tree().paused = false
    get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_restart_pressed() -> void:
    modal_confirm_dialog.visible = true
