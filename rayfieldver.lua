--[[
    Surreal Hub
    Total Roblox Drama — Camp
    Interface: Rayfield Gen 2
    v1.0.0
]]

--==================================================
-- LOAD RAYFIELD GEN 2
--==================================================
local Rayfield
local ok, result = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/gen2"))()
end)

if ok and result then
    Rayfield = result
else
    return warn("[Surreal Hub] Failed to load Rayfield Gen 2: " .. tostring(result))
end

--==================================================
-- SERVICES
--==================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local TextChatService   = game:GetService("TextChatService")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera
local RS          = ReplicatedStorage

--==================================================
-- EXECUTOR FALLBACKS
--==================================================
local function ensureFunction(name, fallback)
    local env = getfenv(0)
    if type(env[name]) ~= "function" then env[name] = fallback end
end

ensureFunction("writefile",         function() end)
ensureFunction("readfile",          function() return "" end)
ensureFunction("makefolder",        function() end)
ensureFunction("isfile",            function() return false end)
ensureFunction("isfolder",          function() return false end)
ensureFunction("listfiles",         function() return {} end)
ensureFunction("delfile",           function() end)
ensureFunction("getcustomasset",    function() return "" end)
ensureFunction("firetouchinterest", function() end)
ensureFunction("fireclickdetector", function() end)
ensureFunction("getconnections",    function() return {} end)
ensureFunction("request",           http_request or (syn and syn.request) or function() end)

--==================================================
-- UTILITIES MODULE
--==================================================
local Utilities = {}
local MAX_NOTIFY_DURATION = 5
local SurrealWindow = nil

function Utilities.setWindow(win)
    SurrealWindow = win
end

function Utilities.safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then warn("[Surreal Hub] Callback error: " .. tostring(err)) end
    end
end

function Utilities.notify(title, content, duration)
    local safeDuration = math.min(duration or MAX_NOTIFY_DURATION, MAX_NOTIFY_DURATION)
    pcall(function()
        if SurrealWindow then
            SurrealWindow:Notify({
                title    = title,
                content  = content,
                duration = safeDuration,
            })
        end
    end)
end

function Utilities.forEachDescendant(root, className, callback)
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA(className) then pcall(callback, obj) end
    end
end

function Utilities.forEachBasePart(callback)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("MeshPart") then pcall(callback, obj) end
    end
end

function Utilities.nameContains(part, needle)
    return part.Name:lower():find(needle, 1, true) ~= nil
end

function Utilities.hasBrick(part, name)
    return part.BrickColor.Name:lower() == name:lower()
end

function Utilities.character()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

function Utilities.rootPart()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

function Utilities.humanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

function Utilities.teleportTo(x, y, z)
    local root = Utilities.rootPart()
    if root then root.CFrame = CFrame.new(x, y, z) end
end

--==================================================
-- UTILITY REGISTRY
--==================================================
local UtilityRegistry = {
    { id = "genesis_sniper", name = "Genesis Sniper",
      source = "https://raw.githubusercontent.com/GenesisFE/Genesis/main/Obfuscations/Sniper", enabled = true },
    { id = "infinite_yield", name = "Infinite Yield",
      source = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source", enabled = true },
    { id = "energize", name = "Energize",
      source = "https://pastebin.com/raw/Cfeu2ZPc", enabled = true },
}

function Utilities.launchUtility(id)
    for _, entry in ipairs(UtilityRegistry) do
        if entry.id == id and entry.enabled then
            local ok, chunk = pcall(function() return game:HttpGet(entry.source, true) end)
            if ok and chunk then
                local fn = loadstring(chunk)
                if fn then
                    task.spawn(fn)
                    Utilities.notify("Utility Loaded", entry.name, 4)
                end
            end
            return
        end
    end
end

--==================================================
-- TYPEFACE MANAGER
--==================================================
local TypefaceManager = {}
local TYPEFACE_BLACKLIST = {
    "Chat","BubbleChat","ChatChannelParentFrame","MessageLogDisplay",
    "DevConsoleMaster","DeveloperConsole","RobloxGui","RobloxPromptGui",
    "PlayerList","StatLabel","StatusText",
}

local function applyTypefaceToObject(obj, jsonName, attrKey, scale)
    if not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then return end
    if obj:FindFirstAncestorOfClass("CoreGui") or obj:FindFirstAncestor("RobloxGui") then return end
    for _, blocked in ipairs(TYPEFACE_BLACKLIST) do
        if obj.Name == blocked or obj:FindFirstAncestor(blocked) then return end
    end
    obj.FontFace = Font.new(getcustomasset(jsonName))
    if not obj:GetAttribute(attrKey) then
        if obj.TextSize > 0 then obj.TextSize = math.clamp(obj.TextSize * scale, 8, 100) end
        obj:SetAttribute(attrKey, true)
    end
end

function TypefaceManager.load(id, displayName, ttfFile, jsonFile, source, attrKey)
    if not isfile(ttfFile) then writefile(ttfFile, game:HttpGet(source)) end
    writefile(jsonFile, HttpService:JSONEncode({
        name = displayName,
        faces = {{ name = "Regular", weight = 400, style = "normal",
                   assetId = getcustomasset(ttfFile) }},
    }))
    for _, obj in ipairs(game:GetDescendants()) do
        pcall(applyTypefaceToObject, obj, jsonFile, attrKey, 0.6)
    end
    game.DescendantAdded:Connect(function(obj)
        task.wait(0.1)
        pcall(applyTypefaceToObject, obj, jsonFile, attrKey, 0.6)
    end)
    Utilities.notify("Typeface Applied", displayName .. " is now active.", 4)
end

--==================================================
-- RUNTIME STATE
--==================================================
local State = {
    voteConn        = nil,
    exposeConn      = nil,
    juryConn        = nil,
    exileConn       = nil,
    printConn       = nil,
    roundConn       = nil,
    swordFightConn  = nil,
    statueConn      = nil,

    autoWinObby     = false,
    autoCollect     = false,
    autoMath        = false,
    mathDelay       = 0,
    dodgeballGuard  = false,
    paintballGuard  = false,

    cliffESP         = false,
    cliffObjects     = {},
    cliffAddedConn   = nil,
    cliffRemovedConn = nil,
    cliffRenderConn  = nil,

    nameplatesEnabled   = false,
    nameplatePlayerConn = nil,
    nameplateCharConns  = {},

    waterWalkEnabled = false,
    followEnabled    = false,
}

--==================================================
-- WINDOW
--==================================================
local Window = Rayfield:CreateWindow({
    name     = "Surreal Hub (Camp)",
    subtitle = "by surrre4L",
    icon     = "rbxassetid://108950683571835",
    theme    = "default",
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "SurrealHub",
        folder   = "Surreal Hub",
    },
})

Utilities.setWindow(Window)

