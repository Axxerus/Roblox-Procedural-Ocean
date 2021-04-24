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
		instances = {},
	}, Interpolate)

	-- Setup connection
	local connection = RunService.Heartbeat:Connect(function()
		meta:Update()
	end)
	table.insert(meta._connections, connection)

	return meta
end

-- Add interpolation for an instance
function Interpolate:AddInterpolation(instance, property, destPos, frames)
    local increment
	if typeof(instance[property]) == "CFrame" then
		-- For bones
		increment = (destPos - instance[property].Position) / frames
	else
		increment = (destPos - instance[property]) / frames
	end
	self.instances[instance] = {
		Increment = increment,
		ElapsedFrames = 0,
        MaxFrames = frames,
		Property = property,
	}
end

-- Update all transformations
function Interpolate:Update()
	for instance, settings in pairs(self.instances) do
		if instance and settings then
			if settings.ElapsedFrames > settings.MaxFrames then
                -- Clear instance from table
				self.instances[instance] = nil
			else
                -- Increment property and elapsed frame
				instance[settings.Property] += settings.Increment
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
