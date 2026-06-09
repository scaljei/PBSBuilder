-- PBSBuilder/Core/ScriptEditor.lua
-- The main script builder panel: list of ActionRows with drag-to-reorder,
-- script name input, preview pane, and Save/Load to PBS.

local B = PBSBuilder

-- ─────────────────────────────────────────────────────────────
-- ScriptEditor "class"
-- ─────────────────────────────────────────────────────────────
local ScriptEditor = {}
ScriptEditor.__index = ScriptEditor
B.ScriptEditor = ScriptEditor

function ScriptEditor:New(parent)
    local obj = setmetatable({}, ScriptEditor)
    obj.rows    = {}    -- array of ActionRow objects
    obj.rowData = {}    -- parallel array of data tables
    obj._drag   = nil

    -- Outer container
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    obj.frame = frame

    -- ── Script name bar ──────────────────────────────────────
    local nameBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    nameBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    nameBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    nameBar:SetHeight(30)
    B:ApplyBackdrop(nameBar, 0.06, 0.08, 0.18, 0.95)
    obj.nameBar = nameBar

    local nameLbl = B:CreateLabel(nameBar, "Script Name:", 11, 0.8, 0.7, 0.3)
    nameLbl:SetPoint("LEFT", nameBar, "LEFT", 8, 0)

    local nameBox = B:CreateEditBox(nameBar, 200, 22, "My Pet Script")
    nameBox:SetPoint("LEFT", nameLbl, "RIGHT", 6, 0)
    obj.nameBox = nameBox

    -- Toolbar buttons
    local saveBtn = B:CreateButton(nameBar, 80, 22, "Save to PBS", function()
        obj:SaveToPBS()
    end)
    saveBtn:SetPoint("RIGHT", nameBar, "RIGHT", -6, 0)

    local copyBtn = B:CreateButton(nameBar, 70, 22, "Copy Text", function()
        obj:CopyScript()
    end)
    copyBtn:SetPoint("RIGHT", saveBtn, "LEFT", -4, 0)

    local addRowBtn = B:CreateButton(nameBar, 80, 22, "+ Add Line", function()
        obj:AddRow({ action="ability 1", conditions={} })
    end)
    addRowBtn:SetPoint("RIGHT", copyBtn, "LEFT", -4, 0)

    local addIfBtn = B:CreateButton(nameBar, 60, 22, "+ If", function()
        obj:AddRow({ action="ability 1", conditions={}, isIfBlock=false })
        -- Add a paired endif comment placeholder
    end)
    addIfBtn:SetPoint("RIGHT", addRowBtn, "LEFT", -4, 0)

    local clearBtn = B:CreateButton(nameBar, 55, 22, "Clear", function()
        obj:ClearRows()
    end)
    clearBtn:SetPoint("RIGHT", addIfBtn, "LEFT", -4, 0)

    -- ── Scroll area for rows ─────────────────────────────────
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",  frame, "TOPLEFT",  4,  -38)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 130)
    obj.scrollFrame = scrollFrame

    -- Mousewheel scrolling (not wired by template in TWW)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local max     = self:GetVerticalScrollRange()
        local step    = 40
        self:SetVerticalScroll(math.max(0, math.min(max, current - delta * step)))
    end)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth() - 4)
    content:SetHeight(10)
    scrollFrame:SetScrollChild(content)
    obj.content = content

    -- Scroll resize on parent resize
    scrollFrame:SetScript("OnSizeChanged", function(s, w, h)
        content:SetWidth(w - 4)
        obj:LayoutRows()
    end)

    -- ── Drop indicator line ──────────────────────────────────
    local dropLine = content:CreateTexture(nil, "OVERLAY")
    dropLine:SetHeight(2)
    dropLine:SetColorTexture(1, 0.85, 0, 1)
    dropLine:Hide()
    obj.dropLine = dropLine

    -- ── Preview pane ─────────────────────────────────────────
    local previewOuter = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    previewOuter:SetPoint("TOPLEFT",  frame, "BOTTOMLEFT",  4,  124)
    previewOuter:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -4, 124)
    previewOuter:SetHeight(120)
    B:ApplyBackdrop(previewOuter, 0.04, 0.06, 0.10, 0.97)
    obj.previewOuter = previewOuter

    local previewLabel = B:CreateLabel(previewOuter, "Script Preview", 11, 0.7, 0.6, 0.2)
    previewLabel:SetPoint("TOPLEFT", previewOuter, "TOPLEFT", 6, -4)

    local previewScroll = CreateFrame("ScrollFrame", nil, previewOuter, "UIPanelScrollFrameTemplate")
    previewScroll:SetPoint("TOPLEFT",  previewOuter, "TOPLEFT", 4, -18)
    previewScroll:SetPoint("BOTTOMRIGHT", previewOuter, "BOTTOMRIGHT", -20, 4)
    previewScroll:EnableMouseWheel(true)
    previewScroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local max     = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, current - delta * 20)))
    end)

    local previewEB = CreateFrame("EditBox", nil, previewScroll)
    previewEB:SetMultiLine(true)
    previewEB:SetFontObject("ChatFontNormal")
    previewEB:SetWidth(previewScroll:GetWidth())
    previewEB:SetAutoFocus(false)
    previewEB:SetTextColor(0.5, 1, 0.5)
    previewScroll:SetScrollChild(previewEB)
    obj.previewEB = previewEB

    -- Drag ghost frame
    local ghost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    ghost:SetSize(300, B.ROW_H)
    ghost:SetFrameStrata("DIALOG")
    ghost:SetFrameLevel(500)
    ghost:Hide()
    B:ApplyBackdrop(ghost, 0.2, 0.2, 0.4, 0.7)
    local ghostLbl = ghost:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ghostLbl:SetAllPoints()
    ghostLbl:SetJustifyH("CENTER")
    obj.ghost = ghost
    obj.ghostLbl = ghostLbl

    -- OnUpdate for drag
    frame:SetScript("OnUpdate", function(s, elapsed)
        obj:UpdateDrag()
    end)

    return obj
