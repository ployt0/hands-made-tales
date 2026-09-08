class_name Game
extends Control

const CONTENTS_SCENE := preload("res://scenes/game_content.tscn")

const MATCHES_PER_TIER: int = 1 # 2 matches per tier: (2 opps) -> (3 opps) -> (4 opps) -> Boss
const MAX_MATCHES: int = (MATCHES_PER_TIER * 3) + 1 

const ANTE_INCREASE_INTERVAL_SECS: int = 300 
const ANTE_GROWTH_MULTIPLIER: float = 1.33   ## +33% increase per interval

enum GameStage { PREFLOP, FLOP, TURN, RIVER, SHOWDOWN }
const STAGE_LABELS := ["Preflop", "Flop", "Turn", "River", "Showdown"]


var current_match_idx: int = 1

var match_simulated_seconds: int = 0
var last_escalation_tier: int = 0

var real_time_accumulator: float = 0.0
var pause_menu: CanvasLayer

var total_hands_dealt: int = 0
var hands_won_count: int = 0
var hands_lost_count: int = 0
var total_chips_won: int = 0
var simulated_seconds: int = 0

var seats: Array[SeatData] = []
var deck: Array[Card] = []
var community_cards: Array[Card] = []
var pot: int = 0
var current_highest_bet: int = 0
var min_raise: int
var base_ante: int = 20
var current_ante: int
var dealer_idx: int = 0
var current_turn_idx: int = 0
var total_real_time_secs: float = 0.0
var stage: GameStage = GameStage.PREFLOP
var is_game_over: bool = false

var player_tracker: PlayerTracker = PlayerTracker.new()
var lb_default_pos: Vector2
var lb_default_size: Vector2

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var ui_root: CanvasLayer = $UIRoot
@onready var game_content: GameContent = $UIRoot/GameContent
@onready var btn_fold: Button = game_content.fold_btn
@onready var btn_call: Button = game_content.call_btn
@onready var btn_raise: Button = game_content.raise_btn
@onready var btn_next_hand: Button = game_content.deal_next_btn
@onready var btn_next_match: Button = game_content.next_match_btn
@onready var raise_slider: HSlider = game_content.raise_slider
@onready var raise_label: Label = game_content.raise_label
@onready var pot_center_label: Label = game_content.pot_label
@onready var match_info_label: Label = game_content.match_num_label
@onready var clock_label: Label = game_content.clock_label
@onready var stage_label: Label = game_content.stage_label

@onready var action_bar: HBoxContainer = game_content.actions_h_box

@onready var leaderboard: Leaderboard = $Leaderboard
@onready var sfx: SFXPlayer = $SFXPlayer


func _ready() -> void:
    _start_tournament_match(current_match_idx)
    game_content.call_pressed.connect(_on_call_pressed)
    game_content.fold_pressed.connect(_on_fold_pressed)
    game_content.raise_pressed.connect(_on_raise_pressed)
    game_content.deal_pressed.connect(_start_new_hand)
    game_content.next_pressed.connect(func(): _start_tournament_match(current_match_idx + 1))
    game_content.raise_slider_changed.connect(_on_raise_slider_changed)
    lb_default_pos = leaderboard.panel_container.position
    lb_default_size = leaderboard.panel_container.size
    leaderboard.populate_lb()


func _input(_ev: InputEvent) -> void:
    if _ev.is_action_pressed("ui_cancel"):
        _toggle_pause_menu()


func _process(delta: float) -> void:
    if stage != GameStage.SHOWDOWN and !is_game_over:
        total_real_time_secs += delta
        real_time_accumulator += delta
        if real_time_accumulator >= 1.0:
            var whole_seconds = int(real_time_accumulator)
            real_time_accumulator -= whole_seconds
            _add_simulated_time(whole_seconds)


func _update_clock_ui() -> void:
    var mins = match_simulated_seconds / 60
    var secs = match_simulated_seconds % 60
    clock_label.text = "Match Clock: %02d:%02d" % [mins, secs]

