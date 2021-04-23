--[[
	Clock sync version 2.0
	Should be a lot more stable on high latency situations; also a lot simpler. 
	
	2/7/21 Fluffmiceter

    Source: https://github.com/Kenji-Shore/Roblox-Client-Server-Time-Sync-Module
    DevForum post: https://devforum.roblox.com/t/high-precision-clock-syncing-tech-between-clients-and-server-with-accuracy-of-1ms/769346

    Slightly adapted from source. (mostly for convenience / consistency to other scripts)
]]

local remoteName = "ClockSyncRemote"

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local module = {}

local function createRemote()
	local remote = script.Parent:FindFirstChild(remoteName)
	if not remote then
		if RunService:IsClient() then
			-- Wait for remote on the client(s)
			warn("Remote has not been setup on the server yet. Waiting for creation.")
			remote = script.Parent:WaitForChild(remoteName)
		else
			-- Create remote on the server
			remote = Instance.new("RemoteEvent")
			remote.Name = remoteName
			remote.Parent = script.Parent
		end
	end
	return remote
end

local clockSyncSignal = createRemote()

local isClient = RunService:IsClient()

--Not recommended to use this on the client upon join because it takes a few seconds to calibrate.
-- The initial values may be extremely off.
-- OverwriteTick is a os.clock() value you can pass in if you want to figure out the synced time at an earlier point in time.
function module:GetTime(overwriteTick)
	if isClient then
		return (overwriteTick or os.clock()) + self.ServerOffset
	else
		return (overwriteTick or os.clock())
	end
end

if isClient then
	-- Setup client
	function module:OnClientEvent(serverSentTick, delayVal)
		self.TimeDelay = delayVal
		self.LastSentTick = serverSentTick
		self.ReceiveTick = os.clock()
	end

	function module:AddOffsetValue(newOffsetValue)
		self.ServerOffsetBuffer[#self.ServerOffsetBuffer + 1] = newOffsetValue
		if #self.ServerOffsetBuffer > 50 then
			table.remove(self.ServerOffsetBuffer, 1)
		end

		self.LastOffset = self.ServerOffset
		local count = #self.ServerOffsetBuffer
		local sum = 0
		local taken = {}
		local total = ((count < 50) and count) or (count - 10)
		for _ = 1, total do
			local smallestDiff, smallestIndex
			for j = 1, count do
				if not taken[j] then
					local diff = math.abs(self.ServerOffsetBuffer[j] - self.LastOffset)
					if not smallestDiff or (diff < smallestDiff) then
						smallestDiff = diff
						smallestIndex = j
					end
				end
			end
			taken[smallestIndex] = true
			sum += self.ServerOffsetBuffer[smallestIndex]
		end

		self.ServerOffset = sum / total
	end
else
	-- Setup server
	function module:PlayerAdded(player)
		self.TimeDelays[player] = 0
	end

	function module:PlayerRemoving(player)
		self.TimeDelays[player] = nil
	end

	function module:OnServerEvent(player, originalSentTick, processingDelay)
		if self.TimeDelays[player] then
			local roundTripTime = os.clock() - originalSentTick
			self.TimeDelays[player] = 0.5 * (roundTripTime - processingDelay)
		end
	end
end

-- Update offset, hook this to RunService.Heartbeat for proper operation.
function module:Heartbeat(step)
	if isClient then
		self.ReplicationPressure = self.ReplicationPressure * 0.8 + (self.Tally / step) * 0.2
		self.Tally = 0

		if self.LastSentTick then
			-- We do not modify the serverOffset value when we are experiencing sufficiently high network load.
			-- This is also experienced on game join, so don't expect a synced time for the first few seconds upon joining.
			if self.ReplicationPressure < self.Threshold then
				local currentTick = os.clock()
				-- Add current client tick to offset value to get the synced time, aka os.clock() of the server at that instant.
				local newOffsetValue = (self.LastSentTick + self.TimeDelay) - currentTick

				self:AddOffsetValue(newOffsetValue)

				clockSyncSignal:FireServer(self.LastSentTick, currentTick - self.ReceiveTick)
			end
			self.LastSentTick = nil
		end
	else
		for _, player in ipairs(Players:GetPlayers()) do
			if self.TimeDelays[player] then
				clockSyncSignal:FireClient(player, os.clock(), self.TimeDelays[player])
			end
		end
	end
end

-- Initialize clock and setup connections
function module:Initialize()
	RunService.Heartbeat:connect(function(step)
		self:Heartbeat(step)
	end)

	if isClient then
		self.LastOffset = nil
		self.ServerOffset = 0

		self.ServerOffsetBuffer = {}
		self.LastSentTick = nil
		self.ReceiveTick = nil
		self.TimeDelay = nil

		self.Tally = 0
		self.ReplicationPressure = 0
		self.Threshold = 100

		clockSyncSignal.OnClientEvent:connect(function(...)
			self:OnClientEvent(...)
		end)

		game.DescendantAdded:Connect(function()
			self.Tally += 1
		end)
	else
		self.TimeDelays = {}

		Players.PlayerAdded:connect(function(player)
			self:PlayerAdded(player)
		end)

		Players.PlayerRemoving:connect(function(player)
			self:PlayerRemoving(player)
		end)

		clockSyncSignal.OnServerEvent:connect(function(...)
			self:OnServerEvent(...)
		end)
	end
end

return module
