-- PBSBuilder/Core/ConditionPicker.lua
-- Modal popup for building a single PBS condition string
-- Fixes: #4 condition dropdown empty, #5 operator/value label overlap

local B = PBSBuilder

local picker -- singleton

local function OwnerItems()
    return {
        { label="Ally",  value="ally"  },
        { label="Enemy", value="enemy" },
    }
end

local function PetSlotItems()
    return {
        { label="Active (no slot)", value="" },
        { label="Slot 1",           value="1" },
        { label="Slot 2",           value="2" },
        { label="Slot 3",           value="3" },
    }
end

local function OpItems(condType)
    local ops
    if condType == "compare" then
        ops = B.COMPARE_OPS
    elseif condType == "equality" then
        ops = B.EQUALITY_OPS
    else
        ops = B.BOOLEAN_OPS
    end
    local t = {}
    for _, op in ipairs(ops) do
        table.insert(t, { label=op, value=op })
    end
    return t
end

local function BuildConditionString(owner, pet, condId, op, arg, valArg)
    local def = B:GetConditionDef(condId)
    if not def then return nil end

    local parts = {}
    if def.needOwner == true or def.needOwner == "optional" then
        if owner and owner ~= "" then table.insert(parts, owner) end
    end
    if def.needPet ~= false and def.needPet ~= nil then
        if pet and pet ~= "" then table.insert(parts, pet) end
    end
    table.insert(parts, condId)
    local prefix = table.concat(parts, ".")

    local argStr = ""
    if def.needArg ~= false and arg and arg ~= "" and arg ~= (def.argHint or "") then
        argStr = " " .. arg
    end

    if def.type == "boolean" then
        local neg = (op == "!") and " !" or ""
        return prefix .. argStr .. neg
    else
        local valStr = ""
        if op and op ~= "" then valStr = " " .. op end
        if valArg and valArg ~= "" and valArg ~= "0" then
            valStr = valStr .. " " .. valArg
        end
        return prefix .. argStr .. valStr
    end
end

