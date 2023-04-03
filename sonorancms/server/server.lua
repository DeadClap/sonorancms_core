local plugin_handlers = {}
local MessageBuffer = {}
local DebugBuffer = {}
local ErrorBuffer = {}

SetHttpHandler(function(req, res)
	local path = req.path
	local method = req.method
	if method == 'POST' and path == '/events' then
		req.setDataHandler(function(data)
			if not data then
				res.send(json.encode({['error'] = 'bad request'}))
				return
			end
			local body = json.decode(data)
			if not body then
				res.send(json.encode({['error'] = 'bad request'}))
				return
			end
			if body.key and body.key:upper() == Config.APIKey:upper() then
				if plugin_handlers[body.type] ~= nil then
					TriggerEvent(plugin_handlers[body.type], body)
					res.send('ok')
					return
				else
					res.send('Event not registered')
				end
			else
				res.send('Bad API Key')
				return
			end
		end)
	else
		res.send('Bad endpoint')
	end
end)

RegisterNetEvent('SonoranCMS::pushevents::UnitLogin', function(accID)
	local payload = {}
	payload['id'] = Config.CommID
	payload['key'] = Config.APIKey
	payload['type'] = 'CLOCK_IN_OUT'
	payload['data'] = {{['accID'] = accID, ['forceClockIn'] = true, ['server'] = Config.serverId}}
	PerformHttpRequest(Config.apiUrl .. '/general/clock_in_out', function(code, result, _)
		if code == 201 and Config.debug_mode then
			print('logging in unit. Results: ' .. result)
		end
	end, 'POST', json.encode(payload), {['Content-Type'] = 'application/json'})
end)

RegisterNetEvent('SonoranCMS::pushevents::UnitLogout', function(accID)
	local payload = {}
	payload['id'] = Config.CommID
	payload['key'] = Config.APIKey
	payload['type'] = 'CLOCK_IN_OUT'
	payload['data'] = {{['accID'] = accID, ['server'] = Config.serverId}}
	PerformHttpRequest(Config.apiUrl .. '/general/clock_in_out', function(code, result, _)
		if code == 201 and Config.debug_mode then
			print('logging out unit. Results: ' .. result)
		end
	end, 'POST', json.encode(payload), {['Content-Type'] = 'application/json'})
end)

RegisterNetEvent('sonorancms::RegisterPushEvent', function(type, event)
	plugin_handlers[type] = event
end)

AddEventHandler('onResourceStart', function(resource)
	if resource == GetCurrentResourceName() then
		Citizen.Wait(100)
		SetConvar('SONORAN_CMS_API_KEY', Config.APIKey)
		SetConvar('SONORAN_CMS_COMMUNITY_ID', Config.CommID)
	end
end)

function getServerVersion()
	local s = GetConvar('version', '')
	local v = s:find('v1.0.0.')
	local i = string.gsub(s:sub(v), 'v1.0.0.', ''):sub(1, 4)
	return i
end

CreateThread(function()
	print('Starting SonoranCMS from ' .. GetResourcePath('sonorancms'))
    exports["sonorancms"]:initializeCMS(Config.CommID, Config.APIKey, Config.serverId, Config.apiUrl, Config.debug_mode)
    performApiRequest({}, "GET_SUB_VERSION", function(result, ok)
        if not ok then
            logError("API_ERROR")
            Config.critError = true
            return
        end
        Config.apiVersion = tonumber(string.sub(result, 1, 1))
        if Config.apiVersion < 2 then
            logError("API_PAID_ONLY")
            Config.critError = true
        end
        debugLog(("Set version %s from response %s"):format(Config.apiVersion, result))
        infoLog(("Loaded community ID %s with API URL: %s"):format(Config.CommID, Config.apiUrl))
    end)
	local versionfile = json.decode(LoadResourceFile(GetCurrentResourceName(), '/version.json'))
	local fxversion = versionfile.testedFxServerVersion
	local currentFxVersion = getServerVersion()
	if currentFxVersion ~= nil and fxversion ~= nil then
		if tonumber(currentFxVersion) < tonumber(fxversion) then
			warnLog(('SonoranCMS has been tested with FXServer version %s, but you\'re running %s. Please update ASAP.'):format(fxversion, currentFxVersion))
		end
	end
	if GetResourceState('sonorancms_updatehelper') == 'started' then
		ExecuteCommand('stop sonorancms_updatehelper')
	end
	TriggerEvent(GetCurrentResourceName() .. '::StartUpdateLoop')
	Wait(100000)
end)

