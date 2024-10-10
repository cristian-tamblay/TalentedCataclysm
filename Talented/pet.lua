function Talented:FixPetTemplate(template)
	local data = self:UncompressSpellData(template.class)[1]
	for index = 1, #data - 1 do
		local info = data[index]
		local ninfo = data[index + 1]
		if info.row == ninfo.row and info.column == ninfo.column then
			local talent = not info.inactive
			local value = template[1][index] + template[1][index + 1]
			if talent then
				template[1][index] = value
				template[1][index + 1] = 0
			else
				template[1][index] = 0
				template[1][index + 1] = value
			end
		end
	end
end

if select(2, UnitClass"player") ~= "HUNTER" then return end

function Talented:GetPetClass()
	local _, _, _, _, _, texture = GetTalentTabInfo(1, nil, true)
	return texture and texture:sub(10):upper()
end

local function PetTalentsAvailable()
	local talentGroup = GetActiveTalentGroup(nil, true)
	if not talentGroup then return end
	local has_talent = GetTalentInfo(1, 1, nil, true, talentGroup) or
		GetTalentInfo(1, 2, nil, true, talentGroup)
	return has_talent
end

function Talented:PET_TALENT_UPDATE()
	local class = self:GetPetClass()
	if not class or not PetTalentsAvailable() then return end
	self:FixAlternatesTalents(class)
	local template = self.pet_current
	if not template then
		template = {pet = true, name = TALENT_SPEC_PET_PRIMARY}
		self.pet_current = template
	end
	local talentGroup = GetActiveTalentGroup(nil, true)
	template.talentGroup = talentGroup
	template.class = class
	local info = self:UncompressSpellData(class)
	for tab, tree in ipairs(info) do
		local ttab = template[tab]
		if not ttab then
			ttab = {}
			template[tab] = ttab
		end
		for index in ipairs(tree) do
			ttab[index] = select(5, GetTalentInfo(tab, index, nil, true, talentGroup))
		end
	end
	for _, view in self:IterateTalentViews(template) do
		view:SetClass(class)
		view:Update()
	end
end

function Talented:UNIT_PET(_, unit)
	if unit == "player" then
		self:PET_TALENT_UPDATE()
	end
end

function Talented:InitializePet()
	self:RegisterEvent"UNIT_PET"
	self:RegisterEvent"PET_TALENT_UPDATE"
	self:PET_TALENT_UPDATE()
end

local function fix_prereqs(data, first_index, second_index, use_index)
	for index = second_index + 1, #data do
		local info = data[index]
		if info.req == first_index or info.req == second_index then
			info.req = use_index
		end
	end
end

function Talented:FixAlternatesTalents(class)
	local talentGroup = GetActiveTalentGroup(nil, true)
	local data = self:UncompressSpellData(class)[1]
	for index = 1, #data - 1 do
		local nindex = index + 1
		local info = data[index]
		local ninfo = data[nindex]
		if info.row == ninfo.row and info.column == ninfo.column then
			local talent = GetTalentInfo(1, index, nil, true, talentGroup)
			local ntalent = GetTalentInfo(1, nindex, nil, true, talentGroup)
			if talent then
				if ntalent then
					error(("Unexpected Talent structure for pets (%s/%d/%d)"):format(class, index, 1))
				end
				info.inactive = nil
				ninfo.inactive = true
			else
				if not ntalent then
					error(("Unexpected Talent structure for pets (%s/%d/%d)"):format(class, index, 2))
				end
				info.inactive = true
				ninfo.inactive = nil
			end
			for _, template in pairs(self.db.global.templates) do
				if template.class == class and not template.code then
					local value = template[1][index] + template[1][nindex]
					if talent then
						template[1][index] = value
						template[1][nindex] = 0
						fix_prereqs(data, index, nindex, index)
					else
						template[1][index] = 0
						template[1][nindex] = value
						fix_prereqs(data, index, nindex, nindex)
					end
				end
			end
		end
	end
	for _, view in self:IterateTalentViews() do
		if view.class == class then
			view:SetClass(view.class, true)
		end
	end
end