-- ─────────────────────────────────────────────────────────────
-- Build the singleton picker frame once
-- ─────────────────────────────────────────────────────────────
local function EnsurePicker()
    if picker then return end

    picker = CreateFrame("Frame", "PBSBuilderConditionPicker", UIParent, "BackdropTemplate")
    picker:SetSize(440, 310)
    picker:SetPoint("CENTER")
    picker:SetFrameStrata("DIALOG")
    picker:SetFrameLevel(300)
    picker:EnableMouse(true)
    picker:SetMovable(true)
    picker:RegisterForDrag("LeftButton")
    picker:SetScript("OnDragStart", function(s) s:StartMoving() end)
    picker:SetScript("OnDragStop",  function(s) s:StopMovingOrSizing() end)
    picker:SetClampedToScreen(true)
    B:ApplyBackdrop(picker, 0.04, 0.04, 0.12, 0.97)

    local title = B:CreateLabel(picker, "Build Condition", 13, 0.9, 0.75, 0.2)
    title:SetPoint("TOPLEFT", picker, "TOPLEFT", 10, -10)

    local closeBtn = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() picker:Hide() end)

    -- Layout constants
    local LX      = 10      -- label left edge
    local LABEL_W = 82
    local CX      = LX + LABEL_W + 8   -- control left edge
    local CTRL_W  = 220
    local RH      = 26      -- row height (control + gap)
    local CH      = 22      -- control height

    local function RowY(n) return -(36 + n * RH) end  -- n=0 is first row

    local function MakeLabel(text, row)
        local lbl = B:CreateLabel(picker, text, 11, 0.7, 0.7, 0.9)
        lbl:SetPoint("TOPLEFT", picker, "TOPLEFT", LX, RowY(row))
        lbl:SetWidth(LABEL_W)
        lbl:SetJustifyH("RIGHT")
        return lbl
    end

    -- Row 0: Condition
    MakeLabel("Condition:", 0)
    -- condItems built fresh each open — stored as builder function
    local condDrop = B:CreateDropdown(picker, CTRL_W, CH, {}, nil)
    condDrop:SetPoint("TOPLEFT", picker, "TOPLEFT", CX, RowY(0))
    picker._condDrop = condDrop

    -- Row 1: Owner
    MakeLabel("Owner:", 1)
    local ownerDrop = B:CreateDropdown(picker, CTRL_W, CH, OwnerItems(), nil)
    ownerDrop:SetPoint("TOPLEFT", picker, "TOPLEFT", CX, RowY(1))
    picker._ownerDrop = ownerDrop

    -- Row 2: Pet Slot
    MakeLabel("Pet Slot:", 2)
    local petDrop = B:CreateDropdown(picker, CTRL_W, CH, PetSlotItems(), nil)
    petDrop:SetPoint("TOPLEFT", picker, "TOPLEFT", CX, RowY(2))
    picker._petDrop = petDrop

    -- Row 3: Arg / Name
    MakeLabel("Arg/Name:", 3)
    local argBox = B:CreateEditBox(picker, CTRL_W, CH, "e.g. 1  or  Burning Aura")
    argBox:SetPoint("TOPLEFT", picker, "TOPLEFT", CX, RowY(3))
    picker._argBox = argBox

    -- Row 4: Operator  [dropdown 80px]  Value [editbox 100px]   — single row, no overlap
    MakeLabel("Op / Value:", 4)
    local opDrop = B:CreateDropdown(picker, 80, CH, OpItems("compare"), nil)
    opDrop:SetPoint("TOPLEFT", picker, "TOPLEFT", CX, RowY(4))
    picker._opDrop = opDrop

    local valBox = B:CreateEditBox(picker, 110, CH, "0")
    valBox:SetPoint("TOPLEFT", opDrop, "TOPRIGHT", 8, 0)
    picker._valBox = valBox

    -- Row 5: Preview
    MakeLabel("Preview:", 5)
    local previewText = B:CreateLabel(picker, "", 11, 0.3, 1, 0.4)
    previewText:SetPoint("TOPLEFT", picker, "TOPLEFT", CX, RowY(5))
    previewText:SetWidth(300)
    previewText:SetJustifyH("LEFT")
    picker._previewText = previewText

    -- Buttons
    local addBtn = B:CreateButton(picker, 90, 26, "Add", function()
        local condStr = BuildConditionString(
            picker._ownerDrop:GetValue(),
            picker._petDrop:GetValue(),
            picker._condDrop:GetValue(),
            picker._opDrop:GetValue(),
            picker._argBox:GetText(),
            picker._valBox:GetText()
        )
        if condStr and picker._onDone then picker._onDone(condStr) end
        picker:Hide()
    end)
    addBtn:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -10, 8)

    local cancelBtn = B:CreateButton(picker, 70, 26, "Cancel", function()
        picker:Hide()
    end)
    cancelBtn:SetPoint("RIGHT", addBtn, "LEFT", -6, 0)

    -- Live preview + operator refresh (polling — works for all controls)
    local function UpdatePreview()
        local cid = picker._condDrop:GetValue()
        local s   = BuildConditionString(
            picker._ownerDrop:GetValue(),
            picker._petDrop:GetValue(),
            cid,
            picker._opDrop:GetValue(),
            picker._argBox:GetText(),
            picker._valBox:GetText()
        ) or ""
        picker._previewText:SetText("|cff55ff55" .. s .. "|r")

        -- Refresh op list to match condition type
        local def = B:GetConditionDef(cid)
        if def then picker._opDrop:SetItems(OpItems(def.type)) end
    end

    picker._previewTimer = 0
    picker:SetScript("OnUpdate", function(self, elapsed)
        self._previewTimer = self._previewTimer + elapsed
        if self._previewTimer >= 0.12 then
            self._previewTimer = 0
            UpdatePreview()
        end
    end)
end

-- ─────────────────────────────────────────────────────────────
-- Public entry point
-- ─────────────────────────────────────────────────────────────
function B:OpenConditionPicker(existing, onDone)
    EnsurePicker()

    -- Rebuild condition items fresh every open so they are never empty
    local condItems = {}
    for _, c in ipairs(B.CONDITIONS) do
        table.insert(condItems, { label=c.label, value=c.id })
    end
    picker._condDrop:SetItems(condItems)

    picker._onDone       = onDone
    picker._previewTimer = 0
    picker:Show()
    picker:Raise()
end
