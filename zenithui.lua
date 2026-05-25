--[[
    ZenithUI Premium Glass Edition
    Non-OOP Roblox Luau UI Library

    Usage:
        local Library = loadstring(game:HttpGet("URL_LIBRARY"))()
        local Window = Library:CreateWindow({ Title = "Zenith", AccentColor = Color3.fromRGB(120, 105, 255) })

    Design goal:
        Premium 2025 dashboard style, dark glassmorphism, clean spacing, soft depth,
        compact sidebar, modern controls, and backward-compatible API.
--]]

local ZenithUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local DefaultTheme = {
    Accent = Color3.fromRGB(120, 105, 255),
    Base = Color3.fromRGB(10, 11, 15),
    Surface = Color3.fromRGB(19, 20, 27),
    Surface2 = Color3.fromRGB(27, 28, 36),
    Surface3 = Color3.fromRGB(36, 38, 49),
    Text = Color3.fromRGB(242, 244, 248),
    Muted = Color3.fromRGB(155, 160, 174),
    Soft = Color3.fromRGB(255, 255, 255),
    Danger = Color3.fromRGB(255, 95, 95),

    MainTransparency = 0.18,
    PanelTransparency = 0.28,
    CardTransparency = 0.22,
    InputTransparency = 0.20,
    StrokeTransparency = 0.88,
    HighlightTransparency = 0.78,

    Radius = 16,
    RadiusSmall = 10,
    RadiusTiny = 7,
}

local function shallowCopy(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

local function resolveTheme(options)
    local theme = shallowCopy(DefaultTheme)
    options = options or {}
    if typeof(options.AccentColor) == "Color3" then
        theme.Accent = options.AccentColor
    end
    if typeof(options.Theme) == "table" then
        for k, v in pairs(options.Theme) do
            if theme[k] ~= nil then
                theme[k] = v
            end
        end
    end
    return theme
end

local function tween(object, props, speed, style, direction)
    local info = TweenInfo.new(speed or 0.18, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out)
    local t = TweenService:Create(object, info, props)
    t:Play()
    return t
end

local function safeParent(gui)
    local ok, core = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok and core then
        gui.Parent = core
    else
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

local function fs()
    local env = getfenv and getfenv(0) or _ENV or {}
    return env.writefile or env.writeFile or (env.syn and env.syn.writefile),
           env.readfile or env.readFile or (env.syn and env.syn.readfile),
           env.isfile or env.isFile or (env.syn and env.syn.isfile)
end

local function new(className, props, children)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    for _, child in ipairs(children or {}) do
        child.Parent = obj
    end
    return obj
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = parent
    return c
end

local function stroke(parent, color, transparency, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(255, 255, 255)
    s.Transparency = transparency or 0.9
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function padding(parent, l, t, r, b)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, l or 0)
    p.PaddingTop = UDim.new(0, t or 0)
    p.PaddingRight = UDim.new(0, r or l or 0)
    p.PaddingBottom = UDim.new(0, b or t or 0)
    p.Parent = parent
    return p
end

local function list(parent, paddingOffset, horizontal)
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, paddingOffset or 8)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
    l.VerticalAlignment = Enum.VerticalAlignment.Top
    l.HorizontalAlignment = Enum.HorizontalAlignment.Left
    l.Parent = parent
    return l
end

local function gradient(parent, colorA, colorB, transparencyA, transparencyB, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(colorA, colorB)
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, transparencyA or 0),
        NumberSequenceKeypoint.new(1, transparencyB or 0),
    })
    g.Rotation = rotation or 90
    g.Parent = parent
    return g
end

local function shadow(parent, sizeOffset, transparency)
    local sh = Instance.new("ImageLabel")
    sh.Name = "SoftShadow"
    sh.AnchorPoint = Vector2.new(0.5, 0.5)
    sh.Position = UDim2.fromScale(0.5, 0.5)
    sh.Size = UDim2.new(1, sizeOffset or 42, 1, sizeOffset or 42)
    sh.BackgroundTransparency = 1
    sh.Image = "rbxassetid://1316045217"
    sh.ImageColor3 = Color3.fromRGB(0, 0, 0)
    sh.ImageTransparency = transparency or 0.58
    sh.ScaleType = Enum.ScaleType.Slice
    sh.SliceCenter = Rect.new(10, 10, 118, 118)
    sh.ZIndex = (parent.ZIndex or 1) - 1
    sh.Parent = parent
    return sh
end

local function glassFrame(parent, props, theme, level)
    level = level or 1
    local trans = level == 1 and theme.PanelTransparency or (level == 2 and theme.CardTransparency or theme.InputTransparency)
    local frame = new("Frame", {
        Name = props.Name or "GlassFrame",
        Parent = parent,
        Size = props.Size or UDim2.new(1, 0, 0, 40),
        Position = props.Position or UDim2.new(),
        AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
        BackgroundColor3 = props.BackgroundColor3 or (level == 1 and theme.Surface or (level == 2 and theme.Surface2 or theme.Surface3)),
        BackgroundTransparency = props.BackgroundTransparency ~= nil and props.BackgroundTransparency or trans,
        BorderSizePixel = 0,
        ClipsDescendants = props.ClipsDescendants or false,
        ZIndex = props.ZIndex or 1,
        AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.None,
        LayoutOrder = props.LayoutOrder or 0,
    })
    corner(frame, props.Radius or (level == 1 and theme.Radius or theme.RadiusSmall))
    if props.Stroke ~= false then
        stroke(frame, theme.Soft, props.StrokeTransparency or theme.StrokeTransparency, 1)
    end
    if props.Gradient ~= false then
        gradient(frame, theme.Soft, theme.Surface3, theme.HighlightTransparency, 1, 110)
    end
    return frame
