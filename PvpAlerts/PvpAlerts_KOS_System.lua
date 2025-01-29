local PVP = PVP_Alerts_Main_Table

local IsGuildMate = IsGuildMate
local sort = table.sort
local insert = table.insert
local remove = table.remove
--local concat = table.concat
--local upper = string.upper
local lower = string.lower
--local format = string.format

function PVP_Who_Mouseover()
	local name

	if not PVP.SV.enabled then return end

	if --[[PVP:IsInPVPZone() and]] DoesUnitExist('reticleover') and IsUnitPlayer('reticleover') then
		name = PVP:GetValidName(GetRawUnitName('reticleover'))
		if name then
			PVP:Who(name)
		end
	end
end

local function trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function GetKOSIndex(accName)
	local KOSList = PVP.SV.KOSList
	for k, v in ipairs(KOSList) do
		local dbAccName = contains and PVP:DeaccentString(v.unitAccName) or v.unitAccName
		if lower(dbAccName) == accName then return k end
	end
	return 0
end

local function WhoIsAccInDB(accName, contains)
	accName = lower(accName)
	local accKOSIndex = GetKOSIndex(accName)
	local playerNamesForAcc = {}
	local playersDB = PVP.SV.playersDB
	for k, v in pairs(playersDB) do
		local dbAccName = contains and PVP:DeaccentString(v.unitAccName) or v.unitAccName
		if lower(dbAccName) == accName then insert(playerNamesForAcc, k) end
	end

	if #playerNamesForAcc ~= 0 then
		sort(playerNamesForAcc)
		return playerNamesForAcc, accKOSIndex
	else
		return false
	end
end

local function GetListOfNames(name, contains)
	local rawPlayerNames, lowercaseMatch, deaccentedMatch, looseMatch, stringPositionsArray = {}, {}, {}, {}, {}
	local only
	local playersDB = PVP.SV.playersDB

	if playersDB[name .. '^Mx'] then
		insert(rawPlayerNames, name .. '^Mx')
	elseif playersDB[name .. '^Fx'] then
		insert(rawPlayerNames, name .. '^Fx')
	end

	if contains and #rawPlayerNames == 1 then only = true end

	if contains and #rawPlayerNames == 0 then
		local deaccentName = lower(PVP:DeaccentString(name))

		name = lower(name)

		for k, v in pairs(playersDB) do
			local strippedName = zo_strformat(SI_UNIT_NAME, k)
			local lowerName = lower(strippedName)
			local currentDeaccentedName = lower(PVP:DeaccentString(strippedName))

			if lowerName == name then
				insert(lowercaseMatch, k)
			elseif currentDeaccentedName == deaccentName then
				insert(deaccentedMatch, k)
			elseif zo_strmatch(currentDeaccentedName, deaccentName) then
				local accentBias = zo_strlen(lower(strippedName)) - zo_strlen(currentDeaccentedName)

				if accentBias > 0 then
					local startChar, endChar = zo_strfind(currentDeaccentedName, deaccentName)

					local indice = PVP:FindUTFIndice(lower(strippedName))

					local newStartChar = startChar
					local newEndChar = endChar

					for j = 1, #indice do
						if indice[j] < startChar then
							newStartChar = newStartChar + 1
							newEndChar = newEndChar + 1
						elseif startChar <= indice[j] and endChar >= indice[j] then
							newEndChar = newEndChar + 1
						end
					end

					stringPositionsArray[k] = { startChar = newStartChar, endChar = newEndChar }
				else
					local startChar, endChar = zo_strfind(currentDeaccentedName, deaccentName)
					stringPositionsArray[k] = { startChar = startChar, endChar = endChar }
				end

				insert(looseMatch, k)
			end
		end

		rawPlayerNames = PVP:TableConcat(rawPlayerNames, lowercaseMatch)
		rawPlayerNames = PVP:TableConcat(rawPlayerNames, deaccentedMatch)
	end

	return rawPlayerNames, only, looseMatch, stringPositionsArray
end

local function IsNameInDB(name, contains)
	local playersDB = PVP.SV.playersDB
	local playerNamesInDB
	if PVP:StringEnd(name, "^Mx") or PVP:StringEnd(name, "^Fx") then
		if playersDB[name] then
			return WhoIsAccInDB(playersDB[name].unitAccName, contains)
		else
			return false
		end
	else
		local only, looseMatch, stringPositionsArray
		playerNamesInDB, only, looseMatch, stringPositionsArray = GetListOfNames(name, contains)

		if #playerNamesInDB ~= 0 or #looseMatch ~= 0 then
			if not contains or only then
				return WhoIsAccInDB(playersDB[playerNamesInDB[1]].unitAccName, contains)
			else
				return playerNamesInDB, nil, looseMatch, stringPositionsArray
			end
		else
			return false
		end
	end
end

local function GetCharAccLink(rawName, unitAccName, unitRace)
	return PVP:GetFormattedClassNameLink(rawName, PVP:NameToAllianceColor(rawName, nil, true)) ..
		', ' ..
		GetRaceName(0, unitRace) ..
		', ' ..
		((PVP:StringEnd(rawName, '^Mx') and 'male' or 'female') .. ', ' .. PVP:GetFormattedAccountNameLink(unitAccName, "FFFFFF"))
end

