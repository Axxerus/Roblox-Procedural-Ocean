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
--local friction = 0
--floatPart.CustomPhysicalProperties = PhysicalProperties.new(0.7, friction, 0.5, 1, 1)
--floatPart.Parent = workspace

--local boatClone = game:GetService("ReplicatedStorage"):WaitForChild("Cutter"):Clone()
--boatClone.Parent = workspace

local wave = Wave.new(plane, {ListenToServer = true})
wave:ConnectUpdate(25)

--wave:AddFloatingPart(floatPart)
--wave:AddFloatingPart(boatClone:WaitForChild("Ballast"))
--wave:AddPlayerFloat(LocalPlayer)