end

local function text(parent, props, theme)
    return new("TextLabel", {
        Name = props.Name or "Text",
        Parent = parent,
        BackgroundTransparency = 1,
        Size = props.Size or UDim2.new(1, 0, 0, 20),
        Position = props.Position or UDim2.new(),
        Font = props.Font or Enum.Font.Gotham,
        Text = props.Text or "",
        TextColor3 = props.Color or theme.Text,
        TextTransparency = props.TextTransparency or 0,
        TextSize = props.SizeText or 14,
        TextXAlignment = props.X or Enum.TextXAlignment.Left,
        TextYAlignment = props.Y or Enum.TextYAlignment.Center,
        TextWrapped = props.Wrapped or false,
        ZIndex = props.ZIndex or 1,
    })
end

local function buttonOverlay(parent)
    return new("TextButton", {
        Name = "Hitbox",
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        AutoButtonColor = false,
        ZIndex = (parent.ZIndex or 1) + 3,
    })
end

local function createRipple(parent, theme, x, y)
    if not parent or not parent.Parent then return end
    local r = new("Frame", {
        Name = "Ripple",
        Parent = parent,
        BackgroundColor3 = theme.Accent,
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(x - parent.AbsolutePosition.X, y - parent.AbsolutePosition.Y),
        Size = UDim2.fromOffset(0, 0),
        ZIndex = (parent.ZIndex or 1) + 2,
    })
    corner(r, 999)
    local s = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 1.8
    tween(r, {Size = UDim2.fromOffset(s, s), BackgroundTransparency = 1}, 0.36, Enum.EasingStyle.Quint)
    task.delay(0.38, function()
        if r then r:Destroy() end
    end)
end

local function autoCanvas(scroll, extra)
    task.defer(function()
        local layout = scroll:FindFirstChildWhichIsA("UIListLayout")
        if layout then
            scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + (extra or 24))
        end
    end)
end

local function makeDraggable(frame, handle)
    local dragging = false
    local dragStart
    local startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        tween(frame, {
            Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        }, 0.035, Enum.EasingStyle.Linear)
    end)
end

