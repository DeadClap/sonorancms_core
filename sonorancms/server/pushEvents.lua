local vehicleGamePool = {}
local sub = string.sub
local ostime = os.time
local tonumber = tonumber
local loggerBuffer = {}
local explosionTypes = {'GRENADE', 'GRENADELAUNCHER', 'STICKYBOMB', 'MOLOTOV', 'ROCKET', 'TANKSHELL', 'HI_OCTANE', 'CAR', 'PLANE', 'PETROL_PUMP', 'BIKE', 'DIR_STEAM', 'DIR_FLAME', 'DIR_WATER_HYDRANT',
	'DIR_GAS_CANISTER', 'BOAT', 'SHIP_DESTROY', 'TRUCK', 'BULLET', 'SMOKEGRENADELAUNCHER', 'SMOKEGRENADE', 'BZGAS', 'FLARE', 'GAS_CANISTER', 'EXTINGUISHER', 'PROGRAMMABLEAR', 'TRAIN', 'BARREL',
	'PROPANE', 'BLIMP', 'DIR_FLAME_EXPLODE', 'TANKER', 'PLANE_ROCKET', 'VEHICLE_BULLET', 'GAS_TANK', 'BIRD_CRAP', 'RAILGUN', 'BLIMP2', 'FIREWORK', 'SNOWBALL', 'PROXMINE', 'VALKYRIE_CANNON',
	'AIR_DEFENCE', 'PIPEBOMB', 'VEHICLEMINE', 'EXPLOSIVEAMMO', 'APCSHELL', 'BOMB_CLUSTER', 'BOMB_GAS', 'BOMB_INCENDIARY', 'BOMB_STANDARD', 'TORPEDO', 'TORPEDO_UNDERWATER', 'BOMBUSHKA_CANNON',
	'BOMB_CLUSTER_SECONDARY', 'HUNTER_BARRAGE', 'HUNTER_CANNON', 'ROGUE_CANNON', 'MINE_UNDERWATER', 'ORBITAL_CANNON', 'BOMB_STANDARD_WIDE', 'EXPLOSIVEAMMO_SHOTGUN', 'OPPRESSOR2_CANNON', 'MORTAR_KINETIC',
	'VEHICLEMINE_KINETIC', 'VEHICLEMINE_EMP', 'VEHICLEMINE_SPIKE', 'VEHICLEMINE_SLICK', 'VEHICLEMINE_TAR', 'SCRIPT_DRONE', 'RAYGUN', 'BURIEDMINE', 'SCRIPT_MISSIL'}

