-- 파티 처치 정보 맞추기
-- FDR은 손으로 누른 체크만 파티에 알리고, 우두머리 자동 체크는 각자 게임 이벤트로 합니다.
-- 그래서 늦게 합류하거나 다시 접속한 사람은 이미 잡힌 우두머리를 모릅니다.
-- 던전 도우미를 쓰는 파티원끼리 "지금 이 던전에서 체크된 지점"을 주고받아 빈 체크를 채웁니다.
-- 체크를 지우지는 않습니다. FDR 쪽 파티 알림이 겹치지 않게 FDR의 SetStopDone 을 씁니다.
--
-- 애드온 메시지 (접두어 DungeonAssist, 칸은 탭으로 나눔)
--   Q <키>                 이 던전에서 체크된 지점을 알려 주세요
--   K <키> <이름> <이름>…  내가 이 던전에서 체크한 지점 (FDR 지점 영어 이름)
local _, ns = ...

local PREFIX = "DungeonAssist"
local ASK_GAP = 15      -- 묻기 사이 최소 초
local ANSWER_GAP = 5    -- 같은 던전 대답 사이 최소 초
local MAX_LEN = 240     -- 메시지 하나의 최대 길이(바이트)

local lastAsk, lastAnswer = -100, {}

local function Now() return GetTime and GetTime() or 0 end

local function Channel()
  if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
  if IsInRaid and IsInRaid() then return "RAID" end
  if IsInGroup and IsInGroup() then return "PARTY" end
  return nil
end

local function Send(msg)
  local ch = Channel()
  if not ch or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return false end
  local ok = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, ch)
  return ok
end

-- 여러 메시지를 0.25초 간격으로 보냅니다(한꺼번에 보내면 게임이 막음). 그림 공유에서 씁니다.
local QUEUE_GAP = 0.25
local queue, sending = {}, false
local function Pump()
  local msg = table.remove(queue, 1)
  if not msg then sending = false return end
  Send(msg)
  if C_Timer and C_Timer.After then
    C_Timer.After(QUEUE_GAP, Pump)
  else
    Pump()
  end
end
local function Queue(msg)
  if not Channel() then return false end
  queue[#queue + 1] = msg
  if not sending then
    sending = true
    Pump()
  end
  return true
end

ns.Comm = { Send = Send, Queue = Queue, Channel = Channel, PREFIX = PREFIX,
  ClearQueue = function() queue, sending = {}, false end }

local function Clean(s)
  return (tostring(s or ""):gsub("[\t\r\n|]", " "))
end

local function Usable()
  return ns.db and ns.db.partySync and ns.GetFDR() or nil
end

-- 내가 지금 있는 던전에서 체크된 지점 이름
local function DoneNames(DR, key)
  local route = DR:GetActiveRoute(key)
  local names = {}
  for i, stop in ipairs(route and route.stops or {}) do
    if type(stop.name) == "string" and stop.name ~= "" and DR:IsStopDone(key, route, i) then
      names[#names + 1] = Clean(stop.name)
    end
  end
  return names
end

-- 이름 목록을 길이에 맞춰 여러 메시지로 나눕니다.
local function Pack(key, names)
  local out, cur = {}, "K\t" .. key
  local empty = true
  for _, n in ipairs(names) do
    if #cur + 1 + #n > MAX_LEN and not empty then
      out[#out + 1] = cur
      cur, empty = "K\t" .. key, true
    end
    cur = cur .. "\t" .. n
    empty = false
  end
  if not empty then out[#out + 1] = cur end
  return out
end

function ns.AskParty(force)
  local DR = Usable()
  if not DR or not DR.currentKey or not Channel() then return false end
  if not force and Now() - lastAsk < ASK_GAP then return false end
  lastAsk = Now()
  return Send("Q\t" .. DR.currentKey)
end

local function Answer(DR, key)
  if DR.currentKey ~= key then return end -- 같은 던전에 있는 사람만 대답
  if lastAnswer[key] and Now() - lastAnswer[key] < ANSWER_GAP then return end
  local names = DoneNames(DR, key)
  if #names == 0 then return end
  lastAnswer[key] = Now()
  for _, msg in ipairs(Pack(key, names)) do Send(msg) end
end

-- 받은 이름을 내 지도에 체크합니다. 체크한 수를 돌려줍니다.
local function Apply(DR, key, names, sender)
  if DR.currentKey ~= key then return 0 end
  local route = DR:GetActiveRoute(key)
  if not route or type(DR.SetStopDone) ~= "function" then return 0 end
  local want = {}
  for _, n in ipairs(names) do want[n] = true end
  local count = 0
  for i, stop in ipairs(route.stops or {}) do
    if stop.name and want[Clean(stop.name)] and not DR:IsStopDone(key, route, i) then
      DR:SetStopDone(key, route, i, true)
      count = count + 1
    end
  end
  if count > 0 then
    ns.Print(("%s님의 정보로 지도에 %d곳을 체크했습니다."):format(tostring(sender or "파티원"), count))
  end
  return count
end

local function MyName()
  local n = ns.Plain(UnitName("player"))
  return n
end

local function OnMessage(msg, sender)
  msg, sender = ns.Plain(msg), ns.Plain(sender)
  if type(msg) ~= "string" or type(sender) ~= "string" then return end
  local short = Ambiguate and Ambiguate(sender, "none") or sender:gsub("%-.*$", "")
  if short == MyName() then return end
  local parts = {}
  for p in (msg .. "\t"):gmatch("([^\t]*)\t") do parts[#parts + 1] = p end
  local kind, key = parts[1], parts[2]
  if not key or key == "" then return end
  -- 그림 메시지는 Draw.lua 가 받습니다(그림 공유 설정을 따름).
  if ns.Draw and ns.Draw.KINDS[kind] then
    ns.Draw.OnMessage(kind, parts, short)
    return
  end
  local DR = Usable()
  if not DR then return end
  if kind == "Q" then
    Answer(DR, key)
  elseif kind == "K" then
    local names = {}
    for i = 3, #parts do if parts[i] ~= "" then names[#names + 1] = parts[i] end end
    Apply(DR, key, names, short)
  end
end

local function InDungeon()
  local inInstance = ns.Plain(IsInInstance())
  return inInstance == true or inInstance == 1
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
  if event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
      pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    end
    -- FDR이 던전을 알아채면(들어감, 구역 바뀜) 파티에 물어봅니다.
    local DR = _G.ForeverDungeonRoutes
    if type(DR) == "table" and type(DR.On) == "function" then
      DR:On("DUNGEON_CHANGED", function()
        if C_Timer and C_Timer.After then
          C_Timer.After(3, function() ns.Safe(ns.AskParty) end)
        else
          ns.Safe(ns.AskParty)
        end
      end)
    end
  elseif event == "CHAT_MSG_ADDON" then
    if a1 == PREFIX then ns.Safe(OnMessage, a2, a4) end
  elseif event == "GROUP_ROSTER_UPDATE" then
    if InDungeon() then ns.Safe(ns.AskParty) end
  end
end)

-- 시험용
ns.Sync = { Pack = Pack, Apply = Apply, DoneNames = DoneNames, OnMessage = OnMessage, PREFIX = PREFIX,
  ResetTimers = function() lastAsk, lastAnswer = -100, {} end }
