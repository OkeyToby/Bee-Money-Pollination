local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DataService = {}
DataService.__index = DataService

local PROFILE_STORE_NAME = "BeeForestPollinationProfiles_v2"

local DEFAULT_PROFILE = {
    Coins = 0,
    ZoneLevel = 1,
    OwnedBees = { "BasicPollinator" },
    EquippedBees = { "BasicPollinator" },
    Upgrades = {
        MoreFlowers = 0,
        SoilQuality = 0,
        HiveCapacity = 0,
        PollenBoost = 0,
    },
    LifetimePollination = 0,
    LifetimeCoins = 0,
    ActiveBoosts = {},
}

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}
    for key, nested in pairs(value) do
        result[key] = deepCopy(nested)
    end
    return result
end

local function mergeDefaults(defaults, loaded)
    local profile = deepCopy(defaults)
    if type(loaded) ~= "table" then
        return profile
    end

    for key, value in pairs(loaded) do
        if type(profile[key]) == "table" and type(value) == "table" then
            for nestedKey, nestedValue in pairs(value) do
                profile[key][nestedKey] = nestedValue
            end
        else
            profile[key] = value
        end
    end

    if type(profile.OwnedBees) ~= "table" then
        profile.OwnedBees = { "BasicPollinator" }
    end
    if type(profile.EquippedBees) ~= "table" or #profile.EquippedBees == 0 then
        profile.EquippedBees = { "BasicPollinator" }
    end

    return profile
end

function DataService.new()
    local self = setmetatable({}, DataService)
    self._profiles = {}
    self._memoryProfiles = {}
    self._profileStore = nil

    local success, profileStoreOrError = pcall(function()
        return DataStoreService:GetDataStore(PROFILE_STORE_NAME)
    end)

    if success then
        self._profileStore = profileStoreOrError
    else
        local reason = tostring(profileStoreOrError)
        local message = string.format(
            "[DataService] DataStore unavailable, using in-memory profiles for this server: %s",
            reason
        )

        if RunService:IsStudio() and string.find(string.lower(reason), "publish this place", 1, true) then
            print(message)
        else
            warn(message)
        end
    end

    return self
end

function DataService:GetProfile(player)
    return self._profiles[player]
end

function DataService:LoadProfile(player)
    local key = string.format("user_%d", player.UserId)
    local loaded = nil

    if self._profileStore then
        local success, result = pcall(function()
            return self._profileStore:GetAsync(key)
        end)

        if success then
            loaded = result
        else
            warn("[DataService] Load failed", player.UserId, result)
        end
    else
        loaded = self._memoryProfiles[key]
    end

    local profile = mergeDefaults(DEFAULT_PROFILE, deepCopy(loaded))
    self._profiles[player] = profile
    self._memoryProfiles[key] = deepCopy(profile)
    return profile
end

function DataService:SaveProfile(player)
    local profile = self._profiles[player]
    if not profile then
        return
    end

    local key = string.format("user_%d", player.UserId)
    self._memoryProfiles[key] = deepCopy(profile)

    if self._profileStore then
        local success, err = pcall(function()
            self._profileStore:SetAsync(key, profile)
        end)

        if not success then
            warn("[DataService] Save failed", player.UserId, err)
        end
    end
end

function DataService:BindLifecycle()
    Players.PlayerAdded:Connect(function(player)
        self:LoadProfile(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        self:SaveProfile(player)
        self._profiles[player] = nil
    end)

    game:BindToClose(function()
        for _, player in ipairs(Players:GetPlayers()) do
            self:SaveProfile(player)
        end
    end)
end

return DataService