--- logger
--- Sends logs to the logging buffer, then to the SonoranCMS game panel
---@param src number the source of the player who did the action
---@param type string the action type
---@param data table|nil the event data
local function serverLogger(src, type, data)
	loggerBuffer[#loggerBuffer + 1] = {src = src, type = type, data = data or false, ts = os.time()}
	while #loggerBuffer > 1000 do
		table.remove(loggerBuffer, 1)
	end
end

--- Checks is a property is invalid
---@param property any
---@param invalidType any
local function isInvalid(property, invalidType)
	return (property == nil or property == invalidType)
end

CreateThread(function()
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_KICK_PLAYER', function(data)
		if data ~= nil then
			local targetPlayer = nil
			for i = 0, GetNumPlayerIndices() - 1 do
				local p = GetPlayerFromIndex(i)
				if tonumber(p) == tonumber(data.data.playerSource) then
					targetPlayer = p
				end
			end
			if targetPlayer ~= nil then
				local reason = 'Kicked By SonoranCMS Management Panel: ' .. data.data.reason
				local targetPlayerName = GetPlayerName(targetPlayer)
				DropPlayer(targetPlayer, reason)
				TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' dropping player ' .. targetPlayerName .. ' for reason: ' .. reason)
				manuallySendPayload()
			else
				TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' but player with source ' .. data.data.playerSource .. ' was not found')
			end
		end
	end)
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_SET_PLAYER_MONEY', function(data)
		if data ~= nil then
			MySQL.single('SELECT * FROM `players` WHERE `citizenid` = ? LIMIT 1', {data.data.citizenId}, function(row)
				if not row then
					TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' but the PlayerData for ' .. data.data.citizenId .. ' was not found')
					return
				end
				local PlayerData = row
				local PlayerDataMoney = json.decode(PlayerData.money)
				local validType = false
				for k, v in pairs(PlayerDataMoney) do
					if k == data.data.moneyType then
						PlayerDataMoney[k] = data.data.amount
						validType = true
					end
				end
				PlayerDataMoney = json.encode(PlayerDataMoney)
				if validType then
					MySQL.update('UPDATE players SET money = ? WHERE citizenid = ?', {PlayerDataMoney, data.data.citizenId})
					TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' setting money for ' .. PlayerData.name .. ' to ' .. PlayerDataMoney)
					manuallySendPayload()
				else
					TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' but money type ' .. data.data.moneyType .. ' was not found')
				end
			end)
		end
	end)
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_DESPAWN_VEHICLE', function(data)
		if data ~= nil then
			for i = 0, GetNumPlayerIndices() - 1 do
				local p = GetPlayerFromIndex(i)
				if p ~= nil then
					TriggerClientEvent('SonoranCMS::core::DeleteVehicle', p, data.data.vehicleHandle)
				end
			end
			TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' despawning vehicle with handle ' .. data.data.vehicleHandle)
			manuallySendPayload()
		else
			TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' but vehicle with handle ' .. data.data.vehicleHandle .. ' was not found')
		end
	end)
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_REPAIR_VEHICLE', function(data)
		if data ~= nil then
			for i = 0, GetNumPlayerIndices() - 1 do
				local p = GetPlayerFromIndex(i)
				if p ~= nil then
					TriggerClientEvent('SonoranCMS::core::RepairVehicle', p, data.data.vehicleHandle)
				end
			end
			TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' repairing vehicle with handle ' .. data.data.vehicleHandle)
			manuallySendPayload()
		else
			TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' but vehicle with handle ' .. data.data.vehicleHandle .. ' was not found')
		end
	end)
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_WARN_PLAYER', function(data)
		if data ~= nil then
			local targetPlayer = nil
			for i = 0, GetNumPlayerIndices() - 1 do
				local p = GetPlayerFromIndex(i)
				if tonumber(p) == tonumber(data.data.playerSource) then
					targetPlayer = p
				end
			end
			if targetPlayer ~= nil then
				local targetPlayerName = GetPlayerName(targetPlayer)
				TriggerClientEvent('SonoranCMS::core::HandleWarnedPlayer', targetPlayer, data.data.message)
				TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' warning player ' .. targetPlayerName .. ' for reason: ' .. data.data.message)
				manuallySendPayload()
			else
				TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' but player with source ' .. data.data.playerSource .. ' was not found')
			end
		end
	end)
	TriggerEvent('sonorancms::RegisterPushEvent', 'EXECUTE_RESOURCE_COMMAND', function(data)
		if data ~= nil then
			if data.data.resourceName then
				ExecuteCommand(data.data.command .. ' ' .. data.data.resourceName)
				TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' executing command ' .. data.data.command .. ' ' .. data.data.resourceName)
				manuallySendPayload()
			else
				ExecuteCommand(data.data.command)
				TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' executing command ' .. data.data.command)
				manuallySendPayload()
			end
		end
	end)
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_SET_CHAR_INFO', function(data)
		if data ~= nil then
			MySQL.single('SELECT * FROM `players` WHERE `citizenid` = ? LIMIT 1', {data.data.citizenId}, function(row)
				if not row then
					TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' but the PlayerData for ' .. data.data.citizenId .. ' was not found')
					return
				end
				local PlayerData = row
				PlayerData.charinfo = json.decode(PlayerData.charinfo)
				if data.data.charInfo.firstName and data.data.charInfo.firstName ~= '' then
					debugLog('Setting first name to ' .. data.data.charInfo.firstName)
					PlayerData.charinfo.firstname = data.data.charInfo.firstName
				end
				if data.data.charInfo.lastName and data.data.charInfo.lastName ~= '' then
					debugLog('Setting last name to ' .. data.data.charInfo.lastName)
					PlayerData.charinfo.lastname = data.data.charInfo.lastName
				end
				if data.data.charInfo.birthDate and data.data.charInfo.birthDate ~= '' then
					debugLog('Setting birth date to ' .. data.data.charInfo.birthDate)
					PlayerData.charinfo.birthdate = data.data.charInfo.birthDate
				end
				if data.data.charInfo.gender and data.data.charInfo.gender ~= '' then
					debugLog('Setting gender to ' .. data.data.charInfo.gender)
					PlayerData.charinfo.gender = data.data.charInfo.gender
				end
				if data.data.charInfo.nationality and data.data.charInfo.nationality ~= '' then
					debugLog('Setting nationality to ' .. data.data.charInfo.nationality)
					PlayerData.charinfo.nationality = data.data.charInfo.nationality
				end
				if data.data.charInfo.phoneNumber and data.data.charInfo.phoneNumber ~= '' then
					debugLog('Setting phone number to ' .. data.data.charInfo.phoneNumber)
					PlayerData.charinfo.phone = data.data.charInfo.phoneNumber
				end
				local NewCharInfo = json.encode(PlayerData.charinfo)
				MySQL.update('UPDATE players SET charinfo = ? WHERE citizenid = ?', {NewCharInfo, PlayerData.citizenid}, function(affectedRows)
					debugLog('Updated charinfo for ' .. PlayerData.name .. ' to ' .. NewCharInfo .. ' with ' .. affectedRows .. ' rows affected')
				end)
				TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' saving player ' .. PlayerData.name)
				manuallySendPayload()
			end)
		else
			TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' but character ID ' .. data.data.citizenId .. ' was not found')
		end
	end)
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_SET_CHAR_VEHICLE', function(data)
		if data ~= nil then
			MySQL.single('SELECT * FROM `player_vehicles` WHERE `id` = ? LIMIT 1', {data.data.vehicleId}, function(row)
				if not row then
					TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' but the vehicle with ID ' .. data.data.vehicleId .. ' was not found')
					return
				else
					local vehData = row
					if data.data.plate and data.data.plate ~= '' then
						vehData.plate = data.data.plate
					end
					if data.data.garage and data.data.garage ~= '' then
						vehData.garage = data.data.garage
					end
					if data.data.fuel and data.data.fuel ~= '' then
						vehData.fuel = data.data.fuel
					end
					if data.data.engine and data.data.engine ~= '' then
						vehData.engine = data.data.engine
					end
					if data.data.body and data.data.body ~= '' then
						vehData.body = data.data.body
					end
					if data.data.state and data.data.state ~= '' then
						vehData.state = data.data.state
					end
					if data.data.mileage and data.data.mileage ~= '' then
						vehData.drivingdistance = data.data.mileage
					end
					if data.data.balance and data.data.balance ~= '' then
						vehData.balance = data.data.balance
					end
					if data.data.paymentAmount and data.data.paymentAmount ~= '' then
						vehData.paymentamount = data.data.paymentAmount
					end
					if data.data.paymentsLeft and data.data.paymentsLeft ~= '' then
						vehData.paymentsleft = data.data.paymentsLeft
					end
					if data.data.financeTime and data.data.financeTime ~= '' then
						vehData.financetime = data.data.financeTime
					end
					MySQL.update(
									'UPDATE player_vehicles SET plate = ?, garage = ?, fuel = ?, engine = ?, body = ?, state = ?, drivingdistance = ?, balance = ?, paymentamount = ?, paymentsleft = ?, financetime = ? WHERE id = ?',
									{vehData.plate, vehData.garage, vehData.fuel, vehData.engine, vehData.body, vehData.state, vehData.drivingdistance, vehData.balance, vehData.paymentamount, vehData.financetime,
										data.data.vehicleId}, function(affectedRows)
										debugLog('Updated vehicle metadata for ' .. data.data.vehicleId .. ' to ' .. json.encode(vehData) .. ' with ' .. affectedRows .. ' rows affected')
									end)
					manuallySendPayload()
				end
			end)
		end
	end)
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_ADD_CHAR_VEHICLE', function(data)
		if data ~= nil then
			MySQL.single('SELECT * FROM `players` WHERE `citizenid` = ? LIMIT 1', {data.data.citizenId}, function(row)
				if not row then
					TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' but the PlayerData for ' .. data.data.citizenId .. ' was not found')
					return
				else
					local PlayerData = row
					PlayerData.charinfo = json.decode(PlayerData.charinfo)
					MySQL.insert('INSERT INTO player_vehicles (citizenid, garage, vehicle, plate, state) VALUES (?, ?, ?, ?, ?)',
					             {PlayerData.citizenid, data.data.garage, data.data.model, data.data.plate, data.data.state}, function(affectedRows)
						debugLog('Added vehicle metadata for ' .. PlayerData.name .. ' to ' .. vehData .. ' with ' .. affectedRows .. ' rows affected')
					end)
					TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' saving player ' .. PlayerData.name)
					manuallySendPayload()
				end
			end)
		else
			TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' but character ID ' .. data.data.citizenId .. ' was not found')
		end
	end)
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_TRANSFER_CHAR_VEHICLE', function(data)
		if data ~= nil then
			MySQL.single('SELECT * FROM `player_vehicles` WHERE `id` = ? LIMIT 1', {data.data.vehicleId}, function(row)
				if not row then
					TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' but the vehicle with ID ' .. data.data.vehicleId .. ' was not found')
					return
				else
					MySQL.update('UPDATE player_vehicles SET citizenid = ? WHERE id = ?', {data.data.newCitizenId, data.data.vehicleId}, function(affectedRows)
						debugLog('Updated vehicle owner for ' .. data.data.vehicleId .. ' to ' .. data.data.newCitizenId .. ' with ' .. affectedRows .. ' rows affected')
					end)
					manuallySendPayload()
				end
			end)
		end
	end)
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_REPAIR_CHAR_VEHICLE', function(data)
		if data ~= nil then
			MySQL.single('SELECT * FROM `player_vehicles` WHERE `id` = ? LIMIT 1', {data.data.vehicleId}, function(row)
				if not row then
					TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' but the vehicle with ID ' .. data.data.vehicleId .. ' was not found')
					return
				else
					MySQL.update('UPDATE player_vehicles SET engine = ?, body = ? WHERE id = ?', {1000, 1000, data.data.vehicleId}, function(affectedRows)
						debugLog('Updated vehicle health for ' .. data.data.vehicleId .. ' to 1000 with ' .. affectedRows .. ' rows affected')
					end)
					manuallySendPayload()
				end
			end)
		end
	end)
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_DELETE_CHAR_VEHICLE', function(data)
		if data ~= nil then
			MySQL.single('SELECT * FROM `player_vehicles` WHERE `id` = ? LIMIT 1', {data.data.vehicleId}, function(row)
				if not row then
					TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' but the vehicle with ID ' .. data.data.vehicleId .. ' was not found')
					return
				else
					MySQL.query('DELETE FROM player_vehicles WHERE id = ?', {data.data.vehicleId}, function(affectedRows)
						debugLog('Deleted vehicle with ID ' .. data.data.vehicleId .. ' with ' .. affectedRows .. ' rows affected')
					end)
					manuallySendPayload()
				end
			end)
		end
	end)
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_REMOVE_GANG_CONFIG', function(data)
		if data ~= nil then
			local originalData = LoadResourceFile('qb-core', './shared/gangs.lua')
			local validGangs = {}
			local function filterGangs(gangs)
				local validGangs = {}
				for gangName, gangData in pairs(gangs) do
					validGangs[gangName] = gangData
				end
				return validGangs
			end
			local tempEnv = {}
			setmetatable(tempEnv, {__index = _G})
			local func, err = load(originalData, 'gangData', 't', tempEnv)
			if not func then
				print('Error loading data: ' .. err)
				return
			end
			func()
			local loadedGangs = tempEnv.QBShared and tempEnv.QBShared.Gangs
			if not loadedGangs or next(loadedGangs) == nil then
				print('Error: QBShared.Gangs table is missing or empty.')
				return
			end
			validGangs = filterGangs(loadedGangs)
			if not validGangs[data.data.gangId] then
				debugLog('Error: Gang ' .. data.data.gangId .. ' does not exist.')
				return
			else
				validGangs[data.data.gangId] = nil
				local function convertToPlainText(gangsTable)
					local lines = {'QBShared = QBShared or {}'}
					table.insert(lines, 'QBShared.Gangs = {')
					for gangName, gangData in pairs(gangsTable) do
						local gangLine = '\t[\'' .. gangName .. '\'] = {'
						table.insert(lines, gangLine)
						local labelLine = '\t\tlabel = ' .. string.format('\'%s\',', gangData.label)
						table.insert(lines, labelLine)
						table.insert(lines, '\t\tgrades = {')
						for gradeIndex, gradeData in pairs(gangData.grades) do
							if gradeData.isboss then
								local gradeLine = string.format('\t\t\t[\'%s\'] = { name = \'%s\', isboss = %s },', gradeIndex, gradeData.name, gradeData.isboss)
								table.insert(lines, gradeLine)
							else
								local gradeLine = string.format('\t\t\t[\'%s\'] = { name = \'%s\' },', gradeIndex, gradeData.name)
								table.insert(lines, gradeLine)
							end
						end
						table.insert(lines, '\t\t},')
						table.insert(lines, '\t},')
					end
					table.insert(lines, '}')
					return table.concat(lines, '\n')
				end
				local modifiedData = convertToPlainText(validGangs)
				TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' removing gang ' .. data.data.gangId)
				-- Too spammy
				-- TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Saving gangs.lua with new data: ' .. modifiedData)
				SaveResourceFile('qb-core', './shared/gangs.lua', modifiedData, -1)
				manuallySendPayload()
			end
		end
	end)
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_EDIT_GANG_CONFIG', function(data)
		if data ~= nil then
			local originalData = LoadResourceFile('qb-core', './shared/gangs.lua')
			local validGangs = {}
			local function filterGangs(gangs)
				local validGangs = {}
				for gangName, gangData in pairs(gangs) do
					validGangs[gangName] = gangData
				end
				return validGangs
			end
			local tempEnv = {}
			setmetatable(tempEnv, {__index = _G})
			local func, err = load(originalData, 'gangData', 't', tempEnv)
			if not func then
				print('Error loading data: ' .. err)
				return
			end
			func()
			local loadedGangs = tempEnv.QBShared and tempEnv.QBShared.Gangs
			if not loadedGangs or next(loadedGangs) == nil then
				print('Error: QBShared.Gangs table is missing or empty.')
				return
			end
			validGangs = filterGangs(loadedGangs)
			if not validGangs[data.data.id] then
				debugLog('Error: Gang ' .. data.data.id .. ' does not exist.')
				return
			else
				local gradesTable = {}
				for gradeIndex, gradeData in pairs(data.data.grades) do
					if gradeData.isBoss then
						gradesTable[gradeIndex - 1] = {name = gradeData.name, isboss = gradeData.isBoss}
					else
						gradesTable[gradeIndex - 1] = {name = gradeData.name}
					end
				end
				validGangs[data.data.id] = {label = data.data.label, grades = gradesTable}
				local function convertToPlainText(gangsTable)
					local lines = {'QBShared = QBShared or {}'}
					table.insert(lines, 'QBShared.Gangs = {')
					for gangName, gangData in pairs(gangsTable) do
						local gangLine = '\t[\'' .. gangName .. '\'] = {'
						table.insert(lines, gangLine)
						local labelLine = '\t\tlabel = ' .. string.format('\'%s\',', gangData.label)
						table.insert(lines, labelLine)
						table.insert(lines, '\t\tgrades = {')
						for gradeIndex, gradeData in pairs(gangData.grades) do
							if gradeData.isboss then
								local gradeLine = string.format('\t\t\t[\'%s\'] = { name = \'%s\', isboss = %s },', gradeIndex, gradeData.name, gradeData.isboss)
								table.insert(lines, gradeLine)
							else
								local gradeLine = string.format('\t\t\t[\'%s\'] = { name = \'%s\' },', gradeIndex, gradeData.name)
								table.insert(lines, gradeLine)
							end
						end
						table.insert(lines, '\t\t},')
						table.insert(lines, '\t},')
					end
					table.insert(lines, '}')
					return table.concat(lines, '\n')
				end
				local modifiedData = convertToPlainText(validGangs)
				TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' editing gang ' .. data.data.id)
				-- Too spammy
				-- TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Saving gangs.lua with new data: ' .. modifiedData)
				SaveResourceFile('qb-core', './shared/gangs.lua', modifiedData, -1)
				manuallySendPayload()
			end
		end
	end)
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_ADD_GANG_CONFIG', function(data)
		if data ~= nil then
			local originalData = LoadResourceFile('qb-core', './shared/gangs.lua')
			local validGangs = {}
			local function filterGangs(gangs)
				local validGangs = {}
				for gangName, gangData in pairs(gangs) do
					validGangs[gangName] = gangData
				end
				return validGangs
			end
			local tempEnv = {}
			setmetatable(tempEnv, {__index = _G})
			local func, err = load(originalData, 'gangData', 't', tempEnv)
			if not func then
				print('Error loading data: ' .. err)
				return
			end
			func()
			local loadedGangs = tempEnv.QBShared and tempEnv.QBShared.Gangs
			if not loadedGangs or next(loadedGangs) == nil then
				print('Error: QBShared.Gangs table is missing or empty.')
				return
			end
			validGangs = filterGangs(loadedGangs)
			if validGangs[data.data.id] then
				debugLog('Error: Gang ' .. data.data.id .. ' already exists.')
				return
			else
				local gradesTable = {}
				for gradeIndex, gradeData in pairs(data.data.grades) do
					if gradeData.isBoss then
						gradesTable[gradeIndex - 1] = {name = gradeData.name, isboss = gradeData.isBoss}
					else
						gradesTable[gradeIndex - 1] = {name = gradeData.name}
					end
				end
				validGangs[data.data.id] = {label = data.data.label, grades = gradesTable}
				exports['qb-core']:AddGang(data.data.id, {label = data.data.label, grades = gradesTable})
				local function convertToPlainText(gangsTable)
					local lines = {'QBShared = QBShared or {}'}
					table.insert(lines, 'QBShared.Gangs = {')
					for gangName, gangData in pairs(gangsTable) do
						local gangLine = '\t[\'' .. gangName .. '\'] = {'
						table.insert(lines, gangLine)
						local labelLine = '\t\tlabel = ' .. string.format('\'%s\',', gangData.label)
						table.insert(lines, labelLine)
						table.insert(lines, '\t\tgrades = {')
						for gradeIndex, gradeData in pairs(gangData.grades) do
							if gradeData.isboss then
								local gradeLine = string.format('\t\t\t[\'%s\'] = { name = \'%s\', isboss = %s },', gradeIndex, gradeData.name, gradeData.isboss)
								table.insert(lines, gradeLine)
							else
								local gradeLine = string.format('\t\t\t[\'%s\'] = { name = \'%s\' },', gradeIndex, gradeData.name)
								table.insert(lines, gradeLine)
							end
						end
						table.insert(lines, '\t\t},')
						table.insert(lines, '\t},')
					end
					table.insert(lines, '}')
					return table.concat(lines, '\n')
				end
				local modifiedData = convertToPlainText(validGangs)
				TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' adding gang ' .. data.data.id)
				-- Too spammy
				-- TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Saving gangs.lua with new data: ' .. modifiedData)
				SaveResourceFile('qb-core', './shared/gangs.lua', modifiedData, -1)
				manuallySendPayload()
			end
		end
	end)
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_REMOVE_JOB_CONFIG', function(data)
		if data ~= nil then
			local originalData = LoadResourceFile('qb-core', './shared/jobs.lua')
			local validJobs = {}
			local function filterJobs(jobs)
				local validJobs = {}
				for jobName, jobData in pairs(jobs) do
					validJobs[jobName] = jobData
				end
				return validJobs
			end
			local tempEnv = {}
			setmetatable(tempEnv, {__index = _G})
			local func, err = load(originalData, 'jobData', 't', tempEnv)
			if not func then
				print('Error loading data: ' .. err)
				return
			end
			func()
			local loadedJobs = tempEnv.QBShared and tempEnv.QBShared.Jobs
			if not loadedJobs or next(loadedJobs) == nil then
				print('Error: QBShared.Jobs table is missing or empty.')
				return
			end
			validJobs = filterJobs(loadedJobs)
			if not validJobs[data.data.jobId] then
				debugLog('Error: Job ' .. data.data.jobId .. ' does not exist.')
				return
			else
				validJobs[data.data.jobId] = nil
				local function convertToPlainText(jobTable)
					local lines = {'QBShared = QBShared or {}'}
					table.insert(lines, 'QBShared.ForceJobDefaultDutyAtLogin = true -- true: Force duty state to jobdefaultDuty | false: set duty state from database last saved')
					table.insert(lines, 'QBShared.Jobs = {')
					for jobName, jobData in pairs(jobTable) do
						local gangLine = '\t[\'' .. jobName .. '\'] = {'
						table.insert(lines, gangLine)
						local labelLine = '\t\tlabel = ' .. string.format('\'%s\',', jobData.label)
						table.insert(lines, labelLine)
						if jobData.type then
							local typeLine = '\t\ttype = \'' .. jobData.type .. '\','
							table.insert(lines, typeLine)
						end
						if jobData.defaultDuty ~= nil then
							local defaultDutyLine = '\t\tdefaultDuty = ' .. tostring(jobData.defaultDuty) .. ','
							table.insert(lines, defaultDutyLine)
						end
						if jobData.offDutyPay ~= nil then
							local offDutyPayLine = '\t\toffDutyPay = ' .. tostring(jobData.offDutyPay) .. ','
							table.insert(lines, offDutyPayLine)
						end
						table.insert(lines, '\t\tgrades = {')
						for gradeIndex, gradeData in pairs(jobData.grades) do
							if gradeData.isboss then
								local gradeLine = string.format('\t\t\t[\'%s\'] = { name = \'%s\', payment = %s, isboss = %s },', gradeIndex, gradeData.name, gradeData.payment, gradeData.isboss)
								table.insert(lines, gradeLine)
							else
								local gradeLine = string.format('\t\t\t[\'%s\'] = { name = \'%s\', payment = %s },', gradeIndex, gradeData.name, gradeData.payment)
								table.insert(lines, gradeLine)
							end
						end
						table.insert(lines, '\t\t},')
						table.insert(lines, '\t},')
					end
					table.insert(lines, '}')
					return table.concat(lines, '\n')
				end
				local modifiedData = convertToPlainText(validJobs)
				TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' removing job ' .. data.data.jobId)
				-- Too spammy
				-- TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Saving jobs.lua with new data: ' .. modifiedData)
				SaveResourceFile('qb-core', './shared/jobs.lua', modifiedData, -1)
				manuallySendPayload()
			end
		end
	end)
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_EDIT_JOB_CONFIG', function(data)
		if data ~= nil then
			local originalData = LoadResourceFile('qb-core', './shared/jobs.lua')
			local validJobs = {}
			local function filterJobs(jobs)
				local validJobs = {}
				for jobName, jobData in pairs(jobs) do
					validJobs[jobName] = jobData
				end
				return validJobs
			end
			local tempEnv = {}
			setmetatable(tempEnv, {__index = _G})
			local func, err = load(originalData, 'jobData', 't', tempEnv)
			if not func then
				print('Error loading data: ' .. err)
				return
			end
			func()
			local loadedJobs = tempEnv.QBShared and tempEnv.QBShared.Jobs
			if not loadedJobs or next(loadedJobs) == nil then
				print('Error: QBShared.Jobs table is missing or empty.')
				return
			end
			validJobs = filterJobs(loadedJobs)
			if not validJobs[data.data.id] then
				debugLog('Error: Job ' .. data.data.id .. ' does not exist.')
				return
			else
				local gradesTable = {}
				for gradeIndex, gradeData in pairs(data.data.grades) do
					if gradeData.isBoss then
						gradesTable[gradeIndex - 1] = {name = gradeData.name, payment = gradeData.payment, isboss = gradeData.isBoss}
					else
						gradesTable[gradeIndex - 1] = {name = gradeData.name, payment = gradeData.payment}
					end
				end
				validJobs[data.data.id] = {type = data.data.type, label = data.data.label, grades = gradesTable, defaultDuty = data.data.defaultDuty, offDutyPay = data.data.offDutyPay}
				local function convertToPlainText(jobTable)
					local lines = {'QBShared = QBShared or {}'}
					table.insert(lines, 'QBShared.ForceJobDefaultDutyAtLogin = true -- true: Force duty state to jobdefaultDuty | false: set duty state from database last saved')
					table.insert(lines, 'QBShared.Jobs = {')
					for jobName, jobData in pairs(jobTable) do
						local gangLine = '\t[\'' .. jobName .. '\'] = {'
						table.insert(lines, gangLine)
						local labelLine = '\t\tlabel = ' .. string.format('\'%s\',', jobData.label)
						table.insert(lines, labelLine)
						if jobData.type and jobData.type ~= nil then
							local typeLine = '\t\ttype = \'' .. jobData.type .. '\','
							table.insert(lines, typeLine)
						end
						if jobData.defaultDuty ~= nil then
							local defaultDutyLine = '\t\tdefaultDuty = ' .. tostring(jobData.defaultDuty) .. ','
							table.insert(lines, defaultDutyLine)
						end
						if jobData.offDutyPay ~= nil then
							local offDutyPayLine = '\t\toffDutyPay = ' .. tostring(jobData.offDutyPay) .. ','
							table.insert(lines, offDutyPayLine)
						end
						table.insert(lines, '\t\tgrades = {')
						for gradeIndex, gradeData in pairs(jobData.grades) do
							if gradeData.isboss then
								local gradeLine = string.format('\t\t\t[\'%s\'] = { name = \'%s\', payment = %s, isboss = %s },', gradeIndex, gradeData.name, gradeData.payment, gradeData.isboss)
								table.insert(lines, gradeLine)
							else
								local gradeLine = string.format('\t\t\t[\'%s\'] = { name = \'%s\', payment = %s },', gradeIndex, gradeData.name, gradeData.payment)
								table.insert(lines, gradeLine)
							end
						end
						table.insert(lines, '\t\t},')
						table.insert(lines, '\t},')
					end
					table.insert(lines, '}')
					return table.concat(lines, '\n')
				end
				local modifiedData = convertToPlainText(validJobs)
				TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' editing job ' .. data.data.id)
				-- Too spammy
				-- TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Saving jobs.lua with new data: ' .. modifiedData)
				SaveResourceFile('qb-core', './shared/jobs.lua', modifiedData, -1)
				manuallySendPayload()
			end
		end
	end)
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_ADD_JOB_CONFIG', function(data)
		if data ~= nil then
			local originalData = LoadResourceFile('qb-core', './shared/jobs.lua')
			local validJobs = {}
			local function filterJobs(jobs)
				local validJobs = {}
				for jobName, jobData in pairs(jobs) do
					validJobs[jobName] = jobData
				end
				return validJobs
			end
			local tempEnv = {}
			setmetatable(tempEnv, {__index = _G})
			local func, err = load(originalData, 'jobData', 't', tempEnv)
			if not func then
				print('Error loading data: ' .. err)
				return
			end
			func()
			local loadedJobs = tempEnv.QBShared and tempEnv.QBShared.Jobs
			if not loadedJobs or next(loadedJobs) == nil then
				print('Error: QBShared.Jobs table is missing or empty.')
				return
			end
			validJobs = filterJobs(loadedJobs)
			if validJobs[data.data.id] then
				debugLog('Error: Job ' .. data.data.id .. ' already exist.')
				return
			else
				local gradesTable = {}
				for gradeIndex, gradeData in pairs(data.data.grades) do
					if gradeData.isBoss then
						gradesTable[gradeIndex - 1] = {name = gradeData.name, payment = gradeData.payment, isboss = gradeData.isBoss}
					else
						gradesTable[gradeIndex - 1] = {name = gradeData.name, payment = gradeData.payment}
					end
				end
				validJobs[data.data.id] = {type = data.data.type, label = data.data.label, grades = gradesTable, defaultDuty = data.data.defaultDuty, offDutyPay = data.data.offDutyPay}
				exports['qb-core']:AddJob(data.data.id, {label = data.data.label, grades = gradesTable, defaultDuty = data.data.defaultDuty, offDutyPay = data.data.offDutyPay})
				local function convertToPlainText(jobTable)
					local lines = {'QBShared = QBShared or {}'}
					table.insert(lines, 'QBShared.ForceJobDefaultDutyAtLogin = true -- true: Force duty state to jobdefaultDuty | false: set duty state from database last saved')
					table.insert(lines, 'QBShared.Jobs = {')
					for jobName, jobData in pairs(jobTable) do
						local gangLine = '\t[\'' .. jobName .. '\'] = {'
						table.insert(lines, gangLine)
						local labelLine = '\t\tlabel = ' .. string.format('\'%s\',', jobData.label)
						table.insert(lines, labelLine)
						if jobData.type and jobData.type ~= nil then
							local typeLine = '\t\ttype = \'' .. jobData.type .. '\','
							table.insert(lines, typeLine)
						end
						if jobData.defaultDuty ~= nil then
							local defaultDutyLine = '\t\tdefaultDuty = ' .. tostring(jobData.defaultDuty) .. ','
							table.insert(lines, defaultDutyLine)
						end
						if jobData.offDutyPay ~= nil then
							local offDutyPayLine = '\t\toffDutyPay = ' .. tostring(jobData.offDutyPay) .. ','
							table.insert(lines, offDutyPayLine)
						end
						table.insert(lines, '\t\tgrades = {')
						for gradeIndex, gradeData in pairs(jobData.grades) do
							if gradeData.isboss then
								local gradeLine = string.format('\t\t\t[\'%s\'] = { name = \'%s\', payment = %s, isboss = %s },', gradeIndex, gradeData.name, gradeData.payment, gradeData.isboss)
								table.insert(lines, gradeLine)
							else
								local gradeLine = string.format('\t\t\t[\'%s\'] = { name = \'%s\', payment = %s },', gradeIndex, gradeData.name, gradeData.payment)
								table.insert(lines, gradeLine)
							end
						end
						table.insert(lines, '\t\t},')
						table.insert(lines, '\t},')
					end
					table.insert(lines, '}')
					return table.concat(lines, '\n')
				end
				local modifiedData = convertToPlainText(validJobs)
				TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Received push event: ' .. data.type .. ' adding job ' .. data.data.id)
				-- Too spammy
				-- TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Saving jobs.lua with new data: ' .. modifiedData)
				SaveResourceFile('qb-core', './shared/jobs.lua', modifiedData, -1)
				manuallySendPayload()
			end
		end
	end)
