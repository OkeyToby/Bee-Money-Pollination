local UpgradeService = {}
UpgradeService.__index = UpgradeService

local UPGRADE_CONFIG = {
    MoreFlowers = { baseCost = 120, growth = 1.6, maxLevel = 6 },
    SoilQuality = { baseCost = 160, growth = 1.7, maxLevel = 10 },
    HiveCapacity = { baseCost = 240, growth = 1.8, maxLevel = 6 },
    PollenBoost = { baseCost = 200, growth = 1.65, maxLevel = 10 },
}

function UpgradeService.new(dataService, economyService)
    local self = setmetatable({}, UpgradeService)
    self._dataService = dataService
    self._economyService = economyService
    return self
end

function UpgradeService:GetUpgradeLevel(player, upgradeId)
    local profile = self._dataService:GetProfile(player)
    if not profile then
        return 0
    end

    return profile.Upgrades[upgradeId] or 0
end

function UpgradeService:GetUpgradeCost(player, upgradeId)
    local config = UPGRADE_CONFIG[upgradeId]
    if not config then
        return nil
    end

    local level = self:GetUpgradeLevel(player, upgradeId)
    return math.floor(config.baseCost * (config.growth ^ level))
end

function UpgradeService:GetHiveCapacity(player)
    return 1 + self:GetUpgradeLevel(player, "HiveCapacity")
end

function UpgradeService:GetSoilMultiplier(player)
    return 1 + (self:GetUpgradeLevel(player, "SoilQuality") * 0.2)
end

function UpgradeService:GetPollenMultiplier(player)
    return 1 + (self:GetUpgradeLevel(player, "PollenBoost") * 0.15)
end

function UpgradeService:GetUnlockedFlowerCount(player)
    return 2 + self:GetUpgradeLevel(player, "MoreFlowers")
end

function UpgradeService:BuyUpgrade(player, upgradeId)
    local config = UPGRADE_CONFIG[upgradeId]
    if not config then
        return false, "Unknown upgrade"
    end

    local profile = self._dataService:GetProfile(player)
    if not profile then
        return false, "Profile missing"
    end

    local level = profile.Upgrades[upgradeId] or 0
    if level >= config.maxLevel then
        return false, "Max level"
    end

    local cost = self:GetUpgradeCost(player, upgradeId)
    local spent = self._economyService:TrySpendCoins(player, cost)
    if not spent then
        return false, "Not enough coins"
    end

    profile.Upgrades[upgradeId] = level + 1
    return true, {
        upgradeId = upgradeId,
        newLevel = profile.Upgrades[upgradeId],
        coins = profile.Coins,
        spent = cost,
    }
end

return UpgradeService