func _start_tournament_match(match_num: int) -> void:
    current_match_idx = match_num
    btn_next_match.visible = false

    match_simulated_seconds = 0
    last_escalation_tier = 0
    _update_clock_ui()

    var is_free_play = (match_num > MAX_MATCHES)
    var opponent_count = 2
    var has_boss = false

    if is_free_play:
        opponent_count = 3
        has_boss = true
    elif match_num <= MATCHES_PER_TIER:
        opponent_count = 2
    elif match_num <= MATCHES_PER_TIER * 2:
        opponent_count = 3
    elif match_num <= MATCHES_PER_TIER * 3:
        opponent_count = 4
    else:
        opponent_count = 3
        has_boss = true

    current_ante = base_ante + (mini(match_num, MAX_MATCHES) - 1) * 10
    min_raise = maxi(20, current_ante * 2)

    var mode_title = "Match %d / %d" % [match_num, MAX_MATCHES] if !is_free_play else "Career Match  %d" % match_num
    match_info_label.text = "%s  |  Table Ante: $%d" % [mode_title, current_ante]

    _init_seats_for_match(opponent_count, has_boss, is_free_play)
    _start_new_hand()


func _init_seats_for_match(opp_count: int, has_boss: bool, is_free_play: bool) -> void:
    for s in seats:
        if is_instance_valid(s.ui):
            s.ui.queue_free()
    seats.clear()

    seats.append(SeatData.make_human())

    var base_pool: Array[PokerAIProfile.Archetype] = [
        PokerAIProfile.Archetype.ROCK,
        PokerAIProfile.Archetype.CALLING_STATION,
        PokerAIProfile.Archetype.MANIAC,
        PokerAIProfile.Archetype.TRAPPER,
        PokerAIProfile.Archetype.BLUFFER,
        PokerAIProfile.Archetype.GAMBLER
    ]
    if is_free_play:
        base_pool.append(PokerAIProfile.Archetype.CHAMELEON)

    var needed_regular = (opp_count - 1) if has_boss else opp_count
    var chosen_archetypes = PokerAIProfile.pick_weighted_archetypes(needed_regular, base_pool)
    if has_boss:
        chosen_archetypes.append(PokerAIProfile.Archetype.CHAMELEON)

    var opponents = CardVisuals.get_random_opponents(opp_count)

    for i in range(opp_count):
        seats.append(SeatData.make_bot(i, chosen_archetypes[i], current_match_idx, opponents[i]))

    _attach_seat_ui()


func _card_to_str(c: Card) -> String:
    var r = CardEvaluator.RANK_NAMES.get(c.rank, str(c.rank))
    var suits = ["♣", "♦", "♥", "♠"]
    return "%s%s" % [r, suits[c.suit]]