end)

CreateThread(function()
	local first = true
	while true do
		while first do
			Wait(5000)
			first = false
		end
		-- Getting System Info
		local systemInfo = exports['sonorancms']:getSystemInfo()
		-- Getting all active players on the server
		local activePlayers = {}
		for i = 0, GetNumPlayerIndices() - 1 do
			local player = GetPlayerFromIndex(i)
			local playerInfo = {name = GetPlayerName(player), ping = GetPlayerPing(player), source = player, identifiers = GetPlayerIdentifiers(player)}
			table.insert(activePlayers, playerInfo)
		end
		if Config.framework == 'qb-core' then
			-- Getting QBCore object
			QBCore = exports['qb-core']:GetCoreObject()
			-- Query the DB for QB Players rather than using the function because the function only returns active ones
			local qbCharacters = {}
			MySQL.query('SELECT * FROM players', function(row)
				for _, v in ipairs(row) do
					local qbCharInfo = QBCore.Functions.GetPlayerByCitizenId(v.citizenid)
					local playerInventory = {}
					v.charinfo = json.decode(v.charinfo)
					v.job = json.decode(v.job)
					v.money = json.decode(v.money)
					v.inventory = json.decode(v.inventory)
					for _, item in pairs(v.inventory) do
						table.insert(playerInventory,
						             {slot = item.slot, name = item.name, amount = item.amount, label = item.label or 'Unknown', description = item.description or '', weight = item.weight or 0, type = item.type,
							unique = item.unique or false, image = item.image or '', info = item.info or {}, shouldClose = item.shouldClose or false,
							combinable = v.combinable and {accept = item.combinable.accept, reward = item.combinable.reward, anim = item.combinable.anim} or nil})
					end
					local charInfo = {firstname = v.charinfo.firstname, lastname = v.charinfo.lastname, dob = v.charinfo.birthdate, offline = true, name = v.charinfo.firstname .. ' ' .. v.charinfo.lastname,
						id = v.charinfo.id, citizenid = v.citizenid, license = v.license, jobInfo = {name = v.job.name, grade = v.job.grade.name, label = v.job.label, onDuty = v.job.onduty, type = v.job.type},
						money = {bank = v.money.bank, cash = v.money.cash, crypto = v.money.crypto}, gender = v.charinfo.gender, nationality = v.charinfo.nationality, phoneNumber = v.charinfo.phone,
						inventory = playerInventory}
					if qbCharInfo then
						charInfo.offline = false
						charInfo.source = qbCharInfo.PlayerData.source
					end
					table.insert(qbCharacters, charInfo)
				end
			end)
			-- Request the game pool of vheicles to send all active vehicles in game
			for i = 0, GetNumPlayerIndices() - 1 do
				local p = GetPlayerFromIndex(i)
				if p ~= nil then
					TriggerClientEvent('SonoranCMS::core::RequestGamePool', p)
				end
			end
			-- Request all the resources and their valid paths relative to the resources folder
			local resourceList = {}
			for i = 0, GetNumResources(), 1 do
				local resource_name = GetResourceByFindIndex(i)
				if resource_name then
					local path = GetResourcePath(resource_name):match('.*/resources/(.*)')
					table.insert(resourceList, {name = resource_name, state = GetResourceState(resource_name), path = path})
				end
			end
			-- Request all the saved player vehicles from the database
			local characterVehicles = {}
			MySQL.query('SELECT * FROM player_vehicles', function(row)
				for _, v in ipairs(row) do
					vehicle = {}
					vehicle.id = v.id
					vehicle.citizenId = v.citizenid
					vehicle.garage = v.garage
					vehicle.model = v.vehicle
					vehicle.plate = v.plate
					vehicle.state = v.state
					vehicle.fuel = v.fuel
					vehicle.engine = v.engine
					vehicle.body = v.body
					vehicle.mileage = v.drivingdistance
					vehicle.balance = v.balance
					vehicle.paymentAmount = v.paymentamount
					vehicle.paymentsLeft = v.paymentsleft
					vehicle.financeTime = v.financetime
					vehicle.depotPrice = v.depotprice
					vehicle.displayName = v.vehicle
					table.insert(characterVehicles, vehicle)
				end
			end)
			-- Request the active runtime jobs and their grades
			local jobTable = {}
			for i, v in pairs(QBCore.Shared.Jobs) do
				local gradesTable = {}
				for h, g in pairs(v.grades) do
					gradesTable[h] = {name = g.name, payment = g.payment, isBoss = g.isboss}
				end
				table.insert(jobTable, {id = i, label = v.label, defaultDuty = v.defaultDuty, offDutyPay = v.offDutyPay, grades = gradesTable})
			end
			-- Request the active runtime gangs and their grades
			local gangTable = {}
			for i, v in pairs(QBCore.Shared.Gangs) do
				local gradesTable = {}
				for h, g in pairs(v.grades) do
					gradesTable[h] = {name = g.name, isBoss = g.isboss}
				end
				table.insert(gangTable, {id = i, label = v.label, grades = gradesTable})
			end
			-- Request the hardcoded jobs from the qb-core shared file (shared/jobs.lua)
			local originalData = LoadResourceFile('qb-core', './shared/jobs.lua')
			local validJobs = {}
			local function filterJobs(jobs)
				local validJobs = {}
				for jobName, jobData in pairs(jobs) do
					for h, j in pairs(jobData.grades) do
						if j.isboss then
							jobData.grades[h].isBoss = j.isboss
						end
						j.isboss = nil
					end
					table.insert(validJobs, {id = jobName, label = jobData.label, grades = jobData.grades, defaultDuty = jobData.defaultDuty, offDutyPay = jobData.offDutyPay})
				end
				return validJobs
			end
			local tempEnv = {}
			setmetatable(tempEnv, {__index = _G})
			local func, err = load(originalData, 'jobData', 't', tempEnv)
			if not func then
				print('Error loading data: ' .. err)
				return
			end
			func()
			local loadedJobs = tempEnv.QBShared and tempEnv.QBShared.Jobs
			if not loadedJobs or next(loadedJobs) == nil then
				print('Error: QBShared.Jobs table is missing or empty.')
				return
			end
			validJobs = filterJobs(loadedJobs)
			-- Request the hardcoded gangs from the qb-core shared file (shared/gangs.lua)
			local originalData = LoadResourceFile('qb-core', './shared/gangs.lua')
			local validGangs = {}
			local function filterGangs(gangs)
				local validGangs = {}
				for gangName, gangData in pairs(gangs) do
					for h, j in pairs(gangData.grades) do
						if j.isboss then
							gangData.grades[h].isBoss = j.isboss
						end
						j.isboss = nil
					end
					table.insert(validGangs, {id = gangName, label = gangData.label, grades = gangData.grades})
				end
				return validGangs
			end
			local tempEnv = {}
			setmetatable(tempEnv, {__index = _G})
			local func, err = load(originalData, 'gangData', 't', tempEnv)
			if not func then
				print('Error loading data: ' .. err)
				return
			end
			func()
			local loadedGangs = tempEnv.QBShared and tempEnv.QBShared.Gangs
			if not loadedGangs or next(loadedGangs) == nil then
				print('Error: QBShared.Gangs table is missing or empty.')
				return
			end
			validGangs = filterGangs(loadedGangs)
			-- Request the garage data from qb-garages
			local QBGarages = exports['qb-garages']:getAllGarages()
			-- Request all items from QBShared
			local QBItems = QBCore.Shared.Items
			local formattedQBItems = {}
			for _, v in pairs(QBItems) do
				local item = {name = v.name, label = v.label or 'Unknown', weight = v.weight or 0, type = v.type, image = v.image or '', description = v.description or '', unique = v.unique or false,
					useable = v.useable or false, ammoType = v.ammoType or nil, shouldClose = v.shouldClose or false,
					combinable = v.combinable and {accept = v.combinable.accept, reward = v.combinable.reward, anim = v.combinable.anim} or nil}
				table.insert(formattedQBItems, item)
			end
			Wait(5000)
			apiResponse = {uptime = GetGameTimer(), system = {cpuRaw = systemInfo.cpuRaw, cpuUsage = systemInfo.cpuUsage, memoryRaw = systemInfo.ramRaw, memoryUsage = systemInfo.ramUsage},
				players = activePlayers, characters = qbCharacters, gameVehicles = vehicleGamePool, logs = loggerBuffer, resources = resourceList, characterVehicles = characterVehicles, jobs = jobTable,
				gangs = gangTable, fileJobs = validJobs, fileGangs = validGangs, items = formattedQBItems, garages = QBGarages}
			-- Disabled for time being, too spammy
			-- TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Sending API update for GAMESTATE, payload: ' .. json.encode(apiResponse))
			SaveResourceFile(GetCurrentResourceName(), './apiPayload.json', json.encode(apiResponse), -1)
			performApiRequest(apiResponse, 'GAMESTATE', function(result, ok)
				Utilities.Logging.logDebug('API Response: ' .. result .. ' ' .. tostring(ok))
				if not ok then
					logError('API_ERROR')
					Config.critError = true
					return
				end
			end)
		end
		Wait(60000)
	end
end)

