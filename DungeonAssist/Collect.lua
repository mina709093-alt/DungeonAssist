-- 자료 수집과 공유: 기존 자료에 없는 것을 게임에서 직접 확인하면 기록하고, 파티·길드의 상수팩 사용자와 나눕니다.
--   1) 희귀 몬스터: 던전 안에서 희귀 등급 몬스터를 대상으로 잡거나 마우스를 올리거나 이름표가 보일 때,
--      그 npc 번호를 아직 모르면 번호, 한국어 이름, 던전 키, 그때 방 이름, (맞으면) FDR 지점 이름을 기록합니다.
--   2) FDR 경로에 없는 우두머리: 우두머리를 잡았는데(ENCOUNTER_END 성공) FDR 지도에 맞는 지점이 없으면
--      우두머리 번호, 한국어 이름, 던전 키, 방 이름을 기록합니다.
-- 추측으로 채우는 값은 없습니다. 저장: DungeonAssistDB.found (계정 공용).
-- 공유: 상수팩 공용 모듈 SangsuData (공간 이름 "DA"). 키는 r:npc번호, b:우두머리번호.
-- 취합: docs/tools/da_merge.lua 가 저장 파일을 읽어 Data/Found.lua 를 만듭니다(AGENTS.md 9절).
local _, ns = ...

local SPACE = "DA"

local function Found()
  if not ns.db then return nil end
  local f = ns.db.found
  if type(f) ~= "table" then f = {} ns.db.found = f end
  f.rares = f.rares or {}
  f.bosses = f.bosses or {}
  return f
end

local function InDungeon()
  local inInstance = ns.Plain(IsInInstance())
  return inInstance == true or inInstance == 1
end

local function Room()
  local s = GetSubZoneText and ns.Plain(GetSubZoneText())
  if type(s) == "string" and s ~= "" then return s end
  return nil
end

local function Changed()
  if SangsuData and SangsuData.Changed then SangsuData:Changed(SPACE) end
end

-- 이미 아는 것인지 (애드온 기본 자료, 취합 자료, 내 기록) ----------------------------------------------

local function KnownRare(id)
  local f = Found()
  return (ns.RareNpcs and ns.RareNpcs[id]) or (ns.FoundRares and ns.FoundRares[id])
    or (f and f.rares[id]) and true or false
end

local function KnownBoss(id)
  local f = Found()
  return (ns.FoundBosses and ns.FoundBosses[id]) or (f and f.bosses[id]) and true or false
end

-- 기록 ------------------------------------------------------------------------------------

local function CanRecord()
  return ns.db and ns.db.collect and InDungeon() and ns.GetFDR() and true or false
end

-- 희귀 등급 유닛 하나를 봅니다.
local function SeeUnit(unit)
  if not CanRecord() or not UnitExists(unit) then return false end
  if UnitIsPlayer and ns.Plain(UnitIsPlayer(unit)) then return false end
  local class = ns.Plain(UnitClassification(unit))
  if class ~= "rare" and class ~= "rareelite" then return false end
  local id = ns.Rare.NpcIdFromGUID(ns.Plain(UnitGUID(unit)))
  local name = ns.Plain(UnitName(unit))
  if not id or type(name) ~= "string" or name == "" or KnownRare(id) then return false end
  local DR = ns.GetFDR()
  local stopName
  ns.Rare.EachMatch(DR, id, name, function(_, _, _, stop) stopName = stopName or stop.name end)
  Found().rares[id] = { n = name, k = DR.currentKey, r = Room(), s = stopName, t = time and time() or nil }
  Changed()
  return true
end

-- FDR 지도에 맞는 지점이 있는 우두머리인지
local function OnRoute(DR, id, name)
  local want = name and ns.Rare.Simple(name) or ""
  for _, key in ipairs(ns.Rare.CurrentKeys(DR)) do
    local route = DR:GetActiveRoute(key)
    for _, stop in ipairs(route and route.stops or {}) do
      for _, e in ipairs(type(stop.encounters) == "table" and stop.encounters or {}) do
        if e == id then return true end
      end
      if want ~= "" then
        for k, v in pairs(stop) do
          if type(k) == "string" and k:match("^name") and ns.Rare.Simple(v) == want then return true end
        end
      end
    end
  end
  return false
