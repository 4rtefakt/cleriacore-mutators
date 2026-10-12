-- Mutators: challenge rules for Ys Origin on CleriaCore, each one a few lines over the mod API.
-- Everything is a setting (F1 > Mods > Mutators), applied at once, kept in cleria.ini.

local S, P, G = cleria.settings, cleria.player, cleria.game

local MUTATORS = {   -- key, name, what it does (the page's description)
    {"GlassCannon", "Glass Cannon", "Your ATK is doubled and your max HP is halved."},
    {"Berserker", "Berserker", "The lower your HP, the harder you hit: up to twice your ATK at 1 HP."},
    {"OneHit", "One Hit", "Your max HP is 1. Anything that touches you kills you."},
    {"Vampire", "Vampire", "Recovery Drops heal nothing. Every kill heals 3% of your max HP instead."},
    {"Midas", "Midas", "Everything a monster drops turns to gold, worth 5 SP per monster level."},
    {"Famine", "Famine", "Monsters drop nothing at all."},
    {"Permadeath", "Permadeath", "A death ends the run for good: that game can not be continued or reloaded."},
}
local on = {}
for _, m in ipairs(MUTATORS) do on[m[1]] = S.get(m[1], false) end
local cap = S.get("LevelCap", 0)            -- 0 = off; 1..60 = no EXP once that level is reached
local show = S.get("ShowList", true)

-- ---- stats: one modifier per stat for the whole mod, so the rules are combined here --------------------------
local last = {}
local function apply_stats()
    if not G.in_game() then return end
    local st = P.stats()
    local atk = on.GlassCannon and 2 or 1
    if on.Berserker and st and st.max_hp > 0 then
        local missing = 1 - math.max(st.hp, 1) / st.max_hp
        atk = atk * (1 + math.floor(missing * 20 + 0.5) / 20)      -- 5% steps: the modifier is not rewritten every tick
    end
    local add, mul = 0, on.GlassCannon and 0.5 or 1
    if on.OneHit then add, mul = -9999, 1 end                       -- the game keeps max HP within 1..999
    if atk ~= last.atk then P.set_modifier("atk", 0, atk) last.atk = atk end
    if add ~= last.add or mul ~= last.mul then P.set_modifier("max_hp", add, mul) last.add, last.mul = add, mul end
end

-- ---- Permadeath: a run is a number kept in the save; the dead ones are kept outside the saves ----------------
local dead = cleria.json.decode(cleria.data.read("dead.json") or "") or {}
local function run_id()
    if not cleria.save.ready() then return nil end
    local id = cleria.save.get("run")
    if not id then
        id = string.format("%d-%d", math.floor(cleria.unix_time()), math.random(100000, 999999))
        cleria.save.set("run", id)
    end
    return id
end
local kill_at = nil
local function check_dead()
    local id = on.Permadeath and run_id()
    if id and dead[id] and not kill_at then
        cleria.notice("This run ended in death. Start a new game.", "Permadeath")
        kill_at = cleria.time() + 2
    end
end
local died = false      -- a Retry raises no event: the tick sees the HP come back
cleria.events.on("death", function()
    kill_at, died = nil, true
    local id = on.Permadeath and run_id()
    if id and not dead[id] then
        dead[id] = true
        cleria.data.write("dead.json", cleria.json.encode(dead))
        cleria.log("permadeath: run " .. id .. " is over")
    end
end)

cleria.events.on("new_game", function() last = {} run_id() apply_stats() end)
cleria.events.on("load", function() last = {} apply_stats() check_dead() end)
cleria.events.on("room_enter", function() check_dead() end)
cleria.events.on("tick", function()
    apply_stats()
    if died and G.in_game() and P.hp() > 0 then died = false check_dead() end
    if kill_at and cleria.time() >= kill_at and G.in_game() and not G.frozen() then
        kill_at = nil
        if P.hp() > 0 then
            cleria.log("permadeath: a dead run was continued, ending it")
            P.set_hp(0)
        end
    end
end)

-- ---- the numbers the game is about to apply ------------------------------------------------------------------
cleria.combat.add_filter("exp", function(q)
    if cap > 0 and q.level >= cap then return "suppress" end
end)
cleria.combat.add_filter("pickup", function(q)
    if on.Vampire and q.what == "hp" then return "suppress" end
end)
cleria.combat.add_filter("drop", function(q)
    if on.Famine then return "suppress" end
    if on.Midas then return {action = "replace", item = 0x78, value = 5 * math.max(q.level or 1, 1)} end
end)
cleria.events.on("enemy_killed", function()
    if not on.Vampire then return end
    local hp, max = P.hp(), P.max_hp()
    if hp > 0 and hp < max then P.set_hp(math.min(max, hp + math.max(1, math.floor(max * 0.03 + 0.5)))) end
end)

-- ---- the page and the corner list ----------------------------------------------------------------------------
local function active_names()
    local t = {}
    for _, m in ipairs(MUTATORS) do if on[m[1]] then t[#t + 1] = m[2] end end
    if cap > 0 then t[#t + 1] = "Level cap " .. cap end
    return t
end

cleria.ui.page("Mutators", function(p)
    p:section("Rules")
    for _, m in ipairs(MUTATORS) do
        local v, changed = p:toggle(m[2], on[m[1]], m[3] .. " Not a retail option.")
        if changed then on[m[1]] = v S.set(m[1], v) apply_stats() check_dead() end
    end
    local c, changed = p:slider("Level cap", cap, 0, 60, 1, "%.0f", "You gain no EXP once you reach this level. 0 = no cap; 1 = a level 1 run.")
    if changed then cap = math.floor(c + 0.5) S.set("LevelCap", cap) end
    p:section("Display")
    local s, ch = p:toggle("Show the active rules", show, "A line in the top-left corner while you play.")
    if ch then show = s S.set("ShowList", show) end
    p:info("Active", #active_names() == 0 and "none" or table.concat(active_names(), ", "))
end)

cleria.hud.layer("mutators", function(d)
    if not show or not G.in_game() then return end
    local names = active_names()
    if #names == 0 then return end
    local s = d.scale
    local text = table.concat(names, "  -  ")
    local w = d:text_size(text, {size = 20 * s, font = "cond_medium"})
    d:rect(14 * s, 14 * s, w + 24 * s, 34 * s, {color = 0x100F0B, alpha = 0.7, rounding = 4 * s})
    d:text(26 * s, 20 * s, text, {size = 20 * s, color = "warn", font = "cond_medium"})
end)

cleria.speedrun.modification(function()
    local names = active_names()
    return #names > 0 and ("Mutators: " .. table.concat(names, ", ")) or "Mutators (none active)"
end)

-- ---- test commands (CLERIA_DRIVE "lua=mut <key> <0|1>", "lua=cap <n>", "lua=st") ------------------------------
cleria.command("mut", function(a)
    local k, v = a:match("^(%S+)%s+(%d)")
    if on[k] == nil then cleria.log("no mutator " .. tostring(k)) return end
    on[k] = v == "1"
    apply_stats() check_dead()
    cleria.log("mutator " .. k .. " = " .. tostring(on[k]))
end)
cleria.command("cap", function(a) cap = tonumber(a) or 0 cleria.log("level cap " .. cap) end)
cleria.command("st", function()
    local st = P.stats()
    cleria.log(string.format("lv %d hp %.0f/%.0f atk %g def %g exp %d sp %d", st.level, st.hp, st.max_hp, st.atk, st.def, math.floor(st.exp), st.sp))
end)
cleria.log("Mutators loaded: " .. (#active_names() == 0 and "none active" or table.concat(active_names(), ", ")))
