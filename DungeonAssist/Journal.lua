-- 보스 정보 버튼: FDR 지도의 보스 아이콘을 오른쪽 클릭하면 Dungeon Codex(AeonDungeonJournal, /codex)를 엽니다.
-- Codex는 다른 애드온이 특정 페이지를 열 수 있는 통로가 없습니다. 그래서
--   1) /codex 명령으로 창을 엽니다(던전 안이면 Codex가 그 던전 페이지를 엽니다).
--   2) 창의 보스 목록 버튼 가운데 이름이 맞는 것을 찾아 눌러 그 보스의 전리품·능력 페이지로 갑니다.
-- 이름이 맞는 버튼이 없으면 창만 열어 둡니다. Codex 파일은 고치지 않습니다.
local _, ns = ...

local function Simple(text)
  if type(text) ~= "string" then return "" end
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|A.-|a", ""):gsub("|T.-|t", "")
  return (text:lower():gsub("[%s%p%c]", ""))
end

local function CodexReady()
  return SlashCmdList and type(SlashCmdList.AEONDUNGEONJOURNAL) == "function"
end

-- Codex 창 안의 보스 목록 버튼들 (number, text, portrait 글자·그림을 가진 버튼)
local function BossButtons(root)
  local found = {}
  local function walk(f, depth)
    if depth > 8 or not f or not f.GetChildren then return end
    for _, child in ipairs({ f:GetChildren() }) do
      if type(child.number) == "table" and type(child.text) == "table" and child.portrait
        and child.IsShown and child:IsShown() and child.Click then
        found[#found + 1] = child
      end
      walk(child, depth + 1)
    end
  end
  walk(root, 0)
  return found
end

-- 지점 이름(모든 언어)과 버튼 글자가 맞는지
local function Matches(stop, buttonText)
  local text = Simple(buttonText)
  if #text < 3 then return false end
  for k, v in pairs(stop) do
    if type(k) == "string" and k:match("^name") and type(v) == "string" then
      local n = Simple(v)
      if #n >= 3 and (text == n or text:find(n, 1, true) or n:find(text, 1, true)) then return true end
    end
  end
  return false
end

-- 보스 지점 하나의 정보를 Codex에서 엽니다. 맞는 보스 버튼을 눌렀으면 true.
function ns.OpenBossInfo(stop)
  if not CodexReady() then
    ns.Print("Dungeon Codex(AeonDungeonJournal)가 없어서 보스 정보를 열 수 없습니다.")
    return false
  end
  local frame = _G.AeonDungeonJournalFrame
  if not (frame and frame.IsShown and frame:IsShown()) then
    SlashCmdList.AEONDUNGEONJOURNAL("")
    frame = _G.AeonDungeonJournalFrame
  end
  if not frame or type(stop) ~= "table" then return false end
  for _, button in ipairs(BossButtons(frame)) do
    local text = button.text.GetText and button.text:GetText()
    if Matches(stop, text) then
      -- Codex는 이미 고른 보스를 다시 누르면 선택을 풉니다. 골라져 있으면 누르지 않습니다.
      local chosen = type(button.selected) == "table" and button.selected.IsShown and button.selected:IsShown()
      if not chosen then button:Click() end
      return true
    end
  end
  ns.Print("Dungeon Codex를 열었습니다. 이 던전 안에서 열면 보스 페이지로 바로 갑니다.")
  return false
end

-- FDR 지도 아이콘에 오른쪽 클릭과 툴팁 줄을 덧붙입니다 -------------------------------------------

local function Editing(pin)
  local DR = ns.GetFDR()
  local view = DR and DR.MapView
  return DR and DR.Editor and type(DR.Editor.IsEditing) == "function" and view
    and DR.Editor:IsEditing(view.key, pin.route) or false
end

local function PinOnClick(pin, button)
  if button ~= "RightButton" or not ns.db or not ns.db.codexButton then return end
  if not pin.stop or Editing(pin) then return end
  ns.Safe(ns.OpenBossInfo, pin.stop)
end

local function PinOnEnter(pin)
  if not ns.db or not ns.db.codexButton or not CodexReady() or Editing(pin) then return end
  if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == pin then
    GameTooltip:AddLine("오른쪽 클릭: 보스 정보 (Dungeon Codex)", 0.06, 0.82, 0.63, true)
    GameTooltip:Show()
  end
end

local function HookPins(view)
  if type(view) ~= "table" or type(view.stopPins) ~= "table" then return end
  for i = 1, (view.numStops or 0) do
    local pin = view.stopPins[i]
    if pin and not pin.dungeonAssistJournal and pin.HookScript then
      pin:HookScript("OnClick", PinOnClick)
      pin:HookScript("OnEnter", PinOnEnter)
      pin.dungeonAssistJournal = true
    end
  end
end

local hooked = false
local function Hook()
  if hooked then return end
  local DR = _G.ForeverDungeonRoutes
  local view = type(DR) == "table" and DR.MapView
  if type(view) ~= "table" or type(view.AddPins) ~= "function" or not hooksecurefunc then return end
  hooksecurefunc(view, "AddPins", function(self) ns.Safe(HookPins, self) end)
  hooked = true
end

-- 다른 애드온의 연결보다 뒤에 실행되게 마지막에 겁니다(Core.lua ns.AtLast).
ns.AtLast(Hook)

-- 시험용
ns.Journal = { Simple = Simple, Matches = Matches, BossButtons = BossButtons, PinOnClick = PinOnClick }
