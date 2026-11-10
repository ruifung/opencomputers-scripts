--[[
    Draconic Reactor Control v2
]]

-- --[[ CONFIGURATION
--     Component names:
--     - overallOutputFG
--     - extOutputFG
--     - shieldInputFG
--     - emergencyFG
--     - chargingFG
--     - reactor
-- ]]
-- compIds = {
--     overallOutputFG = nil,
--     extOutputFG = nil,
--     shieldInputFG = nil,
--     emergencyFG = nil,
--     chargingFG = nil,
--     reactor = nil
-- }
-- fieldTarget = 0.15
-- saturationMinThreshold = 0.3
-- saturationMaxThreshold = 0.5
-- logPath = "reactorLogs"

dofile "reactorConfig.lua"

-- DO NOT MODIFY BELOW THIS LINE --
local fs = require("filesystem")
local os = require("os")
local serialization = require("serialization")
local component = require("component")
local computer = require("computer")
local term = require("term")
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
for k,v in pairs(states) do stateNames[v] = k end

fs.makeDirectory(logPath)

local state = states.DISABLED
local reactor = {
    status = "",
    temperature = 0,
    fieldStrength = 0,
    maxfieldStrength = 0,
    energySaturation = 0,
    maxEnergySaturation = 0,
    fuelConversion = 0,
    fieldRate = 0,
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
    fieldRate = 0,
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
local util = {
    getUptimeTick = function()
        return math.floor(computer.uptime() * 20)
    end,
    toPct = function(val, max)
        return (val / max) * 100
    end
}

local comps = {}

function reactor.emergency(reason)
    local time = os.time()
    criticalReason = reason .. " at " .. time
    state = states.CRITICAL
    reactor.shutdown()

    local log = fs.open(logPath .. "/emergencyLog-" .. time .. ".log", "a")
    log:write("uptimeTick=".. util.getUptimeTick())
    log:write("inout="..serialization.serialize(inout, 50))
    log:write("tickDeltas="..serialization.serialize(tickDeltas, 50))
    log:write("reactor="..serialization.serialize(reactor, 50))
    log:write("prevReading="..serialization.serialize(prevReading, 50))
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
    prevReading.fieldRate = reactor.fieldRate
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
    reactor.fieldRate = reactor.fieldDrainRate / (1 - reactor.fieldStrengthPct)
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

function debugPrintState()
    print("Deltas:")
    for k,v in pairs(tickDeltas) do
        print(k, v)
    end
    print("Program State:", stateNames[state])
    print("In/Out State")
    for k,v in pairs(inout) do
        print(k,v)
    end

    print("Reactor State")
    print("Status:", reactor.status)
    print("Temp: ", reactor.temperature)
    print("Field %:", reactor.fieldStrengthPct)
    print("Saturation %:", reactor.energySaturationPct)
    print("Generation:", reactor.generationRate)
    print("Field Rate:", reactor.fieldRate)
    print("Field Drain:", reactor.fieldDrainRate)
    print("Fuel Conversion %:", reactor.fuelConversionPct)

    print("Field/Generation Ratio:", util.toPct(inout.fieldDraw, reactor.generationRate))

    if criticalReason ~= nil then
        print("Critical Shutdown Reason:", criticalReason)
    end
end

function limitValue(value, min, max)
    return math.max(math.min(value, max), min)
end

function expScalePct1(pctValue, a, b, c)
    return limitValue(c * (1 - math.exp(b * a * pctValue)), 0, 100)
end

-- Return true to retick immediately.
local saturationUp = false
function tick(ticksElapsed)
    --Initialize Tick
    local tickAgain = false
    local checkDuration = ticksBetween + 5
    if (ticksElapsed > 0) then
        reactor.updateReadings()
        updateDeltas()
    end
    inout.emergencyDraw = 0
    inout.chargingDraw = 0
    local minSat = reactor.maxEnergySaturation * saturationMinThreshold
    local maxSat = reactor.maxEnergySaturation * saturationMaxThreshold

    --Handle conversion limit.
    if reactor.fuelConversionPct > 0.9 then
        reactor.shutdown()
    end

    --Update reactor status
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
        print("UNKNOWN STATUS:", reactor.status)
    end

    -- Failsafes
    --If temperature will exceed 9k or saturation below min - 0.05 or 0.05, whichever is higher.
    if reactor.status == "running" and state ~= states.RECOVERY and (reactor.temperature + (tickDeltas.temperature * checkDuration) >= 9000 
            or reactor.energySaturation + (tickDeltas.energySaturation * checkDuration) < reactor.maxEnergySaturation * math.max(saturationMinThreshold - 0.05, 0.05)) then
        state = states.RECOVERY
    end

    --If temperature will exceed 9.5k or saturation below 0.05
    if reactor.status == "running" and (reactor.energySaturationPct < 0.05 or reactor.temperature > 9500) then
        state = states.CRITICAL
    end

    -- Calculate field drain rate.
    local futureFDR = reactor.fieldDrainRate + math.abs(tickDeltas.fieldDrainRate * checkDuration)
    local avgFDR = (reactor.fieldDrainRate + futureFDR) / 2
    local fieldReq = avgFDR / (1 - fieldTarget)

    -- Tick operation
    if state == states.RUNNING or state == states.RAMP_UP then
        -- Calculate scaling exponents. (Temp 7000k - 7500k and Saturation minSat - maxSat)
        
        local a,b,c =  0.03, 1.8, 100.454
        
        -- local tempLimitPct = (1 - math.max(math.min((reactor.temperature - 7800) / 400, 1),0)) * 100
        local tempLimitRange = 8000 - 7900
        local adjTemp = math.max(math.min(reactor.temperature, 8000), 7900) - 7900
        local adjTempPct = (adjTemp/tempLimitRange) * 100
        -- local tempScalingExp = 100 * (1 - math.exp(0.045 * (adjTempPct - 100)) * math.max(math.min((adjTempPct - 5)/5,1),0)) / 100

        local tempScalingExp = expScalePct1(adjTempPct - 100, a, b, c) / 100

        -- local satScalingPct = math.min(math.max((reactor.energySaturation - minSat) / (maxSat - minSat), 0), 1) * 100
        local satRange = maxSat-minSat
        local adjSat = math.max(math.min(reactor.energySaturation, maxSat), minSat) - minSat
        local adjSatPct = (adjSat/satRange) * 100
        -- local satScalingExp = 100 * math.exp(0.045 * (adjSatPct - 100)) * math.max(math.min((adjSatPct-5/5),1),0) / 100
        local satScalingExp = expScalePct1(-adjSatPct, a, b, c) / 100

        if reactor.energySaturationPct < saturationMinThreshold then
            satScalingExp = 0
        end
        if reactor.temperature > 8000 then
            tempScalingExp = 0
        end

        local scalingExp = math.min(tempScalingExp, satScalingExp)
        local negScalingExp = 1 - scalingExp

        print("tempPct", adjTempPct)
        print("TempScalingExp", tempScalingExp)
        print("satPct", adjSatPct)
        print("SatScalingExp", satScalingExp)
        print("ScalingExp", scalingExp)
        
        local output = 0

        if state == states.RAMP_UP then
            if reactor.generationRate > 10000 then
                state = states.RUNNING
            else
                output = reactor.energySaturation * 0.005
            end
        else
            if tickDeltas.energySaturation > 0 and tickDeltas.temperature < 0 and tickDeltas.energySaturation < reactor.generationRate and reactor.energySaturationPct >= 0.9 then
                state = states.IDLE
                return true
            end
            local subtracted = math.min(math.max(reactor.generationRate * negScalingExp, 0), reactor.generationRate)
            local additionalLoad = reactor.energySaturation * (0.005 * scalingExp)
        
            output = reactor.generationRate - subtracted + additionalLoad
            print("AdditionalLoad:", additionalLoad)
            print("Subtracted:", subtracted)
        end
        inout.maximumDraw = math.max(output, reactor.generationRate * 0.95)
        print("Output:", output)
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
        --inout.chargingDraw = math.abs(tickDeltas.fieldStrength)/(1 - reactor.fieldStrengthPct)
    elseif state == states.RECOVERY then
        inout.maximumDraw = fieldReq
        inout.fieldDraw = inout.maximumDraw
        if reactor.status == "running" and (reactor.temperature + (tickDeltas.temperature * checkDuration) < 8000 
                or reactor.energySaturation + (tickDeltas.energySaturation * checkDuration) >= reactor.maxEnergySaturation * saturationMinThreshold) then
            state = states.RUNNING
        end
        print(futureFDR, avgFDR, fieldReq)
    elseif state == states.CRITICAL then
        inout.fieldDraw, inout.maximumDraw = 0, 0
        inout.emergencyDraw = math.max(fieldReq * 10, 10000000)
        if util.toPct(reactor.fieldStrength, reactor.maxfieldStrength) > 20 and reactor.temperature < 7000 then
            state = states.RECOVERY
            inout.emergencyDraw = 0
            return true
        end
    elseif state == states.BEYOND_HOPE then
        print("GOOD BYE CRUEL WORLD")
        running = false -- Terminate program now. Nothing left to do.
    elseif state == states.OFFLINE then
        inout.maximumDraw = 0
        inout.fieldRate = 0
    elseif state == states.CHARGING then
        inout.maximumDraw = 0
        inout.fieldRate = 0
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

local running = true
function runTick()
    local basicSleepDuration = math.max((ticksBetween / 20) - 1, 0)
    print(basicSleepDuration)
    local prevTick = 0
    while running do
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
                term.clear()
                tickAgain = tick(elapsed) and running
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
        os.sleep(sleepDuration)
    end
end

function init()
    -- Initialize component proxies
    local compCount = 0
    for k,v in pairs(compIds) do
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

    if fieldTarget <= 0 or fieldTarget >= 1 then
        error("fieldTarget invalid value. Valid values 0 - 1")
    end
    if saturationMinThreshold <= 0 or saturationMinThreshold >= 1
            or saturationMaxThreshold <= 0 or saturationMaxThreshold >= 1 then
        error("saturationThreshold invalid value. Valid values 0 - 1")
    end
    if temperatureTarget < 2500 or temperatureTarget > 9000 then
        error("invalid temperature target")
    end

    reactor.updateReadings()
    updateDeltas()

    reactor.activate = comps.reactor.activateReactor
    reactor.shutdown = comps.reactor.stopReactor
    reactor.charge = comps.reactor.chargeReactor
    runTick()
end

init()