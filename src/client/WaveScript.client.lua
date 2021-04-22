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

local wave = Wave.new(plane, {ListenToServer = true})
wave:ConnectUpdate(25)
