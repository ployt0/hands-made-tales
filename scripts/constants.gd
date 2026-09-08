class_name Constants

const SEED_PHRASE = "Phoo"
const UTILS_SEED_PHRASE = "Phoo"

const LEADERBOARD_NAME = "hands-made-tales"

## Because INF doesn't translate well to int!
const UNAVAILABLE: int = -42

const MAX_TIME_S = 10000

const SCREEN_SIZE = Vector2(1600, 900)

const IS_DEV = false


## Helper to encode Match + Seconds into 1 sortable integer
static func encode_composite_score(matches_won: int, time_secs: float) -> int:
    var time_component = maxi(0, (MAX_TIME_S - 1) - int(time_secs))
    return (matches_won * MAX_TIME_S) + time_component

## Helper to decode composite score for display
static func decode_composite_score(raw_score: int) -> Dictionary:
    var matches = int(float(raw_score) / float(MAX_TIME_S))
    var time_secs = (MAX_TIME_S - 1) - (raw_score % MAX_TIME_S)
    return { "matches": matches, "seconds": time_secs }
