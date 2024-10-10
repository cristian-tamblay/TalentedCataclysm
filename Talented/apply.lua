local Talented = Talented
local L = LibStub("AceLocale-3.0"):GetLocale("Talented")

function Talented:ApplyCurrentTemplate()
	local template = self.template
	local pet = not RAID_CLASS_COLORS[template.class]
	if pet then
		if not self.GetPetClass or self:GetPetClass() ~= template.class then
			self:Print(L["Sorry, I can't apply this template because it doesn't match your pet's class!"])
			self.mode = "view"
			self:UpdateView()
			return
		end
	else
		if select(2, UnitClass"player") ~= template.class then
			self:Print(L["Sorry, I can't apply this template because it doesn't match your class!"])
			self.mode = "view"
			self:UpdateView()
			return
		end
		local state, mastery = self:GetTemplateMasteryState(template)
		if state == "error" then
			self:Print"Runtime error: Impossible to apply this template, It is invalid"
			self.mode = "view"
			self:UpdateView()
			return
		end
		if state == "none" then
			self:Print(L["Nothing to do"])
			self.mode = "view"
			self:UpdateView()
			return
		end
		local actual_mastery = GetPrimaryTalentTree(nil, nil, GetActiveTalentGroup())
		if actual_mastery and actual_mastery ~= mastery then
			self:Print(L["Sorry, I can't apply this template because it has the wrong primary talent tree selected"])
			self.mode = "view"
			self:UpdateView()
			return
		end
	end
	local count = 0
	local current = pet and self.pet_current or self:GetActiveSpec()
	local group = GetActiveTalentGroup(nil, pet)
	-- check if enough talent points are available
	local available = GetUnspentTalentPoints(nil, pet, group)
	for tab, tree in ipairs(self:UncompressSpellData(template.class)) do
		for index = 1, #tree do
			local delta = template[tab][index] - current[tab][index]
			if delta > 0 then
				count = count + delta
			end
		end
	end
	if count == 0 then
		self:Print(L["Nothing to do"])
		self.mode = "view"
		self:UpdateView()
	elseif count > available then
		self:Print(L["Sorry, I can't apply this template because you don't have enough talent points available (need %d)!"], count)
		self.mode = "view"
		self:UpdateView()
	else
		-- self:EnableUI(false)
		self:ApplyTalentPoints()
	end
end

function Talented:ShowLearnButtonTutorial()
	local frame = PlayerTalentFrameLearnButtonTutorial
	local text = PlayerTalentFrameLearnButtonTutorialText
	if not frame.talented_hook then
		frame.talented_hook = text:GetText()
		frame:HookScript("OnHide", function (self)
			local text = PlayerTalentFrameLearnButtonTutorialText
			text:SetText(self.talented_hook)
		end)
	end
	text:SetText(L["Talented has applied your template to the preview. Review the result and press Learn to validate."])
	frame:Show()
end

local function GetTalentPrereqsGridOrdered(tab, index)
    -- Create a table to store the talents by their row and column
    local talentGrid = {}

    -- Populate the talent grid by iterating through all talents in the tab
    for i = 1, GetNumTalents(tab) do
        local name, icon, row, column, rank, maxRank = GetTalentInfo(tab, i)

        -- Exclude talents that return nil or invalid data
        if name and name ~= "" then
            if not talentGrid[row] then
                talentGrid[row] = {}
            end
            -- Store the valid talent in the correct row and column
            talentGrid[row][column] = {
                name = name,
                icon = icon,
                row = row,
                column = column,
                rank = rank,
                maxRank = maxRank,
                index = i -- Store the original index to maintain mapping
            }
        end
    end

    -- Flatten the talentGrid into a single ordered list by row (1-7), then by column (1-4)
    local orderedTalents = {}
    for row = 1, 7 do  -- Iterate over 7 rows
        for column = 1, 4 do  -- Iterate over 4 columns
            local talent = talentGrid[row] and talentGrid[row][column]
            if talent then
                table.insert(orderedTalents, talent)
            end
        end
    end

    -- Get the talent that corresponds to the requested index
    local talent = orderedTalents[index]
    if not talent then
        return nil -- Handle case where the requested talent doesn't exist
    end

    -- Use the valid talent index to get its prerequisites
    local reqRow, reqColumn = GetTalentPrereqs(tab, talent.index)
    if reqRow and reqColumn then
        -- Return the prerequisites' tier and column in the ordered grid
        return reqRow, reqColumn, true -- isLearnable assumed to be true for this example
    else
        return nil -- Handle the case where no prerequisites are found
    end
