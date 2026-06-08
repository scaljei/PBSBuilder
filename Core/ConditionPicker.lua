-- PBSBuilder/Core/ConditionPicker.lua
-- Modal popup for building a single PBS condition string
-- Calls back: onDone(conditionString)

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
    -- Format: owner.pet.condId op value arg
    -- PBS syntax:  ally.1.hp >= 500
    --              ally.dead
    --              ally.1.ability.usable 1
    local def = B:GetConditionDef(condId)
    if not def then return nil end

    local parts = {}

    -- owner prefix
    if def.needOwner == true or def.needOwner == "optional" then
        if owner and owner ~= "" then
            table.insert(parts, owner)
        end
    end

    -- pet slot
    if def.needPet ~= false and def.needPet ~= nil then
        if pet and pet ~= "" then
            table.insert(parts, pet)
        end
    end

    -- condition id
    table.insert(parts, condId)

    -- build the prefix
    local prefix = table.concat(parts, ".")

    -- arg (aura name, ability slot, weather)
    local argStr = ""
    if def.needArg ~= false and arg and arg ~= "" and arg ~= (def.argHint or "") then
        argStr = " " .. arg
    end

    -- operator + value
    local valStr = ""
    if def.type == "boolean" then
        if op and op == "!" then
            valStr = " !"
        end
        return prefix .. argStr .. valStr
    else
        -- compare / equality
        if op and op ~= "" then
            valStr = " " .. op
        end
        if valArg and valArg ~= "" then
            valStr = valStr .. " " .. valArg
        end
        return prefix .. argStr .. valStr
    end
end

