--[[
    Draconic Reactor Control v3
]] local configPath = "/home/config/DraconicReactorV3.config"

-- DO NOT MODIFY BELOW THIS LINE --
local config = {
    compIds = {
        overallOutputFG = nil,
        extOutputFG = nil,
        shieldInputFG = nil,
        emergencyFG = nil,
        chargingFG = nil,
        reactor = nil
    },
    fieldTarget = 0.15,
    saturationMinThreshold = 0.3,
    saturationMaxThreshold = 0.5,
    logPath = "reactorLogs"
}

package.loaded.GUI = nil
package.loaded.doubleBuffering = nil
local fs = require("filesystem")
local os = require("os")
local serialization = require("serialization")
local component = require("component")
local computer = require("computer")
local GUI = require("GUI")
local buffer = require("doubleBuffering")
local math = require("math")
local table = require("table")

-- Standard utility functions --
function limitValue(value, min, max)
    return math.max(math.min(value, max), min)
end
local util = {
    getUptimeTick = function()
        return math.floor(computer.uptime() * 20)
    end,
    toPct = function(val, max)
        return (val / max) * 100
    end
}

-- [[ BEGIN GUI SECTION ]] --
local workspace = GUI.workspace()

local top_panel = workspace:addChild(GUI.panel(1, 1, workspace.width, 1, 0x616263))
local body_panel = workspace:addChild(GUI.panel(1, 2, workspace.width, workspace.height - 1, 0xa6a9ad))
local sidebar_panel = workspace:addChild(GUI.panel(workspace.width - 39, 2, 40, workspace.height - 1, 0x2a2a2a))
local topbar = workspace:addChild(GUI.layout(1, 1, workspace.width, 1, 3, 1))
for col = 1, 3 do
    topbar:setDirection(col, 1, GUI.DIRECTION_HORIZONTAL)
end
topbar:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_CENTER)
topbar:setAlignment(2, 1, GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)
topbar:setAlignment(3, 1, GUI.ALIGNMENT_HORIZONTAL_RIGHT, GUI.ALIGNMENT_VERTICAL_CENTER)

topbar:setPosition(2, 1, topbar:addChild(GUI.text(1, 1, 0xFFFFFF, "Draconic Reactor Control")))
local memory = topbar:setPosition(3, 1, topbar:addChild(GUI.text(1, 1, 0xFFFFFF, "")))
local clock = topbar:setPosition(3, 1, topbar:addChild(GUI.text(1, 1, 0xFFFFFF, "")))
local blinker = topbar:setPosition(1, 1, topbar:addChild(GUI.text(1, 1, 0xFFFFFF, "")))
local configButton = topbar:setPosition(3, 1, topbar:addChild(
    GUI.button(1, 1, 10, 1, 0xe6d53e, 0x555555, 0x880000, 0xFFFFFF, "Config")))
local quitButton = topbar:setPosition(3, 1, topbar:addChild(
    GUI.button(1, 1, 1, 1, 0xb00707, 0xe6d5d5, 0x5e0505, 0xFFFFFF, "X")))

-- Setup body GUI
local body_layout = workspace:addChild(GUI.layout(1, 2, workspace.width, workspace.height - 1, 2, 1))
body_layout:setColumnWidth(1, GUI.SIZE_POLICY_ABSOLUTE, body_layout.width - 40)
body_layout:setColumnWidth(2, GUI.SIZE_POLICY_ABSOLUTE, 40)
body_layout:setDirection(1, 1, GUI.DIRECTION_VERTICAL)
body_layout:setDirection(2, 1, GUI.DIRECTION_VERTICAL)
body_layout:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_TOP)
body_layout:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_RIGHT, GUI.ALIGNMENT_VERTICAL_TOP)

-- Setup sidebar
local sidebar = body_layout:setPosition(2, 1, body_layout:addChild(GUI.container(1, 1, 40, body_layout.height)))

-- Setup Console
sidebar:addChild(GUI.label(1, 1, sidebar.width, 1, 0xFFFFFF, "Debug Output")):setAlignment(
    GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)
local console_panel = sidebar:addChild(GUI.container(1, 2, 40, 20))
local console = console_panel:addChild(GUI.textBox(1, 1, console_panel.width, console_panel.height, 0x0, 0x00c264, {},
    1, 1, 0))

console.print = function(textbox, text)
    table.insert(textbox.lines, text)
end
console.clear = function(textbox)
    textbox.lines = {}
end

-- Setup property panel GUI
local property_panel = sidebar:addChild(GUI.container(1, 23, 40, sidebar.height - 22))

