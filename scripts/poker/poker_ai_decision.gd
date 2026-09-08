class_name PokerAIDecision
extends RefCounted

enum Action { FOLD, CHECK, CALL, RAISE }

const LINES_MONSTER_VALUE = [
    "Just the card I was waiting for.",
    "Let's see who's really brave.",
    "Now it gets expensive.",
    "You're going to regret staying in.",
    "All according to plan.",
    "Hope you brought plenty of chips.",
    "This table is mine.",
    "Check-raising was an option, but this is faster.",
    "The board connected perfectly.",
    "I don't think you can beat this.",
    "Math doesn't lie.",
    "Every street was leading to this.",
    "Thank you for building the pot.",
    "Are you sure you want to see the river?",
    "I wouldn't call if I were you.",
    "A very clean runout."
]

const LINES_BLUFF_PRESSURE = [
    "I wouldn't stay in if I were you.",
    "You really want to pay to see this?",
    "Might want to think twice about that.",
    "Trust me, you're beat.",
    "Fold while you still have a stack.",
    "Don't say I didn't warn you.",
    "Expensive lesson incoming.",
    "You're drawing dead.",
    "You look like you want to fold.",
    "That card didn't help you at all.",
    "Can you afford to find out?",
    "Just give it up."
]

const LINES_TRAP_SLOWPLAY = [
    "Nothing for me here... check.",
    "Whatever you say.",
    "I'll just watch for now.",
    "Take your time.",
    "Board is too dry. Check.",
    "Just checking to be safe.",
    "Passing the buck.",
    "Ball is in your court.",
    "I'm in no rush."
]

const LINES_CASUAL_CALL = [
    "Too cheap to fold.",
    "Let's see what happens.",
    "I'll pay the toll.",
    "Can't walk away just yet.",
    "One more card won't hurt.",
    "I have a feeling about this river.",
    "Pot odds say I have to look.",
    "Curiosity got the better of me."
]

const LINES_MANIAC_CHAOS = [
    "Why so serious? Let's gamble!",
    "Chips are made to be pushed.",
    "Too slow! Let's build a real pot.",
    "Scared money makes no money.",
    "Let's speed this game up.",
    "Push it all!",
    "You only live once."
]

const LINES_CHAMELEON_MIMIC = [
    "I know exactly how you play.",
    "Predictable.",
    "You've been doing that all night.",
    "Playing the player, not the cards.",
    "Are you sure about that?",
    "You always hesitate when you have nothing.",
    "You think you're reading me?",
    "I've seen this move before."
]