local function GetHighlightedCharAccLink(rawName, startIndex, endIndex)
	local strippedName  = zo_strformat(SI_UNIT_NAME, rawName)
	local nameLength    = zo_strlen(strippedName)
	local allianceColor = PVP:NameToAllianceColor(rawName, nil, true)
	local icon          = PVP:GetFormattedClassIcon(rawName, nil, allianceColor)
	local playersDB = PVP.SV.playersDB

	local normalPartBefore, normalPartAfter, highlightPart

	highlightPart       = PVP:Colorize(
		ZO_LinkHandler_CreateLinkWithoutBrackets(zo_strsub(strippedName, startIndex, endIndex), nil,
			CHARACTER_LINK_TYPE,
			rawName), 'FF00FF')

	if startIndex == 1 then
		normalPartBefore = ""
		if endIndex >= nameLength then
			normalPartAfter = ""
		else
			normalPartAfter = zo_strsub(strippedName, endIndex + 1, nameLength)
		end
	elseif endIndex >= nameLength then
		normalPartBefore = zo_strsub(strippedName, 1, startIndex - 1)
		normalPartAfter = ""
	else
		normalPartBefore = zo_strsub(strippedName, 1, startIndex - 1)
		normalPartAfter = zo_strsub(strippedName, endIndex + 1, nameLength)
	end

	if normalPartBefore ~= "" then
		normalPartBefore = PVP:Colorize(
			ZO_LinkHandler_CreateLinkWithoutBrackets(normalPartBefore, nil, CHARACTER_LINK_TYPE, rawName),
			allianceColor)
	end

	if normalPartAfter ~= "" then
		normalPartAfter = PVP:Colorize(
			ZO_LinkHandler_CreateLinkWithoutBrackets(normalPartAfter, nil, CHARACTER_LINK_TYPE, rawName),
			allianceColor)
	end

	return icon ..
		normalPartBefore ..
		highlightPart ..
		normalPartAfter ..
		', ' ..
		GetRaceName(0, playersDB[rawName].unitRace) ..
		', ' ..
		((PVP:StringEnd(rawName, '^Mx') and 'male' or 'female') .. ', ' .. PVP:GetFormattedAccountNameLink(playersDB[rawName].unitAccName, "FFFFFF"))
end

local function GetCharLink(rawName)
	local playersDB = PVP.SV.playersDB
	return PVP:GetFormattedClassNameLink(rawName, PVP:NameToAllianceColor(rawName)) ..
		', ' ..
		GetRaceName(0, playersDB[rawName].unitRace) .. ', ' ..
		(PVP:StringEnd(rawName, '^Mx') and 'male' or 'female')
end