func _start_new_hand() -> void:
    btn_next_hand.visible = false
    pot = 0
    current_highest_bet = 0
    community_cards.clear()
    stage = GameStage.PREFLOP
    total_hands_dealt += 1
    _add_simulated_time(45)
    _reset_deck()

    game_content.clear_community_cards()
    for s in seats:
        s.blank_cards()
        s.update_cards()

    for s in seats:
        s.reset_hand()
        if not s.folded:
            for i in range(2):
                s.hole_cards.append(_draw_card())
                if s.is_human:
                    sfx.play(sfx.draw_sfx.pick_random(), sfx.get_rand_db(rng), 2 ** rng.randfn(0, 0.15))
                    await get_tree().create_timer(0.2).timeout
                    game_content.update_community_card_visuals(community_cards)
                    s.ui.card_rects[i].texture = CardVisuals.get_card_texture(s.hole_cards[i].rank, s.hole_cards[i].suit)
                    if s.hole_cards[-1].rank == 14 and s.hole_cards[-1].suit == 3:
                        sfx.play(sfx.NEED_IS_ACE_OF_SPADES, linear_to_db(clamp(rng.randfn(0.75, 0.1), 0.6, 0.95)), 2 ** rng.randfn(0, 0.15))
            if Constants.IS_DEV and not s.is_human:
                print("[DEBUG AI - HAND #%d] %s (%s) holds: [%s, %s]" % [
                    total_hands_dealt,
                    s.name,
                    PokerAIProfile.Archetype.keys()[s.profile.archetype],
                    _card_to_str(s.hole_cards[0]),
                    _card_to_str(s.hole_cards[1]),
                ])
            _place_bet(s, mini(current_ante, s.chips))
        s.update_cards()

    dealer_idx = (dealer_idx + 1) % seats.size()
    current_highest_bet = current_ante
    Utils.log(game_content, "[color=yellow]--- Hand #%d Dealt (Ante $%d) ---[/color]" % [total_hands_dealt, current_ante])

    # Action starts immediately to the left of the dealer
    current_turn_idx = (dealer_idx + 1) % seats.size()
    _update_ui()
    _process_turn()

func _reset_deck() -> void:
    deck.clear()
    for suit in range(4):
        for rank in range(2, 15):
            deck.append(Card.new(rank, suit))
    deck.shuffle()

func _draw_card() -> Card:
    return deck.pop_back()

func _process_turn() -> void:
    if _count_active_players() <= 1:
        _end_hand_early()
        return

    if _is_street_complete():
        _advance_street()
        return

    var seat = seats[current_turn_idx]
    if seat.folded or seat.is_all_in:
        current_turn_idx = (current_turn_idx + 1) % seats.size()
        _process_turn()
        return

    if seat.is_human:
        _enable_player_controls()
    else:
        action_bar.visible = false

        # Thinking time calculation: 2 to 10s base; careful/calculating players (low bluffiness) take up to 150% longer (up to 25s)
        var max_think: float = 10.0
        if seat.profile:
            var calculation_factor = 1.0 + (1.0 - (seat.profile.bluffiness / 100.0)) * 1.5
            max_think = 10.0 * calculation_factor

        var sim_think = int(randf_range(2.0, max_think))
        _add_simulated_time(sim_think)

        await get_tree().create_timer(sim_think / 20).timeout
        _run_npc_turn(seat, sim_think)

func _is_street_complete() -> bool:
    var active = seats.filter(func(s): return !s.folded and !s.is_all_in)
    if active.is_empty():
        return true
    for s in active:
        if not s.acted_this_street or s.current_bet != current_highest_bet:
            return false
    return true

func _advance_street() -> void:
    for s in seats:
        s.current_bet = 0
        s.acted_this_street = false
        s.ui.current_bet_label.text = ""
        s.ui.action_label.text = ""
    current_highest_bet = 0

    match stage:
        GameStage.PREFLOP:
            stage = GameStage.FLOP
            for _i in range(3):
                community_cards.append(_draw_card())
                sfx.play(sfx.draw_sfx.pick_random(), sfx.get_rand_db(rng), 2 ** rng.randfn(0, 0.15))
                await get_tree().create_timer(0.2).timeout
                game_content.update_community_card_visuals(community_cards)
            Utils.log(game_content, "[color=cyan]*** Flop: 3 cards dealt ***[/color]")
        GameStage.FLOP:
            stage = GameStage.TURN
            community_cards.append(_draw_card())
            sfx.play(sfx.draw_sfx.pick_random(), sfx.get_rand_db(rng), 2 ** rng.randfn(0, 0.15))
            Utils.log(game_content, "[color=cyan]*** Turn: 4th card dealt ***[/color]")
        GameStage.TURN:
            stage = GameStage.RIVER
            community_cards.append(_draw_card())
            sfx.play(sfx.draw_sfx.pick_random(), sfx.get_rand_db(rng), 2 ** rng.randfn(0, 0.15))
            Utils.log(game_content, "[color=cyan]*** River: Final card dealt ***[/color]")
        GameStage.RIVER:
            stage = GameStage.SHOWDOWN
            _handle_showdown()
            return

    game_content.update_community_card_visuals(community_cards)
    current_turn_idx = (dealer_idx + 1) % seats.size()
    _update_ui()
    _process_turn()

