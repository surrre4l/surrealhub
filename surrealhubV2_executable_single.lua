--[[
    Surreal Hub V2.0
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
))()

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService      = game:GetService("SoundService")
local Debris            = game:GetService("Debris")
local Terrain           = workspace.Terrain
local LocalPlayer       = Players.LocalPlayer

-- PlaceId detection
local PLACE_LOBBY      = 4889315193
local PLACE_CAMP       = 4939362930
local PLACE_MOVIES     = 4939362610
local PLACE_EXPEDITION = 7172152072
local PLACE_PRACTICE   = 15365802831

local isLobby      = game.PlaceId == PLACE_LOBBY
local isCamp       = game.PlaceId == PLACE_CAMP
local isMovies     = game.PlaceId == PLACE_MOVIES
local isExpedition = game.PlaceId == PLACE_EXPEDITION
local isPractice   = game.PlaceId == PLACE_PRACTICE

print(string.format("[Surreal] PlaceId: %d | Mode: %s",
    game.PlaceId,
    isCamp and "Camp"
        or isMovies and "Movies"
        or isExpedition and "Expedition"
        or isPractice and "Practice"
        or "Lobby"))

-- Shared state
local S = { Conns = {}, Flags = {}, ShaderActive = nil }

-- Executor compatibility:
-- Some environments do not expose the optional filesystem APIs.  The original
-- script used them during UI construction, which could abort the entire hub.
-- Keep real executor APIs when available; otherwise use an in-memory fallback
-- so the UI and recording workflow can still execute for the current session.
do
    local memFiles = rawget(_G, "__SURREAL_MEM_FILES")
    local memFolders = rawget(_G, "__SURREAL_MEM_FOLDERS")
    if type(memFiles) ~= "table" then
        memFiles = {}
        pcall(function() _G.__SURREAL_MEM_FILES = memFiles end)
    end
    if type(memFolders) ~= "table" then
        memFolders = { ["SurrealHubV2"] = true }
        pcall(function() _G.__SURREAL_MEM_FOLDERS = memFolders end)
    end

    if type(isfolder) ~= "function" then
        function isfolder(path)
            return memFolders[path] == true
        end
    end

    if type(makefolder) ~= "function" then
        function makefolder(path)
            memFolders[path] = true
            return true
        end
    end

    if type(isfile) ~= "function" then
        function isfile(path)
            return memFiles[path] ~= nil
        end
    end

    if type(writefile) ~= "function" then
        function writefile(path, content)
            memFiles[path] = tostring(content)
            local parent = path:match("^(.*)[/\\][^/\\]+$")
            if parent then memFolders[parent] = true end
            return true
        end
    end

    if type(readfile) ~= "function" then
        function readfile(path)
            local value = memFiles[path]
            if value == nil then error("file not found: " .. tostring(path), 2) end
            return value
        end
    end

    if type(delfile) ~= "function" then
        function delfile(path)
            memFiles[path] = nil
            return true
        end
    end

    if type(listfiles) ~= "function" then
        function listfiles(folder)
            local out = {}
            local prefix = tostring(folder):gsub("[/\\]+$", "") .. "/"
            for path in pairs(memFiles) do
                if path:sub(1, #prefix) == prefix
                   and not path:sub(#prefix + 1):find("[/\\]") then
                    table.insert(out, path)
                end
            end
            return out
        end
    end
end

local function bind(key, c)
    if S.Conns[key] then pcall(function() S.Conns[key]:Disconnect() end) end
    S.Conns[key] = c
    return c
end

local function unbind(key)
    if S.Conns[key] then
        pcall(function() S.Conns[key]:Disconnect() end)
        S.Conns[key] = nil
    end
end

local function safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then warn("[Surreal] " .. tostring(err)) end
    end
end

-- WindUI 1.6.x dropdowns pass the selected value to Callback.
-- Accept both the current value-style callback and older numeric-index callbacks.
local function selectedIndex(values, value)
    if type(value) == "number" then
        return math.max(1, math.floor(value))
    end
    if type(value) == "string" and type(values) == "table" then
        for i, item in ipairs(values) do
            if item == value then return i end
        end
    end
    return 1
end

local function root()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function humanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function teleport(x, y, z)
    local r = root()
    if r then r.CFrame = CFrame.new(x, y, z) end
end

pcall(function()
    if not isfolder("SurrealHubV2") then makefolder("SurrealHubV2") end
end)

--[[
]]

-- Executor APIs are optional. Missing APIs must not prevent the UI from loading.
local executorEnv = _G
if type(getfenv) == "function" then
    pcall(function()
        local env = getfenv()
        if type(env) == "table" then executorEnv = env end
    end)
end
local executorGetGC = rawget(executorEnv, "getgc")
local executorFireTouch = rawget(executorEnv, "firetouchinterest")
local executorFireClick = rawget(executorEnv, "fireclickdetector")

if type(executorGetGC) == "function" then
    pcall(function()
        for _, v in ipairs(executorGetGC(true)) do
            if type(v) == "table" then
                local indexInstance = rawget(v, "indexInstance")
                if type(indexInstance) == "table" and indexInstance[1] == "kick" then
                    v.tvk = {
                        "kick",
                        function()
                            return game.Workspace:WaitForChild("")
                        end
                    }
                end
            end
        end
    end)
    print("[Surreal] Anti-kick installed")
else
    warn("[Surreal] getgc is unavailable; Anti-kick skipped.")
end

--[[
]]

local SurrealTheme = {
    Name        = "Surreal",
    Accent      = Color3.fromHex("#8B5CF6"),
    Background  = Color3.fromHex("#0A0A0F"),
    Outline     = Color3.fromHex("#23232E"),
    Text        = Color3.fromHex("#E5E5F0"),
    Placeholder = Color3.fromHex("#6B6B7E"),
    Button      = Color3.fromHex("#1E1E28"),
    Icon        = Color3.fromHex("#A1A1AA"),
}
local themeOk = pcall(function() WindUI:AddTheme(SurrealTheme) end)
local THEME = themeOk and "Surreal" or "Dark"

local function notify(title, content, duration)
    pcall(function()
        WindUI:Notify({
            Title    = title or "Surreal Hub",
            Content  = content or "",
            Duration = duration or 4,
        })
    end)
end

local Window = WindUI:CreateWindow({
    Title             = "Surreal Hub",
    Author            = "by surrre4L · v2.0",
    Folder            = "SurrealHubV2",
    Icon              = "solar:star-bold",
    Theme             = THEME,
    Transparent       = true,
    Acrylic           = true,
    Resizable         = true,
    NewElements       = true,
    ScrollBarEnabled  = true,
    HideSearchBar     = false,
    SideBarWidth      = 210,
    ToggleKey         = Enum.KeyCode.RightShift,
})

Window:Tag({ Title = "SURREAL HUB", Color = "Text" })
local function addWindowDivider()
    if type(Window.Divider) == "function" then
        pcall(function() Window:Divider() end)
    end
end

addWindowDivider()

local MainTab       = Window:Tab({ Title = "Main",       Icon = "solar:home-2-bold" })
local CampTab       = Window:Tab({ Title = "Camp",       Icon = "solar:home-2-bold" })
local MoviesTab     = Window:Tab({ Title = "Movies",     Icon = "solar:camera-bold" })
local ExpeditionTab = Window:Tab({ Title = "Expedition", Icon = "solar:map-bold" })
local MorphsTab     = Window:Tab({ Title = "Morphs",     Icon = "solar:user-bold" })

addWindowDivider()

local VisualsTab    = Window:Tab({ Title = "Visuals",    Icon = "solar:eye-bold" })
local ThemesTab     = Window:Tab({ Title = "Themes",     Icon = "solar:palette-bold" })
local TrollTab      = Window:Tab({ Title = "Troll",      Icon = "solar:ghost-bold" })
local UtilitiesTab  = Window:Tab({ Title = "Utilities",  Icon = "solar:settings-bold" })
local AutoplayTab   = Window:Tab({ Title = "Autoplay",   Icon = "solar:play-circle-bold" })

addWindowDivider()

local StatsTab      = Window:Tab({ Title = "Stats",      Icon = "solar:chart-bold" })
local TeamsTab      = Window:Tab({ Title = "Teams",      Icon = "solar:users-group-rounded-bold" })
local CharacterTab  = Window:Tab({ Title = "Character",  Icon = "solar:user-bold" })
local ClientTab     = Window:Tab({ Title = "Client",     Icon = "solar:cpu-bolt-bold" })

addWindowDivider()

local PracticeTab   = Window:Tab({ Title = "Practice",   Icon = "solar:sports-bold" })

MainTab:Select()

--[[
]]

MainTab:Section({ Title = "Votes" })

local function getVotesFolder()
    local season = ReplicatedStorage:FindFirstChild("Season")
    local voting = season and season:FindFirstChild("Voting")
    return voting and voting:FindFirstChild("Votes")
end

local function resolveName(season, value)
    if not season then return value end
    local list = season:FindFirstChild("Players")
    local found = list and list:FindFirstChild(value)
    return found and found.Value or value
end

MainTab:Toggle({
    Title    = "Notify Votes",
    Desc     = "Notifies you when someone casts a vote",
    Value    = false,
    Callback = safe(function(enabled)
        unbind("notifyVotes")
        if not enabled then return end
        local season = ReplicatedStorage:FindFirstChild("Season")
        local votes  = getVotesFolder()
        if not season or not votes then return warn("No Votes folder") end
        bind("notifyVotes", votes.ChildAdded:Connect(function(v)
            notify("Vote Update",
                resolveName(season, v.Value) .. " voted for " .. resolveName(season, v.Name), 4)
        end))
    end),
}, "NotifyVotes")

MainTab:Toggle({
    Title    = "Announce Votes",
    Desc     = "Says every cast vote in the general chat",
    Value    = false,
    Callback = safe(function(enabled)
        unbind("announceVotes")
        if not enabled then return end
        local season = ReplicatedStorage:FindFirstChild("Season")
        local votes  = getVotesFolder()
        if not season or not votes then return end
        bind("announceVotes", votes.ChildAdded:Connect(function(v)
            local voter  = resolveName(season, v.Value)
            local target = resolveName(season, v.Name)
            pcall(function()
                local tcs = game:GetService("TextChatService")
                local channels = tcs:FindFirstChild("TextChannels")
                local general = channels and channels:FindFirstChild("RBXGeneral")
                if general then
                    general:SendAsync(voter .. " voted for " .. target)
                end
            end)
        end))
    end),
}, "ExposeVotes")

MainTab:Toggle({
    Title    = "View Jury Votes",
    Desc     = "Notifies when a juror votes a finalist",
    Value    = false,
    Callback = safe(function(enabled)
        unbind("juryWatch")
        if not enabled then return end
        local season = ReplicatedStorage:FindFirstChild("Season")
        local jury   = season and season:FindFirstChild("Jury")
        if not jury then return end
        local conns = {}
        local function watch(j)
            local list = j:WaitForChild("List", 5)
            if not list then return end
            table.insert(conns, list.ChildAdded:Connect(function(v)
                local target = season.Players:FindFirstChild(v.Name)
                notify("Jury Vote",
                    j.Value .. " voted for " .. (target and target.Value or v.Value), 4)
            end))
        end
        for _, j in ipairs(jury:GetChildren()) do watch(j) end
        table.insert(conns, jury.ChildAdded:Connect(watch))
        bind("juryWatch", { Disconnect = function()
            for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        end })
    end),
}, "ViewJuryVotes")

MainTab:Toggle({
    Title    = "View Exile Votes",
    Desc     = "See who will be voted to exile",
    Value    = false,
    Callback = safe(function(enabled)
        unbind("exileVotes")
        if not enabled then return end
        local season = ReplicatedStorage:FindFirstChild("Season")
        local twists = season and season:FindFirstChild("Twists")
        local ev     = twists and twists:FindFirstChild("ExileVoting")
        local votes  = ev and ev:FindFirstChild("Votes")
        if not votes then return end
        bind("exileVotes", votes.ChildAdded:Connect(function(v)
            local voter  = season.Players:FindFirstChild(v.Value)
            local target = season.Players:FindFirstChild(v.Name)
            local msg = (voter and voter.Value or v.Value)
                .. " voted to exile "
                .. (target and target.Value or v.Name)
            notify("Exile Vote", msg, 4)
            print(msg)
        end))
    end),
}, "ViewExileVotes")

MainTab:Toggle({
    Title    = "Print Votes",
    Desc     = "Logs every votes in console",
    Value    = false,
    Callback = safe(function(enabled)
        unbind("printVotes")
        if not enabled then return end
        local season = ReplicatedStorage:FindFirstChild("Season")
        local votes  = getVotesFolder()
        if not season or not votes then return end
        bind("printVotes", votes.ChildAdded:Connect(function(v)
            print(string.format("[Vote] %s → %s",
                resolveName(season, v.Value), resolveName(season, v.Name)))
        end))
    end),
}, "PrintVotes")

--[[
]]

MainTab:Section({ Title = "Statue" })

MainTab:Button({
    Title    = "Find Statue (60% Spawn)",
    Desc     = "Get the statue",
    Icon     = "solar:diploma-bold",
    Callback = safe(function()
        local idols = workspace:FindFirstChild("Idols")
        if not idols then return end
        for _, obj in ipairs(idols:GetDescendants()) do
            if obj.Name == "Bag" or obj.Name == "SafetyStatue" then
                local hit = obj:FindFirstChild("hit")
                if hit then
                    hit.CanCollide = false
                    hit.Transparency = 1
                    task.wait()
                    local torso = LocalPlayer.Character
                        and LocalPlayer.Character:FindFirstChild("Torso")
                    if torso then hit.Position = torso.Position end
                    task.wait()
                end
            end
        end
    end),
})

MainTab:Button({
    Title    = "Get Statue on Spawn",
    Desc     = "Gives you the statue the moment u spawn",
    Icon     = "solar:magic-stick-3-bold",
    Callback = safe(function()
        local function tryGrab(obj)
            if not obj:IsA("BasePart") or obj.Name ~= "hit" then return end
            local parent = obj.Parent
            if not parent or (parent.Name ~= "Bag" and parent.Name ~= "SafetyStatue") then return end
            task.wait(0.1)
            obj.CanCollide = false
            obj.Transparency = 1
            task.spawn(function()
                while obj and obj.Parent do
                    local r = root()
                    if r then obj.CFrame = r.CFrame end
                    task.wait(0.05)
                end
            end)
        end
        if not S.Conns.statueGrab then
            bind("statueGrab", workspace.DescendantAdded:Connect(tryGrab))
        end
        for _, obj in ipairs(workspace:GetDescendants()) do tryGrab(obj) end
    end),
})

MainTab:Button({
    Title    = "Detect Who has Statue",
    Desc     = "Notifies who has the statue",
    Icon     = "solar:eye-bold",
    Callback = safe(function()
        local season = ReplicatedStorage:FindFirstChild("Season")
        local twists = season and season:FindFirstChild("Twists")
        local idol   = twists and twists:FindFirstChild("Idol")
        if not idol then return end
        if idol.Value == "" then
            notify("Statue Owner", "No one currently holds the statue.", 4)
        else
            local owner = season.Players:FindFirstChild(idol.Value)
            notify("Statue Owner",
                (owner and owner.Value or idol.Value) .. " has the statue.", 4)
        end
    end),
})

--[[
]]

MainTab:Section({ Title = "Extras" })

MainTab:Toggle({
    Title    = "Auto Detect Round",
    Desc     = "Detects the round twist",
    Value    = false,
    Callback = safe(function(enabled)
        unbind("roundTwist")
        if not enabled then return end
        local season = ReplicatedStorage:FindFirstChild("Season")
        local twist  = season and season.Twists
                       and season.Twists:FindFirstChild("CurrentTwist")
        if not twist then return end
        local names = {
            normal = "Normal Round", purge = "Purge Round",
            ["double"] = "Double Elimination", singleswap = "Sike Round",
            exile = "Exile Vote Round", votereveal = "Vote Reveal",
        }
        bind("roundTwist", twist:GetPropertyChangedSignal("Value"):Connect(function()
            if names[twist.Value] then notify("Round Detected", names[twist.Value], 4) end
        end))
    end),
}, "AutoDetectRound")

MainTab:Button({
    Title    = "Detect Teamers",
    Desc     = "Scans every account if they have friends in the lobby",
    Icon     = "solar:users-group-two-rounded-bold",
    Callback = safe(function()
        local season = ReplicatedStorage:FindFirstChild("Season")
        local list   = season and season:FindFirstChild("Players")
        if not list then return end
        local function nameOf(plr)
            local e = list:FindFirstChild(plr.Name)
            return (e and e.Value ~= "") and e.Value or plr.Name
        end
        local found, all = false, Players:GetPlayers()
        for i = 1, #all do
            for j = i + 1, #all do
                local ok, friends = pcall(function()
                    return all[i]:IsFriendsWith(all[j].UserId)
                end)
                if ok and friends then
                    found = true
                    notify("Teamer Detected!",
                        nameOf(all[i]) .. " is teaming with " .. nameOf(all[j]), 4)
                    task.wait(0.6)
                end
            end
        end
        if not found then
            notify("No Teamers Found", "No teamers detected at this round", 4)
        end
    end),
})

MainTab:Button({
    Title    = "Remove Cutscenes",
    Desc     = "Just goes to your camera immediately",
    Icon     = "solar:video-frame-play-horizontal-bold",
    Callback = safe(function()
        local events = ReplicatedStorage:FindFirstChild("Events")
        local cam    = events and events:FindFirstChild("Camera")
        if cam then cam:Destroy() end
        local h = humanoid()
        if h then
            workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            workspace.CurrentCamera.CameraSubject = h
        end
    end),
})

MainTab:Section({ Title = "Comebacks" })

local ComebacksGroup = MainTab:Group()
ComebacksGroup:Button({
    Title = "Comeback as Male", IconAlign = "Left", Justify = "Center",
    Icon = "solar:user-bold", Size = "Small",
    Callback = safe(function()
        local ev  = ReplicatedStorage:FindFirstChild("Events")
        local buy = ev and ev:FindFirstChild("Buy")
        if buy then buy:FireServer("Gender", "Male") end
    end),
})
ComebacksGroup:Space({ Columns = 0.5 })
ComebacksGroup:Button({
    Title = "Comeback as Female", IconAlign = "Left", Justify = "Center",
    Icon = "solar:user-bold", Size = "Small",
    Callback = safe(function()
        local ev  = ReplicatedStorage:FindFirstChild("Events")
        local buy = ev and ev:FindFirstChild("Buy")
        if buy then buy:FireServer("Gender", "Female") end
    end),
})

MainTab:Section({ Title = "Fly" })

MainTab:Button({
    Title    = "Universal Fly Gui V3",
    Desc     = "Loads the Universal Fly Gui V3 script",
    Icon     = "solar:paper-plane-bold",
    Callback = safe(function()
        task.spawn(function()
            local ok, err = pcall(function()
                loadstring(game:HttpGet(
                    "https://rawscripts.net/raw/Universal-Script-Universal-Fly-Gui-V3-15837"
                ))()
            end)
            if ok then notify("Fly V3", "Fly Gui loaded successfully.", 4)
            else notify("Fly V3 Error", tostring(err), 4) end
        end)
    end),
})

--[[
]]

MainTab:Section({ Title = "Nameplates" })

local NAMEPLATE_KEY = "SurrealNameplate"
local NAMEPLATE_GRADIENT = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(235, 235, 235)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(165, 165, 165)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(90, 90, 90)),
})

local NameplateManager = {}

function NameplateManager.attach(plr)
    local char = plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head or head:FindFirstChild(NAMEPLATE_KEY) then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = NAMEPLATE_KEY
    bb.Adornee = head
    bb.Size = UDim2.new(0, 150, 0, 30)
    bb.StudsOffset = Vector3.new(0, 3.75, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = 1500
    bb.Parent = head

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
    label.Parent = bb

    local g = Instance.new("UIGradient")
    g.Name = "NameGradient"
    g.Color = NAMEPLATE_GRADIENT
    g.Rotation = 90
    g.Parent = label
end

function NameplateManager.detach(plr)
    local char = plr.Character
    local head = char and char:FindFirstChild("Head")
    local existing = head and head:FindFirstChild(NAMEPLATE_KEY)
    if existing then existing:Destroy() end
end

function NameplateManager.enable()
    for _, plr in ipairs(Players:GetPlayers()) do NameplateManager.attach(plr) end
    S.Conns.npChars = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        table.insert(S.Conns.npChars, plr.CharacterAdded:Connect(function()
            task.wait(0.15)
            if S.Flags.nameplates then NameplateManager.attach(plr) end
        end))
    end
    bind("npPlayer", Players.PlayerAdded:Connect(function(plr)
        table.insert(S.Conns.npChars, plr.CharacterAdded:Connect(function()
            task.wait(0.15)
            if S.Flags.nameplates then NameplateManager.attach(plr) end
        end))
        if plr.Character then NameplateManager.attach(plr) end
    end))
end

function NameplateManager.disable()
    for _, plr in ipairs(Players:GetPlayers()) do NameplateManager.detach(plr) end
    unbind("npPlayer")
    if S.Conns.npChars then
        for _, c in ipairs(S.Conns.npChars) do
            pcall(function() c:Disconnect() end)
        end
        S.Conns.npChars = {}
    end
end

MainTab:Toggle({
    Title    = "Global Nameplates",
    Desc     = "See everyone's display names",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.nameplates = enabled
        if enabled then NameplateManager.enable()
        else NameplateManager.disable() end
    end),
}, "GlobalNameplates")