function B:OpenConditionPicker(existing, onDone)
    if not picker then
        picker = CreateFrame("Frame", "PBSBuilderConditionPicker", UIParent, "BackdropTemplate")
        picker:SetSize(420, 300)
        picker:SetPoint("CENTER")
        picker:SetFrameStrata("DIALOG")
        picker:SetFrameLevel(300)
        picker:EnableMouse(true)
        picker:SetMovable(true)
        picker:RegisterForDrag("LeftButton")
        picker:SetScript("OnDragStart", function(s) s:StartMoving() end)
        picker:SetScript("OnDragStop",  function(s) s:StopMovingOrSizing() end)
        B:ApplyBackdrop(picker, 0.04, 0.04, 0.12, 0.97)

        -- Title
        local title = B:CreateLabel(picker, "Build Condition", 13, 0.9, 0.75, 0.2)
        title:SetPoint("TOPLEFT", picker, "TOPLEFT", 10, -10)
        picker._title = title

        -- X close
        local closeBtn = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -2, -2)
        closeBtn:SetScript("OnClick", function() picker:Hide() end)

        local ROW_Y = -40
        local LABEL_W = 80
        local CTRL_W  = 200
        local CTRL_H  = 22
        local GAP     = 8

        local function MakeRow(label, yOff)
            local lbl = B:CreateLabel(picker, label, 11, 0.7, 0.7, 0.9)
            lbl:SetPoint("TOPLEFT", picker, "TOPLEFT", 10, yOff)
            lbl:SetWidth(LABEL_W)
            lbl:SetJustifyH("RIGHT")
            return lbl
        end

        -- Condition selector (scrollable list on left, info on right)
        -- Simple dropdown for condition
        MakeRow("Condition:", ROW_Y)
        local condItems = {}
        for _, c in ipairs(B.CONDITIONS) do
            table.insert(condItems, { label=c.label, value=c.id })
        end
        local condDrop = B:CreateDropdown(picker, CTRL_W, CTRL_H, condItems, nil)
        condDrop:SetPoint("TOPLEFT", picker, "TOPLEFT", LABEL_W + 18, ROW_Y)
        picker._condDrop = condDrop

        MakeRow("Owner:", ROW_Y - (CTRL_H + GAP))
        local ownerDrop = B:CreateDropdown(picker, CTRL_W, CTRL_H, OwnerItems(), nil)
        ownerDrop:SetPoint("TOPLEFT", picker, "TOPLEFT", LABEL_W + 18, ROW_Y - (CTRL_H + GAP))
        picker._ownerDrop = ownerDrop

        MakeRow("Pet Slot:", ROW_Y - (CTRL_H + GAP)*2)
        local petDrop = B:CreateDropdown(picker, CTRL_W, CTRL_H, PetSlotItems(), nil)
        petDrop:SetPoint("TOPLEFT", picker, "TOPLEFT", LABEL_W + 18, ROW_Y - (CTRL_H + GAP)*2)
        picker._petDrop = petDrop

        MakeRow("Arg/Name:", ROW_Y - (CTRL_H + GAP)*3)
        local argBox = B:CreateEditBox(picker, CTRL_W, CTRL_H, "e.g. 1  or  Burning Aura")
        argBox:SetPoint("TOPLEFT", picker, "TOPLEFT", LABEL_W + 18, ROW_Y - (CTRL_H + GAP)*3)
        picker._argBox = argBox

        MakeRow("Operator:", ROW_Y - (CTRL_H + GAP)*4)
        local opDrop = B:CreateDropdown(picker, 80, CTRL_H, OpItems("compare"), nil)
        opDrop:SetPoint("TOPLEFT", picker, "TOPLEFT", LABEL_W + 18, ROW_Y - (CTRL_H + GAP)*4)
        picker._opDrop = opDrop

        MakeRow("Value:", ROW_Y - (CTRL_H + GAP)*4)
        local valBox = B:CreateEditBox(picker, 100, CTRL_H, "50")
        valBox:SetPoint("TOPLEFT", opDrop, "TOPRIGHT", 8, 0)
        picker._valBox = valBox

        -- Preview
        local previewLbl = B:CreateLabel(picker, "Preview:", 11, 0.7, 0.7, 0.9)
        previewLbl:SetPoint("TOPLEFT", picker, "TOPLEFT", 10, ROW_Y - (CTRL_H + GAP)*5)
        local previewText = B:CreateLabel(picker, "", 11, 0.3, 1, 0.4)
        previewText:SetPoint("TOPLEFT", picker, "TOPLEFT", LABEL_W + 18, ROW_Y - (CTRL_H + GAP)*5)
        previewText:SetWidth(280)
        previewText:SetJustifyH("LEFT")
        picker._previewText = previewText

        -- Add / Cancel buttons
        local addBtn = B:CreateButton(picker, 90, 26, "Add", function()
            local cid   = picker._condDrop:GetValue()
            local owner = picker._ownerDrop:GetValue()
            local pet   = picker._petDrop:GetValue()
            local arg   = picker._argBox:GetText()
            local op    = picker._opDrop:GetValue()
            local val   = picker._valBox:GetText()
            local condStr = BuildConditionString(owner, pet, cid, op, arg, val)
            if condStr and picker._onDone then
                picker._onDone(condStr)
            end
            picker:Hide()
        end)
        addBtn:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -40, 10)

        local cancelBtn = B:CreateButton(picker, 70, 26, "Cancel", function()
            picker:Hide()
        end)
        cancelBtn:SetPoint("RIGHT", addBtn, "LEFT", -6, 0)

        -- Live preview update
        local function UpdatePreview()
            local cid   = picker._condDrop:GetValue()
            local owner = picker._ownerDrop:GetValue()
            local pet   = picker._petDrop:GetValue()
            local arg   = picker._argBox:GetText()
            local op    = picker._opDrop:GetValue()
            local val   = picker._valBox:GetText()
            local s = BuildConditionString(owner, pet, cid, op, arg, val) or ""
            picker._previewText:SetText("|cff55ff55" .. s .. "|r")

            -- Update op choices based on condition type
            local def = B:GetConditionDef(cid)
            if def then
                local newOps = OpItems(def.type)
                picker._opDrop:SetItems(newOps)
            end
        end

        -- Wire up change events
        condDrop:SetScript("OnMouseDown", function(self, ...)
            if condDrop.orig_OnMouseDown then condDrop.orig_OnMouseDown(self, ...) end
            C_Timer.After(0.05, UpdatePreview)
        end)
        -- Patch all dropdowns to call UpdatePreview after selection
        -- We do this by wrapping after each SetItems call in practice;
        -- simpler: poll with OnUpdate every 0.2s when picker is shown
        picker._previewTimer = 0
        picker:SetScript("OnUpdate", function(self, elapsed)
            self._previewTimer = (self._previewTimer or 0) + elapsed
            if self._previewTimer >= 0.15 then
                self._previewTimer = 0
                UpdatePreview()
            end
        end)
    end

    picker._onDone = onDone
    picker:Show()
    picker:Raise()
end