end

function Talented:ApplyTalentPoints()
    local template = self.template
    local pet = not RAID_CLASS_COLORS[template.class]
    local group = GetActiveTalentGroup(nil, pet)
    ResetGroupPreviewTalentPoints(pet, group)
    local cp = GetUnspentTalentPoints(nil, pet, group)

    local tabs = {1, 2, 3}  -- Assuming 3 talent tabs
    local masteryTab = nil

    if not pet then
        local _, masteryState = self:GetTemplateMasteryState(template)
        assert(masteryState)
        masteryTab = masteryState
        SetPreviewPrimaryTalentTree(masteryState, group)

        -- Prioritize the mastery tab first
        tabs[1], tabs[masteryState] = masteryState, tabs[1]
    end

    -- Function to create a grid of talents for each tab
    local function BuildTalentGrid(tab)
        local talentGrid = {}
        for i = 1, GetNumTalents(tab) do
            local name, icon, row, column, rank, maxRank = GetTalentInfo(tab, i)

            -- Exclude talents that return nil or invalid data
            if name and name ~= "" then
                if not talentGrid[row] then
                    talentGrid[row] = {}
                end
                -- Store the valid talent in the correct row and column
                talentGrid[row][column] = {
                    name = name,
                    icon = icon,
                    row = row,
                    column = column,
                    rank = rank,
                    maxRank = maxRank,
                    index = i -- Store the original index to maintain mapping
                }
            end
        end
        return talentGrid
    end

    -- Apply talents based on the grid and template (numerical order matching grid order)
    local function ApplyTalentsFromGrid(talentGrid, tab)
        -- Get the template for the current tab
        local ttab = template[tab]
		local k = 0
        local needSkip = false
        -- Iterate through talents row by row, column by column
        for row = 1, 7 do  -- Assume max 7 rows
            for column = 1, 4 do  -- Assume max 4 columns
                if needSkip then
                    needSkip = false
                else
                    local talent = talentGrid[row] and talentGrid[row][column]
                    if talent then
                        k = k + 1
                        -- Get the talent index from the grid
                        local talentIndex = talent.index

                        -- Retrieve the desired rank from the template, using the correct numerical order
                        local desiredRank = ttab[k]  -- Use the template's talent index

                        local reqRow, reqColumn = GetTalentPrereqsGridOrdered(tab, k)
                        local rightReq = false
                        if reqRow == row and reqColumn == column+1 then
                            nextTalent = talentGrid[row][column+1]
                            AddPreviewTalentPoints(tab, nextTalent.index, ttab[k+1], pet, group)
                            cp = cp - ttab[k+1]
                            rightReq = true
                        end
                        if desiredRank > 0 and cp > 0 then
                            AddPreviewTalentPoints(tab, talentIndex, desiredRank, pet, group)

                            -- Update unspent talent points
                            cp = cp - desiredRank  -- Adjust for the actual desiredRank applied

                            -- Stop if no points are left
                            if cp <= 0 then
                                return false
                            end
                        end
                        if rightReq then
                            needSkip = true
                            k = k+1
                        end
                    end
                end
            end
        end
        return true
    end

    -- Iterate over the tabs, prioritizing the mastery tab
    for _, tab in ipairs(tabs) do
        if cp <= 0 then
            break
        end
        local talentGrid = BuildTalentGrid(tab)
        local success = ApplyTalentsFromGrid(talentGrid, tab)

        -- Stop outer loop if no points are left
        if not success or cp <= 0 then
            break
        end
    end

    -- Check if we're running out of talent points
    if cp < 0 then
        Talented:Print(L["Error while applying talents! Not enough talent points!"])
        ResetGroupPreviewTalentPoints(pet, group)
        Talented:EnableUI(true)
    else
        -- Switch to the appropriate tab based on whether it's for a pet or player
        if pet then
            PlayerTalentFrameTab2:Click()
        else
            PlayerTalentFrameTab1:Click()
        end
        self:ShowLearnButtonTutorial()
    end
end
