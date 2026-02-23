local EconomyService = {}
EconomyService.__index = EconomyService

function EconomyService.new(dataService)
    local self = setmetatable({}, EconomyService)
    self._dataService = dataService
    return self
end

function EconomyService:GetCoins(player)
    local profile = self._dataService:GetProfile(player)
    return profile and profile.Coins or 0
end

function EconomyService:AddCoins(player, amount, reason)
    if type(amount) ~= "number" or amount <= 0 then
        return false
    end

    local profile = self._dataService:GetProfile(player)
    if not profile then
        return false
    end

    local rounded = math.floor(amount)
    profile.Coins += rounded
    profile.LifetimeCoins += rounded

    return true, profile.Coins
end

function EconomyService:TrySpendCoins(player, amount)
    if type(amount) ~= "number" or amount <= 0 then
        return false
    end

    local profile = self._dataService:GetProfile(player)
    if not profile then
        return false
    end

    local rounded = math.floor(amount)
    if profile.Coins < rounded then
        return false
    end

    profile.Coins -= rounded
    return true, profile.Coins
end

return EconomyService
