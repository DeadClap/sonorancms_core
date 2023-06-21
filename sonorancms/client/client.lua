RegisterNetEvent('SonoranCMS::core::RequestGamePool', function()
	local returnVehicleData = {}
	for _, v in pairs(GetGamePool('CVehicle')) do
		local ped = GetPedInVehicleSeat(v, -1)
		if (DoesEntityExist(ped)) and (IsPedAPlayer(ped)) then
			local vehicleData = {}
			vehicleData.vehicleHandle = v
			vehicleData.model = GetEntityModel(v)
			vehicleData.plate = GetVehicleNumberPlateText(v)
			vehicleData.health = GetVehicleEngineHealth(v)
			vehicleData.fuel = GetVehicleFuelLevel(v)
			vehicleData.bodyHealth = GetVehicleBodyHealth(v)
			vehicleData.displayName = GetDisplayNameFromVehicleModel(GetEntityModel(v))
			vehicleData.driver = GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped))
			vehicleData.passengers = {}
			for i = -1, GetVehicleMaxNumberOfPassengers(GetVehiclePedIsIn(ped)) + 1, 1 do
				local pedPass = GetPedInVehicleSeat(GetVehiclePedIsIn(ped), i)
				if (DoesEntityExist(pedPass)) then
					if (IsPedAPlayer(pedPass) and ped ~= pedPass) then
						local pedServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(pedPass))
						table.insert(vehicleData.passengers, {seat = i, passengerId = pedServerId})
					end
				end
			end
			table.insert(returnVehicleData, vehicleData)
		end
	end
	TriggerServerEvent('SonoranCMS::core::ReturnGamePool', returnVehicleData)
end)

RegisterNetEvent('SonoranCMS::core::DeleteVehicle', function(vehHandle)
	if DoesEntityExist(vehHandle) then
		local vehDriver = GetPedInVehicleSeat(vehHandle, -1)
		if (DoesEntityExist(vehDriver)) and (IsPedAPlayer(vehDriver)) then
			local passengers = {}
			for i = -1, GetVehicleMaxNumberOfPassengers(GetVehiclePedIsIn(ped)) + 1, 1 do
				local pedPass = GetPedInVehicleSeat(GetVehiclePedIsIn(ped), i)
				if (DoesEntityExist(pedPass)) then
					if (IsPedAPlayer(pedPass) and ped ~= pedPass) then
						local pedServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(pedPass))
						table.insert(passengers, pedServerId)
					end
				end
			end
			vehDriver = GetPlayerServerId(NetworkGetPlayerIndexFromPed(vehDriver))
			TriggerServerEvent('SonoranCMS::core::DeleteVehicleCB', vehDriver, passengers)
			SetEntityAsMissionEntity(vehHandle, true, true)
			DeleteEntity(vehHandle)
		end
	end
end)
