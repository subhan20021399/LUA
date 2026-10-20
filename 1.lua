local GameStateBase = {
  LuaEventContainer = {
    "DefaultLuaEventPlaceholder"
  }
}
local KismetSystemLibrary = import("KismetSystemLibrary")

function GameStateBase:ctor(selfType)
  self.bIsClient = false
  self.CodeRecord = {}
  self.GlobalCachePool = {}
  self.bLuaGameStateInit = false
  self.SkillManagerEntry = nil
  self._SuperData = nil
  self.MatchReadyConfirmed = false
  self.EnterFightingTime = 0
  self.SelfRescueEndTime = 0
  self.bHaveRevive = false
  local SuperData = self:GetSuperData()
  SuperData.bHaveRevive = self.bHaveRevive
  self.CountdownTime = 0
  self.MaxFPSInMatch = 0
  self.FireworkBGMFlag = -1
end

function GameStateBase:_PostConstruct()
  GameStateBase.__super._PostConstruct(self)
  self:AddControlEvent(self, "OnDSOptimGrayPublishFlagsChanged", self.HandleOnDSOptimGrayPublishFlagsChanged, self)
  local STExtraGameplayStatics = import("STExtraGameplayStatics")
  if not Client then
    local STExtraGameInstance = import("STExtraGameInstance")
    local GameInstance = STExtraGameInstance.GetInstance()
    if slua.isValid(GameInstance) and not STExtraGameplayStatics.IsShipping() then
      local MaxPlayerNum = -1
      GameInstance:ExecuteCMD("ParallelWorld.Debug.MaxPlayerNum", MaxPlayerNum)
    end
  else
    self:AddControlEvent(self, "StartCompleteRecordingDelegate", self.OnStartCompleteRecording, self)
  end
end

function GameStateBase:GetLifetimeReplicatedProps()
  local ELifetimeCondition = import("ELifetimeCondition")
  local RepTable = {
    { "MatchReadyConfirmed", ELifetimeCondition.COND_None, UEnums.EPropertyClass.Bool },
    { "SelfRescueEndTime", ELifetimeCondition.COND_None, UEnums.EPropertyClass.Int },
    { "EnterFightingTime", ELifetimeCondition.COND_None, UEnums.EPropertyClass.Float },
    { "bHaveRevive", ELifetimeCondition.COND_None, UEnums.EPropertyClass.Bool },
    { "CountdownTime", ELifetimeCondition.COND_None, UEnums.EPropertyClass.Int },
    { "MaxFPSInMatch", ELifetimeCondition.COND_None, UEnums.EPropertyClass.Int },
    { "FireworkBGMFlag", ELifetimeCondition.COND_None, UEnums.EPropertyClass.Int }
  }
  return RepTable
end

function GameStateBase:UpdateCountdownTime(CountdownTime)
  local CountdownTimeInt = math.floor(CountdownTime)
  self.CountdownTime = CountdownTimeInt
end

function GameStateBase:UpdateFireworkBGMFlag(InFireworkBGMFlag)
  self.FireworkBGMFlag = InFireworkBGMFlag
end

function GameStateBase:OnStartCompleteRecording()
  local SettingSubsystem_CPP = slua_GameFrontendHUD:GetSettingSubsystem()
  if slua.isValid(SettingSubsystem_CPP) then
    SettingSubsystem_CPP:OnReportSettingConfigStart()
  end
end

function GameStateBase:OnRep_CountdownTime()
  local NewYearCountdownSubsystem = SubsystemMgr:Get("NewYearCountdownSubsystem")
  if NewYearCountdownSubsystem then NewYearCountdownSubsystem:OnRepCurrentTime(self.CountdownTime) end
end

function GameStateBase:OnRep_FireworkBGMFlag()
  local NewYearCountdownSubsystem = SubsystemMgr:Get("NewYearCountdownSubsystem")
  if NewYearCountdownSubsystem then NewYearCountdownSubsystem:OnRepFireworkBGMFlag(self.FireworkBGMFlag) end
end

function GameStateBase:OnRep_MaxFPSInMatch()
  if self.RoomType and self.RoomType == "match" then
    if self.MaxFPSInMatch > 0 then
      local UIUtil = require("client.common.ui_util")
      local GameInstance = UIUtil.GetGameInstance()
      local uSTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
      local CurrentMaxFps = uSTExtraBlueprintFunctionLibrary.GetConsoleVariableFloatValue("t.MaxFPS")
      if CurrentMaxFps > self.MaxFPSInMatch then
        GameInstance:ExecuteCMD("t.MaxFPS", self.MaxFPSInMatch)
      end
    end
  end
end

function GameStateBase:ReportPlayersNumberWhoSawFireworks()
  if CGameState and CGameState:GetGameModeState() == "FinishedState" then return end
  local PlayersNumber = 0
  local NotAliveNumber = 0
  local PlayerArray = Game:GetAllPlayerPawns()
  for i = 0, PlayerArray:Num() - 1 do
    local Pawn = PlayerArray:Get(i)
    if Pawn and slua.isValid(Pawn) and Game:IsPlayer(Pawn) and self:IsSeeingFirework(Pawn) then
      local uPlayerState = Pawn:GetPlayerStateSafety()
      if uPlayerState and slua.isValid(uPlayerState) then
        if uPlayerState:IsAlive() then PlayersNumber = PlayersNumber + 1
        else NotAliveNumber = NotAliveNumber + 1 end
      end
    end
  end
  if 0 < PlayersNumber then
    local DSCommonTLogSubsystem = SubsystemMgr:Get("DSCommonTLogSubsystem")
    if DSCommonTLogSubsystem then DSCommonTLogSubsystem:AddCommonTLog(489, PlayersNumber, true) end
  end
end

function GameStateBase:IsSeeingFirework(Pawn) return true end

function GameStateBase:HandleOnDSOptimGrayPublishFlagsChanged()
  if Client then
    if Client.IsEnableDSGrayPublishFlag(2199023255552) or Client.IsEditor() then
      KismetSystemLibrary.ExecuteConsoleCommand(self, "chara.enablevehiclerep 0")
    end
    if Client.IsEnableDSGrayPublishFlag(1048576) or Client.IsEditor() then
      KismetSystemLibrary.ExecuteConsoleCommand(self, "p.DelayNotifyComponentOverlap 1")
      KismetSystemLibrary.ExecuteConsoleCommand(self, "p.DebugDelayNotifyComponentOverlap 1")
    end
    if Client.IsEnableDSGrayPublishFlag(134217728) or Client.IsEditor() then
      KismetSystemLibrary.ExecuteConsoleCommand(self, "Vehicle.Protection.ImpulseImpl 1")
    end
    self:SetPhysicsTimeSteps()
  end
end

function GameStateBase:SetPhysicsTimeSteps()
  if Client then
    if Client.IsEnableDSGrayPublishFlag(549755813888) or Client.IsEditor() then
      local TCDeviceLevel = Client.GetTCDeviceLevel()
      if TCDeviceLevel <= 3 then
        KismetSystemLibrary.ExecuteConsoleCommand(self, "p.MaxSubStepDeltaTime 0.0333")
        KismetSystemLibrary.ExecuteConsoleCommand(self, "p.MaxSubSteps 3")
      elseif 3 < TCDeviceLevel and TCDeviceLevel <= 5 then
        KismetSystemLibrary.ExecuteConsoleCommand(self, "p.MaxSubStepDeltaTime 0.0222")
        KismetSystemLibrary.ExecuteConsoleCommand(self, "p.MaxSubSteps 3")
      else
        KismetSystemLibrary.ExecuteConsoleCommand(self, "p.MaxSubStepDeltaTime 0.0167")
        KismetSystemLibrary.ExecuteConsoleCommand(self, "p.MaxSubSteps 3")
      end
    end
  elseif Server and Server.IsEnableDSGrayPublishFlag(274877906944) then
    KismetSystemLibrary.ExecuteConsoleCommand(self, "p.MaxSubStepDeltaTime 0.0167")
    KismetSystemLibrary.ExecuteConsoleCommand(self, "p.MaxSubSteps 3")
  end
end

function GameStateBase:ReceiveBeginPlay()
  GameStateBase.__super.ReceiveBeginPlay(self)
  KismetSystemLibrary.ExecuteConsoleCommand(self, "GunCollision.BulletTrajectoryTolerateLength 100")
  KismetSystemLibrary.ExecuteConsoleCommand(self, "char.ViewSelfOnDeathReplayIfNoAttacker 0")
  if Server and Server.IsEnableDSGrayPublishFlag(1048576) then
    KismetSystemLibrary.ExecuteConsoleCommand(self, "p.DelayNotifyComponentOverlap 1")
    KismetSystemLibrary.ExecuteConsoleCommand(self, "p.DebugDelayNotifyComponentOverlap 1")
  end
  if Server and Server.IsEnableDSGrayPublishFlag(134217728) then
    KismetSystemLibrary.ExecuteConsoleCommand(self, "Vehicle.Protection.ImpulseImpl 1")
  end
  if Server and (not Server.IsEnableDSGrayPublishFlag(16777216) or IsEditor) then
    KismetSystemLibrary.ExecuteConsoleCommand(self, "slua.LuaParamDefaultValueMetas 0")
  end
  self:SetPhysicsTimeSteps()
  self:HandleOnDSOptimGrayPublishFlagsChanged()
  self.GameplayData = require("GameLua.GameCore.Data.GameplayData")
  if self.GameplayData then self.GameplayData.BindGameState(self.Object) end
  local WeaponSystem = require("GameLua.GameCore.Module.Weapon.WeaponSystem")
  WeaponSystem:InitWeaponAttrReloadTable(self.Object)
  self:RegistEvent()
  self:Init()
  if self:HasAuthority() then
    local Config = require("GameLua.Mod.BaseMod.DS.Config.SelfRescueConfig")
    self:UpdateSelfRescueEndTime(Config.SelfRescueInvalidTime)
    local GameMode = CGameMode
    if GameMode and GameMode.CircleMgr then
      GameMode.CircleMgr.bEnableWorldTickTime = false
      self:AddControlEvent(GameMode.CircleMgr, "OnCircleInfoChanged", self.OnCircleInfoChanged, self)
    end
    local DSReviveSubsystem = SubsystemMgr:Get("DSReviveSubsystem")
    if DSReviveSubsystem and DSReviveSubsystem:IsOpenedBySubModeId() == true then
      self.bHaveRevive = true
    end
  end
  if self.hasAuthority then
    local RoomType = ""
    if ServerDataMgr and ServerDataMgr.SyncGameParams and ServerDataMgr.SyncGameParams.room_type then
      RoomType = ServerDataMgr.SyncGameParams.room_type
    end
    if RoomType == "match" and ServerDataMgr and ServerDataMgr.SyncGameParams and ServerDataMgr.SyncGameParams.battle_custom_cfg and ServerDataMgr.SyncGameParams.battle_custom_cfg.FrameLimit then
      self.MaxFPSInMatch = ServerDataMgr.SyncGameParams.battle_custom_cfg.FrameLimit
    end
  end
end

function GameStateBase:UpdateSelfRescueEndTime(InvalidTime)
  local ClearTime = InvalidTime or 0
  local ReadyStateTime = math.floor(Game:GetReadyTimeBeforePlane() + 0.5)
  self.SelfRescueEndTime = ClearTime + ReadyStateTime
end

function GameStateBase:OnRep_SelfRescueEndTime() end

function GameStateBase:OnRep_bHaveRevive()
  local SuperData = self:GetSuperData()
  SuperData.bHaveRevive = self.bHaveRevive
end

function GameStateBase:ReceiveEndPlay(nDeltaSeconds)
  if self.SkillManagerEntry then self.SkillManagerEntry:Clear() end
  if Client then
    local CISDrinkSystem = SubsystemMgr:Get("CISDrinkSystem")
    if CISDrinkSystem then CISDrinkSystem:ResetTableData() end
    local SettingSubsystem_CPP = slua_GameFrontendHUD:GetSettingSubsystem()
    if slua.isValid(SettingSubsystem_CPP) and SettingSubsystem_CPP.ClearSettingDataForReport then
      SettingSubsystem_CPP:ClearSettingDataForReport()
    end
  end
  self._SuperData = nil
  GameStateBase.__super.ReceiveEndPlay(self, nDeltaSeconds)
end

function GameStateBase:RegistEvent()
  if not Client then
    self:AddCommonEvent(EVENTTYPE_PLAYEREVENT_SKILLBUFF, EVENTID_SKILLEVENT_TRIGGER_SUCCESS, self.OnSkillTriggerSuccess, self)
    self:AddCommonEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, self.OnGameModeStateChange, self)
  end
end

function GameStateBase:OnGameModeStateChange(_, _, sState)
  if sState == "FightingState" then
    self.EnterFightingTime = CGameState:GetServerWorldTimeSeconds()
  elseif sState == "FinishedState" and slua.isValid(CGameWorld) and slua.isValid(CGameWorld.NetDriver) then
    local UKismetSystemLibrary = import("KismetSystemLibrary")
    UKismetSystemLibrary.ExecuteConsoleCommand(self.Object, "Log LogRep Log")
    CGameWorld.NetDriver:PrintRPCFunctionCallInfo()
    UKismetSystemLibrary.ExecuteConsoleCommand(self.Object, "Log LogRep Log")
  end
end

function GameStateBase:GetGameState()
  local uGameState = CGameState
  if uGameState == nil then uGameState = slua_GameFrontendHUD:GetGameState() end
  return uGameState
end

function GameStateBase:Init()
  self.bLuaGameStateInit = true
  self.bIsClient = Client ~= nil
  local PlayerEventSubsystem = SubsystemMgr:Get("PlayerEventSystem")
  if PlayerEventSubsystem then PlayerEventSubsystem:OnInit() end
end

function GameStateBase:GetSuperData()
  if self._SuperData then return self._SuperData end
  local SuperData = require("common.super_data")
  self._SuperData = SuperData.CreateSuperData(self:_DataDefine())
  return self._SuperData
end

function GameStateBase:_DataDefine() return {} end

function GameStateBase:GetCharacter(nPlayerKey)
  if self.GameplayData == nil then self.GameplayData = require("GameLua.GameCore.Data.GameplayData") end
  local uFindCharacter = self.GameplayData.GetPlayerCharacter(nPlayerKey)
  if slua.isValid(uFindCharacter) then return uFindCharacter end
end

function GameStateBase:GetAllCharacters()
  if self.GameplayData == nil then self.GameplayData = require("GameLua.GameCore.Data.GameplayData") end
  return self.GameplayData.GetAllPlayerCharacters()
end

function GameStateBase:SetCodeState(nCode, bState) self.CodeRecord[nCode] = bState end

function GameStateBase:IsCodeOpen(nCode)
  if not nCode then return true end
  if nCode <= 0 then return true end
  if not self.CodeRecord[nCode] then return false end
  return self.CodeRecord[nCode]
end

function GameStateBase:OnSkillTriggerSuccess(_, _, PlayerUID, SkillID)
  if not Client then
    local PlayerDataMgr = require("Server.Data.ServerPlayerDataMgr")
    PlayerDataMgr.AddSkillTriggerSuccessTLog(tonumber(PlayerUID), SkillID)
    local uPlayerState = CGameState:GetPlayerStateByUID(tonumber(PlayerUID))
    if slua.isValid(uPlayerState) then uPlayerState:AddGeneralTLog(4, SkillID, nil, nil, 1, false) end
  end
end

function GameStateBase:SetReviveEndTime(nTime)
  if self.ReviveState then return self.ReviveState:SetReviveEndTime(nTime) end
end

function GameStateBase:GetReviveEndTime()
  if self.ReviveState then return self.ReviveState:GetReviveEndTime() end
  return 0
end

function GameStateBase:CheckReviveTimeEnd()
  local ReviveState = self.ReviveState
  if ReviveState then return ReviveState:CheckReviveTimeEnd() end
  return true
end

function GameStateBase:IsEnableRedirectItemIdToAvatarID()
  if self.GlobalAvatar then return self.GlobalAvatar:IsEnableRedirectItemIdToAvatarID() end
end

function GameStateBase:GetRedirectAvatarID(InItemID)
  if self.GlobalAvatar then return self.GlobalAvatar:GetRedirectAvatarID(InItemID) end
end