MainTab:Section({ Title = "Hacker Detector" })

local Detector = {
    data = {}, cooldowns = {},
    SPEED_STUDSPS = 45, WALK_SPEED_FLAG = 35, JUMP_POWER_FLAG = 90,
    TELEPORT_DISTANCE = 250, AIR_TIME_FLAG = 3.5, SIZE_DEVIATION = 3,
    SWORD_SWING_LIMIT = 8, FLAG_COOLDOWN = 12,
}

local function canFlag(plr, kind)
    local cd = Detector.cooldowns[plr]
    if not cd then cd = {}; Detector.cooldowns[plr] = cd end
    local last = cd[kind]
    if last and (tick() - last) < Detector.FLAG_COOLDOWN then return false end
    cd[kind] = tick()
    return true
end

local function flagPlayer(plr, reason, detail)
    if plr == LocalPlayer then return end
    local msg = reason .. (detail and (" — " .. detail) or "")
    notify("⚠ " .. plr.Name, msg, 5)
end

local function track(plr)
    local char = plr.Character
    if not char then return end
    local r = char:FindFirstChild("HumanoidRootPart")
    if not r then return end
    Detector.data[plr] = {
        lastPos = r.Position, lastCheck = tick(), airTime = 0,
        swingCount = 0, swingWindow = tick(), baseSize = r.Size,
    }
end

local function scan(plr)
    if plr == LocalPlayer then return end
    local char = plr.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local r = char:FindFirstChild("HumanoidRootPart")
    if not hum or not r then return end
    if not Detector.data[plr] then track(plr) return end
    local d = Detector.data[plr]
    local now = tick()
    local dt = now - d.lastCheck
    if dt < 0.4 then return end

    if hum.WalkSpeed > Detector.WALK_SPEED_FLAG and canFlag(plr, "ws") then
        flagPlayer(plr, "Speed Hack", string.format("WalkSpeed = %.0f", hum.WalkSpeed))
    end
    if hum.UseJumpPower and hum.JumpPower > Detector.JUMP_POWER_FLAG
       and canFlag(plr, "jp") then
        flagPlayer(plr, "Jump Hack", string.format("JumpPower = %.0f", hum.JumpPower))
    end
    local dist = (r.Position - d.lastPos).Magnitude
    local studsps = dist / dt
    if studsps > Detector.SPEED_STUDSPS and canFlag(plr, "speed") then
        flagPlayer(plr, "Speed Hack", string.format("%.0f studs/sec", studsps))
    end
    if dist > Detector.TELEPORT_DISTANCE and dt < 2 and canFlag(plr, "tp") then
        flagPlayer(plr, "Teleport", string.format("%.0f studs in %.1fs", dist, dt))
    end
    if hum.FloorMaterial == Enum.Material.Air then
        d.airTime = (d.airTime or 0) + dt
        if d.airTime >= Detector.AIR_TIME_FLAG and canFlag(plr, "fly") then
            flagPlayer(plr, "Fly / Hover", string.format("airborne %.1fs", d.airTime))
            d.airTime = 0
        end
    else
        d.airTime = 0
    end
    if d.baseSize then
        local diff = (r.Size - d.baseSize).Magnitude
        if diff > Detector.SIZE_DEVIATION and canFlag(plr, "size") then
            flagPlayer(plr, "Size Changer", string.format("Δ %.1f studs", diff))
        end
    end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and tool.Name:lower():find("sword") then
        d.swingCount = d.swingCount + 1
        if now - d.swingWindow > 1 then
            if d.swingCount > Detector.SWORD_SWING_LIMIT and canFlag(plr, "swing") then
                flagPlayer(plr, "Kill Aura", d.swingCount .. " swings/sec")
            end
            d.swingCount = 0
            d.swingWindow = now
        end
    end
    d.lastPos = r.Position
    d.lastCheck = now
end

MainTab:Toggle({
    Title    = "Hacker Detector",
    Desc     = "Flags suspicious behaviors in real time",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.detector = enabled
        unbind("detectScan"); unbind("detectJoin"); unbind("detectLeave")
        if not enabled then
            Detector.data = {}; Detector.cooldowns = {}
            return
        end
        Detector.data = {}; Detector.cooldowns = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then track(p) end
        end
        bind("detectJoin", Players.PlayerAdded:Connect(function(p)
            p.CharacterAdded:Connect(function()
                task.wait(0.3); track(p)
            end)
        end))
        bind("detectLeave", Players.PlayerRemoving:Connect(function(p)
            Detector.data[p] = nil; Detector.cooldowns[p] = nil
        end))
        bind("detectScan", task.spawn(function()
            while S.Flags.detector do
                for _, p in ipairs(Players:GetPlayers()) do pcall(scan, p) end
                task.wait(1.2)
            end
        end))
        notify("Hacker Detector", "Watching for suspicious players.", 4)
    end),
}, "HackerDetector")

--[[
]]

if isCamp then

CampTab:Section({ Title = "Challenges" })

CampTab:Button({
    Title    = "Win Obby",
    Desc     = "Makes you win an Obby",
    Icon     = "solar:flag-bold",
    Callback = safe(function()
        local finish = workspace:FindFirstChild("Assets")
            and workspace.Assets:FindFirstChild("Finish", true)
        if not finish then return end
        finish.CanCollide = false
        finish.Transparency = 1
        task.wait()
        local torso = LocalPlayer.Character
            and LocalPlayer.Character:FindFirstChild("Torso")
        if torso then finish.Position = torso.Position end
    end),
})

CampTab:Toggle({
    Title    = "Auto Win Obby",
    Desc     = "Win every Obby without pressing win Obby",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.autoWinObby = enabled
        if not enabled then return end
        task.spawn(function()
            while S.Flags.autoWinObby do
                local finish = workspace:FindFirstChild("Assets")
                    and workspace.Assets:FindFirstChild("Finish", true)
                local r = root()
                if finish and r then
                    finish.CanCollide = false
                    finish.Transparency = 1
                    task.wait()
                    finish.Position = r.Position
                end
                task.wait(0.1)
            end
        end)
    end),
}, "AutoWinObby")

CampTab:Button({
    Title    = "Remove all Spleef Studs",
    Desc     = "Makes Spleef have no studs and everyone falls",
    Icon     = "solar:trash-bin-bold",
    Callback = safe(function()
        local r = root()
        if not r then return end
        local assets = workspace:FindFirstChild("Assets")
        if not assets then return end
        for _, obj in ipairs(assets:GetDescendants()) do
            if obj.Name == "SpleefPart" then
                if executorFireTouch then pcall(executorFireTouch, r, obj, 0) end
            end
        end
    end),
})

CampTab:Button({
    Title    = "Finish Pancake",
    Desc     = "Rapidly clicks your pancake",
    Icon     = "solar:chef-hat-bold",
    Callback = safe(function()
        local assets = workspace:FindFirstChild("Assets")
        if not assets then return end
        for _, obj in ipairs(assets:GetDescendants()) do
            if obj.Name == LocalPlayer.Name
               and obj:FindFirstChild("ClickDetector") then
                if executorFireClick then for _ = 1, 80 do pcall(executorFireClick, obj.ClickDetector) end end
            end
        end
    end),
})

CampTab:Toggle({
    Title    = "Cliff Diving ESP",
    Desc     = "Automatically find the finish line",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.cliffESP = enabled
        S.Flags.cliffObjects = S.Flags.cliffObjects or {}
        if not enabled then
            for _, m in pairs(S.Flags.cliffObjects) do
                pcall(function() m.billboard:Destroy() end)
            end
            S.Flags.cliffObjects = {}
            unbind("cliffAdd"); unbind("cliffRem"); unbind("cliffRender")
            return
        end
        local MAX_DIST = 500
        local function create(part)
            if S.Flags.cliffObjects[part] then return end
            local bb = Instance.new("BillboardGui")
            bb.AlwaysOnTop = true
            bb.Size = UDim2.new(0, 260, 0, 70)
            bb.StudsOffset = Vector3.new(0, 4, 0)
            bb.Adornee = part
            bb.Parent = part
            local lbl = Instance.new("TextLabel")
            lbl.BackgroundTransparency = 1
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.TextColor3 = Color3.new(1, 1, 1)
            lbl.TextStrokeTransparency = 0
            lbl.TextScaled = true
            lbl.Font = Enum.Font.GothamBold
            lbl.Text = "FINISH"
            lbl.Parent = bb
            S.Flags.cliffObjects[part] = { billboard = bb, label = lbl }
        end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name:lower() == "finish" then create(obj) end
        end
        bind("cliffAdd", workspace.DescendantAdded:Connect(function(obj)
            if S.Flags.cliffESP and obj:IsA("BasePart")
               and obj.Name:lower() == "finish" then create(obj) end
        end))
        bind("cliffRem", workspace.DescendantRemoving:Connect(function(obj)
            if S.Flags.cliffObjects[obj] then
                pcall(function() S.Flags.cliffObjects[obj].billboard:Destroy() end)
                S.Flags.cliffObjects[obj] = nil
            end
        end))
        bind("cliffRender", RunService.RenderStepped:Connect(function()
            if not S.Flags.cliffESP then return end
            local r = root()
            if not r then return end
            for part, m in pairs(S.Flags.cliffObjects) do
                local dist = (part.Position - r.Position).Magnitude
                m.billboard.Enabled = dist <= MAX_DIST
                if dist <= MAX_DIST then
                    m.label.Text = string.format("%.1f studs", dist)
                end
            end
        end))
    end),
}, "CliffDivingESP")

CampTab:Toggle({
    Title    = "Auto Get All Coins",
    Desc     = "Teleports every coin and gem to you",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.autoCollect = enabled
        if not enabled then return end
        task.spawn(function()
            while S.Flags.autoCollect do
                task.wait(0.5)
                local r = root()
                local assets = workspace:FindFirstChild("Assets")
                if r and assets then
                    for _, obj in ipairs(assets:GetDescendants()) do
                        if (obj.Name == "Coin" or obj.Name == "Gem")
                           and obj:IsA("BasePart") then
                            obj.CanCollide = false
                            obj.Position = r.Position
                        end
                    end
                end
            end
        end)
    end),
}, "AutoGetCoins")

CampTab:Toggle({
    Title    = "Answer Math Mania",
    Desc     = "Answer every question easily",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.autoMath = enabled
        if not enabled then return end
        task.spawn(function()
            while S.Flags.autoMath do
                pcall(function()
                    local gui = LocalPlayer.PlayerGui:FindFirstChild("MathMania")
                    if gui then
                        for i = 1, 10 do
                            if not S.Flags.autoMath then break end
                            local q = gui:FindFirstChild(tostring(i))
                            if q and q:FindFirstChild("MainText")
                               and q:FindFirstChild("Box") then
                                local expr = q.MainText.Text
                                    :gsub("=", ""):gsub("%?", ""):gsub(" ", "")
                                local ok, res = pcall(function()
                                    return loadstring("return " .. expr)()
                                end)
                                if ok and res then
                                    q.Box.Text = tostring(res)
                                    local sub = q:FindFirstChild("Enter")
                                    if sub then
                                        for _, ev in ipairs({
                                            "MouseButton1Click",
                                            "MouseButton1Down",
                                            "Activated",
                                        }) do
                                            if sub[ev] and getconnections then
                                                for _, c in pairs(getconnections(sub[ev])) do
                                                    if c.Function then
                                                        pcall(function() c:Fire() end)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                    if S.Flags.mathDelay > 0 then
                                        task.wait(S.Flags.mathDelay)
                                    end
                                end
                            end
                        end
                    end
                end)
                task.wait()
            end
        end)
    end),
}, "AnswerMathMania")

CampTab:Slider({
    Title     = "Math Mania Setback",
    Desc      = "Adds a delay",
    IsTooltip = true,
    Step      = 1,
    Value     = { Min = 0, Max = 100, Default = 0 },
    Callback  = safe(function(v) S.Flags.mathDelay = v / 10 end),
}, "MathManiaSetback")

--[[
]]

CampTab:Button({
    Title    = "Win Blockpush",
    Desc     = "Teleports block to finishing line",
    Icon     = "solar:box-bold",
    Callback = safe(function()
        local r = root()
        if not r then return end
        for _, box in ipairs(workspace:GetDescendants()) do
            if box:IsA("Part") and box.Name == "SingularBox" then
                if (box.Position - r.Position).Magnitude <= 100 then
                    for _, target in ipairs(workspace:GetDescendants()) do
                        if target:IsA("Part") and target.Name == "Gold" then
                            box.Position = target.Position + Vector3.new(0, 3, 0)
                            r.CFrame = CFrame.new(box.Position + Vector3.new(0, 3, 0))
                            break
                        end
                    end
                    break
                end
            end
        end
    end),
})

CampTab:Toggle({
    Title    = "Dodgeball Invincibility",
    Desc     = "Resets you (you do not die)",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.dodgeGuard = enabled
        if not enabled then return end
        task.spawn(function()
            local triggered = false
            while S.Flags.dodgeGuard do
                pcall(function()
                    local assets = workspace:FindFirstChild("Assets")
                    if assets then
                        local giver = assets:FindFirstChild("DodgeballGiver", true)
                        if giver and not triggered then
                            triggered = true
                            local h = humanoid()
                            if h then h.Health = 0 end
                        end
                        if not giver then triggered = false end
                    end
                end)
                task.wait(0.1)
            end
        end)
    end),
}, "DodgeballInvincibility")

CampTab:Button({
    Title    = "Get Dodgeballs",
    Desc     = "Get every dodgeball",
    Icon     = "solar:basketball-bold",
    Callback = safe(function()
        local r = root()
        if not r then return end
        local assets = workspace:FindFirstChild("Assets")
        if not assets then return end
        for _, obj in ipairs(assets:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name:lower():find("dodgeball") then
                if executorFireTouch then pcall(executorFireTouch, r, obj, 0) end
                if executorFireTouch then pcall(executorFireTouch, r, obj, 1) end
            end
        end
    end),
})

CampTab:Toggle({
    Title    = "Paintball Invincibility",
    Desc     = "Resets you b4 the game start (you do not die)",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.paintGuard = enabled
        if not enabled then return end
        task.spawn(function()
            local triggered = false
            while S.Flags.paintGuard do
                pcall(function()
                    local assets = workspace:FindFirstChild("Assets")
                    if assets then
                        local arena = assets:FindFirstChild("Paintball", true)
                            or assets:FindFirstChild("PaintballArena", true)
                        if arena and not triggered then
                            triggered = true
                            local h = humanoid()
                            if h then h.Health = 0 end
                        end
                        if not arena then triggered = false end
                    end
                end)
                task.wait(0.1)
            end
        end)
    end),
}, "PaintballInvincibility")

CampTab:Button({
    Title    = "Kill Everyone in Swordfight",
    Desc     = "Expands hitbox and kills everyone",
    Icon     = "solar:sword-bold",
    Callback = safe(function()
        local bp = LocalPlayer:FindFirstChild("Backpack")
        local c  = LocalPlayer.Character
        if bp and c then
            local sword
            for _, t in ipairs(bp:GetChildren()) do
                if t:IsA("Tool") and t.Name:lower():find("sword") then
                    sword = t; break
                end
            end
            local h = c:FindFirstChildOfClass("Humanoid")
            if sword and h then h:EquipTool(sword) end
        end
        unbind("swordFight")
        bind("swordFight", RunService.RenderStepped:Connect(function()
            pcall(function()
                local all = Players:GetPlayers()
                for i = 2, #all do
                    local target = all[i].Character
                    if target and not LocalPlayer:IsFriendsWith(all[i].UserId) then
                        local cc = LocalPlayer.Character
                        local tool = cc and cc:FindFirstChildOfClass("Tool")
                        if tool and tool:FindFirstChild("Handle") then
                            tool:Activate()
                            for _, p in ipairs(target:GetChildren()) do
                                if p:IsA("BasePart") then
                                    executorFireTouch and executorFireTouch(tool.Handle, p, 0)
                                    executorFireTouch and executorFireTouch(tool.Handle, p, 1)
                                end
                            end
                        end
                    end
                end
            end)
        end))
        task.delay(1, function() unbind("swordFight") end)
    end),
})

CampTab:Button({
    Title    = "FE Genesis Sniper",
    Desc     = "Restarts the finale (server-wide)",
    Icon     = "solar:refresh-circle-bold",
    Callback = safe(function()
        task.spawn(function()
            local ok = pcall(function()
                loadstring(game:HttpGet(
                    "https://raw.githubusercontent.com/GenesisFE/Genesis/main/Obfuscations/Sniper"
                ))()
            end)
            if ok then notify("Genesis Sniper", "Loaded", 4) end
        end)
    end),
})

CampTab:Section({ Title = "Spleef Godmode" })

local Spleef = { enabled = false, conns = {} }

local function stripTouch(part)
    if not part then return 0 end
    local n = 0
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("TouchTransmitter") then
            pcall(function() child:Destroy() end); n = n + 1
        elseif child.ClassName == "TouchInterest" then
            pcall(function() child:Destroy() end); n = n + 1
        end
    end
    return n
end

local function findSpleefParts()
    local out = {}
    local assets = workspace:FindFirstChild("Assets")
    if not assets then return out end
    local spleef = assets:FindFirstChild("Spleef")
    if not spleef then return out end
    for _, obj in ipairs(spleef:GetDescendants()) do
        if obj:IsA("BasePart") then table.insert(out, obj) end
    end
    return out
end

local function applyOnce()
    local parts = findSpleefParts()
    local total = 0
    for _, part in ipairs(parts) do
        total = total + stripTouch(part)
    end
    return total, #parts
end

CampTab:Toggle({
    Title    = "Spleef Godmode",
    Desc     = "Destroys the touch handler on Spleef parts",
    Value    = false,
    Callback = safe(function(enabled)
        Spleef.enabled = enabled
        for _, c in ipairs(Spleef.conns) do pcall(function() c:Disconnect() end) end
        Spleef.conns = {}
        if not enabled then return end

        local stripped, parts = applyOnce()
        print(string.format("[Spleef] Stripped %d handler(s) across %d part(s)",
            stripped, parts))

        local assets = workspace:FindFirstChild("Assets")
        if assets then
            table.insert(Spleef.conns, assets.DescendantAdded:Connect(function(obj)
                if not Spleef.enabled then return end
                if obj:IsA("TouchTransmitter") then
                    local p = obj.Parent
                    if p and p:IsA("BasePart") and p:IsDescendantOf(assets) then
                        local sp = assets:FindFirstChild("Spleef")
                        if sp and p:IsDescendantOf(sp) then
                            pcall(function() obj:Destroy() end)
                        end
                    end
                elseif obj:IsA("BasePart") then
                    local sp = assets:FindFirstChild("Spleef")
                    if sp and obj:IsDescendantOf(sp) then stripTouch(obj) end
                end
            end))
        end

        Spleef._tick = 0
        table.insert(Spleef.conns, RunService.Heartbeat:Connect(function()
            if not Spleef.enabled then return end
            Spleef._tick = Spleef._tick + 1
            if Spleef._tick % 30 == 0 then applyOnce() end
        end))
    end),
}, "SpleefGodmode")

else
    CampTab:Paragraph({
        Title   = "Not Available",
        Content = "The Camp tab only works in Camp (PlaceId 4939362930).\n"
               .. "Current PlaceId: " .. game.PlaceId,
    })
end

--[[
]]

if isMovies then

MoviesTab:Section({ Title = "Challenges" })

MoviesTab:Button({
    Title    = "Win Obby",
    Icon     = "solar:flag-bold",
    Callback = safe(function()
        local finish = workspace:FindFirstChild("Assets")
            and workspace.Assets:FindFirstChild("Finish", true)
        if not finish then return end
        finish.CanCollide = false
        finish.Transparency = 1
        task.wait()
        local torso = LocalPlayer.Character
            and LocalPlayer.Character:FindFirstChild("Torso")
        if torso then finish.Position = torso.Position end
    end),
})

MoviesTab:Toggle({
    Title    = "Auto Win Obby",
    Desc     = "Win every Obby",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.movAutoWinObby = enabled
        if not enabled then return end
        task.spawn(function()
            while S.Flags.movAutoWinObby do
                local finish = workspace:FindFirstChild("Assets")
                    and workspace.Assets:FindFirstChild("Finish", true)
                local r = root()
                if finish and r then
                    finish.CanCollide = false
                    finish.Transparency = 1
                    task.wait()
                    finish.Position = r.Position
                end
                task.wait(0.5)
            end
        end)
    end),
}, "MoviesAutoWinObby")

MoviesTab:Toggle({
    Title    = "Auto Restart Day",
    Desc     = "Reanimates when the round ends",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.movAutoRestart = enabled
        local fired = false
        if not enabled then return end
        task.spawn(function()
            while S.Flags.movAutoRestart do
                local timerVisible = false
                pcall(function()
                    timerVisible = LocalPlayer.PlayerGui.Timer.Background.Timer.Visible
                end)
                if timerVisible and not fired then
                    fired = true
                    loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/robloxcheatck/reanimatescript/main/script.lua",
                        true
                    ))()
                end
                if not timerVisible then fired = false end
                task.wait(0.05)
            end
        end)
    end),
}, "MoviesAutoRestart")

