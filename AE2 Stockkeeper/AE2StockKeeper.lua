local configPath = "/home/config/AE2StockKeeper.config"
local craftingCheckInterval = 2.5

package.loaded.GUI = nil
package.loaded.doubleBuffering = nil
local GUI = require("GUI")
local buffer = require("doubleBuffering")
local math = require("math")
local table = require("table")

--------------------------------------------------------------------------------
local workspace = GUI.workspace()
-- Setup topbar GUI
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

topbar:setPosition(2, 1, topbar:addChild(GUI.text(1, 1, 0xFFFFFF, "AE2 Stock Keeper")))
local modeSwitch = topbar:setPosition(3, 1, topbar:addChild(
    GUI.button(1, 1, 10, 1, 0xe6d53e, 0x555555, 0x880000, 0xFFFFFF, "Add")))
local memory = topbar:setPosition(3, 1, topbar:addChild(GUI.text(1, 1, 0xFFFFFF, "")))
local clock = topbar:setPosition(3, 1, topbar:addChild(GUI.text(1, 1, 0xFFFFFF, "")))
local quitButton = topbar:setPosition(3, 1, topbar:addChild(
    GUI.button(1, 1, 1, 1, 0xb00707, 0xe6d5d5, 0x5e0505, 0xFFFFFF, "X")))
local cpus = topbar:setPosition(1, 1, topbar:addChild(GUI.text(1, 1, 0xFFFFFF, "")))
local jobs = topbar:setPosition(1, 1, topbar:addChild(GUI.text(1, 1, 0xFFFFFF, "")))
local lastChecked = topbar:setPosition(1, 1, topbar:addChild(GUI.text(1, 1, 0xFFFFFF, "")))

-- Setup body GUI
local body_layout = workspace:addChild(GUI.layout(1, 2, workspace.width, workspace.height - 1, 2, 1))
body_layout:setColumnWidth(1, GUI.SIZE_POLICY_ABSOLUTE, body_layout.width - 40)
body_layout:setColumnWidth(2, GUI.SIZE_POLICY_ABSOLUTE, 40)
body_layout:setDirection(1, 1, GUI.DIRECTION_VERTICAL)
body_layout:setDirection(2, 1, GUI.DIRECTION_VERTICAL)
body_layout:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_TOP)
body_layout:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_RIGHT, GUI.ALIGNMENT_VERTICAL_TOP)

local availableXSpace = body_layout.width - 40
local maxButtonsX = 2
local maxButtonsY = math.floor(body_layout.height / 1)

local buttons = {}
local grid = body_layout:addChild(GUI.layout(1, 1, availableXSpace, body_layout.height, maxButtonsX, maxButtonsY))
for x = 1, maxButtonsX do
    for y = 1, maxButtonsY do
        local buttonColor = (y % 2) == 0 and 0xFFE99C or 0xFFFFFF
        local button = grid:addChild(GUI.button(x, y, availableXSpace / 2, 1, buttonColor, 0x0C0C0C, 0x880000, 0xFFFFFF,
            string.format("Button %s,%s", x, y)))
        button.animated = false
        table.insert(buttons, grid:setPosition(x, y, button))

        grid:setDirection(x, y, GUI.DIRECTION_HORIZONTAL)
        grid:setAlignment(x, y, GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)
    end
end

-- Setup sidebar
local sidebar = body_layout:setPosition(2, 1, body_layout:addChild(GUI.container(1, 1, 40, body_layout.height)))
local prevBtn = sidebar:addChild(GUI.button(1, sidebar.height, 20, 1, 0xe6d53e, 0x555555, 0x880000, 0xFFFFFF,
    "Previous Page"))
local nextBtn = sidebar:addChild(GUI.button(21, sidebar.height, 20, 1, 0xe6d53e, 0x555555, 0x880000, 0xFFFFFF,
    "Next Page"))

-- Setup Activity History
sidebar:addChild(GUI.label(1, 1, sidebar.width, 1, 0xFFFFFF, "Activity History")):setAlignment(
    GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)
local history_panel = sidebar:addChild(GUI.container(1, 2, 40, 20))
local history = history_panel:addChild(GUI.textBox(1, 1, history_panel.width, history_panel.height, 0x0, 0x00c264, {},
    1, 1, 0))

-- Setup property panel GUI
local property_panel = sidebar:addChild(GUI.container(1, 23, 40, sidebar.height - 22))
property_panel:addChild(GUI.label(1, 1, sidebar.width, 1, 0xFFFFFF, "Properties")):setAlignment(
    GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)
property_panel:addChild(GUI.label(1, 3, property_panel.width, 1, 0xFFFFFF, "Item Label")):setAlignment(
    GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)
