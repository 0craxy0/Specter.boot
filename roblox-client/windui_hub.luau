-- Specter interface powered by WindUI.
-- UI-only shell: Specter callbacks intentionally report status and do not perform
-- gameplay automation, injection, remote execution, or exploit actions.

local WindUI = _G.SpecterWindUI
if not WindUI then

    local ok, library = pcall(function()
        return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
    end)
    if not ok then
        error("Specter could not load WindUI: " .. tostring(library))
    end
    WindUI = library
end

local Hub = {}
Hub.__index = Hub

local DefaultCatalog = {
    Combat = {
        { Id = "aim", Name = "Aim Assist", Description = "Target assistance settings" },
        { Id = "trigger", Name = "Triggerbot", Description = "Trigger response settings" },
    },
    Movement = {
        { Id = "speed", Name = "Speed", Description = "Movement tuning" },
        { Id = "flight", Name = "Flight", Description = "Aerial movement tuning" },
    },
    Visuals = {
        { Id = "entities", Name = "Entity Overlay", Description = "Entity display settings" },
        { Id = "lighting", Name = "Lighting", Description = "Environment display settings" },
    },
    Utility = {
        { Id = "rejoin", Name = "Quick Rejoin", Description = "Reconnect utility" },
        { Id = "idle", Name = "Idle Guard", Description = "Idle prevention settings" },
    },
}

local function notify(title, content, severity)
    pcall(function()
        WindUI:Notify({ Title = title, Content = content, Duration = 3, Icon = severity == "error" and "triangle-alert" or "info" })
    end)
end

local function sortedKeys(value)
    local keys = {}
    for key in pairs(value) do table.insert(keys, key) end
    table.sort(keys)
    return keys
end

local function safeCallback(item, enabled)
    notify("Specter preview", string.format("%s %s. Specter uses a placeholder-only callback.", item.Name, enabled and "enabled" or "disabled"))
end

function Hub.new(options)
    options = options or {}
    local self = setmetatable({}, Hub)
    self.Catalog = options.Catalog or DefaultCatalog
    self.Options = options
    self.Enabled = {}
    self.Tabs = {}

    pcall(function() WindUI:SetNotificationLower(true) end)
    pcall(function() WindUI:AddTheme({
        Name = "Specter Midnight",
        Accent = Color3.fromHex("#8B5CF6"),
        Background = Color3.fromHex("#0B0A12"),
        Outline = Color3.fromHex("#302A46"),
        Text = Color3.fromHex("#F5F3FF"),
        Placeholder = Color3.fromHex("#918BA8"),
        Button = Color3.fromHex("#201A32"),
        Icon = Color3.fromHex("#C4B5FD"),
    }) end)

    self.Window = WindUI:CreateWindow({
        Title = options.Title or "Specter // Script Hub",
        Icon = "sparkles",
        Author = "Specter",
        Folder = "SpecterInterface",
        Theme = options.Theme or "Specter Midnight",
        Size = UDim2.fromOffset(760, 520),
        MinSize = Vector2.new(640, 420),
        MaxSize = Vector2.new(980, 720),
        ToggleKey = Enum.KeyCode.RightShift,
        Resizable = true,
        SideBarWidth = 190,
        SearchBar = true,
        User = { Enabled = true, Anonymous = true, Callback = function() notify("Profile", "Anonymous profile selected.") end },
    })

    self:buildHome()
    for _, category in ipairs(sortedKeys(self.Catalog)) do self:buildCategory(category, self.Catalog[category]) end
    self:buildSettings()
    notify("Specter ready", "Specter is loaded in safe placeholder mode.")
    return self
end

function Hub:buildHome()
    local tab = self.Window:Tab({ Title = "Specter Overview", Icon = "layout-dashboard" })
    self.Tabs.Overview = tab
    tab:Paragraph({ Title = "Specter Script Hub", Desc = "A polished WindUI catalog for organizing Specter modules.", Color = "Purple", Icon = "sparkles" })
    tab:Paragraph({ Title = "Specter safe mode", Desc = "Specter switches are placeholders. They only update status and show a notification.", Color = "Blue", Icon = "shield-check" })
    tab:Section({ Title = "Specter Session" })
    tab:Toggle({ Title = "Specter notifications", Desc = "Show Specter feedback when a placeholder is toggled.", Value = true, Flag = "SpecterNotifications", Callback = function(value) self.Notifications = value end })
    tab:Button({ Title = "Show Specter status", Desc = "Display the current Specter catalog summary.", Icon = "activity", Callback = function() notify("Specter status", self:summary()) end })
end

function Hub:buildCategory(category, items)
    local tab = self.Window:Tab({ Title = "Specter " .. category, Icon = category == "Combat" and "crosshair" or category == "Movement" and "move" or category == "Visuals" and "eye" or "wrench" })
    self.Tabs[category] = tab
    tab:Paragraph({ Title = "Specter " .. category .. " modules", Desc = "Specter catalog entries use safe placeholder callbacks.", Icon = "layers-3" })
    tab:Section({ Title = "Specter Modules" })
    for _, item in ipairs(items) do
        local flag = "SpecterModule_" .. tostring(item.Id)
        tab:Toggle({
            Title = item.Name,
            Desc = item.Description or "No description provided.",
            Icon = "box",
            Type = "Checkbox",
            Value = item.Enabled == true,
            Flag = flag,
            Callback = function(value)
                self.Enabled[item.Id] = value
                if self.Notifications ~= false then safeCallback(item, value) end
                if type(self.Options.OnToggle) == "function" then self.Options.OnToggle(item, value) end
            end,
        })
    end
end

function Hub:buildSettings()
    local tab = self.Window:Tab({ Title = "Specter Settings", Icon = "sliders-horizontal" })
    self.Tabs.Settings = tab
    tab:Section({ Title = "Specter Appearance" })
    tab:Dropdown({ Title = "Specter theme", Desc = "Choose the Specter interface theme.", Values = { "Specter Midnight", "Dark", "Light" }, Value = "Specter Midnight", Callback = function(value) pcall(function() WindUI:SetTheme(value) end) end })
    tab:Keybind({ Title = "Specter toggle key", Desc = "Key used to show or hide Specter.", Value = "RightShift", Callback = function(value) pcall(function() self.Window:SetToggleKey(Enum.KeyCode[value]) end) end })
    tab:Input({ Title = "Specter status label", Desc = "Optional label shown in the local Specter session.", Placeholder = "Specter ready", Callback = function(value) self.StatusLabel = value end })
    tab:Section({ Title = "Specter Configuration" })
    local config = self.Window.ConfigManager and self.Window.ConfigManager:CreateConfig("specter_profile")
    if config then
        tab:Button({ Title = "Save Specter configuration", Icon = "save", Callback = function() pcall(function() config:Save() end); notify("Specter configuration", "Specter settings saved locally.") end })
        tab:Button({ Title = "Load Specter configuration", Icon = "folder-open", Callback = function() pcall(function() config:Load() end); notify("Specter configuration", "Specter settings loaded locally.") end })
    end
end

function Hub:summary()
    local total, active = 0, 0
    for _, items in pairs(self.Catalog) do for _, item in ipairs(items) do total += 1; if self.Enabled[item.Id] then active += 1 end end end
    return string.format("Specter: %d modules available · %d active · %s", total, active, self.StatusLabel or "session online")
end

return Hub
