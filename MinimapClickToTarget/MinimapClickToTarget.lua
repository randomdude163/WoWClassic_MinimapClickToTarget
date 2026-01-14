-- This AddOn makes the minimap square and removes the frame, buttons and other stuff.
-- It allows you to double-click Humanoid Tracking pips on the map to target the player.
-- This is a port of the 1.12.1 AddOn BaumMap by EinBaum (https://github.com/EinBaum)
-- to the modern Classic Client.

local targetBtn = CreateFrame("Button", "targetBtn", UIParent, "MinimapClickToTargetSecureActionButtonTemplate")

-- Make sure the secure button is actually clickable in newer clients.
targetBtn:EnableMouse(true)
targetBtn:RegisterForClicks("AnyDown", "AnyUp")

local RARE_MOB_NAMES = {
    "Ribchaser",
    "Piggiesmalls",
    "Squiddic",
    "Yowler",
    "Kazon",
    "Hkfarmer"
}

local function unescape(str)
    local escapes = {
        ["|c%x%x%x%x%x%x%x%x"] = "", -- color start
        ["|r"] = "",                 -- color end
        ["|H.-|h(.-)|h"] = "%1",     -- links
        ["|T.-|t"] = "",             -- textures
        ["{.-}"] = "",               -- raid target icons
        ["\r"] = "\n"                -- It seems like the tooltip text has \r instead of \n right before a player name
    }

    for k, v in pairs(escapes) do
        str = gsub(str, k, v)
    end

    return str
end


local function target_name_has_whitespaces(target_name)
    return target_name:find("%s") ~= nil
end

local function target_name_contains_square_brackets(target_name)
    return target_name:find("%[") ~= nil
end

local function target_name_has_apostrophe(target_name)
    return target_name:find("'") ~= nil
end


local function target_name_is_player_name(target_name)
    for i = 1, #RARE_MOB_NAMES do
        if target_name == RARE_MOB_NAMES[i] then
            return false
        end
    end

    if target_name_has_apostrophe(target_name) then
        return false
    end

    local is_player_with_spy_info = (target_name_has_whitespaces(target_name) and target_name_contains_square_brackets(target_name))
    local is_player_without_spy_info = (not target_name_has_whitespaces(target_name))
    return (is_player_with_spy_info or is_player_without_spy_info)
end


local function remove_spy_info_from_target_name(target_name)
    if not target_name_contains_square_brackets(target_name) then
        return target_name
    end
    return target_name:match("^(.-)%s%[")
end


local function player_is_already_targeted(player_name)
    local target_name = UnitName("target")
    if not target_name then
        return false
    end
    return target_name == player_name
end


local function square_map_click_target()
    local tooltip_text = GameTooltipTextLeft1:GetText()
    if not tooltip_text then
        return
    end

    local escaped_tooltip_text = unescape(tooltip_text)
    -- DEFAULT_CHAT_FRAME:AddMessage("EscapedTooltipText="..escaped_tooltip_text)

    local target_names = { strsplit("\n", escaped_tooltip_text) }
    for _, target_name in ipairs(target_names) do
        if target_name_is_player_name(target_name) then
            local player_name = remove_spy_info_from_target_name(target_name)
            if not player_is_already_targeted(player_name) then
                -- DEFAULT_CHAT_FRAME:AddMessage("Player name "..player_name)
                targetBtn:ClearAllPoints()
                targetBtn:SetParent(Minimap)
                targetBtn:SetAllPoints(Minimap)
                targetBtn:SetFrameStrata("TOOLTIP")
                targetBtn:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 50)

                targetBtn:SetAttribute("type", "macro")
                targetBtn:SetAttribute("type1", "macro")
                local macro = "/targetexact " .. player_name .. "\n/target " .. player_name
                targetBtn:SetAttribute("macrotext", macro)
                targetBtn:SetAttribute("macrotext1", macro)
                targetBtn:Show()
                C_Timer.After(0.4, function() targetBtn:Hide() end)

                break
            end
        end
    end
end