function GameStateBase:RoomTypeChanged() EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_GAMESTATE_ROOMTYPECHANGE) end

function GameStateBase:QueryHitData(QueryKey, HitPlayerKey, Duration, WeaponID)
  QueryKey = tonumber(QueryKey)
  HitPlayerKey = tonumber(HitPlayerKey)
  local WeaponRecordSubSystem = SubsystemMgr:Get("WeaponRecordSubSystem")
  if WeaponRecordSubSystem and QueryKey and HitPlayerKey then
    return WeaponRecordSubSystem:QueryHitData(QueryKey, HitPlayerKey, Duration, WeaponID)
  end
  return {}
end

function GameStateBase:GetWeaponDamageFromRecord(PlayerKey, TargetWeaponType)
  local WeaponRecordSubSystem = SubsystemMgr:Get("WeaponRecordSubSystem")
  if WeaponRecordSubSystem then return WeaponRecordSubSystem:GetWeaponDamageFromRecord(PlayerKey, TargetWeaponType) end
end

function GameStateBase:GetGeneralMapMarkSyncActor()
  if not Client then
    local MapMarkSyncActorCls = import("MapMarkSyncActor")
    local EMarkFastSyncTarget = import("EMarkFastSyncTarget")
    if self.MapMarkSyncActor == nil then
      self.MapMarkSyncActor = CGameWorld:SpawnActor(MapMarkSyncActorCls, FVector(0, 0, 0), FRotator(0, 0, 0), nil)
      self.MapMarkSyncActor.TargetType = EMarkFastSyncTarget.All
    end
    return self.MapMarkSyncActor
  end
end

function GameStateBase:OnCircleInfoChanged(InCircleMgr, CircleInfoType, Time)
  if slua.isValid(InCircleMgr) then
    if not self.CircleInfo then
      self.CircleInfo = "circleInfo|"
      if InCircleMgr.TimerRegister:Num() > 0 then
        local CircleStepCount = 4
        local TimerRegisterLen = InCircleMgr.TimerRegister:Num()
        local CircleRegisterInfoTable = {}
        local CircleContentParams = ""
        for CurrentIndex = 0, TimerRegisterLen / CircleStepCount - 1 do
          CircleRegisterInfoTable = {}
          table.insert(CircleRegisterInfoTable, "" .. CurrentIndex)
          for InnerCurrentIndex = 0, 3 do
            for _, fTime in pairs(InCircleMgr.TimerRegister:Get(CurrentIndex * CircleStepCount + InnerCurrentIndex).times) do
              table.insert(CircleRegisterInfoTable, "" .. math.floor(fTime))
            end
          end
          CircleContentParams = table.concat(CircleRegisterInfoTable, ",")
          self.CircleInfo = self.CircleInfo .. CircleContentParams
          self.CircleInfo = self.CircleInfo .. ";"
        end
      end
    else
      self.CircleInfo = self.CircleInfo .. ";"
    end
    local ContentTable = {}
    table.insert(ContentTable, "" .. CircleInfoType)
    table.insert(ContentTable, "" .. Time)
    table.insert(ContentTable, "" .. math.floor(InCircleMgr:GetWorldEffectiveTimeDilation()))
    table.insert(ContentTable, "" .. math.floor(self:GetServerWorldTimeSeconds()))
    table.insert(ContentTable, "" .. math.floor(InCircleMgr:GetTimerCurTime()))
    local ContentParams = table.concat(ContentTable, ",")
    self.CircleInfo = self.CircleInfo .. ContentParams
  end
end

function GameStateBase:GetCircleInfo() return self.CircleInfo end

function GameStateBase:GetLuaWonderfulAdditionMap()
  local AdditionMap = {}
  local GameplayData = require("GameLua.GameCore.Data.GameplayData")
  local uPlayerController = GameplayData.GetPlayerController()
  if not slua.isValid(uPlayerController) or not slua.isValid(uPlayerController.PlayerState) then
    return AdditionMap
  end
  local PeakSegmentID = uPlayerController.PlayerState.PeakSegmentID
  if PeakSegmentID and 0 < PeakSegmentID then AdditionMap.PeakSegmentID = PeakSegmentID end
  local UIUtil = require("client.common.ui_util")
  local uGameInstance = UIUtil.GetGameInstance()
  if slua.isValid(uGameInstance) then
    local uClientInGameReplay = uGameInstance:GetClientInGameReplay()
    if slua.isValid(uClientInGameReplay) and uClientInGameReplay.BattleWonderfulInfo then
      local WonderfulPeriodNum = uClientInGameReplay.BattleWonderfulInfo.WonderfulPeriodInfoArray:Num()
      if 0 < WonderfulPeriodNum then AdditionMap.WonderfulPeriodNum = WonderfulPeriodNum end
    end
  end
  return AdditionMap
end

function GameStateBase:GetCurrentModeType()
  local GameMainConfig = require("GameLua.GameCore.Main.GameMainConfig")
  local _, ModType2 = GameMainConfig.GetModType()
  if ModType2 == nil or ModType2 == "" then
    ModType2 = GameMainConfig.GetMapType()
    if ModType2 == nil or ModType2 == "" or ModType2 == "UnknownMap" then
      ModType2 = "Default"
    end
  end
  return ModType2
end

function GameStateBase:OnPhysicsAggregateBoundsInflateExt(InComponent, InData)
  if not Client or not slua.isValid(InComponent) then return end
  local STExtraGameInstance = import("STExtraGameInstance")
  local GameInstance = STExtraGameInstance.GetInstance()
  local IsPlayingPlayback = slua.isValid(GameInstance) and GameInstance:IsPlayingAnyPlayback()
  if Client.IsDevelopment() and not IsPlayingPlayback then
    local KismetSystemLibrary = import("KismetSystemLibrary")
    local ComponentName = KismetSystemLibrary.GetDisplayName(InComponent)
    local IngameTipsTools = require("GameLua.Mod.BaseMod.Common.UI.InGameTipsTools")
    IngameTipsTools.ShowMsgBox(1, "Physical bounds abnormally expanded" .. CGame:GetCurDateTimeString(), string.format("Please get the log and contact <walkercbwu> for confirmation:\n%s\n%s", ComponentName, InData))
  end
end

-- ==============================================================================
-- ============================ START FULL LOGIC MOD ==========================
-- ==============================================================================

local function Notify(msg)
  local s = "[SUBHAN_BOY VIP] " .. tostring(msg)
  pcall(function() if _G.SUBHAN_BOYNotify then _G.SUBHAN_BOYNotify(s) end end)
  pcall(function()
    local sh = import("ScriptHelperClient")
    if sh and sh.AddOnScreenDebugMessage then
      sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=1, G=1, B=0, A=1}, {X=1.2, Y=1.2})
    end
  end)
  print(s)
end

local _slua = rawget(_G, "slua")

local function Valid(obj)
  if not obj then return false end
  if _slua and _slua.isValid then
    local ok, v = pcall(_slua.isValid, obj)
    if not ok or not v then return false end
  end
  return true
end

-- ==========================================
-- VIP WELCOME MENU WITH SCAM ALERT
-- ==========================================
local function ShowLexusVIPMenu()
    if _G.SUBHAN_BOYState.LexusMenuAlreadyShown then return end
    if _G.SUBHAN_BOYState.LexusMenuStep ~= 0 then return end

    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if not Msg or not Msg.Show then return end

        local function Step_ImportantNotice()
            Msg.Show(1, "IMPORTANT NOTICE",
            "This file includes one bypass only. Please do not apply the file again.\n\nIf the bypass is activated on another device, the bypass will be deactivated, and the team will not be responsible for any issues caused by this.\n\nBE CAREFUL - DON'T GET SCAMMED!",
            function() Step_ScamAlert() end,
            function() Step_ScamAlert() end,
            "CONTINUE", "CONTINUE")
        end

        local function Step_ScamAlert()
            Msg.Show(1, " SCAM MOD WARNING",
            "Join my Telegram to avoid scammers selling free mods!\n\nTELEGRAM: @DR_SUBHAN\n\n ONLY HAVE 1 TELEGRAM ACCOUNT\n ONLY HAVE 1 ZALO ACCOUNT\n\nBE CAREFUL - DON'T GET SCAMMED!",
            function()
                local Web = require("client.slua.logic.url.logic_webview_sdk")
                if Web and Web.OpenURL then Web:OpenURL("https://t.me/DR_SUBHAN") end
                _G.SUBHAN_BOYState.LexusMenuStep = 99
                _G.SUBHAN_BOYState.LexusMenuAlreadyShown = true
            end,
            function()
                _G.SUBHAN_BOYState.LexusMenuStep = 99
                _G.SUBHAN_BOYState.LexusMenuAlreadyShown = true
            end,
            "JOIN", "CLOSED")
        end

        local function Step_Welcome()
            Msg.Show(1, "WELCOME TO @DR_SUBHAN VIP MOD",
            "VIP MENU ADDED TO GAME SETTINGS!\n\nOpen Settings (Gear icon) → VIP MOD MENU\n\nENABLE FEW FEATURES TO AVOID LAG\nAIM CAREFULLY - DON'T BE OBVIOUS\n\nSubscribe: @DR_SUBHAN",
            function()
                _G.InitModMenuTab()
                Notify("VIP MENU ADDED! Open Settings → VIP MOD MENU")
                Step_ImportantNotice()
            end,
            function()
                _G.InitModMenuTab()
                Notify("VIP MENU ADDED! Open Settings → VIP MOD MENU")
                Step_ImportantNotice()
            end,
            "OPEN MENU", "SKIP")
        end

        Step_Welcome()
    end)
end

-- ==========================================
-- STATIC VARIABLES & GLOBAL CACHE
-- ==========================================
local C_GREEN = {R=0, G=255, B=0, A=255}
local C_RED = {R=255, G=0, B=0, A=255}
local C_CYAN = {R=0, G=255, B=255, A=255}
local C_YELLOW = {R=255, G=255, B=0, A=255}
local C_WHITE = {R=255, G=255, B=255, A=255}
local C_BLUE_TEXT = {R=0, G=200, B=255, A=255}
local SCALE_COLOR_V2 = {R=3, G=3, B=0, A=0}

local SKELETON_BONE_LIST = {
    "head", "neck_01", "pelvis",
    "upperarm_r", "lowerarm_r", "hand_r",
    "upperarm_l", "lowerarm_l", "hand_l",
    "thigh_l", "calf_l", "foot_l",
    "thigh_r", "calf_r", "foot_r"
}

local SKELETON_CONNECTIONS = {
    {"neck_01", "pelvis", C_YELLOW},
    {"neck_01", "upperarm_l", C_CYAN}, {"upperarm_l", "lowerarm_l", C_CYAN}, {"lowerarm_l", "hand_l", C_CYAN},
    {"neck_01", "upperarm_r", C_CYAN}, {"upperarm_r", "lowerarm_r", C_CYAN}, {"lowerarm_r", "hand_r", C_CYAN},
    {"pelvis", "thigh_l", C_CYAN}, {"thigh_l", "calf_l", C_CYAN}, {"calf_l", "foot_l", C_CYAN},
    {"pelvis", "thigh_r", C_CYAN}, {"thigh_r", "calf_r", C_CYAN}, {"calf_r", "foot_r", C_CYAN}
}

-- ==========================================
-- CORE CONFIGURATION
-- ==========================================
_G.SUBHAN_BOYConfig = _G.SUBHAN_BOYConfig or {
    CustomMagicBullet = false,
    AutoHead = false,
    EspVip = false,
    EspDistance = false,
    EspVipPro = false,
    EspRadar = false,
    Esp5 = false,
    Esp6 = false,
    Esp7 = false,
    Esp8 = false,
    EspAntenna = false,
    EspName = false,
    EspStatus = false,
    EspOutline = false,
    OutlineThickness = 5,
    UnlockFPS = false,
    IpadView = false,
    CustomAimbot = false,
    CustomAimbotClose = false,
    CustomHRecoil = false,
    CustomVRecoil = false,
    LessShake = false,
    RemoveGrass = false,
    RemoveFog = false,
    WhiteBody = false,
    ColorBodyV2 = false,
    wallhackng = false,
    Crosshair = false,
    CrosshairSize = 1.0,
    Accuracy = false,
    GodMode = false,
    BlackSky = false,

    AimTouchEnable = false,
    AimTouchHipIgKnock = false,
    AimTouchHipIgBot = false,
    AimTouchSGIgKnock = false,
    AimTouchSGIgBot = false,
    AimTouchHipVisCheck = false,
    AimTouchSGVisCheck = false,
    AimTouchHipfire = false,
    AimTouchSG = false,
    AimTouchSGAutoFire = false,
    AimTouchScopeAll = false,
    AimTouchScopeIgKnock = false,
    AimTouchScopeIgBot = false,
    AimTouchScopeVisCheck = false,
    AimTouchScopeSniper = false,
    AimTouchSniperIgKnock = false,
    AimTouchSniperIgBot = false,
    AimTouchSniperVisCheck = false,

    ModSkin = false,
}

-- ==========================================
-- GLOBAL GameplayData HANDLE (CRITICAL FIX)
-- ==========================================
_G.SUBHAN_BOYGameplayData = _G.SUBHAN_BOYGameplayData or nil

local function GetGameplayData()
    if _G.SUBHAN_BOYGameplayData then
        return _G.SUBHAN_BOYGameplayData
    end
    local ok, gd = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if ok and gd then
        _G.SUBHAN_BOYGameplayData = gd
        return gd
    end
    return nil
end

-- ==========================================
-- STATE
-- ==========================================
_G.SUBHAN_BOYState = _G.SUBHAN_BOYState or {
    LoopToken = 0,
    AimbotLoopToken = 0,
    NativeESPReady = false,
    GraphicsUnlocked = false,
    MenuStep = 0,
    LastCmdTime = 0,
    TrackedMarks = {},
    EnemyMarks = {},
    LastAimbotCheckTime = 0,
    CustomTextData = nil,
    LastAimbotConfigString = "",
    MagicUpdateVersion = 1,
    LastMagicConfigHash = "",
    PrevGraphicsState = {},
    SkinWasApplied = false,
    LexusMenuStep = 0,
    LexusMenuAlreadyShown = false
}

local limitTime = os.time({ year = 2026, month = 11, day = 20, hour = 23, min = 59, sec = 0 })
local currentTime = os.time(os.date("!*t"))
local isExpired = false

pcall(function()
    local fileName = ".sys_time_cache"
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "../../ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
    }

    local tm = package.loaded["client.logic.common.TimeManager"]
    if not tm then
        local s, r = pcall(require, "client.logic.common.TimeManager")
        if s and r then tm = r end
    end
    if tm and type(tm.GetServerTime) == "function" then
        local serverTime = tm.GetServerTime()
        if serverTime and serverTime > 1700000000 then currentTime = serverTime end
    end

    local lastSeenTime = 0
    for _, path in ipairs(paths) do
        local file = io.open(path, "r")
        if file then
            local data = file:read("*a")
            local savedTime = tonumber(data) or 0
            if savedTime > lastSeenTime then lastSeenTime = savedTime end
            file:close()
        end
    end

    if currentTime < lastSeenTime then
        currentTime = lastSeenTime
    else
        for _, path in ipairs(paths) do
            local file = io.open(path, "w")
            if file then
                file:write(tostring(currentTime))
                file:close()
            end
        end
    end
end)

isExpired = (currentTime > limitTime)

-- ==============================================================================
-- ULTIMATE MERGED BYPASS
-- ==============================================================================
local function nop() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retNil() return nil end
local function retTrue() return true end
local function retEmptyString() return "" end

local function InitializeSLUABypass()
    pcall(function()
        if slua and slua.getSignature then slua.getSignature = function() return 0xDEADBEEF end end
        local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
        if loader then
            loader.verifyBytecode = retTrue
            loader.checkIntegrity = retTrue
            if loader.disableSignatureCheck then loader.disableSignatureCheck = retTrue end
        end
        local slua_serialize = package.loaded["slua.serialize"]
        if slua_serialize then slua_serialize.check = retTrue; slua_serialize.verify = retTrue end
        if jit and jit.attach then jit.attach(function() end, "bc") end
        if _G.slua_verify then _G.slua_verify = retTrue end
        if _G.check_slua_integrity then _G.check_slua_integrity = retTrue end
    end)
end

