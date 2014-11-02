tip = tip or {}
tip.version = arg[1]
package.path = package.path..(';%s/?.lua;./%s/thirdparty/?.lua'):format(tip.version, tip.version)

tip.outputDir = function()
    local output_dir = (arg[2] or '.') .. '/'
    print("OUTPUT DIRECTORY: " .. output_dir)
    os.execute('mkdir -p ' .. output_dir)
    return output_dir
end

require 'tip.utils'

-- T-Engine's C core.  Unimplemented as much as possible.
local surface_metatable = { __index = {} }
local font_metatable = { __index = {} }
__uids = {}
core = {
    display = {
        newSurface = function(x, y)
            local result = {}
            setmetatable(result, surface_metatable)
            return result
        end,
        newFont = function(font, size, no_cache)
            local result = { size = function(s) return 1 end, lineSkip = function() return 1 end }
            setmetatable(result, font_metatable)
            return result
        end,
    },
    fov = {},
    game = {},
    shader = {},
}
fs = {
    exists = function(path)
        --io.stderr:write(string.format("fs.exists(%s)\n", path))
        return false
    end,
    list = function(path)
        --io.stderr:write(string.format("fs.list(%s)\n", path))
        return {}
    end,
}

-- rng functions.  Shouldn't be needed (descriptions should be static), but
-- bugs and exceptions exist.
rng = {
    percent = function(chance) tip.util.logError('bad function rng.percent called') return false end,
    avg = function(min, max, size) tip.util.logError('bad function rng.avg called') return (min + max) / 2 end,
}

game = {
    level = {
        data = {},
        entities = {},
    },
    party = {
        hasMember = function(actor) return false end,
    },
}

-- Load init.lua and get version number.  Based on Module.lua.
local mod = { config={ settings={} } }
local mod_def = loadfile(tip.version .. '/mod/init.lua')
setfenv(mod_def, mod)
mod_def()

tip.git_tag = tip.version == 'master' and tip.version or ('tome-%s'):format(tip.version)
if not tip.git_tag then
    io.stderr:write(('Unable to determine Git tag from requested version "%s"\n'):format(tip.version))
    os.exit(1)
end

local old_loadfile = loadfile
loadfile = function(file)
    return old_loadfile(tip.version .. file)
end

function loadfile_and_execute(file)
    f = loadfile(file)
    assert(f)
    f()
end
load = loadfile_and_execute

require 'engine.dialogs.Chat'


require 'engine.utils'
local DamageType = require "engine.DamageType"
local ActorStats = require "engine.interface.ActorStats"
local ActorResource = require "engine.interface.ActorResource"
local ActorTalents = require 'engine.interface.ActorTalents'
local ActorInventory = require "engine.interface.ActorInventory"
local Birther = require 'engine.Birther'
-- FIXME: Figure out where these should go and what they should do
resolvers = {
    equip = function() end,
    inscriptions = function() end,
    levelup = function() end,
    mbonus = function() end,
    nice_tile = function() end,
    racial = function() end,
    rngavg = function() end,
    sustains_at_birth = function() end,
    tactic = function() end,
    talents = function() end,
    tmasteries = function() end,
    generic = function() end,
    genericlast = function() end,

    -- For race and class descriptors - may be useful to process these
    -- to show starting inventory
    inscription = function() end,
    inventory = function() end,
    equipbirth = function() end,
    inventorybirth = function() end,
}

config.settings.tome = {}

function setDefaultProjector()
end

load("/engine/colors.lua")

