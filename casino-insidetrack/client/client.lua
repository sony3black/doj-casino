
local QBCore = exports['qb-core']:GetCoreObject()

local cooldown = 60
local tick = 0
local checkRaceStatus = false
local insideTrackActive = false
local gameOpen = false
local insideTrackLocation = vector3(955.619, 70.179, 70.433)

local insideMarker = false
Citizen.CreateThread(function()
    local alreadyEnteredZone = false
    while true do
        wait = 5
        local ped = PlayerPedId()
        local inZone = false
        local coords = GetEntityCoords(ped)
        local dist = #(insideTrackLocation - coords)
        if dist <= 7.0 then
            if dist <= 6.0 and not insideTrackActive then
                insideMarker = true
                wait = 5
                inZone  = true
                if Config.HorseBetPrompt == 'press' then 
                    text = '<b>Diamond Casino Inside Track</b></p>Press [E] to start betting'
					if IsControlJustPressed(0, 38) then -- E
						Citizen.Wait(200)
						TriggerEvent('QBCore:client:openInsideTrack') 
					end
				elseif Config.HorseBetPrompt == 'peek' then
                    text = '<b>Diamond Casino Inside Track</b>'
                    exports['qb-target']:AddCircleZone("Betting", vector3(956.121,70.185,70.433), 1.0, {
                        name="Betting",
                        heading=160,
                        debugPoly=false,
                        useZ=true,
                    }, {
                        options = {
                            {
                                event = "QBCore:client:openInsideTrack", 
                                icon = "fas fa-coins",
                                label = "Start Betting",
                            },
                        },
                        distance = 3.0 
                    })
				end
            end
        else
            wait = 1000
        end
        if inZone and not alreadyEnteredZone then
            alreadyEnteredZone = true
            exports['textUi']:DrawTextUi('show', text)
        end

        if not inZone and alreadyEnteredZone then
            alreadyEnteredZone = false
            exports['textUi']:HideTextUi('hide')
        end
        Citizen.Wait(wait)
    end
end)

local function OpenInsideTrack()
    Citizen.CreateThread(function() -- Disable pause when while in-blackjack
        while true do
            Citizen.Wait(0)
            SetPauseMenuActive(false)
        end
    end)

    QBCore.Functions.TriggerCallback("insidetrack:server:getbalance", function(balance)
        Utils.PlayerBalance = balance
    end)

    if insideTrackActive then
        return
    end
    insideTrackActive = true
    -- Scaleform
    Utils.Scaleform = RequestScaleformMovie('HORSE_RACING_CONSOLE')
    while not HasScaleformMovieLoaded(Utils.Scaleform) do
        Wait(0)
    end
    DisplayHud(false)
    SetPlayerControl(PlayerId(), false, 0)
    while not RequestScriptAudioBank('DLC_VINEWOOD/CASINO_GENERAL') do
        Wait(0)
    end
    Utils:ShowMainScreen()
    Utils:SetMainScreenCooldown(cooldown)
    -- Add horses
    Utils:AddHorses()
    Utils:DrawInsideTrack()
    Utils:HandleControls()
end

function closeHorseBets()
    insideTrackActive = false
    SetPlayerControl(PlayerId(), true, 0)
    DisplayHud(true)
    SetPauseMenuActive(true)
    SetScaleformMovieAsNoLongerNeeded(Utils.Scaleform)
    Utils.Scaleform = -1
    StopSound(0)
end

local function LeaveInsideTrack()
    insideTrackActive = false
    DisplayHud(true)
    SetPauseMenuActive(true)
    SetPlayerControl(PlayerId(), true, 0)
    SetScaleformMovieAsNoLongerNeeded(Utils.Scaleform)
    Utils.Scaleform = -1
end

RegisterNetEvent('QBCore:client:closeBetsNotEnough')
AddEventHandler('QBCore:client:closeBetsNotEnough', function()
    closeHorseBets()
    QBCore.Functions.Notify("Bets Closed! You dont have enough White Casino Chips...", "error", 3500)
end)

RegisterNetEvent('QBCore:client:closeBetsZeroChips')
AddEventHandler('QBCore:client:closeBetsZeroChips', function()
    closeHorseBets()
    QBCore.Functions.Notify("Bets Closed! You dont have any White Casino Chips...", "error", 3500)
end)



RegisterNetEvent('QBCore:client:openInsideTrack')
AddEventHandler('QBCore:client:openInsideTrack', function()
    QBCore.Functions.TriggerCallback('QBCore:HasItem', function(HasItem)
        if HasItem then
            OpenInsideTrack()
        else
            QBCore.Functions.Notify('You are not a member of the casino', 'error', 3500)
        end
    end, "casino_member")
end)


