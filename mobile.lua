-- language: Lua (Roblox Luau), file: anon_perf.lua
-- Client-side render tuning only. No gameplay advantage, no AC surface.
-- Compatible: Delta, Arceus X, Solara, Fluxus, Hydrogen, Codex.

local Players          = game:GetService("Players")
local Lighting         = game:GetService("Lighting")
local Workspace        = game:GetService("Workspace")
local Terrain          = Workspace:FindFirstChildOfClass("Terrain")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local player = Players.LocalPlayer

-- ============================================================
-- CONFIG
-- ============================================================
local CFG = {
    graphics_level    = 1,
    render_distance   = 500,
    post_fx           = false,
    particles         = false,
    textures          = false,
    terrain_detail    = false,
    other_accessories = false,
    fflags            = true,
}

-- ============================================================
-- 1. GRAPHICS QUALITY
-- ============================================================
pcall(function()
    UserGameSettings.SavedQualityLevel = CFG.graphics_level
end)

-- ============================================================
-- 2. RENDER DISTANCE
-- ============================================================
pcall(function()
    if sethiddenproperty then
        sethiddenproperty(player, "MaxSimulationRadius", CFG.render_distance)
        sethiddenproperty(player, "SimulationRadius", CFG.render_distance)
    end
end)

-- ============================================================
-- 3. KILL POST-PROCESSING
-- ============================================================
if CFG.post_fx then
    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") or effect:IsA("Atmosphere")
        or effect:IsA("BloomEffect") or effect:IsA("BlurEffect")
        or effect:IsA("DepthOfFieldEffect") or effect:IsA("SunRaysEffect")
        or effect:IsA("ColorCorrectionEffect") then
            pcall(function() effect.Enabled = false end)
        end
    end
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd  = CFG.render_distance * 2
        Lighting.FogStart = CFG.render_distance
    end)

    pcall(function()
        Lighting.DescendantAdded:Connect(function(obj)
            if obj:IsA("PostEffect") or obj:IsA("BloomEffect")
            or obj:IsA("BlurEffect") or obj:IsA("DepthOfFieldEffect") then
                task.defer(function()
                    pcall(function() obj.Enabled = false end)
                end)
            end
        end)
    end)
end

-- ============================================================
-- 4. KILL PARTICLES / TRAILS / BEAMS
-- ============================================================
if CFG.particles then
    local killTypes = {
        ParticleEmitter = true, Trail = true, Beam = true,
        Smoke = true, Fire = true, Sparkles = true,
    }
    local function kill(parent)
        for _, obj in ipairs(parent:GetDescendants()) do
            if killTypes[obj.ClassName] then
                pcall(function() obj.Enabled = false end)
            end
        end
    end
    kill(Workspace)
    pcall(function()
        Workspace.DescendantAdded:Connect(function(obj)
            if killTypes[obj.ClassName] then
                task.defer(function()
                    pcall(function() obj.Enabled = false end)
                end)
            end
        end)
    end)
end

-- ============================================================
-- 5. TEXTURE + MATERIAL DOWNGRADE
-- ============================================================
if CFG.textures then
    local function downgrade(obj)
        if obj:IsA("BasePart") then
            pcall(function()
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
            end)
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            pcall(function() obj.Transparency = 1 end)
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do downgrade(obj) end
    pcall(function()
        Workspace.DescendantAdded:Connect(function(obj)
            task.defer(function() downgrade(obj) end)
        end)
    end)
end

-- ============================================================
-- 6. TERRAIN DOWNGRADE
-- ============================================================
if CFG.terrain_detail and Terrain then
    pcall(function()
        Terrain.WaterWaveSize     = 0
        Terrain.WaterWaveSpeed    = 0
        Terrain.WaterReflectance  = 0
        Terrain.WaterTransparency = 1
        Terrain.Decoration        = false
    end)
end

-- ============================================================
-- 7. HIDE OTHER PLAYERS' ACCESSORIES
-- ============================================================
if CFG.other_accessories then
    local function strip(char)
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("Accessory") or obj:IsA("Accoutrement") then
                pcall(function() obj:Destroy() end)
            elseif obj:IsA("Shirt") or obj:IsA("Pants")
            or obj:IsA("ShirtGraphic") then
                pcall(function() obj:Destroy() end)
            end
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then strip(p.Character) end
    end
    Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function(c)
            task.wait(1)
            strip(c)
        end)
    end)
end

-- ============================================================
-- 8. FFLAGS
-- ============================================================
if CFG.fflags and type(setfflag) == "function" then
    local flags = {
        ["DFIntTaskSchedulerTargetFps"]                = "240",
        ["FFlagTaskSchedulerBlockingNewThreads"]       = "True",
        ["FFlagRenderSynchronous"]                      = "False",
        ["FFlagRenderDynamicResolution"]                = "True",
        ["DFIntRenderDynamicResolutionMinScale"]        = "50",
        ["DFIntRenderDynamicResolutionMaxScale"]        = "100",
        ["FFlagRenderShadowIntensityEnabled"]           = "False",
        ["FFlagRenderSkyboxes"]                         = "False",
        ["DFIntTextureCompositorActiveJobs"]            = "4",
        ["DFIntTextureQualityOverride"]                 = "1",
        ["DFIntCSGLevelOfDetailSwitchingDistance"]      = "0",
        ["DFIntCSGLevelOfDetailSwitchingDistanceLOD12"] = "0",
        ["DFIntCSGLevelOfDetailSwitchingDistanceLOD23"] = "0",
        ["FFlagRenderParticleLighting"]                 = "False",
        ["FFlagParticleEmitterUseLOD"]                  = "True",
        ["FFlagRenderPostFX"]                           = "False",
        ["FFlagRenderAntiAliasing"]                     = "False",
        ["FFlagDisablePostFx"]                          = "True",
        ["DFIntNewRunningBaseGCMode"]                   = "1",
        ["FFlagGarbageCollectorClearWeakTables"]        = "True",
        ["DFIntPhysicsSenderRate"]                      = "30",
        ["DFIntPhysicsReceiveRate"]                     = "30",
        ["DFIntMaxInterpolationDistance"]               = "200",
        ["FFlagCoreGuiIgnoreScreenSize"]                = "True",
        ["FFlagSoundMemoryLeakFix"]                     = "True",
    }
    for flag, val in pairs(flags) do
        pcall(function() setfflag(flag, val) end)
    end
end

-- ============================================================
-- 9. LIGHTING FLATTEN
-- ============================================================
pcall(function()
    Lighting.GlobalShadows            = false
    Lighting.Brightness               = 2
    Lighting.EnvironmentDiffuseScale  = 0
    Lighting.EnvironmentSpecularScale = 0
    Lighting.OutdoorAmbient           = Color3.fromRGB(128, 128, 128)
    Lighting.Ambient                  = Color3.fromRGB(128, 128, 128)
    Lighting.ClockTime                = 14
end)

-- ============================================================
-- 10. MEMORY CLEANUP LOOP
-- ============================================================
task.spawn(function()
    while true do
        task.wait(30)
        pcall(function() collectgarbage("collect") end)
    end
end)

-- ============================================================
-- 11. WATCHER — re-apply on new character
-- ============================================================
player.CharacterAdded:Connect(function(char)
    task.wait(2)
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(player, "MaxSimulationRadius", CFG.render_distance)
        end
    end)
end)

-- ============================================================
-- BOOT
-- ============================================================
warn("[anon-perf] applied · gfx " .. CFG.graphics_level
    .. " · render " .. CFG.render_distance
    .. " · postfx " .. tostring(CFG.post_fx)
    .. " · particles " .. tostring(CFG.particles))
