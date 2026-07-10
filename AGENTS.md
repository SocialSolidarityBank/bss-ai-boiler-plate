# ai-boiler-plate Agent Notes

이 저장소에서 사용자가 `보일러 플레이트 시작해줘`, `AI 세팅 이어서 해줘`, `개발환경 설치 도와줘`라고 말하면 먼저 현재 상태를 확인한다.

기본 흐름은 사용자가 Claude/Codex 스타일 코딩 에이전트 앱을 열고 이 boilerplate repo 링크를 준 뒤 `보일러 플레이트 시작해줘`라고 말하는 것이다. PowerShell이나 터미널 명령은 fallback, 고급 사용자, QA 확인용으로만 먼저 제안한다.

작업을 이어갈 때는 `./install.sh --status`로 상태를 먼저 보여준다. Windows에서는 `.\windows\install.ps1 -Status`를 쓴다.

설치나 설정 질문이 사업성(business viability), 상업적 판단(commercial judgment), 고객 가치 검증 같은 business judgment를 요구하면 설정되어 있거나 눈에 보이는 G-stack office-hours repo/link를 먼저 사용한다. 보이지 않을 때만 그 순간 사용자에게 G-stack office-hours repo/link를 요청한다.

초보자나 팀 표준 설치 요청이 오면 `docs/team-beginner-standard-install.md`를 우선 따른다. 사용자가 repo link(레포 링크)와 함께 `설치해줘`, `설치 시작해줘`, `설치 진행해줘`처럼 짧게 말해도 초보자 표준 설치 요청으로 해석한다. 반드시 Plan Mode(계획 모드)에서 OS(운영체제), 기본 환경, AI CLI 도구, 추가 기능을 먼저 질문하고, 설치 전 Final Installation Plan(최종 설치 계획) 문서를 발행한다. 초보자 표준 OS 선택지는 Windows와 Linux만 둔다. OS를 설명할 때 Windows는 대부분의 개인용 PC에서 쓰며 PowerShell과 `.\windows\install.ps1 -Standard` 흐름을 사용한다고 말하고, Linux는 서버나 개발용 컴퓨터에서 자주 쓰며 terminal(터미널)과 `./linux/install.sh --standard` 흐름을 사용한다고 말한다. 초보자가 이미 Windows 컴퓨터에서 Codex를 쓰고 있다면 Windows를 권장하고, Linux를 이미 쓰고 있거나 팀에서 Linux를 지정한 경우에만 Linux를 고르게 한다. 기본 환경은 패키지, 런타임, 셸을 쉬운 말로 한 줄씩 설명한 뒤 `기본 환경을 전체 설치할까요?`만 묻는다. AI 도구는 Codex 앱이나 Claude 앱이 아니라 `Codex CLI`와 `Claude Code CLI` 설치 여부만 묻는다. Final Installation Plan(최종 설치 계획) 뒤 사용자가 `승인` 또는 `진행`이라고 말하면 실행 승인으로 본다. 사용자가 그 계획을 승인하기 전에는 폴더 생성, `git clone`, installer 실행을 하지 않는다. 표준 작업 폴더는 `~/Documents/Codex/bss-ai-boiler-plate`로 맞추고, Windows는 `C:\Users\<사용자>\Documents\Codex\bss-ai-boiler-plate`를 쓴다.

설치가 완료되면 반드시 `latest-report.md`와 `manual/index.html`을 생성해 사용자에게 위치를 알려준다. HTML manual(HTML 사용 매뉴얼)은 초보자가 이해할 수 있는 자연어로 무엇이 어디에 설치됐는지, 각 도구의 용도, 사용 방법, 수정하거나 다시 설치하는 방법을 설명한다. 디자인은 Pretendard 서체를 우선 사용하고, 장식 요소는 빼며, point(점), line(선), surface(면)만 활용한다. 색상은 black, grey, white, blue 계열만 사용하고, box radius(박스 둥근 정도)는 요소 크기에 맞춰 4px에서 16px 범위로 둔다.

추가 기능은 제품명만 묻지 말고 기능 설명으로 하나씩 묻는다. Matt Pocock Skills는 "무엇부터 해야 할지 잘 모를 때, 체계적으로 설계하고 작업할 수 있게 도와주는 스킬", Superpowers는 "아이디어를 구체화해서 작업 계획까지 세워주는 스킬", Lazy-Codex는 "Codex 코딩, 수정, 검증 작업을 구조적으로 도와주는 도구", Oh-My-Claudecode는 "Claude Code 사용을 쉽게 도와주는 도구"로 설명한다. 선택지는 `네 설치할게요`, `설치하지 않을게요` 두 가지로 통일한다.

Goal Gate(목표 게이트): 이 레포에서 문서, installer(설치 프로그램), wizard(질문 흐름), report/manual(리포트/매뉴얼), QA를 바꾸는 모든 작업은 최종 완료 답변 전에 `scripts/qa/goal-mode-gate.sh --quick`을 통과해야 한다. push(푸시)나 merge(병합) 전에는 `scripts/qa/goal-mode-gate.sh --full`을 통과해야 한다. 실패하면 최종 완료 답변을 하지 않는다. 허용되는 응답은 "Goal Gate(목표 게이트)가 실패해서 완료로 보고하지 않겠습니다. 실패 항목을 수정한 뒤 다시 검증하겠습니다."뿐이다. 가능하면 `/goal`을 열어 목표와 완료 조건을 잡고, 게이트 실패 시 수정과 재검증을 반복한다.

비밀번호, 토큰, OAuth 코드는 저장하지 않는다. `~/.codex/skills`, `~/.claude/skills`, `~/.agents/skills`에는 직접 쓰지 않는다. 스킬 설치는 `skill-add <dir> --mine`가 있을 때만 SSOT 경로로 처리한다.

GitHub 게시 준비는 읽기 전용으로만 확인한다. 커밋, 푸시, 레포 생성, 원격 변경은 사용자가 명시적으로 요청한 뒤에만 한다.