--==================================================
-- TABS (Lucide icons)
--==================================================
local Main         = Window:CreateTab({ name = "Main",       icon = "home" })
local Challenges   = Window:CreateTab({ name = "Challenges", icon = "trophy" })
local Morphs       = Window:CreateTab({ name = "Morphs",     icon = "user" })
local Visuals      = Window:CreateTab({ name = "Visuals",    icon = "eye" })
local TrollTab     = Window:CreateTab({ name = "Troll",      icon = "zap" })
local UtilitiesTab = Window:CreateTab({ name = "Utilities",  icon = "wrench" })

--==================================================
-- MAIN — VOTES
--==================================================
Main:CreateSection({ name = "Votes", icon = "bar-chart" })

Main:CreateToggle({
    name = "Notify Votes",
    description = "notifies you when someone casts a vote",
    icon = "bell-ring",
    value = false,
    flag = "NotifyVotes",
    callback = Utilities.safe(function(enabled)
        if State.voteConn then State.voteConn:Disconnect(); State.voteConn = nil end
        if not enabled then return end
        local season = RS:FindFirstChild("Season")
        local votes = season and season:FindFirstChild("Voting") and season.Voting:FindFirstChild("Votes")
        if not votes then return end
        State.voteConn = votes.ChildAdded:Connect(function(vote)
            local voter = season.Players:FindFirstChild(vote.Value)
            local target = season.Players:FindFirstChild(vote.Name)
            Utilities.notify("Vote Update",
                (voter and voter.Value or vote.Value) .. " voted for " .. (target and target.Value or vote.Name), 4)
        end)
    end),
})

Main:CreateToggle({
    name = "Announce Votes",
    description = "says every cast vote in the general chat",
    icon = "megaphone",
    value = false,
    flag = "ExposeVotes",
    callback = Utilities.safe(function(enabled)
        if State.exposeConn then State.exposeConn:Disconnect(); State.exposeConn = nil end
        if not enabled then return end
        local season = RS:FindFirstChild("Season")
        local votes = season and season:FindFirstChild("Voting") and season.Voting:FindFirstChild("Votes")
        if not votes then return end
        State.exposeConn = votes.ChildAdded:Connect(function(vote)
            local voter = season.Players:FindFirstChild(vote.Value)
            local target = season.Players:FindFirstChild(vote.Name)
            pcall(function()
                TextChatService.TextChannels.RBXGeneral:SendAsync(
                    (voter and voter.Value or vote.Value) .. " voted for " .. (target and target.Value or vote.Name))
            end)
        end)
    end),
})

Main:CreateToggle({
    name = "View Jury Votes",
    description = "notifies when a juror votes a finalist",
    icon = "users",
    value = false,
    flag = "ViewJuryVotes",
    callback = Utilities.safe(function(enabled)
        if State.juryConn then
            for _, conn in ipairs(State.juryConn) do conn:Disconnect() end
            State.juryConn = nil
        end
        if not enabled then return end
        local season = RS:FindFirstChild("Season")
        local jury = season and season:FindFirstChild("Jury")
        if not jury then return end
        State.juryConn = {}
        local function watchJuror(juror)
            local list = juror:WaitForChild("List")
            table.insert(State.juryConn, list.ChildAdded:Connect(function(vote)
                local voter = juror.Value
                local target = vote.Value
                if season.Players:FindFirstChild(vote.Name) then
                    target = season.Players[vote.Name].Value
                end
                Utilities.notify("Jury Vote", voter .. " voted for " .. target, 4)
            end))
        end
        for _, juror in ipairs(jury:GetChildren()) do watchJuror(juror) end
        table.insert(State.juryConn, jury.ChildAdded:Connect(watchJuror))
    end),
})

Main:CreateToggle({
    name = "View Exile Votes",
    description = "see who will be voted to exile",
    icon = "door-open",
    value = false,
    flag = "ViewExileVotes",
    callback = Utilities.safe(function(enabled)
        if State.exileConn then State.exileConn:Disconnect(); State.exileConn = nil end
        if not enabled then return end
        local twists = RS:FindFirstChild("Season") and RS.Season:FindFirstChild("Twists")
        local ev = twists and twists:FindFirstChild("ExileVoting")
        local votes = ev and ev:FindFirstChild("Votes")
        if not votes then return end
        State.exileConn = votes.ChildAdded:Connect(function(vote)
            local voter = RS.Season.Players:FindFirstChild(vote.Value)
            local target = RS.Season.Players:FindFirstChild(vote.Name)
            local message = (voter and voter.Value or vote.Value) .. " voted to exile " .. (target and target.Value or vote.Name)
            Utilities.notify("Exile Vote", message, 4)
            print(message)
        end)
    end),
})

Main:CreateToggle({
    name = "Print Votes",
    description = "Logs every votes in console (notify votes only)",
    icon = "terminal",
    value = false,
    flag = "PrintVotes",
    callback = Utilities.safe(function(enabled)
        if State.printConn then State.printConn:Disconnect(); State.printConn = nil end
        if not enabled then return end
        local season = RS:FindFirstChild("Season")
        local votes = season and season:FindFirstChild("Voting") and season.Voting:FindFirstChild("Votes")
        if not votes then return end
        State.printConn = votes.ChildAdded:Connect(function(vote)
            local voter = season.Players:FindFirstChild(vote.Value)
            local target = season.Players:FindFirstChild(vote.Name)
            print((voter and voter.Value or vote.Value) .. " voted for " .. (target and target.Value or vote.Name))
        end)
    end),
})

--==================================================
-- MAIN — STATUE
--==================================================
Main:CreateSection({ name = "Statue", icon = "search" })

Main:CreateButton({
    name = "Find Statue (60% Spawn)",
    description = "get the statue",
    icon = "search",
    callback = Utilities.safe(function()
        local idols = workspace:FindFirstChild("Idols")
        if not idols then return end
        for _, obj in ipairs(idols:GetDescendants()) do
            if obj.Name == "Bag" or obj.Name == "SafetyStatue" then
                local hit = obj:FindFirstChild("hit")
                if hit then
                    hit.CanCollide = false
                    hit.Transparency = 1
                    task.wait()
                    local torso = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Torso")
                    if torso then hit.Position = torso.Position end
                    task.wait()
                end
            end
        end
    end),
})

Main:CreateButton({
    name = "Get Statue on Spawn",
    description = "gives you the statue the moment u spawn",
    icon = "map-pin",
    callback = Utilities.safe(function()
        local function tryAttach(obj)
            if not obj:IsA("BasePart") or obj.Name ~= "hit" then return end
            local parent = obj.Parent
            if not parent or (parent.Name ~= "Bag" and parent.Name ~= "SafetyStatue") then return end
            task.wait(0.1)
            obj.CanCollide = false
            obj.Transparency = 1
            task.spawn(function()
                while obj and obj.Parent do
                    local root = Utilities.rootPart()
                    if root then obj.CFrame = root.CFrame end
                    task.wait(0.05)
                end
            end)
        end
        if not State.statueConn then
            State.statueConn = workspace.DescendantAdded:Connect(tryAttach)
        end
        for _, obj in ipairs(workspace:GetDescendants()) do tryAttach(obj) end
    end),
})