end

-- ─────────────────────────────────────────────────────────────
-- Row management
-- ─────────────────────────────────────────────────────────────
function ScriptEditor:AddRow(data, pos)
    data = data or { action="ability 1", conditions={} }
    pos  = pos or (#self.rows + 1)
    table.insert(self.rowData, pos, data)

    local row = B.ActionRow:New(self.content, self, data, pos)
    table.insert(self.rows, pos, row)

    self:LayoutRows()
    self:OnRowChanged()
    return row
end

function ScriptEditor:RemoveRow(rowObj)
    for i, r in ipairs(self.rows) do
        if r == rowObj then
            table.remove(self.rows, i)
            table.remove(self.rowData, i)
            rowObj.frame:Hide()
            break
        end
    end
    self:LayoutRows()
    self:OnRowChanged()
end

function ScriptEditor:ClearRows()
    for _, r in ipairs(self.rows) do
        r.frame:Hide()
    end
    self.rows    = {}
    self.rowData = {}
    self:LayoutRows()
    self:OnRowChanged()
end

function ScriptEditor:LayoutRows()
    local y = 0
    local w = self.content:GetWidth()
    for i, row in ipairs(self.rows) do
        row:SetIndex(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  self.content, "TOPLEFT", 0, -y)
        row.frame:SetWidth(w)
        row:Show()
        y = y + B.ROW_H + B.ROW_PAD
    end
    self.content:SetHeight(math.max(y + 10, 10))
end

-- ─────────────────────────────────────────────────────────────
-- Drag-to-reorder
-- ─────────────────────────────────────────────────────────────
function ScriptEditor:StartDrag(rowObj)
    self._drag = {
        row      = rowObj,
        origIdx  = rowObj.index,
        targetIdx= rowObj.index,
    }
    self.ghostLbl:SetText("|cffffff00" .. (rowObj.data.action or "?") .. "|r")
    self.ghost:Show()
end

function ScriptEditor:StopDrag()
    if not self._drag then return end
    local ti = self._drag.targetIdx
    local oi = self._drag.origIdx
    if ti ~= oi then
        -- Move row in arrays
        local rowObj  = table.remove(self.rows,    oi)
        local rowData = table.remove(self.rowData, oi)
        local insertAt = ti > oi and ti or ti
        table.insert(self.rows,    insertAt, rowObj)
        table.insert(self.rowData, insertAt, rowData)
        self:LayoutRows()
        self:OnRowChanged()
    end
    self.ghost:Hide()
    self.dropLine:Hide()
    self._drag = nil
end

function ScriptEditor:UpdateDrag()
    if not self._drag then return end
    local mx, my = GetCursorPosition()
    local scale  = UIParent:GetEffectiveScale()
    mx, my = mx / scale, my / scale
    self.ghost:ClearAllPoints()
    self.ghost:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", mx + 8, my + 8)

    -- Find insertion point
    local cx, cy = self.content:GetLeft(), self.content:GetTop()
    if not cx then return end
    local relY = cy - my
    local targetIdx = math.floor(relY / (B.ROW_H + B.ROW_PAD)) + 1
    targetIdx = math.max(1, math.min(#self.rows, targetIdx))
    self._drag.targetIdx = targetIdx

    -- Show drop indicator
    self.dropLine:ClearAllPoints()
    self.dropLine:SetPoint("LEFT",  self.content, "LEFT",  0, -(targetIdx - 1) * (B.ROW_H + B.ROW_PAD))
    self.dropLine:SetPoint("RIGHT", self.content, "RIGHT", 0, -(targetIdx - 1) * (B.ROW_H + B.ROW_PAD))
    self.dropLine:Show()
end

-- ─────────────────────────────────────────────────────────────
-- Script generation
-- ─────────────────────────────────────────────────────────────
function ScriptEditor:GetScript()
    return B:RowsToScript(self.rowData)
end

function ScriptEditor:OnRowChanged()
    local txt = self:GetScript()
    self.previewEB:SetText(txt or "")
    self.previewEB:SetHeight(self.previewScroll and self.previewScroll:GetHeight() or 100)
end

-- ─────────────────────────────────────────────────────────────
-- PBS integration
-- ─────────────────────────────────────────────────────────────
function ScriptEditor:SaveToPBS()
    -- Check PBS is loaded
    if not tdBattlePetScript then
        print("|cffff4444PBSBuilder:|r Pet Battle Scripts addon is not loaded.")
        return
    end

    local scriptName = self.nameBox:GetText()
    if not scriptName or scriptName == "" or scriptName == "My Pet Script" then
        print("|cffff4444PBSBuilder:|r Please enter a script name first.")
        return
    end

    local code = self:GetScript()
    if not code or code == "" then
        print("|cffff4444PBSBuilder:|r Script is empty, nothing to save.")
        return
    end

    -- PBS uses its plugin manager to create/update scripts
    local plugin = tdBattlePetScript:GetModule("DefaultPlugin", true)
    if not plugin then
        print("|cffff4444PBSBuilder:|r Could not find PBS DefaultPlugin.")
        return
    end

    local existing = plugin:GetScript(scriptName)
    if existing then
        local ok, err = existing:SetCode(code)
        if not ok then
            print("|cffff4444PBSBuilder: Save error:|r " .. tostring(err))
        else
            print("|cff55ff55PBSBuilder:|r Updated script: " .. scriptName)
        end
    else
        local ok, err = plugin:CreateScript(scriptName)
        if ok then
            local s = plugin:GetScript(scriptName)
            if s then
                s:SetCode(code)
                print("|cff55ff55PBSBuilder:|r Created script: " .. scriptName)
            end
        else
            print("|cffff4444PBSBuilder: Create error:|r " .. tostring(err))
        end
    end
end

function ScriptEditor:CopyScript()
    local code = self:GetScript()
    if not code or code == "" then
        print("|cffff4444PBSBuilder:|r Nothing to copy.")
        return
    end
    -- WoW doesn't have clipboard API; write to an editable box
    self.previewEB:SetFocus()
    self.previewEB:HighlightText()
    print("|cff55ff55PBSBuilder:|r Script text is selected in the preview box — Ctrl+C to copy.")
end

-- ─────────────────────────────────────────────────────────────
-- Load from PBS (import existing script)
-- ─────────────────────────────────────────────────────────────
function ScriptEditor:LoadFromCode(code, name)
    self:ClearRows()
    if name then self.nameBox:SetText(name) end
    if not code or code == "" then return end

    for line in (code .. "\n"):gmatch("([^\n]*)\n") do
        line = line:match("^%s*(.-)%s*$") -- trim
        if line ~= "" then
            local action, condPart = line:match("^(.-)%s*%[(.+)%]%s*$")
            if not action then
                action = line
                condPart = nil
            end
            action = action:match("^%s*(.-)%s*$")

            local conditions = {}
            if condPart then
                for cond in condPart:gmatch("[^&]+") do
                    cond = cond:match("^%s*(.-)%s*$")
                    if cond ~= "" then
                        table.insert(conditions, cond)
                    end
                end
            end

            self:AddRow({ action=action, conditions=conditions })
        end
    end
end
