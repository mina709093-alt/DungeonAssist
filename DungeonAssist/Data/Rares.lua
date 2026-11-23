-- 희귀 몬스터 npc 번호 → Forever Dungeon Routes 기본 경로의 지점 이름(영어)
-- 전리품 창의 몬스터 번호로 FDR 지점을 찾을 때 씁니다.
-- 번호는 게임의 공개 정보입니다. AeonDungeonJournal 자료와 번호만 대조했고, 설명이나 그림은 가져오지 않았습니다.
-- 여기 없는 희귀는 쓰러진 대상의 이름으로 맞추고, 맞으면 그 번호를 DungeonAssistDB.learned 에 기억합니다.
local _, ns = ...

ns.RareNpcs = {
  -- 죽음의 폐광
  [3586] = "Miner Johnson",
  -- 통곡의 동굴
  [5912] = "Deviate Faerie Dragon",
  -- 그림자송곳니 성채
  [3872] = "Deathsworn Captain",
  -- 스톰윈드 지하감옥
  [1720] = "Bruegal Ironknuckle",
  -- 놈리건
  [6228] = "Dark Iron Ambassador",
  -- 가시덩굴 우리
  [4438] = "Razorfen Spearhide",
  [4842] = "Earthcaller Halmgar",
  [4425] = "Blind Hunter",
  -- 가시덩굴 구릉
  [7354] = "Ragglesnout",
  -- 붉은십자군 수도원 묘지
  [6489] = "Ironspine",
  [6490] = "Azshir the Sleepless",
  [6488] = "Fallen Champion",
  -- 줄파락
  [10082] = "Zerillis",
  [10081] = "Dustwraith",
  [10080] = "Sandarr Dunereaver",
  -- 마라우돈
  [12237] = "Meshlok the Harvester",
  -- 검은바위 나락
  [9041] = "Warder Stilgiss",
  [9042] = "Verek",
  [8923] = "Panzor the Invincible",
  -- 검은바위 첨탑 하층
  [9219] = "Spirestone Butcher",
  [9218] = "Spirestone Battle Lord",
  [9217] = "Spirestone Lord Magus",
  [10376] = "Crystal Fang",
  [9596] = "Bannok Grimaxe",
  [9718] = "Ghok Bashguud",
  -- 검은바위 첨탑 상층
  [10509] = "Jed Runewatcher",
  -- 혈투의 전장 서쪽
  [11467] = "Tsu'zee",
  -- 스트라솔름
  [10393] = "Skul",
  [10809] = "Stonespine",
  -- 로데론의 폐허 (WoW: Forever)
  [255699] = "Lordaeron Captain",
}