Main:CreateButton({
    name = "Detect Who has Statue",
    description = "notifies who has the statue",
    icon = "scan-eye",
    callback = Utilities.safe(function()
        local season = RS:FindFirstChild("Season")
        if not season or not season:FindFirstChild("Twists") then return end
        local idol = season.Twists:FindFirstChild("Idol")
        if not idol then return end
        if idol.Value == "" then
            Utilities.notify("Statue Owner", "No one currently holds the statue.", 4)
        else
            local owner = season.Players:FindFirstChild(idol.Value)
            Utilities.notify("Statue Owner", (owner and owner.Value or idol.Value) .. " has the statue.", 4)
        end
    end),
})

--==================================================
-- MAIN — EXTRAS
--==================================================
Main:CreateSection({ name = "Extras", icon = "sparkles" })

Main:CreateToggle({
    name = "Auto Detect Round",
    description = "detects the round twist",
    icon = "refresh-cw",
    value = false,
    flag = "AutoDetectRound",
    callback = Utilities.safe(function(enabled)
        if State.roundConn then State.roundConn:Disconnect(); State.roundConn = nil end
        if not enabled then return end
        local season = RS:FindFirstChild("Season")
        if not season or not season:FindFirstChild("Twists") then return end
        local twist = season.Twists:FindFirstChild("CurrentTwist")
        if not twist then return end
        State.roundConn = twist:GetPropertyChangedSignal("Value"):Connect(function()
            local names = {
                normal = "Normal Round", purge = "Purge Round",
                ["double"] = "Double Elimination", singleswap = "Sike Round",
                exile = "Exile Vote Round", votereveal = "Vote Reveal",
            }
            if names[twist.Value] then Utilities.notify("Round Detected", names[twist.Value], 4) end
        end)
    end),
})

Main:CreateButton({
    name = "Detect Teamers",
    description = "scans every account if they have friends on the same lobby",
    icon = "shield-alert",
    callback = Utilities.safe(function()
        local season = RS:FindFirstChild("Season")
        local playersFolder = season and season:FindFirstChild("Players")
        if not playersFolder then return end
        local function gameNameOf(plr)
            local entry = playersFolder:FindFirstChild(plr.Name)
            return (entry and entry.Value ~= "") and entry.Value or plr.Name
        end
        local found = false
        local allPlayers = Players:GetPlayers()
        for i = 1, #allPlayers do
            for j = i + 1, #allPlayers do
                local p1, p2 = allPlayers[i], allPlayers[j]
                local ok, areFriends = pcall(function() return p1:IsFriendsWith(p2.UserId) end)
                if ok and areFriends then
                    found = true
                    Utilities.notify("Teamer Detected!",
                        gameNameOf(p1) .. " is teaming with " .. gameNameOf(p2), 4)
                    task.wait(0.6)
                end
            end
        end
        if not found then Utilities.notify("No Teamers Found", "No teamers detected at this round", 4) end
    end),
})

Main:CreateButton({
    name = "Remove Cutscenes",
    description = "just goes to your camera immediately",
    icon = "video-off",
    callback = Utilities.safe(function()
        local events = RS:FindFirstChild("Events")
        local camEvent = events and events:FindFirstChild("Camera")
        if camEvent then camEvent:Destroy() end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            Camera.CameraType = Enum.CameraType.Custom
            Camera.CameraSubject = hum
        end
    end),
})

--==================================================
-- MAIN — COMEBACKS
--==================================================
Main:CreateSection({ name = "Comebacks", icon = "rotate-ccw" })

Main:CreateButton({
    name = "Comeback as Male",
    description = "rejoin as a blob of male skin",
    icon = "user",
    callback = Utilities.safe(function()
        local events = RS:FindFirstChild("Events")
        local buy = events and events:FindFirstChild("Buy")
        if buy then buy:FireServer("Gender", "Male") end
    end),
})

Main:CreateButton({
    name = "Comeback as Female",
    description = "rejoin as a blob of skin",
    icon = "user",
    callback = Utilities.safe(function()
        local events = RS:FindFirstChild("Events")
        local buy = events and events:FindFirstChild("Buy")
        if buy then buy:FireServer("Gender", "Female") end
    end),
})

--==================================================
-- MAIN — FLY V3 (Universal Fly Gui V3)
--==================================================
Main:CreateSection({ name = "Fly", icon = "plane" })

Main:CreateButton({
    name = "Universal Fly Gui V3",
    description = "loads the Universal Fly Gui V3 script",
    icon = "plane-takeoff",
    callback = Utilities.safe(function()
        task.spawn(function()
            local ok, err = pcall(function()
                loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Universal-Fly-Gui-V3-15837"))()
            end)
            if ok then
                Utilities.notify("Fly V3", "Fly Gui loaded successfully.", 4)
            else
                Utilities.notify("Fly V3 Error", tostring(err), 4)
                warn("[Surreal Hub][Fly V3] " .. tostring(err))
            end
        end)
    end),
})

--==================================================
-- MAIN — GLOBAL NAMEPLATES
--==================================================
local NameplateManager = {}
local NAMEPLATE_KEY = "SurrealNameplate"
local NAMEPLATE_GRADIENT = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(235, 235, 235)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(165, 165, 165)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(90, 90, 90)),
})

function NameplateManager.attach(plr)
    local char = plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    if head:FindFirstChild(NAMEPLATE_KEY) then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = NAMEPLATE_KEY
    billboard.Adornee = head
    billboard.Size = UDim2.new(0, 150, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 3.75, 0)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = 1500
    billboard.Parent = head

    local label = Instance.new("TextLabel")
    label.Name = "NameLabel"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = (plr.DisplayName ~= "" and plr.DisplayName) or plr.Name
    label.TextScaled = true
    label.Font = Enum.Font.LuckiestGuy
    label.TextColor3 = Color3.fromRGB(180, 180, 180)
    label.TextStrokeTransparency = 0.35
    label.TextStrokeColor3 = Color3.fromRGB(45, 45, 45)
    label.Parent = billboard

    local gradient = Instance.new("UIGradient")
    gradient.Name = "NameGradient"
    gradient.Color = NAMEPLATE_GRADIENT
    gradient.Rotation = 90
    gradient.Parent = label
end

function NameplateManager.detach(plr)
    local char = plr.Character
    local head = char and char:FindFirstChild("Head")
    local existing = head and head:FindFirstChild(NAMEPLATE_KEY)
    if existing then existing:Destroy() end