MoviesTab:Toggle({
    Title    = "Infect All",
    Desc     = "Teleport to every player during infection round",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.movInfectAll = enabled
        if not enabled then return end
        task.spawn(function()
            while S.Flags.movInfectAll do
                local timerVisible = false
                pcall(function()
                    timerVisible = LocalPlayer.PlayerGui.Timer.Background.Timer.Visible
                end)
                if not timerVisible then break end
                local hrp = root()
                if hrp then
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and S.Flags.movInfectAll then
                            local tChar = p.Character
                            local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
                            if tHrp then hrp.CFrame = tHrp.CFrame; task.wait(0.3) end
                        end
                    end
                end
                task.wait(0.1)
            end
        end)
    end),
}, "MoviesInfectAll")

MoviesTab:Toggle({
    Title    = "Disable Fires",
    Desc     = "Removes every fire touch handler",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.movDisableFires = enabled
        unbind("movFires")
        if not enabled then return end
        local function stripFires()
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("TouchTransmitter") then
                    pcall(function() v:Destroy() end)
                end
            end
        end
        stripFires()
        bind("movFires", RunService.Stepped:Connect(function()
            if S.Flags.movDisableFires then stripFires() end
        end))
    end),
}, "MoviesDisableFires")

MoviesTab:Button({
    Title    = "Disable Lasers",
    Icon     = "solar:bolt-slash-bold",
    Callback = safe(function()
        for _, part in ipairs(workspace:GetDescendants()) do
            if part:IsA("BasePart")
               and part.Name:lower():find("laser") then
                for _, v in ipairs(part:GetChildren()) do
                    if v:IsA("TouchTransmitter") then
                        v:Destroy()
                    end
                end
            end
        end
    end),
})

MoviesTab:Toggle({
    Title    = "Auto Solve Math Trivia",
    Desc     = "Answer every question easily",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.movAutoMath = enabled
        if not enabled then return end
        task.spawn(function()
            while S.Flags.movAutoMath do
                pcall(function()
                    local gui = LocalPlayer.PlayerGui:FindFirstChild("MathTrivia")
                        or LocalPlayer.PlayerGui:FindFirstChild("MathMania")
                    if gui then
                        for i = 1, 10 do
                            if not S.Flags.movAutoMath then break end
                            local q = gui:FindFirstChild(tostring(i))
                            if q and q:FindFirstChild("MainText")
                               and q:FindFirstChild("Box") then
                                local expr = q.MainText.Text
                                    :gsub("=", ""):gsub("%?", ""):gsub(" ", "")
                                local ok, res = pcall(function()
                                    return loadstring("return " .. expr)()
                                end)
                                if ok and res then
                                    q.Box.Text = tostring(res)
                                    local sub = q:FindFirstChild("Enter")
                                    if sub then
                                        for _, ev in ipairs({
                                            "MouseButton1Click",
                                            "MouseButton1Down",
                                            "Activated",
                                        }) do
                                            if sub[ev] and getconnections then
                                                for _, c in pairs(getconnections(sub[ev])) do
                                                    if c.Function then
                                                        pcall(function() c:Fire() end)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
                task.wait()
            end
        end)
    end),
}, "MoviesMathTrivia")

MoviesTab:Button({
    Title    = "Collect Keys & Open Chests",
    Icon     = "solar:key-bold",
    Callback = safe(function()
        local pa = workspace.Assets:FindFirstChild("Pirate")
        if not pa then return end
        local function getKey()
            for _, v in ipairs(LocalPlayer.Backpack:GetChildren()) do
                if v:IsA("Tool") then return v end
            end
            for _, v in ipairs(LocalPlayer.Character:GetChildren()) do
                if v:IsA("Tool") then return v end
            end
        end
        while true do
            local kf
            for _, v in ipairs(pa:GetDescendants()) do
                if v.Name == "MainKey" then kf = v; break end
            end
            if not kf then break end
            LocalPlayer.Character.HumanoidRootPart.CFrame = kf.CFrame
            task.wait(0.25)
            local kt, t = nil, 0
            while t < 5 and not kt do
                kt = getKey()
                if not kt then task.wait(0.1); t = t + 0.1 end
            end
            if not kt then break end
            kt.Parent = LocalPlayer.Character
            task.wait(0.05)
            local cf = pa:FindFirstChild("Chests")
            if cf then
                local cm = cf:FindFirstChild(kt.Name)
                if cm then
                    local ch = cm:FindFirstChild("Chest")
                    if ch then
                        LocalPlayer.Character.HumanoidRootPart.CFrame = ch.CFrame
                        task.wait(0.15)
                    end
                end
            end
        end
    end),
})

MoviesTab:Button({
    Title    = "Monster Godmode",
    Icon     = "solar:ghost-bold",
    Callback = safe(function()
        local m = workspace.Assets:FindFirstChild("Monster")
        if not m then return end
        local n = m:FindFirstChild("MonsterNPC")
        if n then n:Destroy() end
    end),
})

MoviesTab:Toggle({
    Title    = "Auto Collect Ancient Artifacts",
    Value    = false,
    Callback = safe(function(enabled)
        unbind("movArtifacts")
        if not enabled then return end
        local ph = workspace.Assets:WaitForChild("Pre-Historic", 5)
        if not ph then return end
        local cf = ph:WaitForChild("Coins", 5)
        if not cf then return end
        bind("movArtifacts", cf.ChildAdded:Connect(function(coin)
            local r = root()
            if r then
                coin.Position = r.Position
                coin.Transparency = 0
                coin.CanCollide = false
            end
        end))
    end),
}, "MoviesArtifacts")

MoviesTab:Toggle({
    Title    = "Auto Collect Guitars",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.movGuitars = enabled
        if not enabled then return end
        task.spawn(function()
            while S.Flags.movGuitars do
                task.wait(0.1)
                local torso = LocalPlayer.Character
                    and LocalPlayer.Character:FindFirstChild("Torso")
                if torso then
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj.Name == "Gem" or obj.Name == "Coin" then
                            obj.Transparency = 1
                            obj.Position = torso.Position
                        end
                    end
                end
            end
        end)
    end),
}, "MoviesGuitars")

MoviesTab:Button({
    Title    = "Finish Poison Food",
    Icon     = "solar:chef-hat-bold",
    Callback = safe(function()
        for _, v in pairs(workspace.Assets:GetDescendants()) do
            if v.Name == LocalPlayer.Name
               and v:FindFirstChild("ClickDetector") then
                if executorFireClick then for _ = 1, 80 do pcall(executorFireClick, v.ClickDetector) end end
            end
        end
    end),
})

MoviesTab:Toggle({
    Title    = "Kill Everyone in Beach Fight",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.movBeachKill = enabled
        unbind("movBeach")
        if not enabled then return end
        task.spawn(function()
            while S.Flags.movBeachKill do
                local bp = LocalPlayer:FindFirstChild("Backpack")
                local c  = LocalPlayer.Character
                if bp and c then
                    local tool
                    for _, t in ipairs(bp:GetChildren()) do
                        if t:IsA("Tool") and t.Name:lower():find("pool noodle") then
                            tool = t; break
                        end
                    end
                    local h = c:FindFirstChildOfClass("Humanoid")
                    if tool and h then h:EquipTool(tool) end
                end
                task.wait()
            end
        end)
        bind("movBeach", RunService.RenderStepped:Connect(function()
            local all = Players:GetPlayers()
            for i = 2, #all do
                local other = all[i]
                local character = other.Character
                if character and not LocalPlayer:IsFriendsWith(other.UserId) then
                    local tool = LocalPlayer.Character
                        and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                    if tool and tool:FindFirstChild("Handle") then
                        tool:Activate()
                        for _, part in next, character:GetChildren() do
                            if part:IsA("BasePart") then
                                executorFireTouch and executorFireTouch(tool.Handle, part, 0)
                                executorFireTouch and executorFireTouch(tool.Handle, part, 1)
                            end
                        end
                    end
                end
            end
        end))
    end),
}, "MoviesBeachKill")

MoviesTab:Section({ Title = "Teleports" })

local MOVIES_TELEPORTS = {
    { "Dock",           -187,  52,    5   },
    { "Voting Area",      89,  63, -148   },
    { "Confessionals",    17,  65,  -24   },
    { "Challenge",       357,  64, -257   },
    { "Aftermath",      -669, -66, -666   },
}

for _, loc in ipairs(MOVIES_TELEPORTS) do
    MoviesTab:Button({
        Title    = loc[1],
        Desc     = string.format("X %d · Y %d · Z %d", loc[2], loc[3], loc[4]),
        Icon     = "solar:map-point-bold",
        Callback = safe(function()
            teleport(loc[2], loc[3], loc[4])
            notify("Teleport", loc[1])
        end),
    })
end

else
    MoviesTab:Paragraph({
        Title   = "Not Available",
        Content = "The Movies tab only works in Movies (PlaceId 4939362610).\n"
               .. "Current PlaceId: " .. game.PlaceId,
    })
end

--[[
]]

if isExpedition then

ExpeditionTab:Section({ Title = "Challenges" })

ExpeditionTab:Button({
    Title    = "Win Obby",
    Icon     = "solar:flag-bold",
    Callback = safe(function()
        local finish = workspace:FindFirstChild("Assets")
            and workspace.Assets:FindFirstChild("Finish", true)
        if not finish then return end
        finish.CanCollide = false
        finish.Transparency = 1
        task.wait()
        local torso = LocalPlayer.Character
            and LocalPlayer.Character:FindFirstChild("Torso")
        if torso then finish.Position = torso.Position end
    end),
})

ExpeditionTab:Toggle({
    Title    = "Auto Win Obby",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.expAutoWinObby = enabled
        if not enabled then return end
        task.spawn(function()
            while S.Flags.expAutoWinObby do
                local finish = workspace:FindFirstChild("Assets")
                    and workspace.Assets:FindFirstChild("Finish", true)
                local r = root()
                if finish and r then
                    finish.CanCollide = false
                    finish.Transparency = 1
                    task.wait()
                    finish.Position = r.Position
                end
                task.wait(0.5)
            end
        end)
    end),
}, "ExpeditionAutoWinObby")

ExpeditionTab:Toggle({
    Title    = "Auto Restart Day",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.expAutoRestart = enabled
        local fired = false
        if not enabled then return end
        task.spawn(function()
            while S.Flags.expAutoRestart do
                local timerVisible = false
                pcall(function()
                    timerVisible = LocalPlayer.PlayerGui.Timer.Background.Timer.Visible
                end)
                if timerVisible and not fired then
                    fired = true
                    loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/robloxcheatck/reanimatescript/main/script.lua",
                        true
                    ))()
                end
                if not timerVisible then fired = false end
                task.wait(0.05)
            end
        end)
    end),
}, "ExpeditionAutoRestart")

ExpeditionTab:Button({
    Title    = "Break Amazon (Spleef)",
    Icon     = "solar:trash-bin-bold",
    Callback = safe(function()
        for _, v in pairs(workspace.Assets:GetDescendants()) do
            if v.Name == "SpleefPart" then
                executorFireTouch and executorFireTouch(LocalPlayer.Character.HumanoidRootPart, v, 0)
            end
        end
    end),
})

ExpeditionTab:Toggle({
    Title    = "Auto Solve Math Mania",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.expAutoMath = enabled
        if not enabled then return end
        task.spawn(function()
            while S.Flags.expAutoMath do
                pcall(function()
                    local gui = LocalPlayer.PlayerGui:FindFirstChild("MathMania")
                        or LocalPlayer.PlayerGui:FindFirstChild("MathTrivia")
                    if gui then
                        for i = 1, 10 do
                            if not S.Flags.expAutoMath then break end
                            local q = gui:FindFirstChild(tostring(i))
                            if q and q:FindFirstChild("MainText")
                               and q:FindFirstChild("Box") then
                                local expr = q.MainText.Text
                                    :gsub("=", ""):gsub("%?", ""):gsub(" ", "")
                                local ok, res = pcall(function()
                                    return loadstring("return " .. expr)()
                                end)
                                if ok and res then
                                    q.Box.Text = tostring(res)
                                    local sub = q:FindFirstChild("Enter")
                                    if sub then
                                        for _, ev in ipairs({
                                            "MouseButton1Click",
                                            "MouseButton1Down",
                                            "Activated",
                                        }) do
                                            if sub[ev] and getconnections then
                                                for _, c in pairs(getconnections(sub[ev])) do
                                                    if c.Function then
                                                        pcall(function() c:Fire() end)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
                task.wait()
            end
        end)
    end),
}, "ExpeditionMath")

ExpeditionTab:Toggle({
    Title    = "Auto Collect Clovers",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.expClovers = enabled
        if not enabled then return end
        task.spawn(function()
            while S.Flags.expClovers do
                task.wait(0.1)
                local torso = LocalPlayer.Character
                    and LocalPlayer.Character:FindFirstChild("Torso")
                if torso then
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj.Name == "Gem" or obj.Name == "Coin" then
                            obj.Transparency = 1
                            obj.Position = torso.Position
                        end
                    end
                end
            end
        end)
    end),
}, "ExpeditionClovers")

ExpeditionTab:Toggle({
    Title    = "Auto Collect Rings",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.expRings = enabled
        if not enabled then return end
        task.spawn(function()
            while S.Flags.expRings do
                task.wait(0.1)
                local torso = LocalPlayer.Character
                    and LocalPlayer.Character:FindFirstChild("Torso")
                if torso then
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj.Name == "RingHitbox" then
                            obj.Transparency = 1
                            obj.Position = torso.Position
                        end
                    end
                end
            end
        end)
    end),
}, "ExpeditionRings")

ExpeditionTab:Button({
    Title    = "Auto Win Cheese Push",
    Icon     = "solar:box-bold",
    Callback = safe(function()
        local char = LocalPlayer.Character
        local r = char and char:FindFirstChild("HumanoidRootPart")
        if not r then return end
        local myPos = r.Position
        local cc, cd = nil, math.huge
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("Model") and v.Name == "Cheese" then
                local d = (v:GetPivot().Position - myPos).Magnitude
                if d < cd then cd = d; cc = v end
            end
        end
        local ch, hd = nil, math.huge
        for _, v in ipairs(workspace:GetDescendants()) do
            if v.Name == "Hitbox" and v:IsA("BasePart") then
                local d = (v.Position - myPos).Magnitude
                if d < hd then hd = d; ch = v end
            end
        end
        if not cc then return notify("Cheese", "No cheese found") end
        if not ch then return notify("Cheese", "No hitbox found") end
        for _, part in ipairs(cc:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = false
                part.CFrame = CFrame.new(ch.Position)
            end
        end
        notify("Cheese", "Cheese teleported")
    end),
})

ExpeditionTab:Toggle({
    Title    = "Kill Everyone in Greece",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.expGreeceKill = enabled
        unbind("expGreece")
        if not enabled then return end
        task.spawn(function()
            while S.Flags.expGreeceKill do
                local bp = LocalPlayer:FindFirstChild("Backpack")
                local c  = LocalPlayer.Character
                if bp and c then
                    local tool
                    for _, t in ipairs(bp:GetChildren()) do
                        if t:IsA("Tool") and t.Name:lower():find("sword") then
                            tool = t; break
                        end
                    end
                    local h = c:FindFirstChildOfClass("Humanoid")
                    if tool and h then h:EquipTool(tool) end
                end
                task.wait()
            end
        end)
        bind("expGreece", RunService.RenderStepped:Connect(function()
            local all = Players:GetPlayers()
            for i = 2, #all do
                local other = all[i]
                local character = other.Character
                if character and not LocalPlayer:IsFriendsWith(other.UserId) then
                    local tool = LocalPlayer.Character
                        and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                    if tool and tool:FindFirstChild("Handle") then
                        tool:Activate()
                        for _, part in next, character:GetChildren() do
                            if part:IsA("BasePart") then
                                executorFireTouch and executorFireTouch(tool.Handle, part, 0)
                                executorFireTouch and executorFireTouch(tool.Handle, part, 1)
                            end
                        end
                    end
                end
            end
        end))
    end),
}, "ExpeditionGreeceKill")

ExpeditionTab:Toggle({
    Title    = "Hawaii Dig All",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.expHawaii = enabled
        if not enabled then return end
        task.spawn(function()
            while S.Flags.expHawaii do
                task.wait()
                local Assets = workspace:FindFirstChild("Assets")
                if Assets and Assets:FindFirstChild("Hawaii") then
                    pcall(function()
                        local pData = ReplicatedStorage.Season.Players
                            :FindFirstChild(LocalPlayer.Name)
                        if pData and pData:FindFirstChild("Team") then
                            local Team = pData.Team.Value
                            local spots = Assets.Hawaii.DiggingSpots:FindFirstChild(Team)
                            if spots then
                                for _, d in ipairs(spots:GetDescendants()) do
                                    if d.Name == "ClickDetector" then
                                        if executorFireClick then for _ = 1, 40 do pcall(executorFireClick, d) end end
                                    end
                                end
                            end
                        end
                    end)
                end
            end
        end)
    end),
}, "ExpeditionHawaii")

ExpeditionTab:Button({
    Title    = "Finish China Food",
    Icon     = "solar:chef-hat-bold",
    Callback = safe(function()
        for _, v in pairs(workspace.Assets:GetDescendants()) do
            if v.Name == LocalPlayer.Name
               and v:FindFirstChild("ClickDetector") then
                if executorFireClick then for _ = 1, 80 do pcall(executorFireClick, v.ClickDetector) end end
            end
        end
    end),
})

ExpeditionTab:Toggle({
    Title    = "Meatball Protection",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.expMeatballGuard = enabled
        if not enabled then return end
        task.spawn(function()
            local fired = false
            while S.Flags.expMeatballGuard do
                pcall(function()
                    local assets = workspace:FindFirstChild("Assets")
                    if assets then
                        local has = false
                        for _, child in ipairs(assets:GetChildren()) do
                            local n = child.Name:lower()
                            if n:find("dodgeball") or n:find("paintball")
                               or n:find("meatball") then
                                has = true; break
                            end
                        end
                        if has and not fired then
                            fired = true
                            local h = humanoid()
                            if h then h.Health = 0 end
                        end
                        if not has then fired = false end
                    end
                end)
                task.wait(0.3)
            end
        end)
    end),
}, "ExpeditionMeatball")

ExpeditionTab:Section({ Title = "Teleports" })

local EXP_TELEPORTS = {
    { "Drop-Off",         -116, 106, -32  },
    { "Confessionals",       2, 102, -23  },
    { "First Class",       172, 105, -35  },
    { "Spectator Island", -157, -22, -885 },
}

for _, loc in ipairs(EXP_TELEPORTS) do
    ExpeditionTab:Button({
        Title    = loc[1],
        Desc     = string.format("X %d · Y %d · Z %d", loc[2], loc[3], loc[4]),
        Icon     = "solar:map-point-bold",
        Callback = safe(function()
            teleport(loc[2], loc[3], loc[4])
            notify("Teleport", loc[1])
        end),
    })
end

else
    ExpeditionTab:Paragraph({
        Title   = "Not Available",
        Content = "The Expedition tab only works in Expedition (PlaceId 7172152072).\n"
               .. "Current PlaceId: " .. game.PlaceId,
    })
end

--[[
]]

MorphsTab:Section({ Title = "Paid" })

local characterNameBuffer = ""

MorphsTab:Input({
    Title       = "Character Name",
    Desc        = "Type your character name",
    Placeholder = "Enter character name...",
    Callback    = safe(function(v) characterNameBuffer = v or "" end),
})

local SYMBOLS = {
    ["None"]     = "",
    ["Verified"] = "\u{e000}",
    ["Premium"]  = "\u{e001}",
    ["Robux"]    = "\u{e002}",
}
local SYMBOL_ORDER = { "None", "Verified", "Premium", "Robux" }
local selectedSymbol = "None"

MorphsTab:Dropdown({
    Title    = "Pick Symbol",
    Desc     = "Append the verified/premium/robux icon to your name",
    Value    = SYMBOL_ORDER[1],
    Values   = SYMBOL_ORDER,
    Callback = safe(function(idx)
        local pick
        if type(idx) == "table" then pick = idx[1] or idx.Option
        else pick = SYMBOL_ORDER[selectedIndex(SYMBOL_ORDER, idx)] end
        if pick and SYMBOLS[pick] ~= nil then
            selectedSymbol = pick
            notify("Symbol", pick .. " selected")
        end
    end),
})

MorphsTab:Button({
    Title    = "Buy Character (@60)",
    Desc     = "Purchases the custom character with selected symbol",
    Icon     = "solar:cart-large-2-bold",
    Callback = safe(function()
        if characterNameBuffer == "" then
            return notify("Morphs", "Enter a name first")
        end
        local symbolChar = SYMBOLS[selectedSymbol] or ""
        local final = characterNameBuffer
        if symbolChar ~= "" then
            final = characterNameBuffer .. " " .. symbolChar
        end
        local ev  = ReplicatedStorage:FindFirstChild("Events")
        local buy = ev and ev:FindFirstChild("Buy")
        if buy then buy:FireServer("Character", final) end
        notify("Morphs", "Sent: " .. characterNameBuffer .. " (" .. selectedSymbol .. ")")
    end),
})

