local L = LibStub("AceLocale-3.0"):GetLocale("Talented")
local Talented = Talented

local function offset(row, column, parent)
	return ((column - 1) * (parent.buttonSpacingX)) + parent.initialOffsetX, -((row - 1) * (parent.buttonSpacingY)) - parent.initialOffsetY
end

--[[
Views are an abstract representation of a Talent tree "view". It should allow
Talented to display the player and it's pet trees at the same time.

Views have several attributes:
	view.frame: parent frame of the view (can be the main Talented window or another) *read only*
	view.name: the name of the view. Must be unique. *read only*
	view.class: the class of the view. *auto on :SetTemplate()*
	view.pet: the view is for a pet tree. *auto on :SetTemplate()*
	view.spec: the view is for an actual spec, it can't be modified except via :LearnTalent() *auto on :SetTemplate()*
	view.mode: view display mode. Can be "view" or "edit" *changed via :SetViewMode()*
	view.template: the template associated with the view *changed via :SetTemplate()*
]]

local TalentView = {}
function TalentView:init(frame, name, offsetx, offsety)
	self.frame = frame
	self.name = name
	self.offsetx = offsetx or 0
	self.offsety = offsety or 0
	self.deltax = 209
	self.elements = {}
end

function TalentView:SetUIElement(element, ...)
	self.elements[strjoin("-", ...)] = element
end

function TalentView:GetUIElement(...)
	return self.elements[strjoin("-", ...)]
end

function TalentView:SetViewMode(mode, force)
	if mode ~= self.mode or force then
		self.mode = mode
		self:Update()
	end
end

local function GetMaxPoints(...)
	local total = 0
	for i = 1, GetNumTalentTabs(...) do
		total = total + select(5, GetTalentTabInfo(i, ...))
	end
	return total + GetUnspentTalentPoints(...)
end

function TalentView:SetClass(class, force)
	if self.class == class and not force then return end
	local pet = not RAID_CLASS_COLORS[class]
	self.pet = pet

	Talented.Pool:changeSet(self.name)
	wipe(self.elements)
	local talents = Talented:UncompressSpellData(class)
	for tab, tree in ipairs(talents) do
		local frame = Talented:MakeTalentFrame(self.frame)
		frame.tab = tab
		frame.view = self
		frame.pet = self.pet

		local tabdata = Talented.tabdata[class][tab]
		local background = tabdata.background
		frame.BgTopLeft:SetTexture("Interface\\TalentFrame\\"..background.."-TopLeft")
		frame.BgTopRight:SetTexture("Interface\\TalentFrame\\"..background.."-TopRight")
		frame.BgBottomLeft:SetTexture("Interface\\TalentFrame\\"..background.."-BottomLeft")
		frame.BgBottomRight:SetTexture("Interface\\TalentFrame\\"..background.."-BottomRight")
		if frame.HeaderIcon then
			frame.HeaderIcon.Icon:SetTexture(tabdata.icon)
		end
		frame.Name:SetText(tabdata.name)
		if frame.NameLarge then
			frame.NameLarge:SetText(tabdata.name)
		end
		frame.HeaderBackground:SetVertexColor(tabdata.r, tabdata.g, tabdata.b)
		if frame.Summary then
			frame.Summary.Border:SetVertexColor(tabdata.r, tabdata.g, tabdata.b)
			frame.Summary.IconGlow:SetVertexColor(tabdata.r, tabdata.g, tabdata.b)
		end
		if frame.RoleIcon then
			-- Update roles
			frame.RoleIcon.Icon:SetTexCoord(GetTexCoordsForRoleSmall(tabdata.role1))
			frame.RoleIcon:Show()
			frame.RoleIcon.role = tabdata.role1

			if tabdata.role2 then
				frame.RoleIcon2.Icon:SetTexCoord(GetTexCoordsForRoleSmall(tabdata.role2))
				frame.RoleIcon2:Show()
				frame.RoleIcon2.role = tabdata.role2
			else
				frame.RoleIcon2:Hide()
			end
		end
		-- FIXME ?
		frame.HeaderIcon.PointsSpent:Show()
		frame.HeaderIcon.PrimaryBorder:Hide()
		frame.HeaderIcon.PointsSpentBgGold:Hide()
		frame.HeaderIcon.SecondaryBorder:Show()
		frame.HeaderIcon.PointsSpentBgSilver:Show()
		frame.HeaderIcon.LockIcon:Hide()

		self:SetUIElement(frame, tab)

		for index, talent in ipairs(tree) do
			if not talent.inactive then
				local button = Talented:MakeButton(frame)
				button.id = index

				self:SetUIElement(button, tab, index)

				button:SetPoint("TOPLEFT", offset(talent.row, talent.column, frame))
				button.IconTexture:SetTexture(Talented:GetTalentIcon(class, tab, index))
				button:Show()
			end
		end

		for index, talent in ipairs(tree) do
			local req = talent.req
			if req then
				local elements = {}
				Talented.DrawLine(elements, frame, offset, talent.row, talent.column, tree[req].row, tree[req].column)
				self:SetUIElement(elements, tab, index, req)
			end
		end

		frame:SetPoint("TOPLEFT", (tab-1) * self.deltax + self.offsetx, self.offsety)
	end

	self.class = class
	self:Update()
