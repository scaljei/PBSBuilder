-- PBSBuilder/Core/Constants.lua
-- All known PBS conditions and actions with metadata for the UI

PBSBuilder = PBSBuilder or {}
local B = PBSBuilder

-- ─────────────────────────────────────────────────────────────
-- OWNERS
-- ─────────────────────────────────────────────────────────────
B.OWNERS = {
    { id = "ally",  label = "Ally  (your team)" },
    { id = "enemy", label = "Enemy (foe team)"  },
}

-- ─────────────────────────────────────────────────────────────
-- PET SLOTS
-- ─────────────────────────────────────────────────────────────
B.PET_SLOTS = {
    { id = "1", label = "Slot 1" },
    { id = "2", label = "Slot 2" },
    { id = "3", label = "Slot 3" },
}

-- ─────────────────────────────────────────────────────────────
-- COMPARE OPERATORS
-- ─────────────────────────────────────────────────────────────
B.COMPARE_OPS = { "=", "!=", ">", "<", ">=", "<=" }
B.EQUALITY_OPS = { "=", "!=", "~", "!~" }
B.BOOLEAN_OPS = { "=", "!" }

-- ─────────────────────────────────────────────────────────────
-- CONDITIONS
-- Each entry: { id, label, type, needOwner, needPet, needArg, argLabel, argHint }
-- type: "boolean" | "compare" | "equality"
-- needOwner: true/false/"optional"/"not-allowed"
-- needPet:   true/false/number(slot default)
-- ─────────────────────────────────────────────────────────────
B.CONDITIONS = {
    -- HP / Health
    { id="dead",            label="Is Dead",             type="boolean",  needOwner=true,  needPet=true,  needArg=false },
    { id="hp",              label="HP (absolute)",       type="compare",  needOwner=true,  needPet=true,  needArg=false, argHint="e.g. 500" },
    { id="hpp",             label="HP (%)",              type="compare",  needOwner=true,  needPet=true,  needArg=false, argHint="e.g. 50" },
    { id="hp.full",         label="HP Full",             type="boolean",  needOwner=true,  needPet=true,  needArg=false },
    { id="hp.low",          label="HP Lower than Enemy", type="boolean",  needOwner=true,  needPet=false, needArg=false },
    { id="hp.high",         label="HP Higher than Enemy",type="boolean",  needOwner=true,  needPet=false, needArg=false },
    { id="hp.diff",         label="HP Diff vs Enemy",    type="compare",  needOwner=true,  needPet=true,  needArg=false },
    { id="hpp.diff",        label="HP% Diff vs Enemy",   type="compare",  needOwner=true,  needPet=true,  needArg=false },
    { id="hp.can_be_exploded", label="Can Be Exploded",  type="boolean",  needOwner=true,  needPet=true,  needArg=false },
    -- Abilities
    { id="ability.usable",  label="Ability Usable",      type="boolean",  needOwner=true,  needPet=true,  needArg=true,  argLabel="Ability", argHint="1, 2, or 3" },
    { id="ability.duration",label="Ability Cooldown",    type="compare",  needOwner=true,  needPet=true,  needArg=true,  argLabel="Ability", argHint="1, 2, or 3" },
    { id="ability.strong",  label="Ability is Strong",   type="boolean",  needOwner=true,  needPet=true,  needArg=true,  argLabel="Ability", argHint="1, 2, or 3" },
    { id="ability.weak",    label="Ability is Weak",     type="boolean",  needOwner=true,  needPet=true,  needArg=true,  argLabel="Ability", argHint="1, 2, or 3" },
    { id="ability.type",    label="Ability Type",        type="equality", needOwner=true,  needPet=true,  needArg=true,  argLabel="Ability", argHint="1, 2, or 3" },
    -- Auras / Buffs
    { id="aura.exists",     label="Aura Exists",         type="boolean",  needOwner=true,  needPet=true,  needArg=true,  argLabel="Aura Name", argHint="Aura name or ID" },
    { id="aura.duration",   label="Aura Duration",       type="compare",  needOwner=true,  needPet=true,  needArg=true,  argLabel="Aura Name", argHint="Aura name or ID" },
    -- Weather
    { id="weather",         label="Weather Exists",      type="boolean",  needOwner=false, needPet=false, needArg=true,  argLabel="Weather",  argHint="Weather name or ID" },
    { id="weather.duration",label="Weather Duration",    type="compare",  needOwner=false, needPet=false, needArg=true,  argLabel="Weather",  argHint="Weather name or ID" },
    -- Pet state
    { id="active",          label="Is Active Pet",       type="boolean",  needOwner=true,  needPet=true,  needArg=false },
    { id="played",          label="Has Been Played",     type="boolean",  needOwner=true,  needPet=true,  needArg=false },
    { id="exists",          label="Pet Exists",          type="boolean",  needOwner=true,  needPet=1,     needArg=false },
    { id="is",              label="Pet Is Specific",     type="boolean",  needOwner=true,  needPet=1,     needArg=true,  argLabel="Pet ID/Name", argHint="Species ID or name" },
    { id="id",              label="Pet Species ID",      type="equality", needOwner=true,  needPet=1,     needArg=false },
    -- Stats
    { id="speed",           label="Speed",               type="compare",  needOwner=true,  needPet=true,  needArg=false },
    { id="power",           label="Power",               type="compare",  needOwner=true,  needPet=true,  needArg=false },
    { id="level",           label="Level",               type="compare",  needOwner=true,  needPet=true,  needArg=false },
    { id="level.max",       label="Level Max (25)",      type="boolean",  needOwner=true,  needPet=true,  needArg=false },
    { id="speed.fast",      label="Faster than Enemy",   type="boolean",  needOwner=true,  needPet=false, needArg=false },
    { id="speed.slow",      label="Slower than Enemy",   type="boolean",  needOwner=true,  needPet=false, needArg=false },
    { id="type",            label="Pet Type",            type="equality", needOwner=true,  needPet=true,  needArg=false },
    { id="quality",         label="Quality",             type="compare",  needOwner=true,  needPet=true,  needArg=false },
    -- Collection
    { id="collected",       label="Is Collected",        type="boolean",  needOwner=true,  needPet=true,  needArg=false },
    { id="collected.count", label="Collected Count",     type="compare",  needOwner=true,  needPet=true,  needArg=false },
    -- Round / Trap
    { id="round",           label="Round Number",        type="compare",  needOwner=false, needPet=false, needArg=false },
    { id="trap",            label="Trap Available",      type="boolean",  needOwner=false, needPet=false, needArg=false },
}