end

function NameplateManager.enable()
    for _, plr in ipairs(Players:GetPlayers()) do NameplateManager.attach(plr) end
    State.nameplateCharConns = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        table.insert(State.nameplateCharConns, plr.CharacterAdded:Connect(function()
            task.wait(0.15)
            if State.nameplatesEnabled then NameplateManager.attach(plr) end
        end))
    end
    State.nameplatePlayerConn = Players.PlayerAdded:Connect(function(plr)
        table.insert(State.nameplateCharConns, plr.CharacterAdded:Connect(function()
            task.wait(0.15)
            if State.nameplatesEnabled then NameplateManager.attach(plr) end
        end))
        if plr.Character then NameplateManager.attach(plr) end
    end)
end

function NameplateManager.disable()
    for _, plr in ipairs(Players:GetPlayers()) do NameplateManager.detach(plr) end
    if State.nameplatePlayerConn then State.nameplatePlayerConn:Disconnect(); State.nameplatePlayerConn = nil end
    for _, conn in ipairs(State.nameplateCharConns) do conn:Disconnect() end
    State.nameplateCharConns = {}
end

Main:CreateToggle({
    name = "Global Nameplates",
    description = "see everyone's display names",
    icon = "id-card",
    value = false,
    flag = "GlobalNameplates",
    callback = Utilities.safe(function(enabled)
        State.nameplatesEnabled = enabled
        if enabled then NameplateManager.enable() else NameplateManager.disable() end
    end),
})

--==================================================
-- CHALLENGES
--==================================================
Challenges:CreateSection({ name = "Challenges", icon = "target" })

Challenges:CreateButton({
    name = "Win Obby",
    description = "makes you win an Obby",
    icon = "flag",
    callback = Utilities.safe(function()
        local assets = workspace:FindFirstChild("Assets")
        if not assets then return end
        local finish = assets:FindFirstChild("Finish", true)
        if not finish then return end
        finish.CanCollide = false
        finish.Transparency = 1
        task.wait()
        local torso = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Torso")
        if torso then finish.Position = torso.Position end
    end),
})

Challenges:CreateToggle({
    name = "Auto Win Obby",
    description = "win every Obby without pressing win Obby",
    icon = "flag",
    value = false,
    flag = "AutoWinObby",
    callback = Utilities.safe(function(enabled)
        State.autoWinObby = enabled
        if not enabled then return end
        task.spawn(function()
            while State.autoWinObby do
                pcall(function()
                    local assets = workspace:FindFirstChild("Assets")
                    local finish = assets and assets:FindFirstChild("Finish", true)
                    local root = Utilities.rootPart()
                    if finish and root then
                        finish.CanCollide = false
                        finish.Transparency = 1
                        task.wait()
                        finish.Position = root.Position
                    end
                end)
                task.wait(0.1)
            end
        end)
    end),
})

Challenges:CreateButton({
    name = "Remove all Spleef Studs",
    description = "makes Spleef have no studs and everyone falls",
    icon = "grid-3x3",
    callback = Utilities.safe(function()
        local root = Utilities.rootPart()
        if not root then return end
        local assets = workspace:FindFirstChild("Assets")
        if not assets then return end
        for _, obj in ipairs(assets:GetDescendants()) do
            if obj.Name == "SpleefPart" then pcall(firetouchinterest, root, obj, 0) end
        end
    end),
})

Challenges:CreateButton({
    name = "Finish Pancake",
    description = "Rapidly clicks your pancake",
    icon = "cookie",
    callback = Utilities.safe(function()
        local assets = workspace:FindFirstChild("Assets")
        if not assets then return end
        for _, obj in ipairs(assets:GetDescendants()) do
            if obj.Name == LocalPlayer.Name and obj:FindFirstChild("ClickDetector") then
                for _ = 1, 80 do pcall(fireclickdetector, obj.ClickDetector) end
            end
        end
    end),
})

Challenges:CreateToggle({
    name = "Cliff Diving ESP",
    description = "automatically find the finish line",
    icon = "map-pin",
    value = false,
    flag = "CliffDivingESP",
    callback = Utilities.safe(function(enabled)
        State.cliffESP = enabled
        if enabled then
            local MAX_DISTANCE = 500
            local function createMarker(part)
                if State.cliffObjects[part] then return end
                if not part:FindFirstChild("CliffHighlight") then
                    local highlight = Instance.new("Highlight")
                    highlight.Name = "CliffHighlight"
                    highlight.FillTransparency = 1
                    highlight.OutlineColor = Color3.new(1, 1, 1)
                    highlight.Parent = part
                end
                local billboard = Instance.new("BillboardGui")
                billboard.AlwaysOnTop = true
                billboard.Size = UDim2.new(0, 260, 0, 70)
                billboard.StudsOffset = Vector3.new(0, 4, 0)
                billboard.Adornee = part
                billboard.Parent = part
                local label = Instance.new("TextLabel")
                label.BackgroundTransparency = 1
                label.Size = UDim2.new(1, 0, 1, 0)
                label.TextColor3 = Color3.new(1, 1, 1)
                label.TextStrokeTransparency = 0
                label.TextScaled = true
                label.Font = Enum.Font.GothamBold
                label.Text = "FINISH"
                label.Parent = billboard
                State.cliffObjects[part] = { billboard = billboard, label = label }
            end
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Name:lower() == "finish" then createMarker(obj) end
            end
            State.cliffAddedConn = workspace.DescendantAdded:Connect(function(obj)
                if State.cliffESP and obj:IsA("BasePart") and obj.Name:lower() == "finish" then createMarker(obj) end
            end)
            State.cliffRemovedConn = workspace.DescendantRemoving:Connect(function(obj)
                if State.cliffObjects[obj] then
                    pcall(function() State.cliffObjects[obj].billboard:Destroy() end)
                    State.cliffObjects[obj] = nil
                end
            end)
            State.cliffRenderConn = RunService.RenderStepped:Connect(function()
                if not State.cliffESP then return end
                local root = Utilities.rootPart()
                if not root then return end
                for part, marker in pairs(State.cliffObjects) do
                    local distance = (part.Position - root.Position).Magnitude
                    marker.billboard.Enabled = distance <= MAX_DISTANCE
                    if distance <= MAX_DISTANCE then
                        marker.label.Text = string.format("%.1f studs", distance)
                    end
                end
            end)
        else
            for part, marker in pairs(State.cliffObjects) do
                pcall(function() marker.billboard:Destroy() end)
                pcall(function()
                    if part:FindFirstChild("CliffHighlight") then part.CliffHighlight:Destroy() end
                end)
            end
            State.cliffObjects = {}
            if State.cliffAddedConn then State.cliffAddedConn:Disconnect(); State.cliffAddedConn = nil end
            if State.cliffRemovedConn then State.cliffRemovedConn:Disconnect(); State.cliffRemovedConn = nil end
            if State.cliffRenderConn then State.cliffRenderConn:Disconnect(); State.cliffRenderConn = nil end
        end
    end),
})