end

function TalentView:SetTemplate(template)
	if template then Talented:UnpackTemplate(template) end

	local curr = self.template
	self.template = template
	if curr and curr ~= template then
		Talented:PackTemplate(curr)
	end

	self.spec = template.talentGroup
	self:SetClass(template.class)

	return self:Update()
end

function TalentView:GetReqLevel(total)
	if not self.pet then
		return Talented.TALENT_LEVELS[total]
	else
		if total == 0 then return 20 end
		if total > 17 then
			return 64 + (total - 16) * 4 -- this spec requires Beast Mastery
		else
			return 16 + total * 4
		end
	end
end

local GRAY_FONT_COLOR = GRAY_FONT_COLOR
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local GREEN_FONT_COLOR = GREEN_FONT_COLOR
local RED_FONT_COLOR = RED_FONT_COLOR
local LIGHTBLUE_FONT_COLOR = { r = 0.3, g = 0.9, b = 1 }
function TalentView:Update()
	local template = self.template
	local total = 0
	local info = Talented:UncompressSpellData(template.class)
	local at_cap = Talented:IsTemplateAtCap(template)
	local state, primary = Talented:GetTemplateMasteryState(template)
	for tab, tree in ipairs(info) do
		local count = 0
		for index, talent in ipairs(tree) do
			if not talent.inactive then
				local rank = template[tab][index]
				count = count + rank
				local button = self:GetUIElement(tab, index)
				local color = GRAY_FONT_COLOR
				local state = Talented:GetTalentState(template, tab, index)