--- Manually send the GAMESTATE payload
function manuallySendPayload()
	-- Getting System Info
	local systemInfo = exports['sonorancms']:getSystemInfo()
	-- Getting all active players on the server
	local activePlayers = {}
	for i = 0, GetNumPlayerIndices() - 1 do
		local player = GetPlayerFromIndex(i)
		local playerInfo = {name = GetPlayerName(player), ping = GetPlayerPing(player), source = player, identifiers = GetPlayerIdentifiers(player)}
		table.insert(activePlayers, playerInfo)
	end
	if Config.framework == 'qb-core' then
		-- Getting QBCore object
		QBCore = exports['qb-core']:GetCoreObject()
		-- Query the DB for QB Players rather than using the function because the function only returns active ones
		local qbCharacters = {}
		MySQL.query('SELECT * FROM players', function(row)
			for _, v in ipairs(row) do
				local qbCharInfo = QBCore.Functions.GetPlayerByCitizenId(v.citizenid)
				local playerInventory = {}
				v.charinfo = json.decode(v.charinfo)
				v.job = json.decode(v.job)
				v.money = json.decode(v.money)
				v.inventory = json.decode(v.inventory)
				for _, item in pairs(v.inventory) do
					table.insert(playerInventory,
					             {slot = item.slot, name = item.name, amount = item.amount, label = item.label or 'Unknown', description = item.description or '', weight = item.weight or 0, type = item.type,
						unique = item.unique or false, image = item.image or '', info = item.info or {}, shouldClose = item.shouldClose or false,
						combinable = v.combinable and {accept = item.combinable.accept, reward = item.combinable.reward, anim = item.combinable.anim} or nil})
				end
				local charInfo = {firstname = v.charinfo.firstname, lastname = v.charinfo.lastname, dob = v.charinfo.birthdate, offline = true, name = v.charinfo.firstname .. ' ' .. v.charinfo.lastname,
					id = v.charinfo.id, citizenid = v.citizenid, license = v.license, jobInfo = {name = v.job.name, grade = v.job.grade.name, label = v.job.label, onDuty = v.job.onduty, type = v.job.type},
					money = {bank = v.money.bank, cash = v.money.cash, crypto = v.money.crypto}, gender = v.charinfo.gender, nationality = v.charinfo.nationality, phoneNumber = v.charinfo.phone,
					inventory = playerInventory}
				if qbCharInfo then
					charInfo.offline = false
					charInfo.source = qbCharInfo.PlayerData.source
				end
				table.insert(qbCharacters, charInfo)
			end
		end)
		-- Request the game pool of vheicles to send all active vehicles in game
		for i = 0, GetNumPlayerIndices() - 1 do
			local p = GetPlayerFromIndex(i)
			if p ~= nil then
				TriggerClientEvent('SonoranCMS::core::RequestGamePool', p)
			end
		end
		-- Request all the resources and their valid paths relative to the resources folder
		local resourceList = {}
		for i = 0, GetNumResources(), 1 do
			local resource_name = GetResourceByFindIndex(i)
			if resource_name then
				local path = GetResourcePath(resource_name):match('.*/resources/(.*)')
				table.insert(resourceList, {name = resource_name, state = GetResourceState(resource_name), path = path})
			end
		end
		-- Request all the saved player vehicles from the database
		local characterVehicles = {}
		MySQL.query('SELECT * FROM player_vehicles', function(row)
			for _, v in ipairs(row) do
				vehicle = {}
				vehicle.id = v.id
				vehicle.citizenId = v.citizenid
				vehicle.garage = v.garage
				vehicle.model = v.vehicle
				vehicle.plate = v.plate
				vehicle.state = v.state
				vehicle.fuel = v.fuel
				vehicle.engine = v.engine
				vehicle.body = v.body
				vehicle.mileage = v.drivingdistance
				vehicle.balance = v.balance
				vehicle.paymentAmount = v.paymentamount
				vehicle.paymentsLeft = v.paymentsleft
				vehicle.financeTime = v.financetime
				vehicle.depotPrice = v.depotprice
				vehicle.displayName = v.vehicle
				table.insert(characterVehicles, vehicle)
			end
		end)
		-- Request the active runtime jobs and their grades
		local jobTable = {}
		for i, v in pairs(QBCore.Shared.Jobs) do
			local gradesTable = {}
			for h, g in pairs(v.grades) do
				gradesTable[h] = {name = g.name, payment = g.payment, isBoss = g.isboss}
			end
			table.insert(jobTable, {id = i, label = v.label, defaultDuty = v.defaultDuty, offDutyPay = v.offDutyPay, grades = gradesTable})
		end
		-- Request the active runtime gangs and their grades
		local gangTable = {}
		for i, v in pairs(QBCore.Shared.Gangs) do
			local gradesTable = {}
			for h, g in pairs(v.grades) do
				gradesTable[h] = {name = g.name, isBoss = g.isboss}
			end
			table.insert(gangTable, {id = i, label = v.label, grades = gradesTable})
		end
		-- Request the hardcoded jobs from the qb-core shared file (shared/jobs.lua)
		local originalData = LoadResourceFile('qb-core', './shared/jobs.lua')
		local validJobs = {}
		local function filterJobs(jobs)
			local validJobs = {}
			for jobName, jobData in pairs(jobs) do
				for h, j in pairs(jobData.grades) do
					if j.isboss then
						jobData.grades[h].isBoss = j.isboss
					end
					j.isboss = nil
				end
				table.insert(validJobs, {id = jobName, label = jobData.label, grades = jobData.grades, defaultDuty = jobData.defaultDuty, offDutyPay = jobData.offDutyPay})
			end
			return validJobs
		end
		local tempEnv = {}
		setmetatable(tempEnv, {__index = _G})
		local func, err = load(originalData, 'jobData', 't', tempEnv)
		if not func then
			print('Error loading data: ' .. err)
			return
		end
		func()
		local loadedJobs = tempEnv.QBShared and tempEnv.QBShared.Jobs
		if not loadedJobs or next(loadedJobs) == nil then
			print('Error: QBShared.Jobs table is missing or empty.')
			return
		end
		validJobs = filterJobs(loadedJobs)
		-- Request the hardcoded gangs from the qb-core shared file (shared/gangs.lua)
		local originalData = LoadResourceFile('qb-core', './shared/gangs.lua')
		local validGangs = {}
		local function filterGangs(gangs)
			local validGangs = {}
			for gangName, gangData in pairs(gangs) do
				for h, j in pairs(gangData.grades) do
					if j.isboss then
						gangData.grades[h].isBoss = j.isboss
					end
					j.isboss = nil
				end
				table.insert(validGangs, {id = gangName, label = gangData.label, grades = gangData.grades})
			end
			return validGangs
		end
		local tempEnv = {}
		setmetatable(tempEnv, {__index = _G})
		local func, err = load(originalData, 'gangData', 't', tempEnv)
		if not func then
			print('Error loading data: ' .. err)
			return
		end
		func()
		local loadedGangs = tempEnv.QBShared and tempEnv.QBShared.Gangs
		if not loadedGangs or next(loadedGangs) == nil then
			print('Error: QBShared.Gangs table is missing or empty.')
			return
		end
		validGangs = filterGangs(loadedGangs)
		-- Request the garage data from qb-garages
		local QBGarages = exports['qb-garages']:getAllGarages()
		-- Request all items from QBShared
		local QBItems = QBCore.Shared.Items
		local formattedQBItems = {}
		for _, v in pairs(QBItems) do
			local item = {name = v.name, label = v.label or 'Unknown', weight = v.weight or 0, type = v.type, image = v.image or '', description = v.description or '', unique = v.unique or false,
				useable = v.useable or false, ammoType = v.ammoType or nil, shouldClose = v.shouldClose or false,
				combinable = v.combinable and {accept = v.combinable.accept, reward = v.combinable.reward, anim = v.combinable.anim} or nil}
			table.insert(formattedQBItems, item)
		end
		Wait(5000)
		apiResponse = {uptime = GetGameTimer(), system = {cpuRaw = systemInfo.cpuRaw, cpuUsage = systemInfo.cpuUsage, memoryRaw = systemInfo.ramRaw, memoryUsage = systemInfo.ramUsage},
			players = activePlayers, characters = qbCharacters, gameVehicles = vehicleGamePool, logs = loggerBuffer, resources = resourceList, characterVehicles = characterVehicles, jobs = jobTable,
			gangs = gangTable, fileJobs = validJobs, fileGangs = validGangs, items = formattedQBItems, garages = QBGarages}
		-- Disabled for time being, too spammy
		-- TriggerEvent('SonoranCMS::core:writeLog', 'debug', 'Sending API update for GAMESTATE, payload: ' .. json.encode(apiResponse))
		SaveResourceFile(GetCurrentResourceName(), './apiPayload.json', json.encode(apiResponse), -1)
		performApiRequest(apiResponse, 'GAMESTATE', function(result, ok)
			Utilities.Logging.logDebug('API Response: ' .. result .. ' ' .. tostring(ok))
			if not ok then
				logError('API_ERROR')
				Config.critError = true
				return
			end
		end)
	end
	Wait(60000)
