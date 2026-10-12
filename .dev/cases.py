K17 = ";".join("%d:near=17;%d:atk" % (t, t + 1) for t in range(40, 140, 25))    # kill the nearest cast 17 (M_130, level 3)
LP = "[lua:4rtefakt.mutators] "
BASE = "8:opt=DamageDealt=10;10:opt=DamageTaken=0;"
CASES = {
    # Glass Cannon: ATK 46 x 2, max HP 60 / 2. Off again: back to the game's own numbers.
    "glass_cannon": dict(room="S_10/S_1002/S_1002",
        drive="20:lua=st;30:lua=mut GlassCannon 1;40:lua=st;50:lua=mut GlassCannon 0;60:lua=st;70:quit",
        expect=[LP + "lv 1 hp 60/60 atk 46 ", LP + "lv 1 hp 30/30 atk 92 ", " hp 30/60 atk 46 "]),
    # One Hit: max HP 1. Berserker at 15 of 60 HP: ATK x 1.75.
    "one_hit_berserker": dict(room="S_10/S_1002/S_1002",
        drive="20:lua=mut OneHit 1;30:lua=st;40:lua=mut OneHit 0;45:lua=mut Berserker 1;50:hp=15;60:lua=st;70:quit",
        expect=[LP + "lv 1 hp 1/1 atk 46 ", LP + "lv 1 hp 15/60 atk 80.5 "]),
    # Level cap 1: the kill credits no EXP. Without it the same kill gives 50.
    "level_cap": dict(room="S_10/S_1002/S_1002",
        drive=BASE + "12:lua=cap 1;" + K17 + ";150:lua=st;160:quit",
        expect=[LP + "level cap 1", LP + "lv 1 hp 60/60 atk 46 def 38 exp 0 "]),
    "no_cap": dict(room="S_10/S_1002/S_1002",
        drive=BASE + K17 + ";150:lua=st;160:quit", expect=[" exp 50 "]),
    # Famine: nothing drops, so the wallet only has the kill's own 4 SP.
    "famine": dict(room="S_10/S_1002/S_1002",
        drive=BASE + "12:lua=mut Famine 1;" + K17 + ";150:pickups;230:lua=st;240:quit",
        expect=["[pickup] debris", " exp 50 sp 4"], absent=["[pickup] id "]),
    # Midas: the drop is a gold piece worth 5 x the monster's level (3) = 15 SP each (two drops here), on top of the kill's 4.
    "midas": dict(room="S_10/S_1002/S_1002",
        drive=BASE + "12:lua=mut Midas 1;" + K17 + ";150:pickups;230:lua=st;240:quit",
        expect=["[pickup] id 120", " exp 50 sp 34"]),
    # Vampire: a kill at 10 of 60 HP heals 2 (3%); the page lists the rule.
    "vampire": dict(room="S_10/S_1002/S_1002",
        drive=BASE + "6:hp=10;12:lua=mut Vampire 1;" + K17 + ";145:lua=st;150:quit",
        expect=[" hp 12/60 "]),
    # Permadeath: the death marks the run; Retry brings the player back, and the mod ends the run again.
    "permadeath": dict(room="S_10/S_1002/S_1002",
        drive="20:lua=mut Permadeath 1;30:hp=0;200:ok;260:ok;400:lua=st;640:lua=st;700:quit",
        expect=["[death] HP 0", LP + "permadeath: run ", " hp 60/60 ", LP + "permadeath: a dead run was continued, ending it", "[death] HP 0"]),
    # Rules read from the settings at start, and the corner line that lists them (the README's capture).
    "from_settings": dict(room="S_10/S_1002/S_1002",
        settings=chr(10).join(["GlassCannon=1", "Vampire=1", "LevelCap=20"]),
        drive="60:shot;70:quit", expect=[LP + "Mutators loaded: Glass Cannon, Vampire, Level cap 20"], shots={"hud": 60}),
    # Off: the same death and Retry, and the game goes on.
    "permadeath_off": dict(room="S_10/S_1002/S_1002",
        drive="30:hp=0;200:ok;260:ok;400:lua=st;640:lua=st;700:quit",
        expect=["[death] HP 0", " hp 60/60 ", " hp 60/60 "], absent=["permadeath"]),
}