end

local function BossKilled(id, name, success)
  id, name, success = ns.Plain(id), ns.Plain(name), ns.Plain(success)
  if success ~= 1 and success ~= true then return false end
  if type(id) ~= "number" or not CanRecord() or KnownBoss(id) then return false end
  local DR = ns.GetFDR()
  if not DR.currentKey or OnRoute(DR, id, name) then return false end
  Found().bosses[id] = { n = type(name) == "string" and name or nil, k = DR.currentKey, r = Room(), t = time and time() or nil }
  Changed()
  return true
end

-- 공유 (SangsuData) --------------------------------------------------------------------------

local function Safe(v) return (tostring(v or ""):gsub("[|~%^\t\r\n]", " ")) end

local function Keys()
  local t, f = {}, Found()
  if not f then return t end
  for id in pairs(f.rares) do
    if not (ns.RareNpcs[id] or (ns.FoundRares and ns.FoundRares[id])) then t[#t + 1] = "r:" .. id end
  end
  for id in pairs(f.bosses) do
    if not (ns.FoundBosses and ns.FoundBosses[id]) then t[#t + 1] = "b:" .. id end
  end
  table.sort(t)
  return t
end

local function HasKey(key)
  local kind, id = tostring(key):match("^(%a):(%d+)$")
  id = tonumber(id)
  if not id then return true end
  if kind == "r" then return KnownRare(id) end
  if kind == "b" then return KnownBoss(id) end
  return true
end

local function Encode(key)
  local kind, id = tostring(key):match("^(%a):(%d+)$")
  id = tonumber(id)
  local f = Found()
  local e = f and id and ((kind == "r" and f.rares[id]) or (kind == "b" and f.bosses[id]))
  if not e then return nil end
  return table.concat({ Safe(e.n), Safe(e.k), Safe(e.r), Safe(e.s) }, "~")
end

local function Apply(key, payload, who)
  local kind, id = tostring(key):match("^(%a):(%d+)$")
  id = tonumber(id)
  local f = Found()
  if not id or not f or type(payload) ~= "string" then return false end
  local t = {}
  for part in (payload .. "~"):gmatch("([^~]*)~") do t[#t + 1] = part end
  local function v(i) return t[i] ~= nil and t[i] ~= "" and t[i] or nil end
  if not v(1) or not v(2) then return false end
  if kind == "r" and not KnownRare(id) then
    f.rares[id] = { n = v(1), k = v(2), r = v(3), s = v(4), rx = who }
  elseif kind == "b" and not KnownBoss(id) then
    f.bosses[id] = { n = v(1), k = v(2), r = v(3), rx = who }
  else
    return false
  end
  return true
end

if SangsuData and SangsuData.Register then
  SangsuData:Register(SPACE, {
    keys = Keys, has = HasKey, encode = Encode, apply = Apply,
    onReceived = function(total, from)
      ns.Print(("파티/길드원에게서 던전 자료 %d건을 받았습니다. (%s)"):format(total, tostring(from)))
    end,
  })
end

-- 개수: 내가 직접 확인한 것, 받은 것
function ns.CollectCounts()
  local f = Found()
  local c = { rares = 0, bosses = 0, mine = 0, received = 0 }
  if not f then return c end
  for _, e in pairs(f.rares) do c.rares = c.rares + 1 if e.rx then c.received = c.received + 1 else c.mine = c.mine + 1 end end
  for _, e in pairs(f.bosses) do c.bosses = c.bosses + 1 if e.rx then c.received = c.received + 1 else c.mine = c.mine + 1 end end
  return c
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("ENCOUNTER_END")
frame:SetScript("OnEvent", function(_, event, a1, a2, _, _, a5)
  if event == "PLAYER_TARGET_CHANGED" then
    ns.Safe(SeeUnit, "target")
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    ns.Safe(SeeUnit, "mouseover")
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    if type(a1) == "string" then ns.Safe(SeeUnit, a1) end
  elseif event == "ENCOUNTER_END" then
    ns.Safe(BossKilled, a1, a2, a5)
  end
end)

-- 시험용
ns.Collect = { SeeUnit = SeeUnit, BossKilled = BossKilled, Keys = Keys, HasKey = HasKey, Encode = Encode, Apply = Apply }
