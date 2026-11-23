-- 사용자들이 게임에서 확인한 던전 자료 (취합 도구 docs/tools/da_merge.lua 로 만든 파일입니다. 직접 고치지 않습니다.)
-- FoundRares[npc 번호] = { k = 던전 키, n = 한국어 이름, r = 방 이름, s = FDR 지점 영어 이름(맞춘 경우) }
-- FoundBosses[우두머리 번호] = { k = 던전 키, n = 한국어 이름, r = 방 이름 }  (FDR 경로에 없던 우두머리)
local _, ns = ...

ns.FoundRares = {
}

ns.FoundBosses = {
}
