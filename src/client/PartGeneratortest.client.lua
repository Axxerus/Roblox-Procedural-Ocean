--[[local Players = game:GetService("Players")

------------------------------------------------------------------------------------------------------------------------------------------------

local BASE_HEIGHT = 10 -- The main height factor for the terrain.
local CHUNK_SCALE = 1 -- The grid scale for terrain generation. Should be kept relatively low if used in real-time.
local RENDER_DISTANCE = 25 -- The length/width of chunks in voxels that should be around the player at all times
local X_SCALE = 90 / 4 -- How much we should strech the X scale of the generation noise
local Z_SCALE = 90 / 4 -- How much we should strech the Z scale of the generation noise
local GENERATION_SEED = math.random() -- Seed for determining the main height map of the terrain.

------------------------------------------------------------------------------------------------------------------------------------------------

local chunks = {}

local function roundToOdd(n)
	return math.floor(n - n % 3)
end

local function chunkExists(chunkX, chunkZ)
	if not chunks[chunkX] then
		chunks[chunkX] = {}
	end
	return chunks[chunkX][chunkZ]
end

local function mountLayer(x, heightY, z, material)
	local beginY = -BASE_HEIGHT
	local endY = heightY
	local cframe = CFrame.new(x * 3 + 1, roundToOdd((beginY + endY) * 3 / 1), z * 3 + 1)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CFrame = cframe
	p.Size = Vector3.new(3, 3, 3)
	p.Material = material
	p.BrickColor = BrickColor.new("Forest green")
	p.Parent = workspace
end

local function makeChunk(chunkX, chunkZ)
	chunks[chunkX][chunkZ] = true -- Acknowledge the chunk's existance.
	for x = 0, CHUNK_SCALE - 1 do
		for z = 0, CHUNK_SCALE - 1 do
			local cx = (chunkX * CHUNK_SCALE) + x
			local cz = (chunkZ * CHUNK_SCALE) + z
			local noise = math.noise(GENERATION_SEED, cx / X_SCALE, cz / Z_SCALE)
			local cy = noise * BASE_HEIGHT
			mountLayer(cx, cy, cz, Enum.Material.Grass)
		end
	end
end

local function checkSurroundings(location)
	local chunkX, chunkZ = math.floor(location.X / 3 / CHUNK_SCALE), math.floor(location.Z / 3 / CHUNK_SCALE)
	local range = math.max(1, RENDER_DISTANCE / CHUNK_SCALE)
	for x = -range, range do
		for z = -range, range do
			local cx = chunkX + x
			local cz = chunkZ + z
			if not chunkExists(cx, cz) then
				makeChunk(cx, cz)
			end
		end
	end
end

game:GetService("RunService").Heartbeat:Connect(function()
	if Players.LocalPlayer.Character then
		local humanoidRootPart = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			checkSurroundings(humanoidRootPart.Position)
		end
	end
end)]]
