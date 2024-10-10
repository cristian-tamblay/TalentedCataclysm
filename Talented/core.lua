local Talented = LibStub("AceAddon-3.0"):NewAddon("Talented",
	"AceConsole-3.0", "AceComm-3.0", "AceHook-3.0", "AceEvent-3.0", "AceSerializer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Talented")

if IsAddOnLoaded"Talented_Loader" then
	DisableAddOn"Talented_Loader"
end

Talented.prev_Print = Talented.Print
function Talented:Print(s, ...)
	if type(s) == "string" and s:find("%", nil, true) then
		self:prev_Print(s:format(...))
	else
		self:prev_Print(s, ...)
	end
end

function Talented:Debug(...)
	if not self.db or self.db.profile.debug then
		self:Print(...)
	end
end

function Talented:MakeTarget(targetName)
	local name = self.db.char.targets[targetName]
	local src = name and self.db.global.templates[name]
	if not src then
		if name then
			self.db.char.targets[targetName] = nil
		end
		return
	end

	local target = self.target
	if not target then
		target = {}
		self.target = target
	end
	self:CopyPackedTemplate(src, target)

	if not self:ValidateTemplate(target) or
		(RAID_CLASS_COLORS[target.class] and target.class ~= select(2, UnitClass"player")) or
		(not RAID_CLASS_COLORS[target.class] and (not self.GetPetClass or target.class ~= self:GetPetClass()))
	then
		self.db.char.targets[targetName] = nil
		return nil
	end
	target.name = name
	return target
end

function Talented:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("TalentedDB", self.defaults)
	self:UpgradeOptions()
	if not self.db.global.cata then
		self.db.global.cata = true
		self:LoadTemplates(true)
	else
		self:LoadTemplates(false)
	end

	local AceDBOptions = LibStub("AceDBOptions-3.0", true)
	if AceDBOptions then
		self.options.args.profiles = AceDBOptions:GetOptionsTable(self.db)
		self.options.args.profiles.order = 200
	end

	LibStub("AceConfig-3.0"):RegisterOptionsTable("Talented", self.options)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Talented", "Talented")
	self:RegisterChatCommand("talented", "OnChatCommand")

	self:RegisterComm("Talented")
	if self.InitializePet then
		self:InitializePet()
	end
	if Talented_Inspect then
		Talented_Inspect:Install(self)
	end
	self.OnInitialize = nil
end

function Talented:OnChatCommand(input)
	if not input or input:trim() == "" then
		self:OpenOptionsFrame()
	else
		LibStub("AceConfigCmd-3.0").HandleCommand(self, "talented", "Talented", input)
	end
end

function Talented:DeleteCurrentTemplate()
	local template = self.template
	if template.talentGroup then return end
	local templates = self.db.global.templates
	templates[template.name] = nil
	self:SetTemplate()
end

function Talented:UpdateTemplateName(template, newname)
	if self.db.global.templates[newname] or
			template.talentGroup or
			type(newname) ~= "string" or newname == "" then
		return
	end

	local oldname = template.name
	template.name = newname
	local t = self.db.global.templates
	t[newname] = template
	t[oldname] = nil
end