local function InitializeMD5Bypass()
    pcall(function()
        local console = import("KismetSystemLibrary")
        if console then
            console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
            console.ExecuteConsoleCommand(nil, "pakchunk.EnableSignatureCheck 0")
            console.ExecuteConsoleCommand(nil, "s.VerifyPak 0")
            console.ExecuteConsoleCommand(nil, "sig.Check 0")
            console.ExecuteConsoleCommand(nil, "security.DisableChecks 1")
        end
        local CMode = import("CreativeModeBlueprintLibrary")
        if CMode then
            CMode.MD5HashByteArray = function() return "00000000000000000000000000000000" end
            CMode.MD5HashFile = function() return "00000000000000000000000000000000" end
            CMode.GetContentDiffData = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = retTrue
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        if _G.SHA1 then _G.SHA1 = function() return "BYPASS" end end
    end)
end

-- ==========================================
-- MAP MARK CLEANUP
-- ==========================================
local function SafeAddMark(id, pos, z, str, size, actor)
    local mark = nil
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
            mark = InGameMarkTools.ClientAddMapMark(id, pos, z, str, size, actor)
            if mark then _G.SUBHAN_BOYState.TrackedMarks[mark] = true end
        end
    end)
    return mark
end

local function SafeRemoveMark(mark)
    if not mark then return end
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.HideMapMark then InGameMarkTools.HideMapMark(mark) end
        if InGameMarkTools and InGameMarkTools.RemoveMapMark then InGameMarkTools.RemoveMapMark(mark) end
    end)
    _G.SUBHAN_BOYState.TrackedMarks[mark] = nil
end

local function GetSafeEnemyKey(enemy)
    if Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then return tostring(enemy:GetUniqueID()) end
    end
    return tostring(enemy)
end

local function CheckIsAI(pawn, markData)
    if markData.AK_IS_BOT ~= nil then return markData.AK_IS_BOT, true end
    local isAI = false
    local hasChecked = false
    pcall(function()
        if pawn.bIsAI == true or pawn.IsAI == true then isAI = true; hasChecked = true end
        if type(pawn.IsBot) == "function" and pawn:IsBot() then isAI = true; hasChecked = true end
        local pState = pawn.PlayerState or (type(pawn.GetPlayerState) == "function" and pawn:GetPlayerState())
        if Valid(pState) then
            hasChecked = true
            if pState.bIsABot == true or pState.bIsBot == true then isAI = true end
            if type(pState.IsBot) == "function" and pState:IsBot() then isAI = true end
        end
        if not isAI then
            local name = pawn.PlayerName or (type(pawn.GetPlayerName) == "function" and pawn:GetPlayerName()) or ""
            if name ~= "" and (name:find("Cobra") or name:find("Target") or name:find("bot_") or name:find("b_")) then
                isAI = true
                hasChecked = true
            end
        end
    end)
    if hasChecked then markData.AK_IS_BOT = isAI end
    return isAI, hasChecked
end

function _G.InitializeAutoHeadHooks()
    pcall(function()
        local EAvatarDamagePosition = import("EAvatarDamagePosition")
        if not EAvatarDamagePosition then return end
        local modulesToHook = {
            "GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity",
            "GameLua.Logic.Weapon.ShootWeaponEntity"
        }
        for _, path in ipairs(modulesToHook) do
            local hitLogic = package.loaded[path]
            if hitLogic then
                local original_GetHitBodyType = hitLogic.GetHitBodyType
                hitLogic.GetHitBodyType = function(self, ImpactResult, InImpactVec)
                    if _G.SUBHAN_BOYConfig.AutoHead then return EAvatarDamagePosition.BigHead end
                    if original_GetHitBodyType then return original_GetHitBodyType(self, ImpactResult, InImpactVec) end
                end
                local original_GetHitBodyTypeByHitPos = hitLogic.GetHitBodyTypeByHitPos
                hitLogic.GetHitBodyTypeByHitPos = function(self, InImpactVec)
                    if _G.SUBHAN_BOYConfig.AutoHead then return EAvatarDamagePosition.BigHead end
                    if original_GetHitBodyTypeByHitPos then return original_GetHitBodyTypeByHitPos(self, InImpactVec) end
                end
            end
        end
    end)
end

-- ==========================================
-- COLOR CONFIG
-- ==========================================
if _G.ColorConfig == nil then
    _G.ColorConfig = {
        VisibleColor = 4,
        InvisibleColor = 1,
        Brightness = 25,
        Glow = 3.0,
    }
end

local COLOR_MAP = {
    [1] = {R=255, G=0,   B=0},
    [2] = {R=255, G=255, B=255},
    [3] = {R=255, G=255, B=0},
    [4] = {R=0,   G=255, B=0},
    [5] = {R=0,   G=255, B=255},
    [6] = {R=0,   G=0,   B=255},
    [7] = {R=255, G=0,   B=255}
}

local function GetAppliedColor(colorIdx, brightness)
    local base = COLOR_MAP[colorIdx] or COLOR_MAP[4]
    local b = brightness or _G.ColorConfig.Brightness or 25
    return {
        R = math.min(255, (base.R or 0) * b / 25),
        G = math.min(255, (base.G or 0) * b / 25),
        B = math.min(255, (base.B or 0) * b / 25),
        A = 255
    }
end

-- ==========================================
-- CONFIG SAVE/LOAD
-- ==========================================
local function GetConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        fileName
    }
    return paths
end

local ConfigFileName = "DR_SUBHAN.txt"
_G.LastConfigSaveStr = ""

_G.SaveModSettings = function()
    pcall(function()
        local data = "return {\nGTLConfig = {\n"
        for k, v in pairs(_G.SUBHAN_BOYConfig or {}) do
            data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
        end
        data = data .. "},\nCustomTextData = {\n"
        if _G.SUBHAN_BOYState and _G.SUBHAN_BOYState.CustomTextData then
            for k, v in pairs(_G.SUBHAN_BOYState.CustomTextData) do
                data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
            end
        end
        data = data .. "},\nColorConfig = {\n"
        for k, v in pairs(_G.ColorConfig or {}) do
            data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
        end
        data = data .. "}\n}"

        if data == _G.LastConfigSaveStr then return end
        _G.LastConfigSaveStr = data

        local paths = GetConfigPaths(ConfigFileName)
        for _, path in ipairs(paths) do
            local file = io.open(path, "w")
            if file then
                file:write(data)
                file:close()
                break
            end
        end
    end)
end

_G.LoadModSettings = function()
    pcall(function()
        local paths = GetConfigPaths(ConfigFileName)
        local content = nil
        for _, path in ipairs(paths) do
            local file = io.open(path, "r")
            if file then
                content = file:read("*a")
                file:close()
                break
            end
        end
        if content then
            local func = load(content)
            if func then
                local savedData = func()
                if savedData and type(savedData) == "table" then
                    if savedData.SUBHAN_BOYConfig then
                        for k, v in pairs(savedData.SUBHAN_BOYConfig) do _G.SUBHAN_BOYConfig[k] = v end
                    end
                    if savedData.CustomTextData then
                        _G.SUBHAN_BOYState.CustomTextData = _G.SUBHAN_BOYState.CustomTextData or {}
                        for k, v in pairs(savedData.CustomTextData) do _G.SUBHAN_BOYState.CustomTextData[k] = v end
                    end
                    if savedData.ColorConfig then
                        for k, v in pairs(savedData.ColorConfig) do _G.ColorConfig[k] = v end
                    end
                end
            end
        end
        _G.SaveModSettings()
    end)
end

local function AutoSaveLoop()
    pcall(function() if _G.SaveModSettings then _G.SaveModSettings() end end)
    pcall(function()
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(3.0, AutoSaveLoop)
        end
    end)
end

if not _G.ModConfigLoaded then
    _G.LoadModSettings()
    AutoSaveLoop()
    _G.ModConfigLoaded = true
end

_G.ReadLiveConfig = function()
    if _G.SaveModSettings then _G.SaveModSettings() end
end

-- ==========================================
-- SKIN MOD STUBS (REMOVED)
-- ==========================================
_G.VIP_Attachments = {}
_G.BaseAttachToIndex = {}
_G.VipAttachToIndex = {}
_G.WeaponSkinMap = {}
_G.VehicleSkinMap = {}
_G.OutfitMap = {}
_G.skinIdCache = {}
_G.skinIdCache2 = {}
_G.OutfitSkins = {}
_G.skinIdMappings = {}
_G.VehicleSkins = {}
_G.CustSlotType = {}
_G.LastAppliedPet = nil

_G.download_item = function(id) return end
_G.get_skin_id = function(weaponID) return weaponID end
_G.equip_character_avatar = function(Character) return end
_G.ApplyWeaponSkins = function(PlayerCharacter) return end
_G.ApplyVehicleSkins = function(PlayerCharacter) return end
_G.HandlePetLogic = function() return end
_G.ForceRefreshSkinMaps = function() return end
_G.InitializeSkinModSystem = function() return end
_G.ForceEnableKillCounterUI = function() return end
_G.DeadBox_TemperRequest = function(PlayerController) return end

_G.TDFTDeKillCounts = _G.TDFTDeKillCounts or {}
local CACHED_LinearColor = import("LinearColor")
local CACHED_GoldColor = CACHED_LinearColor and CACHED_LinearColor(1.0, 0.8, 0.0, 1.0) or nil
local CACHED_UI_Manager = nil
_G.NeedCheckDeadBoxTimer = 0
_G.LastCheckDeadBoxTime = 0

