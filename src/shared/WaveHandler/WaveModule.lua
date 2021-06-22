--[[
	Main module that handles waves.
]]

local RunService = game:GetService("RunService")

local REQUEST_NAME = "RequestSettings"
local CHANGED_NAME = "SettingsChanged"

-- Create remotes on server or wait for creation on client
local function createRemotes()
	local request, changed = script.Parent:FindFirstChild(REQUEST_NAME), script.Parent:FindFirstChild(CHANGED_NAME)
	if not request or not changed then
		if RunService:IsClient() then
			-- Wait for server to create remotes
			warn("Remotes have not been setup on the server yet. Waiting for creation.")
			request = script.Parent:WaitForChild(REQUEST_NAME)
			changed = script.Parent:WaitForChild(CHANGED_NAME)
		else
			-- Only create Remotes on the server
			request = Instance.new("RemoteFunction")
			request.Name = REQUEST_NAME
			request.Parent = script.Parent

			changed = Instance.new("RemoteEvent")
			changed.Name = CHANGED_NAME
			changed.Parent = script.Parent
		end
	end
	return request, changed
end

-- Get or create Remotes
local requestSettings, settingsChanged = createRemotes()

-- Modules
local parent = script.Parent
local Interpolation = require(parent:WaitForChild("InterpolateVector3")).new()
local SyncedClock = require(parent:WaitForChild("ClockSync"))

SyncedClock:Initialize()

-- Default wave settings
local default = {
	WaveLength = 100,
	Gravity = 9.81,
	Steepness = 0.4,
	Direction = Vector2.new(1, 0),
	FollowPoint = nil,
	MaxDistance = 1000,
}

local Wave = {}
Wave.__index = Wave

-- Utility for sorting settings into two tables:
-- One for general settings (apply to all waves)
-- One for wave settings (specific settings per wave)
local function sortSettings(settings)
	local waveSettings = {}
	local generalSettings = {}
	local waveCounter = 0
	for i, v in pairs(settings) do
		if typeof(v) == "table" then
			-- Insert in wave settings table
			waveSettings[i] = v
			waveCounter += 1
		else
			-- Insert in general settings table
			generalSettings[i] = v
		end
	end
	return generalSettings, waveSettings, waveCounter
end

-- Create a new Wave object
function Wave.new(instance, settings)
	-- Check types
	if typeof(instance) ~= "Instance" then
		error("Instance argument must be a valid instance!")
	end

	-- Get bones inside Model
	local bones = {}
	for _, v in pairs(instance:GetDescendants()) do
		if v:IsA("Bone") then
			table.insert(bones, v)
		end
	end

	if #bones <= 0 then
		error("No bones have been found inside the chosen model!")
	end

	-- Return metatable / "Wave" object
	local function createMeta(generalSettings, waveSettings)
		return setmetatable({
			_instance = instance,
			_bones = bones,
			_connections = {},
			_cachedVars = {},
			generalSettings = generalSettings,
			waveSettings = waveSettings,
		}, Wave)
	end

	if RunService:IsClient() then
		-- Setup for client
		if settings.ListenToServer then
			-- Listen to SERVER for getting settings
			-- Don't create settings locally

			-- Request settings from server (RemoteFunction)
			local generalSettings, waveSettings = requestSettings:InvokeServer()
			local meta
			if generalSettings and waveSettings then
				meta = createMeta(generalSettings, waveSettings)
			end

			-- Listen to server settings change (RemoteEvent)
			settingsChanged.OnClientEvent:Connect(function(newGeneralSettings, newWaveSettings, interpolationTime)
				if meta then
					meta.generalSettings = newGeneralSettings
					meta.waveSettings = newWaveSettings
				end
				-- Update cached variables
				meta:UpdateCachedVars(newGeneralSettings, newWaveSettings, interpolationTime)
			end)
			return meta
		else
			-- Get settings from settings table
			-- Effect will be LOCAL only!

			-- Sort settings
			local generalSettings, waveSettings, waveCounter = sortSettings(settings)

			if waveCounter >= 1 then
				-- Return "Wave" object
				return createMeta(generalSettings, waveSettings)
			else
				error("No Wave settings found! Make sure to follow the right format.")
			end
		end
	else
		-- Setup for server
		local generalSettings, waveSettings, waveCounter = sortSettings(settings)
		if waveCounter >= 1 then
			local meta = createMeta(generalSettings, waveSettings)

			-- Setup RemoteFunction settings request
			requestSettings.OnServerInvoke = function()
				return meta.generalSettings, meta.waveSettings
			end

			return meta
		else
			error("No Wave settings found! Make sure to follow the right format.")
		end
	end
