--[[
    Module that creates "WindLines", to visualize wind.
    Originaly created by boatbomber, and adapted from: https://github.com/boatbomber/WindShake
    Under the "MIT License":

    MIT License

    Copyright (c) 2021 boatbomber

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
]]

local RunService = game:GetService("RunService")
local Terrain = workspace:FindFirstChildOfClass("Terrain")

local ATTACHMENT_OFFSET = Vector3.new(0, 0.25, 0)

local module = {}

module.UpdateQueue = table.create(10)

function module:Init(Settings)
	self.settings = Settings
	-- Set defaults
	module.Lifetime = self.settings.Lifetime or 3
	module.Direction = self.settings.Direction or Vector3.new(1, 0, 0)
	module.Speed = self.settings.Speed or 6

	-- Clear any old stuff
	if module.UpdateConnection then
		module.UpdateConnection:Disconnect()
		module.UpdateConnection = nil
	end

	for _, WindLine in ipairs(module.UpdateQueue) do
		WindLine.Attachment0:Destroy()
		WindLine.Attachment1:Destroy()
		WindLine.Trail:Destroy()
	end
	table.clear(module.UpdateQueue)

	module.LastSpawned = os.clock()
	local SpawnRate = 1 / (self.settings.SpawnRate or 25)

	-- Setup logic loop
	module.UpdateConnection = RunService.Heartbeat:Connect(function()
		local Clock = os.clock()

		-- Spawn handler
		if Clock - module.LastSpawned > SpawnRate then
			module:Create()
			module.LastSpawned = Clock
		end

		-- Update queue handler
		debug.profilebegin("Update Wind Lines")
		for i, WindLine in ipairs(module.UpdateQueue) do
			local AliveTime = Clock - WindLine.StartClock
			if AliveTime >= WindLine.Lifetime then
				-- Destroy the objects
				WindLine.Attachment0:Destroy()
				WindLine.Attachment1:Destroy()
				WindLine.Trail:Destroy()

				-- unordered remove at this index
				local Length = #module.UpdateQueue
				module.UpdateQueue[i] = module.UpdateQueue[Length]
				module.UpdateQueue[Length] = nil
				continue
			end

			WindLine.Trail.MaxLength = 20 - (20 * (AliveTime / WindLine.Lifetime))

			local SeededClock = (Clock + WindLine.Seed) * (WindLine.Speed * 0.2)
			local StartPos = WindLine.Position
			WindLine.Attachment0.WorldPosition = (CFrame.new(StartPos, StartPos + WindLine.Direction) * CFrame.new(0, 0, WindLine.Speed * -AliveTime)).Position
				+ Vector3.new(
					math.sin(SeededClock) * 0.5,
					math.sin(SeededClock) * 0.8,
					math.sin(SeededClock) * 0.5
				)

			WindLine.Attachment1.WorldPosition = WindLine.Attachment0.WorldPosition + ATTACHMENT_OFFSET
		end
		debug.profileend()
	end)
end

function module:Cleanup()
	if module.UpdateConnection then
		module.UpdateConnection:Disconnect()
		module.UpdateConnection = nil
	end

	for _, WindLine in ipairs(module.UpdateQueue) do
		WindLine.Attachment0:Destroy()
		WindLine.Attachment1:Destroy()
		WindLine.Trail:Destroy()
	end
	table.clear(module.UpdateQueue)
end

function module:Create()
	debug.profilebegin("Add Wind Line")

	local Lifetime = module.Lifetime
	local Position = module.Position
		or (
				workspace.CurrentCamera.CFrame
				* CFrame.Angles(math.rad(math.random(-30, 70)), math.rad(math.random(-80, 80)), 0)
			)
			* CFrame.new(0, 0, math.random(200, 600) * -0.1).Position
	local Direction = self.settings.Direction or module.Direction
	local Speed = self.settings.Speed or module.Speed
	if Speed <= 0 then
		return
	end

	local Attachment0 = Instance.new("Attachment")
	local Attachment1 = Instance.new("Attachment")

	local Trail = Instance.new("Trail")
	local set = self.settings.TrailSettings
	Trail.Attachment0 = Attachment0
	Trail.Attachment1 = Attachment1
	Trail.WidthScale = set.WidthScale or NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.2, 1),
		NumberSequenceKeypoint.new(0.8, 1),
		NumberSequenceKeypoint.new(1, 0.3),
	})
	Trail.Transparency = set.Transparency or NumberSequence.new(0.7)
	Trail.FaceCamera = true
	Trail.Parent = Attachment0

	Attachment0.WorldPosition = Position
	Attachment1.WorldPosition = Position + ATTACHMENT_OFFSET

	local WindLine = {
		Attachment0 = Attachment0,
		Attachment1 = Attachment1,
		Trail = Trail,
		Lifetime = Lifetime + (math.random(-10, 10) * 0.1),
		Position = Position,
		Direction = Direction,
		Speed = Speed + (math.random(-10, 10) * 0.1),
		StartClock = os.clock(),
		Seed = math.random(1, 1000) * 0.1,
	}

	module.UpdateQueue[#module.UpdateQueue + 1] = WindLine

	Attachment0.Parent = Terrain
	Attachment1.Parent = Terrain

	debug.profileend()
end

return module
