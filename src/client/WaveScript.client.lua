local Players = game:GetService("Players")

local common = game:GetService("ReplicatedStorage"):WaitForChild("Common")
local Wave = require(common:WaitForChild("WaveHandler"):WaitForChild("WaveModule"))
local WindLines = require(common:WaitForChild("WindLines"))

-- Create WindLines
WindLines:Init({
	Direction = Vector3.new(1, 0, 0.5),
	Speed = 18,
	Lifetime = 8,
	SpawnRate = 8,
	TrailSettings = {
		WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.4, 0.4),
			NumberSequenceKeypoint.new(0.7, 1),
			NumberSequenceKeypoint.new(1, 0.3),
		}),
	},
})

local plane = workspace:WaitForChild("Ocean"):WaitForChild("Plane")
local LocalPlayer = Players.LocalPlayer

local floatPart = Instance.new("Part")
floatPart.Size = Vector3.new(30, 8, 20)
floatPart.Material = Enum.Material.WoodPlanks
floatPart.Color = Color3.fromRGB(65, 36, 17)
local friction = 0
floatPart.CustomPhysicalProperties = PhysicalProperties.new(0.7, friction, 0.5, 1, 1)
floatPart.Parent = workspace

local calm = {
	Gravity = 7,
	MaxDistance = 500,
	Wave1 = {
		WaveLength = 100,
		Steepness = 0.15,
		Direction = Vector2.new(1, 0),
	},
	Wave2 = {
		WaveLength = 200,
		Steepness = 0.25,
		Direction = Vector2.new(0, 0.75),
	},
	Wave3 = {
		WaveLength = 125,
		Steepness = 0.25,
		Direction = Vector2.new(0.25, -0.3),
	},
}
local storm = {
	Gravity = 9.81,
	MaxDistance = 500,
	Wave1 = {
		WaveLength = 150,
		Steepness = 0.4,
		Direction = Vector2.new(-1, -1),
	},
	Wave2 = {
		WaveLength = 75,
		Steepness = 0.4,
		Direction = Vector2.new(1, -5),
	},
	Wave3 = {
		WaveLength = 250,
		Steepness = 0.25,
		Direction = Vector2.new(1, 0),
	},
}
local tsunami = {
	Gravity = 9.81,
	MaxDistance = 500,
	Wave = {
		WaveLength = 500,
		Steepness = 0.6,
		Direction = Vector2.new(1, 0),
	},
	Wave2 = {
		WaveLength = 150,
		Steepness = 0.35,
		Direction = Vector2.new(1, -0.75),
	},
}

local boatClone = game:GetService("ReplicatedStorage"):WaitForChild("Cutter"):Clone()
boatClone.Parent = workspace

local wave = Wave.new(plane, calm)
wave:ConnectUpdate(true)

wave:AddFloatingPart(floatPart)
wave:AddFloatingPart(boatClone:WaitForChild("Ballast"))
wave:AddPlayerFloat(LocalPlayer)
