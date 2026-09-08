class_name PlayerTracker
extends RefCounted

var hands_played: int = 0
var hands_folded: int = 0
var raises_made: int = 0
var calls_made: int = 0

func record_fold() -> void:
    hands_folded += 1
    hands_played += 1

func record_call() -> void:
    calls_made += 1

func record_raise() -> void:
    raises_made += 1

func get_fold_rate() -> float:
    return float(hands_folded) / float(maxi(1, hands_played))

func get_call_rate() -> float:
    var total_actions = calls_made + raises_made
    return float(calls_made) / float(maxi(1, total_actions))

func get_aggression_rate() -> float:
    var total_actions = calls_made + raises_made
    return float(raises_made) / float(maxi(1, total_actions))
