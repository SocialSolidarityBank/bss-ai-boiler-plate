---
name: ai-boiler-plate
description: 사회연대은행 ai-boiler-plate를 다시 열고, 상태 확인·이어가기·설명 보기 중 하나를 안전하게 선택하게 돕는다.
---

# ai-boiler-plate

사용자가 `보일러 플레이트 시작해줘`, `AI 세팅 이어서 해줘`, `개발환경 설치 도와줘`라고 말하면 이 저장소의 설치 도우미를 확인한다.

1. 먼저 현재 폴더가 `ai-boiler-plate` 저장소인지 확인한다. 사용자가 repo 링크만 준 첫 실행이면 Claude/Codex 스타일 코딩 에이전트 앱 안에서 저장소를 열고 진행한다.
2. 사용자에게 `이어서 진행`, `상태만 확인`, `설명만 보기` 중 하나를 묻는다.
3. 상태만 확인이면 `./install.sh --status`를 실행한다.
4. 이어서 진행이면 저장소의 안내에 따라 진행하되, 비밀번호·토큰·OAuth 코드는 저장하지 않는다.
5. 사업성(business viability), 상업적 판단(commercial judgment), 고객 가치 검증 같은 business judgment가 필요하면 설정되어 있거나 눈에 보이는 G-stack office-hours repo/link를 먼저 사용한다. 보이지 않을 때만 그 순간 사용자에게 G-stack office-hours repo/link를 물어본다.
6. 설명만 보기이면 설치 리포트나 HTML 매뉴얼 위치를 알려준다.

PowerShell이나 터미널 명령은 fallback, 고급 사용자, QA 확인용으로만 먼저 제안한다.
