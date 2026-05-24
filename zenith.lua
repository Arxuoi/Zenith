--[[
    ZenithUI Library

    A simple, non‑OOP user interface library for Roblox that focuses on a modern,
    minimalist aesthetic. It exposes a procedural API through plain tables, avoiding
    complex class hierarchies and metatables.  The library relies on Roblox
    primitives such as `Instance`, `TweenService`, `UserInputService`, and
    `HttpService` to build a responsive, dark‑themed interface that works on both
    PC and mobile.  Developers can customize theme colours and save/load
    configurations as JSON using executor‑provided filesystem functions when
    available.

    Usage example:

        local ZenithUI = loadstring(game:HttpGet("https://your.domain/zenithui.lua"))()
        local window = ZenithUI:CreateWindow({
            Title = "Demo",
            AccentColor = Color3.fromRGB(120, 90, 255),
            Size = UDim2.new(0, 600, 0, 400)
        })
        local mainTab = window:AddTab({Name = "Main"})
        local section = mainTab:AddSection({Name = "Controls"})
        section:AddButton({Name = "Click Me", Callback = function() print("Clicked") end})
        -- ... (see example at bottom for more)

    The library returns a table with `CreateWindow`, `Notify`, `SaveConfig`,
    `LoadConfig`, and `Destroy` functions.
--]]

local ZenithUI = {}

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- Default theme colours
local DefaultTheme = {
    Background  = Color3.fromRGB(24, 24, 24), -- main window background
    Panel       = Color3.fromRGB(32, 32, 32), -- sidebar and panel backgrounds
    Section     = Color3.fromRGB(40, 40, 40), -- section background
    Outline     = Color3.fromRGB(50, 50, 50), -- outlines/borders
    Accent      = Color3.fromRGB(104, 117, 245), -- default accent (blue/purple)
    Text        = Color3.fromRGB(245, 245, 245), -- general text colour
    SubText     = Color3.fromRGB(180, 180, 180)  -- secondary text colour
}

-- Helper to clone a table (shallow copy)
local function CloneTable(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

-- Helper to apply theme overrides
local function ResolveTheme(overrides)
    local theme = CloneTable(DefaultTheme)
    if overrides then
        for k, v in pairs(overrides) do
            if theme[k] ~= nil and typeof(v) == "Color3" then
                theme[k] = v
            end
        end
    end
    return theme
end

-- Helper to create a tween and play it
local function Tween(object, properties, duration, easingStyle, easingDirection)
    local info = TweenInfo.new(
        duration or 0.25,
        easingStyle or Enum.EasingStyle.Quad,
        easingDirection or Enum.EasingDirection.Out
    )
    local t = TweenService:Create(object, info, properties)
    t:Play()
    return t
end

-- Determine appropriate write/read functions for saving configs.
local function getFSFunctions()
    local env = getfenv and getfenv(0) or _ENV or {}
    -- Many executors expose writefile/readfile through the global environment or via the 'syn' table.
    local writeFn = env.writefile or (env.syn and env.syn.writefile) or env.writeFile
    local readFn  = env.readfile  or (env.syn and env.syn.readfile)  or env.readFile
    return writeFn, readFn
end

-- Returns the local player for convenience
local function GetLocalPlayer()
    return Players.LocalPlayer
end

-- Creates a round‑cornered frame with optional shadow
local function CreateContainer(parent, position, size, colour, transparency, cornerRadius)
    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = colour
    frame.BackgroundTransparency = transparency or 0
    frame.BorderSizePixel = 0
    frame.Position = position or UDim2.new()
    frame.Size = size or UDim2.new()
    frame.Parent = parent
    if cornerRadius then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, cornerRadius)
        corner.Parent = frame
    end
    return frame
end

-- Creates a drop shadow behind a UI element
local function AttachShadow(frame)
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Position = UDim2.new(0.5, 0, 0.5, 4)
    shadow.Size = UDim2.new(1, 8, 1, 8)
    shadow.ZIndex = frame.ZIndex - 1
    shadow.Image = "rbxassetid://1316045217"
    shadow.ImageColor3 = Color3.new(0, 0, 0)
    shadow.ImageTransparency = 0.7
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10, 10, 118, 118)
    shadow.Parent = frame
    return shadow
end