end

RegisterConsoleListener(function(channel, message)
	serverLogger(0, 'CONSOLE_LOG', {channel = channel, message = message})
end)

RegisterNetEvent('SonoranCMS::core::ReturnGamePool', function(gamePool)
	vehicleGamePool = gamePool
end)

RegisterNetEvent('SonoranCMS::core::DeleteVehicleCB', function(vehDriver, passengers)
	TriggerClientEvent('chat:addMessage', vehDriver, {color = {255, 0, 0}, multiline = true,
		args = {'[SonoranCMS Management Panel] ', 'Your vehicle has been despawned! Please contact a staff member if you believe this is an error.'}})
	for _, v in ipairs(passengers) do
		TriggerClientEvent('chat:addMessage', v, {color = {255, 0, 0}, multiline = true,
			args = {'[SonoranCMS Management Panel] ', 'Your vehicle has been despawned! Please contact a staff member if you believe this is an error.'}})
	end
end)

RegisterNetEvent('SonoranCMS::core::RepairVehicleCB', function(vehDriver, passengers)
	TriggerClientEvent('chat:addMessage', vehDriver, {color = {255, 0, 0}, multiline = true, args = {'[SonoranCMS Management Panel] ', 'Your vehicle has been repaired!'}})
	for _, v in ipairs(passengers) do
		TriggerClientEvent('chat:addMessage', v, {color = {255, 0, 0}, multiline = true, args = {'[SonoranCMS Management Panel] ', 'Your vehicle has been repaired!'}})
	end
end)

