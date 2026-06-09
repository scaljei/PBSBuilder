-- PBSBuilder/Core/ActionRow.lua
-- A single draggable row in the script editor
-- Each row = one PBS line: action  [ cond1 & cond2 ]

local B = PBSBuilder

local ROW_H   = 36
local ROW_PAD = 3

-- ─────────────────────────────────────────────────────────────
-- ActionRow "class"
-- ─────────────────────────────────────────────────────────────
local ActionRow = {}
ActionRow.__index = ActionRow

function ActionRow:New(parent, editor, rowData, index)
    local obj = setmetatable({}, ActionRow)
    obj.editor  = editor
    obj.data    = rowData   -- { action, conditions={}, isIfBlock, children }
    obj.index   = index

    -- Root frame
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(parent:GetWidth() - 8, ROW_H)
    B:ApplyBackdrop(frame, 0.10, 0.14, 0.22, 0.95)
    obj.frame = frame

    -- Drag handle (left strip)
    local handle = CreateFrame("Button", nil, frame)
    handle:SetSize(14, ROW_H)
    handle:SetPoint("LEFT", frame, "LEFT", 0, 0)
    handle:SetNormalTexture("Interface/Buttons/UI-MicroStream-Yellow")
    handle:GetNormalTexture():SetVertexColor(0.5, 0.5, 0.7)
    handle:SetScript("OnEnter", function(s)
        s:GetNormalTexture():SetVertexColor(1, 0.8, 0)
        frame:SetCursor("Interface/cursor/moveframe")
    end)
    handle:SetScript("OnLeave", function(s)
        s:GetNormalTexture():SetVertexColor(0.5, 0.5, 0.7)
    end)
    -- Drag events handled by editor (see ScriptEditor drag logic)
    handle:SetScript("OnMouseDown", function(s, btn)
        if btn == "LeftButton" then
            editor:StartDrag(obj)
        end
    end)
    handle:SetScript("OnMouseUp", function(s)
        editor:StopDrag()
    end)
    obj.handle = handle

    -- Row index number
    local numLbl = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    numLbl:SetPoint("LEFT", handle, "RIGHT", 2, 0)
    numLbl:SetWidth(18)
    numLbl:SetJustifyH("RIGHT")
    numLbl:SetTextColor(0.5, 0.5, 0.6)
    obj.numLbl = numLbl

    -- Action dropdown (left side)
    local actionItems = {}
    for _, a in ipairs(B.ACTIONS) do
        table.insert(actionItems, { label=a.label, value=a.id })
    end
    local actionDrop = B:CreateDropdown(frame, 150, 24, actionItems, function(val, lbl)
        rowData.action = val
        -- Show/hide extra arg box for test/comment
        obj:UpdateArgVisibility()
        editor:OnRowChanged()
    end)
    actionDrop:SetPoint("LEFT", numLbl, "RIGHT", 4, 0)
    if rowData.action then actionDrop:SetValue(rowData.action) end
    obj.actionDrop = actionDrop

    -- Extra arg box (for "test" / "--" actions)
    local argBox = B:CreateEditBox(frame, 100, 22, "message...")
    argBox:SetPoint("LEFT", actionDrop, "RIGHT", 4, 0)
    argBox:Hide()
    argBox:SetScript("OnTextChanged", function(s)
        local txt = s:GetText()
        if txt ~= (s._placeholder or "") then
            -- Reconstruct action with arg embedded
            local base = rowData.action and rowData.action:match("^([^ ]+)") or ""
            rowData.action = base .. " " .. txt
            editor:OnRowChanged()
        end
    end)
    obj.argBox = argBox

    -- Conditions area (right side)
    local condFrame = CreateFrame("Frame", nil, frame)
    condFrame:SetPoint("LEFT", actionDrop, "RIGHT", 4, 0)
    condFrame:SetPoint("RIGHT", frame, "RIGHT", -62, 0)
    condFrame:SetHeight(ROW_H)
    obj.condFrame = condFrame

    obj.condButtons = {}
    obj:RebuildCondButtons()

    -- "+" condition button
    local addCondBtn = CreateFrame("Button", nil, frame)
    addCondBtn:SetSize(22, 22)
    addCondBtn:SetPoint("RIGHT", frame, "RIGHT", -38, 0)
    local addCondTex = addCondBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addCondTex:SetAllPoints()
    addCondTex:SetText("|cff55ff55[+]|r")
    addCondBtn:SetScript("OnClick", function()
        B:OpenConditionPicker(nil, function(condStr)
            rowData.conditions = rowData.conditions or {}
            table.insert(rowData.conditions, condStr)
            obj:RebuildCondButtons()
            editor:OnRowChanged()
        end)
    end)
    addCondBtn:SetScript("OnEnter", function() addCondTex:SetText("|cffffff00[+]|r") end)
    addCondBtn:SetScript("OnLeave", function() addCondTex:SetText("|cff55ff55[+]|r") end)
    obj.addCondBtn = addCondBtn

    -- Delete row button (×)
    local delBtn = CreateFrame("Button", nil, frame)
    delBtn:SetSize(20, 20)
    delBtn:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    local delTex = delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    delTex:SetAllPoints()
    delTex:SetText("|cffff4444×|r")
    delBtn:SetScript("OnClick", function()
        editor:RemoveRow(obj)
    end)
    delBtn:SetScript("OnEnter", function() delTex:SetText("|cffff0000×|r") end)
    delBtn:SetScript("OnLeave", function() delTex:SetText("|cffff4444×|r") end)
    obj.delBtn = delBtn

    obj:SetIndex(index)
    obj:UpdateArgVisibility()
    return obj
