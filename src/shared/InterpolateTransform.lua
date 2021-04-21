--[[
	Module that handles interpolation of bones.
	This is done so that work can be divided over several frames, 
	instead of recalculating every bones' offset every frame.

	TweenService seems to be quite laggy / unreliable when tweening large amounts of bones very frequently.
	This module resolves that.
]]

local RunService = game:GetService("RunService")

local Interpolate = {}
Interpolate.__index = Interpolate

function Interpolate.new()
	local meta = setmetatable({
		_connections = {},
		_bones = {},
	}, Interpolate)

	-- Setup connection
	local connection = RunService.Heartbeat:Connect(function()
		meta:Update()
	end)
	table.insert(meta._connections, connection)

	return meta
end

-- Add a transform interpolation for a bone
function Interpolate:AddInterpolation(bone, destPos, frames)
    local increment = (destPos - bone.Transform.Position) / frames
	self._bones[bone] = {
		Increment = increment,
		ElapsedFrames = 0,
        MaxFrames = frames,
	}
end

-- Update all transformations
function Interpolate:Update()
	for bone, settings in pairs(self._bones) do
		if bone and settings then
			if settings.ElapsedFrames > settings.MaxFrames then
                -- Clear bone from table
				self._bones[bone] = nil
			else
                -- Transform bone smoothly based on amount of frames animation has to take
				bone.Transform += settings.Increment
				settings.ElapsedFrames += 1
			end
		end
	end
end

-- Disconnect all functions and destroy "Interpolate" object
function Interpolate:Destroy()
	for _, v in pairs(self._connections) do
		if v then
			v:Disconnect()
		end
	end
	self = nil
end

return Interpolate