RegisterNetEvent('SonoranCMS::ServerLogger::DeathEvent', function(killer, cause)
	serverLogger(source, 'deathEvent', {killer = killer, cause = cause})
end)

RegisterNetEvent('SonoranCMS::ServerLogger::PlayerShot', function(weapon)
	serverLogger(source, 'playerShot', {weapon = weapon})
end)

AddEventHandler('explosionEvent', function(source, ev)
	if (isInvalid(ev.damageScale, 0) or isInvalid(ev.cameraShake, 0) or isInvalid(ev.isInvisible, true) or isInvalid(ev.isAudible, false)) then
		return
	end
	if ev.explosionType < -1 or ev.explosionType > 77 then
		ev.explosionType = 'UNKNOWN'
	else
		ev.explosionType = explosionTypes[ev.explosionType + 1]
	end
	serverLogger(tonumber(source), 'explosionEvent', ev)
end)

RegisterNetEvent('chatMessage', function(src, author, text)
	serverLogger(src, 'ChatMessage', {author = author, text = text})
end)

AddEventHandler('onResourceStarting', function(resource)
	serverLogger(0, 'onResourceStarting', resource)
end)

AddEventHandler('onResourceStart', function(resource)
	serverLogger(0, 'onResourceStart', resource)
end)

AddEventHandler('onServerResourceStart', function(resource)
	serverLogger(0, 'onServerResourceStart', resource)
end)