do
	local function new(templates, name, class)
		if class then
			assert(Talented.spelldata[class],
				("Invalid class `%s' set for new template"):format(class))
		end
		local count = 0
		local template = {
			name = name,
			class = class
		}
		while templates[template.name] do
			count = count + 1
			template.name = format(L["%s (%d)"], name, count)
		end
		templates[template.name] = template
		return template
	end

	local function copy(dst, src)
		dst.class = src.class
		if src.code then
			dst.code = src.code
			return
		else
			for tab, tree in ipairs(Talented:UncompressSpellData(src.class)) do
				local s, d = src[tab], {}
				dst[tab] = d
				for index = 1, #tree do
					d[index] = s[index]
				end
			end
		end
	end

	function Talented:ImportFromOther(name, src)
		if not self:UncompressSpellData(src.class) then return end

		local dst = new(self.db.global.templates, name, src.class)

		copy(dst, src)

		self:OpenTemplate(dst)

		return dst
	end

	function Talented:CopyTemplate(src)
		local dst = new(self.db.global.templates, format(L["Copy of %s"], src.name), src.class)

		copy(dst, src)

		return dst
	end

	function Talented:CreateEmptyTemplate(class)
		class = class or select(2, UnitClass"player")
		local template = new(self.db.global.templates, L["Empty"], class)

		local info = self:UncompressSpellData(class)

		for tab, tree in ipairs(info) do
			local t = {}
			template[tab] = t
				for index = 1, #tree do
				t[index] = 0
			end
		end

		return template
	end

	function Talented:GetPreviousTemplate()
		local profile
		local last = self.db.profile.last_template
		if last then
			profile = self.db.global.templates[last]
		end
		if not profile then
			local _
			_, profile = next(self.db.global.templates)
		end
		if not profile then
			profile = self:CreateEmptyTemplate()
		end
		return profile
	end

	Talented.importers = {}
	Talented.exporters = {}
	function Talented:ImportTemplate(url)
		local dst, result = new(self.db.global.templates, L["Imported"])
		for pattern, method in pairs(self.importers) do
			if url:find(pattern) then
				result = method(self, url, dst)
				if result then break end
			end
		end
		if result then
			if not self:ValidateTemplate(dst) then
				self:Print(L["The given template is not a valid one!"])
				self.db.global.templates[dst.name] = nil
			else
				return dst
			end
		else
			self:Print(L["\"%s\" does not appear to be a valid URL!"], url)
			self.db.global.templates[dst.name] = nil
		end
	end
end

function Talented:OpenTemplate(template)
	self:UnpackTemplate(template)
	if not self:ValidateTemplate(template, true) then
		local name = template.name
		self.db.global.templates[name] = nil
		self:Print(L["The template '%s' is no longer valid and has been removed."], name)
		return
	end
	local base = self:CreateBaseFrame()
	if not self.alternates then
		self:UpdatePlayerSpecs()
	end
	if not PlayerTalentFrame:IsShown() then
		PlayerTalentFrame:Show()
		-- the following call might taint.
		PlayerTalentFrameTab4:Click()
	end
	self:SetTemplate(template)
end

function Talented:SetTemplate(template)
	if not template or template.talentGroup then
		template = assert(self:GetPreviousTemplate())
	end
	local view = self:CreateBaseFrame().view
	local old = view.template
	if template ~= old then
		view:SetTemplate(template)
		self.template = template
	end
	self.db.profile.last_template = template.name
	self:SetMode(self:GetDefaultMode())
end

function Talented:GetMode()
	return self.mode
end

function Talented:SetMode(mode)
    if self.mode ~= mode then
        self.mode = mode
        if mode == "apply" then
            self:ApplyCurrentTemplate()
        elseif self.base and self.base.view then
            self.base.view:SetViewMode(mode)
        end
    end
    local cb = self.base and self.base.checkbox
    if cb then
        -- Reverse the logic so the checkbox shows as unchecked when in edit mode.
        cb:SetChecked(mode ~= "edit")  -- Invert the check logic
    end
end


function Talented:GetDefaultMode()
	return self.db.profile.always_edit and "edit" or "view"
end

