local _, KeystonePolaris = ...

-- Display frame / layout / color cache

KeystonePolaris.colorCache = {}

function KeystonePolaris:UpdateColorCache()
    if not self.db or not self.db.profile then return end

    local function toHex(color)
        return string.format("%02x%02x%02x",
            math.floor((color.r or 1) * 255),
            math.floor((color.g or 1) * 255),
            math.floor((color.b or 1) * 255)
        )
    end

    local colors = self.db.profile.color
    if colors then
        self.colorCache.prefix = toHex(colors.prefix or {r=1, g=0.7960784, b=0.2})
        self.colorCache.milestonePrefix = toHex(colors.milestonePrefix or colors.prefix or {r=1, g=0.7960784, b=0.2})
        self.colorCache.finished = toHex(colors.finished or {r=0, g=1, b=0})
        self.colorCache.inProgress = toHex(colors.inProgress or {r=1, g=1, b=1})
        self.colorCache.missing = toHex(colors.missing or {r=1, g=0, b=0})
    end
end

function KeystonePolaris:InitializeDisplay()
    self:UpdateColorCache()
    self:CreateDisplayFrame()
    self:CreatePositioningToolbar()
end

-- ---------------------------------------------------------------------------
-- Display Frame
-- ---------------------------------------------------------------------------

-- Create or recreate the main display frame
function KeystonePolaris:CreateDisplayFrame()
    if not self.displayFrame then
        self.displayFrame = CreateFrame("Frame", "KeystonePolarisDisplay", UIParent)
        self.displayFrame:SetSize(200, 30)

        -- Create percentage text
        self.displayFrame.text = self.displayFrame:CreateFontString(nil, "OVERLAY")
        self.displayFrame.text:SetFont(self.LSM:Fetch('font', self.db.profile.text.font), self.db.profile.general.fontSize, self:GetFontFlags())
        self.displayFrame.text:SetPoint("CENTER")
        self.displayFrame.text:SetText("0.0%") -- Set initial text

        -- Set position from saved variables
        self.displayFrame:ClearAllPoints()
        self.displayFrame:SetPoint(
            self.db.profile.general.position,
            UIParent,
            self.db.profile.general.position,
            self.db.profile.general.xOffset,
            self.db.profile.general.yOffset
        )
    end

    -- Ensure text is visible and settings are applied
    self:ApplyTextLayout()
    self:Refresh()
end

-- Resize the display frame to fit multi-line content when enabled
function KeystonePolaris:AdjustDisplayFrameSize()
    if not self.displayFrame or not self.db or not self.db.profile then return end

    -- Avoid protected calls during combat; defer resize until combat ends
    if InCombatLockdown() then
        self._pendingAdjustAfterCombat = true
        if not self._combatWatcher then
            local f = CreateFrame("Frame")
            f:RegisterEvent("PLAYER_REGEN_ENABLED")
            f:SetScript("OnEvent", function()
                if self._pendingAdjustAfterCombat then
                    self._pendingAdjustAfterCombat = false
                    if self.AdjustDisplayFrameSize then
                        self:AdjustDisplayFrameSize()
                    end
                end
            end)
            self._combatWatcher = f
        end
        return
    end

    local cfg = self.db.profile.general.mainDisplay
    if not (cfg and cfg.multiLine) then
        -- Reset to default height for single-line usage
        self.displayFrame:SetHeight(30)
        return
    end

    local text = self.displayFrame.text:GetText() or ""
    local _, count = text:gsub("\n", "")
    local lines = (count or 0) + 1
    local lineHeight = self.db.profile.general.fontSize or 12
    local padding = 6
    self.displayFrame:SetHeight(lines * lineHeight + padding)
end

-- Apply text layout to support configurable text alignment (LEFT/CENTER/RIGHT)
function KeystonePolaris:ApplyTextLayout()
    if not (self.displayFrame and self.displayFrame.text and self.db and self.db.profile) then return end
    local cfg = self.db.profile.general.mainDisplay
    if not cfg then return end

    local align = cfg.textAlign or "CENTER"
    local multi = cfg.multiLine and true or false
    local maxWidth = tonumber(cfg.maxWidth) or 0

    self.displayFrame.text:ClearAllPoints()

    if multi then
        -- Multi-line: fixed default width (600px); each metric on its own line
        if not InCombatLockdown() then
            self.displayFrame:SetWidth(600)
        end
        self.displayFrame.text:SetPoint("TOPLEFT", self.displayFrame, "TOPLEFT", 0, 0)
        self.displayFrame.text:SetPoint("TOPRIGHT", self.displayFrame, "TOPRIGHT", 0, 0)
        self.displayFrame.text:SetWidth(self.displayFrame:GetWidth())
        self.displayFrame.text:SetWordWrap(true)
        if self.displayFrame.text.SetMaxLines then
            self.displayFrame.text:SetMaxLines(0) -- unlimited lines
        end
        self.displayFrame.text:SetJustifyV("TOP")
    else
        -- Single-line: ALWAYS center-align regardless of option
        self.displayFrame.text:SetPoint("CENTER", self.displayFrame, "CENTER", 0, 0)
        if maxWidth > 0 then
            self.displayFrame.text:SetWidth(maxWidth)
            self.displayFrame.text:SetWordWrap(true)
        else
            -- Autosize to text; no wrapping
            self.displayFrame.text:SetWidth(0)
            self.displayFrame.text:SetWordWrap(false)
        end
        self.displayFrame.text:SetJustifyV("MIDDLE")
        self.displayFrame.text:SetJustifyH("CENTER")
        return
    end

    -- Multi-line justification
    self.displayFrame.text:SetJustifyH(align)
    -- Force reflow so alignment applies immediately
    local _cur = self.displayFrame.text:GetText()
    if _cur ~= nil then
        self.displayFrame.text:SetText(_cur)
    end
end

-- Refresh the display with current settings
function KeystonePolaris:Refresh()
    if not self.displayFrame then return end

    -- Update frame position (skip during positioning mode — frame is being dragged)
    if not self._positioningMode then
        self.displayFrame:ClearAllPoints()
        self.displayFrame:SetPoint(
            self.db.profile.general.position,
            UIParent,
            self.db.profile.general.position,
            self.db.profile.general.xOffset,
            self.db.profile.general.yOffset
        )
    end

    -- Update font size and font
    self.displayFrame.text:SetFont(self.LSM:Fetch('font', self.db.profile.text.font), self.db.profile.general.fontSize, self:GetFontFlags())
    -- Update horizontal alignment
    self:ApplyTextLayout()

    -- Update text color
    local color = self.db.profile.color.inProgress
    self.displayFrame.text:SetTextColor(color.r, color.g, color.b, 1)
    self.displayFrame.text:SetAlpha(self.db.profile.general.textOpacity or 1)

    -- Update dungeon data with advanced options if enabled
    if self.UpdateDungeonData then self:UpdateDungeonData() end

    -- Show/hide based on enabled state
    local leaderEnabled   = self.db.profile.general.rolesEnabled.LEADER
    local isLeader        = UnitIsGroupLeader("player")
    local role            = UnitGroupRolesAssigned("player")   -- "TANK", "HEALER", "DAMAGER", ou "NONE"
    local roleEnabled     = self.db.profile.general.rolesEnabled[role]

    local shouldShow = (leaderEnabled and isLeader) or roleEnabled or role == "NONE"

    if not shouldShow then
        if self._testMode then
            self.displayFrame:Show()
        else
            self.displayFrame:Hide()
            return
        end
    end
    self.displayFrame:Show()
end
