local L = LibStub("AceLocale-3.0"):GetLocale("Talented")

local function DisableTalented(s, ...)
	if TalentedFrame then TalentedFrame:Hide() end
	if s:find("%", nil, true) then
		s = s:format(...)
	end
	StaticPopupDialogs.TALENTED_DISABLE = {
		button1 = OKAY,
		text = L["Talented has detected an incompatible change in the talent information that requires an update to Talented. Talented will now Disable itself and reload the user interface so that you can use the default interface."]
			.."|n"..s,
		OnAccept = function()
			DisableAddOn"Talented"
			ReloadUI()
		end,
		timeout = 0,
		exclusive = 1,
		whileDead = 1,
		interruptCinematic = 1
	}
	StaticPopup_Show"TALENTED_DISABLE"
end

local function GetTalentInfoGridOrdered(tab, index)
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

    -- Return the talent that corresponds to the requested index
    local talent = orderedTalents[index]
    if talent then
        return talent.name, talent.icon, talent.row, talent.column, talent.rank, talent.maxRank, talent.index
    else
        return nil -- Handle the case where the requested index doesn't exist
    end
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


function Talented:CheckSpellData(class)
	if GetNumTalentTabs() < 1 then return end -- postpone checking without failing
	local spelldata, tabdata  = self.spelldata[class], self.tabdata[class]
	local invalid
	if #spelldata > GetNumTalentTabs() then
		invalid = true
		for i = #spelldata, GetNumTalentTabs() + 1, -1 do
			spelldata[i] = nil
		end
	end
	for tab = 1, GetNumTalentTabs() do
		local talents = spelldata[tab]
		if not talents then
			invalid = true
			talents = {}
			spelldata[tab] = talents
		end
		local _, name, _, _, _, background = GetTalentTabInfo(tab)
		tabdata[tab].name = name -- no need to mark invalid for these
		tabdata[tab].background = background
		if #talents > GetNumTalents(tab) then
			invalid = true
			for i = #talents, GetNumTalents(tab) + 1, -1 do
				talents[i] = nil
			end
		end
		for index = 1, GetNumTalents(tab) do
			local talent = talents[index]
			if not talent then
				return DisableTalented("%s:%d:%d MISSING TALENT", class, tab, index)
			end
			local name, icon, row, column, _, ranks = GetTalentInfoGridOrdered(tab, index)
			if not name then
				if not talent.inactive then
					talent.inactive = true
					invalid = true
				end
			else
				if talent.inactive then
					return DisableTalented("%s:%d:%d NOT INACTIVE", class, tab, index)
				end
				local found
				for _, spell in ipairs(talent.ranks) do
					local n, s = GetSpellInfo(spell)
					if n == name then found = true break end
				end
				if not found then
					local n, s = pcall(GetSpellInfo, talent.ranks[1])
					return DisableTalented("%s:%d:%d MISMATCHED %s ~= %s", class, tab, index, s or "unknown talent-"..talent.ranks[1], name)
				end
				if row ~= talent.row then
					invalid = true
					talent.row = row
				end
				if column ~= talent.column then
					invalid = true
					talent.column = column
				end
				if ranks > #talent.ranks then
					return DisableTalented("%s:%d:%d MISSING RANKS %d ~= %d", class, tab, index, #talent.ranks, ranks)
				end
				if ranks < #talent.ranks then
					invalid = true
					for i = #talent.ranks, ranks + 1, -1 do
						talent.ranks[i] = nil
					end
				end

				local req_row, req_column, isLearnable = GetTalentPrereqsGridOrdered(tab, index)
				if req2 then
					invalid = true
				end
				if not req_row then
					if talent.req then
						invalid = true
						talent.req = nil
						return
					end
				else
					local req = talents[talent.req]
					if not req or req.row ~= req_row or req.column ~= req_column then
						invalid = true
						-- it requires another pass to get the right talent.
						talent.req = 0
					end
				end
			end
		end
		for index = 1, GetNumTalents(tab) do
			local talent = talents[index]
			if talent.req == 0 then
				local row, column = GetTalentPrereqs(tab, index)
				for j = 1, GetNumTalents(tab) do
					if talents[j].row == row and talents[j].column == column then
						talent.req = j
						break
					end
				end
				assert(talent.req ~= 0)
			end
		end
	end
	if invalid then
		self:Print(L["WARNING: Talented has detected that its talent data is outdated. Talented will work fine for your class for this session but may have issue with other classes. You should update Talented if you can."])
	end
	self.CheckSpellData = nil
end