property_panel:addChild(GUI.panel(2, 4, property_panel.width - 2, 1, 0x96a1b3))
local itemLabel = property_panel:addChild(GUI.label(2, 4, property_panel.width - 2, 1, 0x0, "Test Item")):setAlignment(
    GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)

property_panel:addChild(GUI.label(1, 5, property_panel.width, 1, 0xFFFFFF, "Item ID")):setAlignment(
    GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)
property_panel:addChild(GUI.panel(2, 6, property_panel.width - 2, 1, 0x96a1b3))
local itemId = property_panel:addChild(GUI.label(1, 6, property_panel.width - 2, 1, 0x0, "minecraft:test"))
    :setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)

property_panel:addChild(GUI.label(1, 7, property_panel.width, 1, 0xFFFFFF, "Items In Storage")):setAlignment(
    GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)
property_panel:addChild(GUI.panel(2, 8, property_panel.width - 2, 1, 0x96a1b3))
local itemCount = property_panel:addChild(GUI.label(1, 8, property_panel.width - 2, 1, 0x0, "0")):setAlignment(
    GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)

property_panel:addChild(GUI.label(1, 9, property_panel.width, 1, 0xFFFFFF, "Item Craftable")):setAlignment(
    GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)
property_panel:addChild(GUI.panel(2, 10, property_panel.width - 2, 1, 0x96a1b3))
local itemCraftable = property_panel:addChild(GUI.label(1, 10, property_panel.width - 2, 1, 0x0, "No")):setAlignment(
    GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)

local stockKeepSwitch = property_panel:addChild(GUI.switchAndLabel(3, 12, property_panel.width - 2, 5, 0x66DB80,
    0x1D1D1D, 0xEEEEEE, 0xFFFFFF, "Enable Stockeeping", false))

property_panel:addChild(GUI.label(1, 13, property_panel.width, 1, 0xFFFFFF, "Amount to keep in stock")):setAlignment(
    GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)
local stockKeepInput = property_panel:addChild(GUI.input(2, 14, property_panel.width - 2, 3, 0xEEEEEE, 0x555555,
    0x999999, 0xFFFFFF, 0x2D2D2D, "0"))
stockKeepInput.hidden = true

property_panel.hidden = true
--------------------------------------------------------------------------------
local component = require("component")
local computer = require("computer")
local gpu = component.gpu
local serialization = require("serialization")
local io = require("io")
local filesystem = require("filesystem")
local event = require("event")

local originalBg = {gpu.getBackground()}
local originalFg = {gpu.getForeground()}

local AE = component.me_controller
local CCPUCount = 0
local CCPUBusy = 0
local CraftableStacks = {}
local CurrentlySelected = nil
local config = {}
local configKeyIndex = {}
local configBacking = {}
local addMode = false
local curPage = 1
local activeJobs = {}
local activeJobsIndex = {}

setmetatable(config, {
    __newindex = function(tbl, key, value)
        if (value == nil) then
            local old = configBacking[key]
            if old ~= nil then
                table.remove(configKeyIndex, old.index)
            end
        else
            table.insert(configKeyIndex, key)
            value.index = #configKeyIndex
        end
        configBacking[key] = value
    end,
    __len = function(tbl)
        return #configKeyIndex
    end,
    __ipairs = function(tbl)
        local function iterator(tbl, i)
            i = i + 1
            local key = configKeyIndex[i]
            local v = configBacking[key]
            if v ~= nil then
                return i, v
            end
        end

        return iterator, tbl, 0
    end,
    __index = function(tbl, key)
        local direct = configBacking[key]
        if direct then return direct end

        local indexedKey = configKeyIndex[key]
        if indexedKey == nil then
            return nil
        else
            return configBacking[indexedKey]
        end
    end
})

function saveConfig()
    local configString = serialization.serialize(configBacking)
    local stream = io.open(configPath, "w")
    stream:write(configString)
    stream:close()
end

function loadConfig()
    if filesystem.exists(configPath) then
        local stream = io.open(configPath, "r")
        local configString = stream:read("*a")
        stream:close()
        configBacking = serialization.unserialize(configString)
    end
    configEntries = 0

    for k, v in pairs(configBacking) do
        table.insert(configKeyIndex, k)
        v.index = #configKeyIndex
    end
end

