# DungeonAssist (던전 도우미)

## 데이터 출처와 연락처 (Data sources & contact)

이 애드온은 아래에 적은 프로젝트의 공개 데이터를 이용해 만들었습니다. 데이터를 만들고 공개해 주신 분들께 깊이 감사드립니다.

저작권자나 데이터를 제공하신 분께서 사용을 원하지 않으시면, 언제든 아래 메일로 알려 주십시오.
요청을 받는 즉시 해당 데이터의 사용을 멈추고, 이후 배포본에서 빼겠습니다. 그 밖에 필요하신 조치가 있으면 성심껏 협조하겠습니다.
미처 허락을 구하지 못한 부분이 있었다면 진심으로 사과드립니다.

- 연락처: mina709093@gmail.com

> This add-on is built with publicly available data from the projects listed below, and we are sincerely grateful to their authors.
> If you are a rights holder or data provider and would prefer that we not use your data, please contact us at any time at mina709093@gmail.com.
> We will stop using it immediately upon request, remove it from future releases, and cooperate fully with any further steps you may need.
> We apologize for any inconvenience this may have caused.

### 어떤 데이터를 어디서 가져오는지

| 데이터 | 가져온 곳 | 조건 | 들어 있는 파일 |
|---|---|---|---|
| 던전 지도, 경로, 보스·희귀 지점, 처치 표시 (실시간) | 설치된 Forever Dungeon Routes (Checkov23)의 데이터를 읽고, 그 애드온의 체크 기능을 부름. 파일은 복사하지 않음 | MIT | `Core.lua`, `Rare.lua`, `Unknown.lua`, `Sync.lua`, `Draw.lua` |
| 희귀 몬스터 npc 번호 | 게임의 공개 정보. AeonDungeonJournal 자료와 번호만 대조함 (이름·설명·그림은 가져오지 않음) | 사실 정보 | `Data/Rares.lua` |
| 보스 전리품·능력 화면 (실시간) | 설치된 Dungeon Codex(AeonDungeonJournal)의 창을 /codex 명령으로 열고 보스 버튼을 누름. 데이터는 가져오지 않음 | GPL-2.0 (그 애드온) | `Journal.lua` |
| 기존 자료에 없던 희귀 몬스터·우두머리 (번호, 한국어 이름, 던전, 방) | 이 애드온 사용자들이 게임에서 직접 확인해 파티·길드로 나눈 기록을 개발자가 취합 | 사용자 기록 | `Data/Found.lua` |

신규 던전 지도 그림(Santiago Reyes, Atlas de Azeroth: Forever)은 이 애드온에 들어 있지 않습니다. Forever Dungeon Routes가 허락을 받아 보여 주는 그림입니다.

## 하는 일

Forever Dungeon Routes(`/fdr`)를 보완합니다. 그 애드온이 없으면 아무것도 하지 않습니다.

- 희귀 몬스터를 잡거나 그 전리품 창을 열면 FDR 지도의 희귀 지점에 자동으로 체크합니다. (`/던전 희귀`)
- 뒤 순서의 우두머리가 먼저 잡혔는데 앞 우두머리가 체크되지 않았으면, 지도 아이콘에 "?"를 붙입니다. (`/던전 물음표`)
- 던전 도우미를 쓰는 파티원끼리 이미 잡은 우두머리 체크를 맞춥니다. (`/던전 공유`)
- FDR 지도 왼쪽의 [그리기] 버튼으로 지도 위에 선을 그립니다. 던전 도우미를 쓰는 파티원에게도 보이고 사람마다 색이 다릅니다. (`/던전 그리기`, `/던전 지우기`, `/던전 그림공유`)
- FDR 지도의 보스 아이콘을 오른쪽 클릭하면 Dungeon Codex(`/codex`)에서 그 보스의 전리품과 능력을 엽니다. (`/던전 도감`)
- 기존 자료에 없는 희귀 몬스터나 FDR 경로에 없는 우두머리를 게임에서 확인하면 기록하고, 파티·길드의 상수팩 사용자와 나눕니다. 모인 자료는 다음 버전에 넣습니다. (`/던전 수집`)
- 다른 던전 애드온과 함께 써도 충돌하지 않게, 지도 꾸미기와 `/던전` 명령은 다른 애드온보다 나중에 적용됩니다.

## 명령

- `/던전`, `/dga`: 도움말과 FDR 연결 상태
- `/던전 희귀`: 희귀 몬스터 자동 체크 켜기/끄기
- `/던전 물음표`: "?" 표시 켜기/끄기
- `/던전 공유`: 파티원과 체크 맞추기 켜기/끄기
- `/던전 그리기`: 그리기 모드 켜기/끄기 (지도의 [그리기] 버튼과 같음)
- `/던전 지우기`: 이 던전의 내 그림 모두 지우기
- `/던전 그림공유`: 그림을 파티원과 주고받기 켜기/끄기
- `/던전 그림버튼`: 지도의 그리기·지우기 버튼 보이기/숨기기
- `/던전 도감`: 보스 아이콘 오른쪽 클릭으로 Dungeon Codex 열기 켜기/끄기