--~ 				if goldBorder then
--~ 					button.GoldBorder:Show()
--~ 					button.Slot:Hide()
--~ 					button.SlotShadow:Hide()
--~ 				else
--~ 					button.GoldBorder:Hide()
--~ 					button.Slot:Show()
--~ 					button.SlotShadow:Show()
--~ 				end
				if state == "empty" and (at_cap or self.mode == "view") then
					state = "unavailable"
				end
				if state == "unavailable" then
					button.GlowBorder:Hide()
					button.IconTexture:SetDesaturated(1)
					button.Rank:Hide()
					button.RankBorder:Hide()
					button.RankBorderGreen:Hide()
				else
					button.Rank:Show()
					button.RankBorder:Show()
					button.Rank:SetText(rank)
					button.IconTexture:SetDesaturated(0)
					if state == "full" then
						button.GlowBorder:Hide()
						button.RankBorder:Show()
						button.RankBorderGreen:Hide()
						color = NORMAL_FONT_COLOR
					else
						button.GlowBorder:Show()
						button.RankBorder:Hide()
						button.RankBorderGreen:Show()
						color = GREEN_FONT_COLOR
					end
				end
				button.Rank:SetTextColor(color.r, color.g, color.b)
				local req = talent.req
				if req then
					local ecolor = color
					if ecolor == GREEN_FONT_COLOR then
						if self.mode == "edit" then
							local s = Talented:GetTalentState(template, tab, req)
							if s ~= "full" then
								ecolor = RED_FONT_COLOR
							end
						else
							ecolor = NORMAL_FONT_COLOR
						end
					end
					for _, element in ipairs(self:GetUIElement(tab, index, req)) do
						element:SetVertexColor(ecolor.r, ecolor.g, ecolor.b)
					end
				end
			end
		end
		local frame = self:GetUIElement(tab)
		local hicon = frame.HeaderIcon
		if not primary or tab == primary then
			hicon.PrimaryBorder:Show()
			hicon.PointsSpentBgGold:Show()
			hicon.SecondaryBorder:Hide()
			hicon.PointsSpentBgSilver:Hide()
			hicon.PointsSpent:SetPoint("CENTER", hicon.PointsSpentBgGold)
			hicon.PointsSpent:Show()
			hicon.LockIcon:Hide()
		elseif state ~= "strict" then
			hicon.PrimaryBorder:Hide()
			hicon.PointsSpentBgGold:Hide()
			hicon.SecondaryBorder:Show()
			hicon.PointsSpentBgSilver:Show()
			hicon.PointsSpent:SetPoint("CENTER", hicon.PointsSpentBgSilver)
			hicon.PointsSpent:Show()
			hicon.LockIcon:Hide()
		else
			hicon.PointsSpent:Hide()
			hicon.PrimaryBorder:Hide()
			hicon.PointsSpentBgGold:Hide()
			hicon.SecondaryBorder:Show()
			hicon.PointsSpentBgSilver:Hide()
			hicon.LockIcon:Show()
		end
		if tab == primary then
			frame:UpdateGlow"Show"
		else
			frame:UpdateGlow"Hide"
		end
		if tab == primary or state ~= "strict" then
			frame:UpdateGlow("SetDesaturated", 0)
			hicon.Icon:SetDesaturated(0)
			hicon.PrimaryBorder:SetDesaturated(0)
			hicon.PointsSpentBgGold:SetDesaturated(0)
			frame.HeaderBorder:SetDesaturated(0)
			frame.Name:SetFontObject(GameFontNormal)
			frame.RoleIcon.Icon:SetTexture"Interface\\LFGFrame\\LFGRole"
			frame.RoleIcon2.Icon:SetTexture"Interface\\LFGFrame\\LFGRole"
		else
			frame:UpdateGlow("SetDesaturated", 1)
			hicon.Icon:SetDesaturated(1)
			hicon.PrimaryBorder:SetDesaturated(1)
			hicon.PointsSpentBgGold:SetDesaturated(1)
			frame.HeaderBorder:SetDesaturated(1)
			frame.Name:SetFontObject(GameFontDisable)
			frame.RoleIcon.Icon:SetTexture"Interface\\LFGFrame\\LFGRole_BW"
			frame.RoleIcon2.Icon:SetTexture"Interface\\LFGFrame\\LFGRole_BW"
		end
		hicon.PointsSpent:SetText(count)
		total = total + count
		local clear = frame.clear
		if self.mode ~= "edit" or count <= 0 or self.spec then
			clear:Hide()
		else
			clear:Show()
		end
	end
	local maxpoints = GetMaxPoints(nil, self.pet, self.spec)
	local points = self.frame.points
	if points then
		points:SetWidth(140)
		points:SetFormattedText("Level %d Points %d/%d", self:GetReqLevel(total), total, maxpoints)
		local color
		if total < maxpoints then
			color = GREEN_FONT_COLOR
		elseif total > maxpoints then
			color = RED_FONT_COLOR
		else
			color = NORMAL_FONT_COLOR
		end
		points:SetTextColor(color.r, color.g, color.b)
	end
	local pointsleft = self.frame.pointsleft
	if pointsleft then
		if maxpoints ~= total and template.talentGroup then
			pointsleft:Show()
			pointsleft.text:SetFormattedText(L["You have %d talent |4point:points; left"], maxpoints - total)
		else
			pointsleft:Hide()
		end
	end
	local edit = self.frame.editname
	if edit then
		if template.talentGroup then
			edit:Hide()
		else
			edit:Show()
			edit:SetText(template.name)
		end
	end
	local cb, activate = self.frame.checkbox, self.frame.bactivate
	if cb then
		-- Reverse the logic: template is always in edit mode unless the user locks it.
		if template.talentGroup == GetActiveTalentGroup() or template.pet then
			if activate then activate:Hide() end
			cb:Show()
			cb.label:SetText(L["Lock template"]) -- Change label to "Lock template"
			cb.tooltip = L["Toggle locking of the template."] -- Update tooltip
		elseif template.talentGroup then
			cb:Hide()
			if activate then
				activate.talentGroup = template.talentGroup
				activate:Show()
			end
		else
			if activate then activate:Hide() end
			cb:Show()
			cb.label:SetText(L["Lock template"]) -- Change label to "Lock template"
			cb.tooltip = L["Toggle locking of the template."] -- Update tooltip
		end
		-- Reverse the checked state: make the default mode 'edit' (unlocked).
		cb:SetChecked(self.mode ~= "edit")  -- Invert the check logic
	end
