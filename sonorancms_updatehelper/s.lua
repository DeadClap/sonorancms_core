ManagedResources = {'sonorancms'}

CreateThread(function()
	file = io.open(GetResourcePath(GetCurrentResourceName()) .. '/run.lock', 'a+')
	io.input(file)
	line = io.read()
	file:close()
	if line == 'core' or line == 'plugin' then
		ExecuteCommand('refresh')
		Wait(1000)
		if line == 'core' then
			for k, v in pairs(ManagedResources) do
				if GetResourceState(v) ~= 'started' then
					print(('Not restarting resource %s as it is not started. This may be fine. State: %s'):format(v, GetResourceState(v)))
				else
					ExecuteCommand('restart ' .. v)
					Wait(1000)
				end
			end
		elseif line == 'plugin' then
			print('Restarting sonorancms resource for plugin updates...')
			if GetResourceState('sonorancms') ~= 'started' then
				print(('Not restarting resource %s as it is not in the started state to avoid server crashing. State: %s'):format('sonorancms', GetResourceState('sonorancms')))
				print('If you are seeing this message, you have started sonorancms_updatehelper in your configuration which is incorrect. Please do not start sonorancms_updatehelper manually.')
				return
			else
				ExecuteCommand('restart sonorancms')
			end
		end
	else
		os.remove(GetResourcePath(GetCurrentResourceName()) .. '/run.lock')
		print('sonorancms_updatehelper is for internal use and should not be started as a resource.')
	end
	os.remove(GetResourcePath(GetCurrentResourceName()) .. '/run.lock')
end)
