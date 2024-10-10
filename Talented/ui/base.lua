local max = math.max
local CreateFrame = CreateFrame
local GREEN_FONT_COLOR = GREEN_FONT_COLOR
local PlaySound = PlaySound
local Talented = Talented
local GameTooltip = GameTooltip

local L = LibStub("AceLocale-3.0"):GetLocale("Talented")

Talented.uielements = {}

-- All this exists so that a UIPanelButtonTemplate2 like button correctly works
-- with :SetButtonState(). This is because the state is only updated after
-- :OnMouse{Up|Down}().

local BUTTON_TEXTURES = {
	NORMAL = "Interface\\Buttons\\UI-Panel-Button-Up",
	PUSHED = "Interface\\Buttons\\UI-Panel-Button-Down",
	DISABLED = "Interface\\Buttons\\UI-Panel-Button-Disabled",
	PUSHED_DISABLED = "Interface\\Buttons\\UI-Panel-Button-Disabled-Down",
}
local DefaultButton_Enable = GameMenuButtonOptions.Enable
local DefaultButton_Disable = GameMenuButtonOptions.Disable
local DefaultButton_SetButtonState = GameMenuButtonOptions.SetButtonState
local function Button_SetState(self, state)
	if not state then
		if self:IsEnabled() == 0 then
			state = "DISABLED"
		else
			state = self:GetButtonState()
		end
	end
	if state == "DISABLED" and self.locked_state == "PUSHED" then
		state = "PUSHED_DISABLED"
	end
	local texture = BUTTON_TEXTURES[state]
	self.left:SetTexture(texture)
	self.middle:SetTexture(texture)
	self.right:SetTexture(texture)
end

local function Button_SetButtonState(self, state, locked)
	self.locked_state = locked and state
	if self:IsEnabled() ~= 0 then
		DefaultButton_SetButtonState(self, state, locked)
	end
	Button_SetState(self)
end

local function Button_OnMouseDown(self)
	Button_SetState(self, self:IsEnabled() == 0 and "DISABLED" or "PUSHED")
end

local function Button_OnMouseUp(self)
	Button_SetState(self, self:IsEnabled() == 0 and "DISABLED" or "NORMAL")
end

local function Button_Enable(self)
	DefaultButton_Enable(self)
	if self.locked_state then
		Button_SetButtonState(self, self.locked_state, true)
	else
		Button_SetState(self)
	end
end

local function Button_Disable(self)
	DefaultButton_Disable(self)
	Button_SetState(self)
end