--[[
	Sonoran CMS Core Logging Functions
]]

local function sendConsole(level, color, message)
    local debugging = true
    if Config ~= nil then
        debugging = (Config.debugMode == true and Config.debugMode ~= "false")
    end
    local time = os and os.date("%X") or LocalTime()
    local info = debug.getinfo(3, 'S')
    local source = "."
    if info.source:find("@@sonorancms") then
        source = info.source:gsub("@@sonorancms/","")..":"..info.linedefined
    end
    local msg = ("[%s][%s:%s%s^7]%s %s^0"):format(time, debugging and source or "SonoranCMS", color, level, color, message)
    if (debugging and level == "DEBUG") or (not debugging and level ~= "DEBUG") then
        print(msg)
    end
    if (level == "ERROR" or level == "WARNING") and IsDuplicityVersion() then
        table.insert(ErrorBuffer, 1, msg)
    end
    if level == "DEBUG" and IsDuplicityVersion() then
        if #DebugBuffer > 50 then
            table.remove(DebugBuffer)
        end
        table.insert(DebugBuffer, 1, msg)
    else
        if not IsDuplicityVersion() then
            if #MessageBuffer > 10 then
                table.remove(MessageBuffer)
            end
            table.insert(MessageBuffer, 1, msg)
        end
    end
end

AddEventHandler("SonoranCMS::core:writeLog", function(level, message)
    if level == "debug" then
        debugLog(message)
    elseif level == "info" then
        infoLog(message)
    elseif level == "error" then
        errorLog(message)
    else
        debugLog(message)
    end
end)

function getDebugBuffer()
    return DebugBuffer
end

function getErrorBuffer()
    return ErrorBuffer
end


function debugLog(message)
    sendConsole("DEBUG", "^7", message)
end

function logError(err, msg)
    local o = ""
    if msg == nil then
        o = ("ERR %s: %s - See https://sonoran.software/errorcodes for more information."):format(err, ErrorCodes[err])
    else
        o = ("ERR %s: %s - See https://sonoran.software/errorcodes for more information."):format(err, msg)
    end
    sendConsole("ERROR", "^1", o)
end

function errorLog(message)
    sendConsole("ERROR", "^1", message)
end

function warnLog(message)
    sendConsole("WARNING", "^3", message)
end

function infoLog(message)
    sendConsole("INFO", "^5", message)
end

function PerformHttpRequestS(url, cb, method, data, headers)
    if not data then
        data = ""
    end
    if not headers then
        headers = {["X-User-Agent"] = "SonoranCAD"}
    end
    exports["sonorancms"]:HandleHttpRequest(url, cb, method, data, headers)
end

exports("getCmsVersion", function()
    return Config.apiVersion
end)


--[[
	Sonoran CMS API Wrapper
]]

ApiEndpoints = {
    ["GET_SUB_VERSION"] = "general",
    ["CHECK_COM_APIID"] = "general",
    ["GET_COM_ACCOUNT"] = "general",
    ["GET_DEPARTMENTS"] = "general",
    ["GET_PROFILE_FIELDS"] = "general",
    ["GET_ACCOUNT_RANKS"] = "general",
    ["SET_ACCOUNT_RANKS"] = "general",
    ["CLOCK_IN_OUT"] = "general",
    ["KICK_ACCOUNT"] = "general",
    ["BAN_ACCOUNT"] = "general",
    ["EDIT_ACC_PROFLIE_FIELDS"] = "general",
    ["GET_GAME_SERVERS"] = "servers",
	["SET_GAME_SERVERS"] = "servers",
	["VERIFY_WHITELIST"] = "servers",
	["FULL_WHITELIST"] = "servers",
	["RSVP"] = "events"
}