end

function ActionRow:SetIndex(i)
    self.index = i
    self.numLbl:SetText(i)
end

function ActionRow:UpdateArgVisibility()
    local action = self.data.action or ""
    local base = action:match("^([^ ]+)") or action
    local def = B:GetActionDef(base)
    if def and def.hasArg then
        self.argBox:Show()
        self.condFrame:Hide()
        self.addCondBtn:Hide()
    else
        self.argBox:Hide()
        self.condFrame:Show()
        self.addCondBtn:Show()
    end
end

function ActionRow:RebuildCondButtons()
    -- Clear existing
    for _, btn in ipairs(self.condButtons) do
        btn:Hide()
    end
    self.condButtons = {}

    local conditions = self.data.conditions or {}
    local x = 0
    for i, condStr in ipairs(conditions) do
        local btn = CreateFrame("Button", nil, self.condFrame, "BackdropTemplate")
        btn:SetHeight(22)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", btn, "LEFT", 4, 0)
        fs:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
        fs:SetText("|cff88ddff" .. condStr .. "|r")
        fs:SetJustifyH("LEFT")
        btn:SetWidth(math.max(60, fs:GetStringWidth() + 20))
        B:ApplyBackdrop(btn, 0.05, 0.12, 0.22, 0.9)
        btn:SetPoint("LEFT", self.condFrame, "LEFT", x, 0)
        x = x + btn:GetWidth() + 3

        -- Right click to remove
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local ci = i -- capture
        btn:SetScript("OnClick", function(s, mouseBtn)
            if mouseBtn == "RightButton" then
                table.remove(self.data.conditions, ci)
                self:RebuildCondButtons()
                self.editor:OnRowChanged()
            else
                -- Left click: edit this condition
                B:OpenConditionPicker(condStr, function(newStr)
                    self.data.conditions[ci] = newStr
                    self:RebuildCondButtons()
                    self.editor:OnRowChanged()
                end)
            end
        end)
        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(btn, "ANCHOR_TOP")
            GameTooltip:AddLine(condStr, 1,1,1)
            GameTooltip:AddLine("|cffaaaaaaleft-click to edit, right-click to remove|r", 0.7,0.7,0.7)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        table.insert(self.condButtons, btn)
    end
end

function ActionRow:Show() self.frame:Show() end
function ActionRow:Hide() self.frame:Hide() end
function ActionRow:SetPoint(...) self.frame:SetPoint(...) end
function ActionRow:ClearAllPoints() self.frame:ClearAllPoints() end
function ActionRow:GetHeight() return ROW_H end

B.ActionRow = ActionRow
B.ROW_H     = ROW_H
B.ROW_PAD   = ROW_PAD
