-- 던전 도우미: Forever Dungeon Routes(FDR)를 보완하는 상수팩 애드온
-- FDR의 지도와 데이터는 그대로 쓰고, FDR에 없는 기능만 더합니다. FDR 파일은 고치지 않습니다.
-- FDR이 밖으로 열어 둔 테이블 _G.ForeverDungeonRoutes 를 읽고, 그 함수로 체크 표시를 합니다.
local ADDON, ns = ...

local ACCENT = "|cff10d0a0"

function ns.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(ACCENT .. "[던전 도우미]|r " .. tostring(msg))
end

-- 오류가 나도 게임이 막히지 않게 감쌉니다.
function ns.Safe(fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok and geterrorhandler then geterrorhandler()(err) end
  return ok, err
end

-- 비밀값이면 nil
local issecret = issecretvalue or function() return false end
function ns.Plain(value)
  if issecret(value) then return nil end
  return value
end

-- FDR이 켜져 있고 준비가 끝났으면 그 테이블을, 아니면 nil
function ns.GetFDR()
  local DR = _G.ForeverDungeonRoutes
  if type(DR) ~= "table" or not DR.db or not DR.cdb then return nil end
  if type(DR.GetActiveRoute) ~= "function" or type(DR.IsStopDone) ~= "function"
    or type(DR.ToggleStopDone) ~= "function" then
    return nil
  end
  return DR
end

local DEFAULTS = {
  rareAuto = true,   -- 희귀 몬스터 자동 체크
  unknownMark = true, -- 확인할 수 없는 우두머리에 "?" 표시
  partySync = true,  -- 던전 도우미를 쓰는 파티원과 체크 맞추기
  drawShare = true,  -- 손그림을 파티원과 주고받기
  drawButtons = true, -- FDR 지도에 그리기·지우기 버튼 보이기
  codexButton = true, -- 보스 아이콘 오른쪽 클릭으로 Dungeon Codex 열기
  collect = true,    -- 기존 자료에 없는 것을 확인하면 기록하고 파티·길드와 나누기
  found = {},        -- 수집 기록 { rares = { [npc] = {...} }, bosses = { [우두머리] = {...} } }
  learned = {},      -- [npc 번호] = FDR 지점 이름 (이름으로 맞춘 희귀를 기억)
}

local function ApplyDefaults(db, defaults)
  for k, v in pairs(defaults) do
    if db[k] == nil then
      if type(v) == "table" then db[k] = {} else db[k] = v end
    end
  end
end

-- 다른 애드온과 겹칠 때 우리 것이 마지막에 적용되게 합니다 ------------------------------------
-- 1) TOC의 OptionalDeps 로 다른 던전 애드온보다 늦게 읽힙니다.
-- 2) FDR 지도에 붙이는 연결(hooksecurefunc)은 모든 애드온의 PLAYER_LOGIN 처리가 끝난 다음 틀에 겁니다.
--    나중에 건 연결이 나중에 실행되므로, 같은 지도 아이콘을 꾸미는 다른 애드온보다 뒤에 그립니다.
-- 3) 슬래시 명령(/던전, /dga)은 다른 애드온이 같은 글자를 써도 우리 명령으로 열리게 다시 붙잡습니다.
local lastQueue, loggedIn = {}, false

local function RunLast(fn)
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function() ns.Safe(fn) end)
  else
    ns.Safe(fn)
  end
end

