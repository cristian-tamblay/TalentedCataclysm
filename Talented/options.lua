local L = LibStub("AceLocale-3.0"):GetLocale("Talented")
local Talented = Talented

Talented.max_talent_points = 71

Talented.defaults = {
	profile = {

-- Limit Talented to the level cap
		level_cap = true,

-- Show the required level for any template
		show_level_req = true,

-- Offset between Talent icons
		offset = 64,

-- Global frame scale
		scale = 1,

-- the template that was selected last
	--	last_template = nil,

		framepos = {},

-- Use a dialog to output URL or show them directly in Chat ?
		-- show_url_in_chat = nil,

	},
	global = {
	-- the list of saved templates, see below for the format
			templates = {},
	},
	char = {
		targets = {},
	},
}

function Talented:SetOption(info, value)
	local name = info[#info]
	self.db.profile[name] = value
	local arg = info.arg
	if arg then self[arg](self) end
end

function Talented:GetOption(info)
	local name = info[#info]
	return self.db.profile[name]
end

function Talented:MustNotConfirmLearn()
	return not Talented.db.profile.confirmlearn
end

Talented.options = {
	desc = L["Talented - Talent Editor"],
	type = "group",
	childGroups = "tab",
	handler = Talented,
	get = "GetOption",
	set = "SetOption",
	args = {
		options = {
			name = L["Options"],
			desc = L["General Options for Talented."],
			type = "group",
			args = {
				header1 = {
					name = L["General options"],
					type = "header",
					order = 1,
				},
				always_edit = {
					name = L["Always edit"],
					desc = L["Always allow templates and the current build to be modified, instead of having to Unlock them first."],
					type = "toggle",
					arg = "UpdateView",
					order = 100,
				},
			}
		},
	},
}

function Talented:UpgradeOptions()
	local p = self.db.profile
	if p.point or p.offsetx or p.offsety then
		local opts = {
			anchor = p.point or "CENTER",
			anchorTo = p.point or "CENTER",
			x = p.offsetx or 0,
			y = p.offsety or 0,
		}
		p.framepos.TalentedFrame = opts
		p.point, p.offsetx, p.offsety = nil, nil, nil
	end
	local c = self.db.char
	if c.target then
		c.targets[1] = c.target
		c.target = nil
	end
	self.UpgradeOptions = nil
end

function Talented:SaveFramePosition(frame)
	local db = self.db.profile.framepos
	local name = frame:GetName()

	local data, _ = db[name]
	if not data then
		data = {}
		db[name] = data
	end
	data.anchor, _, data.anchorTo, data.x, data.y = frame:GetPoint(1)
end

function Talented:LoadFramePosition(frame)
	local data = self.db.profile.framepos[frame:GetName()]
	if data and data.anchor then
		frame:ClearAllPoints()
		frame:SetPoint(data.anchor, UIParent, data.anchorTo, data.x, data.y)
	else
		frame:SetPoint"CENTER"
		self:SaveFramePosition(frame)
	end
end

local function BaseFrame_OnMouseDown(self)
	if self.OnMouseDown then self:OnMouseDown() end
	self:StartMoving()
end

local function BaseFrame_OnMouseUp(self)
	self:StopMovingOrSizing()
	Talented:SaveFramePosition(self)
	if self.OnMouseUp then self:OnMouseUp() end
end

function Talented:SetFrameLock(frame, locked)
	local db = self.db.profile.framepos
	local name = frame:GetName()
	local data = db[name]
	if not data then
		data = {}
		db[name] = data
	end
	if locked == nil then
		locked = data.locked
	elseif locked == false then
		locked = nil
	end
	data.locked = locked
	if locked then
		frame:SetMovable(false)
		frame:SetScript("OnMouseDown", nil)
		frame:SetScript("OnMouseUp", nil)
	else
		frame:SetMovable(true)
		frame:SetScript("OnMouseDown", BaseFrame_OnMouseDown)
		frame:SetScript("OnMouseUp", BaseFrame_OnMouseUp)
	end
	frame:SetClampedToScreen(true)
end

function Talented:GetFrameLock(frame)
	local data = self.db.profile.framepos[frame:GetName()]
	return data and data.locked
end
