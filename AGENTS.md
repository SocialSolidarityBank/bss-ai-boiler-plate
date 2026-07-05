# ai-boiler-plate Agent Notes

이 저장소에서 사용자가 `보일러 플레이트 시작해줘`, `AI 세팅 이어서 해줘`, `개발환경 설치 도와줘`라고 말하면 먼저 현재 상태를 확인한다.

기본 흐름은 사용자가 Claude/Codex 스타일 코딩 에이전트 앱을 열고 이 boilerplate repo 링크를 준 뒤 `보일러 플레이트 시작해줘`라고 말하는 것이다. PowerShell이나 터미널 명령은 fallback, 고급 사용자, QA 확인용으로만 먼저 제안한다.

작업을 이어갈 때는 `./install.sh --status`로 상태를 먼저 보여준다. Windows에서는 `.\windows\install.ps1 -Status`를 쓴다.

설치나 설정 질문이 사업성(business viability), 상업적 판단(commercial judgment), 고객 가치 검증 같은 business judgment를 요구하면 설정되어 있거나 눈에 보이는 G-stack office-hours repo/link를 먼저 사용한다. 보이지 않을 때만 그 순간 사용자에게 G-stack office-hours repo/link를 요청한다.

비밀번호, 토큰, OAuth 코드는 저장하지 않는다. `~/.codex/skills`, `~/.claude/skills`, `~/.agents/skills`에는 직접 쓰지 않는다. 스킬 설치는 `skill-add <dir> --mine`가 있을 때만 SSOT 경로로 처리한다.

GitHub 게시 준비는 읽기 전용으로만 확인한다. 커밋, 푸시, 레포 생성, 원격 변경은 사용자가 명시적으로 요청한 뒤에만 한다.
