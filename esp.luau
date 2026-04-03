local esp = ESP.new({
	MaxDistance = 1500,
	BoxColor = Color3.fromRGB(255, 80, 80),
	TextColor = Color3.fromRGB(255, 255, 255),
	DistanceColor = Color3.fromRGB(255, 220, 120),
})

esp:TrackPlayers({
	Preset = "Player",
})

esp:AddFolder(workspace.Enemies, {
	Preset = "Character",
	Whitelist = { "Boss", "Guard" },
})

esp:AddFolder(workspace.Loot, {
	Preset = "Object",
	BoxColor = Color3.fromRGB(0, 255, 127),
	Name = true,
	Distance = false,
})

esp:AddToBlacklist("FriendlyNPC")
esp:AddToBlacklist(game.Players.SomePlayer)

esp:Start()
