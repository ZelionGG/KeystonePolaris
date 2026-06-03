local AddOnName, KeystonePolaris = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)

local githubTexture = KeystonePolaris.constants.mediaPath .. "donate\\github.tga"
local paypalTexture = KeystonePolaris.constants.mediaPath .. "donate\\paypal.tga"
local SUPPORT_LINKS = {
    {
        key = "github",
        localeKey = "GITHUB_SPONSORS",
        descriptionKey = "GITHUB_SPONSORS_DESC",
        url = "https://github.com/sponsors/ZelionGG",
        texture = "|T" .. githubTexture .. ":14:14:0:0|t ",
    },
    {
        key = "paypal",
        localeKey = "PAYPAL",
        descriptionKey = "PAYPAL_DESC",
        url = "https://www.paypal.com/donate/?hosted_button_id=7MN59ZWHEJU6Y",
        texture = "|T" .. paypalTexture .. ":14:10:0:0|t ",
    },
}

local LOCALIZATION_CONTRIBUTORS = {
    {
        flag = "ruRU",
        name = "Hollicsh",
        role = (L["LOCALIZATION_STRING"]):format(RURU)
    },
    {
        flag = "koKR",
        name = "BlueSea-jun",
        role = (L["LOCALIZATION_STRING"]):format(KOKR),
    },
    {
        flag = "zhCN",
        name = "nanjuekaien1, Toothache-xDD",
        role = (L["LOCALIZATION_STRING"]):format(ZHCN),
    },
    {
        flag = "deDE",
        name = "KazumaKuma",
        role = (L["LOCALIZATION_STRING"]):format(DEDE),
    },
    {
        flag = "ptBR",
        name = "roneicostajr",
        role = (L["LOCALIZATION_STRING"]):format(LFG_LIST_LANGUAGE_PTBR),
    },
    {
        flag = "frFR",
        name = "ZelionGG",
        role = (L["LOCALIZATION_STRING"]):format(FRFR),
    },
}

local CODE_CONTRIBUTORS = {
    {
        flag = "enUS",
        name = "whatisboom",
        role = L["DEVELOPER"],
    },
    {
        flag = "enUS",
        name = "whatisboom",
        role = L["DEVELOPER"],
    },
}

local function GetFlagPrefix(flag)
    if flag and flag ~= "" then
        local texture = KeystonePolaris.constants.mediaPath .. "flags\\" .. flag .. ".tga"
        return "|T" .. texture .. ":14:20:0:0|t "
    end

    return ""
end

local function FormatContributorLine(flag, name, role)
    return GetFlagPrefix(flag) .. "|cffffffff" .. name .. "|r |cff9d9d9d-|r |cffcfcfcf" .. role .. "|r"
end

local function Whitespace(order)
    return {
        order = order,
        type = "description",
        name = " ",
        fontSize = "medium",
    }
end

function KeystonePolaris.ShowSupportLinkDialog(_, title, url)
    StaticPopupDialogs["KPL_SUPPORT_LINK_DIALOG"] = {
        text = title,
        button1 = OKAY,
        hasEditBox = true,
        editBoxWidth = 350,
        maxLetters = 999999,
        OnShow = function(dialog)
            dialog.EditBox:SetText(url or "")
            dialog.EditBox:HighlightText()
            dialog.EditBox:SetFocus()
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true
    }

    StaticPopup_Show("KPL_SUPPORT_LINK_DIALOG")
end

function KeystonePolaris:GenerateAbout()
    self.aboutOptions = {
        type = "group",
        name = L["ABOUT"],
        args = {}
    }

    local args = self.aboutOptions.args
    local order = 1

    args.introDescription = {
        order = order,
        type = "description",
        name = L["ABOUT_DESC"],
        fontSize = "medium",
    }
    order = order + 1

    args.developmentHeader = {
        order = order,
        type = "header",
        name = L["DEVELOPMENT"],
    }
    order = order + 1

    args.developmentDescription = {
        order = order,
        type = "description",
        name = FormatContributorLine("frFR", "ZelionGG", L["MAINTAINER_AND_DEVELOPER"]),
        fontSize = "medium",
    }
    order = order + 1

    args.developmentSpacer = Whitespace(order)
    order = order + 1

    for _, developer in ipairs(CODE_CONTRIBUTORS) do
        args["developer_" .. developer.name] = {
            order = order,
            type = "description",
            name = FormatContributorLine(developer.flag, developer.name,
                                         developer.role),
            fontSize = "medium",
        }
        order = order + 1
    end

    args.localizationSpacer = {
        order = order,
        type = "description",
        name = " ",
        fontSize = "medium",
    }
    order = order + 1

    args.localizationHeader = {
        order = order,
        type = "header",
        name = L["LOCALIZATION"],
    }
    order = order + 1

    for _, contributor in ipairs(LOCALIZATION_CONTRIBUTORS) do
        args["localizer_" .. contributor.name] = {
            order = order,
            type = "description",
            name = FormatContributorLine(contributor.flag, contributor.name,
                                         contributor.role),
            fontSize = "medium",
        }
        order = order + 1
    end

    args.supportSpacer = {
        order = order,
        type = "description",
        name = " ",
        fontSize = "medium",
    }
    order = order + 1

    args.supportHeader = {
        order = order,
        type = "header",
        name = L["DONATE"],
    }
    order = order + 1

    args.supportDescription = {
        order = order,
        type = "description",
        name = L["DONATE_DESC"],
        fontSize = "medium",
    }
    order = order + 1

    for index, link in ipairs(SUPPORT_LINKS) do
        args["support_" .. link.key] = {
            order = order + index - 1,
            type = "execute",
            name = link.texture .. L[link.localeKey],
            desc = L[link.descriptionKey],
            func = function()
                if KeystonePolaris and KeystonePolaris.ShowSupportLinkDialog then
                    KeystonePolaris:ShowSupportLinkDialog(link.texture .. L[link.localeKey], link.url)
                end
            end,
            width = 1.2,
        }
    end
end