-- fn 을 다른 애드온의 준비가 모두 끝난 뒤에 실행합니다.
function ns.AtLast(fn)
  if loggedIn then RunLast(fn) else lastQueue[#lastQueue + 1] = fn end
end

-- 슬래시 명령을 우리 함수로 다시 붙잡습니다. 게임은 hash_SlashCmdList(대문자 명령 → 함수)를 먼저 봅니다.
function ns.ClaimSlash()
  local hash = _G["hash_SlashCmdList"]
  local fn = SlashCmdList and SlashCmdList["DUNGEONASSIST"]
  if type(hash) ~= "table" or type(fn) ~= "function" then return false end
  for i = 1, 9 do
    local cmd = _G["SLASH_DUNGEONASSIST" .. i]
    if type(cmd) ~= "string" then break end
    hash[cmd:upper()] = fn
  end
  return true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    if type(DungeonAssistDB) ~= "table" then DungeonAssistDB = {} end
    ApplyDefaults(DungeonAssistDB, DEFAULTS)
    ns.db = DungeonAssistDB
  elseif event == "ADDON_LOADED" and loggedIn then
    -- 로그인 뒤에 늦게 켜진 애드온(필요할 때 읽는 애드온)이 명령을 가져가도 다시 붙잡습니다.
    RunLast(ns.ClaimSlash)
  elseif event == "PLAYER_LOGIN" then
    loggedIn = true
    if not _G.ForeverDungeonRoutes then
      ns.Print("Forever Dungeon Routes가 없어서 쉬고 있습니다. 그 애드온을 설치하면 동작합니다.")
    end
    lastQueue[#lastQueue + 1] = ns.ClaimSlash
    local queue = lastQueue
    lastQueue = {}
    RunLast(function()
      for _, fn in ipairs(queue) do ns.Safe(fn) end
    end)
  end
end)

local function OnOff(v) return v and "|cff40ff40켜짐|r" or "|cffff6060꺼짐|r" end

local function Help()
  ns.Print("Forever Dungeon Routes(/fdr) 지도를 돕는 애드온입니다.")
  ns.Print("  /던전 희귀 : 희귀 몬스터 자동 체크 켜기/끄기 (지금 " .. OnOff(ns.db and ns.db.rareAuto) .. ")")
  ns.Print("  /던전 물음표 : 확인할 수 없는 우두머리에 \"?\" 표시 켜기/끄기 (지금 " .. OnOff(ns.db and ns.db.unknownMark) .. ")")
  ns.Print("  /던전 공유 : 파티원과 처치 체크 맞추기 켜기/끄기 (지금 " .. OnOff(ns.db and ns.db.partySync) .. ")")
  ns.Print("  /던전 그리기 : 지도에 그리기 켜기/끄기 (FDR 지도 왼쪽의 [그리기] 버튼과 같음)")
  ns.Print("  /던전 지우기 : 이 던전의 내 그림 모두 지우기")
  ns.Print("  /던전 그림공유 : 그림을 파티원과 주고받기 켜기/끄기 (지금 " .. OnOff(ns.db and ns.db.drawShare) .. ")")
  ns.Print("  /던전 그림버튼 : 지도의 그리기·지우기 버튼 보이기/숨기기 (지금 " .. OnOff(ns.db and ns.db.drawButtons) .. ")")
  ns.Print("  /던전 도감 : 보스 아이콘 오른쪽 클릭으로 Dungeon Codex 열기 켜기/끄기 (지금 " .. OnOff(ns.db and ns.db.codexButton) .. ")")
  ns.Print("  /던전 수집 : 모은 자료와 공유 상태 보기 (/던전 수집 끄기, /던전 수집 켜기)")
  local DR = ns.GetFDR()
  ns.Print("  FDR 연결: " .. (DR and "|cff40ff40됨|r" or "|cffff6060안 됨|r"))
end

SLASH_DUNGEONASSIST1 = "/던전"
SLASH_DUNGEONASSIST2 = "/dga"
SlashCmdList["DUNGEONASSIST"] = function(msg)
  if not ns.db then return end
  msg = strtrim and strtrim(msg or "") or (msg or "")
  if msg == "희귀" or msg == "rare" then
    ns.db.rareAuto = not ns.db.rareAuto
    ns.Print("희귀 몬스터 자동 체크: " .. OnOff(ns.db.rareAuto))
  elseif msg == "물음표" or msg == "?" then
    ns.db.unknownMark = not ns.db.unknownMark
    ns.Print("\"?\" 표시: " .. OnOff(ns.db.unknownMark))
    if ns.RefreshMap then ns.RefreshMap() end
  elseif msg == "공유" or msg == "sync" then
    ns.db.partySync = not ns.db.partySync
    ns.Print("파티원과 체크 맞추기: " .. OnOff(ns.db.partySync))
    if ns.db.partySync and ns.AskParty then ns.AskParty(true) end
  elseif msg == "그리기" or msg == "draw" then
    if ns.SetDrawMode then
      ns.SetDrawMode(not ns.IsDrawMode())
      ns.Print("그리기: " .. OnOff(ns.IsDrawMode()) .. (ns.IsDrawMode() and " (/fdr 지도에서 왼쪽 버튼을 누른 채 끌기)" or ""))
    end
  elseif msg == "지우기" or msg == "clear" then
    if ns.ClearDrawing then ns.Print(("이 던전의 내 그림 %d개를 지웠습니다."):format(ns.ClearDrawing() or 0)) end
  elseif msg == "그림공유" then
    ns.db.drawShare = not ns.db.drawShare
    ns.Print("그림 공유: " .. OnOff(ns.db.drawShare))
  elseif msg == "그림버튼" then
    ns.db.drawButtons = not ns.db.drawButtons
    ns.Print("그리기·지우기 버튼: " .. OnOff(ns.db.drawButtons))
    if ns.RefreshDrawButtons then ns.RefreshDrawButtons() end
  elseif msg:find("^수집") or msg:find("^collect") then
    local arg = msg:match("^%S+%s+(%S+)") or ""
    if arg == "끄기" or arg == "off" then ns.db.collect = false
    elseif arg == "켜기" or arg == "on" then ns.db.collect = true end
    local c = ns.CollectCounts and ns.CollectCounts() or { rares = 0, bosses = 0, mine = 0, received = 0 }
    ns.Print(("자료 수집: %s · 희귀 %d, 경로 밖 우두머리 %d (직접 확인 %d, 받은 것 %d)"):format(OnOff(ns.db.collect), c.rares, c.bosses, c.mine, c.received))
    if SangsuData and SangsuData.Status then ns.Print(SangsuData:Status()) end
    ns.Print("모은 자료는 개발자가 취합해서 다음 버전에 넣습니다. 고맙습니다!")
  elseif msg == "도감" or msg == "codex" then
    ns.db.codexButton = not ns.db.codexButton
    ns.Print("보스 아이콘 오른쪽 클릭으로 도감 열기: " .. OnOff(ns.db.codexButton))
  else
    Help()
  end
end
