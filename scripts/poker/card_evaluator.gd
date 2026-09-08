class_name CardEvaluator
extends RefCounted

enum HandRank {
    HIGH_CARD = 0,
    ONE_PAIR = 1,
    TWO_PAIR = 2,
    THREE_OF_A_KIND = 3,
    STRAIGHT = 4,
    FLUSH = 5,
    FULL_HOUSE = 6,
    FOUR_OF_A_KIND = 7,
    STRAIGHT_FLUSH = 8
}

const RANK_NAMES = {
    2: "2", 3: "3", 4: "4", 5: "5", 6: "6", 7: "7", 8: "8",
    9: "9", 10: "10", 11: "Jack", 12: "Queen", 13: "King", 14: "Ace"
}

const RANK_NAMES_PLURAL = {
    2: "2s", 3: "3s", 4: "4s", 5: "5s", 6: "6s", 7: "7s", 8: "8s",
    9: "9s", 10: "10s", 11: "Jacks", 12: "Queens", 13: "Kings", 14: "Aces"
}

## Returns an exact integer score (higher always wins) and a human-readable description
static func evaluate_hand_info(hole_cards: Array[Card], community_cards: Array[Card]) -> Dictionary:
    var total_cards: Array[Card] = hole_cards + community_cards
    if total_cards.size() < 2:
        return { "score": 0, "description": "Empty Hand", "rank": HandRank.HIGH_CARD }

    # Pre-flop preview
    if community_cards.is_empty():
        var r1 = maxi(hole_cards[0].rank, hole_cards[1].rank)
        var r2 = mini(hole_cards[0].rank, hole_cards[1].rank)
        var pair = (r1 == r2)
        var score = (HandRank.ONE_PAIR << 20 | r1 << 16 | r2 << 12) if pair else (HandRank.HIGH_CARD << 20 | r1 << 16 | r2 << 12)
        var desc = ("Pocket " + RANK_NAMES_PLURAL[r1]) if pair else ("%s-%s" % [RANK_NAMES[r1], RANK_NAMES[r2]])
        return { "score": score, "description": desc, "rank": HandRank.ONE_PAIR if pair else HandRank.HIGH_CARD }

    # Post-flop: Check all 5-card combinations
    var best_score: int = -1
    var best_result: Dictionary = {}

    var combos = _get_combinations(total_cards, 5)
    for combo: Array[Card] in combos:
        var res = _score_5_cards(combo)
        if res.score > best_score:
            best_score = res.score
            best_result = res

    return best_result

static func evaluate_strength(hole_cards: Array[Card], community_cards: Array[Card]) -> int:
    return evaluate_hand_info(hole_cards, community_cards).score

