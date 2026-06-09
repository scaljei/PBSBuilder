-- PBSBuilder/Core/DebugLog.lua
-- Copyable debug window + error capture
-- /pbsbd          - open window (recent log + errors)
-- /pbsbd log      - full log
-- /pbsbd errors   - errors only
-- /pbsbd clear    - clear log
-- PBSBuilderDebug.log(msg)  / PBSBuilderDebug.err(msg)  from any file

local ADDON = "PBSBuilder"
local MAX_LOG = 2000
local MAX_ERR = 500

local _log     = {}
local _errors  = {}
local _pending = {}
local _ready   = false

local function ts() return date("%H:%M:%S") end

local function appendLog(entry)
    if _ready then
        table.insert(_log, entry)
        while #_log > MAX_LOG do table.remove(_log, 1) end
    else
        table.insert(_pending, entry)
    end
end

local function dlog(msg)
    appendLog("[" .. ts() .. "] " .. tostring(msg))
end

local function derr(msg)
    local entry = "[" .. ts() .. "] ERR: " .. tostring(msg)
    appendLog(entry)
    table.insert(_errors, entry)
    while #_errors > MAX_ERR do table.remove(_errors, 1) end
end

-- Hook global error handler
local _prevEH = geterrorhandler and geterrorhandler()
if seterrorhandler then
    seterrorhandler(function(msg)
        derr(tostring(msg))
        if _prevEH then return _prevEH(msg) end
    end)
end

-- ─────────────────────────────────────────────────────────────
-- Debug window (copyable EditBox in a ScrollFrame)
-- ─────────────────────────────────────────────────────────────
local diagWin = nil