local btnCharge = property_panel:addChild(GUI.button(5, 4, 20, 1, 0xe6d53e, 0x555555, 0x880000, 0xFFFFFF, "Charge"))
local btnActivate = property_panel:addChild(GUI.button(5, 6, 20, 1, 0xe6d53e, 0x555555, 0x880000, 0xFFFFFF, "Activate"))
local btnShutdown = property_panel:addChild(GUI.button(5, 8, 20, 1, 0xe6d53e, 0x555555, 0x880000, 0xFFFFFF, "Shutdown"))

-- Setup reactor GUI
function progressBarSetPercentage(progressBar, percentage)
    local adjPct = limitValue(percentage, 0, 1)
    local progressWidth = math.floor((progressBar.width * percentage) + 0.5)
    progressBar.fgPanel.width = progressWidth
end
function progressBar(x, y, width, height, colorBg, colorFg)
    local pbContainer = GUI.container(x, y, width, height)
    local bgPanel = pbContainer:addChild(GUI.panel(1, 1, width, height, colorBg))
    local fgPanel = pbContainer:addChild(GUI.panel(1, 1, 0, height, colorFg))

    pbContainer.bgPanel = bgPanel
    pbContainer.fgPanel = fgPanel
    pbContainer.setPercentage = progressBarSetPercentage

    return pbContainer
end

local reactor_container = body_layout:setPosition(1, 1, body_layout:addChild(
    GUI.container(1, 1, body_layout.width - 40, body_layout.height)))

reactor_container:addChild(GUI.text(2, 2, 0x0, "Reactor Information"))
local txtReactorStatus = reactor_container:addChild(GUI.text(8, 4, 0x0, "Reactor Status: %s"))
local barFieldStrength = reactor_container:addChild(progressBar(23, 5, 30, 1, 0xe6f6fa, 0x6ee4ff))
local txtFieldStrength = reactor_container:addChild(GUI.text(8, 5, 0x0, "Field Strength: %s"))
local barTemperature = reactor_container:addChild(progressBar(23, 6, 30, 1, 0xe6f6fa, 0x6ee4ff))
local txtTemperature = reactor_container:addChild(GUI.text(10, 6, 0x0, "Temperature : %s"))
local barEnergySat = reactor_container:addChild(progressBar(23, 7, 30, 1, 0xe6f6fa, 0x6ee4ff))
local txtEnergySat = reactor_container:addChild(GUI.text(5, 7, 0x0, "Energy Saturation: %s"))
local barFuelConv = reactor_container:addChild(progressBar(23, 8, 30, 1, 0xe6f6fa, 0x6ee4ff))
local txtFuelConv = reactor_container:addChild(GUI.text(7, 8, 0x0, "Fuel Conversion: %s"))
local txtFuelRate = reactor_container:addChild(GUI.text(2, 9, 0x0, "Fuel Conversion Rate: %s"))
local txtRemainingTime = reactor_container:addChild(GUI.text(3, 10, 0x0, "Est. Time Remaining: %s"))

reactor_container:addChild(GUI.text(2, 12, 0x0, "Energy Information"))
local txtGenRate = reactor_container:addChild(GUI.text(7, 14, 0x0, "Generation Rate: %s"))
local txtFieldRate = reactor_container:addChild(GUI.text(6, 15, 0x0, "Field Drain Rate: %s"))
local txtMaxOutput = reactor_container:addChild(GUI.text(5, 16, 0x0, "Total Output Rate: %s"))
local txtExtOutput = reactor_container:addChild(GUI.text(2, 17, 0x0, "External Output Rate: %s"))
local txtFieldInput = reactor_container:addChild(GUI.text(6, 18, 0x0, "Field Input Rate: %s"))
local txtChargeInput = reactor_container:addChild(GUI.text(5, 19, 0x0, "Charge Input Rate: %s"))
local txtPanicInput = reactor_container:addChild(GUI.text(2, 20, 0x0, "Emergency Input Rate: %s"))

local barGenEff = reactor_container:addChild(progressBar(23, 21, 30, 1, 0xe6f6fa, 0x6ee4ff))
local txtGenEff = reactor_container:addChild(GUI.text(12, 21, 0x0, "Efficiency: %s"))

-- [[ END GUI SECTION ]] -- 

local temperatureTarget = 8000
local ticksBetween = 1
local states = {
    OFFLINE = 0,
    CHARGING = 1,
    STOPPING = 2,
    RAMP_UP = 3,
    RUNNING = 4,
    IDLE = 5,
    RECOVERY = 6,
    CRITICAL = 7,
    BEYOND_HOPE = 999
}
local stateNames = {}
for k, v in pairs(states) do
    stateNames[v] = k