function Talented:OnEnable()
	TalentFrame_LoadUI()
	GlyphFrame_LoadUI()
	if GlyphFrame then
		GlyphFrame:ClearAllPoints()
		GlyphFrame:SetParent(PlayerTalentFrameInset)
		GlyphFrame:SetPoint("TOPLEFT", 3, -3)
		GlyphFrame:SetPoint("BOTTOMRIGHT", -3, 3)
	end
	local tab = CreateFrame("Button", "PlayerTalentFrameTab4", PlayerTalentFrame, "PlayerTalentTabTemplate")
	tab:SetText("Talented")
	tab:SetID(4)
	hooksecurefunc("PanelTemplates_UpdateTabs", function (frame)
		if frame == PlayerTalentFrame then
			local tab = PlayerTalentFrameTab4
			local name = tab:GetName()
			if 4 == frame.selectedTab then
				_G[name.."Left"]:Hide()
				_G[name.."Middle"]:Hide()
				_G[name.."Right"]:Hide()
				tab:Disable()
				tab:SetDisabledFontObject(GameFontHighlightSmall)
				_G[name.."Text"]:SetPoint("CENTER", tab, "CENTER", 0, -3)

				_G[name.."LeftDisabled"]:Show()
				_G[name.."MiddleDisabled"]:Show()
				_G[name.."RightDisabled"]:Show()
			else
				_G[name.."Left"]:Show()
				_G[name.."Middle"]:Show()
				_G[name.."Right"]:Show()
				tab:Enable()
				_G[name.."Text"]:SetPoint("CENTER", tab, "CENTER", 0, 2)

				_G[name.."LeftDisabled"]:Hide()
				_G[name.."MiddleDisabled"]:Hide()
				_G[name.."RightDisabled"]:Hide()
			end
		end
	end)
	hooksecurefunc("PlayerTalentFrame_Refresh", function ()
		local selectedTab = PlayerTalentFrame.selectedTab
		if selectedTab == 4 then
			PlayerTalentFrameTalents:Hide()
			PlayerTalentFramePetTalents:Hide()
			PlayerSpecTab1:Hide()
			PlayerSpecTab2:Hide()
			PlayerTalentFrameActivateButton:Hide()
			if GlyphFrame then GlyphFrame:Hide() end
			Talented:SetTemplate()
			Talented:CreateBaseFrame():Show()
			PlayerTalentFrameTitleText:SetText"Talented"
		else
			if Talented.base then
				Talented.base:Hide()
			end
		end
		if selectedTab == 1 then
			local spec = (PlayerSpecTab1:GetChecked() and 1 or 2)
			Talented:OverlayTargetSpec(nil, spec)
		elseif selectedTab == 2 then
			Talented:OverlayTargetSpec(true)
		else
			Talented:HideTargetOverlay()
		end
	end)
	hooksecurefunc("PlayerTalentFrame_UpdateTabs", function ()
		local before = PlayerTalentFrameTab1
		if PlayerTalentFrameTab2:IsShown() then
			before = PlayerTalentFrameTab2
		end
		if PlayerTalentFrameTab3:IsShown() then
			before = PlayerTalentFrameTab3
		end
		PlayerTalentFrameTab4:SetPoint("LEFT", before, "RIGHT", -15, 0)
	end)
	self.OnEnable = function (self)
		PlayerTalentFrameTab4:Show()
	end
end

function Talented:OnDisable()
	PlayerTalentFrameTab4:Hide()
end

function Talented:Update()
	self:CreateBaseFrame()
	self:UpdatePlayerSpecs()
	if not self.template then
		self:SetTemplate()
	end
	self:UpdateView()
end

function Talented:LoadTemplates(check)
	local db = self.db.global.templates
	local invalid = {}
	for name, code in pairs(db) do
		if type(code) == "string" then
			local class = self:GetTemplateStringClass(code)
			if class then
				local t = {
					name = name,
					code = code,
					class = class,
				}
				if check then
					local s = pcall(self.UnpackTemplate, self, t)
					if not s then t = nil end
				end
				db[name] = t
			else
				db[name] = nil
				invalid[#invalid + 1] = name
			end
		elseif not self:ValidateTemplate(code) then
			db[name] = nil
			invalid[#invalid + 1] = name
		end
	end
	if next(invalid) then
		table.sort(invalid)
		self:Print(L["The following templates are no longer valid and have been removed:"])
		self:Print(table.concat(invalid, ", "))
	end

	self.OnDatabaseShutdown = function (self, event, db)
		local db = db.global.templates
		for name, template in pairs(db) do
			template.talentGroup = nil
			Talented:PackTemplate(template)
			if template.code then
				db[name] = template.code
			end
		end
		self.db = nil
	end
	self.db.RegisterCallback(self, "OnDatabaseShutdown")
	self.LoadTemplates = nil
end

_G.Talented = Talented