function updatePagination()
    local maxPages
    if addMode then
        maxPages = math.ceil(#CraftableStacks / #buttons)
    else
        maxPages = math.ceil(#config / #buttons)
    end

    if maxPages == 1 then
        nextBtn.hidden = true
        prevBtn.hidden = true
    else
        local prevPage = curPage - 1
        local nextPage = curPage + 1

        if prevPage <= 0 then
            prevBtn.hidden = true
        else
            prevBtn.hidden = false
            prevBtn.text = string.format("< Page %s", prevPage)
        end

        if nextPage > maxPages then
            nextBtn.hidden = true
        else
            nextBtn.hidden = false
            nextBtn.text = string.format("Page %s >", nextPage)
        end
    end
end

function loadAECraftables()
    CraftableStacks = {}
    local result, craftables = pcall(AE.getCraftables)
    if not result then return end
    for i, craft in ipairs(craftables) do
        table.insert(CraftableStacks, craft.getItemStack())
    end
end

function updateAEStatus()
    local result, cpus = pcall(AE.getCpus)
    if not result then return end
    CCPUCount = #cpus
    CCPUBusy = 0
    for k, v in ipairs(cpus) do
        if v.busy then
            CCPUBusy = CCPUBusy + 1
        end
    end

end

function parseItemId(itemId)
    return itemId:match("(.+):(.+)")
end

function showStackInProperties(stack)
    if stack ~= nil then
        local result, ret = pcall(function() 
            return AE.getItemsInNetwork({
                label = stack.label,
                name = stack.name
            })[1]
        end)
        if not result then return end

        CurrentlySelected = ret
        itemLabel.text = CurrentlySelected.label
        itemId.text = CurrentlySelected.name

        local stacks = math.floor(CurrentlySelected.size / CurrentlySelected.maxSize)
        local loose = math.floor(CurrentlySelected.size % CurrentlySelected.maxSize)
        local stackSize = math.floor(CurrentlySelected.maxSize)

        if stacks > 0 then
            itemCount.text = string.format("%s x %s + %s", stacks, stackSize, loose)
        else
            itemCount.text = tostring(loose)
        end

        if CurrentlySelected.isCraftable then
            itemCraftable.text = "Yes"
        else
            itemCraftable.text = "No"
        end

        local configured = config[getConfigKey(stack.name, stack.label)]
        stockKeepSwitch.switch:setState(configured ~= nil)
        stockKeepInput.hidden = configured == nil
        if configured ~= nil then
            stockKeepInput.text = tostring(configured.stockLevel)
        else
            stockKeepInput.text = "0"
        end

        property_panel.hidden = false
    else
        stockKeepSwitch.switch:setState(false)
        stockKeepInput.text = tostring(0)
        property_panel.hidden = true
    end
end

function updateTopBar()
    cpus.text = string.format("C-CPU: %s/%s", CCPUBusy, CCPUCount)
    clock.text = os.date("%I:%M %p")
    local memTotal = computer.totalMemory()
    local memFree = computer.freeMemory()
    local memUsed = memTotal - memFree
    local memUsage = (memUsed / memTotal) * 100
    memUsage = math.floor(memUsage + 0.5)
    memory.text = string.format("RAM: %s%%", memUsage)
    jobs.text = string.format("Jobs: %s", #activeJobs)
end

function resetBody()
    for i, button in ipairs(buttons) do
        button.hidden = true
        button.onTouch = nil
    end
end

function getConfigKey(itemId, itemLabel)
    return itemId .. "[" .. itemLabel .. "]"
end

function drawAECraftables(page)
    if #CraftableStacks == 0 then
        loadAECraftables()
    end

    resetBody()
    local perPage = #buttons
    local startIdx = (page - 1) * perPage

    if startIdx > #CraftableStacks then
        return
    end

    for i = 1, #buttons do
        local idx = startIdx + i
        local stack = CraftableStacks[idx]

        if stack == nil then
            break
        end

        local namespace, id = parseItemId(stack.name)
        buttons[i].text = string.format("%s (%s)", stack.label, namespace)
        buttons[i].hidden = false
        buttons[i].onTouch = function()
            showStackInProperties(config[getConfigKey(stack.name, stack.label)] or stack)
        end
        buttons[i]:draw()
    end
    curPage = page
    updatePagination()
end

function drawConfigured(page)
    resetBody()
    local perPage = #buttons
    local startIdx = (page - 1) * perPage

    if startIdx > #config then
        return
    end

    for i = 1, #buttons do
        local idx = startIdx + i
        local entry = config[idx]

        if entry ~= nil then
            local namespace, id = parseItemId(entry.name)
            buttons[i].text = string.format("%s of %s (%s)", tostring(entry.stockLevel), entry.label, namespace)
            buttons[i].hidden = false
            buttons[i].onTouch = function()
                showStackInProperties(entry)
            end
            buttons[i]:draw()
        end
    end
    curPage = page
    updatePagination()
end

function addHistory(str)
    table.insert(history.lines, str)
    if #(history.lines) > 100 then
        table.remove(history.lines, 1)
    end
    history:scrollToEnd()
end

function cleanCraftingJobs()
    local newTable = {}

    for i, job in ipairs(activeJobs) do
        if not job.completed then
            table.insert(newTable, job)
            activeJobsIndex[job.configKey] = #newTable
        end
    end

    activeJobs = newTable
end

function updateCraftingJobs()
    for i, job in ipairs(activeJobs) do
        if not job.completed then
            local done = job.job.isDone()
            local cancel = job.job.isCanceled()
            if done then
                addHistory("Crafted: " .. job.description)
            end
            if cancel then
                addHistory("Cancelled: " .. job.description)
            end
            if done or cancel then
                job.completed = true
                activeJobsIndex[job.configKey] = nil
            end
        end
    end
    
    cleanCraftingJobs()
end

local backgroundTasks = {}
function startAEMonitoring()
    addHistory("Starting AE monitoring jobs")
    local index = 1
    function doCraftingCheck()
        if index > #config then
            index = 1
        end

        local toCheck = config[index]
        local configKey = getConfigKey(toCheck.name, toCheck.label)
        local namespace, id = parseItemId(toCheck.name)
        lastChecked.text = "Checked: " .. (string.format("%s (%s)", toCheck.label, namespace):sub(1, 30))
        index = index + 1

        function getAEItem()
            local items = AE.getItemsInNetwork({
                label = toCheck.label,
                name = toCheck.name
            })
            return items[1]
        end

        local status, ret = pcall(getAEItem)

        if status and ret ~= nil and ret.isCraftable and activeJobsIndex[configKey] == nil then
            local item = ret
            local missing = math.ceil(math.max(toCheck.stockLevel - item.size, 0))
            if missing > 0 and CCPUBusy < CCPUCount then
                function requestCrafting()
                    local craftable = AE.getCraftables({
                        label = item.label,
                        name = item.name
                    })[1]
                    if craftable ~= nil then return craftable.request(missing, false) else return nil end
                end

                local result, request = pcall(requestCrafting)

                if not result then
                    return
                end

                local description = string.format("%s of %s (%s)", missing, item.label, item.name)
                if request ~= nil and not request.isCanceled() then
                    addHistory(string.format("Requested: " .. description))
                    table.insert(activeJobs, {
                        job=request,
                        configKey=configKey,
                        description=description
                    })
                    activeJobsIndex[configKey] = #activeJobs
                else
                    addHistory(string.format("Failed to request: " .. description))
                end
            end
        end
    end

    table.insert(backgroundTasks, event.timer(1, updateCraftingJobs, math.huge))
    table.insert(backgroundTasks, event.timer(craftingCheckInterval, doCraftingCheck, math.huge))
end

quitButton.onTouch = function()
    workspace:stop()
    gpu.setBackground(table.unpack(originalBg))
    gpu.setForeground(table.unpack(originalFg))
    for i, timer in ipairs(backgroundTasks) do
        event.cancel(timer)
    end
    require("term").clear()
    os.exit()
end

modeSwitch.onTouch = function()
    addMode = not addMode
    curPage = 1
    if addMode then
        modeSwitch.text = "Cancel"
        drawAECraftables(1)
    else
        modeSwitch.text = "Add"
        drawConfigured(1)
        CraftableStacks = {}
    end
end

stockKeepSwitch.switch.onStateChanged = function()
    stockKeepInput.hidden = not stockKeepSwitch.switch.state
    if not stockKeepSwitch.switch.state then
        config[getConfigKey(CurrentlySelected.name, CurrentlySelected.label)] = nil
        showStackInProperties(nil)
        if not addMode then
            drawConfigured(curPage)
            CurrentlySelected = nil
        end
        saveConfig()
    end
end

stockKeepInput.validator = function(value)
    return tonumber(value, 10) ~= nil
end

stockKeepInput.onInputFinished = function()
    local value = tonumber(stockKeepInput.text, 10)
    local configKey = getConfigKey(CurrentlySelected.name, CurrentlySelected.label)
    if value == 0 then
        config[configKey] = nil
    else
        if config[configKey] == nil then
            config[configKey] = {
                label = CurrentlySelected.label,
                name = CurrentlySelected.name
            }
        end
        config[configKey].stockLevel = value
    end
    if not addMode then
        drawConfigured(curPage)
    end
    saveConfig()
end

prevBtn.onTouch = function()
    if addMode then
        drawAECraftables(curPage - 1)
    else
        drawConfigured(curPage - 1)
    end
end

nextBtn.onTouch = function()
    if addMode then
        drawAECraftables(curPage + 1)
    else
        drawConfigured(curPage + 1)
    end
end

workspace.eventHandler = function(workspace, object, event, ...)
    updateTopBar()
    updateAEStatus()
    workspace:draw()
end
-- Start the loop
--------------------------------------------------------------------------------
local screenX, screenY = gpu.getResolution()
gpu.fill(1, 1, screenX, screenY, ' ')
loadConfig()
drawConfigured(1)
startAEMonitoring()
addHistory(string.format("Started up. Loaded %s config entries.", #config))
workspace:start(1)