end

fs.makeDirectory(config.logPath)
local configSegments = fs.segments(configPath)
table.remove(configSegments)
fs.makeDirectory(fs.concat(table.unpack(configSegments)))
configSegments = nil

local state = states.DISABLED
local reactor = {
    status = "",
    temperature = 0,
    fieldStrength = 0,
    maxfieldStrength = 0,
    energySaturation = 0,
    maxEnergySaturation = 0,
    fuelConversion = 0,
    generationRate = 0,
    fieldDrainRate = 0,
    fuelRate = 0,
    atTick = 0
}
local prevReading = {
    temperature = 0,
    fieldStrength = 0,
    energySaturation = 0,
    fuelConversion = 0,
    generationRate = 0,
    fuelRate = 0,
    atTick = 0
}
local tickDeltas = {} -- See updateDeltas()
local inout = {
    maximumDraw = 0,
    fieldDraw = 0,
    chargingDraw = 0,
    emergencyDraw = 0
}

local comps = {}

function reactor.emergency(reason)
    local time = os.time()
    criticalReason = reason .. " at " .. time
    state = states.CRITICAL
    reactor.shutdown()

    local log = fs.open(config.logPath .. "/emergencyLog-" .. time .. ".log", "a")
    log:write("uptimeTick=" .. util.getUptimeTick())
    log:write("inout=" .. serialization.serialize(inout, 50))
    log:write("tickDeltas=" .. serialization.serialize(tickDeltas, 50))
    log:write("reactor=" .. serialization.serialize(reactor, 50))
    log:write("prevReading=" .. serialization.serialize(prevReading, 50))
    log:close()
end
function reactor.setFieldDraw(drawAmt)
    comps.shieldInputFG.setOverrideEnabled(true)
    comps.shieldInputFG.setFlowOverride(drawAmt)
end
function reactor.setOutputDraw(drawAmt)
    comps.overallOutputFG.setOverrideEnabled(true)
    comps.overallOutputFG.setFlowOverride(drawAmt)
end
function reactor.setExtOutputDraw(drawAmt)
    comps.extOutputFG.setOverrideEnabled(true)
    comps.extOutputFG.setFlowOverride(drawAmt)
end
function reactor.setChargingDraw(drawAmt)
    comps.chargingFG.setOverrideEnabled(true)
    comps.chargingFG.setFlowOverride(drawAmt)
end
function reactor.setEmergencyDraw(drawAmt)
    comps.emergencyFG.setOverrideEnabled(true)
    comps.emergencyFG.setFlowOverride(drawAmt)
end
function reactor.updateReadings()
    -- Copy values to prevReading
    prevReading.temperature = reactor.temperature
    prevReading.fieldStrength = reactor.fieldStrength
    prevReading.energySaturation = reactor.energySaturation
    prevReading.fuelConversion = reactor.fuelConversion
    prevReading.fuelRate = reactor.fuelRate
    prevReading.generationRate = reactor.generationRate
    prevReading.atTick = reactor.atTick
    prevReading.fieldDrainRate = reactor.fieldDrainRate

    -- Read values into reactor table
    local reactorData = comps.reactor.getReactorInfo()
    reactor.status = reactorData.status
    reactor.temperature = reactorData.temperature
    reactor.fieldStrength = reactorData.fieldStrength
    reactor.maxFieldStrength = reactorData.maxFieldStrength
    reactor.fieldStrengthPct = reactor.fieldStrength / reactor.maxFieldStrength
    reactor.fieldDrainRate = reactorData.fieldDrainRate
    reactor.energySaturation = reactorData.energySaturation
    reactor.maxEnergySaturation = reactorData.maxEnergySaturation
    reactor.energySaturationPct = reactor.energySaturation / reactor.maxEnergySaturation
    reactor.fuelConversion = reactorData.fuelConversion
    reactor.maxFuelConversion = reactorData.maxFuelConversion
    reactor.fuelConversionPct = reactor.fuelConversion / reactor.maxFuelConversion
    reactor.fuelRate = reactorData.fuelConversionRate
    reactor.generationRate = reactorData.generationRate
    reactor.atTick = util.getUptimeTick()
end