end

function TalentView:SetTooltipInfo(owner, tab, index)
	Talented:SetTooltipInfo(owner, self.class, tab, index)
end

function TalentView:OnTalentClick(button, tab, index)
	if IsModifiedClick"CHATLINK" then
		local link = Talented:GetTalentLink(self.template, tab, index)
		if link then
			ChatEdit_InsertLink(link)
		end
	else
		self:UpdateTalent(tab, index, button == "LeftButton" and 1 or -1)
	end
end

function TalentView:UpdateTalent(tab, index, offset)
	if self.mode ~= "edit" then return end
	local template = self.template

	if offset > 0 and Talented:IsTemplateAtCap(template) then return end
	local s = Talented:GetTalentState(template, tab, index)

	local ranks = Talented:GetTalentRanks(template.class, tab, index)
	local original = template[tab][index]
	local value = original + offset
	if value < 0 or s == "unavailable" then
		value = 0
	elseif value > ranks then
		value = ranks
	end
	Talented:Debug("Updating %d-%d : %d -> %d (%d)", tab, index, original, value, offset)
	if value == original then
		return
	end
	template[tab][index] = value
	if not Talented:ValidateTemplate(template) then
		template[tab][index] = original
		return
	end
	template.points = nil
	for _, view in Talented:IterateTalentViews(template) do
		view:Update()
	end
	Talented:UpdateTooltip()
	return true
end

function TalentView:ClearTalentTab(tab)
	local template = self.template
	if template and not template.talentGroup then
		local tab = template[tab]
		for index, value in ipairs(tab) do
			tab[index] = 0
		end
	end
	for _, view in Talented:IterateTalentViews(template) do
		view:Update()
	end
end

Talented.views = {}
Talented.TalentView = {
	__index = TalentView,
	new = function (self, ...)
		local view = setmetatable({}, self)
		view:init(...)
		table.insert(Talented.views, view)
		return view
	end,
}

local function next_TalentView(views, index)
	index = (index or 0) + 1
	local view = views[index]
	if not view then
		return nil
	else
		return index, view
	end
end

function Talented:IterateTalentViews(template)
	local next
	if template then
		next = function (views, index)
			while true do
				index = (index or 0) + 1
				local view = views[index]
				if not view then
					return nil
				elseif view.template == template then
					return index, view
				end
			end
		end
	else
		next = next_TalentView
	end
	return next, self.views
end