static func _score_5_cards(cards: Array[Card]) -> Dictionary:
    var ranks: Array[int] = []
    var suits = [0, 0, 0, 0]
    var rank_counts = {}

    for c in cards:
        ranks.append(c.rank)
        suits[c.suit] += 1
        rank_counts[c.rank] = rank_counts.get(c.rank, 0) + 1

    ranks.sort()
    ranks.reverse()

    var is_flush = (suits[0] == 5 or suits[1] == 5 or suits[2] == 5 or suits[3] == 5)
    var straight_high = _get_straight_high_5(ranks)

    # Straight Flush
    if is_flush and straight_high > 0:
        var score = _pack_score(HandRank.STRAIGHT_FLUSH, [straight_high])
        var name = "Royal Flush" if straight_high == 14 else ("Straight Flush (%s-high)" % RANK_NAMES[straight_high])
        return { "score": score, "rank": HandRank.STRAIGHT_FLUSH, "description": name }

    var four_rank = 0
    var trip_rank = 0
    var pairs = []
    var singles = []

    for r in rank_counts:
        var cnt = rank_counts[r]
        if cnt == 4: four_rank = r
        elif cnt == 3: trip_rank = r
        elif cnt == 2: pairs.append(r)
        else: singles.append(r)

    pairs.sort()
    pairs.reverse()
    singles.sort()
    singles.reverse()

    # Four of a Kind
    if four_rank > 0:
        var kicker = singles[0]
        var score = _pack_score(HandRank.FOUR_OF_A_KIND, [four_rank, kicker])
        return { "score": score, "rank": HandRank.FOUR_OF_A_KIND, "description": "Four of a Kind (%s, %s kicker)" % [RANK_NAMES_PLURAL[four_rank], RANK_NAMES[kicker]] }

    # Full House
    if trip_rank > 0 and pairs.size() > 0:
        var score = _pack_score(HandRank.FULL_HOUSE, [trip_rank, pairs[0]])
        return { "score": score, "rank": HandRank.FULL_HOUSE, "description": "Full House (%s full of %s)" % [RANK_NAMES_PLURAL[trip_rank], RANK_NAMES_PLURAL[pairs[0]]] }

    # Flush
    if is_flush:
        var score = _pack_score(HandRank.FLUSH, ranks)
        return { "score": score, "rank": HandRank.FLUSH, "description": "Flush (%s-%s-%s-%s-%s)" % [RANK_NAMES[ranks[0]], RANK_NAMES[ranks[1]], RANK_NAMES[ranks[2]], RANK_NAMES[ranks[3]], RANK_NAMES[ranks[4]]] }

    # Straight
    if straight_high > 0:
        var score = _pack_score(HandRank.STRAIGHT, [straight_high])
        return { "score": score, "rank": HandRank.STRAIGHT, "description": "Straight (%s-high)" % RANK_NAMES[straight_high] }

    # Three of a Kind
    if trip_rank > 0:
        var score = _pack_score(HandRank.THREE_OF_A_KIND, [trip_rank, singles[0], singles[1]])
        return { "score": score, "rank": HandRank.THREE_OF_A_KIND, "description": "Three of a Kind (%s, %s-%s kickers)" % [RANK_NAMES_PLURAL[trip_rank], RANK_NAMES[singles[0]], RANK_NAMES[singles[1]]] }

    # Two Pair
    if pairs.size() >= 2:
        var p1 = pairs[0]
        var p2 = pairs[1]
        var kicker = singles[0]
        var score = _pack_score(HandRank.TWO_PAIR, [p1, p2, kicker])
        return { "score": score, "rank": HandRank.TWO_PAIR, "description": "Two Pair (%s and %s, %s kicker)" % [RANK_NAMES_PLURAL[p1], RANK_NAMES_PLURAL[p2], RANK_NAMES[kicker]] }

    # One Pair
    if pairs.size() == 1:
        var p = pairs[0]
        var score = _pack_score(HandRank.ONE_PAIR, [p, singles[0], singles[1], singles[2]])
        return { "score": score, "rank": HandRank.ONE_PAIR, "description": "Pair of %s (%s-%s-%s kickers)" % [RANK_NAMES_PLURAL[p], RANK_NAMES[singles[0]], RANK_NAMES[singles[1]], RANK_NAMES[singles[2]]] }

    # High Card (lists all 4 kickers)
    var score = _pack_score(HandRank.HIGH_CARD, ranks)
    return { "score": score, "rank": HandRank.HIGH_CARD, "description": "High Card %s (%s-%s-%s-%s kickers)" % [RANK_NAMES[ranks[0]], RANK_NAMES[ranks[1]], RANK_NAMES[ranks[2]], RANK_NAMES[ranks[3]], RANK_NAMES[ranks[4]]] }

## Packs rank and up to 5 kickers into a single monotonically comparable integer
static func _pack_score(hand_rank: HandRank, tiebreakers: Array[int]) -> int:
    var total: int = hand_rank << 20
    for i in range(mini(5, tiebreakers.size())):
        var shift = 16 - (i * 4)
        total |= (tiebreakers[i] & 0xF) << shift
    return total

## Returns the highest card in a straight of 5 cards, else 0.
static func _get_straight_high_5(sorted_ranks: Array[int]) -> int:
    if sorted_ranks[0] - sorted_ranks[1] == 1 and \
       sorted_ranks[1] - sorted_ranks[2] == 1 and \
       sorted_ranks[2] - sorted_ranks[3] == 1 and \
       sorted_ranks[3] - sorted_ranks[4] == 1:
        return sorted_ranks[0]
    # Ace-low (A-5-4-3-2)
    if sorted_ranks[0] == 14 and sorted_ranks[1] == 5 and sorted_ranks[2] == 4 and sorted_ranks[3] == 3 and sorted_ranks[4] == 2:
        return 5
    return 0

static func _get_combinations(pool: Array[Card], k: int) -> Array[Array]:
    var results: Array[Array] = []
    _combine(pool, k, 0, [], results)
    return results

static func _combine(pool: Array[Card], k: int, start: int, current: Array[Card], results: Array[Array]) -> void:
    if current.size() == k:
        results.append(current.duplicate())
        return
    for i in range(start, pool.size()):
        current.append(pool[i])
        _combine(pool, k, i + 1, current, results)
        current.pop_back()