function updateDeltas()
    local ticks = reactor.atTick - prevReading.atTick
    if ticks > 0 then
        tickDeltas.temperature = (reactor.temperature - prevReading.temperature) / ticks
        tickDeltas.fieldStrength = (reactor.fieldStrength - prevReading.fieldStrength) / ticks
        tickDeltas.energySaturation = (reactor.energySaturation - prevReading.energySaturation) / ticks
        tickDeltas.fieldDrainRate = (reactor.fieldDrainRate - prevReading.fieldDrainRate) / ticks
        tickDeltas.generationRate = (reactor.generationRate - prevReading.generationRate) / ticks
        tickDeltas.fuelRate = (reactor.fuelRate - prevReading.fuelRate) / ticks
    end
end
function updateIO()
    local outputDraw = math.max(inout.maximumDraw - inout.fieldDraw, 0)
    reactor.setFieldDraw(inout.fieldDraw)
    reactor.setOutputDraw(math.max(inout.maximumDraw, inout.fieldDraw))
    reactor.setExtOutputDraw(outputDraw)
    reactor.setChargingDraw(inout.chargingDraw)
    reactor.setEmergencyDraw(inout.emergencyDraw)
end

function updateReactorUIState()
    txtReactorStatus.text = string.format("Reactor Status: %s", reactor.status)
    txtFieldStrength.text = string.format("Field Strength: %.4f%%", reactor.fieldStrengthPct * 100)
    barFieldStrength:setPercentage(reactor.fieldStrengthPct)
    txtTemperature.text = string.format("Temperature : %s", reactor.temperature)
    barTemperature:setPercentage(reactor.temperature / 9000)
    txtFuelConv.text = string.format("Fuel Conversion: %.4f%%", reactor.fuelConversionPct * 100)
    barFuelConv:setPercentage(reactor.fuelConversionPct)
    txtEnergySat.text = string.format("Energy Saturation: %.4f%%", reactor.energySaturationPct * 100)
    barEnergySat:setPercentage(reactor.energySaturationPct)
    txtFuelRate.text = string.format("Fuel Conversion Rate: %s", reactor.fuelRate)

    local conversionLimit = reactor.maxFuelConversion * 0.9
    local fuelLeft = conversionLimit - reactor.fuelConversion
    local fuelSecondsLeft = fuelLeft / (reactor.fuelRate / 1000000) / 20
    txtRemainingTime.text = string.format("Est. Time Remaining: %.2dD %.2dH %.2dM %.2dS",
        math.floor(fuelSecondsLeft / 86400),
        math.floor(fuelSecondsLeft / 3600 % 24),
        math.floor(fuelSecondsLeft / 60 % 60),
        math.floor(fuelSecondsLeft % 60))

    txtGenRate.text = string.format("Generation Rate: %s RF/t", math.floor(reactor.generationRate))
    txtFieldRate.text = string.format("Field Drain Rate: %s RF/t", math.floor(reactor.fieldDrainRate))
    txtMaxOutput.text = string.format("Total Output Rate: %s RF/t", math.floor(inout.maximumDraw))
    txtExtOutput.text = string.format("External Output Rate: %s RF/t", math.floor(inout.maximumDraw - inout.fieldDraw))
    txtFieldInput.text = string.format("Field Input Rate: %s RF/t", math.floor(inout.fieldDraw))
    txtChargeInput.text = string.format("Charge Input Rate: %s RF/t", math.floor(inout.chargingDraw))
    txtPanicInput.text = string.format("Emergency Input Rate: %s RF/t", math.floor(inout.emergencyDraw))

    local genEff = 1 - (inout.fieldDraw / inout.maximumDraw)
    if genEff ~= genEff then
        txtGenEff.text = string.format("Efficiency: %.4f%%", 0)
        barGenEff:setPercentage(0)
    else
        txtGenEff.text = string.format("Efficiency: %.4f%%", genEff * 100)
        barGenEff:setPercentage(genEff)
    end

    if criticalReason ~= nil then
        txtReactorStatus.text = txtReactorStatus.text .. string.format(" (Critical Shutdown: %s)", criticalReason)
    end

    btnActivate.hidden = reactor.status ~= "warming_up" and reactor.status ~= "stopping"
    btnCharge.hidden = reactor.status ~= "cold" and reactor.status ~= "cooling"
    btnShutdown.hidden = reactor.status ~= "warming_up" and reactor.status ~= "running"
end

function debugPrintState()
    console:print(string.format("Program State: %s", stateNames[state]))

    console:print("Deltas:")
    for k, v in pairs(tickDeltas) do
        console:print(string.format("%s: %s", k, v))
    end
end

function expScalePct1(pctValue, a, b, c)
    return limitValue(c * (1 - math.exp(b * a * pctValue)), 0, 100)
end