MorphsTab:Button({
    Title    = "Server Crash",
    Desc     = "Loads the crash payload from GitHub",
    Icon     = "solar:danger-triangle-bold",
    Callback = safe(function()
        task.spawn(function()
            local url = "https://raw.githubusercontent.com/surrre4l/bruh/main/surrealcrash.lua"
            local ok, err = pcall(function()
                local src = game:HttpGet(url, true)
                if type(src) ~= "string" or #src < 50 then error("Empty response") end
                local fn = loadstring(src)
                if not fn then error("loadstring failed") end
                fn()
            end)
            if ok then notify("Server Crash", "Payload executed", 4)
            else notify("Server Crash Error", tostring(err), 4) end
        end)
    end),
})

--[[
]]

VisualsTab:Section({ Title = "Typefaces" })

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
    if type(getcustomasset) ~= "function" then return end
    obj.FontFace = Font.new(getcustomasset(jsonName))
    if not obj:GetAttribute(attrKey) then
        if obj.TextSize > 0 then
            obj.TextSize = math.clamp(obj.TextSize * scale, 8, 100)
        end
        obj:SetAttribute(attrKey, true)
    end
end

local function loadTypeface(displayName, ttfFile, jsonFile, source, attrKey)
    if type(getcustomasset) ~= "function" then
        return notify("Typeface", "Your executor does not provide getcustomasset()", 4)
    end
    local ok, err = pcall(function()
        if not isfile(ttfFile) then writefile(ttfFile, game:HttpGet(source)) end
        writefile(jsonFile, HttpService:JSONEncode({
            name  = displayName,
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
    end)
    if ok then notify("Typeface Applied", displayName .. " is now active.", 4)
    else notify("Typeface Failed", displayName .. " — " .. tostring(err), 4) end
end

VisualsTab:Button({
    Title = "Starborn Typeface", Desc = "Starborn try this thing",
    Icon  = "solar:text-bold",
    Callback = safe(function()
        loadTypeface("Starborn", "starborn.ttf", "Starborn.json",
            "https://drive.google.com/uc?export=download&id=1AOv_DKQ0iB55eOvRkQnkq40POxix82dP&confirm=t",
            "SurrealFontStarborn")
    end),
})

VisualsTab:Button({
    Title = "Minecraft Typeface", Desc = "Minecrafter if you are larper",
    Icon  = "solar:text-bold",
    Callback = safe(function()
        loadTypeface("Minecrafter", "minecrafter.ttf", "Minecrafter.json",
            "https://drive.google.com/uc?export=download&id=1oe66VO8IhLBqDvbgxqer4RHEi7bAO7R2&confirm=t",
            "SurrealFontMinecraft")
    end),
})

VisualsTab:Button({
    Title = "Matcha Mint Typeface", Desc = "Labubu matcha font",
    Icon  = "solar:text-bold",
    Callback = safe(function()
        loadTypeface("Matcha Mint", "matchamint.ttf", "MatchaMint.json",
            "https://drive.google.com/uc?export=download&id=1cZomyiePFjjNzciPRextxt0puySrmrEX&confirm=t",
            "SurrealFontMatchaMint")
    end),
})

VisualsTab:Button({
    Title = "OG Roblox Typeface", Desc = "Classic Roblox font",
    Icon  = "solar:text-bold",
    Callback = safe(function()
        loadTypeface("OG Roblox", "ogroblox.ttf", "OGRoblox.json",
            "https://drive.google.com/uc?export=download&id=1XLBx4U-kkzB3B8v2DaO3AcvtHNlyn3tn&confirm=t",
            "SurrealFontOGRoblox")
    end),
})

VisualsTab:Button({
    Title = "Yellow Style Typeface", Desc = "Yellow style font",
    Icon  = "solar:text-bold",
    Callback = safe(function()
        loadTypeface("Yellow Style", "yellowstyle.ttf", "YellowStyle.json",
            "https://drive.google.com/uc?export=download&id=1FAzibH6kP50SybbEfpGZb3pIoIUiUFUt&confirm=t",
            "SurrealFontYellowStyle")
    end),
})

VisualsTab:Button({
    Title = "Super Mario Typeface", Desc = "Super Mario font",
    Icon  = "solar:text-bold",
    Callback = safe(function()
        loadTypeface("Super Mario", "supermario.ttf", "SuperMario.json",
            "https://drive.google.com/uc?export=download&id=1flDI_h9nP0ivHjBJjPuNh5xNzcsF9dcE&confirm=t",
            "SurrealFontSuperMario")
    end),
})

--[[
]]

VisualsTab:Section({ Title = "Shaders" })

local SHADER_PROPS = {
    "Ambient","OutdoorAmbient","Brightness","ClockTime",
    "GeographicLatitude","EnvironmentDiffuseScale",
    "EnvironmentSpecularScale","GlobalShadows","ShadowSoftness",
    "ExposureCompensation","ColorShift_Top","ColorShift_Bottom",
    "FogEnd","FogStart","FogColor",
}

local originalLighting = {}
for _, p in ipairs(SHADER_PROPS) do
    pcall(function() originalLighting[p] = Lighting[p] end)
end

local EFFECT_CLASSES = {
    "Sky","Atmosphere","BloomEffect","ColorCorrectionEffect",
    "ColorGradingEffect","SunRaysEffect","DepthOfFieldEffect","BlurEffect",
}
local hiddenEffects = {}

local function isEffect(inst)
    for _, cls in ipairs(EFFECT_CLASSES) do
        if inst:IsA(cls) then return true end
    end
    return false
end

local function isOurs(inst)
    return inst.Name:find("Surreal_", 1, true) ~= nil
end

local function hideGameEffects()
    hiddenEffects = {}
    for _, child in ipairs(Lighting:GetChildren()) do
        if isEffect(child) and not isOurs(child) then
            local hasEnabled = pcall(function() return child.Enabled end)
            if hasEnabled then
                pcall(function() child.Enabled = false end)
                hiddenEffects[child] = "disabled"
            else
                hiddenEffects[child] = "removed"
                child.Parent = nil
            end
        end
    end
end

local function restoreGameEffects()
    for inst, how in pairs(hiddenEffects) do
        pcall(function()
            if how == "disabled" then inst.Enabled = true
            elseif how == "removed" then inst.Parent = Lighting end
        end)
    end
    hiddenEffects = {}
end

local function clearShader()
    unbind("shaderBeat")
    for _, child in ipairs(Lighting:GetChildren()) do
        if isOurs(child) then child:Destroy() end
    end
    for prop, val in pairs(originalLighting) do
        pcall(function() Lighting[prop] = val end)
    end
    restoreGameEffects()
    S.ShaderActive = nil
end

local function applyShader(name, props, buildFn)
    if S.ShaderActive == name then return end
    if S.ShaderActive then clearShader() end
    hideGameEffects()
    buildFn()
    for prop, val in pairs(props) do
        pcall(function() Lighting[prop] = val end)
    end
    S.ShaderActive = name
    bind("shaderBeat", RunService.Heartbeat:Connect(function()
        pcall(function()
            if not Lighting:FindFirstChild("Surreal_" .. name .. "_Sky") then
                buildFn()
            end
            for prop, val in pairs(props) do
                if Lighting[prop] ~= val then
                    pcall(function() Lighting[prop] = val end)
                end
            end
        end)
    end))
end

local SNUG_PROPS = {
    Ambient = Color3.fromRGB(60, 55, 65),
    OutdoorAmbient = Color3.fromRGB(120, 110, 105),
    Brightness = 2.5, ClockTime = 16.5, GlobalShadows = true,
    FogEnd = 700, FogColor = Color3.fromRGB(200, 185, 175),
}
local function buildSnug()
    pcall(function()
        local atm = Instance.new("Atmosphere")
        atm.Name = "Surreal_Snug_Atmosphere"
        atm.Density = 0.32; atm.Haze = 1.8; atm.Parent = Lighting
    end)
    pcall(function()
        local cc = Instance.new("ColorCorrectionEffect")
        cc.Name = "Surreal_Snug_CC"
        cc.Contrast = 0.12; cc.Saturation = 0.08; cc.Parent = Lighting
    end)
    pcall(function()
        local sky = Instance.new("Sky")
        sky.Name = "Surreal_Snug_Sky"
        sky.SkyboxBk = "rbxassetid://271042516"
        sky.SkyboxDn = "rbxassetid://271077243"
        sky.SkyboxFt = "rbxassetid://271042556"
        sky.SkyboxLf = "rbxassetid://271042310"
        sky.SkyboxRt = "rbxassetid://271042467"
        sky.SkyboxUp = "rbxassetid://271077958"
        sky.Parent = Lighting
    end)
end

local SLAUGHTER_PROPS = {
    Ambient = Color3.fromRGB(45, 40, 55),
    OutdoorAmbient = Color3.fromRGB(95, 85, 100),
    Brightness = 1.8, ClockTime = 17.5, GlobalShadows = true,
    FogEnd = 450, FogColor = Color3.fromRGB(170, 145, 135),
}
local function buildSlaughter()
    pcall(function()
        local atm = Instance.new("Atmosphere")
        atm.Name = "Surreal_Slaughter_Atmosphere"
        atm.Density = 0.55; atm.Haze = 3.5; atm.Parent = Lighting
    end)
    pcall(function()
        local cc = Instance.new("ColorCorrectionEffect")
        cc.Name = "Surreal_Slaughter_CC"
        cc.Contrast = 0.25; cc.Saturation = -0.05; cc.Parent = Lighting
    end)
    pcall(function()
        local sky = Instance.new("Sky")
        sky.Name = "Surreal_Slaughter_Sky"
        sky.SkyboxBk = "rbxassetid://271042516"
        sky.SkyboxDn = "rbxassetid://271077243"
        sky.SkyboxFt = "rbxassetid://271042556"
        sky.SkyboxLf = "rbxassetid://271042310"
        sky.SkyboxRt = "rbxassetid://271042467"
        sky.SkyboxUp = "rbxassetid://271077958"
        sky.Parent = Lighting
    end)
end

local ELLA_PROPS = {
    Ambient = Color3.fromRGB(70, 70, 70),
    OutdoorAmbient = Color3.fromRGB(135, 135, 135),
    Brightness = 5, ClockTime = 9, ShadowSoftness = 0.15,
    ColorShift_Top = Color3.fromRGB(255, 138, 35), GlobalShadows = true,
}
local function buildElla()
    pcall(function()
        local sky = Instance.new("Sky")
        sky.Name = "Surreal_Ella_Sky"
        sky.SkyboxBk = "rbxassetid://271042516"
        sky.SkyboxDn = "rbxassetid://271077243"
        sky.SkyboxFt = "rbxassetid://271042556"
        sky.SkyboxLf = "rbxassetid://271042310"
        sky.SkyboxRt = "rbxassetid://271042467"
        sky.SkyboxUp = "rbxassetid://271077958"
        sky.Parent = Lighting
    end)
    pcall(function()
        Terrain.WaterReflectance = 0.08
        Terrain.WaterTransparency = 0.85
        Terrain.WaterDefaultColor = Color3.fromRGB(12, 84, 92)
    end)
end

VisualsTab:Button({
    Title = "Apply Snug Shaders", Desc = "Balanced cozy lighting",
    Icon  = "solar:sun-2-bold",
    Callback = safe(function()
        applyShader("Snug", SNUG_PROPS, buildSnug)
        notify("Snug Shaders", "Applied.", 4)
    end),
})

VisualsTab:Button({
    Title = "Apply Slaughter Shaders", Desc = "Moody fog + surreal dusk",
    Icon  = "solar:moon-stars-bold",
    Callback = safe(function()
        applyShader("Slaughter", SLAUGHTER_PROPS, buildSlaughter)
        notify("Slaughter Shaders", "Applied.", 4)
    end),
})

VisualsTab:Button({
    Title = "Apply Natural Shaders", Desc = "Golden hour + teal water",
    Icon  = "solar:sunrise-bold",
    Callback = safe(function()
        applyShader("Ella", ELLA_PROPS, buildElla)
        notify("Ella Shaders", "Applied.", 4)
    end),
})

VisualsTab:Button({
    Title = "Remove Shader", Desc = "Back to vanilla lighting",
    Icon  = "solar:refresh-circle-bold",
    Callback = safe(function()
        clearShader()
        notify("Shaders", "Removed.", 4)
    end),
})

--[[
]]

VisualsTab:Section({ Title = "Fullbright" })

local fbBrightness = 3

VisualsTab:Slider({
    Title     = "Fullbright Brightness",
    IsTooltip = true, Step = 1,
    Value     = { Min = 1, Max = 10, Default = 3 },
    Callback  = safe(function(v)
        fbBrightness = v
        if S.Flags.fullbright then
            pcall(function() Lighting.Brightness = v end)
        end
    end),
}, "FullbrightBrightness")

VisualsTab:Toggle({
    Title    = "Fullbright",
    Desc     = "Makes the entire map fully lit, no dark spots",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.fullbright = enabled
        unbind("fullbright")
        if not enabled then
            Lighting.Ambient = Color3.fromRGB(70, 70, 70)
            Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
            Lighting.Brightness = 2
            Lighting.GlobalShadows = true
            Lighting.FogEnd = 100000
            return
        end
        local function apply()
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            Lighting.Brightness = fbBrightness
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 1e6
        end
        apply()
        bind("fullbright", RunService.Heartbeat:Connect(function() pcall(apply) end))
    end),
}, "Fullbright")

VisualsTab:Section({ Title = "Finish Line ESP" })

VisualsTab:Toggle({
    Title    = "Finish Line ESP",
    Desc     = "Shows how many studs you are from the finish line",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.finishESP = enabled
        S.Flags.finishObjects = S.Flags.finishObjects or {}
        if not enabled then
            for _, m in pairs(S.Flags.finishObjects) do
                pcall(function() m.billboard:Destroy() end)
            end
            S.Flags.finishObjects = {}
            unbind("finishAdd"); unbind("finishRem"); unbind("finishRender")
            return
        end
        local COLOR = Color3.fromRGB(80, 220, 120)
        local MAX_DIST = 1000
        local function create(part)
            if S.Flags.finishObjects[part] then return end
            local bb = Instance.new("BillboardGui")
            bb.AlwaysOnTop = true
            bb.Size = UDim2.new(0, 260, 0, 70)
            bb.StudsOffset = Vector3.new(0, 4, 0)
            bb.Adornee = part; bb.Parent = part
            local lbl = Instance.new("TextLabel")
            lbl.BackgroundTransparency = 1
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.TextColor3 = COLOR
            lbl.TextStrokeTransparency = 0
            lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
            lbl.TextScaled = true
            lbl.Font = Enum.Font.GothamBold
            lbl.Text = "FINISH"; lbl.Parent = bb
            S.Flags.finishObjects[part] = { billboard = bb, label = lbl }
        end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name:lower() == "finish" then create(obj) end
        end
        bind("finishAdd", workspace.DescendantAdded:Connect(function(obj)
            if S.Flags.finishESP and obj:IsA("BasePart")
               and obj.Name:lower() == "finish" then create(obj) end
        end))
        bind("finishRem", workspace.DescendantRemoving:Connect(function(obj)
            if S.Flags.finishObjects[obj] then
                pcall(function() S.Flags.finishObjects[obj].billboard:Destroy() end)
                S.Flags.finishObjects[obj] = nil
            end
        end))
        bind("finishRender", RunService.RenderStepped:Connect(function()
            if not S.Flags.finishESP then return end
            local r = root()
            if not r then return end
            for part, m in pairs(S.Flags.finishObjects) do
                local dist = (part.Position - r.Position).Magnitude
                m.billboard.Enabled = dist <= MAX_DIST
                if dist <= MAX_DIST then
                    m.label.Text = string.format("%.1f studs", dist)
                end
            end
        end))
    end),
}, "FinishLineESP")

VisualsTab:Section({ Title = "Custom" })

_G.CustomName = _G.CustomName or ""
_G.UseCustomName = _G.UseCustomName or false
_G.RainbowMode = _G.RainbowMode or false
_G.RainbowSpeed = _G.RainbowSpeed or 0.5
_G.StaticColor = _G.StaticColor or Color3.fromRGB(255, 255, 255)
_G.StaticColorCustom = false

local nameColorArmed = false
task.delay(2, function() nameColorArmed = true end)

VisualsTab:Input({
    Title = "Character Name",
    Desc  = "Replace your character name no tags",
    Placeholder = "Enter character name...",
    Callback = safe(function(v)
        _G.CustomName = v or ""
        _G.UseCustomName = (_G.CustomName ~= "")
    end),
})

VisualsTab:Toggle({
    Title = "Rainbow Name", Desc = "Rainbow rgb in name",
    Value = false,
    Callback = safe(function(enabled) _G.RainbowMode = enabled end),
}, "RainbowName")

VisualsTab:Slider({
    Title = "Rainbow Setback", Desc = "How fast rainbow name",
    IsTooltip = true, Step = 1,
    Value = { Min = 0, Max = 100, Default = 50 },
    Callback = safe(function(v) _G.RainbowSpeed = v / 100 end),
}, "RainbowSetback")

VisualsTab:Colorpicker({
    Title = "Name Color",
    Desc  = "Picks a fixed color for your character's name",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = safe(function(value)
        if not nameColorArmed then return end
        _G.StaticColor = value
        _G.StaticColorCustom = true
    end),
})

VisualsTab:Button({
    Title = "Reset to Team Color",
    Desc  = "Resets your name color to original",
    Icon  = "solar:refresh-bold",
    Callback = safe(function()
        _G.StaticColorCustom = false
        notify("Name Color", "Reverted to team color.", 4)
    end),
})

RunService.RenderStepped:Connect(function()
    pcall(function()
        local active = _G.UseCustomName or _G.RainbowMode or _G.StaticColorCustom
        if not active then return end
        local c = LocalPlayer.Character
        if not c then return end
        for _, obj in ipairs(c:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                if _G.UseCustomName and _G.CustomName ~= "" then
                    obj.Text = _G.CustomName
                end
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

VisualsTab:Section({ Title = "Skins" })

VisualsTab:Button({
    Title = "Get all skins (client)",
    Desc  = "Unlocks all skins in your inventory (client)",
    Icon  = "solar:palette-bold",
    Callback = safe(function()
        local _rs = game:GetService("ReplicatedStorage")
        local _lp = game:GetService("Players").LocalPlayer
        local _DataStore = _lp:WaitForChild("DataStore")
        local _ok, _err = pcall(function()
            for _, _category in ipairs(_rs.Products.Shop.Items:GetChildren()) do
                local dsCat = _DataStore:FindFirstChild(_category.Name)
                if dsCat then
                    for _, _item in ipairs(dsCat:GetChildren()) do _item:Destroy() end
                    for _, _item in ipairs(_category:GetChildren()) do
                        _item:Clone().Parent = dsCat
                    end
                end
            end
        end)
        if _ok then notify("Skins", "All skins added (client)!", 4)
        else notify("Skins", "Failed: " .. tostring(_err), 4) end
    end),
})

--[[
]]

VisualsTab:Section({ Title = "Player ESP" })

local ESP = { on = false, highlights = {}, conns = {} }

local function addHighlight(plr)
    if plr == LocalPlayer then return end
    local char = plr.Character
    if not char then return end
    if ESP.highlights[plr] then ESP.highlights[plr]:Destroy() end
    local h = Instance.new("Highlight")
    h.Name = "SurrealESP"
    h.Adornee = char
    h.FillColor = Color3.fromRGB(255, 60, 60)
    h.OutlineColor = Color3.fromRGB(255, 255, 255)
    h.FillTransparency = 0.6
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.Occluded
    h.Parent = char
    ESP.highlights[plr] = h
end

local function removeHighlight(plr)
    if ESP.highlights[plr] then
        ESP.highlights[plr]:Destroy()
        ESP.highlights[plr] = nil
    end
end

VisualsTab:Toggle({
    Title    = "ESP / Highlight",
    Desc     = "Red outline on every other player",
    Value    = false,
    Callback = safe(function(enabled)
        ESP.on = enabled
        for _, c in ipairs(ESP.conns) do pcall(function() c:Disconnect() end) end
        ESP.conns = {}
        if not enabled then
            for _, plr in ipairs(Players:GetPlayers()) do removeHighlight(plr) end
            return
        end
        for _, plr in ipairs(Players:GetPlayers()) do addHighlight(plr) end
        for _, plr in ipairs(Players:GetPlayers()) do
            table.insert(ESP.conns, plr.CharacterAdded:Connect(function()
                task.wait(0.3)
                if ESP.on then addHighlight(plr) end
            end))
        end
        table.insert(ESP.conns, Players.PlayerAdded:Connect(function(plr)
            plr.CharacterAdded:Connect(function()
                task.wait(0.3)
                if ESP.on then addHighlight(plr) end
            end)
        end))
        table.insert(ESP.conns, Players.PlayerRemoving:Connect(function(plr)
            removeHighlight(plr)
        end))
    end),
}, "PlayerESP")

VisualsTab:Section({ Title = "Usernames" })

local Names = { on = false, tags = {}, conns = {} }

local function getTeamColor(plr)
    local season = ReplicatedStorage:FindFirstChild("Season")
    local list   = season and season:FindFirstChild("Players")
    local entry  = list and list:FindFirstChild(plr.Name)
    if not entry then return Color3.fromRGB(180, 180, 200) end
    local team = entry:FindFirstChild("Team")
    if not team then return Color3.fromRGB(180, 180, 200) end
    local Teams = game:GetService("Teams")
    local teamObj = Teams:FindFirstChild(team.Value)
    return teamObj and teamObj.TeamColor.Color or Color3.fromRGB(180, 180, 200)
end

local function attachNameTag(plr)
    local char = plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    if Names.tags[plr] then Names.tags[plr]:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name = "SurrealUsername"
    bb.Adornee = head
    bb.Size = UDim2.new(0, 160, 0, 22)
    bb.StudsOffset = Vector3.new(0, 3.6, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.Parent = head

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = plr.Name
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextScaled = true
    lbl.TextColor3 = getTeamColor(plr)
    lbl.TextStrokeTransparency = 0.5
    lbl.TextStrokeColor3 = Color3.fromRGB(30, 30, 40)
    lbl.Parent = bb
    Names.tags[plr] = bb
end

local function detachNameTag(plr)
    if Names.tags[plr] then
        Names.tags[plr]:Destroy()
        Names.tags[plr] = nil
    end
end

VisualsTab:Toggle({
    Title    = "Show All Usernames",
    Desc     = "Billboard over every player with real name, colored by team",
    Value    = false,
    Callback = safe(function(enabled)
        Names.on = enabled
        for _, c in ipairs(Names.conns) do pcall(function() c:Disconnect() end) end
        Names.conns = {}
        if not enabled then
            for _, plr in ipairs(Players:GetPlayers()) do detachNameTag(plr) end
            return
        end
        for _, plr in ipairs(Players:GetPlayers()) do attachNameTag(plr) end
        for _, plr in ipairs(Players:GetPlayers()) do
            table.insert(Names.conns, plr.CharacterAdded:Connect(function()
                task.wait(0.3)
                if Names.on then attachNameTag(plr) end
            end))
        end
        table.insert(Names.conns, Players.PlayerAdded:Connect(function(plr)
            plr.CharacterAdded:Connect(function()
                task.wait(0.3)
                if Names.on then attachNameTag(plr) end
            end)
        end))
        table.insert(Names.conns, Players.PlayerRemoving:Connect(function(plr)
            detachNameTag(plr)
        end))
    end),
}, "ShowUsernames")

--[[
]]

ThemesTab:Section({ Title = "Map Themes" })

local originalTheme = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    FogEnd = Lighting.FogEnd,
    FogColor = Lighting.FogColor,
    ClockTime = Lighting.ClockTime,
}

ThemesTab:Button({
    Title    = "Christmas Map",
    Desc     = "Snow + white trees",
    Icon     = "solar:snowflake-bold",
    Callback = safe(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local n = obj.BrickColor.Name:lower()
                if n == "olivine" or n:find("green") then
                    obj.Color = Color3.fromRGB(255, 255, 255)
                    obj.Material = Enum.Material.SmoothPlastic
                end
            end
            if obj:IsA("MeshPart") and obj.Name == "Leaves" then
                obj.Color = Color3.fromRGB(255, 255, 255)
                obj.Material = Enum.Material.SmoothPlastic
            end
        end
        Lighting.Ambient = Color3.fromRGB(127, 127, 127)
        Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
        Lighting.FogEnd = 100000
        Lighting.ClockTime = 14
        notify("Theme", "Christmas applied")
    end),
})

ThemesTab:Button({
    Title    = "Halloween Map",
    Desc     = "Rust leaves + dark foggy lighting",
    Icon     = "solar:ghost-bold",
    Callback = safe(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local n = obj.BrickColor.Name:lower()
                if n == "olivine" or n:find("green") then
                    obj.Color = Color3.fromRGB(180, 100, 40)
                    obj.Material = Enum.Material.SmoothPlastic
                end
            end
            if obj:IsA("MeshPart") and obj.Name == "Leaves" then
                obj.Color = Color3.fromRGB(180, 100, 40)
            end
        end
        Lighting.Ambient = Color3.fromRGB(80, 80, 80)
        Lighting.OutdoorAmbient = Color3.fromRGB(80, 80, 80)
        Lighting.FogColor = Color3.fromRGB(70, 70, 70)
        Lighting.FogEnd = 300
        Lighting.ClockTime = 16
        notify("Theme", "Halloween applied")
    end),
})

ThemesTab:Button({
    Title    = "Valentines Map",
    Desc     = "Pink leaves + rose water",
    Icon     = "solar:heart-bold",
    Callback = safe(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local n = obj.BrickColor.Name:lower()
                if n == "olivine" or n:find("green") then
                    obj.Color = Color3.fromRGB(148, 190, 129)
                    obj.Material = Enum.Material.SmoothPlastic
                end
            end
            if obj:IsA("MeshPart") and obj.Name == "Leaves" then
                obj.Color = Color3.fromRGB(255, 152, 220)
                obj.Material = Enum.Material.SmoothPlastic
            end
        end
        Lighting.Ambient = Color3.fromRGB(127, 127, 127)
        Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
        Lighting.FogEnd = 100000
        Lighting.ClockTime = 14
        notify("Theme", "Valentines applied")
    end),
})

ThemesTab:Button({
    Title    = "Reset Map",
    Desc     = "Restore original lighting",
    Icon     = "solar:refresh-circle-bold",
    Callback = safe(function()
        Lighting.Ambient = originalTheme.Ambient
        Lighting.OutdoorAmbient = originalTheme.OutdoorAmbient
        Lighting.FogEnd = originalTheme.FogEnd
        Lighting.FogColor = originalTheme.FogColor
        Lighting.ClockTime = originalTheme.ClockTime
        notify("Theme", "Reset")
    end),
})

--[[
]]

TrollTab:Section({ Title = "Target Follower" })

local Follow = { active = false, target = nil, anim = nil, tween = nil }

local function playFollowAnim()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if not h then return end
    local animator = h:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = h
    end
    local a = Instance.new("Animation")
    a.AnimationId = "rbxassetid://189854234"
    local track = animator:LoadAnimation(a)
    track:Play()
    Follow.anim = track
end

local function stopFollowAnim()
    if Follow.anim then
        pcall(function() Follow.anim:Stop() end)
        Follow.anim = nil
    end
end

local function tweenTo(inst, goal)
    local t = TweenService:Create(inst,
        TweenInfo.new(0.15, Enum.EasingStyle.Linear), { CFrame = goal })
    Follow.tween = t
    t:Play()
    t.Completed:Wait()
    if Follow.tween == t then Follow.tween = nil end
end

local function stopFollow()
    if not Follow.active then return end
    Follow.active = false
    if Follow.tween then
        pcall(function() Follow.tween:Cancel() end)
        Follow.tween = nil
    end
    stopFollowAnim()
end

local function startFollow()
    if Follow.active then return true end
    if not Follow.target or not Follow.target.Character then return false end
    Follow.active = true
    playFollowAnim()
    task.spawn(function()
        while Follow.active do
            local tc = Follow.target and Follow.target.Character
            local thrp = tc and tc:FindFirstChild("HumanoidRootPart")
            local myc = LocalPlayer.Character
            local myhrp = myc and myc:FindFirstChild("HumanoidRootPart")
            if not thrp or not myhrp then stopFollow() return end
            tweenTo(myhrp, thrp.CFrame * CFrame.new(0, 0, -2.5))
            if not Follow.active then return end
            tweenTo(myhrp, thrp.CFrame * CFrame.new(0, 0, -1.3))
        end
    end)
    return true
end

local followMap, followOpts = {}, { [1] = "(none)" }
local function buildFollowList()
    followOpts = { [1] = "(none)" }
    followMap = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local label = string.format("%s (@%s)", p.DisplayName, p.Name)
            table.insert(followOpts, label)
            followMap[label] = p
        end
    end
end
buildFollowList()

local FollowDropdown = TrollTab:Dropdown({
    Title = "Target Player",
    Desc  = "Choose who to follow",
    Value = followOpts[1],
    Values = followOpts,
    Callback = safe(function(opt)
        local idx = tonumber(opt) or 1
        local label = followOpts[idx]
        if not label or label == "(none)" then
            stopFollow(); Follow.target = nil; return
        end
        Follow.target = followMap[label]
    end),
})

TrollTab:Button({
    Title = "Refresh Players",
    Desc  = "Rebuild the dropdown list",
    Icon  = "solar:refresh-bold",
    Callback = safe(function()
        buildFollowList()
        pcall(function() FollowDropdown:Refresh(followOpts) end)
        notify("Follow", "List refreshed", 3)
    end),
})

TrollTab:Toggle({
    Title = "Follow Target",
    Desc  = "Tween-follow the selected player",
    Value = false,
    Callback = safe(function(enabled)
        if enabled then
            if not startFollow() then notify("Follow", "Pick a target first", 3) end
        else stopFollow() end
    end),
}, "FollowTarget")

TrollTab:Section({ Title = "Sounds" })

local CLICK_ID = "rbxassetid://6895079853"
local OOF_ID = "rbxassetid://9120386436"

local function playOnce(id, dur)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Parent = workspace
    s:Play()
    Debris:AddItem(s, dur or 3)
end

local function playFrom(container, name, dur)
    if not container then return false end
    local sound = container:FindFirstChild(name, true)
    if not sound or not sound:IsA("Sound") then return false end
    local clone = sound:Clone()
    clone.Parent = workspace
    clone:Play()
    Debris:AddItem(clone, dur or 5)
    return true
end

TrollTab:Toggle({
    Title = "Spam Click Sound",
    Desc  = "Rapidly plays a click sound",
    Value = false,
    Callback = safe(function(state)
        S.Flags.spamClick = state
        if not state then return end
        task.spawn(function()
            while S.Flags.spamClick do
                playOnce(CLICK_ID, 1)
                task.wait(0.15)
            end
        end)
    end),
}, "SpamClick")

TrollTab:Toggle({
    Title = "Spam OOF",
    Desc  = "Loops the OOF death sound locally",
    Value = false,
    Callback = safe(function(state)
        S.Flags.spamOof = state
        if not state then return end
        task.spawn(function()
            while S.Flags.spamOof do
                playOnce(OOF_ID, 1)
                task.wait(0.9)
            end
        end)
    end),
}, "SpamOof")

TrollTab:Button({
    Title = "Sword Lunge Sound",
    Icon  = "solar:music-note-bold",
    Callback = safe(function()
        local gear = ReplicatedStorage:FindFirstChild("Products")
            and ReplicatedStorage.Products:FindFirstChild("Gear")
        local sword = gear and gear:FindFirstChild("Sword")
        local hand = sword and sword:FindFirstChild("Handle")
        notify("Sound", playFrom(hand, "LungeSound", 3) and "Played" or "Not found")
    end),
})

TrollTab:Button({
    Title = "Equip (Sword Unsheath)",
    Icon  = "solar:music-note-bold",
    Callback = safe(function()
        local gear = ReplicatedStorage:FindFirstChild("Products")
            and ReplicatedStorage.Products:FindFirstChild("Gear")
        local sword = gear and gear:FindFirstChild("Sword")
        local hand = sword and sword:FindFirstChild("Handle")
        notify("Sound", playFrom(hand, "UnsheathSound", 3) and "Played" or "Not found")
    end),
})

TrollTab:Button({
    Title = "Toilet Elimination Sound",
    Icon  = "solar:music-note-bold",
    Callback = safe(function()
        local em = ReplicatedStorage:FindFirstChild("Products")
            and ReplicatedStorage.Products:FindFirstChild("ElimMethods")
        local camp = em and em:FindFirstChild("Camp")
        local t = camp and camp:FindFirstChild("Toilet Elimination")
        notify("Sound", playFrom(t, "Sound", 5) and "Played" or "Not found")
    end),
})

TrollTab:Button({
    Title = "Sleigh Elimination Sound",
    Icon  = "solar:music-note-bold",
    Callback = safe(function()
        local em = ReplicatedStorage:FindFirstChild("Products")
            and ReplicatedStorage.Products:FindFirstChild("ElimMethods")
        local camp = em and em:FindFirstChild("Camp")
        local s = camp and camp:FindFirstChild("Sleigh Elimination")
        notify("Sound", playFrom(s, "Sound", 5) and "Played" or "Not found")
    end),
})

TrollTab:Section({ Title = "Scripts" })

TrollTab:Button({
    Title = "Flinger",
    Icon  = "solar:rocket-bold",
    Callback = safe(function()
        task.spawn(function()
            local ok, err = pcall(function()
                local src = game:HttpGet(
                    "https://raw.githubusercontent.com/surrre4l/bruh/main/exe.lua.txt",
                    true
                )
                if type(src) ~= "string" or #src < 50 then error("Empty response") end
                local fn = loadstring(src)
                if not fn then error("loadstring returned nil") end
                fn()
            end)
            notify("Flinger", ok and "Loaded" or tostring(err), 4)
        end)
    end),
})

TrollTab:Button({
    Title = "Bang [NEW]",
    Icon  = "solar:bolt-bold",
    Callback = safe(function()
        task.spawn(function()
            pcall(function()
                loadstring(game:HttpGet(
                    "https://rawscripts.net/raw/Universal-Script-New-Bang-script-made-by-me-OFC-75582"
                ))()
            end)
        end)
    end),
})

TrollTab:Button({
    Title = "Freaky",
    Icon  = "solar:heart-bold",
    Callback = safe(function()
        task.spawn(function()
            pcall(function()
                loadstring(game:HttpGet(
                    "https://rawscripts.net/raw/Universal-Script-Freaky-gui-supported-r6-r15-29701"
                ))()
            end)
        end)
    end),
})

--[[
]]

UtilitiesTab:Section({ Title = "World" })

UtilitiesTab:Button({
    Title    = "Barrier Cleanup",
    Desc     = "Removes every barrier",
    Icon     = "solar:trash-bin-trash-bold",
    Callback = safe(function()
        local targets = {
            Glass = true, ChallengeGlass = true,
            AwardCeremony = true, ["Drop-Off"] = true,
        }
        local n = 0
        for _, obj in ipairs(workspace:GetDescendants()) do
            if targets[obj.Name] then
                obj:Destroy(); n = n + 1
            end
        end
        notify("Barriers Cleared", n .. " obstacle(s) removed.", 4)
    end),
})

UtilitiesTab:Toggle({
    Title    = "Water Walk",
    Desc     = "Makes you like Jesus",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.waterWalk = enabled
        local map   = workspace:FindFirstChild("Map")
        local camp  = map and map:FindFirstChild("Roblox Drama: Camp")
        local inner = camp and camp:FindFirstChild("Map")
        local lake  = inner and inner:FindFirstChild("Lake")
        local water = lake and lake:FindFirstChild("Water")
        if water then water.CanCollide = enabled end
        if enabled then
            local sand = camp and camp:FindFirstChild("Sand")
            local touch = sand and sand:FindFirstChild("TouchInterest")
            if touch then touch:Destroy() end
            notify("Water Walk", "enabled", 4)
        end
    end),
}, "WaterWalk")

UtilitiesTab:Section({ Title = "Collision" })

UtilitiesTab:Toggle({
    Title    = "Player Collision",
    Desc     = "Gives other players solid collision boxes",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.collision = enabled
        if not enabled then
            for _, p in ipairs(Players:GetPlayers()) do
                local c = p.Character
                if c then
                    for _, obj in ipairs(c:GetDescendants()) do
                        if obj:IsA("BasePart") and obj.Name == "SurrealCollider" then
                            obj:Destroy()
                        end
                    end
                end
            end
            unbind("collisionJoin")
            return
        end
        local function attach(player)
            if player == LocalPlayer then return end
            local c = player.Character
            if not c then return end
            for _, part in ipairs(c:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "SurrealCollider" then
                    local col = Instance.new("Part")
                    col.Name = "SurrealCollider"
                    col.Size = part.Size
                    col.CFrame = part.CFrame
                    col.Transparency = 1
                    col.CanCollide = true
                    col.CanQuery = false
                    col.CanTouch = false
                    col.Massless = true
                    col.Parent = part
                    local w = Instance.new("WeldConstraint")
                    w.Part0 = part
                    w.Part1 = col
                    w.Parent = col
                end
            end
        end
        for _, p in ipairs(Players:GetPlayers()) do attach(p) end
        bind("collisionJoin", Players.PlayerAdded:Connect(function(p)
            p.CharacterAdded:Connect(function()
                task.wait(0.3)
                if S.Flags.collision then attach(p) end
            end)
        end))
    end),
}, "PlayerCollision")

UtilitiesTab:Section({ Title = "Gear Keeper" })

UtilitiesTab:Toggle({
    Title    = "Gear Keeper",
    Desc     = "Saves your tools and restores them after respawn",
    Value    = false,
    Callback = safe(function(enabled)
        S.Flags.gearKeeper = enabled
        S.Flags.gearSaved = S.Flags.gearSaved or {}
        unbind("gearAdded")
        if not enabled then return end

        local function getBackpack()
            return LocalPlayer:FindFirstChildOfClass("Backpack")
        end

        local function saveTool(tool)
            if not tool or not tool:IsA("Tool") then return end
            if S.Flags.gearSaved[tool.Name] then return end
            local ok, clone = pcall(function() return tool:Clone() end)
            if not ok or not clone then return end
            clone.Parent = nil
            S.Flags.gearSaved[tool.Name] = clone
        end

        local function restoreAll()
            local bp = getBackpack()
            if not bp then return end
            for _, tool in pairs(S.Flags.gearSaved) do
                local ok, clone = pcall(function() return tool:Clone() end)
                if ok and clone then clone.Parent = bp end
            end
        end

        local bp = getBackpack()
        if bp then
            for _, item in ipairs(bp:GetChildren()) do
                if item:IsA("Tool") then saveTool(item) end
            end
            bind("gearAdded", bp.ChildAdded:Connect(function(item)
                if not S.Flags.gearKeeper then return end
                if item:IsA("Tool") then
                    task.wait(0.05); saveTool(item)
                end
            end))
        end

        bind("gearSpawn", LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.6)
            if S.Flags.gearKeeper then restoreAll() end
        end))
    end),
}, "GearKeeper")

UtilitiesTab:Button({
    Title = "Snapshot Gear Now",
    Icon  = "solar:save-bold",
    Callback = safe(function()
        S.Flags.gearSaved = S.Flags.gearSaved or {}
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not bp then return end
        local n = 0
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") and not S.Flags.gearSaved[item.Name] then
                local ok, clone = pcall(function() return item:Clone() end)
                if ok and clone then
                    clone.Parent = nil
                    S.Flags.gearSaved[item.Name] = clone
                    n = n + 1
                end
            end
        end
        notify("Gear Keeper", "Saved " .. n .. " tool(s)")
    end),
})

UtilitiesTab:Button({
    Title = "Restore Gear Now",
    Icon  = "solar:refresh-bold",
    Callback = safe(function()
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not bp then return end
        local n = 0
        for _, tool in pairs(S.Flags.gearSaved or {}) do
            local ok, clone = pcall(function() return tool:Clone() end)
            if ok and clone then
                clone.Parent = bp
                n = n + 1
            end
        end
        notify("Gear Keeper", "Restored " .. n .. " tool(s)")
    end),
})

--[[
]]

UtilitiesTab:Section({ Title = "Gear Spawner" })

local GearSpawner = { autoEquip = false }

local function getGearFolder()
    return ReplicatedStorage:FindFirstChild("Products")
       and ReplicatedStorage.Products:FindFirstChild("Gear")
end

local function listGear()
    local folder = getGearFolder()
    if not folder then return { [1] = "(none)" } end
    local names = { [1] = "(none)" }
    for _, item in ipairs(folder:GetChildren()) do
        if item:IsA("Tool") then table.insert(names, item.Name) end
    end
    table.sort(names, function(a, b)
        if a == "(none)" then return true end
        if b == "(none)" then return false end
        return a < b
    end)
    return names
end

local gearSelected = ""

UtilitiesTab:Dropdown({
    Title = "Gear",
    Desc  = "Pick any tool from Products.Gear",
    Value = (listGear()[1] or ""),
    Values = listGear(),
    Callback = safe(function(idx)
        local list = listGear()
        local pick = list[selectedIndex(list, idx)]
        if pick and pick ~= "(none)" then
            gearSelected = pick
            notify("Gear", pick .. " selected")
        end
    end),
})

UtilitiesTab:Button({
    Title = "Give Selected Gear",
    Desc  = "Clone the tool into your backpack",
    Icon  = "solar:cart-large-2-bold",
    Callback = safe(function()
        if gearSelected == "" then return notify("Gear", "Pick a tool first") end
        local folder = getGearFolder()
        if not folder then return notify("Gear", "No Products.Gear folder") end
        local template = folder:FindFirstChild(gearSelected)
        if not template then return notify("Gear", "Not found") end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not bp then return notify("Gear", "No backpack") end
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") and item.Name == gearSelected then
                pcall(function() item:Destroy() end)
            end
        end
        local ok, clone = pcall(function() return template:Clone() end)
        if ok and clone then
            for _, part in ipairs(clone:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            clone.Parent = bp
            notify("Gear", "Gave " .. gearSelected)
            if GearSpawner.autoEquip then
                local h = humanoid()
                if h then task.wait(0.05); h:EquipTool(clone) end
            end
        end
    end),
})

UtilitiesTab:Toggle({
    Title = "Auto-Equip Gear",
    Desc  = "Wield gear the moment it's given",
    Value = false,
    Callback = safe(function(state) GearSpawner.autoEquip = state end),
}, "GearAutoEquip")

UtilitiesTab:Button({
    Title = "Refresh Gear List",
    Desc  = "Reload the dropdown",
    Icon  = "solar:refresh-bold",
    Callback = safe(function() notify("Gear", "Reload the UI to see fresh list") end),
})

UtilitiesTab:Section({ Title = "Info" })

UtilitiesTab:Button({
    Title = "Grab Place ID",
    Desc  = "Prints the current Place ID, Job ID, and Game Name",
    Icon  = "solar:info-circle-bold",
    Callback = safe(function()
        local MS = game:GetService("MarketplaceService")
        local gameName = "Unknown"
        pcall(function()
            local info = MS:GetProductInfo(game.PlaceId)
            if info and info.Name then gameName = info.Name end
        end)
        print("=== Place ID ===")
        print("Game:     " .. gameName)
        print("Place ID: " .. tostring(game.PlaceId))
        print("Job ID:   " .. game.JobId)
        notify("Place ID", game.PlaceId .. " — check console", 4)
    end),
})

UtilitiesTab:Section({ Title = "Teleports (Camp)" })

local CAMP_TP = {
    { "Spectator Island",  33,  -16, 31   },
    { "Main Island",      150,  -17, -417 },
    { "Exile Island",     -116, -14, -166 },
    { "Voting Area",      -23,   95, -514 },
    { "Boat",              47,  -20, -297 },
    { "Bathroom",         302,  -15, -325 },
}
for _, loc in ipairs(CAMP_TP) do
    UtilitiesTab:Button({
        Title = loc[1],
        Desc  = string.format("X %d · Y %d · Z %d", loc[2], loc[3], loc[4]),
        Icon  = "solar:map-point-bold",
        Callback = safe(function()
            teleport(loc[2], loc[3], loc[4])
            notify("Teleport", loc[1])
        end),
    })
end

UtilitiesTab:Section({ Title = "More" })

UtilitiesTab:Button({
    Title = "Infinite Yield",
    Desc  = "Many features and bang",
    Icon  = "solar:code-square-bold",
    Callback = safe(function()
        task.spawn(function()
            pcall(function()
                loadstring(game:HttpGet(
                    "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"
                ))()
            end)
        end)
    end),
})

UtilitiesTab:Button({
    Title = "Energize R6",
    Desc  = "FE animations hahaha",
    Icon  = "solar:body-bold",
    Callback = safe(function()
        task.spawn(function()
            pcall(function()
                loadstring(game:HttpGet("https://pastebin.com/raw/Cfeu2ZPc"))()
            end)
        end)
    end),
})

UtilitiesTab:Section({ Title = "Interface" })

UtilitiesTab:Button({
    Title = "Execute Rayfield Version",
    Desc  = "Kills WindUI and loads the Rayfield build",
    Icon = "solar:monitor-bold",
    Callback = safe(function()
        if Window and Window.Destroy then
            pcall(function() Window:Destroy() end)
        end
        task.wait(0.3)
        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/surrre4l/surrealhub/main/rayfieldver.lua"
        ))()
    end),
})

