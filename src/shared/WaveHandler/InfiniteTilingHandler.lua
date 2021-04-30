local DEBOUNCE_TIME = 4
local CHANGE_RADIUS = 100

local debounce = 0
local connection
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
	part.Parent = folder
	return part
end

-- Update the positions of parts (first do some checks)
local function updatePartTable(refPos)
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
	local newPositions = positionsAroundReference(refPos, partTable[5].Size.X)

	-- Move parts to new positions
	for i, newPos in pairs(newPositions) do
		partTable[i].Position = Vector3.new(newPos.X, partTable[i].Position.Y, newPos.Z) -- Only move in xz-plane
	end
	updateInProgress = false
end

local module = {}

-- Setup for Tiles around source
function module.Setup(sourcePart)
	sourcePart.Parent = folder
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
end

-- Run this function on Heartbeat or Stepped. Returns true if parts have been moved.
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

			if distance > CHANGE_RADIUS then
				-- Player has walked further than max distance --> update parts
				updatePartTable(rootPart.Position)
				return true
			end
		end
	end
end

-- Disconnect update function and destroy parts
function module.Destroy()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	for _, v in pairs(partTable) do
		if v then
			v:Destroy()
		end
	end
	partTable = {}
end

return module
