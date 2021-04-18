local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local plane = workspace:WaitForChild("Ocean"):WaitForChild("Plane")
local floatPart = workspace:WaitForChild("FloatingPart")

--local STEEPNESS = 1 -- Number from 0 to 1
local GRAVITY = 9.81 -- Used to calculate wave speed (automatically / relative to wave height)
local bones = {}
local positions = {}

floatPart.Position = Vector3.new(floatPart.Position.X, plane.Position.Y, floatPart.Position.Z)

local origPartPos = floatPart.Position

-- Get bones
for _, v in pairs(plane:GetDescendants()) do
	if v:IsA("Bone") then
		table.insert(bones, v)
	end
end

-- Store WorldPosition
for _, bone in pairs(bones) do
	positions[bone] = bone.WorldPosition
end

local function GerstnerWave(xzPos, waveLength, steepness, direction)
	local k = (2 * math.pi) / waveLength
	local speed = math.sqrt(GRAVITY / k)
	local dir = direction.Unit
	local f = k * (dir:Dot(xzPos) - speed * os.clock())

	-- Calculate displacement (direction)
	local amplitude = steepness / k
	local xPos = dir.X * (amplitude * math.cos(f))
	local yPos = amplitude * math.sin(f) -- Y-Position is not affected by direction of wave
	local zPos = dir.Y * (amplitude * math.cos(f))

	return Vector3.new(xPos, yPos, zPos)
end

-- Only calculate height at point (no xz-displacement)
local function GerstnerHeight(xzPos, waveLength, steepness, direction)
    local k = (2 * math.pi) / waveLength
	local speed = math.sqrt(GRAVITY / k)
	local dir = direction.Unit
	local f = k * (dir:Dot(xzPos) - speed * os.clock())

	local amplitude = steepness / k
	local yPos = amplitude * math.sin(f)
	return yPos
end

RunService.Heartbeat:Connect(function(dt)
	-- Update wave position
    local startTime = os.clock()
	for _, bone in pairs(bones) do
		local pos = Vector2.new(positions[bone].X, positions[bone].Z)
		local offset1 = GerstnerWave(pos, 200, 0.25, Vector2.new(-50, -50))
		local offset2 = GerstnerWave(pos, 50, 0.4, Vector2.new(25, -25))
		local offset3 = GerstnerWave(pos, 5, 1, Vector2.new(-25, -15))
		bone.Transform = CFrame.new(offset1 + offset2 + offset3)
	end
    print("Operation took " .. os.clock() - startTime .. " seconds.")

    local pos = Vector2.new(floatPart.Position.X, floatPart.Position.Z)
    -- Update floating part position
	local height1 = GerstnerHeight(pos, 200, 0.25, Vector2.new(-50, -50))
	local height2 = GerstnerHeight(pos, 50, 0.4, Vector2.new(25, -25))
	local height3 = GerstnerHeight(pos, 8, 1, Vector2.new(-25, -15))

    local displacement = Vector3.new(origPartPos.X, height1 + height2 + height3, origPartPos.Z)

    TweenService:Create(floatPart, TweenInfo.new(dt), {Position = origPartPos + displacement}):Play()
end)