func _place_bet(seat: SeatData, amount: int) -> int:
    var actual = mini(amount, seat.chips)
    if actual <= 0:
        return 0

    seat.chips -= actual
    seat.current_bet += actual
    seat.total_hand_contribution += actual
    pot += actual
    if seat.chips == 0:
        seat.is_all_in = true
    if seat.current_bet > current_highest_bet:
        current_highest_bet = seat.current_bet
        for s in seats:
            if !s.folded and !s.is_all_in and s != seat:
                s.acted_this_street = false
    seat.ui.current_bet_label.text = "Bet: $%d" % seat.current_bet if seat.current_bet > 0 else ""

    var chip_holder: Control = ChipStackDisplay.create_chip_holder(seat, actual, pot_center_label, rng)
    game_content.add_child(chip_holder)
    ChipStackDisplay.animate_chip_bet(chip_holder, pot_center_label)
    sfx.play_chip_raise(actual, rng)

    return actual


func _run_npc_turn(seat: SeatData, seconds_spent: int) -> void:
    seat.acted_this_street = true
    var to_call = current_highest_bet - seat.current_bet
    if seat.profile.archetype == PokerAIProfile.Archetype.CHAMELEON:
        seat.profile.adapt_to_player(player_tracker)

    var decision = PokerAIDecision.decide_action(
        seat.profile,
        seat.hole_cards,
        community_cards,
        to_call,
        min_raise,
        seat.chips,
        pot
    )

    if not decision.dialogue.is_empty():
        seat.ui.speech_label.text = '"' + decision.dialogue + '"'

    match decision.action:
        PokerAIDecision.Action.FOLD:
            seat.folded = true
            seat.ui.action_label.text = "FOLD"
            Utils.log(game_content, "%s folds (in %ds)." % [seat.name, seconds_spent])
        PokerAIDecision.Action.CHECK:
            seat.ui.action_label.text = "CHECK"
            Utils.log(game_content, "%s checks (in %ds)." % [seat.name, seconds_spent])
        PokerAIDecision.Action.CALL:
            _place_bet(seat, to_call)
            seat.ui.action_label.text = "CALL $%d" % [to_call]
            Utils.log(game_content, "%s calls $%d (in %ds)." % [seat.name, to_call, seconds_spent])
        PokerAIDecision.Action.RAISE:
            var raise_total = to_call + decision.raise_amount
            _place_bet(seat, raise_total)
            seat.ui.action_label.text = "RAISE to $%d" % [seat.current_bet]
            Utils.log(game_content, "%s raises to $%d (in %ds)." % [seat.name, seat.current_bet, seconds_spent])

    seat.update_cards()
    current_turn_idx = (current_turn_idx + 1) % seats.size()
    _update_ui()
    _process_turn()

func _enable_player_controls() -> void:
    action_bar.visible = true
    var p = seats[0]
    var to_call = current_highest_bet - p.current_bet

    if to_call == 0:
        btn_call.text = "Check"
        btn_call.disabled = false
    elif to_call >= p.chips:
        btn_call.text = "All-In ($%d)" % p.chips
        btn_call.disabled = false
    else:
        btn_call.text = "Call $%d" % to_call
        btn_call.disabled = false

    var max_raise_add = p.chips - to_call
    raise_slider.min_value = min_raise
    raise_slider.max_value = maxi(min_raise, max_raise_add)
    raise_slider.value = min_raise
    raise_slider.editable = (max_raise_add >= min_raise)
    btn_raise.disabled = !raise_slider.editable
    _on_raise_slider_changed(raise_slider.value)

