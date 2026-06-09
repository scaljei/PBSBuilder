-- PBSBuilder/Core/PBSBuilder.lua
-- Main addon frame: initialisation, main window, slash commands

local B = PBSBuilder
local ADDON_NAME = "PBSBuilder"

-- ─────────────────────────────────────────────────────────────
-- Main window
-- ─────────────────────────────────────────────────────────────
local mainFrame

local function BuildMainFrame()
    if mainFrame then return mainFrame end

    mainFrame = CreateFrame("Frame", "PBSBuilderMainFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(700, 580)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetMovable(true)
    mainFrame:SetResizable(true)
    mainFrame:SetResizeBounds(560, 420, 1100, 900)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(s) s:StartMoving() end)
    mainFrame:SetScript("OnDragStop",  function(s) s:StopMovingOrSizing() end)
    -- Close any open dropdown when clicking on the window background
    mainFrame:SetScript("OnMouseDown", function(s, btn)
        if B._closeOpenDropdown then B._closeOpenDropdown() end
        if btn == "LeftButton" then s:StartMoving() end
    end)
    mainFrame:SetScript("OnMouseUp", function(s) s:StopMovingOrSizing() end)
    mainFrame:SetClampedToScreen(true)
    mainFrame:Hide()

    B:ApplyBackdrop(mainFrame, 0.04, 0.05, 0.12, 0.97)

    -- ── Title bar ────────────────────────────────────────────
    local titleBar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  0, 0)
    titleBar:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(28)
    B:ApplyBackdrop(titleBar, 0.08, 0.06, 0.20, 0.98)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleText:SetText("|cff55aaff🐾 PBS Builder|r  |cff777777— Pet Battle Script Visual Editor|r")

    local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)

    -- ── Left panel: script list ───────────────────────────────
    local leftPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    leftPanel:SetPoint("TOPLEFT",    mainFrame, "TOPLEFT",  4, -32)
    leftPanel:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 4, 4)
    leftPanel:SetWidth(155)
    B:ApplyBackdrop(leftPanel, 0.05, 0.06, 0.16, 0.95)

    local listLabel = B:CreateLabel(leftPanel, "PBS Scripts", 12, 0.7, 0.55, 0.2)
    listLabel:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 6, -6)

    local refreshBtn = B:CreateButton(leftPanel, 50, 20, "↺ Sync", nil)
    refreshBtn:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -4, -4)

    -- Script list scroll
    local listScroll = CreateFrame("ScrollFrame", nil, leftPanel, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT",  leftPanel, "TOPLEFT", 4, -30)
    listScroll:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -20, 26)

    -- Mousewheel scrolling
    listScroll:EnableMouseWheel(true)
    listScroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local max     = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, current - delta * 26)))
    end)

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetWidth(listScroll:GetWidth())
    listContent:SetHeight(10)
    listScroll:SetScrollChild(listContent)

    local newScriptBtn = B:CreateButton(leftPanel, 143, 22, "+ New Script", nil)
    newScriptBtn:SetPoint("BOTTOMLEFT", leftPanel, "BOTTOMLEFT", 4, 4)

    -- ── Right panel: editor ───────────────────────────────────
    local editorPanel = CreateFrame("Frame", nil, mainFrame)
    editorPanel:SetPoint("TOPLEFT",     leftPanel, "TOPRIGHT",      4, 0)
    editorPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -4, 4)

    local editor = B.ScriptEditor:New(editorPanel)

    -- ── Script list logic ─────────────────────────────────────
    local listRows = {}

    local function ClearList()
        for _, r in ipairs(listRows) do r:Hide() end
        listRows = {}
    end

    local function AddListRow(name, plugin, scriptObj, yOff)
        local row = CreateFrame("Button", nil, listContent, "BackdropTemplate")
        row:SetSize(listContent:GetWidth(), 24)
        row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -yOff)
        B:ApplyBackdrop(row, 0.08, 0.10, 0.22, 0.9)

        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", row, "LEFT", 6, 0)
        fs:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        fs:SetText(name)
        fs:SetJustifyH("LEFT")

        row:SetScript("OnEnter", function()
            B:ApplyBackdrop(row, 0.15, 0.20, 0.40, 0.95)
        end)
        row:SetScript("OnLeave", function()
            B:ApplyBackdrop(row, 0.08, 0.10, 0.22, 0.9)
        end)
        row:SetScript("OnClick", function()
            if scriptObj then
                editor:LoadFromCode(scriptObj:GetCode(), name)
            end
            -- Highlight selection
            for _, r in ipairs(listRows) do
                B:ApplyBackdrop(r, 0.08, 0.10, 0.22, 0.9)
            end
            B:ApplyBackdrop(row, 0.10, 0.28, 0.50, 0.95)
        end)

        table.insert(listRows, row)
        return row
    end

    local function RefreshScriptList()
        ClearList()
        local y = 0
        if tdBattlePetScript then
            for pluginName, plugin in tdBattlePetScript:IterateEnabledPlugins() do
                if plugin.IterateScripts then
                    for key, scriptObj in plugin:IterateScripts() do
                        AddListRow(scriptObj:GetName() or key, plugin, scriptObj, y)
                        y = y + 26
                    end
                end
            end
        end
        listContent:SetHeight(math.max(y + 4, 10))
    end

    refreshBtn:SetScript("OnClick", RefreshScriptList)

    newScriptBtn:SetScript("OnClick", function()
        editor:ClearRows()
        editor.nameBox:SetText("New Script " .. date("%H:%M:%S"))
        editor:AddRow({ action="ability 1", conditions={} })
    end)

    -- Resize grip
    local resizeGrip = CreateFrame("Button", nil, mainFrame)
    resizeGrip:SetSize(14, 14)
    resizeGrip:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -2, 2)
    resizeGrip:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Over")
    resizeGrip:SetScript("OnMouseDown", function(s, btn)
        if btn == "LeftButton" then mainFrame:StartSizing("BOTTOMRIGHT") end
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        mainFrame:StopMovingOrSizing()
    end)

    -- On show: refresh list
    mainFrame:SetScript("OnShow", RefreshScriptList)

    B.mainFrame  = mainFrame
    B.editor     = editor
    return mainFrame
