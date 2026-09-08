class_name SFXPlayer
extends Node

const COLLECT_01 = preload("res://assets/sfx/collect01.ogg")

var draw_sfx = [
    preload("res://assets/sfx/card_draws/draw1.ogg"),
    preload("res://assets/sfx/card_draws/draw2.ogg"),
    preload("res://assets/sfx/card_draws/draw3.ogg"),
    preload("res://assets/sfx/card_draws/draw4.ogg"),
    preload("res://assets/sfx/card_draws/draw5.ogg"),
    preload("res://assets/sfx/card_draws/draw6.ogg"),
    preload("res://assets/sfx/card_draws/draw7.ogg"),
    preload("res://assets/sfx/card_draws/draw8.ogg"),
    preload("res://assets/sfx/card_draws/draw9.ogg"),
    preload("res://assets/sfx/card_draws/draw10.ogg"),
    preload("res://assets/sfx/card_draws/draw11.ogg"),
]

var chips_sfx = [
    preload("res://assets/sfx/chips/chips01.ogg"),
    preload("res://assets/sfx/chips/chips02.ogg"),
    preload("res://assets/sfx/chips/chips03.ogg"),
    preload("res://assets/sfx/chips/chips04.ogg"),
    preload("res://assets/sfx/chips/chips05.ogg"),
    preload("res://assets/sfx/chips/chips06.ogg"),
    preload("res://assets/sfx/chips/chips07.ogg"),
    preload("res://assets/sfx/chips/chips08.ogg"),
    preload("res://assets/sfx/chips/chips09.ogg"),
    preload("res://assets/sfx/chips/chips10.ogg"),
    preload("res://assets/sfx/chips/chips11.ogg"),
]

var fold_sfx = [
    preload("res://assets/sfx/fold01.ogg"),
    preload("res://assets/sfx/fold02.ogg"),
    preload("res://assets/sfx/fold03.ogg"),
    preload("res://assets/sfx/fold04.ogg"),
    preload("res://assets/sfx/fold05.ogg"),
]

var knock_sfx = [
    preload("res://assets/sfx/knock01.ogg"),
    preload("res://assets/sfx/knock02.ogg"),
    preload("res://assets/sfx/knock11.ogg"),
    preload("res://assets/sfx/knock12.ogg"),
]

const ACE_OF_SPADES = preload("res://assets/sfx/ace_of_spades.ogg")
const NEED_IS_ACE_OF_SPADES = preload("res://assets/sfx/need_is_ace_of_spades.ogg")

## This was found to work on extensive samples and gives a reasonable
## volume in all cases (assuming sample peaks at -2 to -3db as most do).
## Used in [member play] as [vol_shift_db]
func get_rand_db(rng: RandomNumberGenerator):
    return linear_to_db(clamp(rng.randfn(0.55, 0.1), 0.4, 0.75))

## [param pitch_scale] can be used for example like this: `2 ** randfn(0, 0.2)`
## Which gives modal and median of 2**0 = 1, with 1 being the No-Op.
## 2**-1 = 0.5 and 2**1 == 2, which correspond to a halving and doubling in pitch
## respectively. Now 2**-0.4 == 0.75 and 2**0.4 == 1.32, which is subtler.
## eg: sfx.play(sfx.STOP_WHISTLE, sfx.get_rand_db(rng), 2 ** rng.randfn(0, 0.15))
func play(stream, vol_shift_db: float = 1, pitch_scale: float = 1, cb = null):
    var p = AudioStreamPlayer.new()
    p.pitch_scale = pitch_scale
    p.volume_db += vol_shift_db
    p.stream = stream
    p.bus = "SFX"
    if cb != null:
        p.finished.connect(func():
            cb.call()
            p.queue_free()
        )
    else:
        p.finished.connect(func():p.queue_free())
    add_child(p)
    p.play()

# Call like: sfx.play_chip_raise(current_bet_amount, rng)
func play_chip_raise(amount: int, rng: RandomNumberGenerator):
    # Map bet size to how many individual chips clink (min 1, max 10)
    # $10 is min ante and $1000 is max
    var intensity = clampi((amount % 1000) / 100 + 1, 1, 10)

    for i in range(intensity):
        var stream = chips_sfx.pick_random()
        var random_db = randf_range(-2.0, 2.0)
        var random_pitch = 2 ** rng.randfn(0, 0.15)

        if i == 0:
            # Play the first one instantly
            play(stream, random_db, random_pitch)
        else:
            # Stagger the subsequent chips slightly so they cascade
            var delay = randf_range(0.02, 0.08) * i
            get_tree().create_timer(delay).timeout.connect(func():
                if is_inside_tree():
                    play(stream, random_db + (i * 0.3), random_pitch)
            )

func chip_sweep(rng: RandomNumberGenerator):
    play(COLLECT_01, get_rand_db(rng), 2 ** rng.randfn(0, 0.15))
    # todo tack a ker-ching on the end.
