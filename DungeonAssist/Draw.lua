-- 손그림 파티 공유
-- FDR 지도 위에 마우스로 선을 그리고, 던전 도우미를 쓰는 파티원에게 보냅니다.
-- 사람마다 색이 정해집니다(파티원 이름을 가나다순으로 늘어놓은 순서라 모두의 화면에서 같음).
-- 그림은 FDR 지도 좌표(u, v)로 층마다 저장하고, FDR이 선을 다시 그릴 때(DR.MapView:DrawLines) 함께 다시 그립니다.
-- 접속하는 동안만 기억합니다(저장하지 않음).
--
-- 애드온 메시지 (Sync.lua 와 같은 접두어 DungeonAssist, 칸은 탭으로 나눔)
--   T <키> <층> <선 번호> <점들>   선 한 조각. 점은 "u,v;u,v" (0~1 값 × 1000 정수). 같은 번호의 선에 이어 붙임
--   U <키> <선 번호>               그 선 지우기 (되돌리기)
--   C <키>                         그 던전의 내 그림 모두 지우기
--   R <키>                         그 던전 그림을 다시 보내 주세요 (들어왔을 때)
local _, ns = ...

local SCALE = 1000        -- 좌표를 정수로 보낼 때 곱하는 값
local MIN_STEP = 0.004    -- 이 거리(지도 너비 비율)보다 가까운 점은 버림
local MAX_POINTS = 400    -- 선 하나의 최대 점 수
local MAX_STROKES = 100   -- 한 사람이 남길 수 있는 최대 선 수 (넘으면 오래된 것부터 지움)
local PER_MSG = 20        -- 메시지 하나에 넣는 점 수
local RESEND_GAP = 5      -- 다시 보내기 사이 최소 초
local WIDTH = 3           -- 화면에서의 선 두께

local PALETTE = {
  { 1.00, 0.82, 0.20 }, -- 노랑
  { 0.30, 0.75, 1.00 }, -- 파랑
  { 1.00, 0.38, 0.38 }, -- 빨강
  { 0.45, 0.92, 0.45 }, -- 초록
  { 0.85, 0.50, 1.00 }, -- 보라
}

local KINDS = { T = true, U = true, C = true, R = true }

-- strokes[이름] = { list = { [선 번호] = { key, floor, pts = { u1, v1, u2, v2, ... } } }, order = { 선 번호, ... } }
local strokes = {}
local session = tostring((time and time() or 0) % 100000) -- /reload 뒤에도 선 번호가 겹치지 않게
local counter = 0
local current               -- 지금 그리는 선 { id, key, floor, pts }
local drawMode = false
local lastResend = {}

local function Now() return GetTime and GetTime() or 0 end

local function MyName()
  local n = ns.Plain(UnitName("player"))
  return type(n) == "string" and n or "?"
end

