local ZoneService = {}
ZoneService.__index = ZoneService

local ZONES = {
    [1] = { id = "MossyGrove", unlockCost = 0, flowerValueMultiplier = 1.0, speedBoost = 1.0 },
    [2] = { id = "PineHollow", unlockCost = 1200, flowerValueMultiplier = 1.25, speedBoost = 1.05 },
    [3] = { id = "RiverGlade", unlockCost = 3200, flowerValueMultiplier = 1.55, speedBoost = 1.2 },
}

function ZoneService.new(dataService, economyService)
    local self = setmetatable({}, ZoneService)
    self._dataService = dataService
    self._economyService = economyService
    return self
end

function ZoneService:GetZoneLevel(player)
    local profile = self._dataService:GetProfile(player)
    return profile and profile.ZoneLevel or 1
end

function ZoneService:GetZoneConfig(level)
    return ZONES[level] or ZONES[1]
end

function ZoneService:GetCurrentZoneConfig(player)
    return self:GetZoneConfig(self:GetZoneLevel(player))
end

function ZoneService:TryUnlockNextZone(player)
    local profile = self._dataService:GetProfile(player)
    if not profile then
        return false, "Profile missing"
    end

    local current = profile.ZoneLevel
    if current >= #ZONES then
        return false, "All zones unlocked"
    end

    local nextZone = ZONES[current + 1]
    local spent = self._economyService:TrySpendCoins(player, nextZone.unlockCost)
    if not spent then
        return false, "Not enough coins"
    end

    profile.ZoneLevel = current + 1
    return true, {
        zoneLevel = profile.ZoneLevel,
        zoneId = nextZone.id,
        coins = profile.Coins,
    }
end

return ZoneService