static func decide_action(
    profile: PokerAIProfile,
    hole_cards: Array[Card],
    community_cards: Array[Card],
    current_bet_to_call: int,
    min_raise: int,
    my_chips: int,
    pot_size: int
) -> Dictionary:
    var strength: float = CardEvaluator.evaluate_hand_info(hole_cards, community_cards).score / float(CardEvaluator.HandRank.STRAIGHT_FLUSH << 20)

    var is_preflop = community_cards.is_empty()
    var can_check = (current_bet_to_call == 0)
    var is_facing_raise = (current_bet_to_call > min_raise)

    # Ratio of bet relative to the bot's total stack
    var stack_ratio: float = float(current_bet_to_call) / float(maxi(1, my_chips))
    var is_all_in_or_shove: bool = (stack_ratio >= 0.6) or (current_bet_to_call >= my_chips)

    var subversion_chance = (profile.deception / 100.0) * 0.15
    var is_subverting = randf() < subversion_chance

    var tight_val = profile.tightness / 100.0
    var aggro_val = profile.aggression / 100.0
    var bluff_val = profile.bluffiness / 100.0
    var call_val = profile.calliness / 100.0

    var chosen_action: Action = Action.FOLD
    var raise_amt: int = 0
    var dialogue: String = ""

    if is_preflop:
        var preflop_quality = _get_preflop_quality(hole_cards)

        if is_all_in_or_shove:
            # When facing a massive all-in shove, players need premium hands
            # Base threshold: ~0.80 (QQ+, AK), adjusted by archetype tightness
            var shove_call_threshold = lerpf(0.65, 0.90, tight_val)

            if profile.archetype == PokerAIProfile.Archetype.MANIAC or profile.archetype == PokerAIProfile.Archetype.GAMBLER:
                shove_call_threshold -= 0.10 # More willing to gamble on medium pairs / big broadways

            if preflop_quality >= shove_call_threshold:
                chosen_action = Action.CALL
                dialogue = _pick(LINES_MONSTER_VALUE) if randf() < 0.35 else ""
            else:
                chosen_action = Action.FOLD

        elif is_facing_raise:
            # Standard raise facing logic (scaled by bet size ratio)
            var call_req = lerpf(0.40, 0.75, tight_val) + (stack_ratio * 0.25)
            var raise_req = lerpf(0.75, 0.90, 1.0 - aggro_val)

            if preflop_quality >= raise_req and randf() < aggro_val:
                chosen_action = Action.RAISE
                raise_amt = min_raise * 2
                if randf() < 0.25: dialogue = _pick(LINES_MONSTER_VALUE)
            elif preflop_quality >= call_req or (randf() < (call_val * 0.3) and preflop_quality >= 0.40):
                chosen_action = Action.CALL
                if randf() < 0.15: dialogue = _pick(LINES_CASUAL_CALL)
            else:
                chosen_action = Action.FOLD
        else:
            # Unopened or limped pot
            var open_raise_req = lerpf(0.55, 0.80, tight_val)
            var limp_call_req = lerpf(0.25, 0.50, tight_val)

            if preflop_quality >= open_raise_req and randf() < aggro_val:
                chosen_action = Action.RAISE
                raise_amt = min_raise * 2
            elif preflop_quality >= limp_call_req or can_check:
                chosen_action = Action.CHECK if can_check else Action.CALL
            elif randf() < bluff_val * 0.25:
                chosen_action = Action.RAISE
                raise_amt = min_raise
                if randf() < 0.30: dialogue = _pick(LINES_BLUFF_PRESSURE)
            else:
                chosen_action = Action.CHECK if can_check else Action.FOLD

    else:
        match profile.archetype:
            PokerAIProfile.Archetype.ROCK:
                if is_subverting and !is_facing_raise:
                    chosen_action = Action.RAISE
                    raise_amt = min_raise
                    if randf() < 0.40: dialogue = _pick(LINES_BLUFF_PRESSURE)
                elif strength >= 0.55:
                    chosen_action = Action.RAISE if (randf() < aggro_val and !is_facing_raise) else Action.CALL
                    raise_amt = min_raise * 2
                    if randf() < 0.20: dialogue = _pick(LINES_MONSTER_VALUE)
                elif (strength >= (tight_val * 0.35) and not is_all_in_or_shove) or can_check:
                    chosen_action = Action.CHECK if can_check else Action.CALL
                else:
                    chosen_action = Action.FOLD

            PokerAIProfile.Archetype.CALLING_STATION:
                if is_subverting and strength >= 0.75:
                    chosen_action = Action.RAISE
                    raise_amt = min_raise * 2
                    if randf() < 0.50: dialogue = _pick(LINES_MONSTER_VALUE)
                else:
                    if can_check:
                        chosen_action = Action.CHECK
                    elif is_all_in_or_shove:
                        chosen_action = Action.CALL if strength >= 0.45 else Action.FOLD
                    elif current_bet_to_call <= my_chips * 0.35 or strength >= 0.20:
                        chosen_action = Action.CALL
                        if randf() < 0.20: dialogue = _pick(LINES_CASUAL_CALL)
                    else:
                        chosen_action = Action.FOLD

            PokerAIProfile.Archetype.MANIAC:
                if is_subverting:
                    chosen_action = Action.CHECK if can_check else Action.CALL
                    if randf() < 0.30: dialogue = _pick(LINES_TRAP_SLOWPLAY)
                else:
                    if (!is_facing_raise and not is_all_in_or_shove) or randf() < 0.60:
                        chosen_action = Action.RAISE
                        raise_amt = maxi(min_raise, int(pot_size * 0.5))
                        if randf() < 0.35: dialogue = _pick(LINES_MANIAC_CHAOS)
                    elif strength >= 0.30 or not is_all_in_or_shove:
                        chosen_action = Action.CALL
                    else:
                        chosen_action = Action.FOLD

            PokerAIProfile.Archetype.TRAPPER:
                if strength >= 0.60:
                    if randf() < 0.25 or is_facing_raise:
                        chosen_action = Action.RAISE
                        raise_amt = min_raise * 2
                        if randf() < 0.40: dialogue = _pick(LINES_MONSTER_VALUE)
                    else:
                        chosen_action = Action.CHECK if can_check else Action.CALL
                        if randf() < 0.35: dialogue = _pick(LINES_TRAP_SLOWPLAY)
                elif can_check:
                    chosen_action = Action.CHECK
                elif strength >= 0.30 and not is_all_in_or_shove:
                    chosen_action = Action.CALL
                else:
                    chosen_action = Action.FOLD

            PokerAIProfile.Archetype.BLUFFER:
                var wants_bluff = randf() < (bluff_val * 0.6)
                if wants_bluff and !is_facing_raise and strength < 0.40:
                    chosen_action = Action.RAISE
                    raise_amt = maxi(min_raise, int(pot_size * 0.4))
                    if randf() < 0.50: dialogue = _pick(LINES_BLUFF_PRESSURE)
                elif strength >= 0.45:
                    chosen_action = Action.RAISE if randf() < aggro_val else Action.CALL
                    raise_amt = min_raise
                    if randf() < 0.30: dialogue = _pick(LINES_MONSTER_VALUE)
                elif can_check:
                    chosen_action = Action.CHECK
                elif strength >= 0.25 and not is_all_in_or_shove:
                    chosen_action = Action.CALL
                else:
                    chosen_action = Action.FOLD

            _: # GAMBLER / CHAMELEON / DILUTED BALANCED
                var perceived_strength = strength
                if randf() < bluff_val * 0.3:
                    perceived_strength += 0.25

                if perceived_strength >= 0.60 and randf() < aggro_val and !is_facing_raise:
                    chosen_action = Action.RAISE
                    raise_amt = min_raise * 2

                    if profile.archetype == PokerAIProfile.Archetype.CHAMELEON:
                        var roll = randf()
                        if roll < 0.20:
                            dialogue = _pick(LINES_CHAMELEON_MIMIC)
                        elif roll < 0.40:
                            dialogue = _pick(LINES_MONSTER_VALUE)
                        elif roll < 0.50:
                            dialogue = _pick(LINES_BLUFF_PRESSURE)
                    elif randf() < 0.20:
                        dialogue = _pick(LINES_CHAMELEON_MIMIC) if randf() < 0.03 else _pick(LINES_MONSTER_VALUE)

                elif (perceived_strength >= 0.30 and not is_all_in_or_shove) or (perceived_strength >= 0.50 and is_all_in_or_shove) or can_check:
                    chosen_action = Action.CHECK if can_check else Action.CALL
                    if profile.archetype == PokerAIProfile.Archetype.GAMBLER and randf() < 0.25:
                        dialogue = _pick(LINES_CASUAL_CALL)
                    elif profile.archetype == PokerAIProfile.Archetype.CHAMELEON and randf() < 0.15:
                        dialogue = _pick(LINES_TRAP_SLOWPLAY) if randf() < 0.5 else _pick(LINES_CASUAL_CALL)
                else:
                    chosen_action = Action.FOLD

    # Stack sanity clamping
    if chosen_action == Action.RAISE:
        raise_amt = clamp(raise_amt, min_raise, my_chips - current_bet_to_call)
        if raise_amt <= 0:
            chosen_action = Action.CHECK if can_check else Action.CALL

    return {
        "action": chosen_action,
        "raise_amount": raise_amt,
        "dialogue": dialogue
    }

static func _pick(lines: Array) -> String:
    return lines[randi() % lines.size()]

static func _get_preflop_quality(hole_cards: Array[Card]) -> float:
    if hole_cards.size() < 2:
        return 0.0
    var r1 = maxi(hole_cards[0].rank, hole_cards[1].rank)
    var r2 = mini(hole_cards[0].rank, hole_cards[1].rank)
    var suited = (hole_cards[0].suit == hole_cards[1].suit)
    var pair = (r1 == r2)

    if pair:
        return lerpf(0.50, 0.99, float(r1 - 2) / 12.0)

    var score = (float(r1 + r2) / 28.0) * 0.70
    if suited: score += 0.12
    if (r1 - r2) == 1: score += 0.08
    elif (r1 - r2) == 2: score += 0.04

    return clampf(score, 0.05, 0.95)