-- Helper to handle dragging of the window
local function MakeDraggable(frame, dragArea)
    local dragging
    local dragInput
    local startPos
    local startOffset
    local function onInputBegan(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startPos = input.Position
            startOffset = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end
    local function onInputChanged(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - startPos
            frame.Position = UDim2.new(startOffset.X.Scale, startOffset.X.Offset + delta.X,
                                       startOffset.Y.Scale, startOffset.Y.Offset + delta.Y)
        end
    end
    dragArea.InputBegan:Connect(onInputBegan)
    dragArea.InputChanged:Connect(onInputChanged)
end

-- Primary API: Create a new window
function ZenithUI:CreateWindow(options)
    options = options or {}
    local title = options.Title or "ZenithUI"
    local size = options.Size or UDim2.new(0, 600, 0, 400)
    local theme = ResolveTheme({ Accent = options.AccentColor })

    -- Create the ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = "ZenithUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = game:GetService("CoreGui") or GetLocalPlayer():WaitForChild("PlayerGui")

    -- Main container with rounded corners and shadow
    local window = CreateContainer(gui, UDim2.new(0.5, -size.X.Offset/2, 0.5, -size.Y.Offset/2), size, theme.Background, 0, 8)
    window.Name = "MainWindow"
    window.ClipsDescendants = false
    window.ZIndex = 10
    AttachShadow(window)

    -- Top bar
    local topBar = CreateContainer(window, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 36), theme.Panel, 0, 8)
    topBar.Name = "TopBar"
    topBar.ZIndex = 11
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0, 12, 0, 0)
    titleLabel.Size = UDim2.new(1, -60, 1, 0)
    titleLabel.Font = Enum.Font.GothamMedium
    titleLabel.Text = title
    titleLabel.TextColor3 = theme.Text
    titleLabel.TextSize = 16
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = topBar

    -- Minimize button
    local minimize = Instance.new("ImageButton")
    minimize.Name = "Minimize"
    minimize.Size = UDim2.new(0, 20, 0, 20)
    minimize.Position = UDim2.new(1, -32, 0.5, -10)
    minimize.BackgroundTransparency = 1
    minimize.Image = "rbxassetid://7072725343" -- simple minus icon
    minimize.ImageColor3 = theme.Text
    minimize.Parent = topBar

    -- Search box
    local searchBox = Instance.new("TextBox")
    searchBox.Name = "SearchBox"
    searchBox.BackgroundColor3 = theme.Section
    searchBox.Position = UDim2.new(1, -200, 0.5, -14)
    searchBox.Size = UDim2.new(0, 150, 0, 24)
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextColor3 = theme.Text
    searchBox.TextSize = 14
    searchBox.Text = ""
    searchBox.PlaceholderText = "Search..."
    searchBox.PlaceholderColor3 = theme.SubText
    searchBox.BorderSizePixel = 0
    local searchCorner = Instance.new("UICorner")
    searchCorner.CornerRadius = UDim.new(0, 6)
    searchCorner.Parent = searchBox
    searchBox.Parent = topBar

    -- Sidebar for tabs
    local sidebar = CreateContainer(window, UDim2.new(0, 0, 0, 36), UDim2.new(0, 150, 1, -36), theme.Panel, 0, 8)
    sidebar.Name = "Sidebar"
    sidebar.ZIndex = 11
    local sidebarList = Instance.new("UIListLayout")
    sidebarList.Padding = UDim.new(0, 0)
    sidebarList.SortOrder = Enum.SortOrder.LayoutOrder
    sidebarList.Parent = sidebar

    -- Tab content holder
    local tabHolder = CreateContainer(window, UDim2.new(0, 150, 0, 36), UDim2.new(1, -150, 1, -36), theme.Background, 0, 0)
    tabHolder.Name = "TabHolder"
    tabHolder.ClipsDescendants = true
    tabHolder.ZIndex = 10

    -- Hide/show content when minimized
    local minimized = false
    local function toggleMinimize()
        minimized = not minimized
        local endSize = minimized and UDim2.new(size.X.Scale, size.X.Offset, 0, 36) or size
        Tween(window, { Size = endSize }, 0.25)
        -- Hide content when minimized
        tabHolder.Visible = not minimized
        sidebar.Visible = not minimized
        searchBox.Visible = not minimized
    end
    minimize.MouseButton1Click:Connect(toggleMinimize)

    -- Dragging behaviour
    MakeDraggable(window, topBar)

    -- Data structures to hold tabs and search mapping
    local windowObject = {}
    local tabs = {}
    local allElements = {} -- maps element text to a list of UI objects for searching

    -- Helper to register searchable element
    local function registerSearch(itemName, object)
        local key = itemName:lower()
        if not allElements[key] then
            allElements[key] = {}
        end
        table.insert(allElements[key], object)
    end

    -- Updates search results by hiding or showing elements whose names match search
    local function updateSearch()
        local query = searchBox.Text:lower()
        if query == "" then
            -- Show all
            for _, elements in pairs(allElements) do
                for _, obj in pairs(elements) do
                    if obj then obj.Visible = true end
                end
            end
        else
            -- Hide all first
            for _, elements in pairs(allElements) do
                for _, obj in pairs(elements) do
                    if obj then obj.Visible = false end
                end
            end
            -- Show those matching query substring
            for key, elements in pairs(allElements) do
                if key:find(query, 1, true) then
                    for _, obj in pairs(elements) do
                        if obj then obj.Visible = true end
                    end
                end
            end
        end
    end
    searchBox:GetPropertyChangedSignal("Text"):Connect(updateSearch)

    -- Select tab function
    local currentTabIndex = 1
    local function selectTab(index)
        currentTabIndex = index
        for i, tab in ipairs(tabs) do
            local selected = (i == index)
            tab.Button.BackgroundColor3 = selected and theme.Accent or theme.Panel
            tab.Content.Visible = selected
        end
    end

    -- AddTab API
    function windowObject:AddTab(tabOptions)
        tabOptions = tabOptions or {}
        local tabName = tabOptions.Name or ("Tab" .. tostring(#tabs + 1))
        -- Create tab button
        local button = Instance.new("TextButton")
        button.Name = "TabButton_" .. tabName
        button.Parent = sidebar
        button.BackgroundColor3 = #tabs == 0 and theme.Accent or theme.Panel
        button.BorderSizePixel = 0
        button.Size = UDim2.new(1, 0, 0, 32)
        button.Text = tabName
        button.TextColor3 = theme.Text
        button.TextSize = 15
        button.Font = Enum.Font.Gotham
        button.AutoButtonColor = false
        -- Hover effect
        button.MouseEnter:Connect(function()
            if tabs[currentTabIndex] and tabs[currentTabIndex].Button ~= button then
                Tween(button, { BackgroundColor3 = theme.Section }, 0.15)
            end
        end)
        button.MouseLeave:Connect(function()
            if tabs[currentTabIndex] and tabs[currentTabIndex].Button ~= button then
                Tween(button, { BackgroundColor3 = theme.Panel }, 0.15)
            end
        end)
        -- Tab content frame
        local content = Instance.new("ScrollingFrame")
        content.Name = "TabContent_" .. tabName
        content.Parent = tabHolder
        content.BackgroundColor3 = theme.Background
        content.BorderSizePixel = 0
        content.Size = UDim2.new(1, 0, 1, 0)
        content.Visible = (#tabs == 0)
        content.CanvasSize = UDim2.new(0, 0, 0, 0)
        content.ScrollBarThickness = 4
        content.ScrollBarImageColor3 = theme.Accent
        content.ZIndex = 10
        -- Layout for sections in tab
        local sectionList = Instance.new("UIListLayout")
        sectionList.Parent = content
        sectionList.SortOrder = Enum.SortOrder.LayoutOrder
        sectionList.Padding = UDim.new(0, 10)

        -- Tab object to return
        local tabObject = {}
        tabObject.Button = button
        tabObject.Content = content
        tabObject.Sections = {}

        -- Section creation
        function tabObject:AddSection(secOptions)
            secOptions = secOptions or {}
            local sectionName = secOptions.Name or ("Section" .. tostring(#tabObject.Sections + 1))
            -- Section container
            local sectionFrame = CreateContainer(content, UDim2.new(0, 10, 0, 0), UDim2.new(1, -20, 0, 0), theme.Section, 0, 6)
            sectionFrame.Name = "Section_" .. sectionName
            sectionFrame.AutomaticSize = Enum.AutomaticSize.Y
            sectionFrame.ClipsDescendants = false
            sectionFrame.LayoutOrder = #tabObject.Sections + 1
            sectionFrame.ZIndex = 10
            -- Section title
            local sectionTitle = Instance.new("TextLabel")
            sectionTitle.Parent = sectionFrame
            sectionTitle.Name = "Title"
            sectionTitle.BackgroundTransparency = 1
            sectionTitle.Position = UDim2.new(0, 8, 0, 4)
            sectionTitle.Size = UDim2.new(1, -16, 0, 20)
            sectionTitle.Font = Enum.Font.GothamSemibold
            sectionTitle.Text = sectionName
            sectionTitle.TextColor3 = theme.Text
            sectionTitle.TextSize = 15
            sectionTitle.TextXAlignment = Enum.TextXAlignment.Left
            -- Layout for items in section
            local itemList = Instance.new("UIListLayout")
            itemList.Parent = sectionFrame
            itemList.SortOrder = Enum.SortOrder.LayoutOrder
            itemList.Padding = UDim.new(0, 6)
            itemList.VerticalAlignment = Enum.VerticalAlignment.Top
            itemList.HorizontalAlignment = Enum.HorizontalAlignment.Left
            -- Automatic size to expand section height based on children
            local padding = Instance.new("UIPadding")
            padding.PaddingTop = UDim.new(0, 28)
            padding.PaddingBottom = UDim.new(0, 8)
            padding.PaddingLeft = UDim.new(0, 8)
            padding.PaddingRight = UDim.new(0, 8)
            padding.Parent = sectionFrame

            -- Section object to return
            local sectionObject = {}

            -- Helper to update canvas size after adding an item
            local function updateCanvas()
                -- After heartbeat to ensure sizes update
                task.defer(function()
                    local totalHeight = 0
                    for _, sec in ipairs(tabObject.Sections) do
                        totalHeight = totalHeight + sec.Container.AbsoluteSize.Y + sectionList.Padding.Offset
                    end
                    content.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 10)
                end)
            end

            -- Register section for search
            registerSearch(sectionName, sectionFrame)

            -- BUTTON
            function sectionObject:AddButton(btnOptions)
                btnOptions = btnOptions or {}
                local btnName = btnOptions.Name or "Button"
                local callback = btnOptions.Callback or function() end
                local buttonFrame = CreateContainer(sectionFrame, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 32), theme.Panel, 0, 4)
                buttonFrame.Name = "Button_" .. btnName
                buttonFrame.ZIndex = 11
                buttonFrame.LayoutOrder = #sectionFrame:GetChildren()
                local btnLabel = Instance.new("TextLabel")
                btnLabel.Parent = buttonFrame
                btnLabel.BackgroundTransparency = 1
                btnLabel.Size = UDim2.new(1, -10, 1, 0)
                btnLabel.Position = UDim2.new(0, 5, 0, 0)
                btnLabel.Font = Enum.Font.Gotham
                btnLabel.Text = btnName
                btnLabel.TextColor3 = theme.Text
                btnLabel.TextSize = 14
                btnLabel.TextXAlignment = Enum.TextXAlignment.Left
                local btnButton = Instance.new("TextButton")
                btnButton.Parent = buttonFrame
                btnButton.BackgroundTransparency = 1
                btnButton.Size = UDim2.new(1, 0, 1, 0)
                btnButton.Text = ""
                btnButton.AutoButtonColor = false
                -- Hover effect
                btnButton.MouseEnter:Connect(function()
                    Tween(buttonFrame, { BackgroundColor3 = theme.Accent }, 0.2)
                end)
                btnButton.MouseLeave:Connect(function()
                    Tween(buttonFrame, { BackgroundColor3 = theme.Panel }, 0.2)
                end)
                btnButton.MouseButton1Click:Connect(function()
                    pcall(callback)
                end)
                registerSearch(btnName, buttonFrame)
                updateCanvas()
                return buttonFrame
            end

            -- TOGGLE
            function sectionObject:AddToggle(togOptions)
                togOptions = togOptions or {}
                local togName = togOptions.Name or "Toggle"
                local default = togOptions.Default or false
                local callback = togOptions.Callback or function() end
                -- Container for toggle
                local toggleFrame = CreateContainer(sectionFrame, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 32), theme.Panel, 0, 4)
                toggleFrame.Name = "Toggle_" .. togName
                toggleFrame.ZIndex = 11
                toggleFrame.LayoutOrder = #sectionFrame:GetChildren()
                -- Label
                local lbl = Instance.new("TextLabel")
                lbl.Parent = toggleFrame
                lbl.BackgroundTransparency = 1
                lbl.Position = UDim2.new(0, 5, 0, 0)
                lbl.Size = UDim2.new(1, -60, 1, 0)
                lbl.Font = Enum.Font.Gotham
                lbl.Text = togName
                lbl.TextColor3 = theme.Text
                lbl.TextSize = 14
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                -- Toggle switch container
                local switch = CreateContainer(toggleFrame, UDim2.new(1, -50, 0.5, -8), UDim2.new(0, 40, 0, 16), theme.Section, 0, 8)
                switch.BorderSizePixel = 0
                switch.ClipsDescendants = true
                -- Fill part
                local knob = CreateContainer(switch, UDim2.new(default and 1 or 0, default and -16 or 0, 0, 0), UDim2.new(0, 16, 1, 0), theme.Accent, 0, 8)
                -- Toggle state
                local state = default
                local function updateSwitch(animated)
                    local newPos = state and UDim2.new(1, -16, 0, 0) or UDim2.new(0, 0, 0, 0)
                    if animated then
                        -- Change knob position and colour; fallback to Section colour when off
                        Tween(knob, { Position = newPos, BackgroundColor3 = state and theme.Accent or theme.Section }, 0.2)
                    else
                        knob.Position = newPos
                        knob.BackgroundColor3 = state and theme.Accent or theme.Section
                    end
                    callback(state)
                end
                -- Click handling
                local btn = Instance.new("TextButton")
                btn.Parent = toggleFrame
                btn.BackgroundTransparency = 1
                btn.Size = UDim2.new(1, 0, 1, 0)
                btn.Text = ""
                btn.AutoButtonColor = false
                btn.MouseButton1Click:Connect(function()
                    state = not state
                    updateSwitch(true)
                end)
                updateSwitch(false)
                registerSearch(togName, toggleFrame)
                updateCanvas()
                return {
                    Set = function(_, bool)
                        state = bool
                        updateSwitch(true)
                    end,
                    Get = function()
                        return state
                    end
                }
            end

            -- SLIDER
            function sectionObject:AddSlider(sliderOptions)
                sliderOptions = sliderOptions or {}
                local sliderName = sliderOptions.Name or "Slider"
                local min = sliderOptions.Min or 0
                local max = sliderOptions.Max or 100
                local default = math.clamp(sliderOptions.Default or min, min, max)
                local callback = sliderOptions.Callback or function() end
                local rounding = sliderOptions.Rounding or 0
                -- Container
                local sliderFrame = CreateContainer(sectionFrame, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 48), theme.Panel, 0, 4)
                sliderFrame.Name = "Slider_" .. sliderName
                sliderFrame.ZIndex = 11
                -- Store range as attributes for config save/load
                sliderFrame:SetAttribute("Min", min)
                sliderFrame:SetAttribute("Max", max)
                -- Label
                local lbl = Instance.new("TextLabel")
                lbl.Parent = sliderFrame
                lbl.BackgroundTransparency = 1
                lbl.Position = UDim2.new(0, 5, 0, 0)
                lbl.Size = UDim2.new(1, -10, 0, 20)
                lbl.Font = Enum.Font.Gotham
                lbl.Text = sliderName .. ": " .. tostring(default)
                lbl.TextColor3 = theme.Text
                lbl.TextSize = 14
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                -- Bar background
                local bar = CreateContainer(sliderFrame, UDim2.new(0, 5, 0, 24), UDim2.new(1, -10, 0, 16), theme.Section, 0, 8)
                bar.ClipsDescendants = true
                -- Fill bar
                local fill = CreateContainer(bar, UDim2.new((default - min) / (max - min), 0, 0, 0), UDim2.new(1, 0, 1, 0), theme.Accent, 0, 8)
                fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
                -- Draggable knob
                local knob = CreateContainer(bar, UDim2.new((default - min) / (max - min), -8, 0.5, -8), UDim2.new(0, 16, 0, 16), theme.Accent, 0, 8)
                knob.ZIndex = 12
                -- Value state
                local value = default
                local dragging = false
                local function setValue(newVal)
                    newVal = math.clamp(newVal, min, max)
                    value = newVal
                    local pct = (value - min) / (max - min)
                    fill:TweenSize(UDim2.new(pct, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
                    knob:TweenPosition(UDim2.new(pct, -8, 0.5, -8), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
                    local displayVal = rounding > 0 and tostring(math.floor((value + (0.1 ^ (rounding+1))) * 10^rounding) / 10^rounding) or tostring(math.floor(value))
                    lbl.Text = sliderName .. ": " .. displayVal
                    callback(value)
                end
                knob.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        input.Changed:Connect(function()
                            if input.UserInputState == Enum.UserInputState.End then
                                dragging = false
                            end
                        end)
                    end
                end)
                bar.InputChanged:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        local rel = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
                        setValue(min + (max - min) * rel)
                    end
                end)
                setValue(default)
                registerSearch(sliderName, sliderFrame)
                updateCanvas()
                return {
                    Set = function(_, num)
                        setValue(num)
                    end,
                    Get = function()
                        return value
                    end
                }
            end

            -- DROPDOWN
            function sectionObject:AddDropdown(dropOptions)
                dropOptions = dropOptions or {}
                local dropName = dropOptions.Name or "Dropdown"
                local items = dropOptions.Options or {}
                local default = dropOptions.Default or (items[1] or "")
                local callback = dropOptions.Callback or function() end
                -- Container
                local ddFrame = CreateContainer(sectionFrame, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 36), theme.Panel, 0, 4)
                ddFrame.Name = "Dropdown_" .. dropName
                ddFrame.ZIndex = 11
                -- Display label/button
                local display = Instance.new("TextButton")
                display.Parent = ddFrame
                display.BackgroundColor3 = theme.Section
                display.Size = UDim2.new(1, -10, 1, -4)
                display.Position = UDim2.new(0, 5, 0, 2)
                display.BorderSizePixel = 0
                display.TextColor3 = theme.Text
                display.TextSize = 14
                display.Font = Enum.Font.Gotham
                display.TextXAlignment = Enum.TextXAlignment.Left
                display.AutoButtonColor = false
                display.Text = dropName .. ": " .. tostring(default)
                local displayCorner = Instance.new("UICorner")
                displayCorner.CornerRadius = UDim.new(0, 4)
                displayCorner.Parent = display
                -- Arrow indicator
                local arrow = Instance.new("ImageLabel")
                arrow.Parent = display
                arrow.BackgroundTransparency = 1
                arrow.Size = UDim2.new(0, 12, 0, 12)
                arrow.Position = UDim2.new(1, -20, 0.5, -6)
                arrow.Image = "rbxassetid://6031094678"
                arrow.ImageColor3 = theme.SubText
                -- Dropdown list frame
                local listFrame = CreateContainer(ddFrame, UDim2.new(0, 5, 1, 2), UDim2.new(1, -10, 0, 0), theme.Panel, 0, 4)
                listFrame.Visible = false
                listFrame.ZIndex = 12
                listFrame.ClipsDescendants = true
                listFrame.AutomaticSize = Enum.AutomaticSize.Y
                listFrame.LayoutOrder = 0
                -- layout
                local listLayout = Instance.new("UIListLayout")
                listLayout.Parent = listFrame
                listLayout.SortOrder = Enum.SortOrder.LayoutOrder
                -- Build items
                local function buildItems()
                    listFrame:ClearAllChildren()
                    listLayout.Parent = listFrame
                    for i, item in ipairs(items) do
                        local itemBtn = Instance.new("TextButton")
                        itemBtn.Parent = listFrame
                        itemBtn.Size = UDim2.new(1, 0, 0, 24)
                        itemBtn.BackgroundColor3 = theme.Section
                        itemBtn.BorderSizePixel = 0
                        itemBtn.TextColor3 = theme.Text
                        itemBtn.TextSize = 14
                        itemBtn.Font = Enum.Font.Gotham
                        itemBtn.Text = tostring(item)
                        local itemCorner = Instance.new("UICorner")
                        itemCorner.CornerRadius = UDim.new(0, 4)
                        itemCorner.Parent = itemBtn
                        itemBtn.MouseEnter:Connect(function()
                            Tween(itemBtn, { BackgroundColor3 = theme.Accent }, 0.15)
                        end)
                        itemBtn.MouseLeave:Connect(function()
                            Tween(itemBtn, { BackgroundColor3 = theme.Section }, 0.15)
                        end)
                        itemBtn.MouseButton1Click:Connect(function()
                            display.Text = dropName .. ": " .. tostring(item)
                            listFrame.Visible = false
                            arrow.Rotation = 0
                            callback(item)
                        end)
                    end
                end
                buildItems()
                -- Toggle list
                display.MouseButton1Click:Connect(function()
                    local visible = not listFrame.Visible
                    listFrame.Visible = visible
                    Tween(arrow, { Rotation = visible and 90 or 0 }, 0.2)
                end)
                registerSearch(dropName, ddFrame)
                updateCanvas()
                return {
                    Set = function(_, newSelection)
                        display.Text = dropName .. ": " .. tostring(newSelection)
                        callback(newSelection)
                    end,
                    Get = function()
                        local current = display.Text:sub(#dropName + 3)
                        return current
                    end
                }
            end

            -- MULTI DROPDOWN
            function sectionObject:AddMultiDropdown(mdOptions)
                mdOptions = mdOptions or {}
                local mdName = mdOptions.Name or "MultiDropdown"
                local items = mdOptions.Options or {}
                local default = mdOptions.Default or {}
                local callback = mdOptions.Callback or function() end
                -- Container
                local mdFrame = CreateContainer(sectionFrame, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 36), theme.Panel, 0, 4)
                mdFrame.Name = "MultiDropdown_" .. mdName
                mdFrame.ZIndex = 11
                -- Display button
                local display = Instance.new("TextButton")
                display.Parent = mdFrame
                display.BackgroundColor3 = theme.Section
                display.Size = UDim2.new(1, -10, 1, -4)
                display.Position = UDim2.new(0, 5, 0, 2)
                display.BorderSizePixel = 0
                display.TextColor3 = theme.Text
                display.TextSize = 14
                display.Font = Enum.Font.Gotham
                display.TextXAlignment = Enum.TextXAlignment.Left
                display.AutoButtonColor = false
                local selectedList = {}
                -- Build display text
                local function updateLabel()
                    if #selectedList == 0 then
                        display.Text = mdName .. ": None"
                    else
                        display.Text = mdName .. ": " .. table.concat(selectedList, ", ")
                    end
                end
                for _, v in ipairs(default) do table.insert(selectedList, v) end
                updateLabel()
                local displayCorner = Instance.new("UICorner")
                displayCorner.CornerRadius = UDim.new(0, 4)
                displayCorner.Parent = display
                local arrow = Instance.new("ImageLabel")
                arrow.Parent = display
                arrow.BackgroundTransparency = 1
                arrow.Size = UDim2.new(0, 12, 0, 12)
                arrow.Position = UDim2.new(1, -20, 0.5, -6)
                arrow.Image = "rbxassetid://6031094678"
                arrow.ImageColor3 = theme.SubText
                -- List frame
                local listFrame = CreateContainer(mdFrame, UDim2.new(0, 5, 1, 2), UDim2.new(1, -10, 0, 0), theme.Panel, 0, 4)
                listFrame.Visible = false
                listFrame.ZIndex = 12
                listFrame.AutomaticSize = Enum.AutomaticSize.Y
                local listLayout = Instance.new("UIListLayout")
                listLayout.Parent = listFrame
                listLayout.SortOrder = Enum.SortOrder.LayoutOrder
                -- Build items
                local function buildItems()
                    listFrame:ClearAllChildren()
                    listLayout.Parent = listFrame
                    for i, item in ipairs(items) do
                        local itemBtn = Instance.new("TextButton")
                        itemBtn.Parent = listFrame
                        itemBtn.Size = UDim2.new(1, 0, 0, 24)
                        itemBtn.BackgroundColor3 = theme.Section
                        itemBtn.BorderSizePixel = 0
                        itemBtn.TextColor3 = theme.Text
                        itemBtn.TextSize = 14
                        itemBtn.Font = Enum.Font.Gotham
                        itemBtn.TextXAlignment = Enum.TextXAlignment.Left
                        -- selection indicator
                        local check = Instance.new("ImageLabel")
                        check.Parent = itemBtn
                        check.Size = UDim2.new(0, 16, 0, 16)
                        check.Position = UDim2.new(1, -20, 0.5, -8)
                        check.BackgroundTransparency = 1
                        check.Image = "rbxassetid://6031094678" -- using same arrow icon as check mark placeholder
                        check.ImageColor3 = theme.Accent
                        check.Visible = table.find(selectedList, item) ~= nil
                        itemBtn.Text = tostring(item)
                        itemBtn.MouseButton1Click:Connect(function()
                            local idx = table.find(selectedList, item)
                            if idx then
                                table.remove(selectedList, idx)
                            else
                                table.insert(selectedList, item)
                            end
                            check.Visible = not check.Visible
                            updateLabel()
                            callback(selectedList)
                        end)
                        itemBtn.MouseEnter:Connect(function()
                            Tween(itemBtn, { BackgroundColor3 = theme.Accent }, 0.15)
                        end)
                        itemBtn.MouseLeave:Connect(function()
                            Tween(itemBtn, { BackgroundColor3 = theme.Section }, 0.15)
                        end)
                    end
                end
                buildItems()
                display.MouseButton1Click:Connect(function()
                    local visible = not listFrame.Visible
                    listFrame.Visible = visible
                    Tween(arrow, { Rotation = visible and 90 or 0 }, 0.2)
                end)
                registerSearch(mdName, mdFrame)
                updateCanvas()
                return {
                    Set = function(_, list)
                        selectedList = list or {}
                        updateLabel()
                        callback(selectedList)
                    end,
                    Get = function()
                        return selectedList
                    end
                }
            end

            -- TEXTBOX
            function sectionObject:AddTextbox(tbOptions)
                tbOptions = tbOptions or {}
                local tbName = tbOptions.Name or "Textbox"
                local default = tbOptions.Default or ""
                local placeholder = tbOptions.Placeholder or "Type..."
                local callback = tbOptions.Callback or function() end
                -- Container
                local tbFrame = CreateContainer(sectionFrame, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 32), theme.Panel, 0, 4)
                tbFrame.Name = "Textbox_" .. tbName
                tbFrame.ZIndex = 11
                -- Label
                local lbl = Instance.new("TextLabel")
                lbl.Parent = tbFrame
                lbl.BackgroundTransparency = 1
                lbl.Position = UDim2.new(0, 5, 0, 0)
                lbl.Size = UDim2.new(0, 100, 1, 0)
                lbl.Font = Enum.Font.Gotham
                lbl.Text = tbName
                lbl.TextColor3 = theme.Text
                lbl.TextSize = 14
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                -- Text box
                local box = Instance.new("TextBox")
                box.Parent = tbFrame
                box.BackgroundColor3 = theme.Section
                box.Position = UDim2.new(0, 110, 0, 4)
                box.Size = UDim2.new(1, -120, 1, -8)
                box.Font = Enum.Font.Gotham
                box.TextColor3 = theme.Text
                box.TextSize = 14
                box.Text = default
                box.PlaceholderText = placeholder
                box.PlaceholderColor3 = theme.SubText
                box.BorderSizePixel = 0
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 4)
                corner.Parent = box
                box.FocusLost:Connect(function(enterPressed)
                    callback(box.Text)
                end)
                registerSearch(tbName, tbFrame)
                updateCanvas()
                return {
                    Set = function(_, text)
                        box.Text = text
                        callback(text)
                    end,
                    Get = function()
                        return box.Text
                    end
                }
            end

            -- KEYBIND
            function sectionObject:AddKeybind(kbOptions)
                kbOptions = kbOptions or {}
                local kbName = kbOptions.Name or "Keybind"
                local defaultKey = kbOptions.DefaultKey or Enum.KeyCode.E
                local callback = kbOptions.Callback or function() end
                -- Container
                local kbFrame = CreateContainer(sectionFrame, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 32), theme.Panel, 0, 4)
                kbFrame.Name = "Keybind_" .. kbName
                kbFrame.ZIndex = 11
                -- Label
                local lbl = Instance.new("TextLabel")
                lbl.Parent = kbFrame
                lbl.BackgroundTransparency = 1
                lbl.Position = UDim2.new(0, 5, 0, 0)
                lbl.Size = UDim2.new(1, -60, 1, 0)
                lbl.Font = Enum.Font.Gotham
                lbl.Text = kbName .. ": " .. tostring(defaultKey.Name)
                lbl.TextColor3 = theme.Text
                lbl.TextSize = 14
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                -- Key listening flag
                local listening = false
                local boundKey = defaultKey
                -- Button to change key
                local btn = Instance.new("TextButton")
                btn.Parent = kbFrame
                btn.BackgroundColor3 = theme.Section
                btn.Position = UDim2.new(1, -80, 0.5, -12)
                btn.Size = UDim2.new(0, 70, 0, 24)
                btn.BorderSizePixel = 0
                btn.TextColor3 = theme.Text
                btn.TextSize = 14
                btn.Font = Enum.Font.Gotham
                btn.Text = tostring(defaultKey.Name)
                local btnCorner = Instance.new("UICorner")
                btnCorner.CornerRadius = UDim.new(0, 4)
                btnCorner.Parent = btn
                btn.AutoButtonColor = false
                btn.MouseEnter:Connect(function()
                    Tween(btn, { BackgroundColor3 = theme.Accent }, 0.15)
                end)
                btn.MouseLeave:Connect(function()
                    Tween(btn, { BackgroundColor3 = theme.Section }, 0.15)
                end)
                btn.MouseButton1Click:Connect(function()
                    listening = true
                    btn.Text = "..."
                end)
                -- Input detection
                local inputConn
                inputConn = UserInputService.InputBegan:Connect(function(input, gpe)
                    if gpe then return end
                    if listening then
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            boundKey = input.KeyCode
                            btn.Text = boundKey.Name
                            lbl.Text = kbName .. ": " .. boundKey.Name
                            listening = false
                        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                            boundKey = Enum.UserInputType.MouseButton1
                            btn.Text = "M1"
                            lbl.Text = kbName .. ": M1"
                            listening = false
                        end
                    elseif input.KeyCode == boundKey then
                        callback()
                    elseif boundKey == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1 then
                        callback()
                    end
                end)
                registerSearch(kbName, kbFrame)
                updateCanvas()
                return {
                    Set = function(_, key)
                        boundKey = key
                        btn.Text = typeof(key) == "EnumItem" and key.Name or tostring(key)
                        lbl.Text = kbName .. ": " .. btn.Text
                    end,
                    Get = function()
                        return boundKey
                    end
                }
            end

            -- COLOR PICKER
            function sectionObject:AddColorPicker(cpOptions)
                cpOptions = cpOptions or {}
                local cpName = cpOptions.Name or "ColorPicker"
                local defaultColor = cpOptions.Default or Color3.fromRGB(255, 255, 255)
                local callback = cpOptions.Callback or function() end
                -- Container
                local cpFrame = CreateContainer(sectionFrame, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 36), theme.Panel, 0, 4)
                cpFrame.Name = "ColorPicker_" .. cpName
                cpFrame.ZIndex = 11
                -- Label
                local lbl = Instance.new("TextLabel")
                lbl.Parent = cpFrame
                lbl.BackgroundTransparency = 1
                lbl.Position = UDim2.new(0, 5, 0, 0)
                lbl.Size = UDim2.new(1, -60, 1, 0)
                lbl.Font = Enum.Font.Gotham
                lbl.Text = cpName
                lbl.TextColor3 = theme.Text
                lbl.TextSize = 14
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                -- Color display square
                local preview = CreateContainer(cpFrame, UDim2.new(1, -30, 0.5, -10), UDim2.new(0, 20, 0, 20), defaultColor, 0, 4)
                preview.BorderSizePixel = 0
                -- Popup
                local pickerOpen = false
                local picker = CreateContainer(cpFrame, UDim2.new(0, 5, 1, 2), UDim2.new(1, -10, 0, 0), theme.Panel, 0, 4)
                picker.Visible = false
                picker.ZIndex = 12
                picker.ClipsDescendants = false
                -- Hue bar and SV area sizes
                local hueBar = CreateContainer(picker, UDim2.new(0, 0, 0, 0), UDim2.new(0, 20, 0, 120), Color3.new(1,1,1), 0, 4)
                hueBar.BorderSizePixel = 0
                hueBar.Position = UDim2.new(1, -20, 0, 0)
                -- Hue gradient
                local hueGradient = Instance.new("UIGradient")
                hueGradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0/6,1,1)),
                    ColorSequenceKeypoint.new(1/6, Color3.fromHSV(1/6,1,1)),
                    ColorSequenceKeypoint.new(2/6, Color3.fromHSV(2/6,1,1)),
                    ColorSequenceKeypoint.new(3/6, Color3.fromHSV(3/6,1,1)),
                    ColorSequenceKeypoint.new(4/6, Color3.fromHSV(4/6,1,1)),
                    ColorSequenceKeypoint.new(5/6, Color3.fromHSV(5/6,1,1)),
                    ColorSequenceKeypoint.new(1.00, Color3.fromHSV(1,1,1))
                })
                hueGradient.Rotation = 90
                hueGradient.Parent = hueBar
                -- Hue indicator
                local hueIndicator = CreateContainer(hueBar, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 2), theme.Text, 0, 0)
                hueIndicator.BackgroundTransparency = 0
                hueIndicator.BorderSizePixel = 0
                -- Saturation/Value area
                local svArea = CreateContainer(picker, UDim2.new(0, 0, 0, 0), UDim2.new(1, -24, 0, 120), Color3.new(1,1,1), 0, 4)
                svArea.BorderSizePixel = 0
                -- White and black overlays
                local satGradient = Instance.new("UIGradient")
                satGradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
                    ColorSequenceKeypoint.new(1, Color3.new(1,1,1))
                })
                satGradient.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 1)
                })
                satGradient.Parent = svArea
                local valGradient = Instance.new("UIGradient")
                valGradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
                    ColorSequenceKeypoint.new(1, Color3.new(0,0,0))
                })
                valGradient.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(1, 0)
                })
                valGradient.Rotation = 90
                valGradient.Parent = svArea
                -- SV indicator
                local svIndicator = CreateContainer(svArea, UDim2.new(0, 0, 0, 0), UDim2.new(0, 4, 0, 4), theme.Text, 0, 2)
                svIndicator.BorderSizePixel = 0
                -- Colour state (HSV)
                local h, s, v = Color3.toHSV(defaultColor)
                -- function to update indicator positions and preview
                local function updateFromHSV()
                    local x = s * svArea.AbsoluteSize.X
                    local y = (1 - v) * svArea.AbsoluteSize.Y
                    svIndicator.Position = UDim2.new(0, x - 2, 0, y - 2)
                    local hueY = (1 - h) * hueBar.AbsoluteSize.Y
                    hueIndicator.Position = UDim2.new(0, 0, 0, hueY - 1)
                    local col = Color3.fromHSV(h, s, v)
                    preview.BackgroundColor3 = col
                    callback(col)
                end
                -- update SV area base colour for current hue
                local function updateSVBase()
                    svArea.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                end
                updateSVBase()
                updateFromHSV()
                -- Input events for SV area
                local svDragging = false
                svArea.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        svDragging = true
                        local pos = Vector2.new(input.Position.X - svArea.AbsolutePosition.X, input.Position.Y - svArea.AbsolutePosition.Y)
                        s = math.clamp(pos.X / svArea.AbsoluteSize.X, 0, 1)
                        v = 1 - math.clamp(pos.Y / svArea.AbsoluteSize.Y, 0, 1)
                        updateFromHSV()
                        input.Changed:Connect(function()
                            if input.UserInputState == Enum.UserInputState.End then
                                svDragging = false
                            end
                        end)
                    end
                end)
                svArea.InputChanged:Connect(function(input)
                    if svDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        local pos = Vector2.new(input.Position.X - svArea.AbsolutePosition.X, input.Position.Y - svArea.AbsolutePosition.Y)
                        s = math.clamp(pos.X / svArea.AbsoluteSize.X, 0, 1)
                        v = 1 - math.clamp(pos.Y / svArea.AbsoluteSize.Y, 0, 1)
                        updateFromHSV()
                    end
                end)
                -- Input events for hue bar
                local hueDragging = false
                hueBar.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        hueDragging = true
                        local rel = (input.Position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y
                        h = 1 - math.clamp(rel, 0, 1)
                        updateSVBase()
                        updateFromHSV()
                        input.Changed:Connect(function()
                            if input.UserInputState == Enum.UserInputState.End then
                                hueDragging = false
                            end
                        end)
                    end
                end)
                hueBar.InputChanged:Connect(function(input)
                    if hueDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        local rel = (input.Position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y
                        h = 1 - math.clamp(rel, 0, 1)
                        updateSVBase()
                        updateFromHSV()
                    end
                end)
                -- Toggle picker on click
                preview.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        pickerOpen = not pickerOpen
                        picker.Visible = pickerOpen
                    end
                end)
                registerSearch(cpName, cpFrame)
                updateCanvas()
                return {
                    Set = function(_, color)
                        local hh, ss, vv = Color3.toHSV(color)
                        h, s, v = hh, ss, vv
                        updateSVBase()
                        updateFromHSV()
                    end,
                    Get = function()
                        return Color3.fromHSV(h, s, v)
                    end
                }
            end

            -- NOTIFICATION for section (wrapper around window's global)
            function sectionObject:Notify(notiOptions)
                windowObject:Notify(notiOptions)
            end

            table.insert(tabObject.Sections, { Name = sectionName, Container = sectionFrame })
            updateCanvas()
            return sectionObject
        end -- AddSection

        -- Register tab
        table.insert(tabs, tabObject)
        registerSearch(tabName, button)
        -- Button click to select tab
        button.MouseButton1Click:Connect(function()
            local index = table.find(tabs, tabObject)
            selectTab(index)
        end)
        -- Automatically select first tab
        if #tabs == 1 then
            selectTab(1)
        end
        return tabObject
    end -- AddTab

    -- Show a temporary notification at the bottom right of the screen
    function windowObject:Notify(notiOptions)
        notiOptions = notiOptions or {}
        local msg = notiOptions.Text or "Notification"
        local duration = notiOptions.Duration or 3
        -- Container
        local notif = CreateContainer(gui, UDim2.new(1, -260, 1, -80), UDim2.new(0, 250, 0, 50), theme.Panel, 0, 6)
        notif.ZIndex = 100
        -- Text
        local txt = Instance.new("TextLabel")
        txt.Parent = notif
        txt.BackgroundTransparency = 1
        txt.Position = UDim2.new(0, 10, 0, 0)
        txt.Size = UDim2.new(1, -20, 1, 0)
        txt.Font = Enum.Font.Gotham
        txt.TextColor3 = theme.Text
        txt.TextSize = 14
        txt.TextWrapped = true
        txt.TextXAlignment = Enum.TextXAlignment.Left
        txt.TextYAlignment = Enum.TextYAlignment.Center
        txt.Text = msg
        -- Appear animation
        notif.Position = UDim2.new(1, 260, 1, -80)
        Tween(notif, { Position = UDim2.new(1, -260, 1, -80) }, 0.3)
        -- Disappear after duration
        task.delay(duration, function()
            Tween(notif, { Position = UDim2.new(1, 260, 1, -80) }, 0.3)
            task.wait(0.3)
            if notif then notif:Destroy() end
        end)
    end

    -- Save config: iterate through stored sections/items and capture current states
    function windowObject:SaveConfig(fileName)
        local writeFile, readFile = getFSFunctions()
        if not writeFile then
            warn("[ZenithUI] Unable to save config: writefile/readfile functions unavailable")
            return
        end
        local data = {}
        for _, tab in ipairs(tabs) do
            for _, sec in ipairs(tab.Sections) do
                local secName = sec.Name
                data[secName] = data[secName] or {}
                local container = sec.Container
                for _, element in ipairs(container:GetChildren()) do
                    if element.Name:match("Toggle_") then
                        local toggleName = element.Name:sub(8)
                        local knob = element:FindFirstChildWhichIsA("Frame", true)
                        local state = (knob and knob.Position.X.Scale > 0)
                        data[secName][toggleName] = state
                    elseif element.Name:match("Slider_") then
                        local sliderName = element.Name:sub(8)
                        local label = element:FindFirstChildOfClass("TextLabel")
                        local value = tonumber(label.Text:match("%d+[%.%d]*")) or 0
                        data[secName][sliderName] = value
                    elseif element.Name:match("Dropdown_") then
                        local ddName = element.Name:sub(10)
                        local display = element:FindFirstChildWhichIsA("TextButton")
                        local selection = display.Text:sub(#ddName + 3)
                        data[secName][ddName] = selection
                    elseif element.Name:match("MultiDropdown_") then
                        local mdName = element.Name:sub(14)
                        local display = element:FindFirstChildWhichIsA("TextButton")
                        local listStr = display.Text:sub(#mdName + 3)
                        local selections = {}
                        if listStr ~= "None" then
                            for part in string.gmatch(listStr, "[^, ]+") do
                                table.insert(selections, part)
                            end
                        end
                        data[secName][mdName] = selections
                    elseif element.Name:match("Textbox_") then
                        local tbName = element.Name:sub(9)
                        local box = element:FindFirstChildOfClass("TextBox")
                        data[secName][tbName] = box.Text
                    elseif element.Name:match("Keybind_") then
                        local kbName = element.Name:sub(9)
                        local lbl = element:FindFirstChildOfClass("TextLabel")
                        local key = lbl.Text:match(": (.+)") or ""
                        data[secName][kbName] = key
                    elseif element.Name:match("ColorPicker_") then
                        local cpName = element.Name:sub(13)
                        local previewSquare = element:FindFirstChildWhichIsA("Frame")
                        local col = previewSquare.BackgroundColor3
                        data[secName][cpName] = {col.R, col.G, col.B}
                    end
                end
            end
        end
        local encoded = HttpService:JSONEncode(data)
        local path = fileName or "zenithui_config.json"
        pcall(function()
            writeFile(path, encoded)
        end)
    end

    -- Load config: read JSON and apply saved values
    function windowObject:LoadConfig(fileName)
        local writeFile, readFile = getFSFunctions()
        if not readFile then
            warn("[ZenithUI] Unable to load config: readfile function unavailable")
            return
        end
        local path = fileName or "zenithui_config.json"
        local success, contents = pcall(readFile, path)
        if not success or not contents then
            warn("[ZenithUI] Failed to read config file" .. tostring(path))
            return
        end
        local data = nil
        local ok, decoded = pcall(function() return HttpService:JSONDecode(contents) end)
        if ok then data = decoded else return end
        -- Apply values
        for _, tab in ipairs(tabs) do
            for _, sec in ipairs(tab.Sections) do
                local secData = data[sec.Name]
                if secData then
                    for _, element in ipairs(sec.Container:GetChildren()) do
                        -- toggles
                        if element.Name:match("Toggle_") then
                            local tName = element.Name:sub(8)
                            if secData[tName] ~= nil then
                                local knob = element:FindFirstChildWhichIsA("Frame", true)
                                local state = secData[tName]
                                knob.Position = state and UDim2.new(1, -16, 0, 0) or UDim2.new(0, 0, 0, 0)
                                -- update callback
                            end
                        elseif element.Name:match("Slider_") then
                            local sName = element.Name:sub(8)
                            local value = secData[sName]
                            if value then
                                local bar = element:FindFirstChildWhichIsA("Frame")
                                local lbl = element:FindFirstChildOfClass("TextLabel")
                                -- Retrieve stored min/max from attributes
                                local minVal = element:GetAttribute("Min") or 0
                                local maxVal = element:GetAttribute("Max") or 100
                                local pct = (value - minVal)/(maxVal - minVal)
                                local fill = bar:FindFirstChildWhichIsA("Frame")
                                local knob = bar:FindFirstChildWhichIsA("Frame", true)
                                if fill and knob then
                                    fill.Size = UDim2.new(pct, 0, 1, 0)
                                    knob.Position = UDim2.new(pct, -8, 0.5, -8)
                                end
                                lbl.Text = sName .. ": " .. tostring(value)
                            end
                        elseif element.Name:match("Dropdown_") then
                            local dName = element.Name:sub(10)
                            local sel = secData[dName]
                            if sel then
                                local display = element:FindFirstChildWhichIsA("TextButton")
                                display.Text = dName .. ": " .. tostring(sel)
                            end
                        elseif element.Name:match("MultiDropdown_") then
                            local mdName = element.Name:sub(14)
                            local list = secData[mdName]
                            if list then
                                local display = element:FindFirstChildWhichIsA("TextButton")
                                if #list == 0 then
                                    display.Text = mdName .. ": None"
                                else
                                    display.Text = mdName .. ": " .. table.concat(list, ", ")
                                end
                            end
                        elseif element.Name:match("Textbox_") then
                            local tbName = element.Name:sub(9)
                            local text = secData[tbName]
                            if text then
                                local box = element:FindFirstChildOfClass("TextBox")
                                box.Text = text
                            end
                        elseif element.Name:match("Keybind_") then
                            local kbName = element.Name:sub(9)
                            local key = secData[kbName]
                            if key then
                                local lbl = element:FindFirstChildOfClass("TextLabel")
                                local btn = element:FindFirstChildWhichIsA("TextButton")
                                lbl.Text = kbName .. ": " .. key
                                btn.Text = key
                            end
                        elseif element.Name:match("ColorPicker_") then
                            local cpName = element.Name:sub(13)
                            local col = secData[cpName]
                            if col then
                                local previewSquare = element:FindFirstChildWhichIsA("Frame")
                                previewSquare.BackgroundColor3 = Color3.new(col[1], col[2], col[3])
                            end
                        end
                    end
                end
            end
        end
    end

    -- Destroy UI
    function windowObject:Destroy()
        gui:Destroy()
    end

    return windowObject
end

-- Return the library
return ZenithUI