func _on_fold_pressed() -> void:
    seats[0].fold()
    player_tracker.record_fold()
    hands_lost_count += 1
    Utils.log(game_content, "[color=red]You fold.[/color]")
    _finish_human_action()

func _on_call_pressed() -> void:
    var p = seats[0]
    p.acted_this_street = true
    var to_call = current_highest_bet - p.current_bet
    if to_call > 0:
        _place_bet(p, to_call)
        p.ui.action_label.text = "CALL $%d" % to_call
        player_tracker.record_call()
        Utils.log(game_content, "You call $%d." % to_call)
    else:
        p.ui.action_label.text = "CHECK"
        Utils.log(game_content, "You check.")
    _finish_human_action()

func _on_raise_pressed() -> void:
    var p = seats[0]
    p.acted_this_street = true
    var to_call = current_highest_bet - p.current_bet
    var raise_add = int(raise_slider.value)
    _place_bet(p, to_call + raise_add)
    p.ui.action_label.text = "RAISE to $%d" % p.current_bet
    player_tracker.record_raise()
    Utils.log(game_content, "You raise to $%d (added $%d)." % [p.current_bet, raise_add])
    _finish_human_action()

func _on_raise_slider_changed(val: float) -> void:
    var p = seats[0]
    var to_call = current_highest_bet - p.current_bet
    var total_target = p.current_bet + to_call + int(val)
    raise_label.text = "$%d" % int(val)
    btn_raise.text = "Raise to $%d" % total_target

func _finish_human_action() -> void:
    action_bar.visible = false
    current_turn_idx = (current_turn_idx + 1) % seats.size()
    _update_ui()
    _process_turn()

func _handle_showdown() -> void:
    Utils.log(game_content, "[color=gold]--- Showdown! ---[/color]")

    for s in seats:
        if s.folded:
            continue
        s.reveal_cards()
        var hand_info = CardEvaluator.evaluate_hand_info(s.hole_cards, community_cards)
        s.ui.speech_label.text = hand_info.description
        Utils.log(game_content, "%s reveals: [b]%s[/b]" % [s.name, hand_info.description])
    _distribute_pots_with_side_pots()

func _end_hand_early() -> void:
    var remaining = seats.filter(func(s): return !s.folded)
    if remaining.size() == 1:
        var w = remaining[0]
        w.chips += pot
        Utils.log(game_content, "[b][color=green]%s wins $%d (All others folded)![/color][/b]" % [w.name, pot])
        if w.is_human:
            hands_won_count += 1
            total_chips_won += pot
            sfx.chip_sweep(rng)
        else:
            hands_lost_count += 1
        pot = 0
        _update_ui()
        _check_match_status()

