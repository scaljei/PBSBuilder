-- PBSBuilder/Core/Utils.lua
-- Small helpers used throughout the addon

local B = PBSBuilder

-- Find a condition definition by its id
function B:GetConditionDef(id)
    for _, c in ipairs(self.CONDITIONS) do
        if c.id == id then return c end
    end
    return nil
end

-- Find an action definition by its id
function B:GetActionDef(id)
    for _, a in ipairs(self.ACTIONS) do
        if a.id == id then return a end
    end
    return nil
end

-- Build the PBS text line for a single action row table
--   row = { action=string, conditions={string,...} }
function B:RowToLine(row)
    if not row or not row.action or row.action == "" then return nil end

    local action = row.action
    if row.conditions and #row.conditions > 0 then
        local parts = {}
        for _, c in ipairs(row.conditions) do
            if c and c ~= "" then
                table.insert(parts, c)
            end
        end
        if #parts > 0 then
            return action .. " [ " .. table.concat(parts, " & ") .. " ]"
        end
    end
    return action
end

-- Convert a flat list of row tables into the full PBS script string
function B:RowsToScript(rows)
    local lines = {}
    for _, row in ipairs(rows) do
        if row.isIfBlock then
            -- open if
            local conds = {}
            if row.conditions then
                for _, c in ipairs(row.conditions) do
                    if c and c ~= "" then table.insert(conds, c) end
                end
            end
            if #conds > 0 then
                table.insert(lines, "if [ " .. table.concat(conds, " & ") .. " ]")
            else
                table.insert(lines, "if")
            end
            -- children
            if row.children then
                for _, child in ipairs(row.children) do
                    local l = self:RowToLine(child)
                    if l then
                        table.insert(lines, "    " .. l)
                    end
                end
            end
            table.insert(lines, "endif")
        else
            local l = self:RowToLine(row)
            if l then
                table.insert(lines, l)
            end
        end
    end
    return table.concat(lines, "\n")
end

-- Build the display label for a condition string fragment
function B:ConditionLabel(condStr)
    if not condStr then return "?" end
    return condStr
end

-- safe colour set helper
function B:SetBackdropColor(frame, r, g, b, a)
    if frame.SetBackdropColor then
        frame:SetBackdropColor(r, g, b, a or 1)
    end
end

-- Generate a unique frame name suffix
local _nameIdx = 0
function B:UniqueName(prefix)
    _nameIdx = _nameIdx + 1
    return (prefix or "PBSBuilderFrame") .. _nameIdx
end
