-- 희귀 몬스터 자동 체크
-- FDR은 희귀 몬스터(그리고 게임의 우두머리 목록에 없는 선택 보스)를 손으로 체크해야 합니다.
-- 여기서는 두 가지로 처치를 알아내 FDR 지도에 체크합니다.
--   1) 전리품 창: 전리품의 주인 GUID → npc 번호 → Data/Rares.lua 또는 기억한 번호
--   2) 대상이나 주시 대상이 죽음: 그 이름(한국어)을 FDR 지점 이름과 비교
-- 체크는 FDR의 ToggleStopDone 으로 합니다. 그러면 FDR이 파티원에게도 알려 줍니다.
local _, ns = ...
ns.Rare = {}

-- 비교용 글자: 소문자로, 공백과 ASCII 문장부호를 뺍니다(한글 바이트는 남음). FDR과 같은 방식입니다.
local function Simple(text)
  if type(text) ~= "string" then return "" end
  return (text:lower():gsub("[%s%p%c]", ""))
end

-- GUID에서 npc 번호 (Creature-0-서버-인스턴스-구역-번호-생성번호)
local function NpcIdFromGUID(guid)
  if type(guid) ~= "string" then return nil end
  local kind, id = guid:match("^(%a+)%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)%-")
  if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
  return nil
end