-- Return true to retick immediately.
local saturationUp = false
function doReactorTick(ticksElapsed)
    if blinker.text == "" then
        blinker.text = "."
    else
        blinker.text = ""
    end

    -- Initialize Tick
    local tickAgain = false
    local checkDuration = ticksBetween + 5
    if (ticksElapsed > 0) then
        reactor.updateReadings()
        updateDeltas()
    end
    inout.emergencyDraw = 0
    inout.chargingDraw = 0
    local minSat = reactor.maxEnergySaturation * config.saturationMinThreshold
    local maxSat = reactor.maxEnergySaturation * config.saturationMaxThreshold

    -- Handle conversion limit.
    if reactor.fuelConversionPct > 0.9 then
        reactor.shutdown()
    end

    -- Update reactor status
    if reactor.status == "invalid" then
        state = states.OFFLINE
    elseif reactor.status == "cold" then
        state = states.OFFLINE
    elseif reactor.status == "warming_up" then
        state = states.CHARGING
    elseif reactor.status == "running" then
        if criticalReason ~= nil then
            criticalReason = nil
        end
        if state == states.CHARGING then
            state = states.RAMP_UP
        elseif state == states.STOPPING or state == nil then
            state = states.RUNNING
        end
    elseif reactor.status == "stopping" then
        if state ~= states.CRITICAL then
            state = states.STOPPING
        end
    elseif reactor.status == "cooling" then
        state = states.OFFLINE
    elseif reactor.status == "beyond_hope" then
        state = states.GOINGBOOM
    else
        reactor.emergency("UNKNOWN REACTOR STATUS")
        console:print("UNKNOWN STATUS: " .. reactor.status)
    end

    -- Failsafes
    -- If temperature will exceed 9k or saturation below min - 0.05 or 0.05, whichever is higher.
    if reactor.status == "running" and state ~= states.RECOVERY and
        (reactor.temperature + (tickDeltas.temperature * checkDuration) >= 9000 or reactor.energySaturation +
            (tickDeltas.energySaturation * checkDuration) < reactor.maxEnergySaturation *
            math.max(config.saturationMinThreshold - 0.05, 0.05)) then
        state = states.RECOVERY
    end

    -- If temperature will exceed 9.5k or saturation below 0.05
    if reactor.status == "running" and (reactor.energySaturationPct < 0.05 or reactor.temperature > 9500) then
        state = states.CRITICAL
    end

    -- Calculate field drain rate.
    local futureFDR = reactor.fieldDrainRate + math.abs(tickDeltas.fieldDrainRate * checkDuration)
    local avgFDR = (reactor.fieldDrainRate + futureFDR) / 2
    local fieldReq = avgFDR / (1 - config.fieldTarget)

    -- Tick operation
    if state == states.RUNNING or state == states.RAMP_UP then
        -- Calculate scaling exponents. (Temp 7000k - 7500k and Saturation minSat - maxSat)

        local a, b, c = 0.03, 1.8, 100.454

        -- local tempLimitPct = (1 - math.max(math.min((reactor.temperature - 7800) / 400, 1),0)) * 100
        local tempLimitRange = 8000 - 7900
        local adjTemp = limitValue(reactor.temperature, 7900, 8000) - 7900
        local adjTempPct = (adjTemp / tempLimitRange) * 100
        -- local tempScalingExp = 100 * (1 - math.exp(0.045 * (adjTempPct - 100)) * math.max(math.min((adjTempPct - 5)/5,1),0)) / 100

        local tempScalingExp = expScalePct1(adjTempPct - 100, a, b, c) / 100

        -- local satScalingPct = math.min(math.max((reactor.energySaturation - minSat) / (maxSat - minSat), 0), 1) * 100
        local satRange = maxSat - minSat
        local adjSat = limitValue(reactor.energySaturation, minSat, maxSat) - minSat
        local adjSatPct = (adjSat / satRange) * 100
        -- local satScalingExp = 100 * math.exp(0.045 * (adjSatPct - 100)) * math.max(math.min((adjSatPct-5/5),1),0) / 100
        local satScalingExp = expScalePct1(-adjSatPct, a, b, c) / 100

        if reactor.energySaturationPct < config.saturationMinThreshold then
            satScalingExp = 0
        end
        if reactor.temperature > 8000 then
            tempScalingExp = 0
        end

        local scalingExp = math.min(tempScalingExp, satScalingExp)
        local negScalingExp = 1 - scalingExp

        console:print("Internal Scaling Variables:")
        console:print("tempPct: " .. adjTempPct)
        console:print("tempScalingExp: " .. tempScalingExp)
        console:print("adjSatPct: " .. adjSatPct)
        console:print("satScalingExp: " .. satScalingExp)
        console:print("scalingExp: " .. scalingExp)

        local output = 0

        if state == states.RAMP_UP then
            if reactor.generationRate > 10000 then
                state = states.RUNNING
            else
                output = reactor.energySaturation * 0.005
            end
        else
            if tickDeltas.energySaturation > 0 and tickDeltas.temperature < 0 and tickDeltas.energySaturation <
                reactor.generationRate and reactor.energySaturationPct >= 0.9 then
                state = states.IDLE
                return true
            end
            local subtracted = math.min(math.max(reactor.generationRate * negScalingExp, 0), reactor.generationRate)
            local additionalLoad = reactor.energySaturation * (0.005 * scalingExp)

            output = reactor.generationRate - subtracted + additionalLoad
            console:print("additionalLoad: " .. additionalLoad)
            console:print("subtracted: " .. subtracted)
        end
        inout.maximumDraw = math.max(output, reactor.generationRate * 0.95)
        console:print("output: " .. output)
        inout.fieldDraw = fieldReq
    elseif state == states.IDLE then
        if tickDeltas.energySaturation < 0 and reactor.energySaturationPct <= 0.9 then
            state = states.RUNNING
            return true
        else
            inout.maximumDraw = math.max(fieldReq, reactor.generationRate) + reactor.energySaturation * 0.005
            inout.fieldDraw = fieldReq
        end
    elseif state == states.STOPPING then
        inout.fieldDraw = 0
        inout.maximumDraw = 0
        inout.chargingDraw = fieldReq
        -- inout.chargingDraw = math.abs(tickDeltas.fieldStrength)/(1 - reactor.fieldStrengthPct)
    elseif state == states.RECOVERY then
        inout.maximumDraw = fieldReq
        inout.fieldDraw = inout.maximumDraw
        if reactor.status == "running" and
            (reactor.temperature + (tickDeltas.temperature * checkDuration) < 8000 or reactor.energySaturation +
                (tickDeltas.energySaturation * checkDuration) >= reactor.maxEnergySaturation *
                config.saturationMinThreshold) then
            state = states.RUNNING
        end
        console:print("futureFDR: " .. futureFDR)
        console:print("avgFDR: " .. avgFDR)
        console:print("fieldReq: " .. fieldReq)
    elseif state == states.CRITICAL then
        inout.fieldDraw, inout.maximumDraw = 0, 0
        inout.emergencyDraw = math.max(fieldReq * 10, 10000000)
        if util.toPct(reactor.fieldStrength, reactor.maxfieldStrength) > 20 and reactor.temperature < 7000 then
            state = states.RECOVERY
            inout.emergencyDraw = 0
            return true
        end
    elseif state == states.BEYOND_HOPE then
        console:print("GOOD BYE CRUEL WORLD")
        running = false -- Terminate program now. Nothing left to do.
        computer.beep()
        GUI.alert("REACTOR GOING BOOM!")
    elseif state == states.OFFLINE then
        inout.maximumDraw = 0
        inout.fieldDraw = 0
    elseif state == states.CHARGING then
        inout.maximumDraw = 0
        inout.fieldDraw = 0
        inout.chargingDraw = 1000000
    end

    -- Prevent runaway field draw causing boom!
    local genFieldDiff = reactor.generationRate - inout.fieldDraw
    if reactor.status == "running" and genFieldDiff < 0 and math.abs(genFieldDiff) > reactor.energySaturation * 0.1 then
        reactor.emergency("GENERATION RATE / FIELD DRAW DIFF EXCEED 10% SATURATION: genFieldDiff is " .. genFieldDiff)
        return true
    end
    if reactor.status == "running" and (inout.fieldDraw / inout.maximumDraw) > 1.5 then
        reactor.emergency("FIELD DRAW : MAX DRAW RATIO EXCEED 1.5")
        return true
    end

    updateIO()
    return tickAgain
