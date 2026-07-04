---
name: bss-ai-helper
description: 사회연대은행 BSS AI Helper를 다시 열고, 상태 확인·이어가기·설명 보기 중 하나를 안전하게 선택하게 돕는다.
---

# BSS AI Helper

사용자가 `BSS AI Helper 실행해줘`, `AI 세팅 이어서 해줘`, `개발환경 설치 도와줘`라고 말하면 이 저장소의 설치 도우미를 확인한다.

1. 먼저 현재 폴더가 `bss-ai-boiler-plate` 저장소인지 확인한다. 설치 후 실행 명령 이름은 계속 `bss-ai-helper`다.
2. 사용자에게 `이어서 진행`, `상태만 확인`, `설명만 보기` 중 하나를 묻는다.
3. 상태만 확인이면 현재 OS에 맞는 상태 명령을 실행한다: Windows는 `.\windows\install.ps1 -Status`, Linux는 `./linux/install.sh --status`, macOS/root는 `./install.sh --status`. 설치된 helper bin이 있으면 `bss-ai-helper --status`를 우선 사용한다.
4. 이어서 진행이면 저장소의 안내에 따라 진행하되, 비밀번호·토큰·OAuth 코드는 저장하지 않는다.
5. 설명만 보기이면 `~/.bss-ai-helper/manual/index.html` 또는 `~/.bss-ai-helper/latest-report.md` 위치를 알려준다.