-- ─────────────────────────────────────────────────────────────
-- ACTIONS
-- ─────────────────────────────────────────────────────────────
B.ACTIONS = {
    { id="ability 1", label="Use Ability 1",   hasArg=false, description="Use the first ability" },
    { id="ability 2", label="Use Ability 2",   hasArg=false, description="Use the second ability" },
    { id="ability 3", label="Use Ability 3",   hasArg=false, description="Use the third ability" },
    { id="change 1",  label="Swap to Pet 1",   hasArg=false, description="Swap active pet to slot 1" },
    { id="change 2",  label="Swap to Pet 2",   hasArg=false, description="Swap active pet to slot 2" },
    { id="change 3",  label="Swap to Pet 3",   hasArg=false, description="Swap active pet to slot 3" },
    { id="change next", label="Swap to Next",  hasArg=false, description="Swap to the next living pet" },
    { id="catch",     label="Catch (Trap)",    hasArg=false, description="Attempt to catch the enemy pet" },
    { id="standby",   label="Standby (Skip)",  hasArg=false, description="Skip this turn if possible" },
    { id="quit",      label="Forfeit Battle",  hasArg=false, description="Forfeit the pet battle" },
    { id="test",      label="Print Debug",     hasArg=true,  argLabel="Message", description="Print a debug message" },
    { id="--",        label="Comment",         hasArg=true,  argLabel="Comment text", description="A comment line" },
}

-- ─────────────────────────────────────────────────────────────
-- PET TYPES (for type / ability.type conditions)
-- ─────────────────────────────────────────────────────────────
B.PET_TYPES = {
    "Humanoid", "Dragonkin", "Flying", "Undead", "Critter",
    "Magic", "Elemental", "Beast", "Aquatic", "Mechanical",
}

-- Colour palette for rows
B.ROW_COLORS = {
    { 0.13, 0.18, 0.28, 0.95 },   -- dark blue (default)
    { 0.18, 0.28, 0.13, 0.95 },   -- dark green  (if block)
    { 0.28, 0.13, 0.13, 0.95 },   -- dark red    (comment)
}