-- 지점의 모든 이름(name, nameKO, nameDE ...)을 비교용 글자로
local function StopNames(stop)
  local list = {}
  for k, v in pairs(stop) do
    if type(k) == "string" and k:match("^name") and type(v) == "string" then
      local s = Simple(v)
      if s ~= "" then list[#list + 1] = s end
    end
  end
  return list
end

-- 자동 체크 대상 지점: 희귀, 그리고 게임 우두머리 번호가 없는 선택 보스
local function IsCandidate(stop)
  if type(stop) ~= "table" then return false end
  if stop.kind == "rare" then return true end
  if stop.kind == "optional" then
    return type(stop.encounters) ~= "table" or #stop.encounters == 0
  end
  return false
end

-- 찾는 이름 하나가 지점 이름과 맞는지. "A & B", "A, B"처럼 둘을 묶은 지점도 맞춥니다.
local function NameMatches(names, want)
  if #want < 3 then return false end -- 한 글자짜리 오탐 방지 (한글 한 글자 = 3바이트)
  for _, n in ipairs(names) do
    if n == want or n:find(want, 1, true) then return true end
  end
  return false
end

-- 지금 던전(같은 인스턴스의 다른 구역 포함)의 키 목록
local function CurrentKeys(DR)
  local keys, seen = {}, {}
  if DR.currentKey then keys[1] = DR.currentKey seen[DR.currentKey] = true end
  if DR.currentInstanceID and type(DR.GetDungeonsForInstance) == "function" then
    for _, wing in ipairs(DR:GetDungeonsForInstance(DR.currentInstanceID) or {}) do
      if wing.key and not seen[wing.key] then
        keys[#keys + 1] = wing.key
        seen[wing.key] = true
      end
    end
  end
  return keys
end

-- 처치한 몬스터 하나(npc 번호, 이름)를 FDR 지점에 체크합니다. 체크한 지점 수를 돌려줍니다.
local function TickUnit(npcID, unitName)
  local DR = ns.GetFDR()
  if not DR or not ns.db or not ns.db.rareAuto then return 0 end
  local count = 0
  ns.Rare.EachMatch(DR, npcID, unitName, function(key, route, i, stop, hitName)
    -- 이름으로 맞춘 몬스터는 번호를 기억해 다음부터 전리품 창으로도 알아봅니다.
    if hitName and npcID and not ns.RareNpcs[npcID] then
      ns.db.learned[npcID] = stop.name
    end
    if not DR:IsStopDone(key, route, i) then
      DR:ToggleStopDone(key, route, i)
      count = count + 1
      local shown = (DR.GetStopName and DR:GetStopName(stop)) or stop.name or "?"
      ns.Print("처치 확인: " .. tostring(shown) .. " (지도에 체크했습니다)")
    end
  end)
  return count
end

-- npc 번호로 아는 FDR 지점 이름: 기본 자료(Data/Rares.lua) → 취합 자료(Data/Found.lua) → 내가 기억한 것 → 내 수집 기록
local function KnownStopName(npcID)
  if not npcID then return nil end
  local f = ns.FoundRares and ns.FoundRares[npcID]
  local mine = ns.db and ns.db.found and ns.db.found.rares and ns.db.found.rares[npcID]
  return ns.RareNpcs[npcID] or (f and f.s) or (ns.db and ns.db.learned[npcID]) or (mine and mine.s)
end

-- 지금 던전에서 이 몬스터(번호, 이름)와 맞는 자동 체크 대상 지점마다 fn(key, route, i, stop, 이름으로맞음)
local function EachMatch(DR, npcID, unitName, fn)
  local byId = KnownStopName(npcID)
  local wantId = byId and Simple(byId) or nil
  local wantName = unitName and Simple(unitName) or nil
  if not wantId and not wantName then return end
  for _, key in ipairs(CurrentKeys(DR)) do
    local route = DR:GetActiveRoute(key)
    for i, stop in ipairs(route and route.stops or {}) do
      if IsCandidate(stop) then
        local names = StopNames(stop)
        local hitId = wantId and NameMatches(names, wantId)
        local hitName = not hitId and wantName and NameMatches(names, wantName)
        if hitId or hitName then fn(key, route, i, stop, hitName) end
      end
    end
  end
end

-- 같은 몬스터를 여러 번 처리하지 않게 GUID를 기억합니다(던전을 나가면 비움).
local handled = {}

local function HandleGUID(guid, unitName)
  guid = ns.Plain(guid)
  if type(guid) ~= "string" or handled[guid] then return end
  local npcID = NpcIdFromGUID(guid)
  if not npcID then return end
  handled[guid] = true
  TickUnit(npcID, ns.Plain(unitName))
end

local function InDungeon()
  local inInstance = ns.Plain(IsInInstance())
  return inInstance == true or inInstance == 1
end

-- 죽은 유닛(대상, 주시 대상)
local function CheckDeadUnit(unit)
  if not UnitExists(unit) or not UnitIsDead(unit) then return end
  HandleGUID(UnitGUID(unit), UnitName(unit))
end

-- 전리품 창의 주인들
local function ScanLoot()
  if not GetLootSourceInfo or not GetNumLootItems then return end
  for slot = 1, (GetNumLootItems() or 0) do
    local src = { GetLootSourceInfo(slot) } -- guid1, 수량1, guid2, 수량2 ...
    for j = 1, #src, 2 do
      HandleGUID(src[j], nil)
    end
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("LOOT_OPENED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
if frame.RegisterUnitEvent then
  frame:RegisterUnitEvent("UNIT_HEALTH", "target", "focus")
else
  frame:RegisterEvent("UNIT_HEALTH")
end
frame:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_ENTERING_WORLD" then
    handled = {}
    return
  end
  if not ns.db or not ns.db.rareAuto or not InDungeon() then return end
  if event == "LOOT_OPENED" then
    ns.Safe(CheckDeadUnit, "target")
    ns.Safe(ScanLoot)
  elseif event == "UNIT_HEALTH" and (unit == "target" or unit == "focus") then
    ns.Safe(CheckDeadUnit, unit)
  end
end)

-- 시험용
ns.Rare.Simple, ns.Rare.NpcIdFromGUID, ns.Rare.TickUnit, ns.Rare.IsCandidate = Simple, NpcIdFromGUID, TickUnit, IsCandidate
ns.Rare.EachMatch, ns.Rare.KnownStopName, ns.Rare.CurrentKeys = EachMatch, KnownStopName, CurrentKeys
