# class_name UserSettings
extends Node

var volume_master := 1.0
var volume_music := 0.4
var volume_sfx := 0.7

const SETTINGS_PATH := "user://settings.cfg"

func _ready():
    var preferred_language = OS.get_locale_language()
    TranslationServer.set_locale(preferred_language)
    Utils.new().validate_translations()
    load_settings()
    apply()

func apply():
    AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), volume_master)
    AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Music"), volume_music)
    AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("SFX"), volume_sfx)

func save_settings():
    var cfg = ConfigFile.new()
    cfg.set_value("audio", "master", volume_master)
    cfg.set_value("audio", "music", volume_music)
    cfg.set_value("audio", "sfx", volume_sfx)

    cfg.save(SETTINGS_PATH)
    print("Settings saved:", SETTINGS_PATH)

func load_settings():
    var cfg = ConfigFile.new()
    var err = cfg.load(SETTINGS_PATH)
    if err != OK:
        print("Settings: using defaults.")
        return

    volume_master     = cfg.get_value("audio", "master", volume_master)
    volume_music      = cfg.get_value("audio", "music", volume_music)
    volume_sfx        = cfg.get_value("audio", "sfx", volume_sfx)

    print("Settings loaded.")
