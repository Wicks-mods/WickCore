-- WickCore
-- Restrict.lua — Midnight-rule awareness.
--
-- On Forever the player's own health, power, ratings and totems become secret
-- values in combat, and aura queries do not go secret, they throw. Anything
-- that reads player state routes through here so it goes quiet the moment a
-- restriction activates and comes back when it clears.

local ADDON = ...
local Core = LibStub("WickCore-1.0", true)
if not Core or Core._sourceAddon ~= ADDON then return end

local R = {}
Core.Restrict = R

local RA    = rawget(_G, "C_RestrictedActions")
local TYPES = rawget(_G, "Enum") and Enum.AddOnRestrictionType or nil

R.hasSecrets = Core.Client.hasSecrets
R.KINDS = { "Combat", "Encounter", "ChallengeMode", "PvPMatch", "Map", "Chat" }

-- Reverse map enum value -> name for the state-change event payload.
local byValue = {}
if TYPES then
    for name, value in pairs(TYPES) do byValue[value] = name end
end

function R:IsSecret(v)
    local f = rawget(_G, "issecretvalue")
    if not f then return false end
    local ok, s = pcall(f, v)
    return ok and s == true
end

-- Is a restriction type active right now. Combat is also combat lockdown:
-- TBC 2.5.6 has the restriction API and never restricts anything, yet a
-- fight is still a fight for every frame that must not be touched in one.
function R:IsActive(kind)
    local active = false
    if RA and RA.IsAddOnRestrictionActive and TYPES and TYPES[kind] ~= nil then
        local ok, v = pcall(RA.IsAddOnRestrictionActive, TYPES[kind])
        if ok then active = (v == true) end
    end
    if kind == "Combat" and not active then
        return InCombatLockdown() and true or false
    end
    return active
end

function R:IsCombat() return self:IsActive("Combat") end

function R:AnyActive()
    for _, kind in ipairs(self.KINDS) do
        if self:IsActive(kind) then return true, kind end
    end
    return false
end

-- Auras on a secrets client cannot be read under combat, encounter, keystone
-- or PvP restrictions. The call raises rather than returning a secret.
function R:AurasBlocked()
    if not self.hasSecrets then return false end
    return self:IsActive("Combat") or self:IsActive("Encounter")
        or self:IsActive("ChallengeMode") or self:IsActive("PvPMatch")
end

function R:CooldownsSecret()
    local S = rawget(_G, "C_Secrets")
    if S and S.ShouldCooldownsBeSecret then
        local ok, v = pcall(S.ShouldCooldownsBeSecret)
        if ok then return v == true end
    end
    return false
end

function R:ChatBlocked()
    local CI = rawget(_G, "C_ChatInfo")
    if CI and CI.InChatMessagingLockdown then
        local ok, v = pcall(CI.InChatMessagingLockdown)
        if ok and v then return true end
    end
    return self:IsActive("Chat")
end

-- Run fn only when auras are readable, swallowing the secret-access error.
-- Returns nil, reason when it could not run.
function R:Guard(fn, ...)
    if self:AurasBlocked() then return nil, "restricted" end
    local r = Core.pack(pcall(fn, ...))
    if not r[1] then return nil, tostring(r[2]) end
    return unpack(r, 2, r.n)
end

-- Return v unless it is secret, in which case return fallback.
function R:Plain(v, fallback)
    if self:IsSecret(v) then return fallback end
    return v
end

function R:Summary()
    local active = {}
    for _, kind in ipairs(self.KINDS) do
        if self:IsActive(kind) then active[#active + 1] = kind end
    end
    return string.format("secrets %s, active: %s, auras %s, cooldowns %s",
        self.hasSecrets and "on" or "off",
        #active > 0 and table.concat(active, ",") or "none",
        self:AurasBlocked() and "blocked" or "readable",
        self:CooldownsSecret() and "secret" or "readable")
end

-- ============================================================
-- Change notifications
-- ============================================================
-- R:OnChange(function(kind, active) ... end)

R.callbacks = R.callbacks or {}

function R:OnChange(fn)
    self.callbacks[#self.callbacks + 1] = fn
end

local function fire(kind, active)
    for i = 1, #R.callbacks do
        local ok, err = pcall(R.callbacks[i], kind, active)
        if not ok and Core.debug then Core.Print("WickCore", "restriction callback: " .. tostring(err)) end
    end
end

-- What the client refused, and what it refused to do.
--
-- Two different things arrive here. Blocked is tainted execution
-- reaching a protected function, and it writes a taint log line.
-- Forbidden is a call an addon may not make at all: no taint, no log
-- entry, and the popup does not name the function. This event does,
-- and nothing in the suite was listening, so the one fact that ends
-- the guessing was being thrown away each time it happened.
R.refusals = {}

local function noteRefusal(kind, addon, fn)
    if type(addon) ~= "string" or addon:sub(1, 4) ~= "Wick" then return end
    fn = tostring(fn or "an unnamed call")
    local key = kind .. " " .. addon .. " " .. fn
    if R.refusals[key] then
        R.refusals[key].count = R.refusals[key].count + 1
        return
    end
    R.refusals[key] = { kind = kind, addon = addon, fn = fn, count = 1 }
    -- Once per distinct call, and only with /wickcore debug on: the record
    -- is always kept for /wickcore refused, but a player's chat frame is
    -- not where a protected-function name belongs.
    if Core.debug then
        Core.Print("WickCore", ("%s was %s from %s. Tell Wick: this is the name the popup will not give you.")
            :format(addon, kind == "forbidden" and "forbidden" or "blocked", fn))
    end
end

function R:Refusals()
    local out = {}
    for _, r in pairs(self.refusals) do out[#out + 1] = r end
    table.sort(out, function(a, b) return a.fn < b.fn end)
    return out
end

local frame = CreateFrame("Frame")
pcall(frame.RegisterEvent, frame, "ADDON_ACTION_FORBIDDEN")
pcall(frame.RegisterEvent, frame, "ADDON_ACTION_BLOCKED")
pcall(frame.RegisterEvent, frame, "ADDON_RESTRICTION_STATE_CHANGED")
-- Combat lockdown is watched on every client. Forever announces combat
-- through the restriction event as well, so the two are folded into one
-- Combat notification: it fires on a change of state, whichever event
-- carried the news.
pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_ENABLED")

R.inCombat = false
local function combatChanged()
    local now = R:IsCombat()
    if now == R.inCombat then return end
    R.inCombat = now
    fire("Combat", now)
end

frame:SetScript("OnEvent", function(_, event, a, b)
    if event == "ADDON_ACTION_FORBIDDEN" then
        noteRefusal("forbidden", a, b)
    elseif event == "ADDON_ACTION_BLOCKED" then
        noteRefusal("blocked", a, b)
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
        -- a = AddOnRestrictionType value, b = AddOnRestrictionState (0 inactive)
        local kind = byValue[a] or tostring(a)
        if kind == "Combat" then combatChanged() else fire(kind, b ~= 0) end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        combatChanged()
    end
end)