UtilitiesTab:Section({ Title = "Admin Panel" })

UtilitiesTab:Button({
    Title = "Force Open Admin Panel",
    Desc  = "Clone + kill LocalScripts + force everything visible",
    Icon  = "solar:shield-user-bold",
    Callback = safe(function()
        -- Clean old
        for _, parent in ipairs({
            LocalPlayer:FindFirstChild("PlayerGui"),
            (function() local ok, h = pcall(function() return gethui and gethui() end)
                return ok and h or nil end)(),
        }) do
            if parent then
                local old = parent:FindFirstChild("SurrealAdminPanel")
                if old then old:Destroy() end
            end
        end

        local products = ReplicatedStorage:FindFirstChild("Products")
        local guis = products and products:FindFirstChild("GUIs")
        local settings = guis and guis:FindFirstChild("Settings")
        if not settings then return notify("Admin Panel", "No Settings asset") end

        local ok, err = pcall(function()
            local clone = settings:Clone()
            clone.Name = "SurrealAdminPanel"
            clone.Enabled = true
            clone.ResetOnSpawn = false
            clone.DisplayOrder = 99999

            for _, obj in ipairs(clone:GetDescendants()) do
                if obj:IsA("LocalScript") or obj:IsA("Script") then
                    obj:Destroy()
                end
            end
            for _, obj in ipairs(clone:GetDescendants()) do
                if obj:IsA("GuiObject") then obj.Visible = true end
            end

            local parent
            if gethui then
                local hok, h = pcall(gethui)
                if hok and h then parent = h end
            end
            clone.Parent = parent or LocalPlayer:WaitForChild("PlayerGui")

            task.spawn(function()
                while clone and clone.Parent do
                    task.wait(0.5)
                    pcall(function()
                        clone.Enabled = true
                        for _, obj in ipairs(clone:GetDescendants()) do
                            if obj:IsA("GuiObject") and not obj.Visible then
                                obj.Visible = true
                            end
                        end
                    end)
                end
            end)
        end)

        notify("Admin Panel", ok and "Opened" or tostring(err))
    end),
})