local function hide_minimap_clock_frame()
    C_AddOns.LoadAddOn("Blizzard_TimeManager")
    local region = TimeManagerClockButton:GetRegions()
    region:Hide()
    TimeManagerClockButton:Hide()
end

local function hard_hide_frame(frame)
    if not frame then
        return
    end

    if frame.UnregisterAllEvents then
        frame:UnregisterAllEvents()
    end

    frame:Hide()
    frame:SetAlpha(0)
    if frame.EnableMouse then
        frame:EnableMouse(false)
    end
    if frame.SetScript then
        frame:SetScript("OnShow", frame.Hide)
    end
end

local function hide_minimap_title_and_close_button()
    -- Some Anniversary-era clients add title/close frames near the default minimap position.
    -- These frames can be separate from the older zone text button / toggle button.
    hard_hide_frame(_G.MinimapTitle)
    hard_hide_frame(_G.MinimapCloseButton)

    if not _G.MinimapCluster then
        return
    end

    -- Prefer explicit known fields when present.
    hard_hide_frame(_G.MinimapCluster.MinimapTitle)
    hard_hide_frame(_G.MinimapCluster.MinimapCloseButton)

    -- Border frame/texture pieces (e.g. "MinimapCluster.BorderTop" in Anniversary).
    hard_hide_frame(_G.MinimapCluster.BorderTop)
    hard_hide_frame(_G.MinimapCluster.BorderBottom)
    hard_hide_frame(_G.MinimapCluster.BorderLeft)
    hard_hide_frame(_G.MinimapCluster.BorderRight)
    hard_hide_frame(_G.MinimapCluster.Border)

    -- Fallback: scan children for title/close-like frames.
    local children = { _G.MinimapCluster:GetChildren() }
    for _, child in ipairs(children) do
        local name = child and child.GetName and child:GetName()
        if name and (
            name:find("MinimapTitle") or
            name:find("MinimapClose") or
            name:find("CloseButton") or
            name:find("Border")
        ) then
            hard_hide_frame(child)
        end
    end
end

local function hide_unwanted_minimap_elements()
    local hideAll = {
        "MinimapBorder",         -- Outer border
        "MinimapBorderTop",
        "MinimapNorthTag",       -- Compass
        "MinimapZoneTextButton", -- Zone text
        "MinimapZoomIn",         -- Zoom in
        "MinimapZoomOut",        -- Zoom out
        "GameTimeFrame",         -- Time button
        "SubZoneTextFrame",
        "MinimapToggleButton",
    }

    for _, frameName in ipairs(hideAll) do
        local frame = _G[frameName]
        if frame then
            frame:Hide()
        end
    end

    Minimap:SetStaticPOIArrowTexture("") -- remove arrow that points to nearest town
    hide_minimap_clock_frame()
    hide_minimap_title_and_close_button()
end

local function enable_scroll_wheel_zooming()
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function(frame, d)
        if d > 0 then
            MinimapZoomIn:Click()
        elseif d < 0 then
            MinimapZoomOut:Click()
        end
    end)
end

local function make_minimap_draggable()
    Minimap:SetMovable(true)
    Minimap:RegisterForDrag("LeftButton")

    Minimap:SetScript("OnDragStart", function(self)
        if IsControlKeyDown() then
            self:StartMoving()
        end
    end)

    Minimap:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
end

local function position_minimap_and_make_square()
    Minimap:SetPoint("CENTER", UIParent, 0, -250)
    Minimap:SetMaskTexture("Interface\\BUTTONS\\WHITE8X8")
end

local function square_map_setup()
    Minimap:SetScript("OnMouseUp", function(frame, button)
        local name = GameTooltipTextLeft1:GetText()
        if name then
            if IsShiftKeyDown() then -- Shift click to send ping
                Minimap_OnClick(frame, button)
            else
                square_map_click_target()
            end
        else
            Minimap_OnClick(frame, button)
        end
    end)

    hide_unwanted_minimap_elements()
    enable_scroll_wheel_zooming()
    make_minimap_draggable()
    position_minimap_and_make_square()
end

square_map_setup()
