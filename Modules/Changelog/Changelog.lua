local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)
local gsub = string.gsub
local format = string.format
local strsplit = strsplit

-- ---------------------------------------------------------------------------
-- Changelog Logic
-- ---------------------------------------------------------------------------

function KeystonePolaris:CreateColorString(text, db)
    local hex = db.r and db.g and db.b and self.RGBToHex(db.r, db.g, db.b) or
                    "|cffffffff"

    local string = hex .. text .. "|r"
    return string
end

function KeystonePolaris.RGBToHex(r, g, b, header, ending)
    r = r <= 1 and r >= 0 and r or 1
    g = g <= 1 and g >= 0 and g or 1
    b = b <= 1 and b >= 0 and b or 1

    local hex = format('%s%02x%02x%02x%s', header or '|cff', r * 255, g * 255,
                       b * 255, ending or '')
    return hex
end

function KeystonePolaris:GenerateChangelog()
    self.changelogOptions = {
        type = "group",
        childGroups = "select",
        name = L["Changelog"],
        args = {}
    }

    if not self.Changelog or type(self.Changelog) ~= "table" then return end

    local function orange(string)
        if type(string) ~= "string" then string = tostring(string) end
        string = self:CreateColorString(string,
                                        {r = 0.859, g = 0.388, b = 0.203})
        return string
    end

    local function lightblue(string)
        if type(string) ~= "string" then string = tostring(string) end
        string = self:CreateColorString(string, {r = 0.4, g = 0.6, b = 1.0})
        return string
    end
    local function renderChangelogLine(line, colorFunc)
        line = gsub(line, "%[[^%[]+%]", colorFunc)
        return line
    end

    -- Build a plain, colorless text block for a changelog entry (current locale with enUS fallback)
    local function buildPlainText(data)
        local function stripColors(s)
            if type(s) ~= "string" then s = tostring(s) end
            s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
            s = s:gsub("|r", "")
            return s
        end
        local function resolve(list)
            if not list then return {} end
            if list[GetLocale()] and next(list[GetLocale()]) then
                return list[GetLocale()]
            end
            return list["enUS"] or {}
        end

        local chunks = {}
        local function appendSection(titleKey, list)
            local items = resolve(list)
            if items and #items > 0 then
                table.insert(chunks, (L and L[titleKey]) or titleKey)
                for _, line in ipairs(items) do
                    table.insert(chunks, "- " .. stripColors(line))
                end
                table.insert(chunks, "")
            end
        end

        local function appendHeader(headerData)
            if not headerData then return end

            local items = resolve(headerData)
            if items and items.title and items.text then
                table.insert(chunks, stripColors(items.title))
                table.insert(chunks, "")
                table.insert(chunks, stripColors(items.text))
                table.insert(chunks, "")
            end
        end

        if data and type(data) == "table" then
            if data.version_string and data.release_date then
                table.insert(chunks, (L and L["Version"] or "Version") .. ": " .. data.version_string ..
                    " (" .. data.release_date .. ")")
                table.insert(chunks, "")
            end
            appendHeader(data.header)
            appendSection("Important", data.important)
            appendSection("New", data.new)
            appendSection("Bugfixes", data.bugfix)
            appendSection("Improvement", data.improvment)
        end

        return table.concat(chunks, "\n")
    end

    -- Remove the "no changelog" entry if we have actual entries
    self.changelogOptions.args.noChangelog = nil

    for version, data in pairs(self.Changelog) do
        if type(data) == "table" and data.version_string and data.release_date then
            local versionString = data.version_string
            local dateTable = {strsplit("/", data.release_date)}
            local dateString = data.release_date
            if #dateTable == 3 then
                dateString = L["%month%-%day%-%year%"]
                dateString = gsub(dateString, "%%year%%", dateTable[1])
                dateString = gsub(dateString, "%%month%%", dateTable[2])
                dateString = gsub(dateString, "%%day%%", dateTable[3])
            end

            self.changelogOptions.args[tostring(version)] = {
                order = 10000 - version,
                name = versionString,
                type = "group",
                args = {
                    translate = {
                        order = 1,
                        type = "execute",
                        name = L["TRANSLATE"],
                        desc = L["TRANSLATE_DESC"],
                        func = function()
                            local plain = buildPlainText(data)
                            if KeystonePolaris and KeystonePolaris.ShowCopyPopup then
                                KeystonePolaris:ShowCopyPopup(plain)
                            end
                        end,
                    },
                    version = {
                        order = 2,
                        type = "description",
                        name = L["Version"] .. " " .. orange(versionString) ..
                            " - |cffbbbbbb" .. dateString .. "|r",
                        fontSize = "large"
                    }
                }
            }

            local page = self.changelogOptions.args[tostring(version)].args

            local header
            if data.header then
                local headerLocalized = data.header[GetLocale()]
                if headerLocalized ~= nil and (headerLocalized.title ~= nil or headerLocalized.text ~= nil) then
                    header = headerLocalized
                else
                    header = data.header["enUS"]
                end
            end

            if header and (header.title ~= nil or header.text ~= nil) then
                if header.title ~= nil and header.title ~= "" then
                    page.headerHeader = {
                        order = 2.5,
                        type = "header",
                        name = lightblue(header.title)
                    }
                end

                if header.text ~= nil and header.text ~= "" then
                    page.headerText = {
                        order = 2.6,
                        type = "description",
                        name = function()
                            return renderChangelogLine(header.text, lightblue) .. "\n"
                        end,
                        fontSize = "medium"
                    }
                end
            end

            -- Checking localized "Important" category
            local important_localized = {}
            if data.important and data.important[GetLocale()] and
                next(data.important[GetLocale()]) then
                important_localized = data.important[GetLocale()]
            elseif data.important and data.important["enUS"] then
                important_localized = data.important["enUS"]
            end

            if important_localized and #important_localized > 0 then
                page.importantHeader = {
                    order = 3,
                    type = "header",
                    name = orange(L["Important"])
                }
                page.important = {
                    order = 4,
                    type = "description",
                    name = function()
                        local text = ""
                        for index, line in ipairs(important_localized) do
                            text = text .. index .. ". " ..
                                       renderChangelogLine(line, orange) .. "\n"
                        end
                        return text .. "\n"
                    end,
                    fontSize = "medium"
                }
            end

            -- Checking localized "New" category
            local new_localized = {}
            if data.new and data.new[GetLocale()] and
                next(data.new[GetLocale()]) then
                new_localized = data.new[GetLocale()]
            elseif data.new and data.new["enUS"] then
                new_localized = data.new["enUS"]
            end

            if new_localized and #new_localized > 0 then
                page.newHeader = {
                    order = 5,
                    type = "header",
                    name = orange(L["New"])
                }
                page.new = {
                    order = 6,
                    type = "description",
                    name = function()
                        local text = ""
                        for index, line in ipairs(new_localized) do
                            text = text .. index .. ". " ..
                                       renderChangelogLine(line, orange) .. "\n"
                        end
                        return text .. "\n"
                    end,
                    fontSize = "medium"
                }
            end

            -- Checking localized "Bugfix" category
            local bugfix_localized = {}
            if data.bugfix and data.bugfix[GetLocale()] and
                next(data.bugfix[GetLocale()]) then
                bugfix_localized = data.bugfix[GetLocale()]
            elseif data.bugfix and data.bugfix["enUS"] then
                bugfix_localized = data.bugfix["enUS"]
            end

            if bugfix_localized and #bugfix_localized > 0 then
                page.bugfixHeader = {
                    order = 7,
                    type = "header",
                    name = orange(L["Bugfixes"])
                }
                page.bugfix = {
                    order = 8,
                    type = "description",
                    name = function()
                        local text = ""
                        for index, line in ipairs(bugfix_localized) do
                            text = text .. index .. ". " ..
                                       renderChangelogLine(line, orange) .. "\n"
                        end
                        return text .. "\n"
                    end,
                    fontSize = "medium"
                }
            end

            -- Checking localized "Improvment" category
            local improvment_localized = {}
            if data.improvment and data.improvment[GetLocale()] and
                next(data.improvment[GetLocale()]) then
                improvment_localized = data.improvment[GetLocale()]
            elseif data.improvment and data.improvment["enUS"] then
                improvment_localized = data.improvment["enUS"]
            end

            if improvment_localized and #improvment_localized > 0 then
                page.improvmentHeader = {
                    order = 9,
                    type = "header",
                    name = orange(L["Improvement"])
                }
                page.improvment = {
                    order = 10,
                    type = "description",
                    name = function()
                        local text = ""
                        for index, line in ipairs(improvment_localized) do
                            text = text .. index .. ". " ..
                                       renderChangelogLine(line, orange) .. "\n"
                        end
                        return text .. "\n"
                    end,
                    fontSize = "medium"
                }
            end
        end
    end
end