UtilitiesTab:Button({
    Title = "Close Admin Panel",
    Icon  = "solar:close-circle-bold",
    Callback = safe(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local old = pg and pg:FindFirstChild("SurrealAdminPanel")
        if old then old:Destroy() end
        notify("Admin Panel", "Closed")
    end),
})

--[[
]]

StatsTab:Section({ Title = "Player Stats" })

local statTarget = nil

local function buildPlayerOptions()
    local opts = { [1] = "(pick a player)" }
    for _, p in ipairs(Players:GetPlayers()) do table.insert(opts, p.Name) end
    return opts
end

local statsDropdown

local function refreshStatsDropdown()
    pcall(function() statsDropdown:Refresh(buildPlayerOptions()) end)
end

statsDropdown = StatsTab:Dropdown({
    Title = "Target Player",
    Desc  = "Choose who to inspect",
    Value = (buildPlayerOptions()[1] or ""),
    Values = buildPlayerOptions(),
    Callback = safe(function(idx)
        local opts = buildPlayerOptions()
        local pick = opts[selectedIndex(opts, idx)]
        statTarget = (pick and pick ~= "(pick a player)") and pick or nil
    end),
})

StatsTab:Button({
    Title = "Refresh List",
    Icon  = "solar:refresh-bold",
    Callback = safe(function()
        refreshStatsDropdown()
        notify("Stats", "Refreshed")
    end),
})

local STAT_KEYS = {
    "CampWins", "MoviesWins", "ExpeditionWins", "ComebackWins",
    "Coins", "GamesPlayed", "IdolsFound", "OfficialWins",
}

StatsTab:Button({
    Title = "View All Stats",
    Icon  = "solar:chart-bold",
    Callback = safe(function()
        if not statTarget then return notify("Stats", "Pick a player first") end
        local p = Players:FindFirstChild(statTarget)
        if not p then return notify("Stats", "Not found") end
        local ds = p:FindFirstChild("DataStore")
        if not ds then return notify("Stats", "No DataStore") end
        local lines = {}
        for _, key in ipairs(STAT_KEYS) do
            local stat = ds:FindFirstChild(key)
            if stat then table.insert(lines, key .. ": " .. tostring(stat.Value)) end
        end
        print("=== " .. statTarget .. " stats ===")
        for _, l in ipairs(lines) do print("  " .. l) end
        notify(statTarget, table.concat(lines, "\n"), 8)
    end),
})

