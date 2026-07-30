if not isServer() then return end

local MOD = "RealisticDash"
local CMD = "SetRadioSource"

local function onClientCommand(module, command, playerObj, args)
    if module ~= MOD or command ~= CMD then return end
    if not args or args.vid == nil or args.src == nil then return end

    local vid = tonumber(args.vid)
    local src = tostring(args.src)
    if not vid then return end
    if src ~= "radio" and src ~= "cd" then return end

    local veh = getVehicleById(vid)
    if not veh then return end

    -- sanity/anti-cheat: sender must be inside the vehicle they’re trying to control
    if playerObj and playerObj.getVehicle and playerObj:getVehicle() ~= veh then
        return
    end

    -- broadcast to everyone (including sender is fine)
    local players = getOnlinePlayers()
    if players then
        for i = 0, players:size() - 1 do
            local pl = players:get(i)
            if pl then
                sendServerCommand(pl, MOD, CMD, { vid = vid, src = src })
            end
        end
    end

end

Events.OnClientCommand.Add(onClientCommand)