-- 지금 파티(공격대)의 이름 목록 (나 포함, 가나다순)
local function GroupNames()
  local names, seen = {}, {}
  local function add(n)
    n = ns.Plain(n)
    if type(n) == "string" and n ~= "" and not seen[n] then seen[n] = true names[#names + 1] = n end
  end
  add(UnitName("player"))
  if IsInRaid and IsInRaid() then
    for i = 1, 40 do add(UnitName("raid" .. i)) end
  else
    for i = 1, 4 do add(UnitName("party" .. i)) end
  end
  table.sort(names)
  return names, seen
end

local function ColorOf(name)
  local names = GroupNames()
  for i, n in ipairs(names) do
    if n == name then return PALETTE[(i - 1) % #PALETTE + 1] end
  end
  return PALETTE[1]
end

-- 점 목록 ↔ 글자 ------------------------------------------------------------------

local function Round(x) return math.floor(x * SCALE + 0.5) end

local function Encode(pts, first, last)
  local out = {}
  for i = first, last do
    out[#out + 1] = Round(pts[2 * i - 1]) .. "," .. Round(pts[2 * i])
  end
  return table.concat(out, ";")
end

local function Decode(text)
  local pts = {}
  for x, y in tostring(text or ""):gmatch("(%-?%d+),(%-?%d+)") do
    pts[#pts + 1] = tonumber(x) / SCALE
    pts[#pts + 1] = tonumber(y) / SCALE
  end
  return pts
end

-- 선 하나를 메시지 여러 개로
local function PackStroke(key, s)
  local msgs = {}
  local n = #s.pts / 2
  local first = 1
  while first <= n do
    local last = math.min(n, first + PER_MSG - 1)
    msgs[#msgs + 1] = table.concat({ "T", key, tostring(s.floor), s.id, Encode(s.pts, first, last) }, "\t")
    first = last + 1
  end
  return msgs
end

-- 저장 -----------------------------------------------------------------------------

local function Bucket(name)
  local b = strokes[name]
  if not b then
    b = { list = {}, order = {} }
    strokes[name] = b
  end
  return b
end

-- 선에 점을 이어 붙입니다(없으면 새 선).
local function AddPoints(name, id, key, floor, pts)
  local b = Bucket(name)
  local s = b.list[id]
  if not s then
    s = { id = id, key = key, floor = floor, pts = {} }
    b.list[id] = s
    b.order[#b.order + 1] = id
    while #b.order > MAX_STROKES do
      b.list[table.remove(b.order, 1)] = nil
    end
  end
  for i = 1, #pts do
    if #s.pts >= MAX_POINTS * 2 then break end
    s.pts[#s.pts + 1] = pts[i]
  end
  return s
end

local function RemoveStroke(name, id)
  local b = strokes[name]
  if not b or not b.list[id] then return false end
  b.list[id] = nil
  for i = #b.order, 1, -1 do
    if b.order[i] == id then table.remove(b.order, i) end
  end
  return true
end

local function ClearKey(name, key)
  local b = strokes[name]
  if not b then return 0 end
  local n = 0
  for i = #b.order, 1, -1 do
    local id = b.order[i]
    if b.list[id] and b.list[id].key == key then
      b.list[id] = nil
      table.remove(b.order, i)
      n = n + 1
    end
  end
  return n
end

-- 지도에 그리기 ----------------------------------------------------------------------

local layer, lines, numLines = nil, {}, 0
local ui -- { capture, drawButton, clearButton }

local function GetView()
  local DR = ns.GetFDR()
  local view = DR and DR.MapView
  if type(view) ~= "table" or not view.canvas or type(view.ToCanvas) ~= "function" then return nil end
  return view
end

local function Line(x1, y1, x2, y2, width, c)
  numLines = numLines + 1
  local line = lines[numLines]
  if not line then
    line = layer:CreateLine(nil, "OVERLAY")
    lines[numLines] = line
  end
  line:SetStartPoint("TOPLEFT", layer, x1, -y1)
  line:SetEndPoint("TOPLEFT", layer, x2, -y2)
  line:SetThickness(width)
  line:SetColorTexture(c[1], c[2], c[3], 0.95)
  line:Show()
end

local function DrawStroke(view, s, width, c)
  local pts = s.pts
  local n = #pts / 2
  if n < 1 then return end
  local px, py = view:ToCanvas(pts[1], pts[2])
  if n == 1 then
    Line(px - width, py, px + width, py, width, c) -- 점 하나는 짧은 선으로
    return
  end
  for i = 2, n do
    local x, y = view:ToCanvas(pts[2 * i - 1], pts[2 * i])
    Line(px, py, x, y, width, c)
    px, py = x, y
  end
end

local function Redraw()
  local view = GetView()
  if not view or not layer then return end
  for i = 1, numLines do lines[i]:Hide() end
  numLines = 0
  local k = view.scale
  if not k or k <= 0 or not view.key or not view.floor then return end
  local width = WIDTH / k
  for name, b in pairs(strokes) do
    local c = ColorOf(name)
    for _, id in ipairs(b.order) do
      local s = b.list[id]
      if s and s.key == view.key and s.floor == view.floor then DrawStroke(view, s, width, c) end
    end
  end
  if current and current.key == view.key and current.floor == view.floor then
    DrawStroke(view, current, width, ColorOf(MyName()))
  end
end

-- 보내기 ---------------------------------------------------------------------------------

local function Share(msg)
  if ns.db and ns.db.drawShare and ns.Comm then ns.Comm.Queue(msg) end
end

local function SendStroke(key, s)
  for _, msg in ipairs(PackStroke(key, s)) do Share(msg) end
end

-- 내 그림 ------------------------------------------------------------------------------

local function UpdateButtons()
  if not ui then return end
  local on = drawMode
  ui.drawButton.Text:SetText(on and "그리는 중" or "그리기")
  ui.drawButton.Text:SetTextColor(on and 0.06 or 1, on and 0.82 or 0.82, on and 0.63 or 0.2)
  ui.capture:SetShown(on)
end

function ns.SetDrawMode(on)
  drawMode = on and true or false
  if not drawMode then current = nil end
  UpdateButtons()
  Redraw()
end
function ns.IsDrawMode() return drawMode end

local function StartStroke()
  local view = GetView()
  if not view or not view.key or not view.floor then return end
  local u, v = view:GetCursorUV()
  if not u then return end
  counter = counter + 1
  current = { id = session .. "-" .. counter, key = view.key, floor = view.floor, pts = { u, v } }
  Redraw()
end

local function ExtendStroke()
  local view = GetView()
  if not current or not view then return end
  local u, v = view:GetCursorUV()
  if not u then return end
  local pts = current.pts
  local du, dv = u - pts[#pts - 1], v - pts[#pts]
  if du * du + dv * dv < MIN_STEP * MIN_STEP or #pts >= MAX_POINTS * 2 then return end
  pts[#pts + 1], pts[#pts + 2] = u, v
  Redraw()
end

local function FinishStroke()
  local s = current
  current = nil
  if not s then return end
  local stored = AddPoints(MyName(), s.id, s.key, s.floor, s.pts)
  SendStroke(s.key, stored)
  Redraw()
end

-- 그 던전에서 내가 마지막에 그린 선 지우기
function ns.UndoDrawing()
  local view = GetView()
  local b = strokes[MyName()]
  if not view or not b then return end
  for i = #b.order, 1, -1 do
    local s = b.list[b.order[i]]
    if s and s.key == view.key then
      RemoveStroke(MyName(), s.id)
      Share(table.concat({ "U", s.key, s.id }, "\t"))
      Redraw()
      return
    end
  end
end

-- 그 던전의 내 그림 모두 지우기
function ns.ClearDrawing()
  local view = GetView()
  local key = view and view.key or (ns.GetFDR() and ns.GetFDR().currentKey)
  if not key then return 0 end
  local n = ClearKey(MyName(), key)
  Share("C\t" .. key)
  Redraw()
  return n
end

-- 다른 사람 그림을 내 화면에서만 지우기
local function HideOthers()
  local me = MyName()
  for name in pairs(strokes) do
    if name ~= me then strokes[name] = nil end
  end
  Redraw()
end

-- 화면 (버튼과 마우스 받는 판) ---------------------------------------------------------------

local function MakeButton(parent, text)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(72, 22)
  b.Back = b:CreateTexture(nil, "BACKGROUND")
  b.Back:SetAllPoints()
  b.Back:SetColorTexture(0, 0, 0, 0.65)
  b.Text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.Text:SetPoint("CENTER")
  b.Text:SetText(text)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  return b
end

local function Tip(owner, title, text)
  owner:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 0.82, 0)
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  owner:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function EnsureUI(view)
  if ui or not view.frame or not view.canvas then return end
  layer = CreateFrame("Frame", nil, view.canvas)
  layer:SetAllPoints(view.canvas)
  layer:SetFrameLevel(view.canvas:GetFrameLevel() + 11) -- 경로선 위, 보스 아이콘(+12) 아래

  local base = view.frame:GetFrameLevel()
  local capture = CreateFrame("Frame", nil, view.frame)
  capture:SetAllPoints(view.frame)
  capture:SetFrameLevel(base + 40)
  capture:EnableMouse(true)
  capture:Hide()
  capture:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then ns.Safe(StartStroke) end
  end)
  capture:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then
      ns.Safe(FinishStroke)
    elseif button == "RightButton" then
      ns.Safe(ns.UndoDrawing)
    end
  end)
  capture:SetScript("OnUpdate", function()
    if current then ns.Safe(ExtendStroke) end
  end)

  local drawButton = MakeButton(view.frame, "그리기")
  drawButton:SetFrameLevel(base + 45)
  drawButton:SetPoint("LEFT", view.frame, "LEFT", 8, 13)
  drawButton:SetScript("OnClick", function() ns.SetDrawMode(not drawMode) end)
  Tip(drawButton, "그리기 (던전 도우미)",
    "켜면 지도 위에 왼쪽 버튼을 누른 채 끌어서 선을 그립니다. 오른쪽 클릭은 마지막 선 지우기입니다.\n"
    .. "던전 도우미를 쓰는 파티원에게도 보입니다. 다시 누르면 끕니다(그동안 지도 끌기와 보스 클릭이 안 됩니다).")

  local clearButton = MakeButton(view.frame, "지우기")
  clearButton:SetFrameLevel(base + 45)
  clearButton:SetPoint("TOP", drawButton, "BOTTOM", 0, -4)
  clearButton:SetScript("OnClick", function(_, button)
    if button == "RightButton" then HideOthers() else ns.ClearDrawing() end
  end)
  Tip(clearButton, "지우기 (던전 도우미)",
    "클릭: 이 던전의 내 그림을 모두 지웁니다(파티원 화면에서도).\n오른쪽 클릭: 다른 사람 그림을 내 화면에서만 지웁니다.")

  ui = { capture = capture, drawButton = drawButton, clearButton = clearButton }
  UpdateButtons()
end

local function ShowButtons(view)
  if not ui then return end
  local show = ns.db and ns.db.drawButtons and view.key and view.floor and true or false
  ui.drawButton:SetShown(show)
  ui.clearButton:SetShown(show)
  if not show and drawMode then ns.SetDrawMode(false) end
end

local function AfterDrawLines(view)
  EnsureUI(view)
  ShowButtons(view)
  Redraw()
end

function ns.RefreshDrawButtons()
  local view = GetView()
  if view then ShowButtons(view) end
end

-- 받기 ---------------------------------------------------------------------------------

local function ResendMine(key)
  if lastResend[key] and Now() - lastResend[key] < RESEND_GAP then return end
  lastResend[key] = Now()
  local b = strokes[MyName()]
  for _, id in ipairs(b and b.order or {}) do
    local s = b.list[id]
    if s and s.key == key then SendStroke(key, s) end
  end
end

local function OnMessage(kind, parts, sender)
  if not ns.db or not ns.db.drawShare then return end
  local key = parts[2]
  if kind == "T" then
    local floor, id = tonumber(parts[3]), parts[4]
    if not floor or not id or id == "" then return end
    AddPoints(sender, id, key, floor, Decode(parts[5]))
  elseif kind == "U" then
    RemoveStroke(sender, parts[3] or "")
  elseif kind == "C" then
    ClearKey(sender, key)
  elseif kind == "R" then
    ResendMine(key)
    return
  end
  Redraw()
end

-- 그 던전에 들어왔을 때 파티원 그림을 받습니다.
function ns.AskDrawings()
  local DR = ns.GetFDR()
  if not DR or not DR.currentKey or not ns.db or not ns.db.drawShare then return false end
  Share("R\t" .. DR.currentKey)
  return true
end

-- 파티를 나간 사람의 그림은 지웁니다.
local function DropLeavers()
  local _, inGroup = GroupNames()
  local changed = false
  for name in pairs(strokes) do
    if not inGroup[name] then strokes[name] = nil changed = true end
  end
  if changed then Redraw() end
end

local hooked = false
local function Hook()
  if hooked then return end
  local DR = _G.ForeverDungeonRoutes
  local view = type(DR) == "table" and DR.MapView
  if type(view) ~= "table" or type(view.DrawLines) ~= "function" or not hooksecurefunc then return end
  hooksecurefunc(view, "DrawLines", function(self) ns.Safe(AfterDrawLines, self) end)
  if type(DR.On) == "function" then
    DR:On("DUNGEON_CHANGED", function()
      if C_Timer and C_Timer.After then
        C_Timer.After(4, function() ns.Safe(ns.AskDrawings) end)
      end
    end)
  end
  hooked = true
end

-- 다른 애드온의 연결보다 뒤에 실행되게 마지막에 겁니다(Core.lua ns.AtLast).
ns.AtLast(Hook)

local frame = CreateFrame("Frame")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function()
  ns.Safe(DropLeavers)
end)

-- 시험용
ns.Draw = {
  KINDS = KINDS, OnMessage = OnMessage, Encode = Encode, Decode = Decode, PackStroke = PackStroke,
  AddPoints = AddPoints, ColorOf = ColorOf, Strokes = function() return strokes end,
  Start = StartStroke, Extend = ExtendStroke, Finish = FinishStroke, Redraw = Redraw,
  NumLines = function() return numLines end, UI = function() return ui end,
}
