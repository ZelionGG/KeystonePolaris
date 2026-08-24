local _, KeystonePolaris = ...

-- MDT 6.2 no longer sets _G.MDT. Dungeon data lives on the load-on-demand UI
-- addon table, which uses setmetatable(MDT, { __index = MythicDungeonToolsAPI }).
-- DungeonSelect.lua calls MDT:IsRetail() during LoadAddOn; that lookup hits
-- API.IsRetail and passes the UI table as self. Capture it here.

local MDT_CORE_ADDON = "MythicDungeonTools"
local MDT_UI_ADDON = "MythicDungeonTools_UI"

local isRetailHooked = false
local capturedMDT

local function IsMDTDataTable(mdt)
    return type(mdt) == "table" and type(mdt.dungeonEnemies) == "table"
end

local function CaptureMDTFromIsRetail(self)
    if self == _G.MythicDungeonToolsAPI then return end
    if IsMDTDataTable(self) then
        capturedMDT = self
    end
end

local function HookMDTAPI()
    if isRetailHooked then return end
    local api = _G.MythicDungeonToolsAPI
    if type(api) ~= "table" or type(api.IsRetail) ~= "function" then return end
    isRetailHooked = true
    hooksecurefunc(api, "IsRetail", CaptureMDTFromIsRetail)
end

function KeystonePolaris.GetMDT()
    if IsMDTDataTable(capturedMDT) then
        return capturedMDT
    end
    local legacy = _G.MDT or _G.MethodDungeonTools
    if IsMDTDataTable(legacy) then
        return legacy
    end
    return nil
end

function KeystonePolaris.EnsureMDTUILoaded()
    HookMDTAPI()
    if IsMDTDataTable(KeystonePolaris.GetMDT()) then
        return true
    end
    C_AddOns.LoadAddOn(MDT_UI_ADDON)
    return IsMDTDataTable(KeystonePolaris.GetMDT())
end

HookMDTAPI()

if not isRetailHooked then
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function(self, _, addonName)
        if addonName ~= MDT_CORE_ADDON then return end
        HookMDTAPI()
        self:UnregisterEvent("ADDON_LOADED")
    end)
end