end

-- Update settings of wave
function Wave:UpdateWaveSettings(newSettings, interpolationTime)
	interpolationTime = nil --interpolationTime or 2
	-- Sort settings
	local generalSettings, waveSettings, waveCounter = sortSettings(newSettings)
	if waveCounter <= 0 then
		warn("Updated wave settings don't contain a valid wave!")
	end
	-- Update settings and cachedVars (locally)
	self:UpdateCachedVars(generalSettings, waveSettings, interpolationTime)

	-- Send to clients
	if RunService:IsServer() then
		settingsChanged:FireAllClients(generalSettings, waveSettings, interpolationTime)
	end
end

-- Calculate final displacement sum of all Gerstner waves
function Wave:GerstnerWave(xzPos, timeOffset)
	local finalDisplacement = Vector3.new()
	-- Calculate bone displacement for every wave
	for waveName, _ in pairs(self.waveSettings) do
		-- Calculate cachedVars (if they weren't already calculated)
		if not self._cachedVars[waveName] then
			self:UpdateCachedVars(self.generalSettings, self.waveSettings)
		end

		-- Get cached variables (they don't need to be recalculated every frame)
		local cached = self._cachedVars[waveName]
		local period = cached["Period"]
		local speed = cached["WaveSpeed"]
		local dir = cached["UnitDirection"]
		local amplitude = cached["Amplitude"]

		-- Calculate displacement whilst taking into account the time offset
		local displacement
		if not timeOffset then
			displacement = (period * dir:Dot(xzPos)) + (speed * SyncedClock:GetTime())
		else
			displacement = (period * dir:Dot(xzPos)) + (speed * (SyncedClock:GetTime() + timeOffset))
		end

		-- Calculate displacement on every axis (xyz)
		local xPos = dir.X * amplitude * math.cos(displacement)
		local yPos = amplitude * math.sin(displacement) -- Y-Position is not affected by direction of wave
		local zPos = dir.Y * amplitude * math.cos(displacement)

		finalDisplacement += Vector3.new(xPos, yPos, zPos) -- Add this wave to final displacement
	end
	return finalDisplacement
end

-- Get the height of a point at a certain xz-position
function Wave:GetHeight(xzPos, timeOffset)
	-- First calculate xzPosition with offset
	local w = self:GerstnerWave(xzPos, timeOffset)
	local correctedXZPos = Vector2.new(xzPos.X + w.X, xzPos.Y + w.Z)

	-- Now calculate the height from this offset position
	local heightOffset = self:GerstnerWave(correctedXZPos, timeOffset).Y
	return heightOffset
end

-- Update cached variables used by GerstnerWave function
function Wave:UpdateCachedVars(newGeneralSettings, newWaveSettings, smoothInterpolationTime)
	-- Shorthand functions
	local function getSetting(newSetting, name)
		return newSetting[name] or newGeneralSettings[name] or default[name]
	end
	local function calculateNewvars(waveLength, gravity, direction, steepness)
		local period = (2 * math.pi) / waveLength
		local speed = math.sqrt(gravity * period)
		local dir = direction.Unit
		local amplitude = steepness / period
		return period, speed, dir, amplitude
	end

	if not smoothInterpolationTime or typeof(smoothInterpolationTime) ~= "number" then
		-- Instantly set variables
		self._cachedVars = {}
		for waveName, waveSetting in pairs(newWaveSettings) do
			-- Get settings: from this wave, from generalSettings or from default
			local waveLength = getSetting(waveSetting, "WaveLength")
			local gravity = getSetting(waveSetting, "Gravity")
			local direction = getSetting(waveSetting, "Direction")
			local steepness = getSetting(waveSetting, "Steepness")

			local period, speed, dir, amplitude = calculateNewvars(waveLength, gravity, direction, steepness)

			-- Instantly set cached variables
			self._cachedVars[waveName] = {
				Period = period,
				WaveSpeed = speed,
				UnitDirection = dir,
				Amplitude = amplitude,
			}
		end
	else
		-- TODO: make smooth transition possible
		-- Smoothly tween into new values
		-- used for tweening from previous value or from 0
		local function getCached(name)
			return self._cachedVars[name] or 0
		end
		-- Tween to new values
		for waveName, waveSetting in pairs(newWaveSettings) do
			-- Get settings: from this wave, from generalSettings or from default
			local waveLength = getSetting(waveSetting, "WaveLength")
			local gravity = getSetting(waveSetting, "Gravity")
			local direction = getSetting(waveSetting, "Direction")
			local steepness = getSetting(waveSetting, "Steepness")

			local period, speed, dir, amplitude = calculateNewvars(waveLength, gravity, direction, steepness)

			-- Calculate increments
			local frames = smoothInterpolationTime * 60
			local periodIncrement = (period - getCached("Period")) / frames
			local speedIncrement = (speed - getCached("WaveSpeed")) / frames
			--local dirIncrement = (dir - getCached("UnitDirection")) / frames
			local amplitudeIncrement = (amplitude - getCached("Amplitude")) / frames

			-- Smoothly interpolate values (on a separate thread)
			coroutine.wrap(function()
				for _ = 1, frames, 1 do
					local cached = self._cachedVars[waveName]
					self._cachedVars[waveName] = {
						Period = cached["Period"] + periodIncrement,
						WaveSpeed = cached["WaveSpeed"] + speedIncrement,
						UnitDirection = cached["UnitDirection"], --+ dirIncrement,
						Amplitude = cached["Amplitude"] + amplitudeIncrement,
					}
					RunService.Heartbeat:Wait()
				end
			end)()
		end
	end
	-- Set new settings
	self.generalSettings = newGeneralSettings
	self.waveSettings = newWaveSettings
end

-- Make a part float on the waves
function Wave:AddFloatingPart(part)
	local numberOfAttachments = 4
	local positionDrag = 0.4
	local rotationalDrag = 0.1

	if typeof(part) ~= "Instance" then
		error("Part must be a valid Instance.")
	end
	if not self._instance then
		error("Wave object not found!")
	end

	-- Create attachments (on four corners)
	local s = part.Size
	local x = s.X / 2
	local y = s.Y / 2
	local z = s.Z / 2
	local corners = {
		Vector3.new(x, -y, z),
		Vector3.new(x, -y, -z),
		Vector3.new(-x, -y, z),
		Vector3.new(-x, -y, -z),
	}
	local attachmentForces = {}
	-- Create attachments and their forces
	for index, relativePos in pairs(corners) do
		local attach = Instance.new("Attachment")
		attach.Position = relativePos
		attach.Visible = true
		attach.Name = "CornerAttachment" .. tostring(index)
		attach.Parent = part

		local force = Instance.new("VectorForce")
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.Attachment0 = attach
		force.Force = Vector3.new(0, 0, 0)
		force.Visible = false
		force.Enabled = true
		force.ApplyAtCenterOfMass = false
		force.Parent = part
		attachmentForces[attach] = force
	end

	-- Create angular drag
	local waterDragTorque = Instance.new("BodyAngularVelocity")
	waterDragTorque.AngularVelocity = Vector3.new(0, 0, 0)
	waterDragTorque.P = math.huge
	waterDragTorque.Parent = part

	-- Disable gravity for this part
	local cancelGravity = Instance.new("BodyForce")
	cancelGravity.Name = "CancelGravity"
	cancelGravity.Force = Vector3.new(0, workspace.Gravity * part.AssemblyMass, 0)
	cancelGravity.Parent = part

	local gravity = workspace.Gravity / numberOfAttachments -- Force of gravity per attachment
	-- Get axis of size that is the largest
	local largestSize = part.Size.X
	if part.Size.Y > largestSize then
		largestSize = part.Size.Y
	end
	if part.Size.Z > largestSize then
		largestSize = part.Size.Z
	end

	RunService.Stepped:Connect(function()
		local depthBeforeSubmerged = 50
		local displacementAmount = 1

		-- Force per attachment
		for attachment, force in pairs(attachmentForces) do
			local worldPos = attachment.WorldPosition
			-- Calculate wave height at the attachment's position
			local waveHeight = self._instance.Position.Y + self:GetHeight(Vector2.new(worldPos.X, worldPos.Z))
			local displacementMultiplier = math.clamp(
				(waveHeight - worldPos.Y) / depthBeforeSubmerged * displacementAmount,
				0,
				1
			)

			-- Set force of attachment
			local destForce
			local f = gravity * part.AssemblyMass
			if worldPos.Y < waveHeight then -- Check if attachment is under water
				local buoyancyForce = Vector3.new(0, f * displacementMultiplier * 15, 0)
				local dragForce = (part.AssemblyLinearVelocity * f * displacementMultiplier * positionDrag)
					/ numberOfAttachments
				destForce = buoyancyForce - dragForce
			else
				-- Object is above water, don't apply buoyancy
				destForce = Vector3.new(0, 0, 0)
			end
			-- Force of gravity on this attachment
			destForce -= Vector3.new(0, f, 0)
			force.Force = destForce
		end

		-- Angular drag
		local waveHeight = self._instance.Position.Y + self:GetHeight(Vector2.new(part.Position.X, part.Position.Z))
		local difference = (part.Position.Y - part.Size.Y / 2) - waveHeight

		-- part is inside of water
		local p = part.AssemblyAngularVelocity
		--[[ 
			Torque is Directly proportional to: 
			 	current angular velocity, 
			 	part's largest side (larger means more torque can be generated), 
			 	the part's AssemblyMass * gravity
			And is inversely proportional to:
				The difference between waveHeight and part height (Smoothly go towards zero the farther part is out of water)
		--]]
		if difference < 0 then
			-- Part is under water, don't smoothly remove rotational drag
			difference = 1
		else
			-- (middle of) part is out of water! remove rotational drag the further it goes from the water
			difference = (difference ^ 2) / 8
		end
		local destTorque = (
				Vector3.new(math.abs(p.X), math.abs(p.Y), math.abs(p.Z))
				* largestSize
				* part.AssemblyMass
				* workspace.Gravity
				/ difference
			) * rotationalDrag
		waterDragTorque.MaxTorque = destTorque

		-- Parts might have been added/removed to the assembly, so update the cancelGravity force
		cancelGravity.Force = Vector3.new(0, workspace.Gravity * part.AssemblyMass, 0)
	end)
end

function Wave:AddPlayerFloat(player)
	local char = player.Character or player.CharacterAdded:Wait()
	local rootPart = char:WaitForChild("HumanoidRootPart")
	--local humanoid = char:WaitForChild("Humanoid")

	self:AddFloatingPart(rootPart)

	-- Setup BodyForces
	-- local dirVelocity
	-- local floatPosition = Instance.new("BodyPosition")
	-- floatPosition.D = 1250
	-- floatPosition.MaxForce = Vector3.new(0, 0, 0)
	-- floatPosition.P = 10000
	-- floatPosition.Parent = rootPart

	-- -- Rootpart position at wave height
	-- local rootPartWavePos = Vector3.new(rootPart.Position.X, self._instance.Position.Y, rootPart.Position.Z)
	-- local xzPos = Vector2.new(rootPart.Position.X, rootPart.Position.Z)

	-- local connection = RunService.Heartbeat:Connect(function()
	-- 	if rootPart then
	-- 		local waveDisplacement = self:GerstnerWave(xzPos)
	-- 		local absoluteDisplacement = rootPartWavePos + waveDisplacement

	-- 		-- Check if character is underneath wave
	-- 		if rootPart.Position.Y <= waveDisplacement.Y + self._instance.Position.Y then
	-- 			if humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
	-- 				humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	-- 				humanoid:ChangeState(Enum.HumanoidStateType.Swimming, true)
	-- 			end
	-- 			-- Entered water
	-- 			if not dirVelocity then
	-- 				-- Create direction BodyVelocity
	-- 				dirVelocity = Instance.new("BodyVelocity")
	-- 				dirVelocity.Parent = rootPart
	-- 			end
	-- 			-- Only float up if no movement input
	-- 			if humanoid.MoveDirection == Vector3.new(0, 0, 0) then
	-- 				print("Enable float")
	-- 				-- Enable float
	-- 				local force = rootPart.AssemblyMass * workspace.Gravity * 25
	-- 				floatPosition.MaxForce = Vector3.new(force, force, force)
	-- 			else
	-- 				print("Disable float")
	-- 				-- Disable float
	-- 				floatPosition.MaxForce = Vector3.new(0, 0, 0)
	-- 			end
	-- 			dirVelocity.Velocity = humanoid.MoveDirection * humanoid.WalkSpeed
	-- 			floatPosition.Position = Vector3.new(
	-- 				absoluteDisplacement.X + rootPart.Position.X,
	-- 				absoluteDisplacement.Y,
	-- 				absoluteDisplacement.Z + rootPart.Position.Z
	-- 			)
	-- 		elseif math.abs(rootPart.Position.Y - waveDisplacement.Y + self._instance.Position.Y) >= 5 then
	-- 			-- Disable float if distance is great enough
	-- 			if dirVelocity then
	-- 				dirVelocity:Destroy()
	-- 				dirVelocity = nil
	-- 				humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
	-- 				floatPosition.MaxForce = Vector3.new(0, 0, 0)
	-- 			end
	-- 		end
	-- 	end
	-- end)
	-- table.insert(self._connections, connection)
end

-- Update wave's bones on Stepped (only done client-side)
function Wave:ConnectUpdate(frameDivisionCount)
	if RunService:IsClient() then
		frameDivisionCount = frameDivisionCount or 25

		-- Generate tables containing small(er) batches of bones
		local updateBonesAmount = math.round(#self._bones / frameDivisionCount)
		local batches = {}
		local batchCounter = 1
		local boneCounter = 0

		for _, bone in pairs(self._bones) do
			if not batches[batchCounter] then
				batches[batchCounter] = {}
			end
			table.insert(batches[batchCounter], bone)
			boneCounter += 1
			if boneCounter >= updateBonesAmount then
				-- Setup new batch
				boneCounter = 0
				batchCounter += 1
			end
		end

		local currentBatch = 1
		local connection = RunService.Stepped:Connect(function(_, dt)
			if currentBatch > #batches then
				-- Reset currentBatch to 1
				currentBatch = 1
			end

			-- Update this batch
			for _, bone in pairs(batches[currentBatch]) do
				local refPos = bone.WorldPosition

				local destTransform = Vector3.new()
				local camera = workspace.CurrentCamera
				if camera then
					local camPos = camera.CFrame.Position
					if camPos then
						if (camPos - refPos).Magnitude <= self.generalSettings.MaxDistance then
							-- Bone is close enough to camera; calculate offset
							local timeOffset = dt * frameDivisionCount
							destTransform = self:GerstnerWave(Vector2.new(refPos.X, refPos.Z), timeOffset)
						end
					end
				end
				if destTransform then
					Interpolation:AddInterpolation(bone, "Transform", destTransform, frameDivisionCount)
				end
			end
			currentBatch += 1
		end)

		table.insert(self._connections, connection)

		return connection
	else
		warn("The bones of your wave shouldn't be updated by the server. Call this function from the client(s)!")
	end
end

-- Destroy the Wave "object"
function Wave:Destroy()
	self._instance = nil
	-- Try to disconnect all connections and handle errors
	for _, v in pairs(self._connections) do
		local success, response = pcall(function()
			v:Disconnect()
		end)
		if not success then
			warn("Failed to destroy wave! \nError: " .. response .. " Retrying...")
			local count = 1
			repeat
				count += 1
				success, response = pcall(function()
					v:Disconnect()
				end)
			until success or count >= 10
			warn("Retrying to destroy wave, count:", count, "\nError:", response)
		end
	end

	-- Cleanup variables
	self._bones = {}
	self.generalSettings = {}
	self = nil
end

return Wave
