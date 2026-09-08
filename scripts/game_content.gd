class_name GameContent
extends Control

signal call_pressed
signal fold_pressed
signal raise_pressed
signal deal_pressed
signal next_pressed
signal raise_slider_changed(val: float)

var comm_card_rects: Array[TextureRect] = []
var comm_card_panels: Array[Panel] = []


@onready var fold_btn: Button = $ActionsHBox/FoldBtn
@onready var call_btn: Button = $ActionsHBox/CallBtn
@onready var raise_btn: Button = $ActionsHBox/RaiseBtn
@onready var deal_next_btn: Button = $DealNextBtn
@onready var next_match_btn: Button = $NextMatchBtn
@onready var raise_slider: HSlider = $ActionsHBox/RaiseSlider
@onready var raise_label: Label = $ActionsHBox/RaiseLabel
@onready var actions_h_box: HBoxContainer = $ActionsHBox
@onready var log_scroll: ScrollContainer = $LogPanel/LogMargin/LogScroll
@onready var log_vbox: VBoxContainer = $LogPanel/LogMargin/LogScroll/LogVBox
@onready var pot_label: Label = $PotLabel
@onready var match_num_label: Label = $InfoVBox/MatchNumLabel
@onready var clock_label: Label = $InfoVBox/ClockLabel
@onready var stage_label: Label = $InfoVBox/StageLabel

func _ready() -> void:
    fold_btn.pressed.connect(func(): fold_pressed.emit())
    call_btn.pressed.connect(func(): call_pressed.emit())
    raise_slider.value_changed.connect(func(v: float): raise_slider_changed.emit(v))
    raise_btn.pressed.connect(func(): raise_pressed.emit())
    deal_next_btn.pressed.connect(func(): deal_pressed.emit())
    next_match_btn.pressed.connect(func(): next_pressed.emit())
    for i in range(5):
        comm_card_panels.append(get_node("CommunityHBox/CommunityPanel%d" % i))
        comm_card_rects.append(get_node("CommunityHBox/CommunityPanel%d/CommunityTexture%d" % [i, i]))

func clear_community_cards():
    for i in range(5):
        comm_card_rects[i].texture = null
        comm_card_panels[i].visible = true

func update_community_card_visuals(community_cards: Array[Card]) -> void:
    for i in range(5):
        if i < community_cards.size():
            var c = community_cards[i]
            comm_card_rects[i].texture = CardVisuals.get_card_texture(c.rank, c.suit)
            comm_card_panels[i].modulate = Color.WHITE
        else:
            comm_card_rects[i].texture = null
            comm_card_panels[i].modulate = Color(0.1, 0.1, 0.1, 0.4)
