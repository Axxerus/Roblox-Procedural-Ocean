local WaveModule = require(game:GetService("ReplicatedStorage").Common.WaveHandler.WaveModule)

local plane = workspace.Ocean.Plane
local boat = workspace.Cutter

local waveSettings = {
	Calm = {
		Gravity = 7,
		MaxDistance = 500,
		Wave1 = {
			WaveLength = 50,
			Steepness = 0.2,
			Direction = Vector2.new(1, 0),
		},
		Wave2 = {
			WaveLength = 100,
			Steepness = 0.1,
			Direction = Vector2.new(0, 0.75),
		},
		Wave3 = {
			WaveLength = 75,
			Steepness = 0.15,
			Direction = Vector2.new(0.25, -0.3),
		},
	},
	Storm = {
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
	},
	Tsunami = {
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
	},
}

-- Create a new wave object on the server
local wave = WaveModule.new(plane, waveSettings["Calm"])

local part = boat.Ballast
part:SetNetworkOwner(nil)
wave:AddFloatingPart(part)