function ZenithUI:CreateWindow(options)
    options = options or {}
    local theme = resolveTheme(options)
    local windowTitle = options.Title or "ZenithUI"
    local subtitle = options.Subtitle or "Premium Dashboard"
    local size = options.Size or UDim2.fromOffset(680, 460)
    local sidebarWidth = options.SidebarWidth or 112

    local gui = new("ScreenGui", {
        Name = "ZenithUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = false,
    })
    safeParent(gui)

    local main = new("Frame", {
        Name = "ZenithRoot",
        Parent = gui,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = size,
        BackgroundColor3 = theme.Base,
        BackgroundTransparency = theme.MainTransparency,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        ZIndex = 20,
    })
    corner(main, theme.Radius)
    shadow(main, 58, 0.52)

    local scale = Instance.new("UIScale")
    scale.Scale = 1
    scale.Parent = main

    local function updateScale()
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
        local targetW = size.X.Offset
        if viewport.X < targetW + 32 then
            scale.Scale = math.clamp((viewport.X - 28) / targetW, 0.72, 1)
        else
            scale.Scale = 1
        end
    end
    updateScale()
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    end

    -- Fake blur/depth illusion layers.
    local blurBack = new("Frame", {
        Name = "BlurDepthLayer",
        Parent = main,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.96,
        BorderSizePixel = 0,
        ZIndex = 20,
    })
    corner(blurBack, theme.Radius)
    gradient(blurBack, Color3.fromRGB(255,255,255), theme.Accent, 0.92, 0.985, 28)

    local depthLayer = new("Frame", {
        Name = "DepthTint",
        Parent = main,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.56,
        BorderSizePixel = 0,
        ZIndex = 21,
    })
    corner(depthLayer, theme.Radius)
    gradient(depthLayer, theme.Surface3, theme.Base, 0.45, 0.96, 90)

    local highlight = new("Frame", {
        Name = "TopHighlight",
        Parent = main,
        Size = UDim2.new(1, -2, 0, 72),
        Position = UDim2.fromOffset(1, 1),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BackgroundTransparency = 0.95,
        BorderSizePixel = 0,
        ZIndex = 22,
    })
    corner(highlight, theme.Radius)
    gradient(highlight, Color3.fromRGB(255,255,255), theme.Accent, 0.82, 1, 0)

    local softStroke = stroke(main, Color3.fromRGB(255,255,255), 0.87, 1)

    local topbar = new("Frame", {
        Name = "Topbar",
        Parent = main,
        Size = UDim2.new(1, -28, 0, 58),
        Position = UDim2.fromOffset(14, 12),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 30,
    })

    local brandDot = new("Frame", {
        Name = "BrandDot",
        Parent = topbar,
        Size = UDim2.fromOffset(10, 10),
        Position = UDim2.fromOffset(2, 13),
        BackgroundColor3 = theme.Accent,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ZIndex = 32,
    })
    corner(brandDot, 20)
    gradient(brandDot, Color3.fromRGB(255,255,255), theme.Accent, 0.38, 0, 45)

    text(topbar, {
        Name = "Title",
        Text = windowTitle,
        Position = UDim2.fromOffset(20, 4),
        Size = UDim2.new(1, -360, 0, 22),
        Font = Enum.Font.GothamSemibold,
        SizeText = 16,
    }, theme)
    text(topbar, {
        Name = "Subtitle",
        Text = subtitle,
        Position = UDim2.fromOffset(20, 26),
        Size = UDim2.new(1, -360, 0, 18),
        Color = theme.Muted,
        SizeText = 12,
    }, theme)

    local searchWrap = glassFrame(topbar, {
        Name = "SearchWrap",
        Size = UDim2.fromOffset(190, 34),
        Position = UDim2.new(1, -238, 0, 8),
        Radius = 12,
        StrokeTransparency = 0.92,
        ZIndex = 32,
    }, theme, 3)
    searchWrap.BackgroundTransparency = 0.42

    text(searchWrap, {
        Text = "⌕",
        Position = UDim2.fromOffset(12, 1),
        Size = UDim2.fromOffset(18, 32),
        Color = theme.Muted,
        SizeText = 15,
        X = Enum.TextXAlignment.Center,
    }, theme)

    local searchBox = new("TextBox", {
        Name = "SearchBox",
        Parent = searchWrap,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(34, 0),
        Size = UDim2.new(1, -42, 1, 0),
        Font = Enum.Font.Gotham,
        Text = "",
        PlaceholderText = "Search controls",
        PlaceholderColor3 = theme.Muted,
        TextColor3 = theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 34,
    })

    local minimize = glassFrame(topbar, {
        Name = "MinimizeButton",
        Size = UDim2.fromOffset(34, 34),
        Position = UDim2.new(1, -38, 0, 8),
        Radius = 12,
        StrokeTransparency = 0.94,
        ZIndex = 32,
    }, theme, 3)
    minimize.BackgroundTransparency = 0.48
    text(minimize, {Text = "–", Size = UDim2.fromScale(1, 1), SizeText = 18, X = Enum.TextXAlignment.Center, Color = theme.Muted}, theme)
    local minHit = buttonOverlay(minimize)

    local body = new("Frame", {
        Name = "Body",
        Parent = main,
        Size = UDim2.new(1, -28, 1, -84),
        Position = UDim2.fromOffset(14, 72),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 30,
    })

    local sidebar = glassFrame(body, {
        Name = "Sidebar",
        Size = UDim2.new(0, sidebarWidth, 1, 0),
        Position = UDim2.fromOffset(0, 0),
        Radius = 14,
        StrokeTransparency = 0.93,
        ZIndex = 31,
    }, theme, 1)
    sidebar.BackgroundTransparency = 0.42
    padding(sidebar, 8, 10, 8, 10)
    local sideLayout = list(sidebar, 6)

    local sideBrand = new("Frame", {
        Name = "SubtleBrand",
        Parent = sidebar,
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        LayoutOrder = 0,
        ZIndex = 32,
    })
    text(sideBrand, {Text = "ZENITH", Size = UDim2.fromScale(1, 1), Color = theme.Muted, TextTransparency = 0.22, SizeText = 11, Font = Enum.Font.GothamSemibold, X = Enum.TextXAlignment.Center}, theme)

    local tabHolder = new("Frame", {
        Name = "ContentHolder",
        Parent = body,
        Position = UDim2.fromOffset(sidebarWidth + 12, 0),
        Size = UDim2.new(1, -(sidebarWidth + 12), 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 31,
    })

    makeDraggable(main, topbar)

    local minimized = false
    minHit.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            tween(main, {Size = UDim2.fromOffset(size.X.Offset, 74)}, 0.24, Enum.EasingStyle.Quint)
            body.Visible = false
            searchWrap.Visible = false
        else
            body.Visible = true
            searchWrap.Visible = true
            tween(main, {Size = size}, 0.24, Enum.EasingStyle.Quint)
        end
    end)

    local Window = {}
    local tabs = {}
    local controls = {}
    local searchable = {}
    local currentTab

    local function registerControl(id, api)
        if id then
            controls[id] = api
        end
    end

    local function registerSearch(label, frame)
        table.insert(searchable, {Name = string.lower(label or ""), Frame = frame})
    end

    local function runSearch()
        local q = string.lower(searchBox.Text or "")
        for _, item in ipairs(searchable) do
            if item.Frame and item.Frame.Parent then
                item.Frame.Visible = (q == "") or string.find(item.Name, q, 1, true) ~= nil
            end
        end
        for _, t in ipairs(tabs) do
            autoCanvas(t.Content, 24)
        end
    end
    searchBox:GetPropertyChangedSignal("Text"):Connect(runSearch)

    local function selectTab(tab)
        currentTab = tab
        for _, t in ipairs(tabs) do
            local selected = (t == tab)
            tween(t.Button, {
                BackgroundTransparency = selected and 0.10 or 1,
                BackgroundColor3 = selected and theme.Accent or theme.Surface2,
            }, 0.18)
            tween(t.ButtonText, {TextColor3 = selected and theme.Text or theme.Muted}, 0.18)

            if selected then
                t.Content.Visible = true
                t.Scroll.CanvasPosition = Vector2.new(0, 0)
                t.Content.GroupTransparency = 1
                tween(t.Content, {GroupTransparency = 0}, 0.22, Enum.EasingStyle.Quint)
            else
                tween(t.Content, {GroupTransparency = 1}, 0.14, Enum.EasingStyle.Quint)
                task.delay(0.15, function()
                    if currentTab ~= t and t.Content then
                        t.Content.Visible = false
                    end
                end)
            end
        end
    end

    function Window:AddTab(tabOptions)
        tabOptions = tabOptions or {}
        local tabName = tabOptions.Name or ("Tab " .. tostring(#tabs + 1))
        local icon = tabOptions.Icon

        local tabButton = glassFrame(sidebar, {
            Name = "Tab_" .. tabName,
            Size = UDim2.new(1, 0, 0, 34),
            Radius = 10,
            Stroke = false,
            Gradient = false,
            LayoutOrder = #tabs + 1,
            ZIndex = 33,
        }, theme, 3)
        tabButton.BackgroundTransparency = 1

        local iconObj
        if icon then
            iconObj = new("ImageLabel", {
                Parent = tabButton,
                BackgroundTransparency = 1,
                Image = icon,
                ImageColor3 = theme.Muted,
                Size = UDim2.fromOffset(16, 16),
                Position = UDim2.fromOffset(10, 9),
                ZIndex = 35,
            })
        end

        local btnText = text(tabButton, {
            Text = tabName,
            Position = UDim2.fromOffset(icon and 32 or 12, 0),
            Size = UDim2.new(1, icon and -40 or -20, 1, 0),
            Color = theme.Muted,
            SizeText = 13,
            Font = Enum.Font.GothamMedium,
        }, theme)
        btnText.ZIndex = 35
        local hit = buttonOverlay(tabButton)

        local content = new("CanvasGroup", {
            Name = "Content_" .. tabName,
            Parent = tabHolder,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Visible = false,
            GroupTransparency = 1,
            ZIndex = 35,
        })

        local scroll = new("ScrollingFrame", {
            Name = "Scroll",
            Parent = content,
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = theme.Accent,
            ScrollBarImageTransparency = 0.38,
            CanvasSize = UDim2.fromOffset(0, 0),
            ZIndex = 36,
        })
        padding(scroll, 2, 2, 6, 12)
        local contentList = list(scroll, 12)

        local Tab = {Button = tabButton, ButtonText = btnText, Content = content, Scroll = scroll, Sections = {}}

        hit.MouseEnter:Connect(function()
            if currentTab ~= Tab then
                tween(tabButton, {BackgroundTransparency = 0.74}, 0.16)
            end
        end)
        hit.MouseLeave:Connect(function()
            if currentTab ~= Tab then
                tween(tabButton, {BackgroundTransparency = 1}, 0.16)
            end
        end)
        hit.MouseButton1Click:Connect(function()
            selectTab(Tab)
        end)

        function Tab:AddSection(sectionOptions)
            sectionOptions = sectionOptions or {}
            local sectionName = sectionOptions.Name or "Section"

            local card = glassFrame(scroll, {
                Name = "Section_" .. sectionName,
                Size = UDim2.new(1, -4, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Radius = 15,
                Stroke = false,
                StrokeTransparency = 0.95,
                LayoutOrder = #Tab.Sections + 1,
                ZIndex = 36,
            }, theme, 2)
            card.BackgroundTransparency = 0.33
            -- Section cards avoid heavy per-card shadows; depth comes from layered transparency.
            padding(card, 14, 12, 14, 14)

            local header = new("Frame", {
                Parent = card,
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundTransparency = 1,
                LayoutOrder = 0,
                ZIndex = 37,
            })
            text(header, {Text = sectionName, Size = UDim2.fromScale(1, 1), Color = theme.Text, SizeText = 13, Font = Enum.Font.GothamSemibold}, theme)

            local separator = new("Frame", {
                Parent = card,
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Color3.fromRGB(255,255,255),
                BackgroundTransparency = 0.93,
                BorderSizePixel = 0,
                LayoutOrder = 1,
                ZIndex = 37,
            })

            local cardLayout = list(card, 8)
            header.LayoutOrder = 0
            separator.LayoutOrder = 1

            local Section = {}
            table.insert(Tab.Sections, {Name = sectionName, Container = card})
            registerSearch(sectionName, card)

            local function refresh()
                autoCanvas(scroll, 26)
            end

            local function controlBase(kind, name, height, icon)
                local row = glassFrame(card, {
                    Name = kind .. "_" .. name,
                    Size = UDim2.new(1, 0, 0, height or 38),
                    Radius = 12,
                    Stroke = false,
                    Gradient = false,
                    LayoutOrder = #card:GetChildren() + 1,
                    ZIndex = 38,
                }, theme, 3)
                row.BackgroundTransparency = 0.56
                row.ClipsDescendants = true

                local accentLine = new("Frame", {
                    Parent = row,
                    Size = UDim2.new(0, 2, 0, 16),
                    Position = UDim2.fromOffset(0, math.floor(((height or 38) - 16) / 2)),
                    BackgroundColor3 = theme.Accent,
                    BackgroundTransparency = 0.42,
                    BorderSizePixel = 0,
                    ZIndex = 39,
                })
                corner(accentLine, 8)

                if icon then
                    new("ImageLabel", {
                        Parent = row,
                        BackgroundTransparency = 1,
                        Image = icon,
                        ImageColor3 = theme.Muted,
                        Size = UDim2.fromOffset(15, 15),
                        Position = UDim2.fromOffset(12, math.floor(((height or 38) - 15) / 2)),
                        ZIndex = 39,
                    })
                end
                local label = text(row, {
                    Text = name,
                    Position = UDim2.fromOffset(icon and 34 or 14, 0),
                    Size = UDim2.new(1, -160, 1, 0),
                    SizeText = 13,
                    Font = Enum.Font.GothamMedium,
                }, theme)
                label.ZIndex = 39
                registerSearch(name, row)
                refresh()
                return row, label
            end

            function Section:AddButton(opts)
                opts = opts or {}
                local name = opts.Name or "Button"
                local callback = opts.Callback or function() end
                local row, label = controlBase("Button", name, 38, opts.Icon)
                local hit = buttonOverlay(row)

                hit.MouseEnter:Connect(function()
                    tween(row, {BackgroundTransparency = 0.44}, 0.16)
                    tween(label, {TextColor3 = theme.Text}, 0.16)
                end)
                hit.MouseLeave:Connect(function()
                    tween(row, {BackgroundTransparency = 0.56}, 0.16)
                end)
                hit.MouseButton1Down:Connect(function()
                    local p = UserInputService:GetMouseLocation()
                    createRipple(row, theme, p.X, p.Y)
                    tween(row, {Size = UDim2.new(1, -2, 0, 37)}, 0.07, Enum.EasingStyle.Quad)
                    task.delay(0.08, function()
                        if row then tween(row, {Size = UDim2.new(1, 0, 0, 38)}, 0.12, Enum.EasingStyle.Quad) end
                    end)
                end)
                hit.MouseButton1Click:Connect(function()
                    pcall(callback)
                end)
                return row
            end

            function Section:AddToggle(opts)
                opts = opts or {}
                local name = opts.Name or "Toggle"
                local state = opts.Default or false
                local callback = opts.Callback or function() end
                local flag = opts.Flag or name
                local row = controlBase("Toggle", name, 38, opts.Icon)

                local capsule = glassFrame(row, {
                    Name = "Capsule",
                    Parent = row,
                    Size = UDim2.fromOffset(44, 22),
                    Position = UDim2.new(1, -58, 0.5, -11),
                    Radius = 22,
                    Stroke = false,
                    Gradient = false,
                    ZIndex = 42,
                }, theme, 3)
                capsule.BackgroundTransparency = state and 0.18 or 0.62
                capsule.BackgroundColor3 = state and theme.Accent or theme.Surface3

                local knob = new("Frame", {
                    Parent = capsule,
                    Size = UDim2.fromOffset(18, 18),
                    Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.fromOffset(2, 2),
                    BackgroundColor3 = Color3.fromRGB(255,255,255),
                    BackgroundTransparency = 0.08,
                    BorderSizePixel = 0,
                    ZIndex = 43,
                })
                corner(knob, 18)

                local function draw(skip)
                    local props = {
                        BackgroundColor3 = state and theme.Accent or theme.Surface3,
                        BackgroundTransparency = state and 0.18 or 0.62,
                    }
                    local kpos = state and UDim2.new(1, -20, 0.5, -9) or UDim2.fromOffset(2, 2)
                    if skip then
                        capsule.BackgroundColor3 = props.BackgroundColor3
                        capsule.BackgroundTransparency = props.BackgroundTransparency
                        knob.Position = kpos
                    else
                        tween(capsule, props, 0.18, Enum.EasingStyle.Quint)
                        tween(knob, {Position = kpos}, 0.18, Enum.EasingStyle.Quint)
                    end
                    pcall(callback, state)
                end

                local hit = buttonOverlay(row)
                hit.MouseButton1Click:Connect(function()
                    state = not state
                    draw(false)
                end)
                draw(true)

                local api = {
                    Set = function(_, v) state = v and true or false; draw(false) end,
                    Get = function() return state end,
                    Type = "Toggle",
                }
                registerControl(flag, api)
                return api
            end

            function Section:AddSlider(opts)
                opts = opts or {}
                local name = opts.Name or "Slider"
                local min, max = opts.Min or 0, opts.Max or 100
                local value = math.clamp(opts.Default or min, min, max)
                local rounding = opts.Rounding or 0
                local callback = opts.Callback or function() end
                local flag = opts.Flag or name

                local row = controlBase("Slider", name, 50, opts.Icon)
                local valueLabel = text(row, {
                    Text = tostring(value),
                    Position = UDim2.new(1, -88, 0, 0),
                    Size = UDim2.fromOffset(74, 24),
                    Color = theme.Muted,
                    SizeText = 12,
                    X = Enum.TextXAlignment.Right,
                }, theme)

                local track = new("Frame", {
                    Parent = row,
                    Position = UDim2.fromOffset(14, 34),
                    Size = UDim2.new(1, -28, 0, 5),
                    BackgroundColor3 = theme.Surface3,
                    BackgroundTransparency = 0.48,
                    BorderSizePixel = 0,
                    ZIndex = 41,
                })
                corner(track, 6)

                local fill = new("Frame", {
                    Parent = track,
                    Size = UDim2.fromScale(0, 1),
                    BackgroundColor3 = theme.Accent,
                    BackgroundTransparency = 0.08,
                    BorderSizePixel = 0,
                    ZIndex = 42,
                })
                corner(fill, 6)

                local knob = new("Frame", {
                    Parent = track,
                    Size = UDim2.fromOffset(12, 12),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0, 0.5),
                    BackgroundColor3 = theme.Text,
                    BackgroundTransparency = 0.04,
                    BorderSizePixel = 0,
                    ZIndex = 43,
                })
                corner(knob, 12)

                local function round(v)
                    if rounding > 0 then
                        local m = 10 ^ rounding
                        return math.floor(v * m + 0.5) / m
                    end
                    return math.floor(v + 0.5)
                end

                local function set(v, noCallback)
                    value = math.clamp(v, min, max)
                    local pct = (value - min) / (max - min)
                    tween(fill, {Size = UDim2.fromScale(pct, 1)}, 0.12, Enum.EasingStyle.Quad)
                    tween(knob, {Position = UDim2.fromScale(pct, 0.5)}, 0.12, Enum.EasingStyle.Quad)
                    valueLabel.Text = tostring(round(value))
                    if not noCallback then pcall(callback, value) end
                end

                local dragging = false
                local function inputToValue(input)
                    local pct = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                    set(min + (max - min) * pct)
                end
                track.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        inputToValue(input)
                    end
                end)
                UserInputService.InputChanged:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        inputToValue(input)
                    end
                end)
                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                    end
                end)

                set(value, true)
                local api = {
                    Set = function(_, v) set(v) end,
                    Get = function() return value end,
                    Type = "Slider",
                }
                registerControl(flag, api)
                return api
            end

            local function makeDropdown(opts, multi)
                opts = opts or {}
                local name = opts.Name or (multi and "MultiDropdown" or "Dropdown")
                local options = opts.Options or {}
                local callback = opts.Callback or function() end
                local flag = opts.Flag or name
                local expanded = false
                local selected = multi and shallowCopy(opts.Default or {}) or (opts.Default or options[1] or "")
                local baseHeight = 40
                local optionHeight = 30
                local maxVisible = 5

                local row = controlBase(multi and "MultiDropdown" or "Dropdown", name, baseHeight, opts.Icon)
                row.ClipsDescendants = true

                local valueText = text(row, {
                    Text = "",
                    Position = UDim2.new(0, 14, 0, 18),
                    Size = UDim2.new(1, -50, 0, 18),
                    Color = theme.Muted,
                    SizeText = 12,
                }, theme)
                local arrow = text(row, {
                    Text = "⌄",
                    Position = UDim2.new(1, -34, 0, 7),
                    Size = UDim2.fromOffset(22, 22),
                    Color = theme.Muted,
                    SizeText = 16,
                    X = Enum.TextXAlignment.Center,
                }, theme)

                local listFrame = new("Frame", {
                    Parent = row,
                    Position = UDim2.fromOffset(8, baseHeight),
                    Size = UDim2.new(1, -16, 0, 0),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    ZIndex = 42,
                    ClipsDescendants = true,
                })
                list(listFrame, 4)

                local function labelText()
                    if multi then
                        if #selected == 0 then return "None" end
                        return table.concat(selected, ", ")
                    end
                    return tostring(selected)
                end
                local function updateLabel()
                    valueText.Text = labelText()
                end

                local function contains(v)
                    for _, item in ipairs(selected) do
                        if item == v then return true end
                    end
                    return false
                end

                local function rebuild()
                    for _, child in ipairs(listFrame:GetChildren()) do
                        if child:IsA("TextButton") then child:Destroy() end
                    end
                    for _, opt in ipairs(options) do
                        local optBtn = new("TextButton", {
                            Parent = listFrame,
                            Size = UDim2.new(1, 0, 0, optionHeight - 4),
                            BackgroundColor3 = theme.Surface3,
                            BackgroundTransparency = 0.62,
                            BorderSizePixel = 0,
                            Text = multi and ((contains(opt) and "✓  " or "   ") .. tostring(opt)) or tostring(opt),
                            TextColor3 = theme.Text,
                            TextSize = 12,
                            Font = Enum.Font.Gotham,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            AutoButtonColor = false,
                            ZIndex = 43,
                        })
                        corner(optBtn, 9)
                        padding(optBtn, 10, 0, 10, 0)
                        optBtn.MouseEnter:Connect(function()
                            tween(optBtn, {BackgroundTransparency = 0.48}, 0.12)
                        end)
                        optBtn.MouseLeave:Connect(function()
                            tween(optBtn, {BackgroundTransparency = 0.62}, 0.12)
                        end)
                        optBtn.MouseButton1Click:Connect(function()
                            if multi then
                                local found
                                for i, v in ipairs(selected) do
                                    if v == opt then found = i; break end
                                end
                                if found then table.remove(selected, found) else table.insert(selected, opt) end
                                rebuild()
                                updateLabel()
                                pcall(callback, selected)
                            else
                                selected = opt
                                updateLabel()
                                pcall(callback, selected)
                                expanded = false
                                tween(row, {Size = UDim2.new(1, 0, 0, baseHeight)}, 0.18)
                                tween(arrow, {Rotation = 0}, 0.18)
                            end
                        end)
                    end
                end

                local hit = buttonOverlay(row)
                hit.Size = UDim2.new(1, 0, 0, baseHeight)
                hit.MouseButton1Click:Connect(function()
                    expanded = not expanded
                    rebuild()
                    local count = math.min(#options, maxVisible)
                    local target = expanded and (baseHeight + count * optionHeight + 8) or baseHeight
                    tween(row, {Size = UDim2.new(1, 0, 0, target)}, 0.20, Enum.EasingStyle.Quint)
                    tween(listFrame, {Size = expanded and UDim2.new(1, -16, 0, count * optionHeight) or UDim2.new(1, -16, 0, 0)}, 0.20, Enum.EasingStyle.Quint)
                    tween(arrow, {Rotation = expanded and 180 or 0}, 0.20)
                    refresh()
                end)

                updateLabel()
                local api = {
                    Set = function(_, v) selected = multi and (v or {}) or v; updateLabel(); pcall(callback, selected) end,
                    Get = function() return selected end,
                    Type = multi and "MultiDropdown" or "Dropdown",
                }
                registerControl(flag, api)
                return api
            end

            function Section:AddDropdown(opts)
                return makeDropdown(opts, false)
            end

            function Section:AddMultiDropdown(opts)
                return makeDropdown(opts, true)
            end

            function Section:AddTextbox(opts)
                opts = opts or {}
                local name = opts.Name or "Textbox"
                local value = opts.Default or ""
                local callback = opts.Callback or function() end
                local flag = opts.Flag or name
                local row = controlBase("Textbox", name, 40, opts.Icon)

                local box = new("TextBox", {
                    Parent = row,
                    Position = UDim2.new(0, 112, 0.5, -14),
                    Size = UDim2.new(1, -126, 0, 28),
                    BackgroundColor3 = theme.Surface3,
                    BackgroundTransparency = 0.58,
                    BorderSizePixel = 0,
                    Font = Enum.Font.Gotham,
                    Text = value,
                    PlaceholderText = opts.Placeholder or "Type...",
                    PlaceholderColor3 = theme.Muted,
                    TextColor3 = theme.Text,
                    TextSize = 12,
                    ClearTextOnFocus = false,
                    ZIndex = 42,
                })
                corner(box, 10)
                padding(box, 10, 0, 10, 0)
                box.Focused:Connect(function()
                    tween(box, {BackgroundTransparency = 0.45}, 0.16)
                end)
                box.FocusLost:Connect(function()
                    tween(box, {BackgroundTransparency = 0.58}, 0.16)
                    value = box.Text
                    pcall(callback, value)
                end)

                local api = {
                    Set = function(_, v) value = tostring(v or ""); box.Text = value; pcall(callback, value) end,
                    Get = function() return value end,
                    Type = "Textbox",
                }
                registerControl(flag, api)
                return api
            end

            function Section:AddKeybind(opts)
                opts = opts or {}
                local name = opts.Name or "Keybind"
                local key = opts.DefaultKey or Enum.KeyCode.E
                local callback = opts.Callback or function() end
                local flag = opts.Flag or name
                local listening = false
                local row = controlBase("Keybind", name, 38, opts.Icon)

                local keyBtn = new("TextButton", {
                    Parent = row,
                    Position = UDim2.new(1, -84, 0.5, -13),
                    Size = UDim2.fromOffset(70, 26),
                    BackgroundColor3 = theme.Surface3,
                    BackgroundTransparency = 0.58,
                    BorderSizePixel = 0,
                    Text = key.Name or tostring(key),
                    TextColor3 = theme.Text,
                    TextSize = 12,
                    Font = Enum.Font.GothamMedium,
                    AutoButtonColor = false,
                    ZIndex = 42,
                })
                corner(keyBtn, 10)

                keyBtn.MouseButton1Click:Connect(function()
                    listening = true
                    keyBtn.Text = "..."
                    tween(keyBtn, {BackgroundTransparency = 0.44}, 0.16)
                end)

                UserInputService.InputBegan:Connect(function(input, processed)
                    if processed then return end
                    if listening then
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            key = input.KeyCode
                            keyBtn.Text = key.Name
                            listening = false
                            tween(keyBtn, {BackgroundTransparency = 0.58}, 0.16)
                        end
                    elseif input.KeyCode == key then
                        pcall(callback)
                    end
                end)

                local api = {
                    Set = function(_, v) key = v; keyBtn.Text = v.Name or tostring(v) end,
                    Get = function() return key end,
                    Type = "Keybind",
                }
                registerControl(flag, api)
                return api
            end

            function Section:AddColorPicker(opts)
                opts = opts or {}
                local name = opts.Name or "ColorPicker"
                local color = opts.Default or theme.Accent
                local callback = opts.Callback or function() end
                local flag = opts.Flag or name
                local open = false
                local row = controlBase("ColorPicker", name, 40, opts.Icon)
                row.ClipsDescendants = true

                local preview = new("Frame", {
                    Parent = row,
                    Position = UDim2.new(1, -44, 0, 8),
                    Size = UDim2.fromOffset(24, 24),
                    BackgroundColor3 = color,
                    BorderSizePixel = 0,
                    ZIndex = 43,
                })
                corner(preview, 8)
                stroke(preview, Color3.fromRGB(255,255,255), 0.80, 1)

                local picker = new("Frame", {
                    Parent = row,
                    Position = UDim2.fromOffset(14, 44),
                    Size = UDim2.new(1, -28, 0, 0),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    ClipsDescendants = true,
                    ZIndex = 43,
                })
                list(picker, 6)

                local rSlider, gSlider, bSlider
                local function makeMini(name2, initial, onChanged)
                    local wrap = new("Frame", {Parent = picker, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, ZIndex = 44})
                    text(wrap, {Text = name2, Size = UDim2.fromOffset(18, 24), Color = theme.Muted, SizeText = 11, X = Enum.TextXAlignment.Left}, theme)
                    local track = new("Frame", {Parent = wrap, Position = UDim2.fromOffset(24, 10), Size = UDim2.new(1, -34, 0, 4), BackgroundColor3 = theme.Surface3, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 44})
                    corner(track, 4)
                    local fill = new("Frame", {Parent = track, Size = UDim2.fromScale(initial, 1), BackgroundColor3 = theme.Accent, BorderSizePixel = 0, ZIndex = 45})
                    corner(fill, 4)
                    local dragging = false
                    local val = initial
                    local function setFromInput(input)
                        val = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                        fill.Size = UDim2.fromScale(val, 1)
                        onChanged(val)
                    end
                    track.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; setFromInput(input) end
                    end)
                    UserInputService.InputChanged:Connect(function(input)
                        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then setFromInput(input) end
                    end)
                    UserInputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
                    end)
                    return {Set = function(v) val = v; fill.Size = UDim2.fromScale(v, 1) end, Get = function() return val end}
                end

                local function applyColor(noCallback)
                    color = Color3.new(rSlider:Get(), gSlider:Get(), bSlider:Get())
                    preview.BackgroundColor3 = color
                    if not noCallback then pcall(callback, color) end
                end

                rSlider = makeMini("R", color.R, function() applyColor(false) end)
                gSlider = makeMini("G", color.G, function() applyColor(false) end)
                bSlider = makeMini("B", color.B, function() applyColor(false) end)

                local hit = buttonOverlay(row)
                hit.Size = UDim2.new(1, 0, 0, 40)
                hit.MouseButton1Click:Connect(function()
                    open = not open
                    local h = open and 128 or 40
                    tween(row, {Size = UDim2.new(1, 0, 0, h)}, 0.2, Enum.EasingStyle.Quint)
                    tween(picker, {Size = UDim2.new(1, -28, 0, open and 80 or 0)}, 0.2, Enum.EasingStyle.Quint)
                    refresh()
                end)

                local api = {
                    Set = function(_, c)
                        color = c
                        rSlider:Set(c.R); gSlider:Set(c.G); bSlider:Set(c.B)
                        applyColor(false)
                    end,
                    Get = function() return color end,
                    Type = "ColorPicker",
                }
                registerControl(flag, api)
                return api
            end

            function Section:Notify(opts)
                Window:Notify(opts)
            end

            refresh()
            return Section
        end

        table.insert(tabs, Tab)
        if #tabs == 1 then
            selectTab(Tab)
        end
        return Tab
    end

    function Window:Notify(opts)
        opts = opts or {}
        local message = opts.Text or opts.Message or "Notification"
        local duration = opts.Duration or 3

        local notif = glassFrame(gui, {
            Name = "Notification",
            Size = UDim2.fromOffset(255, 44),
            Position = UDim2.new(1, 280, 1, -74),
            Radius = 14,
            Stroke = false,
            ZIndex = 200,
        }, theme, 1)
        notif.BackgroundTransparency = 0.26
        shadow(notif, 34, 0.66)
        padding(notif, 12, 8, 12, 8)
        text(notif, {Text = message, Size = UDim2.fromScale(1, 1), SizeText = 13, Wrapped = true}, theme)

        tween(notif, {Position = UDim2.new(1, -270, 1, -74)}, 0.28, Enum.EasingStyle.Quint)
        task.delay(duration, function()
            if notif and notif.Parent then
                tween(notif, {Position = UDim2.new(1, 280, 1, -74), BackgroundTransparency = 1}, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                task.wait(0.25)
                if notif then notif:Destroy() end
            end
        end)
    end

    function Window:SaveConfig(fileName)
        local write = fs()
        if not write then
            warn("[ZenithUI] writefile unavailable; config cannot be saved.")
            return false
        end
        local data = {}
        for id, api in pairs(controls) do
            local ok, value = pcall(api.Get)
            if ok then
                if typeof(value) == "Color3" then
                    data[id] = {__type = "Color3", r = value.R, g = value.G, b = value.B}
                elseif typeof(value) == "EnumItem" then
                    data[id] = {__type = "EnumItem", enum = tostring(value.EnumType), name = value.Name}
                else
                    data[id] = value
                end
            end
        end
        write(fileName or "ZenithUI_Config.json", HttpService:JSONEncode(data))
        return true
    end

    function Window:LoadConfig(fileName)
        local _, read, isfile = fs()
        if not read then
            warn("[ZenithUI] readfile unavailable; config cannot be loaded.")
            return false
        end
        local path = fileName or "ZenithUI_Config.json"
        if isfile and not isfile(path) then return false end
        local ok, raw = pcall(read, path)
        if not ok or not raw then return false end
        local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if not ok2 or typeof(data) ~= "table" then return false end
        for id, saved in pairs(data) do
            local api = controls[id]
            if api and api.Set then
                if typeof(saved) == "table" and saved.__type == "Color3" then
                    pcall(api.Set, api, Color3.new(saved.r, saved.g, saved.b))
                elseif typeof(saved) == "table" and saved.__type == "EnumItem" and saved.name then
                    -- Most keybinds use Enum.KeyCode; fallback safely.
                    local enumValue = Enum.KeyCode[saved.name]
                    if enumValue then pcall(api.Set, api, enumValue) end
                else
                    pcall(api.Set, api, saved)
                end
            end
        end
        return true
    end

    function Window:Destroy()
        tween(main, {Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1}, 0.20, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.delay(0.22, function()
            if gui then gui:Destroy() end
        end)
    end

    Window.Root = main
    Window.Gui = gui
    Window.Theme = theme

    return Window
end

return ZenithUI