local function MakeButton(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetNormalFontObject(GameFontNormal)
	button:SetHighlightFontObject(GameFontHighlight)
	button:SetDisabledFontObject(GameFontDisable)

	local texture = button:CreateTexture()
	texture:SetTexCoord(0, 0.09375, 0, 0.6875)
	texture:SetPoint"LEFT"
	texture:SetSize(12, 22)
	button.left = texture

	texture = button:CreateTexture()
	texture:SetTexCoord(0.53125, 0.625, 0, 0.6875)
	texture:SetPoint"RIGHT"
	texture:SetSize(12, 22)
	button.right = texture

	texture = button:CreateTexture()
	texture:SetTexCoord(0.09375, 0.53125, 0, 0.6875)
	texture:SetPoint("LEFT", button.left, "RIGHT")
	texture:SetPoint("RIGHT", button.right, "LEFT")
	texture:SetHeight(22)
	button.middle = texture

	texture = button:CreateTexture()
	texture:SetTexture"Interface\\Buttons\\UI-Panel-Button-Highlight"
	texture:SetBlendMode"ADD"
	texture:SetTexCoord(0, 0.625, 0, 0.6875)
	texture:SetAllPoints(button)
	button:SetHighlightTexture(texture)

	button:SetScript("OnMouseDown", Button_OnMouseDown)
	button:SetScript("OnMouseUp", Button_OnMouseUp)
	button:SetScript("OnShow", Button_SetState)
	button.Enable = Button_Enable
	button.Disable = Button_Disable
	button.SetButtonState = Button_SetButtonState

	table.insert(Talented.uielements, button)
	return button
end

local function CreateBaseButtons(parent)
	local function Frame_OnEnter(self)
		if self.tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
			GameTooltip:SetText(self.tooltip, nil, nil, nil, nil, 1)
		end
	end

	local function Frame_OnLeave(self)
		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
	end

	local button = MakeButton(parent)

	button:SetSize(120, 20)
	button:SetPoint("CENTER", parent, "BOTTOM", 0, 15)
	button:SetText(L["Apply template"])
	button:SetScript("OnClick", function () Talented:SetMode("apply") end)

	local b = MakeButton(parent)
	parent.bactions = b

	b:SetText(L["Actions"])
	b:SetSize(max(110, b:GetTextWidth() + 22), 22)
	b:SetScript("OnClick", function (self)
		Talented:OpenActionMenu(self)
	end)
	b:SetPoint("TOPLEFT", 66, 32)

	b = MakeButton(parent)
	parent.bmode = b

	b:SetText(L["Templates"])
	b:SetSize(max(110, b:GetTextWidth() + 22), 22)
	b:SetScript("OnClick", function (self)
		Talented:OpenTemplateMenu(self)
	end)
	b:SetPoint("LEFT", parent.bactions, "RIGHT", 14, 0)

	local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	parent.editname = e
	e:SetFontObject(ChatFontNormal)
	e:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
	e:SetSize(200, 13)
	e:SetAutoFocus(false)

	e:SetScript("OnEscapePressed", function (this)
			this:ClearFocus()
		end)
	e:SetScript("OnEditFocusLost", function (this)
			this:SetText(Talented.template.name)
		end)
	e:SetScript("OnEnterPressed",  function (this)
			Talented:UpdateTemplateName(Talented.template, this:GetText())
			Talented:UpdateView()
			this:ClearFocus()
		end)
	e:SetScript("OnEnter", Frame_OnEnter)
	e:SetScript("OnLeave", Frame_OnLeave)
	e:SetPoint("LEFT", parent.bmode, "RIGHT", 14, 1)
	e.tooltip = L["You can edit the name of the template here. You must press the Enter key to save your changes."]

	b = MakeButton(parent)

	b:SetText("Credits")
	b:SetSize(max(110, b:GetTextWidth() + 22), 22)
	b:SetScript("OnClick", function (self)
		Talented:OpenCreditsMenu(self)
	end)
	b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, 32)



	local cb = CreateFrame("Checkbutton", nil, parent)
	parent.checkbox = cb

	local makeTexture = function (path, blend)
		local t = cb:CreateTexture()
		t:SetTexture(path)
		t:SetAllPoints(cb)
		if blend then
			t:SetBlendMode(blend)
		end
		return t
	end

	cb:SetSize(20, 20)

	local fs = cb:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
	cb.label = fs
	fs:SetJustifyH("LEFT")
	fs:SetSize(400, 20)
	fs:SetPoint("LEFT", cb, "RIGHT", 1, 1)
	cb:SetNormalTexture(makeTexture("Interface\\Buttons\\UI-CheckBox-Up"))
	cb:SetPushedTexture(makeTexture("Interface\\Buttons\\UI-CheckBox-Down"))
	cb:SetDisabledTexture(makeTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled"))
	cb:SetCheckedTexture(makeTexture("Interface\\Buttons\\UI-CheckBox-Check"))
	cb:SetHighlightTexture(makeTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD"))
	cb:SetScript("OnClick", function ()
		if Talented.mode == "edit" then
			Talented:SetMode("view")
		else
			Talented:SetMode("edit")
		end
	end)
	cb:SetScript("OnEnter", Frame_OnEnter)
	cb:SetScript("OnLeave", Frame_OnLeave)
	cb:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 14, 4)
	cb:SetFrameLevel(parent:GetFrameLevel() + 2)

	local points = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	parent.points = points
	points:SetJustifyH("RIGHT")
	points:SetSize(80, 14)
	points:SetPoint("LEFT", cb.label, "RIGHT", 40, 0)
end

local function CloseButton_OnClick(self, button)
	if button == "LeftButton" then
		if self.OnClick then
			self:OnClick(button)
		else
			self:GetParent():Hide()
		end
	else
		Talented:OpenLockMenu(self, self:GetParent())
	end
end

function Talented:CreateCloseButton(parent, OnClickHandler)
	local close = CreateFrame("Button", nil, parent)

	local makeTexture = function (path, blend)
		local t = close:CreateTexture()
		t:SetAllPoints(close)
		t:SetTexture(path)
		if blend then
			t:SetBlendMode(blend)
		end
		return t
	end

	close:SetNormalTexture(makeTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up"))
	close:SetPushedTexture(makeTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down"))
	close:SetHighlightTexture(makeTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD"))
	close:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	close:SetScript("OnClick", CloseButton_OnClick)
	close.OnClick = OnClickHandler

	close:SetSize(32, 32)
	close:SetPoint("TOPRIGHT", 1, 0)

	return close
end

function Talented:CreateBaseFrame()
	local frame = CreateFrame("Frame", "TalentedFrame", PlayerTalentFrame)
	frame:Hide()

	frame:EnableMouse(true)
	frame:SetPoint("TOPLEFT", 4, -68)
	frame:SetPoint("BOTTOMRIGHT")

	CreateBaseButtons(frame)

	frame:SetScript("OnShow", function ()
		Talented:RegisterEvent"MODIFIER_STATE_CHANGED"
	end)
	frame:SetScript("OnHide", function()
		Talented:CloseMenu()
		Talented:UnregisterEvent"MODIFIER_STATE_CHANGED"
	end)
	frame.view = self.TalentView:new(frame, "base", 5, 5)

	self.base = frame
	self.CreateBaseFrame = function (self) return self.base end
	return frame
end

function Talented:EnableUI(enable)
	if enable then
		for _, element in ipairs(self.uielements) do
			element:Enable()
		end
	else
		for _, element in ipairs(self.uielements) do
			element:Disable()
		end
	end
end

function Talented:MakeAlternateView()
	local frame = CreateFrame("Frame", "TalentedAltFrame", UIParent)

	frame:SetFrameStrata("DIALOG")
	if TalentedFrame then
		frame:SetFrameLevel(TalentedFrame:GetFrameLevel() + 5)
	end
	frame:EnableMouse(true)
	frame:SetToplevel(true)
	frame:SetSize(50, 50)
	frame:SetBackdrop({
		bgFile = "Interface\\TutorialFrame\\TutorialFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		edgeSize = 16,
		tileSize = 32,
		insets = {
			left = 5,
			right = 5,
			top = 5,
			bottom = 5
		}
	})

	frame.close = self:CreateCloseButton(frame)
	frame.view = self.TalentView:new(frame, "alt")
	self:LoadFramePosition(frame)
	self:SetFrameLock(frame)

	self.altView = frame
	self.MakeAlternateView = function (self) return self.altView end
	return frame
end

function Talented:OpenCreditsMenu(self)
    if Talented.CreditsFrame then
        Talented.CreditsFrame:Show()
        return
    end

    local frame = CreateFrame("Frame", "TalentedCreditsFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(400, 300)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100) 

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFontObject("GameFontHighlight")
    title:SetPoint("TOP", frame, "TOP", 0, -10)
    title:SetText("Credits")

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(360, 400)
    scrollFrame:SetScrollChild(scrollChild)

    local creditsText = scrollChild:CreateFontString(nil, "OVERLAY")
    creditsText:SetFontObject("GameFontNormal")
    creditsText:SetJustifyH("LEFT")
    creditsText:SetJustifyV("TOP")
    creditsText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -10)
    creditsText:SetText("Talented Addon Creators:\n\n" ..
        "• Jerry - Original Creator back in 2012\n" ..
        "• Dassel-Faerlina - Cataclysm Classic port\n\n" ..
        "Please buy me a coffee so I can keep coding :)")

    local textHeight = creditsText:GetStringHeight()
    scrollChild:SetHeight(textHeight + 100)

    local editBox = CreateFrame("EditBox", nil, scrollChild, "InputBoxTemplate")
    editBox:SetSize(350, 20)
    editBox:SetPoint("TOPLEFT", creditsText, "BOTTOMLEFT", 0, -10)
    editBox:SetAutoFocus(false)
    editBox:SetText("https://buymeacoffee.com/dassel")
    editBox:HighlightText()

    -- Make the EditBox read-only
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
    editBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    -- Instructions label
    local instructions = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -10)
    instructions:SetText("Copy the link above to support me!")

    -- Close button
    local closeButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    closeButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
    closeButton:SetSize(100, 30)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    Talented.CreditsFrame = frame
end
