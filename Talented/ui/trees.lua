local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local Talented = Talented

local L = LibStub("AceLocale-3.0"):GetLocale("Talented")

local function CreateTexture(base, layer, path, blend, inherit, subLevel)
	local t = base:CreateTexture(nil, layer, inherit, subLevel)
	if path then t:SetTexture(path) end
	if blend then t:SetBlendMode(blend)	end
	return t
end

local trees = Talented.Pool:new()

local function ClearBranchButton_OnClick (self)
	local parent = self:GetParent()
	if parent.view then
		parent.view:ClearTalentTab(parent.tab)
	else
		Talented:ClearTalentTab(self:GetParent().tab)
	end
end

local function Button_OnEnter (self)
	local parent = self:GetParent()
	parent.view:SetTooltipInfo(self, parent.tab, self.id)
end

local function Button_OnLeave (self)
	Talented:HideTooltipInfo()
end

local function Button_OnClick (self, button, down)
	local parent = self:GetParent()
	parent.view:OnTalentClick(button, parent.tab, self.id)
end

local GLOW_ELEMENTS = {
	"GlowTop",
	"GlowTopLeft",
	"GlowLeft",
	"GlowBottomLeft",
	"GlowBottom",
	"GlowBottomRight",
	"GlowRight",
	"GlowTopRight",
}

local function NewTalentFrame(parent)
	local index = parent.treeIndex and (parent.treeIndex + 1) or 1
	local name = ("%sTree%d"):format(parent:GetName(), index)
	parent.treeIndex = index
	local frame = CreateFrame("Frame", name, parent, "PlayerTalentFramePanelTemplate")

	frame.UpdateGlow = function (self, method, ...)
		for _, e in next, GLOW_ELEMENTS do
			e = self[e]
			if e then e[method](e, ...) end
		end
	end

	local clear = CreateFrame("Button", nil, frame)
	frame.clear = clear

	local makeTexture = function (path, blend)
		local t = CreateTexture(clear, nil, path, blend)
		t:SetAllPoints(clear)
		return t
	end

	clear:SetNormalTexture(makeTexture("Interface\\Buttons\\CancelButton-Up"))
	clear:SetPushedTexture(makeTexture("Interface\\Buttons\\CancelButton-Down"))
	clear:SetHighlightTexture(makeTexture("Interface\\Buttons\\CancelButton-Highlight", "ADD"))

	clear:SetScript("OnClick", ClearBranchButton_OnClick)
	clear:SetScript("OnEnter", Talented.base.editname:GetScript("OnEnter"))
	clear:SetScript("OnLeave", Talented.base.editname:GetScript("OnLeave"))
	clear.tooltip = L["Remove all talent points from this tree."]
	clear:SetSize(32, 32)
	clear:ClearAllPoints()
	clear:SetPoint("TOPRIGHT", 0, -36)

	local name = frame:GetName()
	local talentName = name.."Talent"
	local arrowName = name.."Arrow"
	local branchName = name.."Branch"
	for i = 1, 30 do
		local t = _G[talentName..i]
		if t then
			t.IconTexture = _G[talentName..i.."IconTexture"]
			t:SetScript("OnEnter", Button_OnEnter)
			t:SetScript("OnLeave", Button_OnLeave)
			t:SetScript("OnClick", Button_OnClick)
			t:Hide()
		end
		local a = _G[arrowName..i]
		if a then
			a:SetTexture("Interface\\Addons\\Talented\\Textures\\arrows-normal")
			a:Hide()
		end
		local b = _G[branchName..i]
		if b then
			b:SetTexture"Interface\\Addons\\Talented\\Textures\\branches-normal"
			b:Hide()
		end
	end
	frame.talentButtonSize = 30
	frame.initialOffsetX = 20
	frame.initialOffsetY = 52
	frame.buttonSpacingX = 46
	frame.buttonSpacingY = 46
	frame.arrowInsetX = 2
	frame.arrowInsetY = 2
	frame.buttonIndex = 0
	frame.arrowIndex = 0
	frame.branchIndex = 0

	local header = frame.HeaderIcon
	header.PointsSpentBgGold:ClearAllPoints()
	header.PointsSpentBgGold:SetPoint("BOTTOMRIGHT", 7, -3)
	header.PointsSpentBgSilver:ClearAllPoints()
	header.PointsSpentBgSilver:SetPoint("BOTTOMRIGHT", 7, -3)
	header.PointsSpent:ClearAllPoints()
	header.PointsSpent:SetPoint("CENTER", header.PointsSpentBgSilver)

	trees:push(frame)

	return frame
end

local function InitTree(tree)
	local name = tree:GetName()
	local talentName = name.."Talent"
	local arrowName = name.."Arrow"
	local branchName = name.."Branch"
	for i = 1, 30 do
		local t = _G[talentName..i]
		if t then
			t:Hide()
		end
		local a = _G[arrowName..i]
		if a then
			a:Hide()
		end
		local b = _G[branchName..i]
		if b then
			b:Hide()
		end
	end
	tree.buttonIndex = 0
	tree.arrowIndex = 0
	tree.branchIndex = 0
end

function Talented:MakeTalentFrame(parent, width, height)
	local tree = trees:next()
	if tree then
		InitTree(tree)
		tree:SetParent(parent)
	else
		tree = NewTalentFrame(parent)
	end
	return tree
end

function Talented:MakeButton(parent)
	local name = parent:GetName()
	local buttonIndex = parent.buttonIndex + 1
	local button = _G[name .. "Talent" .. buttonIndex]
	parent.buttonIndex = buttonIndex
	button:Show()
	return button
end

function Talented:MakeArrow(parent)
	local name = parent:GetName()
	local arrowIndex = parent.arrowIndex + 1
	local arrow = _G[name .. "Arrow" .. arrowIndex]
	parent.arrowIndex = arrowIndex
	arrow:Show()
	return arrow
end

function Talented:MakeBranch(parent)
	local name = parent:GetName()
	local branchIndex = parent.branchIndex + 1
	local branch = _G[name .. "Branch" .. branchIndex]
	parent.branchIndex = branchIndex
	branch:Show()
	return branch
end
