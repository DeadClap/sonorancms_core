CreateThread(function()
	TriggerEvent('sonorancms::RegisterPushEvent', 'CMD_KICK_PLAYER', function(data)
		if data ~= nil then
			local targetPlayer = nil
			for i = 0, GetNumPlayerIndices() - 1 do
				local p = GetPlayerFromIndex(i)
				if p == data.data.playerSource then
					targetPlayer = p
				end
			end
			if targetPlayer ~= nil then
				local reason = 'Kicked By SonoranCMS Management Panel: ' .. data.data.reason
				local targetPlayerName = GetPlayerName(targetPlayer)
				print(targetPlayerName)
				DropPlayer(targetPlayer, reason)
				infoLog('Received push event: ' .. data.type .. ' dropping player ' .. targetPlayerName .. ' for reason: ' .. reason)
			else
				infoLog('Received push event: ' .. data.type .. ' but player with source ' .. data.data.playerSource .. ' was not found')
			end
		end
	end)
end)

CreateThread(function()
	while true do
		local systemInfo = exports['sonorancms']:getSystemInfo()
		local activePlayers = {}
		for i = 0, GetNumPlayerIndices() - 1 do
			local player = GetPlayerFromIndex(i)
			local playerInfo = {name = GetPlayerName(player), ping = GetPlayerPing(player), source = player, identifiers = GetPlayerIdentifiers(player)}
			table.insert(activePlayers, playerInfo)
		end
        if Config.framework == 'qb-core' then
            QBCore = exports['qb-core']:GetCoreObject()
            qbCharacters = QBCore.Functions.GetQBPlayers()
        end
		local apiResponse = {{uptime = GetGameTimer(), system = {cpu = systemInfo.cpu, memory = systemInfo.memory}, players = activePlayers, characters = qbCharacters }}
        print(json.encode(apiResponse))
		-- performApiRequest(apiResponse, 'GAMESTATE', function(result, ok)
		-- 	if not ok then
		-- 		logError('API_ERROR')
		-- 		Config.critError = true
		-- 		return
		-- 	end
		-- end)
		Wait(60000)
	end
end)
