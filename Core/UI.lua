-- PBSBuilder/Core/UI.lua
-- Low-level frame/widget helpers

local B = PBSBuilder

-- ─────────────────────────────────────────────────────────────
-- Backdrop (11.x uses CreateBackdrop pattern)
-- ─────────────────────────────────────────────────────────────
local BACKDROP = {
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left=2, right=2, top=2, bottom=2 },
}

function B:ApplyBackdrop(frame, r, g, b, a)
    if not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(r or 0.05, g or 0.05, b or 0.1, a or 0.95)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.6, 1)
end

-- ─────────────────────────────────────────────────────────────
-- Simple text button
-- ─────────────────────────────────────────────────────────────
function B:CreateButton(parent, w, h, text, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(w, h)
    btn:SetText(text)
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end

-- ─────────────────────────────────────────────────────────────
-- Label (FontString shortcut)
-- ─────────────────────────────────────────────────────────────
function B:CreateLabel(parent, text, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text or "")
    if size then
        local font, _, flags = fs:GetFont()
        fs:SetFont(font, size, flags)
    end
    if r then fs:SetTextColor(r, g or 1, b or 1, 1) end
    return fs
end

-- ─────────────────────────────────────────────────────────────
-- EditBox
-- ─────────────────────────────────────────────────────────────
function B:CreateEditBox(parent, w, h, placeholder)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(w, h)
    eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal")
    if placeholder then
        eb._placeholder = placeholder
        eb:SetText(placeholder)
        eb:SetTextColor(0.5, 0.5, 0.5)
        eb:SetScript("OnEditFocusGained", function(self)
            if self:GetText() == self._placeholder then
                self:SetText("")
                self:SetTextColor(1, 1, 1)
            end
        end)
        eb:SetScript("OnEditFocusLost", function(self)
            if self:GetText() == "" then
                self:SetText(self._placeholder)
                self:SetTextColor(0.5, 0.5, 0.5)
            end
        end)
    end
    return eb
end

-- ─────────────────────────────────────────────────────────────
-- Simple Dropdown (pure Lua, no UIDropDownMenu)
-- Opens a popup list of { label, value } items
-- onSelect(value) callback
-- ─────────────────────────────────────────────────────────────
local openDropdown = nil

local function CloseOpenDropdown()
    if openDropdown and openDropdown:IsShown() then
        openDropdown:Hide()
    end
    openDropdown = nil
end

function B:CreateDropdown(parent, w, h, items, onSelect)
    -- The "button" that shows current selection
    local btn = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    btn:SetSize(w, h)
    B:ApplyBackdrop(btn, 0.1, 0.1, 0.2, 1)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", btn, "LEFT", 6, 0)
    label:SetPoint("RIGHT", btn, "RIGHT", -20, 0)
    label:SetJustifyH("LEFT")
    label:SetText(items and items[1] and items[1].label or "Select...")
    btn._label = label

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    arrow:SetText("|cffaaaaaa▼|r")

    -- Popup list frame (parented to UIParent so it floats above everything)
    local popup = CreateFrame("Frame", B:UniqueName("PBSDropPopup"), UIParent, "BackdropTemplate")
    popup:SetFrameStrata("TOOLTIP")  -- always on top of any DIALOG window
    popup:SetFrameLevel(100)
    -- IMPORTANT: popup must not block mouse when hidden
    popup:EnableMouse(true)
    popup:Hide()
    B:ApplyBackdrop(popup, 0.05, 0.05, 0.15, 0.98)
    popup._items = items
    popup._btn   = btn
    popup._rows  = {}

    local MAX_VISIBLE_ROWS = 10
    local ROW_H = 20

    -- Scroll frame inside popup for long lists
    local popupScroll = CreateFrame("ScrollFrame", nil, popup)
    popupScroll:SetPoint("TOPLEFT",     popup, "TOPLEFT",     2,  -2)
    popupScroll:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -2,  2)
    popupScroll:EnableMouseWheel(true)
    popupScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * ROW_H * 2)))
    end)

    local popupContent = CreateFrame("Frame", nil, popupScroll)
    popupContent:SetWidth(w - 4)
    popupScroll:SetScrollChild(popupContent)

    local function BuildPopup()
        for _, r in ipairs(popup._rows) do r:Hide() end
        popup._rows = {}
        local popupItems = popup._items or {}
        local visRows   = math.min(#popupItems, MAX_VISIBLE_ROWS)
        local popupH    = visRows * ROW_H + 4

        popup:SetWidth(w)
        popup:SetHeight(popupH)
        popupContent:SetWidth(w - 4)
        popupContent:SetHeight(#popupItems * ROW_H)
        popupScroll:SetVerticalScroll(0)

        for i, item in ipairs(popupItems) do
            local row = CreateFrame("Button", nil, popupContent)
            row:SetFrameLevel(popup:GetFrameLevel() + 2)
            row:SetSize(w - 4, ROW_H)
            row:SetPoint("TOPLEFT", popupContent, "TOPLEFT", 0, -(i-1) * ROW_H)
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetPoint("LEFT", row, "LEFT", 6, 0)
            fs:SetText(item.label)
            fs:SetJustifyH("LEFT")

            row:SetScript("OnEnter", function(self)
                fs:SetTextColor(1, 0.85, 0, 1)
            end)
            row:SetScript("OnLeave", function(self)
                fs:SetTextColor(1, 1, 1, 1)
            end)
            row:SetScript("OnClick", function(self)
                label:SetText(item.label)
                btn._value = item.value
                CloseOpenDropdown()
                if onSelect then onSelect(item.value, item.label) end
            end)
            table.insert(popup._rows, row)
        end
    end

    btn:EnableMouse(true)
    btn:SetScript("OnMouseDown", function(self, mouseBtn)
        if mouseBtn ~= "LeftButton" then return end
        if openDropdown == popup then
            CloseOpenDropdown()
            return
        end
        CloseOpenDropdown()
        BuildPopup()
        popup:ClearAllPoints()

        -- Flip upward if popup would go off the bottom of the screen
        local btnBottom = btn:GetBottom()
        local popupH    = math.min(#(popup._items or {}), MAX_VISIBLE_ROWS) * ROW_H + 4
        if btnBottom and btnBottom - popupH < 0 then
            popup:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 2)
        else
            popup:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
        end
        popup:Show()
        openDropdown = popup
    end)

    -- Close when clicking elsewhere
    popup:SetScript("OnHide", function() openDropdown = nil end)

    -- Public API
    function btn:SetItems(newItems)
        popup._items = newItems
        if newItems and newItems[1] then
            label:SetText(newItems[1].label)
            self._value = newItems[1].value
        end
    end

    function btn:GetValue()
        return self._value or (items and items[1] and items[1].value)
    end

    function btn:SetValue(val)
        for _, item in ipairs(popup._items or items or {}) do
            if item.value == val then
                label:SetText(item.label)
                self._value = val
                return
            end
        end
    end

    -- Init default value
    if items and items[1] then
        btn._value = items[1].value
    end

    return btn
end

-- ─────────────────────────────────────────────────────────────
-- Global dropdown closer
-- IMPORTANT: must NOT use SetAllPoints on UIParent — that frame
-- would swallow all mouse input and block camera right-click drag.
-- Instead we hook OnMouseDown only on the *popup frames themselves*
-- via their OnHide, and close on any WorldFrame click.
-- ─────────────────────────────────────────────────────────────
local worldClickCatcher = CreateFrame("Frame", nil, WorldFrame)
worldClickCatcher:SetAllPoints(WorldFrame)
worldClickCatcher:SetFrameStrata("BACKGROUND")
worldClickCatcher:EnableMouse(false)  -- never block world interaction
-- Dropdowns self-close via their popup OnHide and btn OnMouseDown logic above.
-- If a dropdown is open and the user clicks anywhere outside it, the popup's
-- own OnHide fires when another frame receives focus.  For belt-and-suspenders
-- we also hook the main window's OnMouseDown to close any open dropdown.
B._closeOpenDropdown = CloseOpenDropdown
