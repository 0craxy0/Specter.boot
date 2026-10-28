local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Specter = {}
Specter.__index = Specter

Specter.Catalog = {
	Combat = { { Id = "aim", Name = "Aim Assist", Description = "Target assistance settings" }, { Id = "trigger", Name = "Triggerbot", Description = "Trigger response settings" } },
	Movement = { { Id = "speed", Name = "Speed", Description = "Movement tuning" }, { Id = "flight", Name = "Flight", Description = "Aerial movement tuning" } },
	Visuals = { { Id = "entities", Name = "Entity Overlay", Description = "Entity display settings" }, { Id = "lighting", Name = "Lighting", Description = "Environment display settings" } },
	Utility = { { Id = "rejoin", Name = "Quick Rejoin", Description = "Reconnect utility" }, { Id = "idle", Name = "Idle Guard", Description = "Idle prevention settings" } },
}

local Theme = { Background = Color3.fromRGB(9, 10, 16), Surface = Color3.fromRGB(20, 22, 34), Hover = Color3.fromRGB(30, 33, 50), Text = Color3.fromRGB(240, 241, 255), Muted = Color3.fromRGB(145, 150, 177), Accent = Color3.fromRGB(126, 84, 255), AccentB = Color3.fromRGB(47, 190, 255), RowHeight = 58, PoolSize = 10 }

local function new(class, props)
	local object = Instance.new(class)
	for key, value in pairs(props) do object[key] = value end
	return object
end
local function corner(parent, radius) return new("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent }) end
local function fade(object, props, time) TweenService:Create(object, TweenInfo.new(time or .16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play() end

local function flatten(catalog)
	local rows, categories = {}, {}
	for name in pairs(catalog) do table.insert(categories, name) end
	table.sort(categories)
	for _, category in ipairs(categories) do
		table.insert(rows, { Kind = "category", Name = category })
		for _, data in ipairs(catalog[category]) do table.insert(rows, { Kind = "script", Category = category, Data = data }) end
	end
	return rows, categories
end

function Specter.new(options)
	local self = setmetatable({}, Specter)
	self.Catalog = options and options.Catalog or Specter.Catalog
	self.OnToggle = options and options.OnToggle or function() end
	self.Rows, self.Categories = flatten(self.Catalog)
	self.Filtered = self.Rows
	self.Pool, self.Offset = {}, 0
	self:Build(options and options.Parent)
	return self
end

function Specter:Build(parent)
	parent = parent or Players.LocalPlayer:WaitForChild("PlayerGui")
	self.Gui = new("ScreenGui", { Name = "SpecterInterface", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parent })
	local glow = new("Frame", { BackgroundColor3 = Theme.Accent, BackgroundTransparency = .85, BorderSizePixel = 0, AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(720, 720), Parent = self.Gui })
	corner(glow, 999)
	new("UIGradient", { Color = ColorSequence.new(Theme.Accent, Theme.AccentB), Rotation = 35, Parent = glow })
	local root = new("Frame", { BackgroundColor3 = Theme.Background, BorderSizePixel = 0, AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(760, 500), Parent = self.Gui })
	corner(root, 16); new("UIStroke", { Color = Color3.fromRGB(76, 69, 112), Transparency = .4, Parent = root })
	local side = new("Frame", { BackgroundColor3 = Color3.fromRGB(14, 15, 24), BorderSizePixel = 0, Size = UDim2.fromOffset(180, 500), Parent = root })
	corner(side, 16)
	new("TextLabel", { BackgroundTransparency = 1, Text = "SPECTER", Font = Enum.Font.GothamBold, TextSize = 21, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(24, 22), Size = UDim2.fromOffset(130, 28), Parent = side })
	new("TextLabel", { BackgroundTransparency = 1, Text = "SPECTER INTERFACE", Font = Enum.Font.GothamMedium, TextSize = 9, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(25, 49), Size = UDim2.fromOffset(130, 15), Parent = side })
	local nav = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 94), Size = UDim2.fromOffset(152, 380), Parent = side })
	new("UIListLayout", { Padding = UDim.new(0, 7), Parent = nav })
	for _, name in ipairs(self.Categories) do
		local button = new("TextButton", { AutoButtonColor = false, BackgroundColor3 = Theme.Hover, BackgroundTransparency = 1, BorderSizePixel = 0, Text = "   " .. name, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(152, 34), Parent = nav })
		corner(button, 7)
		button.MouseEnter:Connect(function() if self.Category ~= name then fade(button, { BackgroundTransparency = 0, TextColor3 = Theme.Text }) end end)
		button.MouseLeave:Connect(function() if self.Category ~= name then fade(button, { BackgroundTransparency = 1, TextColor3 = Theme.Muted }) end end)
		button.MouseButton1Click:Connect(function() self:ShowCategory(name) end)
	end
	local content = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(206, 0), Size = UDim2.fromOffset(530, 500), Parent = root })
	self.Title = new("TextLabel", { BackgroundTransparency = 1, Text = "SCRIPT CATALOG", Font = Enum.Font.GothamBold, TextSize = 19, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 24), Size = UDim2.fromOffset(250, 28), Parent = content })
	self.Status = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(1, 51), Size = UDim2.fromOffset(230, 16), Parent = content })
	local search = new("TextBox", { BackgroundColor3 = Theme.Surface, BorderSizePixel = 0, ClearTextOnFocus = false, PlaceholderText = "Search modules...", PlaceholderColor3 = Theme.Muted, Text = "", TextColor3 = Theme.Text, Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(316, 27), Size = UDim2.fromOffset(205, 35), Parent = content })
	corner(search, 8); new("UIPadding", { PaddingLeft = UDim.new(0, 12), Parent = search })
	self.View = new("ScrollingFrame", { Active = true, BackgroundColor3 = Theme.Surface, BorderSizePixel = 0, CanvasSize = UDim2.new(), ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent, Position = UDim2.fromOffset(0, 91), Size = UDim2.fromOffset(530, 390), Parent = content })
	corner(self.View, 11)
	self.View:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self.Offset = self.View.CanvasPosition.Y; self:Render() end)
	search:GetPropertyChangedSignal("Text"):Connect(function() self:Search(search.Text) end)
	for _ = 1, Theme.PoolSize do table.insert(self.Pool, self:CreateRow()) end
	self:ShowCategory(self.Categories[1])
