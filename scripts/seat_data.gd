class_name SeatData

const SEAT_SCENE := preload("res://scenes/seat_control.tscn")
const STARTING_CHIPS = 1000

var id: int
var is_human: bool = false
var profile: PokerAIProfile
var portrait_tex: Texture2D
var name: String = ""
var chips: int
var current_bet: int = 0
var total_hand_contribution: int = 0
var hole_cards: Array[Card] = []
var folded: bool = false
var is_all_in: bool = false
var acted_this_street: bool = false
var ui: SeatControl

static func make_human() -> SeatData:
    var human = SeatData.new()
    human.id = 0
    human.is_human = true
    human.name = "You"
    human.chips = STARTING_CHIPS
    return human

static func make_bot(i: int, archetype: PokerAIProfile.Archetype, match_id: int, opponent: Dictionary) -> SeatData:
    var bot = SeatData.new()
    bot.id = i + 1
    bot.is_human = false
    bot.profile = PokerAIProfile.create_profile(archetype, match_id, Game.MAX_MATCHES)
    bot.name = opponent.name
    bot.portrait_tex = opponent.texture
    bot.chips = STARTING_CHIPS
    if Constants.IS_DEV:
        bot.chips = 1
        print("[DEBUG AI - MATCH %d] %s is secretly: %s (Tight: %.1f, Agg: %.1f, Bluff: %.1f)" % [
            match_id, bot.name, PokerAIProfile.Archetype.keys()[bot.profile.archetype],
            bot.profile.tightness, bot.profile.aggression, bot.profile.bluffiness
        ])
    return bot


func fold():
    folded = true
    acted_this_street = true
    ui.action_label.text = "FOLD"


## Displays face if owner is human.
func update_cards() -> void:
    for i in range(hole_cards.size()):
        if is_human:
            ui.card_rects[i].texture = CardVisuals.get_card_texture(hole_cards[i].rank, hole_cards[i].suit)
            ui.card_panels[i].modulate = Color.WHITE
        else:
            ui.card_rects[i].texture = null
            ui.card_panels[i].modulate = Color(0.2, 0.2, 0.2, 0.9) if !folded else Color(0.1, 0.1, 0.1, 0.3)

func blank_cards() -> void:
    for i in range(2):
        ui.card_rects[i].texture = null
        ui.card_panels[i].modulate = Color(0.2, 0.2, 0.2, 0.9) if !folded else Color(0.1, 0.1, 0.1, 0.3)


func reveal_cards() -> void:
    for i in range(hole_cards.size()):
        ui.card_rects[i].texture = CardVisuals.get_card_texture(hole_cards[i].rank, hole_cards[i].suit)
        ui.card_panels[i].modulate = Color.WHITE



func create_ui(spawn_pos: Vector2, parent_container: Control) -> void:
    ui = SEAT_SCENE.instantiate()
    ui.name = name
    ui.position = spawn_pos
    parent_container.add_child(ui)
    ui.portrait_rect.texture = portrait_tex
    ui.name_label.text = name


func reset_hand():
    self.hole_cards.clear()
    self.current_bet = 0
    self.total_hand_contribution = 0
    self.folded = (self.chips <= 0)
    self.is_all_in = false
    self.acted_this_street = false
    self.ui.action_label.text = ""
    self.ui.speech_label.text = ""
    self.ui.current_bet_label.text = ""