end

-- ─────────────────────────────────────────────────────────────
-- Minimap button
-- ─────────────────────────────────────────────────────────────
local minimapBtn

local function CreateMinimapButton()
    if minimapBtn then return end

    minimapBtn = CreateFrame("Button", "PBSBuilderMinimapBtn", Minimap)
    minimapBtn:SetSize(32, 32)
    minimapBtn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 10, -10)
    minimapBtn:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    minimapBtn:SetFrameStrata("MEDIUM")

    minimapBtn:SetNormalTexture("Interface/Icons/Achievement_PetBattle_WinPVP")
    minimapBtn:GetNormalTexture():SetTexCoord(0.07, 0.93, 0.07, 0.93)

    minimapBtn:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight", "ADD")

    local ring = minimapBtn:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface/Minimap/MiniMap-TrackingBorder")
    ring:SetSize(56, 56)
    ring:SetPoint("CENTER")

    minimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapBtn:SetScript("OnClick", function(s, btn)
        local mf = BuildMainFrame()
        if mf:IsShown() then
            mf:Hide()
        else
            mf:Show()
        end
    end)
    minimapBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(minimapBtn, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cffffff00PBS Builder|r")
        GameTooltip:AddLine("Click to open the Pet Battle Script builder.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    minimapBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- ─────────────────────────────────────────────────────────────
-- Initialisation
-- ─────────────────────────────────────────────────────────────
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        PBSBuilderDB = PBSBuilderDB or {}

        CreateMinimapButton()
        PBSBuilderDebug.log("Addon loaded OK. PBS present: " .. tostring(tdBattlePetScript ~= nil))
        print("|cff55aaff[PBS Builder]|r loaded — |cff55ff55/pbsb|r to open, |cff55ff55/pbsbd|r for debug log.")
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- ─────────────────────────────────────────────────────────────
-- Slash commands
-- ─────────────────────────────────────────────────────────────
SLASH_PBSBUILDER1 = "/pbsb"
SLASH_PBSBUILDER2 = "/pbsbuilder"
SlashCmdList["PBSBUILDER"] = function(msg)
    msg = msg and msg:lower():trim() or ""
    local mf = BuildMainFrame()
    if msg == "hide" then
        mf:Hide()
    elseif msg == "new" then
        mf:Show()
        B.editor:ClearRows()
        B.editor.nameBox:SetText("New Script")
        B.editor:AddRow({ action="ability 1", conditions={} })
    elseif msg == "demo" then
        mf:Show()
        B.editor:ClearRows()
        B.editor.nameBox:SetText("Demo: Basic Attacker")
        B.editor:LoadFromCode(
            "ability 1 [ ally.dead ]\n" ..
            "ability 2 [ ally.1.ability.usable 2 & enemy.hpp <= 50 ]\n" ..
            "ability 3 [ ally.1.hpp < 30 ]\n" ..
            "ability 1",
            "Demo: Basic Attacker"
        )
    else
        if mf:IsShown() then mf:Hide() else mf:Show() end
    end
end