AddEventHandler('onResourceListRefresh', function(resource)
	serverLogger(0, 'onResourceListRefresh', resource)
end)

AddEventHandler('onResourceStop', function(resource)
	serverLogger(0, 'onResourceStop', resource)
end)

AddEventHandler('onServerResourceStop', function(resource)
	serverLogger(0, 'onServerResourceStop', resource)
end)

AddEventHandler('playerConnecting', function(name, _, _)
	serverLogger(0, 'playerConnecting', name)
end)

AddEventHandler('playerDropped', function(name, _, _)
	serverLogger('playerDropped', name)
end)

AddEventHandler('QBCore:CallCommand', function(command, args)
	serverLogger(source, 'QBCore::CallCommand', {command = command, args = args})
end)

AddEventHandler('QBCore:ToggleDuty', function()
	local Player = QBCore.Functions.GetPlayer(source)
	if Player.PlayerData.job.onduty then
		serverLogger(source, 'QBCore::ToggleDuty', {job = Player.PlayerData.job.name, duty = false})
	else
		serverLogger(source, 'QBCore::ToggleDuty', {job = Player.PlayerData.job.name, duty = true})
	end
end)

-- Disabled for time being, too spammy
-- AddEventHandler('QBCore:Server:SetMetaData', function(meta, data)
-- 	serverLogger(source, 'QBCore:Server:SetMetaData', {meta = meta, data = data})
-- end)

RegisterNetEvent('SonoranCMS::ServerLogger::QBSpawnVehicle', function(veh)
	serverLogger(source, 'QBCore:Command:SpawnVehicle', veh)
end)

RegisterNetEvent('SonoranCMS::ServerLogger::QBDeleteVehicle', function()
	serverLogger(source, 'QBCore:Command:DeleteVehicle', nil)
end)

RegisterNetEvent('SonoranCMS::ServerLogger::QBClientUsedItem', function(item)
	serverLogger(source, 'QBCore:Command:ClientUsedItem', item)
end)
