local Talented = Talented
local min = math.min
local max = math.max

local COORDS = {
	branch = {
		top = { left = 0.12890625, width = 0.125, height = 0.96875 },
		left = { left = 0.2578125, width = 0.125 },
		topright = { left = 0.515625, width = 0.125 },
		topleft = { left = 0.640625, width = -0.125 },
	},
	arrow = {
		top = { left = 0, width = 0.5 },
		left = { left = 0.5, width = 0.5 },
		right = { left = 1.0, width = -0.5 },
	},
}

local function SetTextureCoords(object, type, subtype)
	local coords = COORDS[type] and COORDS[type][subtype]
	if not coords then return end

	local left = coords.left
	local right = left + coords.width
	local bottom = coords.height or 1

	object:SetTexCoord(left, right, 0, bottom)
end

local function DrawVerticalLine(list, parent, offset, base_row, base_column, row, column)
	if column ~= base_column then return false end
	local talentButtonSize = parent.talentButtonSize
	for i = row+1, base_row-1 do
		local x, y = offset(i, column, parent)
		local branch = Talented:MakeBranch(parent)
		branch:SetPoint("TOPLEFT", x, y + talentButtonSize)
		list[#list + 1] = branch
		SetTextureCoords(branch, "branch", "top")
		branch = Talented:MakeBranch(parent)
		branch:SetPoint("TOPLEFT", x, y)
		list[#list + 1] = branch
		SetTextureCoords(branch, "branch", "top")
	end
	local x, y = offset(base_row, base_column, parent)
	local branch = Talented:MakeBranch(parent)
	branch:SetPoint("TOPLEFT", x, y + talentButtonSize / 2 + 1)
	list[#list + 1] = branch
	SetTextureCoords(branch, "branch", "top")
	local arrow = Talented:MakeArrow(parent)
	SetTextureCoords(arrow, "arrow", "top")
	arrow:SetPoint("TOPLEFT", x, y + talentButtonSize / 2 - 2)
	list[#list + 1] = arrow

	return true
end

local function DrawHorizontalLine(list, parent, offset, base_row, base_column, row, column)
	if row ~= base_row then return false end
	local talentButtonSize = parent.talentButtonSize
	for i = min(base_column, column)+1, max(base_column, column)-1 do
		local x, y = offset(row, i, parent)
		local branch = Talented:MakeBranch(parent)
		branch:SetPoint("TOPLEFT", x - talentButtonSize, y)
		list[#list + 1] = branch
		SetTextureCoords(branch, "branch", "left")
		branch = Talented:MakeBranch(parent)
		branch:SetPoint("TOPLEFT", x, y)
		list[#list + 1] = branch
		SetTextureCoords(branch, "branch", "left")
	end
	local x, y = offset(base_row, base_column, parent)
	local branch = Talented:MakeBranch(parent)
	list[#list + 1] = branch
	SetTextureCoords(branch, "branch", "left")
	local arrow = Talented:MakeArrow(parent)
	if base_column < column then
		SetTextureCoords(arrow, "arrow", "right")
		arrow:SetPoint("TOPLEFT", x + talentButtonSize / 2 + 4, y)
		branch:SetPoint("TOPLEFT", x + talentButtonSize, y - 2)
	else
		SetTextureCoords(arrow, "arrow", "left")
		arrow:SetPoint("TOPLEFT", x - talentButtonSize / 2 + 2, y)
		branch:SetPoint("TOPLEFT", x - talentButtonSize + 1, y)
	end
	list[#list + 1] = arrow
	return true
end

local function DrawHorizontalVerticalLine(list, parent, offset, base_row, base_column, row, column)
	local min_row, max_row, min_column, max_column
	--[[
	FIXME : I need to check if this line is possible and return false if not.
	Note that for the current trees, it's never impossible.
	]]
	local talentButtonSize = parent.talentButtonSize

	if base_column < column then
		min_column = base_column + 1
		max_column = column - 1
	else
		min_column = column + 1
		max_column = base_column - 1
	end

	for i = min_column, max_column do
		local x, y = offset(row, i, parent)
		local branch = Talented:MakeBranch(parent)
		branch:SetPoint("TOPLEFT", x - talentButtonSize, y - 2)
		list[#list + 1] = branch
		SetTextureCoords(branch, "branch", "left")
		branch = Talented:MakeBranch(parent)
		branch:SetPoint("TOPLEFT", x, y - 2)
		list[#list + 1] = branch
		SetTextureCoords(branch, "branch", "left")
	end

	local x, y = offset(row, base_column, parent)
	local branch = Talented:MakeBranch(parent)
	branch:SetPoint("TOPLEFT", x + 2, y - 2)
	list[#list + 1] = branch
	local branch2 = Talented:MakeBranch(parent)
	SetTextureCoords(branch2, "branch", "left")
	list[#list + 1] = branch2
	if base_column < column then
		branch2:SetPoint("TOPLEFT", x + talentButtonSize + 3, y - 2)
		SetTextureCoords(branch, "branch", "topleft")
	else
		branch2:SetPoint("TOPLEFT", x - talentButtonSize + 3, y - 2)
		SetTextureCoords(branch, "branch", "topright")
	end

	for i = row+1, base_row-1 do
		local x, y = offset(i, base_column, parent)
		local branch = Talented:MakeBranch(parent)
		branch:SetPoint("TOPLEFT", x + 2, y + talentButtonSize)
		list[#list + 1] = branch
		SetTextureCoords(branch, "branch", "top")
		branch = Talented:MakeBranch(parent)
		branch:SetPoint("TOPLEFT", x + 2, y)
		list[#list + 1] = branch
		SetTextureCoords(branch, "branch", "top")
	end

	x, y = offset(base_row, base_column, parent)
	branch = Talented:MakeBranch(parent)
	branch:SetPoint("TOPLEFT", x + 2, y + talentButtonSize)
	list[#list + 1] = branch
	SetTextureCoords(branch, "branch", "top")
	local arrow = Talented:MakeArrow(parent)
	SetTextureCoords(arrow, "arrow", "top")
	arrow:SetPoint("TOPLEFT", x + 2, y + talentButtonSize / 2)
	list[#list + 1] = arrow

	return true
end

local function DrawVerticalHorizontalLine(list, parent, offset, base_row, base_column, row, column)
	--[[
	FIXME : I need to check if this line is possible and return false if not.
	Note that it should never be impossible.

	Also, I need to really implement it.
	]]
	return true
end

function Talented.DrawLine(...)
--~ 	Talented:Print("DrawLine", ...)
	return DrawVerticalLine(...) or
		DrawHorizontalLine(...) or
		DrawHorizontalVerticalLine(...) or
		DrawVerticalHorizontalLine(...)
end