local function CreateDebugWindow()
    if diagWin then diagWin:Show() return end

    diagWin = CreateFrame("Frame", "PBSBuilderDebugWindow", UIParent, "BackdropTemplate")
    diagWin:SetSize(720, 520)
    diagWin:SetPoint("CENTER")
    diagWin:SetFrameStrata("DIALOG")
    diagWin:SetFrameLevel(600)
    diagWin:SetMovable(true)
    diagWin:SetClampedToScreen(true)
    diagWin:EnableMouse(true)
    diagWin:RegisterForDrag("LeftButton")
    diagWin:SetScript("OnDragStart", function(s) s:StartMoving() end)
    diagWin:SetScript("OnDragStop",  function(s) s:StopMovingOrSizing() end)
    if diagWin.SetBackdrop then
        diagWin:SetBackdrop({
            bgFile   = "Interface/DialogFrame/UI-DialogBox-Background",
            edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left=11, right=12, top=12, bottom=11 },
        })
        diagWin:SetBackdropColor(0.04, 0.04, 0.10, 0.97)
    end

    -- Title
    local title = diagWin:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cff55aaffPBS Builder|r  Debug Log")

    -- Close button — must be above the window background layer
    local closeBtn = CreateFrame("Button", nil, diagWin, "UIPanelCloseButton")
    closeBtn:SetFrameLevel(diagWin:GetFrameLevel() + 10)
    closeBtn:SetPoint("TOPRIGHT", diagWin, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() diagWin:Hide() end)

    -- Toolbar: Clear / Errors / Full Log buttons
    local clearBtn = CreateFrame("Button", nil, diagWin, "UIPanelButtonTemplate")
    clearBtn:SetSize(70, 22)
    clearBtn:SetPoint("BOTTOMLEFT", diagWin, "BOTTOMLEFT", 14, 12)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        _log    = {}
        _errors = {}
        diagWin.editBox:SetText("Log cleared.")
        dlog("=== LOG CLEARED ===")
    end)

    local errBtn = CreateFrame("Button", nil, diagWin, "UIPanelButtonTemplate")
    errBtn:SetSize(80, 22)
    errBtn:SetPoint("LEFT", clearBtn, "RIGHT", 4, 0)
    errBtn:SetText("Errors")
    errBtn:SetScript("OnClick", function()
        local lines = { "=== ERRORS (" .. #_errors .. ") ===" }
        for i = math.max(1, #_errors - 199), #_errors do
            table.insert(lines, _errors[i])
        end
        if #_errors == 0 then table.insert(lines, "(none)") end
        diagWin.editBox:SetText(table.concat(lines, "\n"))
        diagWin.editBox:SetCursorPosition(0)
    end)

    local fullBtn = CreateFrame("Button", nil, diagWin, "UIPanelButtonTemplate")
    fullBtn:SetSize(80, 22)
    fullBtn:SetPoint("LEFT", errBtn, "RIGHT", 4, 0)
    fullBtn:SetText("Full Log")
    fullBtn:SetScript("OnClick", function()
        local lines = { "=== FULL LOG (" .. #_log .. " entries) ===" }
        for i = 1, #_log do table.insert(lines, _log[i]) end
        diagWin.editBox:SetText(table.concat(lines, "\n"))
        diagWin.editBox:SetCursorPosition(0)
    end)

    -- Hint
    local hint = diagWin:CreateFontString(nil, "OVERLAY")
    hint:SetFont(STANDARD_TEXT_FONT, 10, "")
    hint:SetPoint("BOTTOMRIGHT", diagWin, "BOTTOMRIGHT", -16, 14)
    hint:SetTextColor(0.5, 0.5, 0.5)
    hint:SetText("Click inside text, Ctrl+A then Ctrl+C to copy all")

    -- Scroll + EditBox
    local scrollFrame = CreateFrame("ScrollFrame", nil, diagWin, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     diagWin, "TOPLEFT",     14, -34)
    scrollFrame:SetPoint("BOTTOMRIGHT", diagWin, "BOTTOMRIGHT", -34, 44)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
    end)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:SetFont(STANDARD_TEXT_FONT, 11, "")
    editBox:SetTextColor(0.85, 1.0, 0.85)
    editBox:SetWidth(670)
    editBox:SetHeight(1)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        diagWin:Hide()
    end)
    scrollFrame:SetScrollChild(editBox)

    diagWin.editBox = editBox
    diagWin.scrollFrame = scrollFrame
end

local function ShowDebugWindow(lines)
    CreateDebugWindow()
    diagWin.editBox:SetText(table.concat(lines, "\n"))
    diagWin.editBox:SetCursorPosition(0)
    diagWin:Show()
    diagWin:Raise()
end

local function ShowSummary()
    local lines = {
        "=== PBS Builder Debug Log ===",
        "Errors: " .. #_errors .. "   Log entries: " .. #_log,
        "",
        "=== RECENT ERRORS ===",
    }
    for i = math.max(1, #_errors - 9), #_errors do
        table.insert(lines, _errors[i])
    end
    if #_errors == 0 then table.insert(lines, "(none)") end
    table.insert(lines, "")
    table.insert(lines, "=== RECENT LOG (last 50) ===")
    for i = math.max(1, #_log - 49), #_log do
        table.insert(lines, _log[i])
    end
    table.insert(lines, "")
    table.insert(lines, "Commands: /pbsbd log | /pbsbd errors | /pbsbd clear")
    ShowDebugWindow(lines)
end

-- ─────────────────────────────────────────────────────────────
-- Initialisation event
-- ─────────────────────────────────────────────────────────────
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("VARIABLES_LOADED")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "VARIABLES_LOADED" then
        _ready = true
        for _, e in ipairs(_pending) do table.insert(_log, e) end
        _pending = {}
        dlog("=== PBSBuilder session start ===")
        self:UnregisterEvent("VARIABLES_LOADED")
    end
end)

-- ─────────────────────────────────────────────────────────────
-- Slash commands
-- ─────────────────────────────────────────────────────────────
SLASH_PBSBUILDERDEBUG1 = "/pbsbd"
SlashCmdList["PBSBUILDERDEBUG"] = function(input)
    input = input and input:lower():match("^%s*(.-)%s*$") or ""
    if input == "clear" then
        _log = {}; _errors = {}
        dlog("=== LOG CLEARED ===")
        DEFAULT_CHAT_FRAME:AddMessage("|cff55aaffPBSBuilder Debug:|r Log cleared.")
    elseif input == "errors" then
        local lines = { "=== ERRORS (" .. #_errors .. ") ===" }
        for i = math.max(1, #_errors - 199), #_errors do
            table.insert(lines, _errors[i])
        end
        if #_errors == 0 then table.insert(lines, "(none)") end
        ShowDebugWindow(lines)
    elseif input == "log" then
        local lines = { "=== FULL LOG (" .. #_log .. " entries) ===" }
        for i = 1, #_log do table.insert(lines, _log[i]) end
        ShowDebugWindow(lines)
    else
        ShowSummary()
    end
end

-- ─────────────────────────────────────────────────────────────
-- Public API  (PBSBuilderDebug.log / .err / .show)
-- ─────────────────────────────────────────────────────────────
PBSBuilderDebug = {
    log  = dlog,
    err  = derr,
    show = ShowSummary,
}

dlog("DebugLog.lua loaded")
