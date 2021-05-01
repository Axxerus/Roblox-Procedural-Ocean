local DEBOUNCE_TIME = 4
local CHANGE_RADIUS = 100

local debounce = 0
local updateInProgress = false
local partTable = {}
-- Standard configuration (indexes of table):
-- 1 = TopLeft
-- 2 = TopMiddle
-- 3 = TopRight
-- 4 = MiddleLeft
-- 5 = MiddleMiddle (reference)
-- 6 = MiddleRight
-- 7 = BottomLeft
-- 8 = BottomMiddle
-- 9 = BottomRight
local folder = Instance.new("Folder")
folder.Name = "SeaParts"
folder.Parent = workspace

-- Return positions around referencePosition (only for squares)
local function positionsAroundReference(refPos, length)
	return {
		[1] = refPos + Vector3.new(-length, 0, length),
		[2] = refPos + Vector3.new(0, 0, length),
		[3] = refPos + Vector3.new(length, 0, length),
		[4] = refPos + Vector3.new(-length, 0, 0),
		[5] = refPos,
		[6] = refPos + Vector3.new(length, 0, 0),
		[7] = refPos + Vector3.new(-length, 0, -length),
		[8] = refPos + Vector3.new(0, 0, -length),
		[9] = refPos + Vector3.new(length, 0, -length),
	}
end

-- Create a part at the specified position
local function createPart(source, pos)
	local part = source:Clone()
	part.Position = pos
	part.Name = "Clone"
	part.Parent = workspace
	return part
end

-- Update the positions of parts (first do some checks)
local function updatePartTable(sourcePart)
	if updateInProgress then
		return
	end
	-- Check debounce
	if debounce <= 0 then
		debounce = DEBOUNCE_TIME
	else
		return
	end
	print("Update")
	updateInProgress = true

	-- Get new positions
	local newPositions = positionsAroundReference(sourcePart)

	local newTable = {}
	for index, newPos in pairs(newPositions) do
		if index == 5 then
			-- Use sourcePart in the middle
			newTable[index] = sourcePart
			newTable[index].Color = Color3.fromRGB(255, 0, 0)
		else
			for _, part in pairs(folder:GetChildren()) do
				if (part.Position - newPos).Magnitude <= 0.25 then
					-- This already created part has the position we want!
					newTable[index] = part
				end
			end

			if not newTable[index] then
				-- Create a new part
				newTable[index] = createPart(newPos)
			end
		end
	end

	-- Update partsTable
	for i, v in pairs(newTable) do
		partTable[i] = v
	end

	updateInProgress = false
end

local module = {}

-- Setup for Tiles around source
function module.Setup(sourcePart, detectionRadius)
	--sourcePart.Parent = folder

	-- Create parts around source
	for i, newPos in pairs(positionsAroundReference(sourcePart.Position, sourcePart.Size.X)) do
		if i == 5 then
			-- Use source part
			partTable[i] = sourcePart
		else
			-- First set, create part
			partTable[i] = createPart(sourcePart, newPos)
		end
	end

	CHANGE_RADIUS = sourcePart.Size.X / 4

	-- Create folder
	folder = Instance.new("Folder")
	folder.Name = "SeaParts"
	folder.Parent = workspace
end

-- Run this function on Heartbeat or Stepped
function module.SteppedFunction(dt)
	debounce -= dt

	local char = game:GetService("Players").LocalPlayer.Character
	if char then
		local rootPart = char:FindFirstChild("HumanoidRootPart")
		if rootPart and partTable[5] then
			-- Vector pointing from middle part to HumanoidRootPart (Vector2)
			local distance = (Vector2.new(rootPart.Position.X, rootPart.Position.Z) - Vector2.new(
				partTable[5].Position.X,
				partTable[5].Position.Z
			)).Magnitude

			-- Get closest part to player
			local closestPart
			local closestDistance = math.huge
			for i, part in pairs(partTable) do
				if i ~= 5 then -- Don't use middle part
					local newDistance = (Vector2.new(part.Position.X, part.Position.Z) - Vector2.new(
						rootPart.Position.X,
						rootPart.Position.Z
					)).Magnitude
					if newDistance < closestDistance then -- If part is closer (by a margin)
						closestPart = part
						closestDistance = newDistance
					end
				end
			end

			if distance > CHANGE_RADIUS then
				-- Player has walked further than max distance --> update parts
				updatePartTable(closestPart)
			end
		end
	end
end

-- Destroy parts
function module.Destroy()
	for _, v in pairs(folder:GetChildren()) do
		if v then
			v:Destroy()
		end
	end
	partTable = {}
end

return module