function registerApiType(type, endpoint)
    ApiEndpoints[type] = endpoint
end
exports("registerApiType", registerApiType)

local rateLimitedEndpoints = {}

function performApiRequest(postData, type, cb)
    -- apply required headers
    local payload = {}
    payload["id"] = Config.CommID
    payload["key"] = Config.APIKey
    payload["data"] = postData
    payload["type"] = type
    local endpoint = nil
    if ApiEndpoints[type] ~= nil then
        endpoint = ApiEndpoints[type]
    else
        return warnLog(("API request failed: endpoint %s is not registered. Use the registerApiType function to register this endpoint with the appropriate type."):format(type))
    end
    local url = Config.apiUrl..tostring(endpoint).."/"..tostring(type:lower())
    assert(type ~= nil, "No type specified, invalid request.")
    if Config.critError then
        return
    end
    if rateLimitedEndpoints[type] == nil then
        PerformHttpRequestS(url, function(statusCode, res, headers)
            if Config.debug_mode then
                debugLog('API Result:', tostring(res))
            end
            debugLog(("type %s called with post data %s to url %s"):format(type, json.encode(payload), url))
            if statusCode == 200 or statusCode == 201 and res ~= nil then
                debugLog("result: "..tostring(res))
                if res == "Sonoran CMS: Backend Service Reached" or res == "Backend Service Reached" then
                    errorLog(("API ERROR: Invalid endpoint (URL: %s). Ensure you're using a valid endpoint."):format(url))
                else
                    if res == nil then
                        res = {}
                        debugLog("Warning: Response had no result, setting to empty table.")
                    end
                    cb(res, true)
                end
            elseif statusCode == 400 then
                warnLog("Bad request was sent to the API. Enable debug mode and retry your request. Response: "..tostring(res))
                -- additional safeguards
                if res == "INVALID COMMUNITY ID"
                        or res == "API IS NOT ENABLED FOR THIS COMMUNITY"
                        or string.find(res, "IS NOT ENABLED FOR THIS COMMUNITY")
                        or res == "INVALID API KEY" then
                    errorLog("Fatal: Disabling API - an error was encountered that must be resolved. Please restart the resource after resolving: "..tostring(res))
                    Config.critError = true
                end
                cb(res, false)
            elseif statusCode == 404 then -- handle 404 requests, like from CHECK_APIID
                debugLog("404 response found")
                cb(res, false)
            elseif statusCode == 429 then -- rate limited :(
                if rateLimitedEndpoints[type] then
                    -- don't warn again, it's spammy. Instead, just print a debug
                    debugLog(("Endpoint %s ratelimited. Dropping request."))
                    return
                end
                rateLimitedEndpoints[type] = true
                warnLog(("WARN_RATELIMIT: You are being ratelimited (last request made to %s) - Ignoring all API requests to this endpoint for 60 seconds. If this is happening frequently, please review your configuration to ensure you're not sending data too quickly."):format(type))
                SetTimeout(60000, function()
                    rateLimitedEndpoints[type] = nil
                    infoLog(("Endpoint %s no longer ignored."):format(type))
                end)
            elseif string.match(tostring(statusCode), "50") then
                errorLog(("API error returned (%s). Check status.sonoransoftware.com or our Discord to see if there's an outage."):format(statusCode))
                debugLog(("API_ERROR Error returned: %s %s"):format(statusCode, res))
            else
                errorLog(("CAD API ERROR (from %s): %s %s"):format(url, statusCode, res))
            end
        end, "POST", json.encode(payload), {["Content-Type"]="application/json"})
    else
        debugLog(("Endpoint %s is ratelimited. Dropped request: %s"):format(type, json.encode(payload)))
    end

end

exports("performApiRequest", performApiRequest)
