local GRAY_FONT_COLOR = GRAY_FONT_COLOR
local LIGHTBLUE_FONT_COLOR = { r = 0.3, g = 0.9, b = 1 }
local RED_FONT_COLOR = RED_FONT_COLOR

local targetTemplate
local targetTexts = {}

local function Target_Display(self, value, color)
	self:SetVertexColor(color.r, color.g, color.b)
	self:SetText(value)
	self:Show()
	self.texture:Show()
end

local function Target_Undisplay(self)
	self:Hide()
	self.texture:Hide()
end

local function MakeTargetText(button)
	local t = button:CreateTexture(button, "OVERLAY")
	t:SetTexture"Interface\\Addons\\Talented\\Textures\\border"
	t:SetSize(32, 32)
	t:SetPoint("CENTER", button, "TOPRIGHT", -2, -2)
	local fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	fs.texture = t
	fs:SetPoint("CENTER", t)
	targetTexts[button] = fs
	fs.Display = Target_Display
	fs.Undisplay = Target_Undisplay
	return fs
end

function Talented:OverlayTargetSpec(pet, spec)
	self:HideTargetOverlay()
	local target = pet and UnitName"pet" or spec
	if not target then return end
	target = self.db.char.targets[target]
	if not target then return end
	target = self.db.global.templates[target]
	if not target then return end
	self:UnpackTemplate(target)
	targetTemplate = target
	local parent = pet and "PlayerTalentFramePetPanel"
	for tab, tree in ipairs(target) do
		local panel = parent
		if not panel then
			panel = "PlayerTalentFramePanel"..tab
		end
		for index, value in ipairs(tree) do
			local button = _G[panel.."Talent"..index]
			local current = select(8, GetTalentInfo(tab, index, nil, pet, spec))
			if value > 0 or current > 0 then
				local color
				local text = targetTexts[button] or MakeTargetText(button)
				if current == value then
					color = GRAY_FONT_COLOR
				elseif current < value then
					color = LIGHTBLUE_FONT_COLOR
				elseif current > value then
					color = RED_FONT_COLOR
				end
				text:Display(value, color)
			end
		end
	end
end

function Talented:HideTargetOverlay()
	local target = targetTemplate
	if target then
		self:PackTemplate(target)
		targetTemplate = nil
		for _, fs in next, targetTexts do
			fs:Undisplay()
		end
	end
end
