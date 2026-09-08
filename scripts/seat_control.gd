class_name SeatControl
extends Control

@onready var portrait_rect: TextureRect = $PortraitRect
@onready var name_label: Label = $NameLabel
@onready var chips_label: Label = $ChipsLabel
@onready var current_bet_label: Label = $CurrentBetLabel
@onready var action_label: Label = $ActionLabel
@onready var speech_label: Label = $SpeechLabel
@onready var card_h_box: HBoxContainer = $CardHBox
@onready var card_rects: Array[TextureRect] = [$CardHBox/CardPanel0/TextureRect, $CardHBox/CardPanel1/TextureRect]
@onready var card_panels: Array[Panel] = [$CardHBox/CardPanel0, $CardHBox/CardPanel1]