StatsTab:Button({
    Title = "Print Skins",
    Icon  = "solar:palette-bold",
    Callback = safe(function()
        if not statTarget then return notify("Stats", "Pick a player first") end
        local p = Players:FindFirstChild(statTarget)
        local ds = p and p:FindFirstChild("DataStore")
        local skins = ds and ds:FindFirstChild("Skins")
        if not skins then return notify("Stats", "No Skins") end
        local list = skins:GetChildren()
        print(statTarget .. " skins: " .. #list)
        for _, v in ipairs(list) do print("  " .. v.Name) end
        notify("Skins", #list .. " owned — F9", 5)
    end),
})

StatsTab:Button({
    Title = "Print Marshmallows",
    Icon  = "solar:smile-bold",
    Callback = safe(function()
        if not statTarget then return notify("Stats", "Pick a player first") end
        local p = Players:FindFirstChild(statTarget)
        local ds = p and p:FindFirstChild("DataStore")
        local marsh = ds and ds:FindFirstChild("Marshmallows")
        if not marsh then return notify("Stats", "No Marshmallows") end
        local list = marsh:GetChildren()
        print(statTarget .. " marshmallows: " .. #list)
        for _, v in ipairs(list) do print("  " .. v.Name) end
        notify("Marshmallows", #list .. " owned — F9", 5)
    end),
})

StatsTab:Button({
    Title = "View Confessional",
    Icon  = "solar:chat-round-dots-bold",
    Callback = safe(function()
        if not statTarget then return notify("Stats", "Pick a player first") end
        local p = Players:FindFirstChild(statTarget)
        local ds = p and p:FindFirstChild("DataStore")
        local conf = ds and ds:FindFirstChild("Confessional")
        if not conf then return notify("Stats", "No Confessional") end
        notify(statTarget, tostring(conf.Value), 6)
    end),
})

--[[
]]

TeamsTab:Section({ Title = "Quick Join" })

local function joinTeam(name)
    local Teams = game:GetService("Teams")
    local team = Teams:FindFirstChild(name)
    if not team then return notify("Team", "Not found: " .. name) end
    LocalPlayer.Team = team
    LocalPlayer.Neutral = false
    notify("Team", "Joined " .. name)
end

TeamsTab:Button({ Title = "Spectator", Desc = "Join Spectator team",
    Icon = "solar:eye-bold", Callback = safe(function() joinTeam("Spectator") end) })
TeamsTab:Button({ Title = "Jury", Desc = "Join Jury team",
    Icon = "solar:gavel-bold", Callback = safe(function() joinTeam("Jury") end) })
TeamsTab:Button({ Title = "Team 1", Desc = "Join Team 1",
    Icon = "solar:user-bold", Callback = safe(function() joinTeam("Team1") end) })
TeamsTab:Button({ Title = "Team 2", Desc = "Join Team 2",
    Icon = "solar:user-bold", Callback = safe(function() joinTeam("Team2") end) })
TeamsTab:Button({ Title = "Team 3", Desc = "Join Team 3",
    Icon = "solar:user-bold", Callback = safe(function() joinTeam("Team3") end) })

TeamsTab:Button({
    Title = "Print Teams",
    Desc  = "Log every available team to F9",
    Icon  = "solar:list-bold",
    Callback = safe(function()
        local Teams = game:GetService("Teams")
        print("=== Teams ===")
        for _, t in ipairs(Teams:GetChildren()) do
            print("  " .. t.Name)
        end
    end),
})

--[[
]]

CharacterTab:Section({ Title = "Skin Changer" })

local skinMap, skinFaceMap = {}, {}
local skinLabels = { [1] = "None" }

local function scanSkins()
    local root = ReplicatedStorage:FindFirstChild("Products")
    local cs   = root and root:FindFirstChild("CharacterSelection")
    local croot = cs and cs:FindFirstChild("Characters")
    if not croot then return end
    for _, gender in ipairs(croot:GetChildren()) do
        for _, character in ipairs(gender:GetChildren()) do
            local skins = character:FindFirstChild("Skins")
            if skins then
                local charKey = gender.Name .. " | " .. character.Name
                for _, skin in ipairs(skins:GetChildren()) do
                    local label = charKey .. " | " .. skin.Name
                    skinMap[label] = skin
                    local fd = skin:FindFirstChildOfClass("Decal")
                    if fd then skinFaceMap[label] = fd.Texture
                    else
                        local cfd = character:FindFirstChildOfClass("Decal")
                        skinFaceMap[label] = cfd and cfd.Texture or ""
                    end
                    table.insert(skinLabels, label)
                end
            end
        end
    end
    table.sort(skinLabels, function(a, b)
        if a == "None" then return true end
        if b == "None" then return false end
        return a < b
    end)
end

scanSkins()

local function findAttachment(char, name)
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("Attachment") and d.Name == name then return d end
    end
end

local function applySkin(skinObj, faceTexture)
    local char = LocalPlayer.Character
    if not char then return end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Shirt") or v:IsA("Pants") or v:IsA("Accessory")
        or v:IsA("ShirtGraphic") or v:IsA("CharacterMesh") or v:IsA("Hat") then
            v:Destroy()
        end
    end
    local function doFace()
        local head = char:FindFirstChild("Head")
        if not head or not faceTexture or faceTexture == "" then return end
        local fc = head:FindFirstChildOfClass("FaceControls")
        if fc then fc:Destroy() end
        local sa = head:FindFirstChildOfClass("SurfaceAppearance")
        if sa then sa.ColorMap = faceTexture end
        local decal = head:FindFirstChildOfClass("Decal")
        if not decal then
            decal = Instance.new("Decal")
            decal.Name = "face"
            decal.Face = Enum.NormalId.Front
            decal.Parent = head
        end
        decal.Texture = faceTexture
    end
    doFace()
    task.delay(0.2, doFace)
    task.delay(0.7, doFace)
    local clothes = skinObj:FindFirstChild("Clothes")
    if not clothes then return end
    local shirt = clothes:FindFirstChildOfClass("Shirt")
    if shirt then shirt:Clone().Parent = char end
    local pants = clothes:FindFirstChildOfClass("Pants")
    if pants then pants:Clone().Parent = char end
    local bc = clothes:FindFirstChildOfClass("BodyColors")
    if bc then
        local existing = char:FindFirstChildOfClass("BodyColors")
        if existing then existing:Destroy() end
        bc:Clone().Parent = char
    end
    for _, v in ipairs(clothes:GetChildren()) do
        if v:IsA("CharacterMesh") then v:Clone().Parent = char end
    end
    for _, v in ipairs(clothes:GetChildren()) do
        if v:IsA("Accessory") then
            local clone = v:Clone()
            local handle = clone:FindFirstChild("Handle")
            if handle then
                handle.Massless = true
                local hatAtt
                for _, ch in ipairs(handle:GetDescendants()) do
                    if ch:IsA("Attachment") then hatAtt = ch; break end
                end
                if hatAtt then
                    local charAtt = findAttachment(char, hatAtt.Name)
                    if charAtt then
                        local rigid = Instance.new("RigidConstraint")
                        rigid.Attachment0 = charAtt
                        rigid.Attachment1 = hatAtt
                        rigid.Parent = clone
                    end
                end
            end
            clone.Parent = char
        elseif v:IsA("Hat") then
            v:Clone().Parent = char
        end
    end
end

CharacterTab:Dropdown({
    Title = "Skin",
    Desc  = "Apply any skin from the game's roster",
    Value = skinLabels[1],
    Values = skinLabels,
    Callback = safe(function(idx)
        local label = skinLabels[selectedIndex(skinLabels, idx)]
        if not label or label == "None" then return end
        local skin = skinMap[label]
        local face = skinFaceMap[label]
        if skin then
            applySkin(skin, face)
            notify("Skin", skin.Name)
        end
    end),
})

CharacterTab:Section({ Title = "Marshmallow Changer" })

local MARSHMALLOWS = {
    ["Marshmallow"]                 = "http://www.roblox.com/asset/?id=4921967564",
    ["Mr.Coconut Marshmallow"]      = "http://www.roblox.com/asset/?id=4993225404",
    ["Cook Surprise Marshmallow"]   = "http://www.roblox.com/asset/?id=4993211976",
    ["Soda Marshmallow"]            = "http://www.roblox.com/asset/?id=13424792834",
    ["Dino Marshmallow"]            = "http://www.roblox.com/asset/?id=13424788699",
    ["Official 3-4 Marshmallow"]    = "http://www.roblox.com/asset/?id=9005433388",
    ["Furious Trout Marshmallow"]   = "http://www.roblox.com/asset/?id=13557360275",
    ["Orange Marshmallow"]          = "http://www.roblox.com/asset/?id=4993231360",
    ["Cabbage Marshmallow"]         = "http://www.roblox.com/asset/?id=13424785412",
    ["Toxic Marshmallow"]           = "http://www.roblox.com/asset/?id=4939073413",
    ["Grip Marshmallow"]            = "http://www.roblox.com/asset/?id=14253207872",
    ["Vote Me Marshmallow"]         = "http://www.roblox.com/asset/?id=13424797492",
    ["Honey Dipped Marshmallow"]    = "http://www.roblox.com/asset/?id=13424799638",
    ["Banana Marshmallow"]          = "http://www.roblox.com/asset/?id=4922748526",
    ["Cursed Idol Marshmallow"]     = "http://www.roblox.com/asset/?id=4993221853",
    ["Choc Dipped Marshmallow"]     = "http://www.roblox.com/asset/?id=10420319581",
    ["Candyfloss Marshmallow"]      = "http://www.roblox.com/asset/?id=4939071806",
    ["Guilty Gift Marshmallow"]     = "http://www.roblox.com/asset/?id=13424790186",
    ["Coconut Marshmallow"]         = "http://www.roblox.com/asset/?id=4922749819",
    ["Official Marshmallow"]        = "http://www.roblox.com/asset/?id=6190482040",
    ["Chocolate Marshmallow"]       = "http://www.roblox.com/asset/?id=8989965765",
    ["Toasted Marshmallow"]         = "http://www.roblox.com/asset/?id=11109548044",
    ["Surfboard Marshmallow"]       = "http://www.roblox.com/asset/?id=14253216830",
    ["Official 2 Marshmallow"]      = "http://www.roblox.com/asset/?id=6918605850",
    ["Stink Bomb Marshmallow"]      = "http://www.roblox.com/asset/?id=14253212538",
    ["Deathly Frog Marshmallow"]    = "http://www.roblox.com/asset/?id=13557357445",
    ["Heart Marshmallow"]           = "http://www.roblox.com/asset/?id=11109545563",
    ["Burnt Marshmallow"]           = "http://www.roblox.com/asset/?id=4939257688",
    ["Spooky Skull Marshmallow"]    = "http://www.roblox.com/asset/?id=13424794215",
    ["Camo Marshmallow"]            = "http://www.roblox.com/asset/?id=4993218908",
    ["Star Barrel Marshmallow"]     = "http://www.roblox.com/asset/?id=13557362587",
    ["Candycane Marshmallow"]       = "http://www.roblox.com/asset/?id=8087099712",
    ["Claus Marshmallow"]           = "http://www.roblox.com/asset/?id=8087103731",
    ["Gingerbread Marshmallow"]     = "http://www.roblox.com/asset/?id=8087104305",
    ["Snowflake Marshmallow"]       = "http://www.roblox.com/asset/?id=8087108522",
    ["Snowman Marshmallow"]         = "http://www.roblox.com/asset/?id=8087109234",
    ["Xmas Tree Marshmallow"]       = "http://www.roblox.com/asset/?id=8087102391",
    ["Official 5 Marshmallow"]      = "http://www.roblox.com/asset/?id=12089683577",
    ["Refresher Marshmallow"]       = "http://www.roblox.com/asset/?id=10420322407",
    ["Friendly Fish Marshmallow"]   = "http://www.roblox.com/asset/?id=6213300124",
    ["Popcorn Marshmallow"]         = "http://www.roblox.com/asset/?id=14253210682",
    ["Salt&Pepper Marshmallow"]     = "http://www.roblox.com/asset/?id=4939073043",
    ["Grape Marshmallow"]           = "http://www.roblox.com/asset/?id=4939072171",
    ["Mutant Marshmallow"]          = "http://www.roblox.com/asset/?id=4993228141",
    ["Blue Sky Marshmallow"]        = "http://www.roblox.com/asset/?id=6213301823",
    ["Rainbow Marshmallow"]         = "http://www.roblox.com/asset/?id=11109546611",
    ["Animatronic Marshmallow"]     = "http://www.roblox.com/asset/?id=14253197608",
    ["Fly Trap Marshmallow"]        = "http://www.roblox.com/asset/?id=13557358447",
    ["Lightning Marshmallow"]       = "http://www.roblox.com/asset/?id=6213299603",
    ["Official 6 Marshmallow"]      = "http://www.roblox.com/asset/?id=13883154348",
    ["Cave Marshmallow"]            = "http://www.roblox.com/asset/?id=14253202968",
    ["Briefcase Marshmallow"]       = "http://www.roblox.com/asset/?id=14253200770",
    ["Alien Slime Marshmallow"]     = "http://www.roblox.com/asset/?id=14253195386",
    ["Strawberry Marshmallow"]      = "http://www.roblox.com/asset/?id=8989965284",
    ["Gaffer Marshmallow"]          = "http://www.roblox.com/asset/?id=14253205269",
    ["Bane Marshmallow"]            = "http://www.roblox.com/asset/?id=4939072726",
    ["All Star Marshmallow"]        = "http://www.roblox.com/asset/?id=4993216167",
    ["Voting Machine Marshmallow"]  = "http://www.roblox.com/asset/?id=14253219599",
    ["Mint Choc Chip Marshmallow"]  = "http://www.roblox.com/asset/?id=10420505533",
    ["Dropped Marshmallow"]         = "http://www.roblox.com/asset/?id=6213298209",
    ["Spiderweb Marshmallow"]       = "http://www.roblox.com/asset/?id=14891850347",
    ["Mummy Marshmallow"]           = "http://www.roblox.com/asset/?id=14891849082",
    ["Jack-o-lantern Marshmallow"]  = "http://www.roblox.com/asset/?id=14891848232",
    ["Cauldron Marshmallow"]        = "http://www.roblox.com/asset/?id=14891845147",
    ["Ghost Marshmallow"]           = "http://www.roblox.com/asset/?id=14891847267",
    ["Candy Corn Marshmallow"]      = "http://www.roblox.com/asset/?id=14891843386",
    ["Black Cat Marshmallow"]       = "http://www.roblox.com/asset/?id=14891842127",
    ["Frankenstein Marshmallow"]    = "http://www.roblox.com/asset/?id=14891846020",
    ["Candy Cane Marshmallow"]      = "http://www.roblox.com/asset/?id=15484725814",
    ["Christmas Gift Marshmallow"]  = "http://www.roblox.com/asset/?id=15484726913",
    ["Christmas Tree Marshmallow"]  = "http://www.roblox.com/asset/?id=15484727551",
    ["Festive Lights Marshmallow"]  = "http://www.roblox.com/asset/?id=15484728253",
    ["Frosted Marshmallow"]         = "http://www.roblox.com/asset/?id=15484728905",
    ["Hot Chocolate Marshmallow"]   = "http://www.roblox.com/asset/?id=15484729538",
    ["Jingle Bell Marshmallow"]     = "http://www.roblox.com/asset/?id=15484730291",
    ["Mr Snow Marshmallow"]         = "http://www.roblox.com/asset/?id=15484731148",
    ["Reindeer Marshmallow"]        = "http://www.roblox.com/asset/?id=15484731823",
    ["Santa Suit Marshmallow"]      = "http://www.roblox.com/asset/?id=15484732509",
    ["Snowglobe Marshmallow"]       = "http://www.roblox.com/asset/?id=15484733560",
    ["The Grunch Marshmallow"]      = "http://www.roblox.com/asset/?id=15484734379",
    ["Bacon Grease Marshmallow"]    = "http://www.roblox.com/asset/?id=16029143731",
    ["Pink Paint Marshmallow"]      = "http://www.roblox.com/asset/?id=16029151877",
    ["Skunk Tail Marshmallow"]      = "http://www.roblox.com/asset/?id=16029163767",
    ["Rodent Face Marshmallow"]     = "http://www.roblox.com/asset/?id=16029162747",
    ["Candy Marshmallow"]           = "http://www.roblox.com/asset/?id=16029146948",
    ["Lychee Soda Marshmallow"]     = "http://www.roblox.com/asset/?id=16029149121",
    ["Banana Soda Marshmallow"]     = "http://www.roblox.com/asset/?id=16029144639",
    ["The Wolves Marshmallow"]      = "http://www.roblox.com/asset/?id=16029164794",
    ["Young Chester Marshmallow"]   = "http://www.roblox.com/asset/?id=16029185414",
    ["Owl Mascot Marshmallow"]      = "http://www.roblox.com/asset/?id=16029150192",
    ["Racoon Marshmallow"]          = "http://www.roblox.com/asset/?id=16029160256",
}

local marshList = { [1] = "None" }
for name in pairs(MARSHMALLOWS) do table.insert(marshList, name) end
table.sort(marshList, function(a, b)
    if a == "None" then return true end
    if b == "None" then return false end
    return a < b
end)

local function applyMarshmallow(tex)
    local char = LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")
    if not head then return end
    local gui = head:FindFirstChild("MarshmallowGUI")
    if not gui then return end
    local sector = gui:FindFirstChild("Sector")
    if not sector then return end
    local img = sector:FindFirstChildOfClass("ImageLabel")
    if img then img.Image = tex end
end

CharacterTab:Dropdown({
    Title = "Marshmallow",
    Desc  = "Swap the image on your marshmallow GUI",
    Value = marshList[1],
    Values = marshList,
    Callback = safe(function(idx)
        local name = marshList[selectedIndex(marshList, idx)]
        if not name or name == "None" then return end
        local tex = MARSHMALLOWS[name]
        if tex then
            applyMarshmallow(tex)
            notify("Marshmallow", name)
        end
    end),
})

CharacterTab:Section({ Title = "Elimination Changer" })

local boatBackup = nil

local function swapToSleigh()
    local ws = workspace
    local rs = ReplicatedStorage
    local elimFolder = ws:FindFirstChild("ElimMethod")
    if not elimFolder then return notify("Elim", "No ElimMethod") end
    local sleighTemplate = rs:FindFirstChild("Products")
        and rs.Products:FindFirstChild("ElimMethods")
        and rs.Products.ElimMethods:FindFirstChild("Camp")
        and rs.Products.ElimMethods.Camp:FindFirstChild("Sleigh Elimination")
    if not sleighTemplate then return notify("Elim", "No Sleigh asset") end

    local boat = elimFolder:FindFirstChild("Boat Elimination")
    if boat then
        boatBackup = boat:Clone()
        boatBackup.Parent = rs
    end
    for _, v in pairs(elimFolder:GetChildren()) do v:Destroy() end
    local clone = sleighTemplate:Clone()
    clone.Name = "Sleigh Elimination"
    clone.Parent = elimFolder
    if rs.Products.DataStore
       and rs.Products.DataStore:FindFirstChild("Elimination") then
        rs.Products.DataStore.Elimination.Value = "Sleigh Elimination"
    end
    local sound = clone:FindFirstChild("Sound", true)
    if sound then sound:Play() end
    notify("Elim", "Sleigh active — restores in 18s")

    task.delay(18, function()
        clone:Destroy()
        if boatBackup then
            local back = boatBackup:Clone()
            back.Name = "Boat Elimination"
            back.Parent = elimFolder
            if rs.Products.DataStore
               and rs.Products.DataStore:FindFirstChild("Elimination") then
                rs.Products.DataStore.Elimination.Value = "Boat Elimination"
            end
        end
    end)
end

local function restoreBoat()
    local ws = workspace
    local rs = ReplicatedStorage
    local elimFolder = ws:FindFirstChild("ElimMethod")
    if not elimFolder then return end
    for _, v in pairs(elimFolder:GetChildren()) do v:Destroy() end
    if boatBackup then
        local back = boatBackup:Clone()
        back.Name = "Boat Elimination"
        back.Parent = elimFolder
        if rs.Products.DataStore
           and rs.Products.DataStore:FindFirstChild("Elimination") then
            rs.Products.DataStore.Elimination.Value = "Boat Elimination"
        end
    end
    notify("Elim", "Boat restored")
end

CharacterTab:Dropdown({
    Title = "Elimination",
    Desc  = "Swap elimination method (Camp only)",
    Value = "None",
    Values = { [1] = "None", [2] = "Sleigh Elimination" },
    Callback = safe(function(idx)
        local pick = ({ "None", "Sleigh Elimination" })[selectedIndex({ "None", "Sleigh Elimination" }, idx)]
        if pick == "Sleigh Elimination" then swapToSleigh()
        elseif pick == "None" then restoreBoat() end
    end),
})

CharacterTab:Button({
    Title = "Force Restore Boat",
    Icon  = "solar:refresh-bold",
    Callback = safe(function() restoreBoat() end),
})

--[[
    VC Unban + Silent Camera + Fake #1 Leaderboard + VIP Nametag
]]

ClientTab:Section({ Title = "Voice Chat" })

ClientTab:Button({
    Title = "VC Unban",
    Desc  = "Rejoin voice chat to bypass a voice ban",
    Icon  = "solar:microphone-bold",
    Callback = safe(function()
        local VCS = game:GetService("VoiceChatService")
        local ok, err = pcall(function() VCS:joinVoice() end)
        if ok then notify("VC", "Rejoined voice")
        else notify("VC", "Failed: " .. tostring(err)) end
    end),
})

ClientTab:Section({ Title = "Camera" })

ClientTab:Toggle({
    Title = "Silent Camera",
    Desc  = "Detach camera from your character (freecam)",
    Value = false,
    Callback = safe(function(enabled)
        local cam = workspace.CurrentCamera
        if enabled then
            cam.CameraType = Enum.CameraType.Scriptable
            notify("Camera", "Silent ON")
        else
            cam.CameraType = Enum.CameraType.Custom
            local h = humanoid()
            if h then cam.CameraSubject = h end
        end
    end),
}, "SilentCamera")

ClientTab:Section({ Title = "Fake #1 Leaderboard" })

local Leaderboard = { conn = nil, origName = nil, origAvatar = nil }

local function myAvatarURL()
    return "https://www.roblox.com/headshot-thumbnail/image?userId="
        .. LocalPlayer.UserId
        .. "&width=48&height=48&format=png"
end

local function collectBoards()
    local boards = {}
    local elements = workspace:FindFirstChild("Elements")
    if elements then
        for _, name in ipairs({
            "CampWinLeaderboard",
            "MoviesWinLeaderboard",
            "ExpeditionWinLeaderboard",
        }) do
            local b = elements:FindFirstChild(name)
            if b then table.insert(boards, b) end
        end
    end
    local generic = workspace:FindFirstChild("WinLeaderboard")
    if generic then table.insert(boards, generic) end
    return boards
end

local function patchBoard(board)
    local surface
    for _, child in ipairs(board:GetChildren()) do
        if child:IsA("SurfaceGui") then surface = child; break end
    end
    if not surface then return false end
    local scroll = surface:FindFirstChild("ScrollingFrame")
    if not scroll then return false end
    local patched = 0
    for _, frame in ipairs(scroll:GetChildren()) do
        if frame:IsA("Frame") then
            local image = frame:FindFirstChild("Image")
            local place = image and image:FindFirstChild("Place")
            if place and place.Text == "1" then
                local nameLabel = frame:FindFirstChild("PName")
                if nameLabel then
                    if not Leaderboard.origName then
                        Leaderboard.origName = nameLabel.Text
                    end
                    nameLabel.Text = LocalPlayer.Name
                end
                if image:IsA("ImageLabel") then
                    if not Leaderboard.origAvatar then
                        Leaderboard.origAvatar = image.Image
                    end
                    image.Image = myAvatarURL()
                end
                patched = patched + 1
            end
        end
    end
    return patched > 0
end

ClientTab:Button({
    Title = "Apply Fake #1 Leaderboard",
    Desc  = "Swap the physical board's #1 slot for you",
    Icon  = "solar:trophy-bold",
    Callback = safe(function()
        local boards = collectBoards()
        if #boards == 0 then
            return notify("Leaderboard", "No board found")
        end
        for _, b in ipairs(boards) do pcall(patchBoard, b) end
        if Leaderboard.conn then Leaderboard.conn:Disconnect() end
        Leaderboard.conn = RunService.Heartbeat:Connect(function()
            for _, b in ipairs(boards) do pcall(patchBoard, b) end
        end)
        notify("Leaderboard", "Patched")
    end),
})

ClientTab:Button({
    Title = "Restore Leaderboard",
    Icon  = "solar:refresh-bold",
    Callback = safe(function()
        if Leaderboard.conn then
            Leaderboard.conn:Disconnect()
            Leaderboard.conn = nil
        end
        for _, b in ipairs(collectBoards()) do
            local surface = b:FindFirstChildOfClass("SurfaceGui")
            if surface then
                local scroll = surface:FindFirstChild("ScrollingFrame")
                if scroll then
                    for _, frame in ipairs(scroll:GetChildren()) do
                        if frame:IsA("Frame") then
                            local image = frame:FindFirstChild("Image")
                            local place = image and image:FindFirstChild("Place")
                            if place and place.Text == "1" then
                                local nl = frame:FindFirstChild("PName")
                                if nl and Leaderboard.origName then
                                    nl.Text = Leaderboard.origName
                                end
                                if image:IsA("ImageLabel")
                                   and Leaderboard.origAvatar then
                                    image.Image = Leaderboard.origAvatar
                                end
                            end
                        end
                    end
                end
            end
        end
        Leaderboard.origName = nil
        Leaderboard.origAvatar = nil
        notify("Leaderboard", "Restored")
    end),
})

ClientTab:Section({ Title = "VIP Nametag" })

local VIP = { colors = {} }

ClientTab:Toggle({
    Title = "VIP Nametag",
    Desc  = "Makes the game's hidden VIP badge visible + colors name gold",
    Value = false,
    Callback = safe(function(enabled)
        local char = LocalPlayer.Character
        if not char then return notify("VIP", "Respawn first") end
        local head = char:FindFirstChild("Head")
        if not head then return notify("VIP", "No Head") end
        local pn = head:FindFirstChild("playerName")
        if not pn then return notify("VIP", "No playerName GUI") end

        local vip = pn:FindFirstChild("VIP")
        if vip then
            vip.Visible = enabled
            for _, v in ipairs(vip:GetDescendants()) do
                if v:IsA("GuiObject") then v.Visible = enabled end
            end
        end
        for _, v in ipairs(pn:GetDescendants()) do
            if v:IsA("TextLabel") or v:IsA("TextButton") then
                if enabled then
                    if not VIP.colors[v] then
                        VIP.colors[v] = v.TextColor3
                    end
                    v.TextColor3 = Color3.fromRGB(255, 165, 0)
                else
                    if VIP.colors[v] then
                        v.TextColor3 = VIP.colors[v]
                        VIP.colors[v] = nil
                    end
                end
            end
        end
        notify("VIP", enabled and "ON" or "OFF")
    end),
}, "VIPNametag")

--[[
]]

AutoplayTab:Section({ Title = "Credits" })

AutoplayTab:Paragraph({
    Title   = "Credits",
    Content = "Autoplay engine by Ian\nAutoplay system is in beta",
})

AutoplayTab:Section({ Title = "Autoplay" })

local REPO_BASE    = "https://raw.githubusercontent.com/manningian744-droid/Open-Source-Autoplay/refs/heads/main/"
local MANIFEST_URL = REPO_BASE .. "manifest.txt"
local GITHUB_API   = "https://api.github.com/repos/manningian744-droid/Open-Source-Autoplay/commits?path="
local FOLDER       = "TAS_Recorder"
local REC_FOLDER   = FOLDER .. "/recordings"
local TIMESTAMPS   = FOLDER .. "/timestamps.json"

local DISPLAY_NAMES = {
    ["boot1"] = "Bootcamp (Left)", ["boot2"] = "Bootcamp (Middle)",
    ["boot3"] = "Bootcamp (Right)", ["cave"] = "Cave Chaos",
    ["collo"] = "Colosseum Climb", ["collo2"] = "Colosseum Climb (Faster)",
    ["cons"] = "Construct Course", ["hill"] = "Hill Hike",
    ["lava"] = "Lava Dash", ["obsta"] = "Obstacle Course",
    ["pond"] = "Pond Pier", ["rickety"] = "Rickety Rails",
    ["rock1"] = "Rockwall (Left)", ["rock2"] = "Rockwall (Middle)",
    ["rock3"] = "Rockwall (Right)", ["spin"] = "Spinner",
    ["sweep"] = "Sweeper", ["tight"] = "Tightrope",
    ["unstab"] = "Unstable Savannah",
    ["caveclip"] = "Cave Chaos (Clip)",
    ["unstabclip"] = "Unstable Savannah (Clip)",
}

local MAP_KEYWORDS = {
    { key = "bootcamp",   id = "boot1" },
    { key = "cave",       id = "cave" },
    { key = "colosseum",  id = "collo" },
    { key = "construct",  id = "cons" },
    { key = "hill",       id = "hill" },
    { key = "lava",       id = "lava" },
    { key = "obstacle",   id = "obsta" },
    { key = "pond",       id = "pond" },
    { key = "rickety",    id = "rickety" },
    { key = "rock wall",  id = "rock1" },
    { key = "rockwall",   id = "rock1" },
    { key = "spinner",    id = "spin" },
    { key = "sweeper",    id = "sweep" },
    { key = "tightrope",  id = "tight" },
    { key = "unstable",   id = "unstab" },
    { key = "savannah",   id = "unstab" },
}

local TAS = {
    running = false, autoplayOn = false,
    playConn = nil, conns = {},
    recorder = { frames = {}, recording = false, startTime = 0, recConn = nil, finishConns = {}, autoOn = false },
}

local function tasTrack(c) table.insert(TAS.conns, c); return c end
local function tasClearConns()
    for _, c in ipairs(TAS.conns) do pcall(function() c:Disconnect() end) end
    TAS.conns = {}
end

local function fetchManifest()
    local ok, content = pcall(function() return game:HttpGet(MANIFEST_URL, true) end)
    if not ok or not content or #content < 3 then return nil end
    local runs = {}
    for line in content:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then
            local id = line:gsub("%.json$", "")
            table.insert(runs, { id = id, label = DISPLAY_NAMES[id] or id })
        end
    end
    return #runs > 0 and runs or nil
end

local function loadStamps()
    if not isfile(TIMESTAMPS) then return {} end
    local ok, c = pcall(readfile, TIMESTAMPS)
    if not ok or not c then return {} end
    local ok2, d = pcall(function() return HttpService:JSONDecode(c) end)
    return (ok2 and type(d) == "table") and d or {}
end

local function saveStamps(t)
    pcall(function() writefile(TIMESTAMPS, HttpService:JSONEncode(t)) end)
end

local function fetchCommitDate(filename)
    local ok, c = pcall(function()
        return game:HttpGet(GITHUB_API .. filename .. "&per_page=1", true)
    end)
    if not ok or not c then return nil end
    local ok2, d = pcall(function() return HttpService:JSONDecode(c) end)
    if not ok2 or type(d) ~= "table" or not d[1] then return nil end
    local commit = d[1].commit
    return commit and commit.committer and commit.committer.date or nil
end

local function ensureRuns(runs)
    if not isfolder(FOLDER) then makefolder(FOLDER) end
    local stamps = loadStamps()
    local downloaded, updated = 0, 0
    for _, run in ipairs(runs) do
        local filename = run.id .. ".json"
        local path = FOLDER .. "/" .. filename
        local exists = isfile(path)
        local remote = fetchCommitDate(filename)
        local localT = stamps[filename]
        local needs = (not exists) or (remote and localT and remote ~= localT)
                      or (remote and not localT)
        if needs then
            local ok, content = pcall(function()
                return game:HttpGet(REPO_BASE .. filename, true)
            end)
            if ok and content and #content > 10 then
                pcall(function() writefile(path, content) end)
                if remote then stamps[filename] = remote end
                if exists then updated = updated + 1 else downloaded = downloaded + 1 end
            end
        end
    end
    saveStamps(stamps)
    if updated + downloaded > 0 then
        notify("TAS Repo", "Downloaded " .. downloaded .. ", updated " .. updated)
    end
end

local ValToStateName = {}
for _, s in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
    ValToStateName[s.Value] = s.Name
end

local KeepEnabled = {
    [Enum.HumanoidStateType.Dead] = true,
    [Enum.HumanoidStateType.GettingUp] = true,
    [Enum.HumanoidStateType.Landed] = true,
    [Enum.HumanoidStateType.None] = true,
}

local function cfToQuat(cf)
    local ax, ang = cf:ToAxisAngle()
    local sh = math.sin(ang / 2)
    return ax.X*sh, ax.Y*sh, ax.Z*sh, math.cos(ang / 2)
end

local function quatToCF(x, y, z, qx, qy, qz, qw)
    return CFrame.new(x, y, z, qx, qy, qz, qw)
end

local function normaliseFrame(f)
    local function fix(t)
        if type(t) == "table" then
            if #t == 12 then
                local cf = CFrame.new(table.unpack(t))
                local qx, qy, qz, qw = cfToQuat(cf)
                return {cf.X, cf.Y, cf.Z, qx, qy, qz, qw}
            elseif #t == 6 then
                local cf = CFrame.new(t[1], t[2], t[3])
                    * CFrame.fromEulerAnglesYXZ(t[4], t[5], t[6])
                local qx, qy, qz, qw = cfToQuat(cf)
                return {cf.X, cf.Y, cf.Z, qx, qy, qz, qw}
            end
        end
        return t
    end
    if f.CF then f.CF = fix(f.CF) end
    if f.CCF then f.CCF = fix(f.CCF) end
end

local function tasStop()
    if TAS.playConn then
        pcall(function() TAS.playConn:Disconnect() end)
        TAS.playConn = nil
    end
    TAS.running = false
    local char = LocalPlayer.Character
    if not char then return end
    local r = char:FindFirstChild("HumanoidRootPart")
    local h = char:FindFirstChildOfClass("Humanoid")
    if r then
        r.Anchored = false
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    if h then
        for _, st in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
            pcall(function() h:SetStateEnabled(st, true) end)
        end
    end
end

local function tasPlay(label, rawJson)
    if TAS.running then tasStop() task.wait(0.05) end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, rawJson)
    if not ok or type(data) ~= "table" then
        return notify("TAS Error", "Bad data")
    end
    local frames = {}
    if type(data.frames) == "table" then
        for _, f in ipairs(data.frames) do
            normaliseFrame(f); table.insert(frames, f)
        end
    else
        if type(data[1]) ~= "table" or type(data[2]) ~= "table" then
            return notify("TAS Error", "Unrecognized format")
        end
        for _, seg in ipairs(data[1]) do
            for _, f in ipairs(seg) do
                normaliseFrame(f); table.insert(frames, f)
            end
        end
        for _, f in ipairs(data[2]) do
            normaliseFrame(f); table.insert(frames, f)
        end
    end
    if #frames == 0 then return notify("TAS Error", "No frames") end

    local char = LocalPlayer.Character
    local r = char and char:FindFirstChild("HumanoidRootPart")
    local h = char and char:FindFirstChildOfClass("Humanoid")
    if not r then return notify("TAS Error", "Respawn first") end

    TAS.running = true
    r.Anchored = false
    if h then
        for _, st in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
            if not KeepEnabled[st] then
                pcall(function() h:SetStateEnabled(st, false) end)
            end
        end
    end

    notify("TAS Playing", label)
    local t0 = os.clock()
    local idx = 1

    TAS.playConn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent or not r or not r.Parent then
            tasStop() return
        end
        if h and h.Health <= 0 then tasStop() return end

        local elapsed = os.clock() - t0
        while idx < #frames and frames[idx+1] and frames[idx+1].T <= elapsed do
            idx = idx + 1
        end
        local fA, fB = frames[idx], frames[idx + 1]

        if fB and type(fA) == "table" and type(fB) == "table"
           and fA.CF and fB.CF and fA.V and fB.V and fA.RV and fB.RV then
            local dt = fB.T - fA.T
            local alpha = (dt > 0) and math.clamp((elapsed - fA.T) / dt, 0, 1) or 0

            r.CFrame = quatToCF(table.unpack(fA.CF))
                :Lerp(quatToCF(table.unpack(fB.CF)), alpha)
            if type(fA.CCF) == "table" and type(fB.CCF) == "table" then
                workspace.CurrentCamera.CFrame = quatToCF(table.unpack(fA.CCF))
                    :Lerp(quatToCF(table.unpack(fB.CCF)), alpha)
            end
            local vA = Vector3.new(table.unpack(fA.V))
            local vB = Vector3.new(table.unpack(fB.V))
            local rvA = Vector3.new(table.unpack(fA.RV))
            local rvB = Vector3.new(table.unpack(fB.RV))
            local cv = vA:Lerp(vB, alpha)
            local crv = rvA:Lerp(rvB, alpha)
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.AssemblyLinearVelocity = cv
                    p.AssemblyAngularVelocity = crv
                end
            end
            if h and fA.HS then
                local sname = type(fA.HS) == "number" and ValToStateName[fA.HS] or fA.HS
                if sname and sname ~= "None" and h:GetState().Name ~= sname then
                    local enum = Enum.HumanoidStateType[sname]
                    if enum then pcall(function() h:ChangeState(enum) end) end
                end
            end
        else
            tasStop()
            notify("TAS Done", label)
        end
    end)
end

local function tasPlayFromFile(path, label)
    if not isfile(path) then return notify("TAS Error", "Missing file") end
    local ok, content = pcall(readfile, path)
    if not ok or not content then return notify("TAS Error", "Read failed") end
    tasPlay(label, content)
end

local function currentMapName()
    local assets = workspace:FindFirstChild("Assets")
    if not assets then return nil end
    for _, child in ipairs(assets:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then return child.Name end
    end
    return nil
end

local function matchRunForMap(mapName)
    if not mapName then return nil end
    local lower = mapName:lower()
    for _, e in ipairs(MAP_KEYWORDS) do
        if lower:find(e.key, 1, true) then
            return e.id, DISPLAY_NAMES[e.id] or e.id
        end
    end
    return nil
end

local CD = { fired = false, seen3 = false, seen2 = false, seen1 = false, seenGO = false }
local function resetCD()
    CD.fired, CD.seen3, CD.seen2, CD.seen1, CD.seenGO = false, false, false, false, false
end
local function fireCD(cb)
    if CD.fired then return end
    CD.fired = true
    task.spawn(function() task.wait(0.15); cb() end)
end

local function watchCountdown(cb)
    resetCD()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    for _, r in ipairs({ pg, workspace }) do
        if r then
            tasTrack(r.DescendantAdded:Connect(function(obj)
                if not TAS.autoplayOn then return end
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    local t = (obj.Text or ""):upper():gsub("%s", "")
                    if t == "3" then CD.seen3 = true end
                    if t == "2" then CD.seen2 = true end
                    if t == "1" then CD.seen1 = true end
                    if t == "GO" or t == "GO!" or t == "GO!!" then
                        CD.seenGO = true
                        fireCD(cb)
                    end
                end
            end))
        end
    end
    tasTrack(RunService.Heartbeat:Connect(function()
        if not TAS.autoplayOn or CD.fired then return end
        if pg then
            for _, obj in ipairs(pg:GetDescendants()) do
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    local t = (obj.Text or ""):upper():gsub("%s", "")
                    if t == "GO" or t == "GO!" or t == "GO!!" then
                        CD.seenGO = true; fireCD(cb); return
                    end
                end
            end
        end
        if CD.fired then return end
        local h = humanoid()
        if h and h.WalkSpeed >= 16 and (CD.seen3 or CD.seen2 or CD.seen1) then
            fireCD(cb); return
        end
        local cp = workspace:FindFirstChild("ChallengePlayers")
        if cp and cp:FindFirstChild(LocalPlayer.Name) then fireCD(cb) end
    end))
end

local function tryAutoplay()
    if not TAS.autoplayOn or TAS.running then return end
    local mapName = currentMapName()
    if not mapName then return end
    local runId, label = matchRunForMap(mapName)
    if not runId then
        return notify("Autoplay", "No run for \"" .. mapName .. "\"")
    end
    tasPlayFromFile(FOLDER .. "/" .. runId .. ".json", label)
end

AutoplayTab:Toggle({
    Title = "Autoplay",
    Desc  = "Auto-start the matching run when countdown ends",
    Value = false,
    Callback = safe(function(enabled)
        TAS.autoplayOn = enabled
        tasClearConns()
        if enabled then
            watchCountdown(tryAutoplay)
            local assets = workspace:FindFirstChild("Assets")
            if assets then
                tasTrack(assets.ChildAdded:Connect(function()
                    if not TAS.autoplayOn then return end
                    task.wait(0.5); tryAutoplay()
                end))
            end
            notify("Autoplay", "ON · waiting for round")
        else
            tasStop()
            notify("Autoplay", "OFF")
        end
    end),
}, "TASAutoplay")

AutoplayTab:Button({
    Title = "Play Current Map", Desc = "Detect + play the run for current obby",
    Icon  = "solar:play-bold",
    Callback = safe(function()
        local mapName = currentMapName()
        if not mapName then return notify("Autoplay", "No obby") end
        local runId, label = matchRunForMap(mapName)
        if not runId then return notify("Autoplay", "No run for " .. mapName) end
        tasPlayFromFile(FOLDER .. "/" .. runId .. ".json", label)
    end),
})

AutoplayTab:Button({
    Title = "Stop Playback", Desc = "Stop any active playback",
    Icon  = "solar:stop-circle-bold",
    Callback = safe(function() tasStop(); notify("Autoplay", "Stopped") end),
})

AutoplayTab:Section({ Title = "Recorder" })

AutoplayTab:Toggle({
    Title = "Auto-Record on Round Start",
    Desc  = "Starts recording when the round begins",
    Value = false,
    Callback = safe(function(enabled)
        TAS.recorder.autoOn = enabled
        if not enabled then return end
        task.spawn(function()
            while TAS.recorder.autoOn do
                task.wait(0.5)
                if not TAS.recorder.recording then
                    local h = humanoid()
                    local cp = workspace:FindFirstChild("ChallengePlayers")
                    if h and h.WalkSpeed == 0 and cp
                       and cp:FindFirstChild(LocalPlayer.Name) then
                        -- Start recording
                        TAS.recorder.frames = {}
                        TAS.recorder.recording = true
                        TAS.recorder.startTime = tick()
                        if TAS.recorder.recConn then
                            TAS.recorder.recConn:Disconnect()
                        end
                        TAS.recorder.recConn = RunService.RenderStepped:Connect(function()
                            if not TAS.recorder.recording then return end
                            local c = LocalPlayer.Character
                            if not c then return end
                            local r = c:FindFirstChild("HumanoidRootPart")
                            local hh = c:FindFirstChildOfClass("Humanoid")
                            local cam = workspace.CurrentCamera
                            if not r or not hh or not cam then return end
                            local cfx, cfy, cfz, cfqx, cfqy, cfqz, cfqw = r.CFrame.X, r.CFrame.Y, r.CFrame.Z, cfToQuat(r.CFrame)
                            local ccx, ccy, ccz, ccqx, ccqy, ccqz, ccqw = cam.CFrame.X, cam.CFrame.Y, cam.CFrame.Z, cfToQuat(cam.CFrame)
                            table.insert(TAS.recorder.frames, {
                                CF = {cfx, cfy, cfz, cfqx, cfqy, cfqz, cfqw},
                                CCF = {ccx, ccy, ccz, ccqx, ccqy, ccqz, ccqw},
                                V = {r.AssemblyLinearVelocity.X, r.AssemblyLinearVelocity.Y, r.AssemblyLinearVelocity.Z},
                                RV = {r.AssemblyAngularVelocity.X, r.AssemblyAngularVelocity.Y, r.AssemblyAngularVelocity.Z},
                                T = tick() - TAS.recorder.startTime,
                                HS = hh:GetState().Name,
                            })
                        end)
                        notify("Recorder", "Recording…")
                    end
                end
            end
        end)
    end),
}, "AutoRecord")

AutoplayTab:Button({
    Title = "Start Recording", Desc = "Manually begin recording",
    Icon  = "solar:record-circle-bold",
    Callback = safe(function()
        TAS.recorder.frames = {}
        TAS.recorder.recording = true
        TAS.recorder.startTime = tick()
        if TAS.recorder.recConn then TAS.recorder.recConn:Disconnect() end
        TAS.recorder.recConn = RunService.RenderStepped:Connect(function()
            if not TAS.recorder.recording then return end
            local c = LocalPlayer.Character
            if not c then return end
            local r = c:FindFirstChild("HumanoidRootPart")
            local hh = c:FindFirstChildOfClass("Humanoid")
            local cam = workspace.CurrentCamera
            if not r or not hh or not cam then return end
            local cfx, cfy, cfz, cfqx, cfqy, cfqz, cfqw = r.CFrame.X, r.CFrame.Y, r.CFrame.Z, cfToQuat(r.CFrame)
            local ccx, ccy, ccz, ccqx, ccqy, ccqz, ccqw = cam.CFrame.X, cam.CFrame.Y, cam.CFrame.Z, cfToQuat(cam.CFrame)
            table.insert(TAS.recorder.frames, {
                CF = {cfx, cfy, cfz, cfqx, cfqy, cfqz, cfqw},
                CCF = {ccx, ccy, ccz, ccqx, ccqy, ccqz, ccqw},
                V = {r.AssemblyLinearVelocity.X, r.AssemblyLinearVelocity.Y, r.AssemblyLinearVelocity.Z},
                RV = {r.AssemblyAngularVelocity.X, r.AssemblyAngularVelocity.Y, r.AssemblyAngularVelocity.Z},
                T = tick() - TAS.recorder.startTime,
                HS = hh:GetState().Name,
            })
        end)
        notify("Recorder", "Recording…")
    end),
})

AutoplayTab:Button({
    Title = "Stop Recording", Desc = "Stops and keeps buffer",
    Icon  = "solar:stop-circle-bold",
    Callback = safe(function()
        TAS.recorder.recording = false
        if TAS.recorder.recConn then
            TAS.recorder.recConn:Disconnect()
            TAS.recorder.recConn = nil
        end
        notify("Recorder", "Stopped · " .. #TAS.recorder.frames .. " frames")
    end),
})

local saveName = ""

AutoplayTab:Input({
    Title       = "Recording Name",
    Desc        = "Type a name then Save",
    Placeholder = "e.g. cave_run_1",
    Callback    = safe(function(v) saveName = v or "" end),
})

AutoplayTab:Button({
    Title = "Save Recording", Desc = "Save buffer to disk",
    Icon  = "solar:save-bold",
    Callback = safe(function()
        if saveName == "" then return notify("Recorder", "Enter a name") end
        if #TAS.recorder.frames == 0 then return notify("Recorder", "Nothing recorded") end
        if not isfolder(FOLDER) then makefolder(FOLDER) end
        if not isfolder(REC_FOLDER) then makefolder(REC_FOLDER) end
        saveName = saveName:gsub("[^%w_%- ]", ""):gsub("%s+", "_")
        local payload = {
            meta = { name = saveName, created = os.date("%Y-%m-%d %H:%M:%S"),
                     frames = #TAS.recorder.frames },
            frames = TAS.recorder.frames,
        }
        local path = REC_FOLDER .. "/" .. saveName .. ".json"
        local ok = pcall(function()
            writefile(path, HttpService:JSONEncode(payload))
        end)
        notify("Recorder", ok and "Saved: " .. saveName or "Save failed")
    end),
})

AutoplayTab:Button({
    Title = "Clear Buffer", Desc = "Discard current recording",
    Icon  = "solar:trash-bin-trash-bold",
    Callback = safe(function()
        TAS.recorder.frames = {}
        notify("Recorder", "Buffer cleared")
    end),
})

AutoplayTab:Section({ Title = "Saved Recordings" })

local function recListFiles()
    if not isfolder(REC_FOLDER) then return { [1] = "(none)" } end
    local out = { [1] = "(none)" }
    for _, path in ipairs(listfiles(REC_FOLDER)) do
        local fname = path:match("([^/\\]+)$") or path
        if fname:match("%.json$") then
            table.insert(out, fname:gsub("%.json$", ""))
        end
    end
    table.sort(out, function(a, b)
        if a == "(none)" then return true end
        if b == "(none)" then return false end
        return a < b
    end)
    return out
end

local selectedRec = nil
local recDropdown

local function refreshRecDropdown()
    local list = recListFiles()
    if recDropdown then
        pcall(function() recDropdown:Refresh(list) end)
    end
end

recDropdown = AutoplayTab:Dropdown({
    Title = "Select Recording",
    Desc  = "Choose a saved recording",
    Value = recListFiles()[1],
    Values = recListFiles(),
    Callback = safe(function(idx)
        local list = recListFiles()
        local pick = list[selectedIndex(list, idx)]
        if pick and pick ~= "(none)" then
            selectedRec = pick
        end
    end),
})

AutoplayTab:Button({
    Title = "Refresh List", Desc = "Reload recordings dropdown",
    Icon  = "solar:refresh-bold",
    Callback = safe(function() refreshRecDropdown() end),
})

AutoplayTab:Button({
    Title = "Play Selected", Desc = "Play the chosen recording",
    Icon  = "solar:play-bold",
    Callback = safe(function()
        if not selectedRec then return notify("Recorder", "Pick one first") end
        tasPlayFromFile(REC_FOLDER .. "/" .. selectedRec .. ".json", selectedRec)
    end),
})

AutoplayTab:Button({
    Title = "Delete Selected", Desc = "Remove chosen recording",
    Icon  = "solar:trash-bin-trash-bold",
    Callback = safe(function()
        if not selectedRec then return notify("Recorder", "Pick one first") end
        local path = REC_FOLDER .. "/" .. selectedRec .. ".json"
        if isfile(path) then
            pcall(function() delfile(path) end)
            notify("Recorder", "Deleted: " .. selectedRec)
            selectedRec = nil
            refreshRecDropdown()
        end
    end),
})

AutoplayTab:Section({ Title = "Downloaded Runs" })

-- Build the downloaded-run list asynchronously so network/file operations
-- cannot block the UI from appearing.
local runs = {}

local function buildDownloadedRuns()
    local ok, result = pcall(function()
        local fetched = fetchManifest()
        if fetched then
            return fetched
        end

        if not isfolder or not listfiles or not isfile then
            return {}
        end

        if not isfolder(FOLDER) then
            if makefolder then
                pcall(function() makefolder(FOLDER) end)
            end
            return {}
        end

        local localRuns = {}
        for _, path in ipairs(listfiles(FOLDER)) do
            local fname = path:match("([^/\\]+)$") or path
            if fname:match("%.json$") and fname ~= "timestamps.json" then
                local id = fname:gsub("%.json$", "")
                table.insert(localRuns, { id = id, label = DISPLAY_NAMES[id] or id })
            end
        end

        table.sort(localRuns, function(a, b) return a.id < b.id end)
        return localRuns
    end)

    return ok and result or {}
end

local function addRunButtons(runList)
    if type(runList) ~= "table" or #runList == 0 then
        AutoplayTab:Paragraph({
            Title   = "No runs",
            Content = "No downloaded runs are currently available.",
        })
        return
    end

    for _, run in ipairs(runList) do
        AutoplayTab:Button({
            Title = run.label,
            Desc  = run.id .. ".json",
            Icon  = "solar:play-bold",
            Callback = safe(function()
                tasPlayFromFile(FOLDER .. "/" .. run.id .. ".json", run.label)
            end),
        })
    end
end

-- Do the optional manifest/download work after the UI has been constructed.
task.spawn(function()
    local loadedRuns = buildDownloadedRuns()

    task.defer(function()
        addRunButtons(loadedRuns)
    end)

    if type(loadedRuns) == "table" and #loadedRuns > 0 then
        pcall(function()
            ensureRuns(loadedRuns)
        end)
    end
end)


AutoplayTab:Button({
    Title = "Re-download Runs", Desc = "Force refresh from GitHub",
    Icon  = "solar:refresh-bold",
    Callback = safe(function()
        local fresh = fetchManifest()
        if fresh then
            ensureRuns(fresh)
            notify("TAS", "Re-downloaded")
        else
            notify("TAS", "Manifest unavailable")
        end
    end),
})

--[[
]]

PracticeTab:Section({ Title = "New Practice Utility Update!" })

PracticeTab:Button({
    Title = "Kill Everyone",
    Desc  = "Equips a sword and kills everyone in the practice round",
    Icon  = "solar:sword-bold",
    Callback = safe(function()
        local player = LocalPlayer
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local oldCFrame = hrp and hrp.CFrame

        ReplicatedStorage:WaitForChild("Events")
            :WaitForChild("PracticeMap")
            :FireServer("Movies", "Beach")

        if oldCFrame then
            task.wait(0.5)
            local newChar = player.Character
            local newHrp = newChar and newChar:FindFirstChild("HumanoidRootPart")
            if newHrp then newHrp.CFrame = oldCFrame end
        end

        task.spawn(function()
            local bp = player:WaitForChild("Backpack")
            local tool
            local waited = 0
            while waited < 3 do
                for _, t in ipairs(bp:GetChildren()) do
                    if t:IsA("Tool") then tool = t; break end
                end
                if tool then break end
                task.wait(0.1); waited = waited + 0.1
            end
            if tool then
                local h = humanoid()
                if h then h:EquipTool(tool) end
            end
        end)

        unbind("practiceKill")
        bind("practiceKill", RunService.RenderStepped:Connect(function()
            local all = Players:GetPlayers()
            for i = 2, #all do
                local v = all[i].Character
                if v and v:FindFirstChild("Humanoid")
                   and v.Humanoid.Health > 0
                   and v:FindFirstChild("HumanoidRootPart") then
                    local tool = LocalPlayer.Character
                        and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                    if tool and tool:FindFirstChild("Handle") then
                        tool:Activate()
                        for _, part in ipairs(v:GetChildren()) do
                            if part:IsA("BasePart") then
                                executorFireTouch and executorFireTouch(tool.Handle, part, 0)
                                executorFireTouch and executorFireTouch(tool.Handle, part, 1)
                            end
                        end
                    end
                end
            end
        end))
        task.delay(1, function() unbind("practiceKill") end)
    end),
})

PracticeTab:Button({
    Title = "Restart / Fling Reanimate [PATCHED]",
    Desc  = "Loads the reanimate script to restart / fling the round",
    Icon  = "solar:refresh-circle-bold",
    Callback = safe(function()
        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/robloxcheatck/reanimatescript/main/script.lua",
            true
        ))()
    end),
})

--[[
]]

local SettingsTab = Window:Tab({ Title = "Settings", Icon = "solar:tuning-2-bold" })

SettingsTab:Section({ Title = "Theme" })

SettingsTab:Dropdown({
    Title = "Theme",
    Desc  = "WindUI color theme",
    Value = "Surreal",
    Values = { [1] = "Surreal", [2] = "Dark", [3] = "Light",
               [4] = "Aqua", [5] = "Bloom", [6] = "Rose" },
    Callback = safe(function(idx, label)
        local pick = label
            or ({ "Surreal", "Dark", "Light", "Aqua", "Bloom", "Rose" })[selectedIndex({ "Surreal", "Dark", "Light", "Aqua", "Bloom", "Rose" }, idx)]
        if pick then pcall(function() WindUI:SetTheme(pick) end) end
    end),
})

SettingsTab:Section({ Title = "Notifications" })

SettingsTab:Button({
    Title = "Test Notifications",
    Desc  = "Fire a sample toast",
    Icon  = "solar:bell-bold",
    Callback = safe(function()
        notify("Surreal Hub", "Notifications are working")
    end),
})

SettingsTab:Section({ Title = "Info" })

SettingsTab:Paragraph({
    Title = "Surreal Hub V2.0",
    Content = "WindUI build · V1.2.0 + V2 additions.\n"
           .. "Press Right Shift to toggle the UI.",
})

SettingsTab:Button({
    Title = "Destroy UI",
    Desc  = "Close and unload the hub",
    Icon  = "solar:trash-bin-trash-bold",
    Callback = safe(function()
        for _, c in pairs(S.Conns) do pcall(function() c:Disconnect() end) end
        S.Conns = {}
        pcall(function() Window:Destroy() end)
    end),
})

--[[
]]

-- WindUI constructs the window during CreateWindow().
-- Avoid making startup depend on a second optional Init call.
task.delay(0.25, function()
    pcall(function()
        notify("Surreal Hub V2", "Loaded · Right Shift to toggle", 5)
    end)
end)

print("[Surreal Hub] V2.0 loaded successfully")