end

local running = false
local prevTick = 0
function runTick()
    if not running then
        return
    end

    local basicSleepDuration = math.max((ticksBetween / 20) - 1, 0)
    local curTick = util.getUptimeTick()
    local sleepDuration = basicSleepDuration
    if (curTick - prevTick) >= ticksBetween then
        local elapsed = 0
        local count = 0
        if prevTick ~= 0 then
            elapsed = curTick - prevTick
        end
        local tickAgain = false
        repeat
            count = count + 1
            console:clear()
            tickAgain = doReactorTick(elapsed) and running
            debugPrintState()
            if tickAgain then
                elapsed = -1
                if curTick ~= util.getUptimeTick() then
                    prevTick = curTick
                    curTick = util.getUptimeTick()
                    elapsed = curTick - prevTick
                end
            end
            if count > 10 then -- Stop continuous tick, need to yield.
                tickAgain = false
                sleepDuration = 0.001
            end
        until not tickAgain
        prevTick = curTick
    end
end

function setupEnvironment()
    running = false

    -- Initialize component proxies
    local compCount = 0
    for k, v in pairs(config.compIds) do
        compCount = compCount + 1
        if v == nil or string.len(v) == 0 then
            error("Missing address for: " .. k)
        end
        local addr = component.get(v)
        if addr == nil then
            error("Invalid GUID specified in config: " .. v)
        else
            comps[k] = component.proxy(addr)
        end
    end

    if compCount <= 0 then
        error("No Compponents Defined!")
    end

    if config.fieldTarget <= 0 or config.fieldTarget >= 1 then
        error("fieldTarget invalid value. Valid values 0 - 1")
    end
    if config.saturationMinThreshold <= 0 or config.saturationMinThreshold >= 1 or config.saturationMaxThreshold <= 0 or
        config.saturationMaxThreshold >= 1 then
        error("saturationThreshold invalid value. Valid values 0 - 1")
    end
    if temperatureTarget < 2500 or temperatureTarget > 9000 then
        error("invalid temperature target")
    end

    reactor.activate = comps.reactor.activateReactor
    reactor.shutdown = comps.reactor.stopReactor
    reactor.charge = comps.reactor.chargeReactor

    reactor.updateReadings()
    updateDeltas()
    updateIO()

    running = true