-- Body parts - copied from ToME's load.lua
ActorInventory:defineInventory("MAINHAND", "In main hand", true, "Most weapons are wielded in the main hand.", nil, {equipdoll_back="ui/equipdoll/mainhand_inv.png"})
ActorInventory:defineInventory("OFFHAND", "In off hand", true, "You can use shields or a second weapon in your off-hand, if you have the talents for it.", nil, {equipdoll_back="ui/equipdoll/offhand_inv.png"})
ActorInventory:defineInventory("PSIONIC_FOCUS", "Psionic focus", true, "Object held in your telekinetic grasp. It can be a weapon or some other item to provide a benefit to your psionic powers.", nil, {equipdoll_back="ui/equipdoll/psionic_inv.png", etheral=true})
ActorInventory:defineInventory("FINGER", "On fingers", true, "Rings are worn on fingers.", nil, {equipdoll_back="ui/equipdoll/ring_inv.png"})
ActorInventory:defineInventory("NECK", "Around neck", true, "Amulets are worn around the neck.", nil, {equipdoll_back="ui/equipdoll/amulet_inv.png"})
ActorInventory:defineInventory("LITE", "Light source", true, "A light source allows you to see in the dark places of the world.", nil, {equipdoll_back="ui/equipdoll/light_inv.png"})
ActorInventory:defineInventory("BODY", "Main armor", true, "Armor protects you from physical attacks. The heavier the armor the more it hinders the use of talents and spells.", nil, {equipdoll_back="ui/equipdoll/body_inv.png"})
ActorInventory:defineInventory("CLOAK", "Cloak", true, "A cloak can simply keep you warm or grant you wondrous powers should you find a magical one.", nil, {equipdoll_back="ui/equipdoll/cloak_inv.png"})
ActorInventory:defineInventory("HEAD", "On head", true, "You can wear helmets or crowns on your head.", nil, {equipdoll_back="ui/equipdoll/head_inv.png"})
ActorInventory:defineInventory("BELT", "Around waist", true, "Belts are worn around your waist.", nil, {equipdoll_back="ui/equipdoll/belt_inv.png"})
ActorInventory:defineInventory("HANDS", "On hands", true, "Various gloves can be worn on your hands.", nil, {equipdoll_back="ui/equipdoll/hands_inv.png"})
ActorInventory:defineInventory("FEET", "On feet", true, "Sandals or boots can be worn on your feet.", nil, {equipdoll_back="ui/equipdoll/boots_inv.png"})
ActorInventory:defineInventory("TOOL", "Tool", true, "This is your readied tool, always available immediately.", nil, {equipdoll_back="ui/equipdoll/tool_inv.png"})
ActorInventory:defineInventory("QUIVER", "Quiver", true, "Your readied ammo.", nil, {equipdoll_back="ui/equipdoll/ammo_inv.png"})
ActorInventory:defineInventory("GEM", "Socketed Gems", true, "Socketed gems.", nil, {equipdoll_back="ui/equipdoll/gem_inv.png"})
ActorInventory:defineInventory("QS_MAINHAND", "Second weapon set: In main hand", false, "Weapon Set 2: Most weapons are wielded in the main hand. Press 'x' to switch weapon sets.", true)
ActorInventory:defineInventory("QS_OFFHAND", "Second weapon set: In off hand", false, "Weapon Set 2: You can use shields or a second weapon in your off-hand, if you have the talents for it. Press 'x' to switch weapon sets.", true)
ActorInventory:defineInventory("QS_PSIONIC_FOCUS", "Second weapon set: psionic focus", false, "Weapon Set 2: Object held in your telekinetic grasp. It can be a weapon or some other item to provide a benefit to your psionic powers. Press 'x' to switch weapon sets.", true)
ActorInventory:defineInventory("QS_QUIVER", "Second weapon set: Quiver", false, "Weapon Set 2: Your readied ammo.", true)

-- Copied from ToME's load.lua
DamageType:loadDefinition("/data/damage_types.lua")

ActorTalents:loadDefinition("/data/talents.lua")
if tip.version ~= "1.2.3" then	
	damDesc = function(self, type, dam)
		-- Increases damage
		if self.inc_damage then
			local inc = self:combatGetDamageIncrease(type)
			dam = dam + (dam * inc / 100)
		end
		return dam
	end
	ActorTalents:loadDefinition("/../tome-ashes-urhrok/data/talents/misc/races.lua")
	ActorTalents:loadDefinition("/../tome-ashes-urhrok/data/talents/corruptions/corruptions.lua")
	t_talent_name = t_talent_name or {}
	dofile("tome-chn123-/data/talents/talents.lua")
end

-- Actor resources - copied from ToME's load.lua
ActorResource:defineResource("Air", "air", nil, "air_regen", "Air capacity in your lungs. Entities that need not breath are not affected.")
ActorResource:defineResource("Stamina", "stamina", ActorTalents.T_STAMINA_POOL, "stamina_regen", "Stamina represents your physical fatigue. Each physical ability used reduces it.")
ActorResource:defineResource("Mana", "mana", ActorTalents.T_MANA_POOL, "mana_regen", "Mana represents your reserve of magical energies. Each spell cast consumes mana and each sustained spell reduces your maximum mana.")
ActorResource:defineResource("Equilibrium", "equilibrium", ActorTalents.T_EQUILIBRIUM_POOL, "equilibrium_regen", "Equilibrium represents your standing in the grand balance of nature. The closer it is to 0 the more balanced you are. Being out of equilibrium will negatively affect your ability to use Wild Gifts.", 0, false)
ActorResource:defineResource("Vim", "vim", ActorTalents.T_VIM_POOL, "vim_regen", "Vim represents the amount of life energy/souls you have stolen. Each corruption talent requires some.")
ActorResource:defineResource("Positive", "positive", ActorTalents.T_POSITIVE_POOL, "positive_regen", "Positive energy represents your reserve of positive power. It slowly decreases.")
ActorResource:defineResource("Negative", "negative", ActorTalents.T_NEGATIVE_POOL, "negative_regen", "Negative energy represents your reserve of negative power. It slowly decreases.")
ActorResource:defineResource("Hate", "hate", ActorTalents.T_HATE_POOL, "hate_regen", "Hate represents the level of frenzy of a cursed soul.")
ActorResource:defineResource("Paradox", "paradox", ActorTalents.T_PARADOX_POOL, "paradox_regen", "Paradox represents how much damage you've done to the space-time continuum. A high Paradox score makes Chronomancy less reliable and more dangerous to use but also amplifies the effects.", 0, false)
ActorResource:defineResource("Psi", "psi", ActorTalents.T_PSI_POOL, "psi_regen", "Psi represents the power available to your mind.")
ActorResource:defineResource("Soul", "soul", ActorTalents.T_SOUL_POOL, "soul_regen", "Soul fragments you have extracted from your foes.", 0, 10)

