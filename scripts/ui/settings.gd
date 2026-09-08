class_name Settings
extends PanelContainer

signal back_pressed

@onready var sfxvol: HSlider = $SettingsHBox/MarginContainer/VBoxContainer/VolumeVBox/SFXVol
@onready var music_vol: HSlider = $SettingsHBox/MarginContainer/VBoxContainer/VolumeVBox/MusicVol
@onready var main_vol: HSlider = $SettingsHBox/MarginContainer/VBoxContainer/VolumeVBox/MainVol
@onready var back_button: Button = $SettingsHBox/MarginContainer/VBoxContainer/BackButton
@onready var full_screen_chk: CheckBox = $SettingsHBox/MarginContainer/VBoxContainer/FullScreenChk

func _ready() -> void:
    back_button.pressed.connect(_on_back_button_pressed)
    main_vol.value = AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Master"))
    main_vol.value_changed.connect(_on_main_vol_value_changed)
    music_vol.value = AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music"))
    music_vol.value_changed.connect(_on_music_vol_value_changed)
    sfxvol.value = AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("SFX"))
    sfxvol.value_changed.connect(_on_sfx_vol_value_changed)


func _on_back_button_pressed() -> void:
    back_pressed.emit()

func _input(ev: InputEvent):
    if ev.is_action_pressed("ui_cancel"):
        back_pressed.emit()
        get_viewport().set_input_as_handled()



func _on_main_vol_value_changed(value: float) -> void:
    AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), value)
    UserSettings.volume_master = value
    UserSettings.apply()
    UserSettings.save_settings()


func _on_music_vol_value_changed(value: float) -> void:
    AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Music"), value)
    UserSettings.volume_music = value
    UserSettings.apply()
    UserSettings.save_settings()


func _on_sfx_vol_value_changed(value: float) -> void:
    AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("SFX"), value)
    UserSettings.volume_sfx = value
    UserSettings.apply()
    UserSettings.save_settings()
