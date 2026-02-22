local PollinationConfig = {
	ForestCenter = Vector3.new(0, 0, 0),
	ForestRadius = 110,
	ForestInnerRadius = 20,
	FlowerCount = 70,
	MinFlowerSpacing = 7,
	FlowerStemHeight = 3,
	FlowerBloomBaseSize = 1.6,
	FlowerBloomMaxBonus = 0.9,
	FlowerNectarMin = 6,
	FlowerNectarMax = 14,
	FlowerRegenPerSecondMin = 0.8,
	FlowerRegenPerSecondMax = 1.7,
	PollinationBloomForMax = 30,
	VisualUpdateInterval = 0.2,

	HiveRingRadius = 150,
	HiveRingSpacing = 18,
	HiveSlotsPerRing = 10,
	HiveSize = Vector3.new(12, 4, 12),

	BeesPerPlayer = 5,
	BeeSpeedMin = 20,
	BeeSpeedMax = 28,
	BeeGatherMin = 2,
	BeeGatherMax = 5,
	BeeIdleCooldownMin = 0.7,
	BeeIdleCooldownMax = 2.5,
	BeeSearchCooldown = 1.2,
	BeeFlightHeight = 4,

	HoneyPerPollen = 4,
	NectarBoostOnPollination = 1.2,
	TargetFlowerMinNectar = 0.2,
}

return table.freeze(PollinationConfig)
