class_name PokerAIProfile
extends Resource

enum Archetype {
    ROCK,
    CALLING_STATION,
    MANIAC,
    TRAPPER,
    BLUFFER,
    GAMBLER,
    CHAMELEON
}

const ARCHETYPE_TENDENCY: float = 4.0

@export var archetype: Archetype = Archetype.ROCK
@export var profile_name: String = "Opponent"

## This is like the inverse of bluffiness, but distinct from bluffing. A tight
## player will discard their hand pre-flop if they calculate it unworthy.
## It is the gatekeeper for each hand. Think of it as a pre-filter, playing
## only when the odds are better. Tight players play better hands, but
## whether they raise or call is down to other stats.
@export_range(0, 100) var tightness: float = 50.0
## Tendency to bet/raise instead of check/call. Kind of psycopathy in how
## this can harm their position.
@export_range(0, 100) var aggression: float = 50.0
## Inverted tightness, on steroids; they see unpredictability as a strength.
@export_range(0, 100) var bluffiness: float = 50.0
## Tenacity; resistance to folding.
@export_range(0, 100) var calliness: float = 50.0
## Tendency to break their character's mould.
@export_range(0, 100) var deception: float = 50.0

static func create_profile(type: Archetype, match_idx: int = 1, max_matches: int = 7) -> PokerAIProfile:
    var p = PokerAIProfile.new()
    p.archetype = type

    var base_tight: float = 50.0
    var base_aggro: float = 50.0
    var base_bluff: float = 50.0
    var base_call: float = 50.0
    var base_dec: float = 50.0

    match type:
        Archetype.ROCK:
            p.profile_name = "The Rock"
            base_tight = 85.0; base_aggro = 45.0; base_bluff = 8.0; base_call = 25.0; base_dec = 25.0
        Archetype.CALLING_STATION:
            p.profile_name = "The Station"
            base_tight = 25.0; base_aggro = 15.0; base_bluff = 5.0; base_call = 90.0; base_dec = 10.0
        Archetype.MANIAC:
            p.profile_name = "The Maniac"
            base_tight = 15.0; base_aggro = 75.0; base_bluff = 55.0; base_call = 50.0; base_dec = 20.0
        Archetype.TRAPPER:
            p.profile_name = "The Trapper"
            base_tight = 55.0; base_aggro = 35.0; base_bluff = 20.0; base_call = 60.0; base_dec = 80.0
        Archetype.BLUFFER:
            p.profile_name = "The Bluffer"
            base_tight = 35.0; base_aggro = 60.0; base_bluff = 65.0; base_call = 35.0; base_dec = 45.0
        Archetype.GAMBLER:
            p.profile_name = "The Gambler"
            base_tight = 25.0; base_aggro = 50.0; base_bluff = 35.0; base_call = 75.0; base_dec = 20.0
        Archetype.CHAMELEON:
            p.profile_name = "The Chameleon"
            p.tightness = 50.0; p.aggression = 50.0; p.bluffiness = 50.0; p.calliness = 50.0; p.deception = 100.0
            return p

    # Clamp match progress to MAX_MATCHES so free-play stays at the intended baseline
    var effective_m_idx = mini(match_idx, max_matches)
    var weight_base = ARCHETYPE_TENDENCY + float(max_matches - effective_m_idx)
    var weight_opt = float(effective_m_idx)
    var total_weight = ARCHETYPE_TENDENCY + float(max_matches)

    p.tightness = (base_tight * weight_base + 50.0 * weight_opt) / total_weight
    p.aggression = (base_aggro * weight_base + 50.0 * weight_opt) / total_weight
    p.bluffiness = (base_bluff * weight_base + 50.0 * weight_opt) / total_weight
    p.calliness = (base_call * weight_base + 50.0 * weight_opt) / total_weight
    p.deception = (base_dec * weight_base + 50.0 * weight_opt) / total_weight

    return p

## Weighted pool selection: duplicates allowed, unpicked types gain 2x weight
static func pick_weighted_archetypes(count: int, pool: Array[Archetype]) -> Array[Archetype]:
    var weights: Dictionary = {}
    for type in pool:
        weights[type] = 1.0

    var selected: Array[Archetype] = []
    for i in range(count):
        var total_w = 0.0
        for t in pool:
            total_w += weights[t]

        var roll = randf() * total_w
        var acc = 0.0
        var chosen = pool[0]
        for t in pool:
            acc += weights[t]
            if roll <= acc:
                chosen = t
                break

        selected.append(chosen)
        # Double weight of all unselected types
        for t in pool:
            if t != chosen:
                weights[t] *= 2.0

    return selected

func adapt_to_player(tracker: PlayerTracker) -> void:
    if archetype != Archetype.CHAMELEON:
        return
    if tracker.get_fold_rate() > 0.45:
        aggression = 75.0
        bluffiness = 70.0
        tightness = 30.0
    elif tracker.get_call_rate() > 0.50:
        tightness = 70.0
        aggression = 60.0
        bluffiness = 10.0
        calliness = 40.0
    elif tracker.get_aggression_rate() > 0.45:
        tightness = 60.0
        aggression = 25.0
        calliness = 70.0
        bluffiness = 15.0