-- Actor stats - copied from ToME's load.lua
ActorStats:defineStat("Strength",     "str", 10, 1, 100, "Strength defines your character's ability to apply physical force. It increases your melee damage, damage done with heavy weapons, your chance to resist physical effects, and carrying capacity.")
ActorStats:defineStat("Dexterity",    "dex", 10, 1, 100, "Dexterity defines your character's ability to be agile and alert. It increases your chance to hit, your ability to avoid attacks, and your damage with light or ranged weapons.")
ActorStats:defineStat("Magic",        "mag", 10, 1, 100, "Magic defines your character's ability to manipulate the magical energy of the world. It increases your spell power, and the effect of spells and other magic items.")
ActorStats:defineStat("Willpower",    "wil", 10, 1, 100, "Willpower defines your character's ability to concentrate. It increases your mana, stamina and PSI capacity, and your chance to resist mental attacks.")
ActorStats:defineStat("Cunning",      "cun", 10, 1, 100, "Cunning defines your character's ability to learn, think, and react. It allows you to learn many worldly abilities, and increases your mental capabilities and chance of critical hits.")
ActorStats:defineStat("Constitution", "con", 10, 1, 100, "Constitution defines your character's ability to withstand and resist damage. It increases your maximum life and physical resistance.")
-- Luck is hidden and starts at half max value (50) which is considered the standard
ActorStats:defineStat("Luck",         "lck", 50, 1, 100, "Luck defines your character's fortune when dealing with unknown events. It increases your critical strike chance, your chance of random encounters, ...")

-- Birther descriptor - copied from ToME's load.lua
Birther:loadDefinition("/data/birth/descriptors.lua")

tip.raw_resources = {'mana', 'soul', 'stamina', 'equilibrium', 'vim', 'positive', 'negative', 'hate', 'paradox', 'psi', 'feedback', 'fortress_energy', 'sustain_mana', 'sustain_stamina', 'sustain_equilibrium', 'sustain_vim', 'drain_vim', 'sustain_positive', 'sustain_negative', 'sustain_hate', 'sustain_paradox', 'sustain_psi', 'sustain_feedback' }

tip.resources = {}
tip.resources['mana'] =  '法力消耗：'
tip.resources['soul'] =  '灵魂消耗: '
tip.resources['stamina'] =  '体力消耗： '
tip.resources['equilibrium'] =  '自然失衡值消耗： '
tip.resources['vim'] =  '活力值消耗： '
tip.resources['positive'] =  '正能量消耗： '
tip.resources['negative'] =  '负能量消耗： '
tip.resources['hate'] =  '仇恨值消耗：  '
tip.resources['paradox'] =  '紊乱值消耗： '
tip.resources['psi'] =  '意念力消耗： '
tip.resources['feedback'] =  '反馈值消耗： '
tip.resources['fortress_energy'] =  '堡垒能量值消耗： '
tip.resources['sustain_mana'] =  '持续法力消耗： '
tip.resources['sustain_stamina'] =  '持续体力消耗： '
tip.resources['sustain_equilibrium'] =  '持续失衡值消耗： '
tip.resources['sustain_vim'] =  '持续活力值消耗： '
tip.resources['drain_vim'] =  '每回合活力值消耗: '
tip.resources['sustain_positive'] =  '持续正能量消耗： '
tip.resources['sustain_negative'] =  '持续负能量消耗： '
tip.resources['sustain_hate'] =  '持续仇恨值消耗：  '
tip.resources['sustain_paradox'] =  '持续紊乱值消耗： '
tip.resources['sustain_psi'] =  '持续意念力消耗： '
tip.resources['sustain_feedback'] =  '持续反馈值消耗： '

local Actor = require 'mod.class.Actor'
local player = Actor.new{
    combat_mindcrit = 0, -- Shouldn't be needed; see http://forums.te4.org/viewtopic.php?f=42&t=39888
    body = { INVEN = 1000, QS_MAINHAND = 1, QS_OFFHAND = 1, MAINHAND = 1, OFFHAND = 1, FINGER = 2, NECK = 1, LITE = 1, BODY = 1, HEAD = 1, CLOAK = 1, HANDS = 1, BELT = 1, FEET = 1, TOOL = 1, QUIVER = 1, QS_QUIVER = 1 },
    wards = {},
    preferred_paradox = 0,
}
game.player = player


-- table.mapv was added in newer versions of T-Engine's utils.lua.
-- Copy its implementation and add it to older versions if needed.
if not table.mapv then
    -- Make a new table with each k, v = k, f(v) in the original.
    function table.mapv(f, source)
        local result = {}
        for k, v in pairs(source) do
            result[k] = f(v)
        end
        return result
    end
end


if tip.version ~= "1.2.3" then
	Birther:loadDefinition("/../tome-ashes-urhrok/data/birth/doomelf.lua")
	Birther:loadDefinition("/../tome-ashes-urhrok/data/birth/races_cosmetic.lua")
	Birther:loadDefinition("/../tome-ashes-urhrok/data/birth/corrupted.lua")
end