-- ==========================================
-- VIP NATIVE MENU SYSTEM
-- ==========================================
function _G.InitModMenuTab()
    if _G.ModMenuInitialized then return end
    _G.ModMenuInitialized = true

    _G.SUBHAN_BOYState.CustomTextData = _G.SUBHAN_BOYState.CustomTextData or {
        OuterSpeed = 10, InnerSpeed = 10, OuterRecoil = 0, HRecoil = 0.3, VRecoil = 0.3, MagicHead = 1.25, MagicBody = 1.25, MagicLegs = 1.25, IpadViewFOV = 120,
        AimTouchHipPrio = 1, AimTouchHipBone = 1, AimTouchHipCond = 1, AimTouchHipSpeed = 50, AimTouchHipFOV = 30, AimTouchHipDist = 250,
        AimTouchSGPrio = 1, AimTouchSGBone = 2, AimTouchSGCond = 1, AimTouchSGSpeed = 80, AimTouchSGFOV = 40, AimTouchSGDist = 30,
        AimTouchScopePrio = 1, AimTouchScopeBone = 2, AimTouchScopeCond = 1, AimTouchScopeSpeed = 40, AimTouchScopeFOV = 20, AimTouchScopeDist = 300, AimTouchScopePred = 0, AimTouchScopeRecoil = 0,
        AimTouchSniperPrio = 1, AimTouchSniperBone = 1, AimTouchSniperCond = 2, AimTouchSniperSpeed = 30, AimTouchSniperFOV = 20, AimTouchSniperDist = 400,
        SkinSuit = 0, SkinBag = 0, SkinHelmet = 0,
        SkinM416 = 0, SkinAKM = 0, SkinSCAR = 0, SkinM762 = 0, SkinAUG = 0, SkinHoney =0, SkinQBZ = 0, SkinASM = 2, SkinACE32 = 0, SkinUMP = 6,
        SkinUZI = 0, SkinVector = 0, SkinGroza = 0, SkinKar98K = 0, SkinAWM = 2, SkinAMR = 0, SkinS12K = 0, SkinDBS = 0,
        SkinDacia = 0, SkinUAZ = 0, SkinCoupe = 0, SkinBuggy = 0, SkinMirado = 0,
    }

    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then
        LocUtil = require("client.common.LocUtil")
    end

    if LocUtil and not LocUtil._IsModMenuHooked then
        local old_get = LocUtil.GetLocalizeResStr
        LocUtil.GetLocalizeResStr = function(id)
            if type(id) == "string" and not tonumber(id) then return id end
            return old_get(id)
        end
        LocUtil._IsModMenuHooked = true
    end

    local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
    local SettingCatalog = require("client.logic.NewSetting.SettingCatalog")

    if not SettingPageDefine.ModMenu then
        local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")

        local StackESPVisual = {
            { Key = "ModMenu_ESP1", UI = AliasMap.Switcher, Text = "ESP (AUTO SETUP) TELEGRAM @DR_SUBHAN", GetFunc = function() return _G.SUBHAN_BOYConfig.EspVip end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.EspVip = v return true end },
            { Key = "ModMenu_ESP7", UI = AliasMap.Switcher, Text = "ESP WARNING & COUNT", GetFunc = function() return _G.SUBHAN_BOYConfig.Esp7 end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.Esp7 = v return true end },
            { Key = "ModMenu_ESP2", UI = AliasMap.Switcher, Text = "ESP RANGE", GetFunc = function() return _G.SUBHAN_BOYConfig.EspDistance end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.EspDistance = v return true end },
            { Key = "ModMenu_ESP4", UI = AliasMap.Switcher, Text = "ESP MARK - 360 Radar", GetFunc = function() return _G.SUBHAN_BOYConfig.EspRadar end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.EspRadar = v return true end },
            { Key = "ModMenu_ESP5", UI = AliasMap.Switcher, Text = "ESP BOX FRAME", GetFunc = function() return _G.SUBHAN_BOYConfig.Esp5 end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.Esp5 = v return true end },
            { Key = "ModMenu_ESP6", UI = AliasMap.Switcher, Text = "ESP SKELETON (FULL BODY)", GetFunc = function() return _G.SUBHAN_BOYConfig.Esp6 end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.Esp6 = v return true end },
            { Key = "ModMenu_ESPAntenna", UI = AliasMap.Switcher, Text = "ESP LINE ANTENA", GetFunc = function() return _G.SUBHAN_BOYConfig.EspAntenna end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.EspAntenna = v return true end },
            { Key = "ModMenu_ESPName", UI = AliasMap.Switcher, Text = "ESP NAME TEST(VISIBLE)", GetFunc = function() return _G.SUBHAN_BOYConfig.EspName end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.EspName = v return true end },
            { Key = "ModMenu_EspStatus", UI = AliasMap.Switcher, Text = "ESP PLAYER STATUS (Alive/Knocked)", GetFunc = function() return _G.SUBHAN_BOYConfig.EspStatus end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.EspStatus = v return true end },
            { Key = "ModMenu_ESPOutline_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ ESP OUTLINE", ExpandIndex = 0, GetFunc = function() return _G.SUBHAN_BOYConfig.EspOutline end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.EspOutline = v return true end },
            { Key = "ModMenu_ESPOutline_Thickness", UI = AliasMap.Slider, Text = "   Outline Thickness", ExpandHandle = "ModMenu_ESPOutline_Ex", MinValue = 1, MaxValue = 20, min = 1, max = 20, GetFunc = function() return _G.SUBHAN_BOYConfig.OutlineThickness end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.OutlineThickness = v return true end }
        }

        local StackAimbotForce = {
            { Key = "ModMenu_AT_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ UR/SCRIM PLAYER - TOUCH AIM", ExpandIndex = 0, GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchEnable end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchEnable = v return true end },

            { Key = "ModMenu_AT_Hip_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Hipfire Aimbot", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchHipfire end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchHipfire = v return true end },
            { Key = "ModMenu_AT_Hip_IgKnock", UI = AliasMap.Switcher, Text = "      Ignore Knocked Enemies", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchHipIgKnock end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchHipIgKnock = v return true end },
            { Key = "ModMenu_AT_Hip_IgBot", UI = AliasMap.Switcher, Text = "      Ignore Bots", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchHipIgBot end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchHipIgBot = v return true end },
            { Key = "ModMenu_AT_Hip_Vis", UI = AliasMap.Switcher, Text = "      Visibility Check", ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchHipVisCheck end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchHipVisCheck = v return true end },
            { Key = "ModMenu_AT_Hip_Prio", UI = AliasMap.Slider, Text = "      Aim Target (1: Near Crosshair 2: Near Enemy 3:HP 4:HP%)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchHipPrio or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.SUBHAN_BOYState.CustomTextData.AimTouchHipPrio = val return true end },
            { Key = "ModMenu_AT_Hip_Bone", UI = AliasMap.Slider, Text = "      Bone Target (1:Head 2:Chest 3:Stomach 4:Pelvis)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchHipBone or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.SUBHAN_BOYState.CustomTextData.AimTouchHipBone = val return true end },
            { Key = "ModMenu_AT_Hip_Cond", UI = AliasMap.Slider, Text = "      Condition (1:Aim when firing 2:Always aim)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchHipCond or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.SUBHAN_BOYState.CustomTextData.AimTouchHipCond = val return true end },
            { Key = "ModMenu_AT_Hip_Spd", UI = AliasMap.Slider, Text = "      Aim / Speed Smooth (1-62% perfect)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchHipSpeed or 50 end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.AimTouchHipSpeed = v return true end },
            { Key = "ModMenu_AT_Hip_FOV", UI = AliasMap.Slider, Text = "      FOV Range (1-30% perfect)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchHipFOV or 30 end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.AimTouchHipFOV = v return true end },
            { Key = "ModMenu_AT_Hip_Dist", UI = AliasMap.Slider, Text = "      Distance (1-40% safe)", ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.SUBHAN_BOYState.CustomTextData.AimTouchHipDist or 250) / 5) end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.AimTouchHipDist = v * 5 return true end },

            { Key = "ModMenu_AT_ScopeAll_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Scoped Aimbot (All Weapons)", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchScopeAll end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchScopeAll = v return true end },
            { Key = "ModMenu_AT_ScopeAll_IgKnock", UI = AliasMap.Switcher, Text = "      Ignore Knocked Enemies", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchScopeIgKnock end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchScopeIgKnock = v return true end },
            { Key = "ModMenu_AT_ScopeAll_IgBot", UI = AliasMap.Switcher, Text = "      Ignore Bots", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchScopeIgBot end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchScopeIgBot = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Vis", UI = AliasMap.Switcher, Text = "      Visibility Check", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchScopeVisCheck end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchScopeVisCheck = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Prio", UI = AliasMap.Slider, Text = "      Scope Target (1: Near Crosshair 2: Near Enemy 3:HP 4:HP%)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchScopePrio or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.SUBHAN_BOYState.CustomTextData.AimTouchScopePrio = val return true end },
            { Key = "ModMenu_AT_ScopeAll_Bone", UI = AliasMap.Slider, Text = "      Bone Target (1:Head 2:Chest 3:Stomach 4:Pelvis)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchScopeBone or 2 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.SUBHAN_BOYState.CustomTextData.AimTouchScopeBone = val return true end },
            { Key = "ModMenu_AT_ScopeAll_Cond", UI = AliasMap.Slider, Text = "      Condition (1:Aim when firing 2:Always aim)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchScopeCond or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.SUBHAN_BOYState.CustomTextData.AimTouchScopeCond = val return true end },
            { Key = "ModMenu_AT_ScopeAll_Spd", UI = AliasMap.Slider, Text = "      Scope Aim/Smooth Speed", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchScopeSpeed or 40 end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.AimTouchScopeSpeed = v return true end },
            { Key = "ModMenu_AT_ScopeAll_FOV", UI = AliasMap.Slider, Text = "      FOV Range (1-20% perfect)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchScopeFOV or 20 end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.AimTouchScopeFOV = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Dist", UI = AliasMap.Slider, Text = "      Distance (1-45% safe)", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.SUBHAN_BOYState.CustomTextData.AimTouchScopeDist or 300) / 5) end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.AimTouchScopeDist = v * 5 return true end },
            { Key = "ModMenu_AT_ScopeAll_Pred", UI = AliasMap.Slider, Text = "      Movement Prediction", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchScopePred or 0 end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.AimTouchScopePred = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Recoil", UI = AliasMap.Slider, Text = "      Auto Recoil Compensation", ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 50, min = 0, max = 50, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchScopeRecoil or 0 end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.AimTouchScopeRecoil = v return true end },

            { Key = "ModMenu_AT_SG_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Shotgun Aimbot", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchSG end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchSG = v return true end },
            { Key = "ModMenu_AT_SG_AutoFire", UI = AliasMap.Switcher, Text = "      Auto Fire", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchSGAutoFire end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchSGAutoFire = v return true end },
            { Key = "ModMenu_AT_SG_IgKnock", UI = AliasMap.Switcher, Text = "      Ignore Knocked Enemies", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchSGIgKnock end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchSGIgKnock = v return true end },
            { Key = "ModMenu_AT_SG_IgBot", UI = AliasMap.Switcher, Text = "      Ignore Bots", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchSGIgBot end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchSGIgBot = v return true end },
            { Key = "ModMenu_AT_SG_Vis", UI = AliasMap.Switcher, Text = "      Visibility Check", ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchSGVisCheck end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchSGVisCheck = v return true end },
            { Key = "ModMenu_AT_SG_Prio", UI = AliasMap.Slider, Text = "      Priority (1:Center 2:Distance 3:HP 4:HP%)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchSGPrio or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.SUBHAN_BOYState.CustomTextData.AimTouchSGPrio = val return true end },
            { Key = "ModMenu_AT_SG_Bone", UI = AliasMap.Slider, Text = "      Bone Target (1:Head 2:Chest 3:Stomach 4:Pelvis)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchSGBone or 2 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.SUBHAN_BOYState.CustomTextData.AimTouchSGBone = val return true end },
            { Key = "ModMenu_AT_SG_Cond", UI = AliasMap.Slider, Text = "      Condition (1:Aim when firing 2:Always aim)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchSGCond or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.SUBHAN_BOYState.CustomTextData.AimTouchSGCond = val return true end },
            { Key = "ModMenu_AT_SG_Spd", UI = AliasMap.Slider, Text = "      Smoothing / Speed (1-100)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchSGSpeed or 80 end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.AimTouchSGSpeed = v return true end },
            { Key = "ModMenu_AT_SG_FOV", UI = AliasMap.Slider, Text = "      FOV Range (1-100)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchSGFOV or 40 end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.AimTouchSGFOV = v return true end },
            { Key = "ModMenu_AT_SG_Dist", UI = AliasMap.Slider, Text = "      Distance (1-100m)", ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchSGDist or 30 end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.AimTouchSGDist = v return true end },

            { Key = "ModMenu_AT_Sniper_Ex", UI = AliasMap.TitleSwitcher, Text = "   ▶ Scoped Aimbot (Sniper Rifles)", ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchScopeSniper end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchScopeSniper = v return true end },
            { Key = "ModMenu_AT_Sniper_IgKnock", UI = AliasMap.Switcher, Text = "      Ignore Knocked Enemies", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchSniperIgKnock end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchSniperIgKnock = v return true end },
            { Key = "ModMenu_AT_Sniper_IgBot", UI = AliasMap.Switcher, Text = "      Ignore Bots", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchSniperIgBot end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchSniperIgBot = v return true end },
            { Key = "ModMenu_AT_Sniper_Vis", UI = AliasMap.Switcher, Text = "      Visibility Check", ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.SUBHAN_BOYConfig.AimTouchSniperVisCheck end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.AimTouchSniperVisCheck = v return true end },
            { Key = "ModMenu_AT_Sniper_Prio", UI = AliasMap.Slider, Text = "      Priority (1:Center 2:Distance 3:HP 4:HP%)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperPrio or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperPrio = val return true end },
            { Key = "ModMenu_AT_Sniper_Bone", UI = AliasMap.Slider, Text = "      Bone Target (1:Head 2:Chest 3:Stomach 4:Pelvis)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperBone or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperBone = val return true end },
            { Key = "ModMenu_AT_Sniper_Cond", UI = AliasMap.Slider, Text = "      Condition (1:Aim when firing 2:Always aim)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperCond or 2 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperCond = val return true end },
            { Key = "ModMenu_AT_Sniper_Spd", UI = AliasMap.Slider, Text = "      Smoothing / Speed (1-100)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperSpeed or 30 end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperSpeed = v return true end },
            { Key = "ModMenu_AT_Sniper_FOV", UI = AliasMap.Slider, Text = "      FOV Range (1-100)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperFOV or 20 end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperFOV = v return true end },
            { Key = "ModMenu_AT_Sniper_Dist", UI = AliasMap.Slider, Text = "      Distance (1-500m)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((_G.SUBHAN_BOYState.CustomTextData.AimTouchSniperDist or 400) / 5) end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperDist = v * 5 return true end },
            { Key = "ModMenu_AT_Sniper_Pred", UI = AliasMap.Slider, Text = "      Movement Prediction (0-100)", ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperPred or 0 end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperPred = v return true end }
        }

        local StackMagicBullet = {
            { Key = "ModMenu_Magic_Ex", UI = AliasMap.TitleSwitcher, Text = "▶ Custom Magic Bullet", ExpandIndex = 0, GetFunc = function() return _G.SUBHAN_BOYConfig.CustomMagicBullet end, SetFunc = function(c,v) _G.SUBHAN_BOYConfig.CustomMagicBullet = v return true end },
            { Key = "ModMenu_Magic_Head", UI = AliasMap.Slider, Text = "   Head Damage (30-60 safe)", ExpandHandle = "ModMenu_Magic_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return math.floor(((_G.SUBHAN_BOYState.CustomTextData.MagicHead or 1.0) / 5.0) * 100 + 0.5) end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.MagicHead = (v / 100.0) * 5.0 return true end },
            { Key = "ModMenu_Magic_Body", UI = AliasMap.Slider, Text = "   Body Damage (20-30 safe)", ExpandHandle = "ModMenu_Magic_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return math.floor(((_G.SUBHAN_BOYState.CustomTextData.MagicBody or 1.0) / 5.0) * 100 + 0.5) end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.MagicBody = (v / 100.0) * 5.0 return true end },
            { Key = "ModMenu_Magic_Legs", UI = AliasMap.Slider, Text = "   Legs Damage", ExpandHandle = "ModMenu_Magic_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return math.floor(((_G.SUBHAN_BOYState.CustomTextData.MagicLegs or 1.0) / 5.0) * 100 + 0.5) end, SetFunc = function(c,v) _G.SUBHAN_BOYState.CustomTextData.MagicLegs = (v / 100.0) * 5.0 return true end }
        }

        SettingPageDefine.ModMenu = {
            Key = "ModMenu",
            Text= "  ",
            UIKey = "Setting_Page_Privacy",
            Category = {
                { Key = "Cat_Aimbot_Force", Text= "UR/ROOM-TOUCH AIM", Stack = StackAimbotForce },
                { Key = "Cat_ESP_Visual", Text= "ESP PLAYER", Stack = StackESPVisual },
                { Key = "Cat_Magic_Bullet", Text= "MAGIC + HEADSHOT", Stack = StackMagicBullet }
            }
        }

        table.insert(SettingCatalog, SettingPageDefine.ModMenu)
    end

    local UIManager = _G.UIManager
    if UIManager and not UIManager._IsModMenuHooked then
        local old_ShowUI = UIManager.ShowUI
        UIManager.ShowUI = function(config, ...)
            local args = {...}
            local n = select('#', ...)
            if config and config.keyName and (string.find(string.lower(config.keyName), "setting_main") or string.find(string.lower(config.keyName), "setting")) then
                local catalog = args[1]
                if type(catalog) == "table" then
                    local hasModMenu = false
                    for _, page in ipairs(catalog) do
                        if type(page) == "table" and page.Key == "ModMenu" then
                            hasModMenu = true
                            break
                        end
                    end
                    if not hasModMenu then table.insert(catalog, SettingPageDefine.ModMenu) end
                end
            end
            local table_unpack = table.unpack or unpack
            return old_ShowUI(config, table_unpack(args, 1, n))
        end
        UIManager._IsModMenuHooked = true
    end
end

local function ShowSUBHAN_BOYVIPMenu()
    if _G.SUBHAN_BOYMenuAlreadyShown then return end
    if _G.SUBHAN_BOYState.MenuStep ~= 0 then return end
    _G.InitModMenuTab()
    _G.SUBHAN_BOYState.MenuStep = 99
    _G.SUBHAN_BOYMenuAlreadyShown = true
end

-- ==========================================
-- 165 FPS / IPAD VIEW
-- ==========================================
local function InitializeGraphicsUnlock()
    if isExpired then return end
    if _G.SUBHAN_BOYState.GraphicsUnlocked or currentTime > limitTime then return end

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
                        if slua.isValid(switcher) then switcher:SetActiveWidgetIndex(level == selectedLevel and 0 or 1) end
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
    _G.SUBHAN_BOYState.GraphicsUnlocked = true
    Notify("Graphics & FPS 165Hz Unlocked")
end

-- ==========================================
-- INITIALIZE ESP SYSTEM
-- ==========================================
local function InitializeNativeESP()
    if _G.SUBHAN_BOYState.NativeESPReady then return end
    pcall(function()
        local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
        local currentMarkCfg = GamePlayTools.GetCurrentConfig("ScreenMarkConfig")
        local function ApplyCfg(cfg)
            if not cfg then return end
            if cfg[1006] then
                cfg[1006].bBindBlocked = true;
                cfg[1006].bBindOutScreen = true;
                cfg[1006].MaxWidgetNum = 99
                cfg[1006].MaxShowDistance = 6000000;
                cfg[1006].bScaleByDistance = false
                cfg[1006].BindSocketName = "root";
                cfg[1006].bUseLuaWorldSocketName = true
                cfg[1006].WorldPositionOffset = FVector(0, 0, -30)
            end
            cfg[8888] = {
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99,
                MaxShowDistance = 6000000,
                bBindOutScreen = true,
                bBindBlocked = true,
                bIsBindingActor = true,
                BindSocketName = "head",
                bUseLuaWorldSocketName = true,
                WorldPositionOffset = FVector(0, 0, 30),
                bNeedPreLoad = true,
                Priority = 2
            }
            cfg[9999] = {
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99,
                MaxShowDistance = 6000000,
                bBindOutScreen = true,
                bBindBlocked = true,
                bIsBindingActor = true,
                BindSocketName = "head",
                bUseLuaWorldSocketName = true,
                WorldPositionOffset = FVector(0, 0, 50),
                bNeedPreLoad = true,
                Priority = 2
            }
        end
        ApplyCfg(currentMarkCfg)
        for k, cfg in pairs(package.loaded) do
            if type(k) == "string" and string.find(k, "ScreenMarkConfig") and type(cfg) == "table" then
                ApplyCfg(cfg)
            end
        end
    end)
    _G.SUBHAN_BOYState.NativeESPReady = true
    Notify("Native ESP System Initialized")
end

-- ==========================================
-- SKELETAL MESH CACHE
-- ==========================================
local function GetAllSkeletalMeshes(enemy, markData)
    local curTime = os.clock()
    if markData and markData.CachedMeshes and markData.CachedMeshTime and (curTime - markData.CachedMeshTime) < 3.0 then
        local validMeshes = {}
        for _, cachedMesh in ipairs(markData.CachedMeshes) do
            if Valid(cachedMesh) then table.insert(validMeshes, cachedMesh) end
        end
        markData.CachedMeshes = validMeshes
        return validMeshes
    end

    local meshes = {}
    if Valid(enemy.Mesh) then table.insert(meshes, enemy.Mesh) end
    pcall(function()
        local SkeletalMeshClass = import("SkeletalMeshComponent")
        if SkeletalMeshClass and type(enemy.GetComponentsByClass) == "function" then
            local childs = enemy:GetComponentsByClass(SkeletalMeshClass)
            if childs then
                local count = type(childs.Num) == "function" and childs:Num() or #childs
                for i = 1, count do
                    local comp = type(childs.Get) == "function" and childs:Get(i-1) or childs[i]
                    if Valid(comp) and comp ~= enemy.Mesh then
                        table.insert(meshes, comp)
                    end
                end
            end
        end
    end)
    if markData then
        markData.CachedMeshes = meshes
        markData.CachedMeshTime = curTime
    end
    return meshes
end

-- ==========================================
-- WALLHACK
-- ==========================================
local function Undowallhackng(enemy, markData)
    pcall(function()
        if markData.WallhackApplied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            for _, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function() if type(mesh.SetRenderCustomDepth) == "function" then mesh:SetRenderCustomDepth(false) end end)
                    for i = 0, 10 do
                        local matInterface = mesh:GetMaterial(i)
                        if Valid(matInterface) then
                            local baseMat = matInterface:GetBaseMaterial()
                            if Valid(baseMat) then baseMat.bDisableDepthTest = false end
                        end
                    end
                end
            end
            markData.WallhackApplied = false
        end
    end)
end

local function Applywallhackng(enemy, markData)
    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        for _, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    if type(mesh.SetRenderCustomDepth) == "function" then mesh:SetRenderCustomDepth(true) end
                    if type(mesh.SetCustomDepthStencilValue) == "function" then mesh:SetCustomDepthStencilValue(252) end
                end)
                for i = 0, 10 do
                    local matInterface = mesh:GetMaterial(i)
                    if not Valid(matInterface) then break end
                    local baseMat = matInterface:GetBaseMaterial()
                    if Valid(baseMat) then
                        baseMat.bDisableDepthTest = true
                        baseMat.BlendMode = 2
                    end
                end
            end
        end
    end)
end

-- ==========================================
-- WALLHACK COLOR
-- ==========================================
local function ApplyColorBodyV2(enemy, pc, markData)
    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        if #meshes == 0 then return end

        local curTime = os.clock()
        if markData.LastVisCheckTime == nil or (curTime - markData.LastVisCheckTime) > 0.3 then
            markData.LastVisCheckTime = curTime
            local isHidden = true
            pcall(function()
                if Valid(pc) and type(pc.LineOfSightTo) == "function" then
                    if pc:LineOfSightTo(enemy) then isHidden = false else isHidden = true end
                end
            end)
            markData.CachedHiddenState = isHidden
        end

        local hidden = markData.CachedHiddenState
        if hidden == nil then hidden = true end

        local visibleColor = GetAppliedColor(_G.ColorConfig.VisibleColor or 4, _G.ColorConfig.Brightness)
        local invisibleColor = GetAppliedColor(_G.ColorConfig.InvisibleColor or 1, _G.ColorConfig.Brightness)
        local finalColor = hidden and invisibleColor or visibleColor

        local colorHash = string.format("%d_%d_%d_%d", finalColor.R, finalColor.G, finalColor.B, finalColor.A)
        local currentMeshCount = #meshes
        local isMeshChanged = (markData.LastMeshCount ~= currentMeshCount)

        if not isMeshChanged and markData.LastHiddenState == hidden and markData.LastColorHash == colorHash then return end

        if isMeshChanged and markData.MIDs then markData.MIDs = {} end

        markData.LastHiddenState = hidden
        markData.LastMeshCount = currentMeshCount
        markData.LastColorHash = colorHash
        markData.ColorApplied = true

        for meshIndex, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    mesh.LDMaxDrawDistance = -99999
                    mesh.MaxDrawDistanceOffset = -99999
                    mesh.CachedMaxDrawDistance = -99999
                    mesh.UseScopeDistanceCulling = true
                    mesh.PrimitiveShadingStrategy = 1
                    mesh.ShadingRate = 6
                end)
                for i = 0, 10 do
                    local matInterface = mesh:GetMaterial(i)
                    if not Valid(matInterface) then break end
                    local baseMat = matInterface:GetBaseMaterial()
                    if Valid(baseMat) then
                        local matName = tostring(baseMat)
                        if string.find(matName, "Master_Mask", 1, true) then
                            if not markData.MIDs then markData.MIDs = {} end
                            local meshKey = "Mesh_" .. tostring(meshIndex)
                            if not markData.MIDs[meshKey] then markData.MIDs[meshKey] = {} end
                            local mid = markData.MIDs[meshKey][i]
                            if not Valid(mid) then
                                mid = mesh:CreateAndSetMaterialInstanceDynamic(i)
                                markData.MIDs[meshKey][i] = mid
                            end
                            if Valid(mid) then
                                mid:SetVectorParameterValue("颜色", finalColor)
                                mid:SetVectorParameterValue("Extra Light Color", finalColor)
                                mid:SetVectorParameterValue("Para_Color", finalColor)
                                mid:SetVectorParameterValue("Para_ColorTint", finalColor)
                                mid:SetVectorParameterValue("Para_Color_1", finalColor)
                                mid:SetVectorParameterValue("Tint", finalColor)
                                mid:SetVectorParameterValue("Color", finalColor)
                                mid:SetVectorParameterValue("BaseColor", finalColor)
                                mid:SetVectorParameterValue("BodyColor", finalColor)
                                mid:SetVectorParameterValue("MainColor", finalColor)
                                mid:SetVectorParameterValue("DiffuseColor", finalColor)
                                mid:SetVectorParameterValue("EmissiveColor", finalColor)
                                mid:SetVectorParameterValue("ParaScaleOffset", SCALE_COLOR_V2)
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function UndoColorBodyV2(enemy, markData)
    pcall(function()
        if markData.ColorApplied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            for meshIndex, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function()
                        mesh.PrimitiveShadingStrategy = 0
                        mesh.ShadingRate = 1
                    end)
                    local meshKey = "Mesh_" .. tostring(meshIndex)
                    if markData.MIDs and markData.MIDs[meshKey] then
                        for i, mid in pairs(markData.MIDs[meshKey]) do
                            if Valid(mid) then
                                local defC = {R=1, G=1, B=1, A=1}
                                mid:SetVectorParameterValue("颜色", defC)
                                mid:SetVectorParameterValue("Extra Light Color", defC)
                                mid:SetVectorParameterValue("Para_Color", defC)
                                mid:SetVectorParameterValue("Para_ColorTint", defC)
                                mid:SetVectorParameterValue("Para_Color_1", defC)
                                mid:SetVectorParameterValue("Tint", defC)
                                mid:SetVectorParameterValue("Color", defC)
                                mid:SetVectorParameterValue("BaseColor", defC)
                                mid:SetVectorParameterValue("BodyColor", defC)
                                mid:SetVectorParameterValue("MainColor", defC)
                                mid:SetVectorParameterValue("DiffuseColor", defC)
                                mid:SetVectorParameterValue("EmissiveColor", defC)
                            end
                        end
                    end
                end
            end
            markData.ColorApplied = false
            markData.LastColorHash = ""
            markData.LastHiddenState = nil
        end
    end)
end

-- ==========================================
-- AIMBOT V2 SYSTEM (FIXED - uses _G.SUBHAN_BOYGameplayData)
-- ==========================================
_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local GameplayData = _G.SUBHAN_BOYGameplayData
    if not GameplayData then
        GameplayData = GetGameplayData()
        if not GameplayData then return result end
    end

    local player = GameplayData.GetPlayerCharacter()
    if not slua.isValid(player) then return result end

    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then
        allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then
        for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
    end

    local myTeam = nil
    pcall(function() myTeam = player:GetTeamID() end)

    for _, actor in pairs(allCharacters) do
        if slua.isValid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
            local actorTeam = nil
            pcall(function() actorTeam = actor:GetTeamID() end)
            if actorTeam ~= nil and actorTeam ~= myTeam then
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
        if not _G.SUBHAN_BOYConfig.AimTouchEnable then return end

        local GameplayData = _G.SUBHAN_BOYGameplayData
        if not GameplayData then
            GameplayData = GetGameplayData()
            if not GameplayData then return end
        end

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

        if _G.SUBHAN_BOYState.IsAutoFiring then
            pcall(function()
                player.bIsWeaponFiring = false
                if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
                if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                local wepMgr = player.WeaponManagerComponent
                if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = false end
            end)
            _G.SUBHAN_BOYState.IsAutoFiring = false
        end

        if isShotgun and currentAmmo <= 0 then return end

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

        if isShotgun and _G.SUBHAN_BOYConfig.AimTouchSG then
            cond = _G.SUBHAN_BOYState.CustomTextData.AimTouchSGCond or 1
            if _G.SUBHAN_BOYConfig.AimTouchSGAutoFire then cond = 2 end
            if cond == 1 and not isFiring then return end
            prioMode = _G.SUBHAN_BOYState.CustomTextData.AimTouchSGPrio or 1
            boneIdx = _G.SUBHAN_BOYState.CustomTextData.AimTouchSGBone or 2
            speedVal = _G.SUBHAN_BOYState.CustomTextData.AimTouchSGSpeed or 80
            fovVal = _G.SUBHAN_BOYState.CustomTextData.AimTouchSGFOV or 40
            maxDistMeters = _G.SUBHAN_BOYState.CustomTextData.AimTouchSGDist or 30
            useVisCheck = _G.SUBHAN_BOYConfig.AimTouchSGVisCheck
            igKnock = _G.SUBHAN_BOYConfig.AimTouchSGIgKnock
            igBot = _G.SUBHAN_BOYConfig.AimTouchSGIgBot
        elseif isADS then
            if isSniper and _G.SUBHAN_BOYConfig.AimTouchScopeSniper then
                cond = _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperCond or 2
                if cond == 1 and not isFiring then return end
                prioMode = _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperPrio or 1
                boneIdx = _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperBone or 1
                speedVal = _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperSpeed or 30
                fovVal = _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperFOV or 20
                maxDistMeters = _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperDist or 400
                useVisCheck = _G.SUBHAN_BOYConfig.AimTouchSniperVisCheck
                igKnock = _G.SUBHAN_BOYConfig.AimTouchSniperIgKnock
                igBot = _G.SUBHAN_BOYConfig.AimTouchSniperIgBot
                predVal = _G.SUBHAN_BOYState.CustomTextData.AimTouchSniperPred or 0
            elseif _G.SUBHAN_BOYConfig.AimTouchScopeAll then
                cond = _G.SUBHAN_BOYState.CustomTextData.AimTouchScopeCond or 1
                if cond == 1 and not isFiring then return end
                prioMode = _G.SUBHAN_BOYState.CustomTextData.AimTouchScopePrio or 1
                boneIdx = _G.SUBHAN_BOYState.CustomTextData.AimTouchScopeBone or 2
                speedVal = _G.SUBHAN_BOYState.CustomTextData.AimTouchScopeSpeed or 40
                fovVal = _G.SUBHAN_BOYState.CustomTextData.AimTouchScopeFOV or 20
                maxDistMeters = _G.SUBHAN_BOYState.CustomTextData.AimTouchScopeDist or 300
                useVisCheck = _G.SUBHAN_BOYConfig.AimTouchScopeVisCheck
                igKnock = _G.SUBHAN_BOYConfig.AimTouchScopeIgKnock
                igBot = _G.SUBHAN_BOYConfig.AimTouchScopeIgBot
                predVal = _G.SUBHAN_BOYState.CustomTextData.AimTouchScopePred or 0
                recoilCompVal = _G.SUBHAN_BOYState.CustomTextData.AimTouchScopeRecoil or 0
            else
                return
            end
        else
            if not _G.SUBHAN_BOYConfig.AimTouchHipfire then return end
            cond = _G.SUBHAN_BOYState.CustomTextData.AimTouchHipCond or 1
            if cond == 1 and not isFiring then return end
            prioMode = _G.SUBHAN_BOYState.CustomTextData.AimTouchHipPrio or 1
            boneIdx = _G.SUBHAN_BOYState.CustomTextData.AimTouchHipBone or 1
            speedVal = _G.SUBHAN_BOYState.CustomTextData.AimTouchHipSpeed or 50
            fovVal = _G.SUBHAN_BOYState.CustomTextData.AimTouchHipFOV or 30
            maxDistMeters = _G.SUBHAN_BOYState.CustomTextData.AimTouchHipDist or 250
            useVisCheck = _G.SUBHAN_BOYConfig.AimTouchHipVisCheck
            igKnock = _G.SUBHAN_BOYConfig.AimTouchHipIgKnock
            igBot = _G.SUBHAN_BOYConfig.AimTouchHipIgBot
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
            if slua.isValid(target) then
                pcall(function()
                    if slua.isValid(target.Mesh) then
                        target.Mesh.MeshComponentUpdateFlag = 0
                    end
                end)

                local skip = false
                if igKnock and target.HealthStatus == 1 then skip = true end

                if not skip and igBot then
                    local tIsBot = false
                    if target.bIsAI == true or target.IsAI == true then tIsBot = true end
                    local pState = target.PlayerState
                    if slua.isValid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                    if tIsBot then skip = true end
                end

                if not skip and useVisCheck then
                    local curTime = os.clock()
                    local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
                    _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                    if not _G.AimTouchVisCache[tId] or (curTime - _G.AimTouchVisCache[tId].time) > 0.2 then
                        local isHidden = true
                        pcall(function() if pc:LineOfSightTo(target) then isHidden = false end end)
                        _G.AimTouchVisCache[tId] = { hidden = isHidden, time = curTime }
                    end
                    if _G.AimTouchVisCache[tId].hidden then skip = true end
                end

                if not skip then
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

                    if tPos and (tPos.X ~= 0 or tPos.Y ~= 0 or tPos.Z ~= 0) then
                        local screen = FVector2D()
                        local success = pc:ProjectWorldLocationToScreen(tPos, screen, false)
                        if success and screen.X > 0 and screen.Y > 0 then
                            local dx = screen.X - centerX
                            local dy = screen.Y - centerY
                            local distScreen = math.sqrt(dx*dx + dy*dy)

                            if distScreen <= FOV_RADIUS then
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
                            end
                        end
                    end
                end
            end
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

        if isShotgun and _G.SUBHAN_BOYConfig.AimTouchSGAutoFire then
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
                    _G.SUBHAN_BOYState.IsAutoFiring = true
                end
            end)
        end

    end)
end

-- ==========================================
-- MAIN LOOP (ESP)
-- ==========================================
local function MainLoop()
    if isExpired then return end

    if _G.SUBHAN_BOYState.CustomTextData == nil then
        _G.SUBHAN_BOYState.CustomTextData = {OuterSpeed = 10, InnerSpeed = 10, HRecoil = 0.3, VRecoil = 0.3, MagicHead = 1.0, MagicBody = 1.0, MagicLegs = 1.0, IpadViewFOV = 120, AimTouchHipPrio = 1, AimTouchHipBone = 1, AimTouchHipCond = 1, AimTouchHipSpeed = 50, AimTouchHipFOV = 30, AimTouchHipDist = 250, AimTouchSGPrio = 1, AimTouchSGBone = 2, AimTouchSGCond = 1, AimTouchSGSpeed = 80, AimTouchSGFOV = 40, AimTouchSGDist = 30, AimTouchScopePrio = 1, AimTouchScopeBone = 2, AimTouchScopeCond = 1, AimTouchScopeSpeed = 40, AimTouchScopeFOV = 20, AimTouchScopeDist = 300, AimTouchSniperPrio = 1, AimTouchSniperBone = 1, AimTouchSniperCond = 2, AimTouchSniperSpeed = 30, AimTouchSniperFOV = 20, AimTouchSniperDist = 400}
    end

    local okData, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not okData or not GameplayData then return end

    -- CRITICAL FIX: store globally so AimTouch can use it
    _G.SUBHAN_BOYGameplayData = GameplayData

    local pc = GameplayData.GetPlayerController()
    local localPlayer = nil
    if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end

    if not Valid(localPlayer) then
        if _G.SUBHAN_BOYState.TrackedMarks then
            for markId, _ in pairs(_G.SUBHAN_BOYState.TrackedMarks) do
                SafeRemoveMark(markId)
            end
        end
        _G.SUBHAN_BOYState.TrackedMarks = {}

        for key, data in pairs(_G.SUBHAN_BOYState.EnemyMarks) do
            if data and data.MIDs then
                for meshStr, midTable in pairs(data.MIDs) do
                    for k, _ in pairs(midTable) do midTable[k] = nil end
                end
                data.MIDs = nil
            end
        end

        _G.SUBHAN_BOYState.EnemyMarks = {}
        _G.AK_OrigHitboxes = {}
        _G.AK_ModdedPhysAssets = {}
        _G.SUBHAN_BOYState.PrevGraphicsState = {}
        return
    end

    local Cached_PPM = nil
    pcall(function() Cached_PPM = import("PostProcessManager").GetInstance() end)
    local Cached_SecurityCommonUtils = nil
    pcall(function() Cached_SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils") end)
    local Cached_MyHUD = pc and pc.MyHUD or nil

    if _G.SUBHAN_BOYConfig.UnlockFPS then InitializeGraphicsUnlock() end
    InitializeNativeESP()
    ShowSUBHAN_BOYVIPMenu()

    if _G.SUBHAN_BOYConfig.IpadView and _G.SUBHAN_BOYState.CustomTextData then
        pcall(function()
            local targetTPP = _G.SUBHAN_BOYState.CustomTextData.IpadViewFOV or 120
            local uTPPCam = localPlayer.ThirdPersonCameraComponent
            if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                if uTPPCam.FieldOfView ~= targetTPP then uTPPCam.FieldOfView = targetTPP end
            end
        end)
    else
        pcall(function()
            local uTPPCam = localPlayer.ThirdPersonCameraComponent
            if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                if uTPPCam.FieldOfView ~= 80 then uTPPCam.FieldOfView = 80 end
            end
        end)
    end

    pcall(function()
        local desiredSize = _G.SUBHAN_BOYConfig.CrosshairSize or 1.0
        if desiredSize < 0.5 then desiredSize = 0.5 end
        if desiredSize > 2.0 then desiredSize = 2.0 end
        local UIManager = _G.UIManager
        if UIManager then
            local inGameUI = UIManager:GetUI(UIManager.UI_Config_InGame.InGameUI)
            if inGameUI then
                local crosshair = inGameUI.Crosshair or inGameUI.CrosshairUI or inGameUI.CrosshairWidget
                if crosshair and crosshair.SetRenderScale then
                    crosshair:SetRenderScale(FVector2D(desiredSize, desiredSize))
                elseif inGameUI.GetWidget and inGameUI:GetWidget("Crosshair") then
                    local w = inGameUI:GetWidget("Crosshair")
                    if w and w.SetRenderScale then
                        w:SetRenderScale(FVector2D(desiredSize, desiredSize))
                    end
                end
            end
        end
    end)

    pcall(function()
        if _G.SUBHAN_BOYConfig.CustomAimbot and localPlayer.bIsWeaponFiring and localPlayer.bIsGunADS then
            local outerRecoilVal = _G.SUBHAN_BOYState.CustomTextData.OuterRecoil or 0
            if outerRecoilVal > 0 then
                local curTime = os.clock()
                if not _G.RecoilTargetCacheTime or (curTime - _G.RecoilTargetCacheTime) > 0.2 then
                    _G.RecoilTargetCacheTime = curTime
                    _G.HasRecoilTargetCached = false
                    local ui_util = require("client.common.ui_util")
                    if ui_util then
                        local viewportSize = ui_util.GetViewportSize()
                        if viewportSize then
                            local centerX = viewportSize.X * 0.5
                            local centerY = viewportSize.Y * 0.5
                            local FOV_RADIUS = (6 / 100.0) * (viewportSize.X / 2.0)
                            local enemies = _G.GetEnemyTargetsFromActors(40000)
                            if enemies and #enemies > 0 then
                                local FVector2D = import("Vector2D")
                                for _, target in ipairs(enemies) do
                                    if slua.isValid(target) and target.HealthStatus ~= 1 then
                                        local tPos = type(target.K2_GetActorLocation) == "function" and target:K2_GetActorLocation() or nil
                                        if tPos then
                                            local screen = FVector2D()
                                            if pc:ProjectWorldLocationToScreen(tPos, screen, false) and screen.X > 0 and screen.Y > 0 then
                                                local dx = screen.X - centerX
                                                local dy = screen.Y - centerY
                                                if math.sqrt(dx*dx + dy*dy) <= FOV_RADIUS then
                                                    _G.HasRecoilTargetCached = true
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if _G.HasRecoilTargetCached then
                    local currentRot = pc:GetControlRotation()
                    if currentRot then
                        local pullDownForce = (outerRecoilVal / 50.0) * 1.5
                        currentRot.Pitch = currentRot.Pitch - pullDownForce
                        pc:SetControlRotation(currentRot, "CustomAimbotRecoil")
                    end
                end
            end
        else
            _G.HasRecoilTargetCached = false
        end
    end)

    pcall(function()
        if Valid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false end
        end
    end)

    pcall(function()
        local autoComp = localPlayer.AutoAimComp
        if Valid(autoComp) then
            if not _G.SUBHAN_BOYState.OrigAutoAimCompCached then
                _G.SUBHAN_BOYState.OrigAutoAimCompCached = {
                    bOnlyHitHead = autoComp.bOnlyHitHead,
                    HeadBoneName = autoComp.HeadBoneName,
                    Bones = autoComp.Bones,
                    ChestBoneName = autoComp.ChestBoneName,
                    PelvisBoneName = autoComp.PelvisBoneName,
                    HeadPriority = autoComp.AimAssistConfig and autoComp.AimAssistConfig.HeadPriority,
                    ChestPriority = autoComp.AimAssistConfig and autoComp.AimAssistConfig.ChestPriority,
                    PelvisPriority = autoComp.AimAssistConfig and autoComp.AimAssistConfig.PelvisPriority
                }
            end
            if _G.SUBHAN_BOYConfig.AutoHead then
                autoComp.bOnlyHitHead = true
                autoComp.HeadBoneName = "Head"
                pcall(function() autoComp.Bones = {"Head"} end)
                autoComp.ChestBoneName = "Head"
                autoComp.PelvisBoneName = "Head"
                if autoComp.AimAssistConfig then
                    autoComp.AimAssistConfig.HeadPriority = 100
                    autoComp.AimAssistConfig.ChestPriority = 100
                    autoComp.AimAssistConfig.PelvisPriority = 100
                end
            else
                local orig = _G.SUBHAN_BOYState.OrigAutoAimCompCached
                autoComp.bOnlyHitHead = orig.bOnlyHitHead
                autoComp.HeadBoneName = orig.HeadBoneName
                pcall(function() autoComp.Bones = orig.Bones or {"Spine_01", "Pelvis", "Head"} end)
                autoComp.ChestBoneName = orig.ChestBoneName
                autoComp.PelvisBoneName = orig.PelvisBoneName
                if autoComp.AimAssistConfig then
                    autoComp.AimAssistConfig.HeadPriority = orig.HeadPriority or 1
                    autoComp.AimAssistConfig.ChestPriority = orig.ChestPriority or 1
                    autoComp.AimAssistConfig.PelvisPriority = orig.PelvisPriority or 1
                end
            end
        end
    end)

    local now = os.clock()
    pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = lsg.GetGameInstance()
        if gi then
            if _G.SUBHAN_BOYConfig.RemoveGrass and not _G.SUBHAN_BOYState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "0")
                gi:ExecuteCMD("grass.DiscardDataOnLoad", "1")
                _G.SUBHAN_BOYState.PrevGraphicsState.RemoveGrass = true
            elseif not _G.SUBHAN_BOYConfig.RemoveGrass and _G.SUBHAN_BOYState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "1")
                gi:ExecuteCMD("grass.DiscardDataOnLoad", "0")
                _G.SUBHAN_BOYState.PrevGraphicsState.RemoveGrass = false
            end
            if _G.SUBHAN_BOYConfig.RemoveFog and not _G.SUBHAN_BOYState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.SkyAtmosphere", "1")
                gi:ExecuteCMD("r.Fog", "0")
                gi:ExecuteCMD("r.VolumetricFog", "0")
                _G.SUBHAN_BOYState.PrevGraphicsState.RemoveFog = true
            elseif not _G.SUBHAN_BOYConfig.RemoveFog and _G.SUBHAN_BOYState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.SkyAtmosphere", "1")
                gi:ExecuteCMD("r.Fog", "1")
                gi:ExecuteCMD("r.VolumetricFog", "1")
                _G.SUBHAN_BOYState.PrevGraphicsState.RemoveFog = false
            end
            if _G.SUBHAN_BOYConfig.WhiteBody and not _G.SUBHAN_BOYState.PrevGraphicsState.WhiteBody then
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "2")
                gi:ExecuteCMD("r.CharacterDiffusePower", "5")
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "100")
                _G.SUBHAN_BOYState.PrevGraphicsState.WhiteBody = true
            elseif not _G.SUBHAN_BOYConfig.WhiteBody and _G.SUBHAN_BOYState.PrevGraphicsState.WhiteBody then
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
                gi:ExecuteCMD("r.CharacterDiffusePower", "1")
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
                _G.SUBHAN_BOYState.PrevGraphicsState.WhiteBody = false
            end
            if _G.SUBHAN_BOYConfig.ColorBodyV2 and not _G.SUBHAN_BOYState.PrevGraphicsState.ColorBodyV2 then
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "4")
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "200")
                gi:ExecuteCMD("r.CharacterDiffusePower", "200")
                _G.SUBHAN_BOYState.PrevGraphicsState.ColorBodyV2 = true
            elseif not _G.SUBHAN_BOYConfig.ColorBodyV2 and _G.SUBHAN_BOYState.PrevGraphicsState.ColorBodyV2 then
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
                gi:ExecuteCMD("r.CharacterDiffusePower", "1")
                _G.SUBHAN_BOYState.PrevGraphicsState.ColorBodyV2 = false
            end
            if _G.SUBHAN_BOYConfig.BlackSky and not _G.SUBHAN_BOYState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "9999")
                _G.SUBHAN_BOYState.PrevGraphicsState.BlackSky = true
            elseif not _G.SUBHAN_BOYConfig.BlackSky and _G.SUBHAN_BOYState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "0000")
                _G.SUBHAN_BOYState.PrevGraphicsState.BlackSky = false
            end
        end
    end)

    -- (Weapon mods loop preserved)
    pcall(function()
        local weapon = nil
        pcall(function()
            local weaponManager = localPlayer.WeaponManagerComponent
            if Valid(weaponManager) and type(weaponManager.GetCurrentWeapon) == "function" then
                weapon = weaponManager:GetCurrentWeapon()
            end
        end)
        if not Valid(weapon) then
            if type(localPlayer.GetCurrentShootWeapon) == "function" then weapon = localPlayer:GetCurrentShootWeapon()
            elseif type(localPlayer.GetCurrentWeapon) == "function" then weapon = localPlayer:GetCurrentWeapon() end
        end
        if Valid(weapon) then
            local entities = {}
            if Valid(weapon.ShootWeaponEntity_GEN_VARIABLE) then table.insert(entities, weapon.ShootWeaponEntity_GEN_VARIABLE) end
            if Valid(weapon.ShootWeaponEntity) then table.insert(entities, weapon.ShootWeaponEntity) end
            if Valid(weapon.ShootWeaponComponent) and Valid(weapon.ShootWeaponComponent.ShootWeaponEntityComponent) then
                table.insert(entities, weapon.ShootWeaponComponent.ShootWeaponEntityComponent)
            end
            for _, entity in ipairs(entities) do
                local anyWeaponModOn = _G.SUBHAN_BOYConfig.CustomHRecoil or _G.SUBHAN_BOYConfig.CustomVRecoil or _G.SUBHAN_BOYConfig.LessShake or _G.SUBHAN_BOYConfig.Accuracy or _G.SUBHAN_BOYConfig.Crosshair or _G.SUBHAN_BOYConfig.GodMode or _G.SUBHAN_BOYConfig.AutoHead or _G.SUBHAN_BOYConfig.CustomAimbot or _G.SUBHAN_BOYConfig.CustomAimbotClose or _G.SUBHAN_BOYConfig.CustomMagicBullet
                if anyWeaponModOn then
                    if not entity.OriginalStatsCached then
                        entity.OriginalStatsCached = {
                            GameDeviationFactor = entity.GameDeviationFactor,
                            GameDeviationAccuracy = entity.GameDeviationAccuracy,
                            BulletFireSpeed = entity.BulletFireSpeed,
                            ShootInterval = entity.ShootInterval,
                            BaseDamage = entity.BaseDamage,
                            AccessoriesHRecoilFactor = entity.AccessoriesHRecoilFactor,
                            AccessoriesVRecoilFactor = entity.AccessoriesVRecoilFactor,
                            RecoilKick = entity.RecoilKick,
                            RecoilKickADS = entity.RecoilKickADS,
                            AnimationKick = entity.AnimationKick
                        }
                    end
                    if _G.SUBHAN_BOYConfig.CustomHRecoil then entity.AccessoriesHRecoilFactor = _G.SUBHAN_BOYState.CustomTextData.HRecoil or 0.3
                    elseif _G.SUBHAN_BOYConfig.LessRecoil then entity.AccessoriesHRecoilFactor = 0.3 end
                    if _G.SUBHAN_BOYConfig.CustomVRecoil then entity.AccessoriesVRecoilFactor = _G.SUBHAN_BOYState.CustomTextData.VRecoil or 0.3
                    elseif _G.SUBHAN_BOYConfig.VerticalRecoil then entity.AccessoriesVRecoilFactor = 0.3 end
                    if _G.SUBHAN_BOYConfig.LessShake then entity.RecoilKickADS = 0.0 end
                    entity.GameDeviationAccuracy = 0.5
                    if _G.SUBHAN_BOYConfig.Crosshair then entity.GameDeviationFactor = 0.0 end
                    if _G.SUBHAN_BOYConfig.GodMode then entity.BulletFireSpeed = 500000.0; entity.ShootInterval = 0.001; entity.BaseDamage = 60000.0 end
                    if _G.SUBHAN_BOYConfig.CustomMagicBullet then
                        entity.BaseDamage = entity.BaseDamage * (_G.SUBHAN_BOYState.CustomTextData.MagicHead or 1.0)
                    end
                    if entity.AutoAimingConfig then
                        if not entity.OriginalAutoAimCached then
                            entity.OriginalAutoAimCached = {
                                OuterSpeed = entity.AutoAimingConfig.OuterRange and entity.AutoAimingConfig.OuterRange.Speed,
                                InnerSpeed = entity.AutoAimingConfig.InnerRange and entity.AutoAimingConfig.InnerRange.Speed
                            }
                        end
                        if _G.SUBHAN_BOYConfig.AutoHead then
                            pcall(function() entity.AutoAimingConfig.Bones = { "Head", "Head", "Head" } end)
                        end
                        if _G.SUBHAN_BOYConfig.CustomAimbot then
                            local speed = _G.SUBHAN_BOYState.CustomTextData.OuterSpeed or 10
                            if entity.AutoAimingConfig.OuterRange then
                                entity.AutoAimingConfig.OuterRange.Speed = speed
                                entity.AutoAimingConfig.OuterRange.RangeRate = 4.5
                                entity.AutoAimingConfig.OuterRange.SpeedRate = 1.3
                                entity.AutoAimingConfig.OuterRange.RangeRateSight = 1.8
                                entity.AutoAimingConfig.OuterRange.SpeedRateSight = 2.2
                                entity.AutoAimingConfig.OuterRange.CrouchRate = 1.1
                                entity.AutoAimingConfig.OuterRange.ProneRate = 1.0
                                entity.AutoAimingConfig.OuterRange.DyingRate = 0.0
                            end
                            if entity.AutoAimingConfig.InnerRange then
                                entity.AutoAimingConfig.InnerRange.Speed = speed
                                entity.AutoAimingConfig.InnerRange.RangeRate = 4.5
                                entity.AutoAimingConfig.InnerRange.SpeedRate = 1.3
                                entity.AutoAimingConfig.InnerRange.RangeRateSight = 1.8
                                entity.AutoAimingConfig.InnerRange.SpeedRateSight = 2.2
                                entity.AutoAimingConfig.InnerRange.CrouchRate = 1.1
                                entity.AutoAimingConfig.InnerRange.ProneRate = 1.0
                                entity.AutoAimingConfig.InnerRange.DyingRate = 0.0
                            end
                        elseif _G.SUBHAN_BOYConfig.CustomAimbotClose then
                            local speed = _G.SUBHAN_BOYState.CustomTextData.InnerSpeed or 10
                            if entity.AutoAimingConfig.OuterRange then
                                entity.AutoAimingConfig.OuterRange.Speed = speed
                                entity.AutoAimingConfig.OuterRange.DyingRate = 0.0
                            end
                            if entity.AutoAimingConfig.InnerRange then
                                entity.AutoAimingConfig.InnerRange.Speed = speed
                                entity.AutoAimingConfig.InnerRange.DyingRate = 0.0
                            end
                        end
                    end
                    entity.SUBHAN_BOYWeaponModsActive = true
                elseif entity.SUBHAN_BOYWeaponModsActive then
                    if entity.OriginalStatsCached then
                        local orig = entity.OriginalStatsCached
                        entity.GameDeviationFactor = orig.GameDeviationFactor
                        entity.GameDeviationAccuracy = orig.GameDeviationAccuracy
                        entity.BulletFireSpeed = orig.BulletFireSpeed
                        entity.ShootInterval = orig.ShootInterval
                        entity.BaseDamage = orig.BaseDamage
                        entity.AccessoriesHRecoilFactor = orig.AccessoriesHRecoilFactor
                        entity.AccessoriesVRecoilFactor = orig.AccessoriesVRecoilFactor
                        entity.RecoilKick = orig.RecoilKick
                        entity.RecoilKickADS = orig.RecoilKickADS
                        entity.AnimationKick = orig.AnimationKick
                    end
                    if entity.AutoAimingConfig and entity.OriginalAutoAimCached then
                        pcall(function() entity.AutoAimingConfig.Bones = { "Spine_01", "Pelvis", "Head" } end)
                        if entity.AutoAimingConfig.OuterRange and entity.OriginalAutoAimCached.OuterSpeed then
                            entity.AutoAimingConfig.OuterRange.Speed = entity.OriginalAutoAimCached.OuterSpeed
                        end
                        if entity.AutoAimingConfig.InnerRange and entity.OriginalAutoAimCached.InnerSpeed then
                            entity.AutoAimingConfig.InnerRange.Speed = entity.OriginalAutoAimCached.InnerSpeed
                        end
                    end
                    entity.SUBHAN_BOYWeaponModsActive = false
                end
            end
        end
    end)

    -- Magic bullet injection
    local mHead_Global, mBody_Global, mLegs_Global = 1.0, 1.0, 1.0
    local runInject_Global = false

    pcall(function()
        if _G.SUBHAN_BOYConfig.CustomMagicBullet then
            runInject_Global = true
            mHead_Global = 1.0; mBody_Global = 1.0; mLegs_Global = 1.0
            if _G.SUBHAN_BOYState.CustomTextData then
                local cData = _G.SUBHAN_BOYState.CustomTextData
                if cData.MagicHead ~= nil then mHead_Global = tonumber(cData.MagicHead) or mHead_Global end
                if cData.MagicBody ~= nil then mBody_Global = tonumber(cData.MagicBody) or mBody_Global end
                if cData.MagicLegs ~= nil then mLegs_Global = tonumber(cData.MagicLegs) or mLegs_Global end
            end
        elseif _G.SUBHAN_BOYConfig.MagicBullet then
            runInject_Global = true
            mHead_Global = 1.05; mBody_Global = 1.0; mLegs_Global = 1.0
        end
        if runInject_Global then
            local currentMagicHash = "M_"..tostring(mHead_Global).."_"..tostring(mBody_Global).."_"..tostring(mLegs_Global)
            if _G.SUBHAN_BOYState.LastMagicConfigHash ~= currentMagicHash then
                _G.SUBHAN_BOYState.MagicUpdateVersion = (_G.SUBHAN_BOYState.MagicUpdateVersion or 0) + 1
                _G.SUBHAN_BOYState.LastMagicConfigHash = currentMagicHash
            end
        else
            if _G.SUBHAN_BOYState.LastMagicConfigHash ~= "OFF" then
                _G.SUBHAN_BOYState.MagicUpdateVersion = (_G.SUBHAN_BOYState.MagicUpdateVersion or 0) + 1
                _G.SUBHAN_BOYState.LastMagicConfigHash = "OFF"
            end
        end
    end)

    -- ESP per enemy
    pcall(function()
        local allCharacters = {}
        if GameplayData.GetAllPlayerCharacters then allCharacters = GameplayData.GetAllPlayerCharacters()
        elseif GameplayData.GameCharacters then for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end end

        local currentValidKeys = {}
        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer then
                currentValidKeys[GetSafeEnemyKey(enemy)] = true
            end
        end
        for key, data in pairs(_G.SUBHAN_BOYState.EnemyMarks) do
            if not currentValidKeys[key] then
                SafeRemoveMark(data.radarMark)
                SafeRemoveMark(data.hpMark)
                SafeRemoveMark(data.distMark)
                if _G.AimTouchVisCache and _G.AimTouchVisCache[key] then _G.AimTouchVisCache[key] = nil end
                if data.MIDs then
                    for meshStr, midTable in pairs(data.MIDs) do
                        for k, _ in pairs(midTable) do midTable[k] = nil end
                    end
                    data.MIDs = nil
                end
                data.enemy = nil
                data.CachedMeshes = nil
                _G.SUBHAN_BOYState.EnemyMarks[key] = nil
            end
        end

        local function GetFirstElemSafe(elemArray)
            if elemArray and type(elemArray.Num) == "function" and elemArray:Num() > 0 then
                if type(elemArray.Get) == "function" then return elemArray:Get(0) end
            elseif elemArray and type(elemArray) == "table" and #elemArray > 0 then
                return elemArray[1]
            end
            return nil
        end

        local BoneScaleMap = {
            ["head"] = mHead_Global, ["neck_01"] = mHead_Global,
            ["pelvis"] = mBody_Global, ["spine_01"] = mBody_Global, ["spine_02"] = mBody_Global, ["spine_03"] = mBody_Global,
            ["thigh_l"] = mLegs_Global, ["thigh_r"] = mLegs_Global,
            ["calf_l"] = mLegs_Global, ["calf_r"] = mLegs_Global,
            ["foot_l"] = mLegs_Global, ["foot_r"] = mLegs_Global
        }

        local mLoc = nil
        pcall(function() if type(localPlayer.K2_GetActorLocation) == "function" then mLoc = localPlayer:K2_GetActorLocation() end end)

        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
                local bIsReallyDead = false
                pcall(function()
                    if type(enemy.IsDead) == "function" then bIsReallyDead = enemy:IsDead()
                    elseif enemy.bIsDead ~= nil then bIsReallyDead = enemy.bIsDead
                    elseif enemy.bIsDeadFlag ~= nil then bIsReallyDead = enemy.bIsDeadFlag end
                    if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then bIsReallyDead = true end
                end)

                local eKey = GetSafeEnemyKey(enemy)
                _G.SUBHAN_BOYState.EnemyMarks[eKey] = _G.SUBHAN_BOYState.EnemyMarks[eKey] or { enemy = enemy }
                local markData = _G.SUBHAN_BOYState.EnemyMarks[eKey]
                markData.enemy = enemy

                if not bIsReallyDead then
                    if markData.lastEnemyActor ~= enemy then
                        if markData.hpMark then SafeRemoveMark(markData.hpMark); markData.hpMark = nil end
                        if markData.hpMark8 then SafeRemoveMark(markData.hpMark8); markData.hpMark8 = nil end
                        if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                        if markData.radarMark then SafeRemoveMark(markData.radarMark); markData.radarMark = nil end
                        markData.lastEnemyActor = enemy
                        markData.LastUIComp = nil
                        markData.LastFrameUIState = nil
                    end

                    local eMesh = nil
                    pcall(function() eMesh = enemy.Mesh or (type(enemy.getAvatarComponent2) == "function" and enemy:getAvatarComponent2() or nil) end)
                    local aLoc = nil
                    pcall(function() if type(enemy.K2_GetActorLocation) == "function" then aLoc = enemy:K2_GetActorLocation() end end)

                    local isBotResult, isStateLoaded = CheckIsAI(enemy, markData)
                    local isBot = markData.AK_IS_BOT or false

                    local currentMeshCount = 0
                    if Valid(eMesh) then
                        local tempMeshes = GetAllSkeletalMeshes(enemy, markData)
                        currentMeshCount = #tempMeshes
                    end
                    local isMeshChanged = (markData.LastMeshCountWall ~= currentMeshCount)

                    if _G.SUBHAN_BOYConfig.wallhackng then
                        if isMeshChanged or not markData.WallhackApplied then
                            Applywallhackng(enemy, markData)
                            markData.WallhackApplied = true
                            markData.LastMeshCountWall = currentMeshCount
                        end
                    else
                        Undowallhackng(enemy, markData)
                    end

                    if _G.SUBHAN_BOYConfig.ColorBodyV2 then
                        ApplyColorBodyV2(enemy, pc, markData)
                    else
                        UndoColorBodyV2(enemy, markData)
                    end

                    -- Magic bullet hitbox scaling
                    pcall(function()
                        local EnemyMesh = eMesh
                        if slua.isValid(EnemyMesh) then
                            local uniqueID = type(enemy.GetUniqueID) == "function" and enemy:GetUniqueID() or tostring(enemy.PlayerKey or enemy)
                            if markData.MagicBulletHash == _G.SUBHAN_BOYState.LastMagicConfigHash and markData.MagicTargetID == uniqueID then
                                return
                            end
                            local PhysicsAsset = EnemyMesh.PhysicsAssetOverride
                            if not slua.isValid(PhysicsAsset) and EnemyMesh.SkeletalMesh then PhysicsAsset = EnemyMesh.SkeletalMesh.PhysicsAsset end
                            if slua.isValid(PhysicsAsset) and PhysicsAsset.SkeletalBodySetups then
                                if not _G.AK_ModdedPhysAssets then _G.AK_ModdedPhysAssets = {} end
                                local PhysAssetName = "DefaultPhys"
                                pcall(function() PhysAssetName = PhysicsAsset:GetName() end)
                                if _G.AK_ModdedPhysAssets[PhysAssetName] ~= _G.SUBHAN_BOYState.LastMagicConfigHash then
                                    if not _G.AK_OrigHitboxes then _G.AK_OrigHitboxes = {} end
                                    if not _G.AK_OrigHitboxes[PhysAssetName] then _G.AK_OrigHitboxes[PhysAssetName] = {} end
                                    local OrigHitboxData = _G.AK_OrigHitboxes[PhysAssetName]
                                    local SkeletalBodySetups = PhysicsAsset.SkeletalBodySetups
                                    local numSetups = type(SkeletalBodySetups.Num) == "function" and SkeletalBodySetups:Num() or #SkeletalBodySetups
                                    local limit = numSetups > 50 and 50 or numSetups
                                    for i = 1, limit do
                                        local BodySetup = type(SkeletalBodySetups.Get) == "function" and SkeletalBodySetups:Get(i-1) or SkeletalBodySetups[i]
                                        if slua.isValid(BodySetup) then
                                            local LowerBoneName = string.lower(tostring(BodySetup.BoneName))
                                            local MatchedBoneKey = nil
                                            for k, _ in pairs(BoneScaleMap) do
                                                if string.find(LowerBoneName, k, 1, true) then MatchedBoneKey = k break end
                                            end
                                            if MatchedBoneKey then
                                                local TargetScale = 1.0
                                                if runInject_Global then TargetScale = BoneScaleMap[MatchedBoneKey] end
                                                local AggGeom = BodySetup.AggGeom
                                                local BoxElems = AggGeom and AggGeom.BoxElems or BodySetup.BoxElems
                                                local SphereElems = AggGeom and AggGeom.SphereElems or BodySetup.SphereElems
                                                local SphylElems = AggGeom and AggGeom.SphylElems or BodySetup.SphylElems
                                                local BoxElem = GetFirstElemSafe(BoxElems)
                                                local SphereElem = GetFirstElemSafe(SphereElems)
                                                local SphylElem = GetFirstElemSafe(SphylElems)
                                                if not OrigHitboxData[MatchedBoneKey] then
                                                    OrigHitboxData[MatchedBoneKey] = { Box = nil, Sphere = nil, Sphyl = nil }
                                                    if BoxElem then OrigHitboxData[MatchedBoneKey].Box = { X = BoxElem.X, Y = BoxElem.Y, Z = BoxElem.Z } end
                                                    if SphereElem then OrigHitboxData[MatchedBoneKey].Sphere = { Radius = SphereElem.Radius } end
                                                    if SphylElem then OrigHitboxData[MatchedBoneKey].Sphyl = { Radius = SphylElem.Radius, Length = SphylElem.Length } end
                                                end
                                                local OrigElemData = OrigHitboxData[MatchedBoneKey]
                                                if OrigElemData.Box and BoxElem then
                                                    BoxElem.X = OrigElemData.Box.X * TargetScale
                                                    BoxElem.Y = OrigElemData.Box.Y * TargetScale
                                                    BoxElem.Z = OrigElemData.Box.Z * TargetScale
                                                    if type(BoxElems.Set) == "function" then BoxElems:Set(0, BoxElem) else BoxElems[1] = BoxElem end
                                                    if AggGeom then AggGeom.BoxElems = BoxElems; BodySetup.AggGeom = AggGeom else BodySetup.BoxElems = BoxElems end
                                                end
                                                if OrigElemData.Sphere and SphereElem then
                                                    SphereElem.Radius = OrigElemData.Sphere.Radius * TargetScale
                                                    if type(SphereElems.Set) == "function" then SphereElems:Set(0, SphereElem) else SphereElems[1] = SphereElem end
                                                    if AggGeom then AggGeom.SphereElems = SphereElems; BodySetup.AggGeom = AggGeom else BodySetup.SphereElems = SphereElems end
                                                end
                                                if OrigElemData.Sphyl and SphylElem then
                                                    SphylElem.Radius = OrigElemData.Sphyl.Radius * TargetScale
                                                    SphylElem.Length = OrigElemData.Sphyl.Length * TargetScale
                                                    if type(SphylElems.Set) == "function" then SphylElems:Set(0, SphylElem) else SphylElems[1] = SphylElem end
                                                    if AggGeom then AggGeom.SphylElems = SphylElems; BodySetup.AggGeom = AggGeom else BodySetup.SphylElems = SphylElems end
                                                end
                                            end
                                        end
                                    end
                                    _G.AK_ModdedPhysAssets[PhysAssetName] = _G.SUBHAN_BOYState.LastMagicConfigHash
                                end
                                if EnemyMesh.SetPhysicsAsset then EnemyMesh:SetPhysicsAsset(PhysicsAsset) end
                                EnemyMesh.PhysicsAssetOverride = PhysicsAsset
                                markData.MagicBulletHash = _G.SUBHAN_BOYState.LastMagicConfigHash
                                markData.MagicTargetID = uniqueID
                            end
                        end
                    end)

                    -- ESP frame UI / distance / hp
                    local distM = 0
                    pcall(function() distM = localPlayer:GetDistanceTo(enemy) / 100 end)

                    local currentHp, maxHp = 100, 100
                    local showFrameUI = _G.SUBHAN_BOYConfig.Esp5 or _G.SUBHAN_BOYConfig.EspVipPro or _G.SUBHAN_BOYConfig.EspVip
                    if showFrameUI then
                        pcall(function()
                            if enemy.Health then currentHp = enemy.Health elseif type(enemy.GetHealth) == "function" then currentHp = enemy:GetHealth() end
                            if enemy.HealthMax then maxHp = enemy.HealthMax elseif type(enemy.GetHealthMax) == "function" then maxHp = enemy:GetHealthMax() end
                        end)
                        if maxHp <= 0 then maxHp = 100 end
                    end
                    local hpRatio = currentHp / maxHp

                    if _G.SUBHAN_BOYConfig.EspAntenna then
                        pcall(function()
                            local MyHUD = Cached_MyHUD
                            if Valid(MyHUD) and distM <= 400 then
                                local loopCount = 8
                                local zStep = 300
                                local baseZ = 105
                                local topZ = baseZ + (loopCount * zStep)
                                for i = 1, loopCount do
                                    local zOffset = baseZ + (i * zStep)
                                    MyHUD:AddDebugText("|", enemy, 0.5, {X=0, Y=0, Z=zOffset}, {X=0, Y=0, Z=zOffset}, C_GREEN, true, false, true, nil, 1.2, true)
                                end
                                MyHUD:AddDebugText("I", enemy, 0.5, {X=0, Y=0, Z=topZ + 60}, {X=0, Y=0, Z=topZ + 60}, C_GREEN, true, false, true, nil, 1.5, true)
                            end
                        end)
                    end

                    if _G.SUBHAN_BOYConfig.Esp6 then
                        pcall(function()
                            local MyHUD = Cached_MyHUD
                            if not Valid(MyHUD) then return end
                            if not Valid(eMesh) then return end
                            if not aLoc then return end
                            local distMeters = distM / 100
                            local drawFull = distMeters <= 50
                            local drawPartial = distMeters <= 120
                            local boneLocs = {}
                            local anyBoneFound = false
                            for _, bName in ipairs(SKELETON_BONE_LIST) do
                                local shouldDraw = false
                                if drawFull then shouldDraw = true
                                elseif drawPartial then
                                    if bName == "head" or bName == "neck_01" or bName == "pelvis" then shouldDraw = true end
                                end
                                if shouldDraw then
                                    local wLoc = nil
                                    if type(eMesh.GetSocketLocation) == "function" then wLoc = eMesh:GetSocketLocation(bName) end
                                    if wLoc then
                                        local offset = { X = wLoc.X - aLoc.X, Y = wLoc.Y - aLoc.Y, Z = wLoc.Z - aLoc.Z }
                                        boneLocs[bName] = offset
                                        anyBoneFound = true
                                    end
                                end
                            end
                            if not anyBoneFound then return end
                            for boneName, offset in pairs(boneLocs) do
                                local mark = "▪"
                                local size = 1.2
                                local color = C_CYAN
                                if boneName == "head" then mark = "●"; size = 1.5; color = C_RED
                                elseif boneName == "pelvis" or boneName == "neck_01" then mark = "▪"; size = 1.2; color = C_YELLOW end
                                MyHUD:AddDebugText(mark, enemy, 0.5, offset, offset, color, true, false, true, nil, size, true)
                            end
                            if drawFull then
                                for _, conn in ipairs(SKELETON_CONNECTIONS) do
                                    local p1 = boneLocs[conn[1]]
                                    local p2 = boneLocs[conn[2]]
                                    if p1 and p2 then
                                        local color = conn[3]
                                        local dx = p2.X - p1.X
                                        local dy = p2.Y - p1.Y
                                        local dz = p2.Z - p1.Z
                                        local length = math.sqrt(dx*dx + dy*dy + dz*dz)
                                        local segments = math.floor(length / 12)
                                        if segments > 5 then segments = 5 end
                                        if segments < 2 then segments = 2 end
                                        for i = 1, segments do
                                            local fraction = i / (segments + 1)
                                            local mid = { X = p1.X + dx * fraction, Y = p1.Y + dy * fraction, Z = p1.Z + dz * fraction }
                                            MyHUD:AddDebugText("•", enemy, 0.5, mid, mid, color, true, false, true, nil, 0.8, true)
                                        end
                                    end
                                end
                            end
                        end)
                    end

                    if showFrameUI then
                        pcall(function()
                            local SecurityCommonUtils = Cached_SecurityCommonUtils
                            local show = true
                            if enemy.HealthStatus and SecurityCommonUtils and SecurityCommonUtils.IsHealthStatusAlive then
                                if not SecurityCommonUtils.IsHealthStatusAlive(enemy.HealthStatus) then show = false end
                            end
                            if show and mLoc then
                                if aLoc and SecurityCommonUtils and SecurityCommonUtils.IsVector then
                                    if SecurityCommonUtils.IsVector(aLoc) and SecurityCommonUtils.IsVector(mLoc) then
                                        if aLoc.Z >= 150000 or FVector.Dist2D(mLoc, aLoc) > 50000 then show = false end
                                    end
                                end
                            end
                            if show then
                                if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then enemy:Replay_CreateEnemyFrameUI(true, true) end
                                if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(true) end
                                if enemy.Replay_UpdateEnemyFrameUI then enemy:Replay_UpdateEnemyFrameUI(hpRatio) end
                                local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                                if Valid(uiComp) then
                                    if markData.LastFrameUIState ~= "VISIBLE" then
                                        if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(0) end
                                        if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(false) end
                                        markData.LastFrameUIState = "VISIBLE"
                                    end
                                end
                            end
                        end)
                    else
                        pcall(function()
                            if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                            local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                            if Valid(uiComp) then
                                if markData.LastFrameUIState ~= "HIDDEN" then
                                    if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end
                                    if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                    markData.LastFrameUIState = "HIDDEN"
                                end
                            end
                        end)
                    end

                    if _G.SUBHAN_BOYConfig.EspVipPro then
                        pcall(function()
                            local hud = Cached_MyHUD
                            if not (Valid(hud) and hud.AddDebugText) then return end
                            if distM > 400 then return end
                            local hp = enemy.Health or 100
                            local maxHp = enemy.HealthMax or 100
                            local isKnock = (hp <= 0 or enemy.HealthStatus == 1)
                            local hpPercent = isKnock and 0 or (hp / maxHp)
                            local pctValue = math.floor(hpPercent * 100 + 0.5)
                            local pName = ""
                            if _G.SUBHAN_BOYConfig.EspName then
                                pName = enemy.PlayerName or enemy.PlayerNamePublic or "Enemy"
                            end
                            local bIsVisible = false
                            if pc and type(pc.LineOfSightTo) == "function" then bIsVisible = pc:LineOfSightTo(enemy) end
                            local visibleCol = GetAppliedColor(_G.ColorConfig.VisibleColor or 4, _G.ColorConfig.Brightness)
                            local invisibleCol = GetAppliedColor(_G.ColorConfig.InvisibleColor or 1, _G.ColorConfig.Brightness)
                            local textColor = {R=255, G=255, B=255, A=255}
                            if isKnock then textColor = {R=0, G=0, B=255, A=255}
                            else textColor = bIsVisible and visibleCol or invisibleCol end
                            local prefix = bIsVisible and "▶" or "▶"
                            local label = ""
                            if isKnock then label = (pName ~= "" and string.format("%s [knocked]", pName) or "knocked")
                            else
                                if pName ~= "" then label = string.format("%s %s %.0f%%", pName, prefix, pctValue)
                                else label = string.format("%s %.0f%%", prefix, pctValue) end
                            end
                            hud:AddDebugText(label, enemy, 0.2, {X=0, Y=0, Z=120}, {X=0, Y=0, Z=120}, textColor, true, false, true, nil, 1.0, true)
                        end)
                    end

                    if _G.SUBHAN_BOYConfig.EspDistance then
                        pcall(function()
                            local hud = Cached_MyHUD
                            if not (Valid(hud) and hud.AddDebugText) then return end
                            if distM > 400 then return end
                            local distMeters = math.floor(distM + 0.5)
                            local rangeColor = {R=255, G=255, B=255, A=255}
                            hud:AddDebugText(string.format("%.0fm", distMeters), enemy, 0.6, {X=15, Y=15, Z=-15}, {X=15, Y=15, Z=-15}, rangeColor, true, false, true, nil, 0.9, true)
                        end)
                    end

                    if _G.SUBHAN_BOYConfig.EspName and not _G.SUBHAN_BOYConfig.EspVipPro then
                        pcall(function()
                            local hud = Cached_MyHUD
                            if not (Valid(hud) and hud.AddDebugText) then return end
                            if distM > 400 then return end
                            local now = os.clock()
                            if not markData.LastNameUpdate or (now - markData.LastNameUpdate) >= 0.2 then
                                markData.LastNameUpdate = now
                                local pName = enemy.PlayerName or enemy.PlayerNamePublic or "Enemy"
                                if pName == "" then return end
                                local isKnock = (enemy.Health or 100) <= 0 or enemy.HealthStatus == 1
                                local bIsVisible = true
                                pcall(function() if pc and type(pc.LineOfSightTo) == "function" then bIsVisible = pc:LineOfSightTo(enemy) end end)
                                local visibleCol = GetAppliedColor(_G.ColorConfig.VisibleColor or 4, _G.ColorConfig.Brightness)
                                local invisibleCol = GetAppliedColor(_G.ColorConfig.InvisibleColor or 1, _G.ColorConfig.Brightness)
                                local nameColor = {R=255, G=255, B=255, A=255}
                                if isKnock then nameColor = {R=0, G=0, B=255, A=255}
                                else nameColor = bIsVisible and visibleCol or invisibleCol end
                                hud:AddDebugText(pName, enemy, 0.6, {X=0, Y=0, Z=120}, {X=0, Y=0, Z=120}, nameColor, true, false, true, nil, 1.0, true)
                            end
                        end)
                    end

                    if _G.SUBHAN_BOYConfig.EspStatus then
                        pcall(function()
                            local hud = Cached_MyHUD
                            if not (Valid(hud) and hud.AddDebugText) then return end
                            if distM > 400 then return end
                            local isKnock = (enemy.Health or 100) <= 0 or enemy.HealthStatus == 1
                            local statusText = isKnock and "Knocked" or "Alive"
                            local statusColor = isKnock and {R=255, G=0, B=0, A=255} or {R=0, G=255, B=0, A=255}
                            hud:AddDebugText(statusText, enemy, 0.6, {X=0, Y=0, Z=90}, {X=0, Y=0, Z=90}, statusColor, true, false, true, nil, 0.8, true)
                        end)
                    end

                    if _G.SUBHAN_BOYConfig.EspVip then
                        if markData.hpMark == nil then markData.hpMark = SafeAddMark(1006, FVector(0,0,0), 0, "", 4, enemy) end
                        if markData.distMark == nil then markData.distMark = SafeAddMark(9999, FVector(0,0,0), 0, "", 4, enemy) end
                    else
                        if markData.hpMark then SafeRemoveMark(markData.hpMark); markData.hpMark = nil end
                        if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                    end

                    if _G.SUBHAN_BOYConfig.Esp8 then
                        if markData.hpMark8 == nil then markData.hpMark8 = SafeAddMark(1006, FVector(0,0,0), 0, "", 4, enemy) end
                    else
                        if markData.hpMark8 then SafeRemoveMark(markData.hpMark8); markData.hpMark8 = nil end
                    end

                    if _G.SUBHAN_BOYConfig.EspRadar then
                        if not markData.radarMark or markData.radarMark == 0 then
                            markData.radarMark = SafeAddMark(8888, FVector(0,0,0), 0, "", 4, enemy)
                        end
                    else
                        if markData.radarMark and markData.radarMark ~= 0 then
                            SafeRemoveMark(markData.radarMark)
                            markData.radarMark = nil
                        end
                    end

                    if _G.SUBHAN_BOYConfig.EspOutline then
                        pcall(function()
                            local outlineHash = tostring(_G.SUBHAN_BOYConfig.OutlineThickness)
                            if markData.OutlineState ~= outlineHash then
                                local PPM = Cached_PPM
                                local avatarComp = (type(enemy.getAvatarComponent2) == "function") and enemy:getAvatarComponent2() or nil
                                if Valid(avatarComp) and Valid(PPM) then
                                    PPM.OutlineThickness = _G.SUBHAN_BOYConfig.OutlineThickness
                                    if PPM.OutlineColor then PPM.OutlineColor = {r = 1, g = 0, b = 0, a = 1} end
                                    PPM:EnableAvatarOutline(avatarComp, true)
                                    markData.OutlineState = outlineHash
                                end
                            end
                        end)
                    else
                        pcall(function()
                            if markData.OutlineState ~= "OFF" then
                                local PPM = Cached_PPM
                                local avatarComp = (type(enemy.getAvatarComponent2) == "function") and enemy:getAvatarComponent2() or nil
                                if Valid(avatarComp) and Valid(PPM) then PPM:EnableAvatarOutline(avatarComp, false) end
                                markData.OutlineState = "OFF"
                            end
                        end)
                    end

                else
                    if not markData.IsCleanedUp then
                        SafeRemoveMark(markData.radarMark); markData.radarMark = nil
                        SafeRemoveMark(markData.hpMark); markData.hpMark = nil
                        SafeRemoveMark(markData.hpMark8); markData.hpMark8 = nil
                        SafeRemoveMark(markData.distMark); markData.distMark = nil
                        if markData.MIDs then
                            for meshStr, midTable in pairs(markData.MIDs) do
                                for k, _ in pairs(midTable) do midTable[k] = nil end
                            end
                            markData.MIDs = nil
                        end
                        pcall(function()
                            local eObj = markData.enemy
                            if Valid(eObj) then
                                if eObj.Replay_SetVisiableOfFrameUI then eObj:Replay_SetVisiableOfFrameUI(false) end
                                local uiComp = eObj.EnemyFrameUI or (type(eObj.GetEnemyFrameUI) == "function" and eObj:GetEnemyFrameUI())
                                if Valid(uiComp) then
                                    if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end
                                    if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                end
                            end
                            local PPM = Cached_PPM
                            local avatarComp = Valid(eObj) and (type(eObj.getAvatarComponent2) == "function") and eObj:getAvatarComponent2() or nil
                            if Valid(avatarComp) and Valid(PPM) then PPM:EnableAvatarOutline(avatarComp, false) end
                        end)
                        markData.IsCleanedUp = true
                    end
                end
            end
        end

        if _G.SUBHAN_BOYConfig.Esp7 then
            pcall(function()
                local MyHUD = Cached_MyHUD
                if Valid(MyHUD) then
                    local text = string.format("[ PLAY SAFE!! @DR_SUBHAN ]")
                    MyHUD:AddDebugText(text, localPlayer, 0.06, {X=0, Y=0, Z=0}, {X=0, Y=0, Z=0}, C_RED, true, false, true, nil, 0.8, true)
                end
            end)
        end
    end)
end

_G.SUBHAN_BOYState.LoopToken = (_G.SUBHAN_BOYState.LoopToken or 0) + 1
local myToken = _G.SUBHAN_BOYState.LoopToken

-- ==========================================
-- FAST TICK (ESP)
-- ==========================================
local function FastTick()
    if isExpired then
        if not _G.SUBHAN_BOYNotifiedExpire then
            Notify("MOD HAS EXPIRED! PLEASE CONTACT ADMIN TO RENEW!\nTelegram @DR_SUBHAN")
            _G.SUBHAN_BOYNotifiedExpire = true
        end
        return
    end
    if myToken ~= _G.SUBHAN_BOYState.LoopToken then return end
    pcall(MainLoop)
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.4, FastTick)
    end
end

-- ==========================================
-- FAST AIMBOT TICK (FIXED)
-- ==========================================
local aimbotToken = 0
local function FastAimbotTick()
    if isExpired then return end
    if aimbotToken ~= _G.SUBHAN_BOYState.AimbotLoopToken then return end

    -- FIX: only run when GameplayData is available
    if _G.SUBHAN_BOYGameplayData then
        pcall(function()
            if _G.SUBHAN_BOYConfig.AimTouchEnable then
                _G.AimTouch()
            end
        end)
    end

    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.016, FastAimbotTick)
    end
end

-- ==========================================
-- BOOT LOOPS
-- ==========================================
if not isExpired then
    FastTick()
    _G.SUBHAN_BOYState.AimbotLoopToken = (_G.SUBHAN_BOYState.AimbotLoopToken or 0) + 1
    aimbotToken = _G.SUBHAN_BOYState.AimbotLoopToken
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.1, FastAimbotTick)
    end
    Notify("VIP MOD ACTIVATED! Telegram: @DR_SUBHAN")
else
    FastTick()
end

-- ==========================================
-- INIT SYSTEMS
-- ==========================================
local function InitAllModSystems()
    if isExpired then return end
    pcall(function()
        if _G.StartBypass_VIP_v3 then _G.StartBypass_VIP_v3() end
        if _G.InitializeAutoHeadHooks then _G.InitializeAutoHeadHooks() end
    end)
    local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
    if not GameplayData then return end
    _G.SUBHAN_BOYGameplayData = GameplayData
    pcall(function()
        local LocalPlayer = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if slua.isValid(LocalPlayer) then
            if LocalPlayer.bHasShownDevNotice == nil then
                LocalPlayer.bHasShownDevNotice = false
                LocalPlayer.bHasShownExpiredNotice = false
                LocalPlayer.bIsDeadFlag = false
            end
        end
    end)
end

if not isExpired then
    pcall(function()
        require("common.time_ticker").AddTimerOnce(0.5, InitAllModSystems)
    end)
end

-- ==========================================
-- RETURN SECTION (ORIGINAL)
-- ==========================================
local class = require("class")
local CActorBase = require("GameLua.Mod.BaseMod.Common.Core.ActorBase")
local CGameStateBase = class(CActorBase, nil, GameStateBase)
return require("combine_class").DeclareFeature(CGameStateBase, {
  { GlobalAvatar = "GameLua.GameCore.Feature.GlobalAvatarFeature" },
  { ReviveState = "GameLua.Mod.BaseMod.GamePlay.Revive.ReviveGameStateFeature" },
  { KingEliminationFeature = "GameLua.GameCore.Feature.KingEliminationFeature" },
  { FatalDamageFeature = "GameLua.Mod.BaseMod.Gameplay.Feature.GameStateFatalDamageFeature" }
}, "GameStateBase")