Challenges:CreateToggle({
    name = "Auto Get All Coins",
    description = "teleports every coin and gem to you",
    icon = "coins",
    value = false,
    flag = "AutoGetCoins",
    callback = Utilities.safe(function(enabled)
        State.autoCollect = enabled
        if not enabled then return end
        task.spawn(function()
            while State.autoCollect do
                task.wait(0.5)
                pcall(function()
                    local root = Utilities.rootPart()
                    local assets = workspace:FindFirstChild("Assets")
                    if root and assets then
                        for _, obj in ipairs(assets:GetDescendants()) do
                            if (obj.Name == "Coin" or obj.Name == "Gem") and obj:IsA("BasePart") then
                                obj.CanCollide = false
                                obj.Position = root.Position
                            end
                        end
                    end
                end)
            end
        end)
    end),
})

Challenges:CreateToggle({
    name = "Answer Math Mania",
    description = "answer every question easily",
    icon = "calculator",
    value = false,
    flag = "AnswerMathMania",
    callback = Utilities.safe(function(enabled)
        State.autoMath = enabled
        if not enabled then return end
        task.spawn(function()
            while State.autoMath do
                pcall(function()
                    local mathGui = LocalPlayer.PlayerGui:FindFirstChild("MathMania")
                    if mathGui then
                        for index = 1, 10 do
                            if not State.autoMath then break end
                            local question = mathGui:FindFirstChild(tostring(index))
                            if question and question:FindFirstChild("MainText") and question:FindFirstChild("Box") then
                                local expression = question.MainText.Text:gsub("=", ""):gsub("?", ""):gsub(" ", "")
                                local ok, result = pcall(function() return loadstring("return " .. expression)() end)
                                if ok and result then
                                    question.Box.Text = tostring(result)
                                    local submit = question:FindFirstChild("Enter")
                                    if submit then
                                        for _, eventName in ipairs({"MouseButton1Click", "MouseButton1Down", "Activated"}) do
                                            if submit[eventName] then
                                                for _, conn in pairs(getconnections(submit[eventName])) do
                                                    if conn.Function then pcall(function() conn:Fire() end) end
                                                end
                                            end
                                        end
                                    end
                                    if State.mathDelay > 0 then task.wait(State.mathDelay) end
                                end
                            end
                        end
                    end
                end)
                task.wait()
            end
        end)
    end),
})

Challenges:CreateSlider({
    name = "Math Mania Setback",
    description = "Adds a delay",
    icon = "timer",
    range = { 0, 100 },
    increment = 1,
    value = 0,
    flag = "MathManiaSetback",
    callback = Utilities.safe(function(value) State.mathDelay = value / 10 end),
})

Challenges:CreateButton({
    name = "Win Blockpush",
    description = "teleports block to finishing line",
    icon = "box",
    callback = Utilities.safe(function()
        local root = Utilities.rootPart()
        if not root then return end
        for _, box in ipairs(workspace:GetDescendants()) do
            if box:IsA("Part") and box.Name == "SingularBox" then
                if (box.Position - root.Position).Magnitude <= 100 then
                    for _, target in ipairs(workspace:GetDescendants()) do
                        if target:IsA("Part") and target.Name == "Gold" then
                            box.Position = target.Position + Vector3.new(0, 3, 0)
                            root.CFrame = CFrame.new(box.Position + Vector3.new(0, 3, 0))
                            break
                        end
                    end
                    break
                end
            end
        end
    end),
})

Challenges:CreateToggle({
    name = "Dodgeball Invincibility",
    description = "resets you (you do not die)",
    icon = "shield",
    value = false,
    flag = "DodgeballInvincibility",
    callback = Utilities.safe(function(enabled)
        State.dodgeballGuard = enabled
        if not enabled then return end
        task.spawn(function()
            local triggered = false
            while State.dodgeballGuard do
                pcall(function()
                    local assets = workspace:FindFirstChild("Assets")
                    if assets then
                        local giver = assets:FindFirstChild("DodgeballGiver", true)
                        if giver and not triggered then
                            triggered = true
                            local hum = Utilities.humanoid()
                            if hum then hum.Health = 0 end
                        end
                        if not giver then triggered = false end
                    end
                end)
                task.wait(0.1)
            end
        end)
    end),
})

