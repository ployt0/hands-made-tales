extends GutTest

# Convenience helper to create Card instances
func _c(rank: int, suit: int) -> Card:
    var card = Card.new()
    card.rank = rank
    card.suit = suit
    return card


func test_preflop_pocket_pair_beats_ace_king():
    var pocket_twos: Array[Card] = [_c(2, 0), _c(2, 1)]
    var big_slick: Array[Card] = [_c(14, 2), _c(13, 3)]

    var res_twos = CardEvaluator.evaluate_hand_info(pocket_twos, [])
    var res_ak = CardEvaluator.evaluate_hand_info(big_slick, [])

    assert_eq(res_twos.rank, CardEvaluator.HandRank.ONE_PAIR)
    assert_eq(res_ak.rank, CardEvaluator.HandRank.HIGH_CARD)
    assert_gt(res_twos.score, res_ak.score, "Pocket pair must beat unpaired high cards pre-flop")


func test_preflop_higher_pocket_pair_wins():
    var kings: Array[Card] = [_c(13, 0), _c(13, 1)]
    var queens: Array[Card] = [_c(12, 0), _c(12, 1)]

    assert_gt(
        CardEvaluator.evaluate_strength(kings, []),
        CardEvaluator.evaluate_strength(queens, []),
		"Pocket Kings should beat Pocket Queens"
    )



func test_wheel_straight_is_five_high():
    # A-2-3-4-5 straight (Ace plays low)
    var hole: Array[Card] = [_c(14, 0), _c(2, 1)]
    var board: Array[Card] = [_c(3, 2), _c(4, 3), _c(5, 0), _c(9, 1), _c(10, 2)]

    var res = CardEvaluator.evaluate_hand_info(hole, board)

    assert_eq(res.rank, CardEvaluator.HandRank.STRAIGHT)
    assert_eq(res.description, "Straight (5-high)", "Wheel straight must be identified as 5-high, not Ace-high")

func test_six_high_straight_beats_wheel():
    # 6-5-4-3-2 should beat A-5-4-3-2
    var board: Array[Card] = [_c(3, 0), _c(4, 1), _c(5, 2), _c(9, 3), _c(10, 0)]
    var six_high_hole: Array[Card] = [_c(6, 1), _c(2, 2)]
    var wheel_hole: Array[Card] = [_c(14, 0), _c(2, 3)]

    var six_score = CardEvaluator.evaluate_strength(six_high_hole, board)
    var wheel_score = CardEvaluator.evaluate_strength(wheel_hole, board)

    assert_gt(six_score, wheel_score, "6-high straight must beat 5-high (Ace-low) straight")

func test_two_pair_tiebreak_uses_kicker():
    # Both players make Aces and Tens, but player 1 has a King kicker vs Queen kicker
    var board: Array[Card] = [_c(14, 0), _c(10, 1), _c(2, 2), _c(4, 3), _c(6, 0)]
    var p1_hole: Array[Card] = [_c(14, 1), _c(13, 2)] # A + K
    var p2_hole: Array[Card] = [_c(14, 2), _c(12, 3)] # A + Q

    var p1_score = CardEvaluator.evaluate_strength(p1_hole, board)
    var p2_score = CardEvaluator.evaluate_strength(p2_hole, board)

    assert_gt(p1_score, p2_score, "When two pair matches, highest kicker must break the tie")

func test_full_house_compares_trips_before_pair():
    # Player 1: 4s full of 2s (4-4-4-2-2)
    # Player 2: 3s full of Aces (3-3-3-A-A)
    # Three-of-a-Kind determines the winner, not the pair.
    var board: Array[Card] = [_c(4, 0), _c(3, 0), _c(2, 0), _c(8, 1), _c(9, 2)]
    var p1_hole: Array[Card] = [_c(4, 1), _c(4, 2)] # Trip 4s
    var p2_hole: Array[Card] = [_c(3, 1), _c(3, 2)] # Trip 3s

    # Let's test with complete 5-card hands to be explicit.
    var full_house_fours = [_c(4, 0), _c(4, 1), _c(4, 2), _c(2, 0), _c(2, 1)]
    var full_house_threes = [_c(3, 0), _c(3, 1), _c(3, 2), _c(14, 0), _c(14, 1)]

    var score_fours = CardEvaluator.evaluate_strength(full_house_fours.slice(0, 2), full_house_fours.slice(2))
    var score_threes = CardEvaluator.evaluate_strength(full_house_threes.slice(0, 2), full_house_threes.slice(2))

    assert_gt(score_fours, score_threes, "Three-of-a-kind rank must take priority over the pair in a Full House")

func test_best_five_cards_selected_from_seven():
    # Player has garbage hole cards (2 and 7 offsuit), but board runs out a Royal Flush
    var hole: Array[Card] = [_c(2, 0), _c(7, 1)]
    var royal_board: Array[Card] = [_c(10, 2), _c(11, 2), _c(12, 2), _c(13, 2), _c(14, 2)]

    var res = CardEvaluator.evaluate_hand_info(hole, royal_board)

    assert_eq(res.rank, CardEvaluator.HandRank.STRAIGHT_FLUSH)
    assert_eq(res.description, "Royal Flush", "Evaluator must play the 5 board cards and discard weak hole cards")

func test_flush_beats_straight():
    var flush_cards: Array[Card] = [_c(2, 0), _c(4, 0), _c(7, 0), _c(9, 0), _c(13, 0)]
    var straight_cards: Array[Card] = [_c(9, 1), _c(10, 2), _c(11, 3), _c(12, 0), _c(13, 1)]

    var flush_score = CardEvaluator.evaluate_strength(flush_cards.slice(0, 2), flush_cards.slice(2))
    var straight_score = CardEvaluator.evaluate_strength(straight_cards.slice(0, 2), straight_cards.slice(2))

    assert_gt(flush_score, straight_score, "Flush must rank higher than Straight")