function PVP:Who(name, contains)

	local foundPlayerNames, KOSIndex, looseMatch, stringPositionsArray

	if type(name) ~= "string" then
		d('Invalid name provided!')
		return
	end

	if name == "" then
		d('No name provided!')
		return
	end

	if zo_strlen(name) <= 2 then
		d('Name has to be longer than 2 characters!')
		return
	end

	local trimmedName = trim(name)
	local isDecorated = IsDecoratedDisplayName(trimmedName)

	if isDecorated then
		foundPlayerNames, KOSIndex = WhoIsAccInDB(trimmedName, contains)
	else
		foundPlayerNames, KOSIndex, looseMatch, stringPositionsArray = IsNameInDB(trimmedName, contains)
	end

	if (not foundPlayerNames or #foundPlayerNames == 0) and (not looseMatch or #looseMatch == 0) then
		if isDecorated then
			d('No such account in the database!')
		else
			d('No such player in the database!')
		end
		return
	end

	if KOSIndex ~= nil then --single player account information returned
		local currentCP = ""
		local playerDbRecord = PVP.SV.playersDB[foundPlayerNames[1]]
		local accName = playerDbRecord.unitAccName
		local sharedGuilds = PVP:GetGuildmateSharedGuilds(accName)
		if self.SV.CP[accName] then currentCP = ' with ' .. PVP:Colorize(self.SV.CP[accName] .. 'cp', 'FFFFFF') .. ',' end
		if isDecorated then
			d('The player ' ..
				PVP:GetFormattedAccountNameLink(accName, "FFFFFF") ..
				currentCP ..
				' has ' ..
				tostring(#foundPlayerNames) .. ' known character' .. (#foundPlayerNames > 1 and 's' or '') .. ':')
		else
			d('Found ' ..
				PVP:GetFormattedAccountNameLink(accName, "FFFFFF") ..
				' account' ..
				currentCP ..
				' for the player ' ..
				PVP:Colorize(zo_strformat(SI_UNIT_NAME, trimmedName), 'FF00FF') ..
				' that has ' .. PVP:Colorize(#foundPlayerNames, 'FFFFFF') .. ' known characters:')
		end
		for i = 1, #foundPlayerNames do
			d(tostring(i) .. '. ' .. GetCharLink(foundPlayerNames[i]))
		end
		if sharedGuilds and sharedGuilds ~= "" then
			d('Shared Guild(s): ' .. sharedGuilds)
		end
		if self.SV.playerNotes[accName] and self.SV.playerNotes[accName] ~= "" then
			d('Note: ' .. self:Colorize(self.SV.playerNotes[accName], "76BCC3"))
		end
	else -- multiple players information returned
		local patternName = zo_strformat(SI_UNIT_NAME, trimmedName)
		local patternLength = zo_strlen(patternName)
		local highlightedName = PVP:Colorize(patternName, 'FF00FF')

		d('Found ' .. tostring(#foundPlayerNames + #looseMatch) .. ' players, similar to ' .. highlightedName .. ':')

		for i = 1, #foundPlayerNames do
			local currentplayerDbRecord = PVP.SV.playersDB[foundPlayerNames[i]]
			local currentAccName = currentplayerDbRecord.unitAccName
			local currentAccCP = ""
			if self.SV.CP[currentAccName] then currentAccCP = ' (' .. self.SV.CP[currentAccName] .. 'cp)' end
			local currentName = foundPlayerNames[i]

			local nameLink = GetCharAccLink(currentName, currentAccName, currentplayerDbRecord.unitRace)

			d(tostring(i) .. '. ' .. nameLink .. currentAccCP)
		end

		if #looseMatch ~= 0 then
			local startFullWord, midFullWord, startPartWord, remainder = {}, {}, {}, {}
			for i = 1, #looseMatch do
				local currentName = looseMatch[i]
				local strippedCurrentName = zo_strformat(SI_UNIT_NAME, currentName)
				local currentNameLength = zo_strlen(strippedCurrentName)
				local first, last = stringPositionsArray[currentName].startChar,
					stringPositionsArray[currentName].endChar
				local startsFullWord = zo_strsub(strippedCurrentName, first - 1, first - 1) == " " or
					zo_strsub(strippedCurrentName, first - 1, first - 1) == "-"
				local endsFullWord = last == currentNameLength or zo_strsub(strippedCurrentName, last + 1, last + 1) ==
					" " or zo_strsub(strippedCurrentName, last + 1, last + 1) == "-"

				if first == 1 then
					if endsFullWord then
						insert(startFullWord, currentName)
					else
						insert(startPartWord, currentName)
					end
				elseif startsFullWord and endsFullWord then
					insert(midFullWord, currentName)
				else
					insert(remainder, currentName)
				end
			end

			if #startFullWord > 1 then sort(startFullWord) end
			if #midFullWord > 1 then sort(midFullWord) end
			if #startPartWord > 1 then sort(startPartWord) end
			if #remainder > 1 then sort(remainder) end

			local looseMatchOutput = {}

			looseMatchOutput = PVP:TableConcat(looseMatchOutput, startFullWord)
			looseMatchOutput = PVP:TableConcat(looseMatchOutput, startPartWord)
			looseMatchOutput = PVP:TableConcat(looseMatchOutput, midFullWord)
			looseMatchOutput = PVP:TableConcat(looseMatchOutput, remainder)

			local indexToHighlight = #startFullWord + #startPartWord + 1

			for i = 1, #looseMatchOutput do
				local currentplayerDbRecord = PVP.SV.playersDB[foundPlayerNames[i]]
				local currentAccName = currentplayerDbRecord.unitAccName
				local currentAccCP = ""
				if self.SV.CP[currentAccName] then currentAccCP = ' (' .. self.SV.CP[currentAccName] .. 'cp)' end
				local currentName = looseMatchOutput[i]
				local strippedCurrentName = zo_strformat(SI_UNIT_NAME, currentName)

				local nameLink

				if i >= indexToHighlight and (zo_strlen(zo_strgsub(strippedCurrentName, "%s+", "")) - patternLength) > 2 then
					nameLink = GetHighlightedCharAccLink(currentName, stringPositionsArray[currentName].startChar,
						stringPositionsArray[currentName].endChar)
				else
					nameLink = GetCharAccLink(currentName, currentAccName, currentplayerDbRecord.unitRace)
				end

				d(tostring(i) .. '. ' .. nameLink .. currentAccCP)
			end
		end
	end
end

local function IsAccFriendKOSorCOOL(charAccName)
	if IsFriend(charAccName) then return true end
	local KOSList = PVP.SV.KOSList
	for i = 1, #KOSList do
		if KOSList[i].unitAccName == charAccName then
			return true
		end
	end
	for i = 1, #PVP.SV.coolList do
		if PVP.SV.coolList[i] == charAccName then return true end
	end
	return false
end

local function IsAccMalformedName(charAccName)
	local KOSList = PVP.SV.KOSList
	for i = 1, #KOSList do
		local unitKOSName = KOSList[i].unitName
		if PVP:DeaccentString(unitKOSName) == charAccName then
			return true, unitKOSName
		end
	end
	for i = 1, #PVP.SV.coolList do
		local unitCOOLName = PVP.SV.coolList[i]
		if PVP:DeaccentString(unitCOOLName) == charAccName then
			return true, unitCOOLName
		end
	end
	return false
end

function PVP:managePlayerNote(noteString)
	local doFunc, charAccName, accNote = noteString:match("([^ ]+) ([^ ]+)%s*(.*)")

	if not doFunc then
		doFunc = noteString
	end

	if doFunc ~= "list" and doFunc ~= "clear" then
		if not charAccName then
			PVP.CHAT:Printf("No account name provided!")
			return
		end

		if charAccName:sub(1, 1) ~= "@" then
			PVP.CHAT:Printf("Must use player @name to assign notes!")
			return
		end

		if not IsAccFriendKOSorCOOL(charAccName) then
			local isMalformed, unitDBName = IsAccMalformedName(charAccName)
			if isMalformed then
				PVP.CHAT:Printf("%s wasn't found in your KOS, COOL. or Friends lists, did you mean \"%s\"?",
					charAccName, self:GetFormattedAccountNameLink(unitDBName, "FFFFFF"))
			else
				PVP.CHAT:Printf("%s must be added to KOS, COOL, or Friends list for notes to display!",
					self:GetFormattedAccountNameLink(charAccName, "FFFFFF"))
			end
		end
	end

	if doFunc == "add" then
		if not self.SV.playerNotes[charAccName] then
			self.SV.playerNotes[charAccName] = accNote
			PVP.CHAT:Printf("Note added for %s!", self:GetFormattedAccountNameLink(charAccName, "FFFFFF"))
		else
			local oldAccNote = self.SV.playerNotes[charAccName]
			self.SV.playerNotes[charAccName] = accNote
			PVP.CHAT:Printf("Note '%s' overwritten for %s!", oldAccNote,
				self:GetFormattedAccountNameLink(charAccName, "FFFFFF"))
		end
	elseif doFunc == "delete" then
		if self.SV.playerNotes[charAccName] then
			self.SV.playerNotes[charAccName] = nil
			PVP.CHAT:Printf("Note deleted for %s!", self:GetFormattedAccountNameLink(charAccName, "FFFFFF"))
		else
			PVP.CHAT:Printf("No note exists for %s!", self:GetFormattedAccountNameLink(charAccName, "FFFFFF"))
		end
	elseif doFunc == "show" then
		if self.SV.playerNotes[charAccName] then
			PVP.CHAT:Printf("Note for %s: %s", self:GetFormattedAccountNameLink(charAccName, "FFFFFF"),
				self:Colorize(self.SV.playerNotes[charAccName], "76BCC3"))
		else
			PVP.CHAT:Printf("No note exists for %s!", self:GetFormattedAccountNameLink(charAccName, "FFFFFF"))
		end
	elseif doFunc == "list" then
		if next(self.SV.playerNotes) then
			PVP.CHAT:Printf("Player notes:")
			for k, v in pairs(self.SV.playerNotes) do
				PVP.CHAT:Printf(self:GetFormattedAccountNameLink(k, "FFFFFF") .. ": " .. self:Colorize(v, "76BCC3"))
			end
		else
			PVP.CHAT:Printf("No notes found!")
		end
	elseif doFunc == "clear" then
		self.SV.playerNotes = {}
		PVP.CHAT:Printf("All notes cleared!")
	else
		PVP.CHAT:Printf("Invalid command! Options are 'add', 'delete', 'show', 'list', or 'clear'.")
	end
end

local function IsAccInKOS(unitAccName)
	local KOSList = PVP.SV.KOSList
	for i = 1, #KOSList do
		if KOSList[i].unitAccName == unitAccName then return KOSList[i].unitName, i end
	end
	return false
end

local function IsKOSAccInDB(unitAccName)
	local nameFromKOS, indexInKOS = IsAccInKOS(unitAccName)
	if nameFromKOS then return nameFromKOS, indexInKOS end

	local foundPlayerNames = {}
	local playersDB = PVP.SV.playersDB
	for k, v in pairs(playersDB) do
		if v.unitAccName == unitAccName then insert(foundPlayerNames, k) end
	end
	if #foundPlayerNames > 0 then
		if #foundPlayerNames == 1 then return foundPlayerNames[1] end
		for i = 1, #foundPlayerNames do
			if playersDB[foundPlayerNames[i]].unitAlliance ~= PVP.allianceOfPlayer then
				return foundPlayerNames[i]
			end
		end
		return foundPlayerNames[1]
	end
	return false
end

local function CheckNameWithoutSuffixes(rawName)
	local maleName = rawName .. "^Mx"
	local femaleName = rawName .. "^Fx"
	local playersDB = PVP.SV.playersDB
	local allianceOfPlayer = PVP.allianceOfPlayer

	if playersDB[maleName] or playersDB[femaleName] then
		if playersDB[maleName] and not playersDB[femaleName] then return maleName end
		if not playersDB[maleName] and playersDB[femaleName] then return femaleName end
		if playersDB[maleName].unitAccName == playersDB[femaleName].unitAccName then
			if playersDB[maleName].unitAlliance ~= allianceOfPlayer and playersDB[femaleName].unitAlliance == allianceOfPlayer then
				return
					maleName
			end
			if playersDB[maleName].unitAlliance == allianceOfPlayer and playersDB[femaleName].unitAlliance ~= allianceOfPlayer then
				return
					femaleName
			end
			if zo_random() > 0.5 then return maleName else return femaleName end
		end
		return rawName, true
	end

	local foundNames = {}
	for k, _ in pairs(playersDB) do
		if PVP:DeaccentString(maleName) == PVP:DeaccentString(k) or PVP:DeaccentString(femaleName) == PVP:DeaccentString(k) then
			insert(foundNames, k)
		end
	end

	if #foundNames ~= 0 then
		PVP.CHAT:Printf('Found multiple names. Please use account name to add the desired person:')
		for i = 1, #foundNames do
			d(tostring(i) ..
				'. ' ..
				PVP:GetFormattedClassNameLink(foundNames[i], PVP:NameToAllianceColor(foundNames[i])) ..
				PVP:GetFormattedAccountNameLink(playersDB[foundNames[i]].unitAccName, "FFFFFF"))
		end
	end

	return false, false, true
end

local function IsNameInDBRecord(unitCharName, playerDbRecord)
	if PVP:CheckName(unitCharName) then
		if playerDbRecord.unitAccName then
			local nameFromKOS, indexInKOS = IsAccInKOS(playerDbRecord.unitAccName)
			if nameFromKOS then return nameFromKOS, indexInKOS end
			return unitCharName
		else
			return false
		end
	end

	local foundRawName, isAmbiguous, isMultiple = CheckNameWithoutSuffixes(unitCharName)

	if isAmbiguous then return foundRawName, false, true end

	if foundRawName then
		local nameFromKOS, indexInKOS = IsAccInKOS(PVP.SV.playersDB[foundRawName].unitAccName)
		if nameFromKOS then return nameFromKOS, indexInKOS end
		return foundRawName
	end

	return false, false, false, isMultiple
end

function PVP:CheckKOSValidity(unitCharName, playerDbRecord)

	local rawName, isInKOS, isAmbiguous, isMultiple

	if IsDecoratedDisplayName(unitCharName) then
		rawName, isInKOS = IsKOSAccInDB(playerDbRecord.unitAccName)
	else
		rawName, isInKOS, isAmbiguous, isMultiple = IsNameInDBRecord(unitCharName, playerDbRecord)
	end

	return rawName, isInKOS, isAmbiguous, isMultiple
end

function PVP_Add_KOS_Mouseover()
	if not PVP.SV.enabled then return end
	if PVP:IsInPVPZone() and DoesUnitExist('reticleover') and IsUnitPlayer('reticleover') then
		local name = PVP:GetValidName(GetRawUnitName('reticleover'))
		if name then
			PVP:AddKOS(name)
		end
	end
end

function PVP_Add_COOL_Mouseover()
	if not PVP.SV.enabled then return end
	if PVP:IsInPVPZone() and DoesUnitExist('reticleover') and IsUnitPlayer('reticleover') then
		local name = PVP:GetValidName(GetRawUnitName('reticleover'))
		if name then
			PVP:AddCOOL(name)
		end
	end
end

function PVP:FindInCOOL(playerName, unitAccName)
	if not playersDB[playerName] then return false end

	local coolList = self.SV.coolList
	local found
	for k, v in pairs(coolList) do
		if unitAccName == v then
			found = k
			break
		end
	end
	if found and found ~= playerName then
		coolList[found] = nil
		coolList[playerName] = unitAccName
		found = playerName
	end
	return found
end

function PVP:FindAccInCOOL(unitPlayerName, unitAccName)
	if not unitAccName then return false end

	local coolList = self.SV.coolList
	local found
	for k, v in pairs(coolList) do
		if unitAccName == v then
			found = k
			break
		end
	end
	if found and found ~= unitPlayerName then
		coolList[found] = nil
		coolList[unitPlayerName] = unitAccName
		found = unitPlayerName
	end
	return found
end

function PVP:AddKOS(playerName, isSlashCommand)
	local SV       = self.SV
	if not SV.showKOSFrame then PVP.CHAT:Printf('KOS/COOL system is disabled!') end

	if not playerName or playerName == "" then
		d("Name was not provided!")
		return
	end
	local KOSList  = SV.KOSList
	local playersDB = SV.playersDB
	local playerDbRecord = cachedPlayerDbUpdates[playerName] or playersDB[playerName] or {}
	playerDbRecord.unitCharName = playerName
	local rawName, isInKOS, isAmbiguous, isMultiple = self:CheckKOSValidity(playerName, playerDbRecord)
	if rawName and (rawName ~= playerName) then
		playerDbRecord = cachedPlayerDbUpdates[rawName] or playersDB[rawName] or {}
		playerDbRecord.unitCharName = rawName
	end

	if not rawName then
		if not isMultiple then PVP.CHAT:Printf("This player is not in the database!") end
		return
	end

	if isAmbiguous then
		PVP.CHAT:Printf("The name is ambiguous!")
		return
	end

	-- if isInKOS then d('This account is already in KOS as: '..self:GetFormattedName(rawName).."!") return end

	local cool = self:FindInCOOL(rawName, playersDB[rawName].unitAccName)
	if cool then
		PVP.CHAT:Printf("Removed from COOL: %s%s!", self:GetFormattedName(playersDB[cool].unitName),
			playersDB[cool].unitAccName)
		SV.coolList[cool] = nil
		self:PopulateReticleOverNamesBuffer()
	end

	if not isInKOS then
		local unitId = 0
		if next(self.idToName) ~= nil and playersDB[rawName] then
			for k, v in pairs(self.idToName) do
				if playersDB[v] and playersDB[v].unitAccName == playersDB[rawName].unitAccName then
					unitId = k
					break
				end
			end
		end
		insert(KOSList,
			{ unitName = rawName, unitAccName = playerDbRecord.unitAccName, unitId = unitId })
		PVP.CHAT:Printf("Added to KOS: %s%s!", self:GetFormattedName(rawName), playerDbRecord.unitAccName)
	else
		PVP.CHAT:Printf("Removed from KOS: %s%s!", self:GetFormattedName(KOSList[isInKOS].unitName),
			KOSList[isInKOS].unitAccName)
		remove(KOSList, isInKOS)
	end
	self:PopulateKOSBuffer()
end

function PVP:AddCOOL(playerName, isSlashCommand)
	local SV       = self.SV

	if not SV.showKOSFrame then PVP.CHAT:Printf('KOS/COOL system is disabled!') end

	if not playerName or playerName == "" then
		PVP.CHAT:Printf("Name was not provided!")
		return
	end

	local KOSList  = SV.KOSList
	local coolList = SV.coolList
	local playersDB = SV.playersDB

	local playerDbRecord = cachedPlayerDbUpdates[playerName] or playersDB[playerName] or {}
	local rawName, isInKOS, isAmbiguous, isMultiple = self:CheckKOSValidity(playerName, playerDbRecord)
	if rawName and (rawName ~= playerName) then
		playerDbRecord = cachedPlayerDbUpdates[rawName] or playersDB[rawName] or {}
	end


	if not rawName then
		if not isMultiple then PVP.CHAT:Printf("This player is not in the database!") end
		return
	end

	-- if isInKOS then d('This account is already in KOS as: '..self:GetFormattedName(rawName).."!") return end
	if isAmbiguous then
		PVP.CHAT:Printf("The name is ambiguous!")
		return
	end

	if isInKOS then
		for i = 1, #KOSList do
			if KOSList[i].unitAccName == playerDbRecord.unitAccName then
				PVP.CHAT:Printf("Removed from KOS: %s%s!", self:GetFormattedName(KOSList[i].unitName),
					KOSList[i].unitAccName)
				remove(KOSList, i)
				break
			end
		end
	end

	local cool = self:FindInCOOL(rawName, playersDB[rawName].unitAccName)


	if not cool then
		coolList[rawName] = playerDbRecord.unitAccName
		PVP.CHAT:Printf("Added to COOL: %s%s!", self:GetFormattedName(rawName), playerDbRecord.unitAccName)
	else
		PVP.CHAT:Printf("Removed from COOL: %s%s!", self:GetFormattedName(rawName), playerDbRecord.unitAccName)
		SV.coolList[cool] = nil
		-- d(self:GetFormattedName(rawName)..self.SV.playersDB[rawName].unitAccName.." is already COOL!")
	end

	self:PopulateKOSBuffer()
	self:PopulateReticleOverNamesBuffer()
end

function PVP:IsKOSOrFriend(playerName, unitAccName)
	if PVP:GetValidName(GetRawUnitName(GetGroupLeaderUnitTag())) == playerName then return "groupleader" end
	if IsPlayerInGroup(playerName) then return "group" end
	if unitAccName and self:IsAccNameInKOS(unitAccName) then return "KOS" end
	if self.SV.showFriends and IsFriend(playerName) then return "friend" end
	if unitAccName and self:FindAccInCOOL(playerName, unitAccName) then return "cool" end
	if self.SV.showGuildMates and IsGuildMate(playerName) then return "guild" end

	return false
end

function PVP:IsEmperor(playerName, currentCampaignActiveEmperor)
	if currentCampaignActiveEmperor == "" or currentCampaignActiveEmperor == nil then return false end
	if playerName == "" or playerName == nil then return false end
	playerName = tostring(playerName)
	if playerName == currentCampaignActiveEmperor .. "^Mx" then return true end
	if playerName == currentCampaignActiveEmperor .. "^Fx" then return true end
	return false
end

function PVP:IsAccNameInKOS(unitAccName)
	local KOSList = self.SV.KOSList
	for i = 1, #KOSList do
		if unitAccName == KOSList[i].unitAccName then return true end
	end
	return false
end

function PVP:FindKOSPlayer(index)
	local currentTime = GetFrameTimeMilliseconds()
	local unitId = 0
	local kosPlayer = self.SV.KOSList[index]
	local localPlayers = self.localPlayers
	for rawName, rec in pairs(localPlayers) do
		if rec.unitAccName == kosPlayer.unitAccName then
			local hasPlayerNote = (self.SV.playerNotes[kosPlayer.unitAccName] ~= nil)
			if rawName ~= kosPlayer.unitName then kosPlayer.unitName = rawName end
			if hasPlayerNote or not IsPlayerInGroup(rawName) then
				unitId = rec.unitId
			end
			break
		end
	end

	local isInNames = (localPlayers[kosPlayer.unitName] ~= nil)

	if kosPlayer.unitId == 0 and unitId ~= 0 and self.SV.playKOSSound and (isInNames or self.playerAlliance[unitId]) then
		if (isInNames and self.SV.playersDB[kosPlayer.unitName].unitAlliance == self.allianceOfPlayer) or self.playerAlliance[unitId] == self.allianceOfPlayer or (IsActiveWorldBattleground() and PVP.bgNames and PVP.bgNames[kosPlayer.unitName] and PVP.bgNames[kosPlayer.unitName] == GetUnitBattlegroundTeam('player')) then
			-- d('KOS failed here')
			if PVP.SV.KOSmode == 2 then
				if currentTime - self.kosSoundDelay > 2000 then
					PlaySound(SOUNDS.CROWN_CRATES_CARD_FLIPPING)
				end
				PlaySound(SOUNDS.CROWN_CRATES_CARD_FLIPPING)
				self.kosSoundDelay = currentTime
			end
		elseif PVP.SV.KOSmode ~= 2 then
			if currentTime - self.kosSoundDelay > 2000 then
				PlaySound(SOUNDS.JUSTICE_STATE_CHANGED)
			end
			PlaySound(SOUNDS.JUSTICE_STATE_CHANGED)
			self.kosSoundDelay = currentTime
		end
	end
	kosPlayer.unitId = unitId
	return unitId
end

function PVP:FindCOOLPlayer(unitName, unitAccName)
	local unitId = 0
	local newName = unitName
	local localPlayers = self.localPlayers
	local playerNotes = self.SV.playerNotes
	local coolList = self.SV.coolList

	for rawName, rec in pairs(localPlayers) do
		if rec.unitAccName == unitAccName then
			local hasPlayerNote = (playerNotes[unitAccName] ~= nil)
			if rawName ~= unitName then
				coolList[rawName] = unitAccName
				coolList[unitName] = nil
				newName = rawName
			end
			if hasPlayerNote or not IsPlayerInGroup(rawName) then
				unitId = rec.unitId
			end
			break
		end
	end

	return unitId, newName
end

local function CheckActive(KOSNamesList, kosActivityList, reportActive)
	if not KOSNamesList or KOSNamesList == {} then return end
	local currentTime = GetFrameTimeSeconds()
	if kosActivityList and kosActivityList.measureTime and (currentTime - kosActivityList.measureTime) < 60 then return end
	QueryCampaignLeaderboardData()
	local currentCampaignId = GetCurrentCampaignId()

	if not kosActivityList then
		kosActivityList = { activeChars = {} }
		for k, v in pairs(KOSNamesList) do
			kosActivityList[k] = { chars = {} }
		end
	end

	for k, v in pairs(kosActivityList) do
		if k ~= "activeChars" and not KOSNamesList[k] then kosActivityList[k] = nil end
	end

	kosActivityList.measureTime = currentTime

	for alliance = 1, 3 do
		for i = 1, GetNumCampaignAllianceLeaderboardEntries(currentCampaignId, alliance) do
			local isPlayer, ranking, charName, alliancePoints, _, accName = GetCampaignAllianceLeaderboardEntryInfo(currentCampaignId, alliance, i)

			if KOSNamesList[accName] then
				if not kosActivityList[accName] then
					kosActivityList[accName] = { chars = {} }
				end
				if not kosActivityList[accName].chars[charName] then
					kosActivityList[accName].chars[charName] = { currentTime = currentTime, points = alliancePoints }
				elseif kosActivityList[accName].chars[charName].points < alliancePoints then
					if not kosActivityList.activeChars[accName] then
						if reportActive then
							d("ACTIVE KOS: " .. charName)
						end
						kosActivityList.activeChars[accName] = charName
					end
					kosActivityList[accName].chars[charName] = { currentTime = currentTime, points = alliancePoints }
				end
			end
		end
	end

	for k, v in pairs(kosActivityList.activeChars) do
		if (kosActivityList[k] and kosActivityList[k].chars[v] and kosActivityList[k].chars[v].currentTime and (currentTime - kosActivityList[k].chars[v].currentTime) > 600) or (not kosActivityList[k]) or (not kosActivityList[k].chars[v]) then
			kosActivityList.activeChars[k] = nil
		end
	end
	return kosActivityList
end

function PVP:RefreshLocalPlayers()
	local SV            = self.SV
	local localPlayers  = {}
	local potentialAllies = {}
	local idToName      = self.idToName
	local playerNames   = self.playerNames
	local playersDB     = SV.playersDB
	local playerNotes   = SV.playerNotes
	local showPlayerNotes  = SV.showPlayerNotes
	local showFriends      = SV.showFriends
	local showGuildMates   = SV.showGuildMates
	local currentTime      = GetFrameTimeMilliseconds()

	for unitId, rawName in pairs(idToName) do
		local dbRec = playersDB[rawName]
		if dbRec then
			local isCool          = self:FindAccInCOOL(rawName, dbRec.unitAccName)
			local isPlayerGrouped = IsPlayerInGroup(rawName)
			local playerNote      = showPlayerNotes and playerNotes[dbRec.unitAccName] or nil
			local hasPlayerNote   = playerNote and (playerNote ~= "")
			local isFriend        = showFriends and IsFriend(rawName) or false
			local isGuildmate     = showGuildMates and IsGuildMate(rawName) or false

			localPlayers[rawName] = {
				unitId        = unitId,
				unitAccName   = dbRec.unitAccName,
				unitAlliance  = dbRec.unitAlliance,
			}

			if hasPlayerNote or ((not isPlayerGrouped) and (isCool or isFriend or isGuildmate)) then
				potentialAllies[rawName] = {
					currentTime     = currentTime,
					unitAccName     = dbRec.unitAccName,
					unitAlliance    = dbRec.unitAlliance,
					isPlayerGrouped = isPlayerGrouped,
					isFriend        = isFriend,
					isGuildmate     = isGuildmate,
					isCool          = isCool,
					playerNote      = hasPlayerNote and playerNote or nil,
					isResurrect     = false
				}
			end
		end
	end

	for rawName, _ in pairs(playerNames) do
		if not localPlayers[rawName] then
			local dbRec = playersDB[rawName]
			if dbRec then
				local isCool          = self:FindAccInCOOL(rawName, dbRec.unitAccName)
				local isPlayerGrouped = IsPlayerInGroup(rawName)
				local playerNote      = showPlayerNotes and playerNotes[dbRec.unitAccName] or nil
				local hasPlayerNote   = playerNote and (playerNote ~= "")
				local isFriend        = showFriends and IsFriend(rawName) or false
				local isGuildmate     = showGuildMates and IsGuildMate(rawName) or false

				localPlayers[rawName] = {
					unitId        = 1234567890,
					unitAccName   = dbRec.unitAccName,
					unitAlliance  = dbRec.unitAlliance,
				}

				if hasPlayerNote or ((not isPlayerGrouped) and (isCool or isFriend or isGuildmate)) then
					potentialAllies[rawName] = {
						currentTime     = currentTime,
						unitAccName     = dbRec.unitAccName,
						unitAlliance    = dbRec.unitAlliance,
						isPlayerGrouped = isPlayerGrouped,
						isFriend        = isFriend,
						isGuildmate     = isGuildmate,
						isCool          = isCool,
						playerNote      = hasPlayerNote and playerNote or nil,
						isResurrect     = false
					}
				end
			end
		end
	end

	local namesToDisplay = self.namesToDisplay
	if namesToDisplay then
		for i = 1, #namesToDisplay do
			local name = namesToDisplay[i]
			if potentialAllies[name] and namesToDisplay[i].isResurrect then
				potentialAllies[name].isResurrect = true
			end
		end
	end

	self.localPlayers     = localPlayers
	self.potentialAllies  = potentialAllies
end

local function BuildImportantIcon(v)
	local importantIcon = ""
	if v.isFriend then importantIcon = importantIcon .. PVP:GetFriendIcon() end
	if v.isCool then importantIcon = importantIcon .. PVP:GetCoolIcon() end
	if v.isGuildmate then
		local guildNames, firstGuildAllianceColor = PVP:GetGuildmateSharedGuilds(v.unitAccName)
		importantIcon = importantIcon .. PVP:GetGuildIcon(nil, firstGuildAllianceColor)
		if not v.isPlayerGrouped then importantIcon = importantIcon .. guildNames end
	end
	return importantIcon
end

local function FormatPlayerNote(playerNote)
	return playerNote and PVP:Colorize("- " .. playerNote, 'C5C29F') or ""
end

local function FormatResurrectIcon(isResurrect)
	return isResurrect and PVP:GetResurrectIcon() or ""
end

function PVP:PopulateKOSBuffer()
	local SV         = self.SV
	if SV.unlocked then return end

	local KOSList    = SV.KOSList
	local coolList   = SV.coolList
	local playersDB  = SV.playersDB
	local allianceOfPlayer = self.allianceOfPlayer

	if SV.showTargetNameFrame then self:UpdateTargetName() end
	local mode = SV.KOSmode
	PVP_KOS_Text:Clear()

	local KOSNamesList = {}
	for i = 1, #KOSList do
		KOSNamesList[KOSList[i].unitAccName] = true
	end

	local currentTime = GetFrameTimeMilliseconds()

	if not self.lastActiveCheckedTime or ((currentTime - self.lastActiveCheckedTime) >= 300000) then
		self.lastActiveCheckedTime = currentTime
		PVP.kosActivityList = CheckActive(KOSNamesList, PVP.kosActivityList, SV.outputNewKos)
	end
	
	self:RefreshLocalPlayers()

	local potentialAllies = self.potentialAllies
	if next(potentialAllies) ~= nil then
		for rawName, v in pairs(potentialAllies) do
			local isAlly = (v.unitAlliance == allianceOfPlayer)
			local validAlliance = (mode == 1) or (mode == 2 and isAlly) or (mode == 3 and not isAlly)
			if validAlliance and not KOSNamesList[v.unitAccName] then
				local resurrectIcon = FormatResurrectIcon(v.isResurrect)
				local importantIcon = BuildImportantIcon(v)
				local playerNoteToken = FormatPlayerNote(v.playerNote)

				PVP_KOS_Text:AddMessage(
					self:GetFormattedClassNameLink(rawName, self:NameToAllianceColor(rawName)) ..
					self:GetFormattedAccountNameLink(v.unitAccName, "40BB40") ..
					resurrectIcon ..
					importantIcon ..
					playerNoteToken
				)
				KOSNamesList[v.unitAccName] = true
			end
		end
	end
	self.KOSNamesList = KOSNamesList

	local activeStringsArray = {}
	for i = 1, #KOSList do
		local unitId = self:FindKOSPlayer(i)
		local rawName = KOSList[i].unitName
		local accName = KOSList[i].unitAccName
		local ally = playersDB[rawName].unitAlliance == allianceOfPlayer
		local isActive = PVP.kosActivityList.activeChars[accName]
		local isResurrect, playerNote, guildNames, firstGuildAllianceColor, guildIcon
		local isGuildmate = SV.showGuildMates and IsGuildMate(accName) or false

		if isGuildmate then
			guildNames, firstGuildAllianceColor = self:GetGuildmateSharedGuilds(accName)
			guildIcon = self:GetGuildIcon(nil, firstGuildAllianceColor)
		else
			guildIcon = ""
			guildNames = ""
		end

		playerNote = SV.playerNotes[accName]
		if playerNote then playerNote = PVP:Colorize("- " .. playerNote, 'C5C29F') else playerNote = "" end

		local namesToDisplay = self.namesToDisplay
		if unitId ~= 0 and #namesToDisplay > 0 then
			for j = 1, #namesToDisplay do
				if namesToDisplay[j] == rawName and namesToDisplay[j].isResurrect then
					isResurrect = true
				end
			end
		end

		if (mode == 2 and ally) or (mode == 3 and not ally) or mode == 1 then
			if unitId ~= 0 then
				local resurrectIcon = FormatResurrectIcon(isResurrect)
				local message = self:GetFormattedClassNameLink(rawName, self:NameToAllianceColor(rawName)) ..
					self:GetFormattedAccountNameLink(accName, ally and "FFFFFF" or "BB4040") ..
					self:GetKOSIcon(nil, ally and "FFFFFF" or nil) ..
					resurrectIcon .. guildIcon .. (ally and "" or guildNames) .. playerNote
				PVP_KOS_Text:AddMessage(message)
			end
		end

		if mode == 4 then
			if isActive then
				local activeMessage = self:GetFormattedClassNameLink(rawName, self:NameToAllianceColor(rawName)) ..
					self:GetFormattedAccountNameLink(accName, ally and "FFFFFF" or "BB4040") .. " ACTIVE"
				insert(activeStringsArray, activeMessage)
			else
				local inactiveMessage = self:GetFormattedClassNameLink(rawName, self:NameToAllianceColor(rawName, true), nil, true) ..
					self:GetFormattedAccountNameLink(accName, "3F3F3F") .. guildIcon .. guildNames .. playerNote
				PVP_KOS_Text:AddMessage(inactiveMessage)
			end
		end
	end

	if mode == 4 then
		for k, v in pairs(coolList) do
			local unitId, newName = self:FindCOOLPlayer(k, v)
			local playerNote = FormatPlayerNote(SV.playerNotes[v])
			local message = self:GetFormattedClassNameLink(newName, self:NameToAllianceColor(newName)) ..
				self:Colorize(v, unitId ~= 0 and "40BB40" or "3F3F3F") ..
				self:GetCoolIcon(nil, unitId == 0) .. playerNote
			PVP_KOS_Text:AddMessage(message)
		end

		for _, v in ipairs(activeStringsArray) do
			PVP_KOS_Text:AddMessage(v)
		end
	end
end

function PVP:SetKOSSliderPosition()
	local mode = PVP.SV.KOSmode
	local control = PVP_KOS_ControlFrame
	local button = PVP_KOS_ControlFrame_Button
	local controlWidth = control:GetWidth() - 10
	local selfWidth = button:GetWidth()
	local effectiveWidth = controlWidth - selfWidth

	local offset1 = zo_round(-effectiveWidth / 2)
	local offset2 = zo_round(-effectiveWidth / 6)
	local offset3 = zo_round(effectiveWidth / 6)
	local offset4 = zo_round(effectiveWidth / 2)

	local _, point, relativeTo, relativePoint, offsetX, offsetY = button:GetAnchor()

	if mode == 1 then
		offsetX = offset1
		button:SetText("All")
	elseif mode == 2 then
		offsetX = offset2
		button:SetText("Allies")
	elseif mode == 3 then
		offsetX = offset3
		button:SetText("Enemies")
	elseif mode == 4 then
		offsetX = offset4
		button:SetText("Setup")
	end

	button:ClearAnchors()
	button:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)
end