Challenges:CreateButton({
    name = "Get Dodgeballs",
    description = "get every dodgeball",
    icon = "circle-dot",
    callback = Utilities.safe(function()
        local root = Utilities.rootPart()
        if not root then return end
        local assets = workspace:FindFirstChild("Assets")
        if not assets then return end
        for _, obj in ipairs(assets:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name:lower():find("dodgeball") then
                pcall(firetouchinterest, root, obj, 0)
                pcall(firetouchinterest, root, obj, 1)
            end
        end
    end),
})

Challenges:CreateToggle({
    name = "Paintball Invincibility",
    description = "resets you b4 the game start (you do not die)",
    icon = "shield",
    value = false,
    flag = "PaintballInvincibility",
    callback = Utilities.safe(function(enabled)
        State.paintballGuard = enabled
        if not enabled then return end
        task.spawn(function()
            local triggered = false
            while State.paintballGuard do
                pcall(function()
                    local assets = workspace:FindFirstChild("Assets")
                    if assets then
                        local arena = assets:FindFirstChild("Paintball", true)
                            or assets:FindFirstChild("PaintballArena", true)
                        if arena and not triggered then
                            triggered = true
                            local hum = Utilities.humanoid()
                            if hum then hum.Health = 0 end
                        end
                        if not arena then triggered = false end
                    end
                end)
                task.wait(0.1)
            end
        end)
    end),
})

Challenges:CreateButton({
    name = "Kill Everyone in Swordfight",
    description = "expands hitbox and kills everyone",
    icon = "sword",
    callback = Utilities.safe(function()
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local char = LocalPlayer.Character
        if backpack and char then
            local sword
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") and tool.Name:lower():find("sword") then
                    sword = tool
                    break
                end
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if sword and hum then hum:EquipTool(sword) end
        end
        if State.swordFightConn then State.swordFightConn:Disconnect() end
        State.swordFightConn = RunService.RenderStepped:Connect(function()
            pcall(function()
                local players = Players:GetPlayers()
                for i = 2, #players do
                    local target = players[i].Character
                    if target and not LocalPlayer:IsFriendsWith(players[i].UserId) then
                        local charL = LocalPlayer.Character
                        local tool = charL and charL:FindFirstChildOfClass("Tool")
                        if tool and tool:FindFirstChild("Handle") then
                            tool:Activate()
                            for _, part in ipairs(target:GetChildren()) do
                                if part:IsA("BasePart") then
                                    firetouchinterest(tool.Handle, part, 0)
                                    firetouchinterest(tool.Handle, part, 1)
                                end
                            end
                        end
                    end
                end
            end)
        end)
        task.delay(1, function()
            if State.swordFightConn then
                State.swordFightConn:Disconnect()
                State.swordFightConn = nil
            end
        end)
    end),
})

--==================================================
-- CHALLENGES — RESTARTING
--==================================================
Challenges:CreateSection({ name = "Restarting", icon = "refresh-cw" })

Challenges:CreateButton({
    name = "FE Genesis Sniper",
    description = "restarts the finale (server-wide)",
    icon = "crosshair",
    callback = Utilities.safe(function()
        Utilities.launchUtility("genesis_sniper")
    end),
})

--==================================================
-- MORPHS — PAID
--==================================================
Morphs:CreateSection({ name = "Paid", icon = "crown" })

local characterNameBuffer = ""

Morphs:CreateInput({
    name = "Character Name",
    description = "type what you character name",
    icon = "type",
    placeholder = "Enter character name...",
    value = "",
    flag = "MorphCharacterName",
    callback = Utilities.safe(function(value) characterNameBuffer = value or "" end),
})

Morphs:CreateButton({
    name = "Buy Character (@60)",
    description = "purchases the custom character",
    icon = "shopping-cart",
    callback = Utilities.safe(function()
        if characterNameBuffer == "" then return end
        local events = RS:FindFirstChild("Events")
        local buy = events and events:FindFirstChild("Buy")
        if buy then buy:FireServer("Character", characterNameBuffer) end
    end),
})

Morphs:CreateButton({
    name = "Get Verified Symbol (@60)",
    description = "applies the verified badge to your character name",
    icon = "badge-check",
    callback = Utilities.safe(function()
        if characterNameBuffer == "" then return end
        local VERIFIED = "\u{e000}"
        local final = characterNameBuffer .. " " .. VERIFIED
        local events = RS:FindFirstChild("Events")
        local buy = events and events:FindFirstChild("Buy")
        if buy then buy:FireServer("Character", final) end
    end),
})

Morphs:CreateButton({
    name = "Server Crash",
    description = "loads the crash payload from GitHub",
    icon = "bomb",
    callback = Utilities.safe(function()
        task.spawn(function()
            local url = "https://raw.githubusercontent.com/surrre4l/bruh/main/surrealcrash.lua"
            local ok, err = pcall(function()
                local src = game:HttpGet(url, true)
                if not src or #src < 50 then error("Empty or invalid response") end
                local fn = loadstring(src)
                if not fn then error("loadstring returned nil") end
                fn()
            end)
            if ok then
                Utilities.notify("Server Crash", "Payload executed.", 4)
            else
                Utilities.notify("Server Crash Error", tostring(err), 4)
                warn("[Surreal Hub][Server Crash] " .. tostring(err))
            end
        end)
    end),
})

--==================================================
-- VISUALS — TYPEFACES
--==================================================
Visuals:CreateSection({ name = "Typefaces", icon = "type" })

Visuals:CreateButton({
    name = "Starborn Typeface",
    description = "starborn try this thing",
    icon = "star",
    callback = Utilities.safe(function()
        TypefaceManager.load(
            "starborn", "Starborn", "starborn.ttf", "Starborn.json",
            "https://drive.google.com/uc?export=download&id=1AOv_DKQ0iB55eOvRkQnkq40POxix82dP&confirm=t",
            "SurrealFontStarborn"
        )
    end),
})

Visuals:CreateButton({
    name = "Minecraft Typeface",
    description = "minecrafter if you are larper",
    icon = "blocks",
    callback = Utilities.safe(function()
        TypefaceManager.load(
            "minecraft", "Minecrafter", "minecrafter.ttf", "Minecrafter.json",
            "https://drive.google.com/uc?export=download&id=1oe66VO8IhLBqDvbgxqer4RHEi7bAO7R2&confirm=t",
            "SurrealFontMinecraft"
        )
    end),
})

Visuals:CreateButton({
    name = "Matcha Mint Typeface",
    description = "labubu matcha font",
    icon = "coffee",
    callback = Utilities.safe(function()
        TypefaceManager.load(
            "matchamint", "Matcha Mint", "matchamint.ttf", "MatchaMint.json",
            "https://drive.google.com/uc?export=download&id=1cZomyiePFjjNzciPRextxt0puySrmrEX&confirm=t",
            "SurrealFontMatchaMint"
        )
    end),
})

Visuals:CreateButton({
    name = "OG Roblox Typeface",
    description = "classic Roblox font",
    icon = "square",
    callback = Utilities.safe(function()
        TypefaceManager.load(
            "ogroblox", "OG Roblox", "ogroblox.ttf", "OGRoblox.json",
            "https://drive.google.com/uc?export=download&id=1XLBx4U-kkzB3B8v2DaO3AcvtHNlyn3tn&confirm=t",
            "SurrealFontOGRoblox"
        )
    end),
})

--==================================================
-- VISUALS — CUSTOM
--==================================================
Visuals:CreateSection({ name = "Custom", icon = "palette" })

_G.CustomName        = _G.CustomName or ""
_G.UseCustomName     = _G.UseCustomName or false
_G.SelectedFont      = _G.SelectedFont or nil
_G.RainbowMode       = _G.RainbowMode or false
_G.RainbowSpeed      = _G.RainbowSpeed or 0.5
_G.StaticColor       = _G.StaticColor or Color3.fromRGB(255, 255, 255)
_G.StaticColorCustom = false

local nameColorArmed = false
task.delay(2, function() nameColorArmed = true end)

Visuals:CreateInput({
    name = "Character Name",
    description = "replace your character name no tags",
    icon = "type",
    placeholder = "Enter character name...",
    value = "",
    flag = "VisualCustomName",
    callback = Utilities.safe(function(value)
        _G.CustomName = value or ""
        _G.UseCustomName = (_G.CustomName ~= "")
    end),
})

Visuals:CreateToggle({
    name = "Rainbow Name",
    description = "rainbow rgb in name",
    icon = "rainbow",
    value = false,
    flag = "RainbowName",
    callback = Utilities.safe(function(enabled) _G.RainbowMode = enabled end),
})

Visuals:CreateSlider({
    name = "Rainbow Setback",
    description = "how fast rainbow name",
    icon = "gauge",
    range = { 0, 100 },
    increment = 1,
    value = 50,
    flag = "RainbowSetback",
    callback = Utilities.safe(function(value) _G.RainbowSpeed = value / 100 end),
})

Visuals:CreateButton({
    name = "Reset to Team Color",
    description = "resets your name color to original",
    icon = "rotate-ccw",
    callback = Utilities.safe(function()
        _G.StaticColorCustom = false
        Utilities.notify("Name Color", "Reverted to team color.", 4)
    end),
})

--==================================================
-- VISUALS — NAME RENDER LOOP
--==================================================
RunService.RenderStepped:Connect(function()
    pcall(function()
        local anyCustomActive = _G.UseCustomName or _G.SelectedFont or _G.RainbowMode or _G.StaticColorCustom
        if not anyCustomActive then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                if _G.UseCustomName and _G.CustomName ~= "" then obj.Text = _G.CustomName end
                if _G.SelectedFont then obj.Font = _G.SelectedFont end
                if _G.RainbowMode then
                    local hue = (tick() * _G.RainbowSpeed) % 1
                    obj.TextColor3 = Color3.fromHSV(hue, 0.6, 1)
                elseif _G.StaticColorCustom then
                    obj.TextColor3 = _G.StaticColor
                end
                obj.TextScaled = true
                obj.TextStrokeTransparency = 0.5
                obj.BackgroundTransparency = 1
            end
        end
    end)
end)

--==================================================
-- TROLL — TARGET FOLLOWER
--==================================================
TrollTab:CreateSection({ name = "Target Follower", icon = "crosshair" })

local FollowController = {}
FollowController.__index = FollowController

local ANIMATION_ID    = "189854234"
local STEP_TIME       = 0.15
local FORWARD_OFFSET  = CFrame.new(0, 0, -2.5)
local BACKWARD_OFFSET = CFrame.new(0, 0, -1.3)
local TWEEN_INFO      = TweenInfo.new(STEP_TIME, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

function FollowController.new()
    local self = setmetatable({}, FollowController)
    self._following, self._target, self._anim, self._tween, self._thread = false, nil, nil, nil, nil
    self.Changed = nil
    return self
end

function FollowController:IsFollowing() return self._following end
function FollowController:GetTarget()   return self._target end

function FollowController:SetTarget(player)
    if player == LocalPlayer then return false end
    self._target = player
    if self._following then
        self:Stop()
        if player then return self:Start() end
    end
    return true
end

function FollowController:Start()
    if self._following then return true end
    if not self._target or not self._target.Character then return false end
    self._following = true
    self:_playAnim()
    if self.Changed then self.Changed(true) end
    self._thread = task.spawn(function() self:_loop() end)
    return true
end

function FollowController:Stop()
    if not self._following then return end
    self._following = false
    if self._tween then self._tween:Cancel(); self._tween = nil end
    self:_stopAnim()
    if self.Changed then self.Changed(false) end
end

function FollowController:_loop()
    while self._following do
        local tc   = self._target and self._target.Character
        local thrp = tc and tc:FindFirstChild("HumanoidRootPart")
        local myc  = LocalPlayer.Character
        local myhrp = myc and myc:FindFirstChild("HumanoidRootPart")
        if not thrp or not myhrp then self:Stop() return end
        self:_tween(myhrp, thrp.CFrame * FORWARD_OFFSET)
        if not self._following then return end
        self:_tween(myhrp, thrp.CFrame * BACKWARD_OFFSET)
    end
end

function FollowController:_tween(inst, goal)
    local t = TweenService:Create(inst, TWEEN_INFO, { CFrame = goal })
    self._tween = t
    t:Play()
    t.Completed:Wait()
    if self._tween == t then self._tween = nil end
end

function FollowController:_playAnim()
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
    local a = Instance.new("Animation")
    a.AnimationId = "rbxassetid://" .. ANIMATION_ID
    local track = animator:LoadAnimation(a)
    track:Play()
    self._anim = track
end

function FollowController:_stopAnim()
    if self._anim then self._anim:Stop(); self._anim = nil end
end

local followController = FollowController.new()

local playerMap = {}
local suppress  = false

local function buildOptions()
    local opts = {}
    playerMap = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local label = string.format("%s (@%s)", p.DisplayName, p.Name)
            opts[#opts + 1] = label
            playerMap[label] = p
        end
    end
    table.sort(opts)
    return opts
end

local targetDropdown

targetDropdown = TrollTab:CreateDropdown({
    name = "Target Player",
    description = "pick who to follow",
    icon = "user-search",
    options = buildOptions(),
    value = nil,
    flag = "TrollTarget",
    callback = function(selected)
        if suppress then return end
        local player = playerMap[selected]
        if player then
            followController:SetTarget(player)
        else
            followController:Stop()
            followController:SetTarget(nil)
        end
    end,
})

TrollTab:CreateButton({
    name = "Refresh Players",
    icon = "refresh-cw",
    callback = function()
        local opts = buildOptions()
        pcall(function() targetDropdown:Refresh(opts) end)
    end,
})

local followToggle

followToggle = TrollTab:CreateToggle({
    name = "Follow Target",
    description = "start following the selected player",
    icon = "user-check",
    value = false,
    flag = "TrollFollow",
    callback = function(value)
        if suppress then return end
        if value then
            local ok = followController:Start()
            if not ok then
                suppress = true
                pcall(function() followToggle:Set(false) end)
                suppress = false
            end
        else
            followController:Stop()
        end
    end,
})

followController.Changed = function(isFollowing)
    suppress = true
    pcall(function() followToggle:Set(isFollowing) end)
    suppress = false
end

Players.PlayerAdded:Connect(function()
    task.defer(function()
        local opts = buildOptions()
        pcall(function() targetDropdown:Refresh(opts) end)
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    task.defer(function()
        if followController:GetTarget() == p then
            followController:Stop()
            followController:SetTarget(nil)
            suppress = true
            pcall(function() targetDropdown:Set(nil) end)
            suppress = false
        end
        local opts = buildOptions()
        pcall(function() targetDropdown:Refresh(opts) end)
    end)
end)

--==================================================
-- TROLL — SCRIPTS
--==================================================
TrollTab:CreateSection({ name = "Scripts", icon = "file-code" })

TrollTab:CreateButton({
    name = "Flinger",
    description = "loads the Flinger script from GitHub",
    icon = "send",
    callback = function()
        task.spawn(function()
            local url = "https://raw.githubusercontent.com/surrre4l/bruh/main/exe.lua.txt"
            local ok, err = pcall(function()
                local src = game:HttpGet(url, true)
                if not src or #src < 50 then error("Empty or invalid response") end
                local fn = loadstring(src)
                if not fn then error("loadstring returned nil") end
                fn()
            end)
            if ok then
                Utilities.notify("Flinger Loaded", "Flinger is now active.", 4)
            else
                Utilities.notify("Flinger Error", tostring(err), 4)
                warn("[Surreal Hub][Flinger] " .. tostring(err))
            end
        end)
    end,
})

TrollTab:CreateButton({
    name = "Bang [NEW]",
    description = "loads the Bang script",
    icon = "zap",
    callback = function()
        task.spawn(function()
            pcall(function()
                loadstring(game:HttpGet(
                    "https://rawscripts.net/raw/Universal-Script-New-Bang-script-made-by-me-OFC-75582"
                ))()
            end)
        end)
    end,
})

TrollTab:CreateButton({
    name = "Jerk Off (gives tool)",
    description = "gives you the Jerk tool",
    icon = "hand",
    callback = function()
        local plr  = LocalPlayer
        local char = plr.Character or plr.CharacterAdded:Wait()
        local hum  = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
        local pack = plr:FindFirstChildOfClass("Backpack") or plr:WaitForChild("Backpack")

        if workspace:FindFirstChild("aaa") then workspace:FindFirstChild("aaa"):Destroy() end

        local isR15 = hum.RigType == Enum.HumanoidRigType.R15
        local animation = Instance.new("Animation")
        animation.Name = "aaa"
        animation.Parent = workspace
        animation.AnimationId = isR15 and "rbxassetid://698251653" or "rbxassetid://72042024"

        local tool = Instance.new("Tool")
        tool.Name = "Jerk"
        tool.RequiresHandle = false
        tool.Parent = pack

        local doing, animtrack = false, nil
        tool.Equipped:Connect(function()
            doing = true
            while doing do
                if not animtrack then
                    animtrack = hum:FindFirstChildOfClass("Animator")
                    animtrack = animtrack and animtrack:LoadAnimation(animation)
                end
                if animtrack then
                    animtrack:Play()
                    animtrack:AdjustSpeed(0.7)
                    animtrack.TimePosition = 0.6
                    task.wait(0.1)
                    while doing and animtrack and animtrack.TimePosition < 0.7 do task.wait(0.05) end
                    animtrack:Stop()
                    animtrack:Destroy()
                    animtrack = nil
                end
            end
        end)
        tool.Unequipped:Connect(function()
            doing = false
            if animtrack then animtrack:Stop(); animtrack:Destroy(); animtrack = nil end
        end)
    end,
})

TrollTab:CreateButton({
    name = "Freaky",
    description = "loads the Freaky script",
    icon = "flame",
    callback = function()
        task.spawn(function()
            pcall(function()
                loadstring(game:HttpGet(
                    "https://rawscripts.net/raw/Universal-Script-Freaky-gui-supported-r6-r15-29701"
                ))()
            end)
        end)
    end,
})

--==================================================
-- UTILITIES — HELPERS
--==================================================
local WaterManager = {}

local function getLakeWater()
    local map = workspace:FindFirstChild("Map")
    local camp = map and map:FindFirstChild("Roblox Drama: Camp")
    local innerMap = camp and camp:FindFirstChild("Map")
    local lake = innerMap and innerMap:FindFirstChild("Lake")
    return lake and lake:FindFirstChild("Water")
end

local function getSandTouch()
    local map = workspace:FindFirstChild("Map")
    local camp = map and map:FindFirstChild("Roblox Drama: Camp")
    local sand = camp and camp:FindFirstChild("Sand")
    return sand and sand:FindFirstChild("TouchInterest")
end

function WaterManager.setEnabled(enabled)
    pcall(function()
        local water = getLakeWater()
        if water then water.CanCollide = enabled end
        if enabled then
            local touch = getSandTouch()
            if touch then touch:Destroy() end
        end
    end)
end

local BarrierManager = {}
local BARRIER_TARGETS = {
    ["Glass"]          = true,
    ["ChallengeGlass"] = true,
    ["AwardCeremony"]  = true,
    ["Drop-Off"]       = true,
}

function BarrierManager.clear()
    local removed = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if BARRIER_TARGETS[obj.Name] then
            obj:Destroy()
            removed = removed + 1
        end
    end
    Utilities.notify("Barriers Cleared", removed .. " obstacle(s) removed.", 4)
end

--==================================================
-- UTILITIES TAB
--==================================================
UtilitiesTab:CreateSection({ name = "Utility", icon = "settings" })

UtilitiesTab:CreateButton({
    name = "Barrier Cleanup",
    description = "removes every barrier",
    icon = "trash-2",
    callback = Utilities.safe(function() BarrierManager.clear() end),
})

UtilitiesTab:CreateToggle({
    name = "Water Walk",
    description = "makes you like jesus",
    icon = "waves",
    value = false,
    flag = "WaterWalk",
    callback = Utilities.safe(function(enabled)
        State.waterWalkEnabled = enabled
        WaterManager.setEnabled(enabled)
        if enabled then Utilities.notify("Water Walk", "enabled", 4) end
    end),
})

UtilitiesTab:CreateSection({ name = "Teleports", icon = "map-pin" })

UtilitiesTab:CreateButton({
    name = "Spectator Island",
    description = "don't go to loser land",
    icon = "eye",
    callback = Utilities.safe(function() Utilities.teleportTo(33, -16, 31) end),
})

UtilitiesTab:CreateButton({
    name = "Main Island",
    description = "main island",
    icon = "home",
    callback = Utilities.safe(function() Utilities.teleportTo(150, -17, -417) end),
})

UtilitiesTab:CreateButton({
    name = "Exile Island",
    description = "go to exile",
    icon = "door-open",
    callback = Utilities.safe(function() Utilities.teleportTo(-116, -14, -166) end),
})

UtilitiesTab:CreateButton({
    name = "Voting Area",
    description = "go here for voting (remove barrier first)",
    icon = "check-square",
    callback = Utilities.safe(function() Utilities.teleportTo(-23, 95, -514) end),
})

UtilitiesTab:CreateButton({
    name = "Boat",
    description = "do u want to be eliminated",
    icon = "ship",
    callback = Utilities.safe(function() Utilities.teleportTo(47, -20, -297) end),
})

UtilitiesTab:CreateButton({
    name = "Bathroom",
    description = "tps you to bathroom",
    icon = "toilet",
    callback = Utilities.safe(function() Utilities.teleportTo(302, -15, -325) end),
})

UtilitiesTab:CreateSection({ name = "More", icon = "plus-circle" })

UtilitiesTab:CreateButton({
    name = "Infinite Yield",
    description = "many features and bang",
    icon = "terminal",
    callback = Utilities.safe(function() Utilities.launchUtility("infinite_yield") end),
})

UtilitiesTab:CreateButton({
    name = "Energize R6",
    description = "fe animations hahaha",
    icon = "sparkles",
    callback = Utilities.safe(function() Utilities.launchUtility("energize") end),
})

--==================================================
-- INITIALIZE
--==================================================
task.spawn(function()
    task.wait(1.5)

    pcall(function()
        if SurrealWindow then
            SurrealWindow:Notify({
                title    = "Surreal Hub Loaded",
                content  = "Rayfield version is loaded enjoy!",
                duration = 6,
            })
        end
    end)

    warn("[Surreal Hub] inputs may not work, tested and I can't click it so. Try if u can!")
end)