function Utils:DrawInsideTrack()
    Citizen.CreateThread(function()
        while insideTrackActive do
            Wait(0)
            local xMouse, yMouse = GetDisabledControlNormal(2, 239), GetDisabledControlNormal(2, 240)
            -- Fake cooldown
            tick = (tick + 10)
            if (tick == 1000) then
                if (cooldown == 1) then
                    cooldown = 60
                end
                cooldown = (cooldown - 1)
                tick = 0
                Utils:SetMainScreenCooldown(cooldown)
            end
            -- Mouse control
            BeginScaleformMovieMethod(Utils.Scaleform, 'SET_MOUSE_INPUT')
            ScaleformMovieMethodAddParamFloat(xMouse)
            ScaleformMovieMethodAddParamFloat(yMouse)
            EndScaleformMovieMethod()
            -- Draw
            DrawScaleformMovieFullscreen(Utils.Scaleform, 255, 255, 255, 255)
        end
    end)
end

function Utils:HandleControls()
    Citizen.CreateThread(function()
        while insideTrackActive do
            Wait(0)


            if IsControlJustPressed(2, 194) then
                LeaveInsideTrack()
            end

            if IsControlJustPressed(2, 202) then
                LeaveInsideTrack()
            end

            -- Left click
            if IsControlJustPressed(2, 237) then
                local clickedButton = Utils:GetMouseClickedButton()
 
                if Utils.ChooseHorseVisible then
                    if (clickedButton ~= 12) and (clickedButton ~= -1) then
                        Utils.CurrentHorse = (clickedButton - 1)
                        Utils:ShowBetScreen(Utils.CurrentHorse)
                        Utils.ChooseHorseVisible = false
                    end
                end

                -- Rules button
                if (clickedButton == 15) then
                    Utils:ShowRules()
                end

                -- Close buttons
                if (clickedButton == 12) then
                    if Utils.ChooseHorseVisible then
                        Utils.ChooseHorseVisible = false
                    end
                    
                    if Utils.BetVisible then
                        Utils:ShowHorseSelection()
                        Utils.BetVisible = false
                        Utils.CurrentHorse = -1
                    else
                        Utils:ShowMainScreen()
                    end
                end

                -- Start bet
                if (clickedButton == 1) then
                    Utils:ShowHorseSelection()
                end

                -- Start race
                if (clickedButton == 10) then
                    PlaySoundFrontend(-1, 'race_loop', 'dlc_vw_casino_inside_track_betting_single_event_sounds')
                    TriggerServerEvent("insidetrack:server:placebet", Utils.CurrentBet)
                    Utils:StartRace()
                    checkRaceStatus = true
                end

                -- Change bet
                if (clickedButton == 8) then
                    if (Utils.CurrentBet < Utils.PlayerBalance) then
                        Utils.CurrentBet = (Utils.CurrentBet + 100)
                        Utils.CurrentGain = (Utils.CurrentBet * 2)
                        Utils:UpdateBetValues(Utils.CurrentHorse, Utils.CurrentBet, Utils.PlayerBalance, Utils.CurrentGain)
                    end
                end

                if (clickedButton == 9) then
                    if (Utils.CurrentBet > 100) then
                        Utils.CurrentBet = (Utils.CurrentBet - 100)
                        Utils.CurrentGain = (Utils.CurrentBet * 2)
                        Utils:UpdateBetValues(Utils.CurrentHorse, Utils.CurrentBet, Utils.PlayerBalance, Utils.CurrentGain)
                    end
                end

                if (clickedButton == 13) then
                    Utils:ShowMainScreen()
                end

                -- Check race
                while checkRaceStatus do
                    Wait(0)
                    local raceFinished = Utils:IsRaceFinished()
                    if (raceFinished) then
                        StopSound(0)
                        if (Utils.CurrentHorse == Utils.CurrentWinner) then
                            TriggerServerEvent("insidetrack:server:winnings", Utils.CurrentGain)
                        end
                        QBCore.Functions.TriggerCallback("insidetrack:server:getbalance", function(balance)
                            Utils.PlayerBalance = balance
                        end)
                        Utils:UpdateBetValues(Utils.CurrentHorse, Utils.CurrentBet, Utils.PlayerBalance, Utils.CurrentGain)
                        Utils:ShowResults()
                        Utils.CurrentHorse = -1
                        Utils.CurrentWinner = -1
                        Utils.HorsesPositions = {}
                        checkRaceStatus = false
                    end
                end
            end
        end
    end)
end