end

function Specter:CreateRow()
	local row = new("TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(25, 28, 42), BorderSizePixel = 0, Text = "", Visible = false, Size = UDim2.fromOffset(510, Theme.RowHeight - 7), Parent = self.View })
	corner(row, 9)
	row.NameLabel = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamSemibold, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 9), Size = UDim2.fromOffset(280, 19), Parent = row })
	row.Detail = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 29), Size = UDim2.fromOffset(300, 15), Parent = row })
	row.Toggle = new("Frame", { BackgroundColor3 = Color3.fromRGB(58, 61, 76), BorderSizePixel = 0, Position = UDim2.fromOffset(441, 15), Size = UDim2.fromOffset(43, 22), Parent = row }); corner(row.Toggle, 99)
	row.Knob = new("Frame", { BackgroundColor3 = Color3.fromRGB(220, 221, 232), BorderSizePixel = 0, Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(16, 16), Parent = row.Toggle }); corner(row.Knob, 99)
	row.MouseButton1Click:Connect(function() local item = row.Item; if item then item.Enabled = not item.Enabled; self:PaintToggle(row, item.Enabled); self.OnToggle(item, item.Enabled) end end)
	row.MouseEnter:Connect(function() if row.Visible and row.Item then fade(row, { BackgroundColor3 = Theme.Hover }) end end)
	row.MouseLeave:Connect(function() if row.Visible and row.Item then fade(row, { BackgroundColor3 = Color3.fromRGB(25, 28, 42) }) end end)
	return row
end

function Specter:PaintToggle(row, enabled)
	fade(row.Toggle, { BackgroundColor3 = enabled and Theme.Accent or Color3.fromRGB(58, 61, 76) })
	fade(row.Knob, { Position = enabled and UDim2.fromOffset(24, 3) or UDim2.fromOffset(3, 3) })
end
function Specter:Render()
	local first = math.max(1, math.floor(self.Offset / Theme.RowHeight) + 1)
	for i, row in ipairs(self.Pool) do
		local entry, index = self.Filtered[first + i - 1], first + i - 1
		row.Visible = entry ~= nil
		if entry then
			row.Position = UDim2.fromOffset(10, (index - 1) * Theme.RowHeight + 8)
			if entry.Kind == "category" then row.Item = nil; row.NameLabel.Text = entry.Name:upper(); row.NameLabel.Position = UDim2.fromOffset(16, 17); row.Detail.Visible = false; row.Toggle.Visible = false; row.BackgroundColor3 = Color3.fromRGB(18, 20, 31)
			else row.Item = entry.Data; row.NameLabel.Text = entry.Data.Name; row.NameLabel.Position = UDim2.fromOffset(16, 9); row.Detail.Text = entry.Data.Description or ""; row.Detail.Visible = true; row.Toggle.Visible = true; self:PaintToggle(row, entry.Data.Enabled == true) end
		end
	end
	self.Status.Text = string.format("%d MODULES AVAILABLE", #self.Filtered)
end
function Specter:Refresh()
	self.View.CanvasSize = UDim2.fromOffset(0, #self.Filtered * Theme.RowHeight + 8)
	self.View.CanvasPosition = Vector2.new(); self.Offset = 0; self:Render()
end
function Specter:ShowCategory(category)
	self.Category, self.Filtered = category, {}
	for _, row in ipairs(self.Rows) do if row.Kind == "category" and row.Name == category or row.Kind == "script" and row.Category == category then table.insert(self.Filtered, row) end end
	self.Title.Text = category:upper() .. " MODULES"; self:Refresh()
end
function Specter:Search(query)
	query = string.lower(query); if query == "" then return self:ShowCategory(self.Categories[1]) end
	self.Filtered, self.Category = {}, nil
	for _, row in ipairs(self.Rows) do if row.Kind == "script" and string.find(string.lower(row.Data.Name .. " " .. (row.Data.Description or "") .. " " .. row.Category), query, 1, true) then table.insert(self.Filtered, row) end end
	self.Title.Text = "SEARCH RESULTS"; self:Refresh()
end
function Specter:Add(category, data)
	self.Catalog[category] = self.Catalog[category] or {}; table.insert(self.Catalog[category], data); self.Rows, self.Categories = flatten(self.Catalog); self:ShowCategory(category)
end
function Specter:Destroy() if self.Gui then self.Gui:Destroy() end end

return Specter