func _distribute_pots_with_side_pots() -> void:
    var active_contenders = seats.filter(func(s): return !s.folded)
    if active_contenders.is_empty():
        pot = 0
        return

    # Collect all-in contribution cutoffs from active players
    var caps: Array[int] = []
    for s in active_contenders:
        if s.is_all_in and not caps.has(s.total_hand_contribution):
            caps.append(s.total_hand_contribution)
    caps.sort()

    # If no active player is all-in, the entire pot goes to the best hand in one shot
    if caps.is_empty():
        var best_score = -1.0
        var winners: Array[SeatData] = []
        for p in active_contenders:
            var sc = CardEvaluator.evaluate_strength(p.hole_cards, community_cards)
            if sc > best_score:
                best_score = sc
                winners = [p]
            elif is_equal_approx(sc, best_score):
                winners.append(p)

        var share = pot / maxi(1, winners.size())
        var names: Array[String] = []
        for w in winners:
            w.chips += share
            names.append(w.name)
            if w.is_human:
                hands_won_count += 1
                total_chips_won += share
                sfx.chip_sweep(rng)

        var w_str = ", ".join(names)
        Utils.log(game_content, "[b][color=green]%s wins the pot of $%d![/color][/b]" % [w_str, pot])
        pot = 0
        _update_ui()
        _check_match_status()
        return

    # Multi-tiered side pot resolution (when 1+ active players are all-in)
    var prev_cap = 0
    for cap in caps:
        var pot_slice = 0
        var eligible: Array[SeatData] = []

        for s in seats:
            var contrib = s.total_hand_contribution
            if contrib > prev_cap:
                pot_slice += mini(contrib - prev_cap, cap - prev_cap)
                if !s.folded and contrib >= cap:
                    eligible.append(s)

        prev_cap = cap
        if eligible.is_empty() or pot_slice == 0:
            continue

        var best_sc = -1.0
        var slice_winners: Array[SeatData] = []
        for p in eligible:
            var sc = CardEvaluator.evaluate_strength(p.hole_cards, community_cards)
            if sc > best_sc:
                best_sc = sc
                slice_winners = [p]
            elif is_equal_approx(sc, best_sc):
                slice_winners.append(p)

        var slice_share = pot_slice / maxi(1, slice_winners.size())
        var w_names: Array[String] = []
        for sw in slice_winners:
            sw.chips += slice_share
            w_names.append(sw.name)
            if sw.is_human:
                hands_won_count += 1
                total_chips_won += slice_share
                sfx.chip_sweep(rng)

        Utils.log(game_content, "[b][color=green]%s wins side pot of $%d![/color][/b]" % [", ".join(w_names), pot_slice])

    # Remaining excess above the highest all-in cap
    var leftover_pot = 0
    var final_eligible: Array[SeatData] = []
    for s in seats:
        if s.total_hand_contribution > prev_cap:
            leftover_pot += (s.total_hand_contribution - prev_cap)
            if !s.folded:
                final_eligible.append(s)

    if leftover_pot > 0 and !final_eligible.is_empty():
        var best_sc = -1.0
        var rem_winners: Array[SeatData] = []
        for p in final_eligible:
            var sc = CardEvaluator.evaluate_strength(p.hole_cards, community_cards)
            if sc > best_sc:
                best_sc = sc
                rem_winners = [p]
            elif is_equal_approx(sc, best_sc):
                rem_winners.append(p)

        var rem_share = leftover_pot / maxi(1, rem_winners.size())
        var rem_names: Array[String] = []
        for rw in rem_winners:
            rw.chips += rem_share
            rem_names.append(rw.name)
            if rw.is_human:
                hands_won_count += 1
                total_chips_won += rem_share
                sfx.chip_sweep(rng)
        Utils.log(game_content, "[b][color=green]%s wins main pot share of $%d![/color][/b]" % [", ".join(rem_names), leftover_pot])

    pot = 0
    _update_ui()
    _check_match_status()

func _check_match_status() -> void:
    var human = seats[0]
    if human.chips <= 0:
        _show_game_over(false)
        return

    var opponents_alive = seats.filter(func(s): return !s.is_human and s.chips > 0)
    if opponents_alive.is_empty():
        Utils.log(game_content, "[b][color=gold]MATCH %d CLEARED! ALL OPPONENTS BUSTED![/color][/b]" % current_match_idx)
        if current_match_idx == MAX_MATCHES:
            _show_game_over(true)
        else:
            btn_next_match.visible = true
    else:
        btn_next_hand.visible = true

func _add_simulated_time(sec: int) -> void:
    simulated_seconds += sec
    match_simulated_seconds += sec
    _update_clock_ui()

    var current_tier = match_simulated_seconds / ANTE_INCREASE_INTERVAL_SECS
    if current_tier > last_escalation_tier:
        last_escalation_tier = current_tier
        var old_ante = current_ante
        current_ante = int(current_ante * ANTE_GROWTH_MULTIPLIER)
        min_raise = maxi(20, current_ante * 2)

        Utils.log(game_content, ">>> TIME LEVEL UP! Ante increased from $%d to $%d! <<<" % [old_ante, current_ante], Color.ORANGE)

        _play_ante_up_juice(old_ante, current_ante)

