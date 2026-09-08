class_name CardVisuals
extends RefCounted

const CARDS_PATH = "res://assets/art/cards/"
const PORTRAITS_PATH = "res://assets/art/portraits/"

const PORTRAIT_DATA = [
    { "file": "athlete.png",     "gender": "M", "names": ["Marcus", "Trent", "Derrick", "Garrison", "Brant", "Gareth"] },
    { "file": "chico.png",       "gender": "M", "names": ["Chico", "Mateo", "Rafael", "Esteban", "Javier", "Enrique"] },
    { "file": "cyril.png",       "gender": "M", "names": ["Cyril", "Arthur", "Julian", "Percival", "Barnaby", "Joe", "Kevin"] },
    { "file": "dolores.png",     "gender": "F", "names": ["Dolores", "Dolly", "Caroline", "Lucinda", "Juliette", "Wilma"] },
    { "file": "esquisse.png",    "gender": "M", "names": ["Simon", "Eddy", "Carl", "Henri", "Lucien", "Jerome"] },
    { "file": "gillian.png",     "gender": "F", "names": ["Gillian", "Berryl", "Gwynneth", "Sheila", "Tammy",] },
    { "file": "glyn.png",        "gender": "M", "names": ["Glyn", "Glen", "Howard", "Wayne", "Brendan",] },
    { "file": "harry.png",       "gender": "M", "names": ["Harry", "Barry", "Fred", "Wayne", "Stuart", "Justin"] },
    { "file": "h06.png",         "gender": "M", "names": ["Hank", "Steve", "Tucker", "Boris", "Ivan", "Duncan"] },
    { "file": "brett.png",       "gender": "M", "names": ["Brett", "Leroy", "Jerome", "Leonard", "Ian", "Greg", "Shaun"] },
    { "file": "linda02.png",     "gender": "F", "names": ["Linda", "Roxanne", "Nadia", "Mona", "Delilah", "Kate"] },
    { "file": "logan.png",       "gender": "M", "names": ["Logan", "Wyatt", "Cole", "Jesse", "Shane", "Gavin"] },
    { "file": "mama.png",        "gender": "F", "names": ["Maeve", "Beatrice", "Dolores", "Agnes", "Hattie", "Yvonne"] },
    { "file": "peter.png",       "gender": "M", "names": ["Peter", "Charles", "Carlos", "Phil", "Paul"] },
    { "file": "punk01.png",      "gender": "M", "names": ["Rabe", "Spike", "Rocco", "Bane", "Vinny"] },
    { "file": "russ.png",        "gender": "M", "names": ["Rene", "John", "Toby", "Bill", "Bruce"] },
    { "file": "santa_claws.png", "gender": "M", "names": ["Klaus", "Jasper", "Silas", "Ebenezer", "Sterling"] },
    { "file": "sarah.png",       "gender": "F", "names": ["Sarah", "Evelyn", "Tessa", "Genevieve", "Lorelei"] },
    { "file": "siobhan.png",     "gender": "F", "names": ["Siobhan", "Sara", "Zara", "Sally", "Melinda", "Melissa"] },
    { "file": "zedobar02.png",   "gender": "M", "names": ["Zed", "Baron", "Vance", "Malachi", "Gary", "Hector", "Corvus"] }
]

static func get_card_texture(rank: int, suit: int) -> Texture2D:
    var rank_str = ""
    match rank:
        14: rank_str = "ace"
        13: rank_str = "king"
        12: rank_str = "queen"
        11: rank_str = "jack"
        _: rank_str = str(rank)

    var suit_str = ""
    match suit:
        0: suit_str = "clubs"
        1: suit_str = "diamonds"
        2: suit_str = "hearts"
        3: suit_str = "spades"

    var full_path = CARDS_PATH + ("%s_of_%s.webp" % [rank_str, suit_str])
    if ResourceLoader.exists(full_path):
        return load(full_path)
    return null

static func get_random_opponents(count: int) -> Array[Dictionary]:
    var pool = PORTRAIT_DATA.duplicate()
    pool.shuffle()
    var opponents: Array[Dictionary] = []
    for i in range(mini(count, pool.size())):
        var entry = pool[i]
        var tex_path = PORTRAITS_PATH + entry.file
        var tex: Texture2D = load(tex_path) if ResourceLoader.exists(tex_path) else null
        var names: Array = entry.names
        var display_name: String = names[randi() % names.size()]
        opponents.append({
            "name": display_name,
            "texture": tex,
            "file": entry.file
        })
    return opponents