end

-- Setup config GUI --------------------------------------------------------------------------------
function showConfigGUI()
    reactor_container.hidden = true
    local config_layout = body_layout:setPosition(1, 1, body_layout:addChild(
        GUI.layout(1, 1, body_layout.width - 40, body_layout.height, 2, 10)))
    config_layout:setColumnWidth(1, GUI.SIZE_POLICY_ABSOLUTE, 30)
    config_layout:setColumnWidth(2, GUI.SIZE_POLICY_ABSOLUTE, config_layout.width - 30)

    config_layout:setPosition(1, 1, config_layout:addChild(GUI.text(1, 1, 0x0, "Reactor Component")))
    local cbReactor = config_layout:setPosition(2, 1, config_layout:addChild(
        GUI.comboBox(1, 1, 30, 3, 0xFFFFFF, 0x0, 0xFFFFFF, 0x0)))
    config_layout:setPosition(1, 2, config_layout:addChild(GUI.text(1, 1, 0x0, "Overall Output Flux Gate")))
    local cbOverallFG = config_layout:setPosition(2, 2, config_layout:addChild(
        GUI.comboBox(1, 1, 30, 3, 0xFFFFFF, 0x0, 0xFFFFFF, 0x0)))
    config_layout:setPosition(1, 3, config_layout:addChild(GUI.text(1, 1, 0x0, "Output Flux Gate")))
    local cbOutputFG = config_layout:setPosition(2, 3, config_layout:addChild(
        GUI.comboBox(1, 1, 30, 3, 0xFFFFFF, 0x0, 0xFFFFFF, 0x0)))
    config_layout:setPosition(1, 4, config_layout:addChild(GUI.text(1, 1, 0x0, "Containment Input Flux Gate")))
    local cbFieldFG = config_layout:setPosition(2, 4, config_layout:addChild(
        GUI.comboBox(1, 1, 30, 3, 0xFFFFFF, 0x0, 0xFFFFFF, 0x0)))
    config_layout:setPosition(1, 5, config_layout:addChild(GUI.text(1, 1, 0x0, "Charging Flux Gate")))
    local cbChargingFG = config_layout:setPosition(2, 5, config_layout:addChild(
        GUI.comboBox(1, 1, 30, 3, 0xFFFFFF, 0x0, 0xFFFFFF, 0x0)))
    config_layout:setPosition(1, 6, config_layout:addChild(GUI.text(1, 1, 0x0, "Emergency Flux Gate")))
    local cbEmergencyFG = config_layout:setPosition(2, 6, config_layout:addChild(
        GUI.comboBox(1, 1, 30, 3, 0xFFFFFF, 0x0, 0xFFFFFF, 0x0)))

    config_layout:setPosition(1, 7, config_layout:addChild(GUI.text(1, 1, 0x0, "Field Strength Target")))
    local slFieldTargetPct = config_layout:setPosition(2, 7,
        config_layout:addChild(
            GUI.slider(4, 2, 30, 0x66DB80, 0x0, 0xFFFFFF, 0x0, 5, 100, config.fieldTarget * 100, true, "", " %")))
    slFieldTargetPct.roundValues = true
    config_layout:setPosition(1, 8, config_layout:addChild(GUI.text(1, 1, 0x0, "Target Min Energy Saturation")))
    local slSatMinPct = config_layout:setPosition(2, 8,
        config_layout:addChild(
            GUI.slider(4, 2, 30, 0x66DB80, 0x0, 0xFFFFFF, 0x0, 5, 100, config.saturationMinThreshold * 100, true, "",
                " %")))
    slSatMinPct.roundValues = true
    config_layout:setPosition(1, 9, config_layout:addChild(GUI.text(1, 1, 0x0, "Target Max Energy Saturation")))
    local slSatMaxPct = config_layout:setPosition(2, 9,
        config_layout:addChild(
            GUI.slider(4, 2, 30, 0x66DB80, 0x0, 0xFFFFFF, 0x0, 5, 100, config.saturationMaxThreshold * 100, true, "",
                " %")))
    slSatMaxPct.roundValues = true

    local btnConfigSave = config_layout:setPosition(1, 10, config_layout:addChild(
        GUI.button(1, 1, 20, 1, 0xe6d53e, 0x555555, 0x880000, 0xFFFFFF, "Save Config")))
    btnConfigSave.onTouch = function()
        local result, payload = pcall(setupEnvironment)
        if result then
            local stream = io.open(configPath, "w")
            local configString = serialization.serialize(config)
            stream:write(configString)
            stream:close()
            config_layout:remove()
            reactor_container.hidden = false
        else
            GUI.alert(payload)
        end
    end

    slFieldTargetPct.onValueChanged = function()
        config.fieldTarget = slFieldTargetPct.value / 100
    end
    slSatMinPct.onValueChanged = function()
        config.saturationMinThreshold = slSatMinPct.value / 100
    end
    slSatMaxPct.onValueChanged = function()
        config.saturationMaxThreshold = slSatMaxPct.value / 100
    end

    function cbAddItemAndSelect(combobox, item, curValue)
        local cbItem = combobox:addItem(item)
        if item == curValue then
            combobox.selectedItem = combobox:count()
        end
        return cbItem
    end

    for address, type in component.list("flux_gate") do
        cbAddItemAndSelect(cbOutputFG, address, config.compIds.extOutputFG).onTouch = function()
            config.compIds.extOutputFG = address
        end
        cbAddItemAndSelect(cbOverallFG, address, config.compIds.overallOutputFG).onTouch = function()
            config.compIds.overallOutputFG = address
        end
        cbAddItemAndSelect(cbFieldFG, address, config.compIds.shieldInputFG).onTouch = function()
            config.compIds.shieldInputFG = address
        end
        cbAddItemAndSelect(cbChargingFG, address, config.compIds.chargingFG).onTouch = function()
            config.compIds.chargingFG = address
        end
        cbAddItemAndSelect(cbEmergencyFG, address, config.compIds.emergencyFG).onTouch = function()
            config.compIds.emergencyFG = address
        end
    end

    for address, type in component.list("draconic_reactor") do
        cbAddItemAndSelect(cbReactor, address, config.compIds.reactor).onTouch = function()
            config.compIds.reactor = address
        end
    end
end

configButton.onTouch = function()
    showConfigGUI()
end
quitButton.onTouch = function()
    running = false
    os.exit()
end
btnCharge.onTouch = function()
    reactor.charge()
end
btnActivate.onTouch = function()
    reactor.activate()
end
btnShutdown.onTouch = function()
    reactor.shutdown()
end

function loadConfig()
    if fs.exists(configPath) then
        local stream = io.open(configPath, "r")
        local configString = stream:read("*a")
        stream:close()
        config = serialization.unserialize(configString)
        local result = pcall(setupEnvironment)
        if not result then
            showConfigGUI()
        end
    else
        showConfigGUI()
    end
end

function init()
    loadConfig()
    workspace.eventHandler = function(workspace, object, event, ...)
        runTick()

        clock.text = os.date("%I:%M %p")
        local memTotal = computer.totalMemory()
        local memFree = computer.freeMemory()
        local memUsed = memTotal - memFree
        local memUsage = (memUsed / memTotal) * 100
        memUsage = math.floor(memUsage + 0.5)
        memory.text = string.format("RAM: %s%%", memUsage)

        updateReactorUIState()

        workspace:draw()
    end
    workspace:start(0)
end

init()