func _play_ante_up_juice(old_ante: int, new_ante: int) -> void:
    var is_free_play = (current_match_idx > MAX_MATCHES)
    var mode_title = "Match %d / %d" % [current_match_idx, MAX_MATCHES] if !is_free_play else "Career Match %d" % current_match_idx
    match_info_label.text = "%s  |  Table Ante: $%d" % [mode_title, new_ante]

    var label_tween = create_tween().set_parallel(true)
    label_tween.tween_property(match_info_label, "modulate", Color(1.0, 0.8, 0.2), 0.1)
    label_tween.chain().tween_property(match_info_label, "modulate", Color.WHITE, 0.4)

    var banner = Label.new()
    banner.text = "ANTE UP!\n$%d  ->  $%d" % [old_ante, new_ante]
    banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    # Render on top of chips and all table elements
    banner.z_index = 1
    banner.mouse_filter = Control.MOUSE_FILTER_IGNORE

    banner.add_theme_font_size_override("font_size", 42)
    banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
    banner.add_theme_color_override("font_outline_color", Color.BLACK)
    banner.add_theme_constant_override("outline_size", 12)

    # Position in center of table
    banner.size = Vector2(500, 120)
    banner.pivot_offset = banner.size * 0.5
    banner.position = Vector2(
        (Constants.SCREEN_SIZE.x - banner.size.x) * 0.5,
        (Constants.SCREEN_SIZE.y * 0.4) - banner.pivot_offset.y
    )  # Community cards and pot are at y = 0.4 height. 
    banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    game_content.add_child(banner)

    banner.scale = Vector2(0.3, 0.3)
    banner.modulate.a = 0.0

    # Pop-in with spring/overshoot, hold, then float up and fade
    var pop_tween = create_tween()
    pop_tween.set_parallel(true)
    pop_tween.tween_property(banner, "scale", Vector2(1.2, 1.2), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    pop_tween.tween_property(banner, "modulate:a", 1.0, 0.15)

    # Settle
    pop_tween.chain().tween_property(banner, "scale", Vector2(1.0, 1.0), 0.1)

    #Hold, then float fade out
    pop_tween.chain().tween_interval(1.0)
    pop_tween.chain().set_parallel(true)
    pop_tween.tween_property(banner, "position:y", banner.position.y - 50.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    pop_tween.tween_property(banner, "scale", Vector2(1.15, 1.15), 0.6)
    pop_tween.tween_property(banner, "modulate:a", 0.0, 0.6)

    pop_tween.chain().tween_callback(banner.queue_free)

    # Placeholder for triumphant SFX
    # sfx.play(sfx.LEVEL_UP_SFX)

func _show_game_over(victory: bool) -> void:
    is_game_over = true
    action_bar.visible = false
    btn_next_hand.visible = false
    btn_next_match.visible = false

    var final_matches = current_match_idx if !victory else MAX_MATCHES
    leaderboard.expand()

    var stats_data = {
        "matches_completed": final_matches,
        "hands_dealt": total_hands_dealt,
        "hands_won": hands_won_count,
        "hands_lost": hands_lost_count,
        "chips_won": total_chips_won,
        "sim_time_secs": simulated_seconds,
        "real_time_secs": total_real_time_secs
    }

    var overlay: ResultScreen = load("res://scenes/result_screen.tscn").instantiate()
    add_child(overlay)
    overlay.setup(stats_data, victory)

    overlay.restart_requested.connect(func():
        overlay.queue_free()
        is_game_over = false
        leaderboard.reset_hud_view(lb_default_pos, lb_default_size)
        _on_restart_pressed()
        update_music(false)
    )

    overlay.continue_requested.connect(func():
        overlay.queue_free()
        is_game_over = false
        leaderboard.reset_hud_view(lb_default_pos, lb_default_size)
        _start_tournament_match(current_match_idx + 1)
        update_music(true)
    )

    overlay.leaderboard_updated.connect(leaderboard.populate_lb)


func _on_restart_pressed() -> void:
    current_match_idx = 1
    total_hands_dealt = 0
    hands_won_count = 0
    hands_lost_count = 0
    total_chips_won = 0
    simulated_seconds = 0
    match_simulated_seconds = 0
    last_escalation_tier = 0
    _start_tournament_match(1)

func _count_active_players() -> int:
    return seats.filter(func(s): return !s.folded).size()

func _draw() -> void:
    # Table Border
    draw_circle(Vector2(500, 420), 280, Color(0.18, 0.1, 0.05))
    draw_circle(Vector2(1100, 420), 280, Color(0.18, 0.1, 0.05))
    draw_rect(Rect2(500, 140, 600, 560), Color(0.18, 0.1, 0.05))

    # Green Poker Felt
    draw_circle(Vector2(500, 420), 260, Color(0.12, 0.35, 0.18))
    draw_circle(Vector2(1100, 420), 260, Color(0.12, 0.35, 0.18))
    draw_rect(Rect2(500, 160, 600, 520), Color(0.12, 0.35, 0.18))


func _attach_seat_ui() -> void:
    var pos_map: Dictionary[int, PackedVector2Array] = {
        3: [
            Vector2(700, 560), # Human (Bottom Center)
            Vector2(320, 40),  # Opponent 1 (Top Left)
            Vector2(1080, 40)  # Opponent 2 (Top Right)
        ],
        4: [
            Vector2(700, 560), # Human (Bottom Center)
            Vector2(200, 140), # Opponent 1 (Left Wing)
            Vector2(700, 10),  # Opponent 2 (Top Center)
            Vector2(1260, 140) # Opponent 3 (Right Wing)
        ],
        5: [
            Vector2(700, 560), # Human (Bottom Center)
            Vector2(160, 220), # Opponent 1 (Mid Left)
            Vector2(420, 10),  # Opponent 2 (Top Left Center)
            Vector2(980, 10),  # Opponent 3 (Top Right Center)
            Vector2(1280, 220) # Opponent 4 (Mid Right)
        ]
    }

    var positions: PackedVector2Array = pos_map.get(seats.size(), pos_map[3])

    for i in range(seats.size()):
        seats[i].create_ui(positions[i], game_content)


func _update_ui() -> void:
    pot_center_label.text = "POT: $%d" % pot
    stage_label.text = "Stage: " + STAGE_LABELS[stage]
    for s in seats:
        s.ui.chips_label.text = "Chips: $%d" % s.chips
        s.ui.modulate = Color(0.5, 0.5, 0.5, 0.5) if s.folded else Color.WHITE

func _toggle_pause_menu() -> void:
    if pause_menu and pause_menu.is_inside_tree():
        dispose_unpaused_menu()
    else:
        if ResourceLoader.exists("res://scenes/pause_n_restart_menu.tscn"):
            pause_menu = preload("res://scenes/pause_n_restart_menu.tscn").instantiate()
            get_tree().current_scene.add_child(pause_menu)
            #get_tree().paused = true
            if pause_menu.has_method("pause_in"):
                pause_menu.pause_in()

func dispose_unpaused_menu() -> void:
    #get_tree().paused = false
    if pause_menu:
        pause_menu.queue_free()
        pause_menu = null

var current_music_track: String = MusicStreamPlayer.stream.get_clip_name(MusicStreamPlayer.stream.initial_clip)

func update_music(is_free_play: bool) -> void:
    var target_track = "Best Jazz Club In New Orleans" if is_free_play else "Poker Player"
    if current_music_track != target_track:
        current_music_track = target_track
        MusicStreamPlayer.set("parameters/switch_to_clip", target_track)
