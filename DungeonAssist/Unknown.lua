-- "?" 표시: 처치했는지 확인할 수 없는 우두머리
-- 경로 순서에서 뒤에 있는 우두머리가 이미 처치됐는데 앞의 우두머리가 체크되지 않았으면,
-- 그 앞 우두머리는 건너뛰었거나, 내가 없을 때(늦게 합류, 멀리 떨어짐) 잡혔을 수 있습니다.
-- 이런 우두머리의 FDR 지도 아이콘 오른쪽 위에 금색 "?"를 붙입니다.
-- FDR의 지도 그리기 함수(DR.MapView:AddPins)가 끝난 뒤에 덧붙이기만 하고, FDR 동작은 바꾸지 않습니다.
local _, ns = ...

-- 확인할 수 없는 지점 번호의 표: { [지점 번호] = true }
local function UnknownSet(DR, key, route)
  local set = {}
  if not DR or not key or type(route) ~= "table" or type(route.stops) ~= "table" then return set end
  local laterDone = false
  for i = #route.stops, 1, -1 do
    local stop = route.stops[i]
    if type(stop) == "table" and (stop.kind or "boss") == "boss" then
      if DR:IsStopDone(key, route, i) then
        laterDone = true
      elseif laterDone then
        set[i] = true
      end
    end
  end
  return set
end

local TIP = "던전 도우미: 처치했는지 확인하지 못했습니다. 뒤 순서의 우두머리가 먼저 처치되었습니다. 이미 잡았다면 눌러서 체크하세요."

local function PinOnEnter(pin)
  if not pin.dungeonAssistUnknown then return end
  if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == pin then
    GameTooltip:AddLine(TIP, 1, 0.82, 0.2, true)
    GameTooltip:Show()
  end
end

local function MakeMark(pin)
  local q = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  if q.SetDrawLayer then q:SetDrawLayer("OVERLAY", 4) end
  q:SetPoint("CENTER", pin, "TOPRIGHT", -3, -3)
  q:SetText("?")
  q:SetTextColor(1, 0.82, 0.2)
  pin.dungeonAssistQ = q
  if pin.HookScript then pin:HookScript("OnEnter", PinOnEnter) end
  return q
end

-- 지도에 그려진 지점 아이콘마다 "?"를 켜거나 끕니다.
local function Decorate(view)
  if type(view) ~= "table" or type(view.stopPins) ~= "table" then return end
  local DR = ns.GetFDR()
  local set = (DR and ns.db and ns.db.unknownMark) and UnknownSet(DR, view.key, view.route) or {}
  for i = 1, (view.numStops or 0) do
    local pin = view.stopPins[i]
    if pin then
      local show = pin.index and set[pin.index] or false
      pin.dungeonAssistUnknown = show
      local q = pin.dungeonAssistQ
      if show and not q then q = MakeMark(pin) end
      if q then q:SetShown(show) end
    end
  end
end

local hooked = false
local function Hook()
  if hooked then return end
  local DR = _G.ForeverDungeonRoutes
  local view = type(DR) == "table" and DR.MapView
  if type(view) ~= "table" or type(view.AddPins) ~= "function" or not hooksecurefunc then return end
  hooksecurefunc(view, "AddPins", function(self) ns.Safe(Decorate, self) end)
  hooked = true
end

-- 설정을 바꾸면 지도를 다시 그립니다.
function ns.RefreshMap()
  local DR = _G.ForeverDungeonRoutes
  local view = type(DR) == "table" and DR.MapView
  if type(view) == "table" and type(view.Refresh) == "function" and view.key then
    ns.Safe(view.Refresh, view)
  end
end

-- 다른 애드온의 연결보다 뒤에 실행되게 마지막에 겁니다(Core.lua ns.AtLast).
ns.AtLast(Hook)

-- 시험용
ns.Unknown = { UnknownSet = UnknownSet, Decorate = Decorate, IsHooked = function() return hooked end }
