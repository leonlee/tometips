require 'tip.engine'
require 'lib.json4lua.json.json'

require 'data.talent_name'
require 'data.talent_type_description'
require 'data.talent_type_name'
require 'data.stat_name'
printf = function(s,...)
	return io.write(s:format(...))
 end
local Actor = require 'mod.class.Actor'	
spoilers = {
    -- Currently active parameters.  TODO: Configurable
    active = {
        mastery = 1.3,
		
        -- To simplify implementation, we use one value for stats (str, dex,
        -- etc.) and powers (physical power, accuracy, mindpower, spellpower).
        stat_power = 100,
		
        -- According to chronomancer.lua, 300 is "the optimal balance"
        paradox = 300,
		
        -- The goal is to display effectiveness at 50% of max psi.
        psi = 50,
        max_psi = 100,
    },
	alter_mastery_type = {
		["corruption/vile-life"] = 1.0,
		["cursed/cursed-aura"] = 1.0,
		["cursed/cursed-form"] = 1.0,
		["cursed/fears"] = 1.0,
		["cursed/predator"] = 1.0,
		["cursed/rampage"] = 1.0,
		["golem/fighting"] = 1.0,
		["golem/arcane"] = 1.0,
		["race/higher"] = 1.0,
		["race/dwarf"] = 1.0,
		["race/shalore"] = 1.0,
		["race/thalore"] = 1.0,
		["race/halfling"] = 1.0,
		["race/orc"] = 1.0,
		["race/yeek"] = 1.0,
		["undead/ghoul"] = 1.0,
		["undead/skeleton"] = 1.0,
		["wild-gift/harmony"] = 1.0,
		["misc/objects"] = 1.0,
		["other/other"] = 1.0,
		["other/horror"] = 1.0,
		["base/class"] = 1.0,
		["technique/objects"] = 1.0,
		["technique/other"] = 1.0,
		["technique/horror"] = 1.0,
		["golem/drolem"] = 1.0,
		["spell/objects"] = 1.0,
		["spell/other"] = 1.0,
		["spell/horror"] = 1.0,
		["wild-gift/objects"] = 1.0,
		["wild-gift/other"] = 1.0,
		["wild-gift/horror"] = 1.0,
		["corruption/other"] = 1.0,
		["corruption/horror"] = 1.0,
		["undead/other"] = 1.0,
		["undead/keepsake"] = 1.0,
		["chronomancy/other"] = 1.0,
		["psionic/other"] = 1.0,
		["psionic/horror"] = 1.0,
	},
    -- We iterate over these parameters to display the effects of a talent at
    -- different stats and talent levels.
    --
    -- determineDisabled depends on this particular layout (5 varying stats and
    -- 5 varying talent levels).
	all_active = {
        { stat_power=10,  talent_level=1},
        { stat_power=25,  talent_level=1},
        { stat_power=50,  talent_level=1},
        { stat_power=75,  talent_level=1},
        { stat_power=100, talent_level=1},
        { stat_power=100, talent_level=2}, 
        { stat_power=100, talent_level=3}, 
        { stat_power=100, talent_level=4}, 
        { stat_power=100, talent_level=5}, 
    },

    -- Merged into active whenever we're not processing per-stat /
    -- per-talent-level values.
    default_active = {
        stat = 100,
        power = 100,
        talent_level = 0,
    },

    -- Which parameters have been used for the current tooltip
    used = {
    },

    -- Paradox is a special case.  Unlike most parameter-dependent values, we
    -- only calculate for a single value of paradox.
    usedParadoxOnly = function(self)
        return #table.keys(self.used) == 1 and self.used.paradox
    end,

    -- talent, by looking at spoilers.used, the results of determineDisabled,
    -- and the results so far of generating the talent message.
    usedMessage = function(self, disable, prev_results)
        disable = disable or {}
        local msg = {}
        local use_talent = self.used.talent and not disable.talent
        if use_talent then
            if self.active.alt_talent then
                msg[#msg+1] = Actor.talents_def[self.active.alt_talent_fake_id or self.active.talent_id].name .. " 技能等级 1-5"
            else
                msg[#msg+1] = "技能等级 1-5"
            end

            if self.used.mastery then msg[#msg+1] = ("技能树等级 %.2f"):format(self.active.mastery) end
        end

        local stat_power_text
        -- As in determineDisabled, if both stats / powers and talents have an
        -- effect, hide the stats / powers to cut down on space usage.
        if use_talent then
            stat_power_text = tostring(self.active.stat_power)
        else
            stat_power_text = '10, 25, 50, 75, 100' -- HACK/TODO: Remove duplication with self.all_active
        end

        local use_stat_power = false
        if not disable.stat_power then
            for k, v in pairs(self.used.stat or {}) do
                if v then msg[#msg+1] = ("%s %s"):format(s_stat_name[Actor.stats_def[k].name] or Actor.stats_def[k].name, stat_power_text) use_stat_power = true end
            end
            if self.used.attack then msg[#msg+1] = ("命中率 %s"):format(stat_power_text) use_stat_power = true end
            if self.used.physicalpower then msg[#msg+1] = ("物理强度 %s"):format(stat_power_text) use_stat_power = true end
            if self.used.spellpower then msg[#msg+1] = ("法术强度 %s"):format(stat_power_text) use_stat_power = true end
            if self.used.mindpower then msg[#msg+1] = ("精神强度 %s"):format(stat_power_text) use_stat_power = true end
        end

        if self.used.paradox then msg[#msg+1] = ("紊乱值 %i"):format(self.active.paradox) use_stat_power = true end
		
		if self.used.psi and self.used.max_psi then
            -- MAJOR HACK: If it looks like we're in a "(max %d)" block, then
            -- don't include the psi percentage.  Also hard-code the fact that
            -- radius doesn't depend on psi percentage.
            if prev_results[#prev_results-1] ~= 'radius' and not (prev_results[#prev_results-2] == '(' and prev_results[#prev_results-1] == 'max') then
                msg[#msg+1] = ("超能力值 %i%%"):format(self.active.psi / self.active.max_psi * 100)
            end
        elseif self.used.psi or self.used.max_psi then
            -- Abort, since we won't know how to handle.
            -- We can add handling if/when ToME starts using it.
            tip.util.logError("Unexpected use of psi without max_psi or vice versa")
            os.exit(1)
        end
		
        local css_class
        if use_stat_power and use_talent then
            css_class = 'variable'
        elseif use_stat_power then
            css_class = 'stat-variable'
        else
            css_class = 'talent-variable'
        end

        return (self:usedParadoxOnly() and "以下状况下的数值\r" or "以下状况下的数值\r") .. table.concat(msg, ",\r"), css_class
    end,

    -- Looks at the results of getTalentByLevel or multiDiff (a table) to see
    -- which active parameters were actually used for a particular set of
    -- results.
    determineDisabled = function(self, results)
        assert(#results == 9)

        -- All values are the same.  It must be paradox.
        if table.allSame(results) then
            return results[1], {}

        -- Values 5-10 have varying talents.  If they're all the same,
        -- then talents have no effect.
        elseif table.allSame(results, 5, 9) then
            return table.concat(results, ', ', 1, 5), { talent = true }

        -- Values 1-5 have varying stats / powers.  If they're all the
        -- same, then stats / powers have no effect.
        elseif table.allSame(results, 1, 5) then
            return table.concat(results, ', ', 5, 9), { stat_power = true }

        -- Both stats / powers and talents have an effect, but hide the
        -- stats / powers to cut down on space usage.
        else
            return table.concat(results, ', ', 5, 9), {}
        end
    end,

    formatResults = function(self, results, prev_results)
        local new_result, disabled = self:determineDisabled(results)
        local message, css_class = self:usedMessage(disabled, prev_results)
        return '<acronym class="' .. css_class .. '" title="' .. message .. '">' .. new_result .. '</acronym>'
    end,

    blacklist_talent_type = {
--        ["technique/2hweapon-cripple"] = true, -- unavailable in this ToME version
        ["chronomancy/temporal-archery"] = true, -- unavailable in this ToME version
        ["psionic/possession"] = true,           -- unavailable in this ToME version
        ["psionic/psi-archery"] = true,          -- unavailable in this ToME version
        ["sher'tul/fortress"] = true,            -- unavailable in this ToME version
        ["tutorial"] = true,                     -- Do these even still exist?
        ["wild-gift/malleable-body"] = true,     -- unavailable in this ToME version (and not even intelligible)
        ["spell/war-alchemy"] = true,            -- Added in 1.2.0, but it only has the old fire alchemy "Heat" talent
    },

    blacklist_talent = {
        ["T_SHERTUL_FORTRESS_GETOUT"] = true,
        ["T_SHERTUL_FORTRESS_BEAM"] = true,
        ["T_SHERTUL_FORTRESS_ORBIT"] = true,
        ["T_GLOBAL_CD"] = true,                  -- aka "charms"
    }
}

local player = game.player

player.getStat = function(self, stat, scale, raw, no_inc)
    spoilers.used.stat = spoilers.used.stat or {}
    spoilers.used.stat[stat] = true

    local val = spoilers.active.stat_power
    if no_inc then
        tip.util.logError("Unsupported use of getStat no_inc")
    end

    -- Based on interface.ActorStats.getStat
    if scale then
        if not raw then
            val = math.floor(val * scale / self.stats_def[stat].max)
        else
            val = val * scale / self.stats_def[stat].max
        end
    end
    return val
end

player.combatAttack = function(self, weapon, ammo)
    spoilers.used.attack = true
    return spoilers.active.stat_power
end

player.combatPhysicalpower = function(self, mod, weapon, add)
    mod = mod or 1
    if add then
        tip.util.logError("Unsupported add to combatPhysicalpower")
    end
    spoilers.used.physicalpower = true
    return spoilers.active.stat_power * mod
end

player.combatSpellpower = function(self, mod, add)
    mod = mod or 1
    if add then
        tip.util.logError("Unsupported add to combatSpellpower")
    end
    spoilers.used.spellpower = true
    return spoilers.active.stat_power * mod
end

player.combatMindpower = function(self, mod, add)
    mod = mod or 1
    if add then
        tip.util.logError("Unsupported add to combatMindpower")
    end
    spoilers.used.mindpower = true
    return spoilers.active.stat_power * mod
end

player.getParadox = function(self)
    spoilers.used.paradox = true
    return spoilers.active.paradox
end

player.getPsi = function(self)
    spoilers.used.psi = true
    return spoilers.active.psi
end

player.getMaxPsi = function(self)
    spoilers.used.max_psi = true
    return spoilers.active.max_psi
end

player.isTalentActive = function() return false end  -- TODO: Doesn't handle spiked auras
player.hasEffect = function() return false end
player.getSoul = function() return math.huge end
player.knowTalent = function() return false end
player.getInscriptionData = function()
    return {
        inc_stat = 0,

        -- TODO: Can we use any better values for the following?
        range = 0,
        power = 0,
        dur = 0,
        heal = 0,
        effects = 0,
        speed = 0,
        heal_factor = 0,
        turns = 0,
        die_at = 0,
        mana = 0,
        apply = 0,
        radius = 0,
        what = { ["physical, mental, or magical"] = true }
    }
end
player.getTalentLevel = function(self, id)
    if type(id) == "table" then id = id.id end
    if id == spoilers.active.talent_id then
        spoilers.used.talent = true
        spoilers.used.mastery = true
        return spoilers.active.talent_level * spoilers.active.mastery
    else
        return 0
    end
end
player.getTalentLevelRaw = function(self, id)
    if type(id) == "table" then id = id.id end
    if id == spoilers.active.talent_id then
        spoilers.used.talent = true
        return spoilers.active.talent_level
    else
        return 0
    end
end

-- Overrides data/talents/psionic/psionic.lua.  TODO: Can we incorporate this at all?
function getGemLevel()
    return 0
end

require 'tip.utils'

function getByTalentLevel(actor, f)
    local result = {}

    spoilers.used = {}
    for i, v in ipairs(spoilers.all_active) do
        table.merge(spoilers.active, v)
        result[#result+1] = tostring(f())
    end
    table.merge(spoilers.active, spoilers.default_active)

    if table.allSame(result) and not spoilers:usedParadoxOnly() then
        assert(next(spoilers.used) == nil)
        return result[1]
    else
        return spoilers:formatResults(result):gsub('\r', '<br>')
    end
end

function getvalByTalentLevel(val, actor, t)
    if type(val) == "function" then
        return getByTalentLevel(actor, function() return val(actor, t) end)
    -- ToME supports random values, but we shouldn't need that.
    --elseif type(val) == "table" then
    --    return val[rng.range(1, #val)]
    else
        return val
    end
end

function getTalentReqDesc(player, t, tlev)
    -- Based on ActorTalents.getTalentReqDesc
    local new_require = {}
    local req = t.require
    spoilers.used = {}
    if type(req) == "function" then req = req(player, t) end
    if req.level then
        local v = util.getval(req.level, tlev)
        if #new_require > 0 then new_require[#new_require+1] = ', ' end
        new_require[#new_require+1] = ("等级 %d"):format(v)
    end
    if req.stat then
        for s, v in pairs(req.stat) do
            v = util.getval(v, tlev)
            if spoilers.used.stat then
                local stat = {}
                for k, s in pairs(spoilers.used.stat or {}) do
                    stat[#stat+1] = Actor.stats_def[k].name:capitalize()
                end
                if #new_require > 0 then new_require[#new_require+1] = ', ' end
                new_require[#new_require+1] = ("%s %d"):format(table.concat(stat, " or "), v)
            else
                if #new_require > 0 then new_require[#new_require+1] = ', ' end
                new_require[#new_require+1] = ("%s %d"):format(s_stat_name[player.stats_def[s].name:capitalize() ], v)
            end
        end
    end
    if req.special then
        if #new_require > 0 then new_require[#new_require+1] = '; ' end
        new_require[#new_require+1] = req.special.desc
    end
    if req.talent then
        -- Currently unimplemented (not because it's hard, but because ToME doesn't use it)
        assert(false)
    end
    return table.concat(new_require)
end

-- Process each talent, adding text descriptions of the various attributes
for tid, t in pairs(Actor.talents_def) do
    spoilers.active.talent_id = tid
	spoilers.active.mastery = spoilers.alter_mastery_type[t.type[1] ] or 1.3
    -- Special cases: Poison effects depend on the Vile Poisons talent.  Traps depend on Trap Mastery.
    spoilers.active.alt_talent = false
    spoilers.active.alt_talent_fake_id = nil
    if t.type[1] == "cunning/poisons-effects" then
        spoilers.active.talent_id = Actor.T_VILE_POISONS
        spoilers.active.alt_talent = true
    end
    if t.type[1] == "cunning/traps" then
        spoilers.active.talent_id = Actor.T_TRAP_MASTERY
        spoilers.active.alt_talent = true
    end
    -- Special case: Jumpgate's talent is tied to Jumpgate: Teleport.
    -- TODO: This is arguably a bug, since ToME can't properly report talent increases' effects either.
    if t.name:starts('Jumpgate') then
        spoilers.active.talent_id = Actor.T_JUMPGATE_TELEPORT
        spoilers.active.alt_talent = true
        spoilers.active.alt_talent_fake_id = Actor.T_JUMPGATE
    end
    -- Special case: Armour Training isn't very useful unless you're wearing armor.
    if tid == 'T_ARMOUR_TRAINING' then
        player.inven[player.INVEN_BODY][1] = { subtype = "heavy" }
    end

    -- Beginning of info text.  This is a bit complicated.
    local info_text = {}
    spoilers.used = {}
    for i, v in ipairs(spoilers.all_active) do
        table.merge(spoilers.active, v)
        info_text[i] = t.info(player, t):escapeHtml():toTString():tokenize(" ()[]")
    end
    table.merge(spoilers.active, spoilers.default_active)

    t.info_text = tip.util.multiDiff(info_text, function(s, res)
        -- Reduce digits after the decimal.
        for i = 1, #s do
            s[i] = s[i]:gsub("(%d%d+)%.(%d)%d*", function(a, b) return tonumber(b) >= 5 and tostring(tonumber(a) + 1) or a end)
        end

        res:add(spoilers:formatResults(s, res))
    end):toString()

    -- Special case: Extract Gems is too hard to format
    if t.id == Actor.T_EXTRACT_GEMS then
        spoilers.active.talent_level = 5
        t.info_text = t.info(player, t):escapeHtml()
        spoilers.active.talent_level = nil
    end
    -- Special case: Finish Armour Training.
    if tid == 'T_ARMOUR_TRAINING' then
        player.inven[player.INVEN_BODY][1] = nil
        t.info_text = t.info_text:gsub(' with your current body armour', ', assuming heavy mail armour')
    end

    -- Hack: Fix text like "increases foo by 1., 2., 3., 4., 5."
    t.info_text = t.info_text:gsub('%., ', ", ")
    t.info_text = t.info_text:gsub(',, ', ", ")

    -- Turn ad hoc lists into <ul>
    t.info_text = t.info_text:gsub('\n[lL]evel %d+ *[-:][^\n]+', function(s)
        return '<li>' .. s:sub(2) .. '</li>'
    end)
    t.info_text = t.info_text:gsub('\nAt level %d+:[^\n]+', function(s)
        return '<li>' .. s:sub(2) .. '</li>'
    end)
    t.info_text = t.info_text:gsub('\n%-[^\n]+', function(s)
        return '<li>' .. s:sub(3) .. '</li>'
    end)

    -- Turn line breaks into <p>
    t.info_text = '<p>' .. t.info_text:gsub("\n", "</p><p>") .. '</p>'

    -- Turn line breaks that we've added into normal line breaks
    t.info_text = t.info_text:gsub("\r", "<br>")

    -- Finish turning ad hoc lists into <ul>
    t.info_text = t.info_text:gsub('([^>])<li>', function(s)
        return s .. '</p><ul><li>'
    end)
    t.info_text = t.info_text:gsub('</li></p>', '</li></ul>')

    -- Add HTML character entities
    t.info_text = t.info_text:gsub('%-%-', '&mdash;')
    t.info_text = t.info_text:gsub('%.%.%.', '&hellip;')

    -- Handle font tags. Duplicated from tip.util.tstringToHtml.
    t.info_text = t.info_text:gsub('#{bold}#', '<span style="font-weight: bold"><span style="tstr-font-bold">')
    t.info_text = t.info_text:gsub('#{normal}#', '</span></span>')

    -- Ending of info text.

    t.mode = t.mode or "activated"

    if t.mode ~= "passive" then
        if t.range == Actor.talents_def[Actor.T_SHOOT].range then
            t.range = "archery"
        else
            t.range = getByTalentLevel(player, function() return ("%.1f"):format(player:getTalentRange(t)) end)

            -- Sample error handling:
            --local success, value = pcall(function() getByTalentLevel(player, function() return player:getTalentRange(t) end) end)
            --if not success then
            --    tip.util.logError(string.format("%s: range: %s\n", tid, value))
            --else
            --    t.range = value
            --end
        end
        -- Note: Not the same logic as ToME (which checks <= 1), but seems to work
        if t.range == 1 or t.range == "1" then t.range = "melee/personal" end

        -- Simple speed logic from 1.2.3 and earlier
        if not player.getTalentSpeed then
            if t.no_energy and type(t.no_energy) == "boolean" and t.no_energy == true then
                t.use_speed = "瞬间"
            else
                t.use_speed = "1 回合"
            end
        else
            -- "Usage Speed" logic from Actor:getTalentFullDescription
            local uspeed = "1 回合"
            local no_energy = util.getval(t.no_energy, player, t)
            local display_speed = util.getval(t.display_speed, player, t)
            if display_speed then
                uspeed = display_speed
            elseif no_energy and type(no_energy) == "boolean" and no_energy == true then
                uspeed = "瞬间"
            else
                local speed = player:getTalentSpeed(t)
                local speed_type = player:getTalentSpeedType(t)
                if type(speed_type) == "string" then
                    speed_type = speed_type:capitalize()
                else
                    speed_type = '特殊'
                end
                -- Actual speed value is fairly meaningless for spoilers
                --uspeed = ("%s (#LIGHT_GREEN#%d%%#LAST# of a turn)"):format(speed_type, speed * 100)
                uspeed = speed_type
            end
            t.use_speed = uspeed
        end
    end
	if t.mode == "passive" then t.mode = "被动"
	elseif t.mode == "sustained" then t.mode = "持续"
	else t.mode = "主动"
	end
    t.cooldown = getvalByTalentLevel(t.cooldown, player, t)
    local cost = {}
    for i, v in ipairs(tip.raw_resources) do
        if t[v] then
            cost[#cost+1] = string.format("%s %s", tip.resources[v], getvalByTalentLevel(t[v], player, t))
        end
    end
    if #cost > 0 then t.cost = table.concat(cost, ", ") end

    if t.image then t.image = t.image:gsub("talents/", "") end

    if t.require then
        local new_require = {}
        for tlev = 1, t.points do
            new_require[#new_require+1] = getTalentReqDesc(player, t, tlev)
        end
        t.require = new_require
        t.multi_require = t.points > 1
    end
	
	
    -- Strip unused elements in order to save space.
    t.display_entity = nil
    t.tactical = nil
    t.allow_random = nil
    t.no_npc_use = nil

    -- Find the info function, and use that to find where the talent is defined.
    --
    -- Inscriptions have their own newInscription function that sets an old_info function.
    --
    -- For other talents, engine.interface.ActorTalents:newTalent creates its own
    -- local info function based on the talent's provided info function, so we need to look
    -- for upvalues.
    local d = t.old_info and debug.getinfo(t.old_info) or tip.util.getinfo_upvalue(t.info, 'info')
    if d then
        t.source_code = tip.util.resolveSource(d)
    end
	t.chnname = t_talent_name[string.gsub(t.id, "_1", "")] or t.name;
end

-- TODO: travel speed
--        local speed = self:getTalentProjectileSpeed(t)
--        if speed then d:add({"color",0x6f,0xff,0x83}, "Travel Speed: ", {"color",0xFF,0xFF,0xFF}, ""..(speed * 100).."% of base", true)
--        else d:add({"color",0x6f,0xff,0x83}, "Travel Speed: ", {"color",0xFF,0xFF,0xFF}, "instantaneous", true)
--        end

-- TODO: Special cases:
-- Golem's armor reconfiguration depends on armor mastery
-- Values that depend only on a stat - Wave of Power's range, prodigies - can these be improved?

-- Helper functions for organizing ToME's data for output
function shouldSkipTalent(t)
    -- Remove blacklisted and hide = "always" talents and five of the six copies of inscriptions.
    return spoilers.blacklist_talent[t.id] or
        (t.hide == 'always' and t.id ~= 'T_ATTACK') or
        (t.is_inscription and t.id:match('.+_[2-9]')) or
        shouldSkipPsiTalent(t)
end

-- Implementation for shouldSkipTalent: skip psionic talents that were hidden
-- and replaced but not actually removed in 1.2.0.
function shouldSkipPsiTalent(t)
    return t.hide == true and t.type[1]:starts("psionic/") and t.autolearn_mindslayer
end

-- Reorganize ToME's data for output
local talents_by_category = {}
local talent_categories = {}
printf("%d\n", table.getn(Actor.talents_types_def["chronomancy/other"].talents) )
for k, v in pairs(Actor.talents_types_def) do
    -- talent_types_def is indexed by both number and name.
    -- We only want to print by name.
    -- Also support blacklisting unavailable talent types.
    if type(k) ~= 'number' and not spoilers.blacklist_talent_type[k] then
        if next(v.talents) ~= nil then   -- skip talent categories with no talents

            -- This modifies the real in-memory talents table, but we shouldn't need the original version...
            for i = #v.talents, 1, -1 do
                if shouldSkipTalent(v.talents[i]) then
                    table.remove(v.talents, i)
                end
            end

            local category = k:split('/')[1]
            talents_by_category[category] = talents_by_category[category] or {}
            table.insert(talents_by_category[category], v)
            talent_categories[category] = true
        end
    end
	v.chnname = t_talent_type_name[v.name] or v.name
	v.chndescription = t_talent_type_description[v.description] or v.description
end
cate_order_id = {}
type_order_id = {}
for k, v in pairs(Actor.talents_types_def) do
	if type(k) == 'number' then
		cate_order_id[v.type:split('/')[1] ] = k
		--io.write(string.format("%s %d\n", v.type, k))
		type_order_id[v.type] = k
	end
end
talent_categories = table.keys(talent_categories)
table.sort(talent_categories, function(a, b) return cate_order_id[a] < cate_order_id[b] end)
chn_talent_categories = {}
for k, v in pairs(talent_categories) do
	chn_talent_categories[v] = t_talent_cat[v] or v
end
for k, v in pairs(talents_by_category) do
    table.sort(v, function(a, b) 
		--io.write(string.format("%s %s\n", k .. "/" .. a.name, k .. "/" .. b.name))
		return (type_order_id[a.type] or 10000) < (type_order_id[b.type] or 10000)
	end)
end

-- Output the data
local output_dir = tip.outputDir()

local out = io.open(output_dir .. 'tome.json', 'w')
out:write(json.encode({
    -- Official ToME tag in git.net-core.org to link to.
    tag = tip.git_tag,

    version = tip.version,

    talent_categories = talent_categories,
	
	chn_talent_categories = chn_talent_categories,
}))
out:close()

for k, v in pairs(talents_by_category) do
    local out = io.open(output_dir .. 'talents.'..k:gsub("[']", "_")..'.json', 'w')
    out:write(json.encode(v))
    out:close()
end

