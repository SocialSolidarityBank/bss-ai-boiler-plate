# Team Beginner Standard Install(팀 초보자 표준 설치)

이 문서는 초보자가 `SocialSolidarityBank/bss-ai-boiler-plate` 레포 링크를 에이전트에게 주고, Plan Mode(계획 모드)에서 설치 계획을 먼저 세운 뒤 한 번에 실행하는 표준 workflow(작업 흐름)입니다.

실제 Codex 초보자가 어떤 순서로 화면과 질문을 만나게 되는지는 [Beginner Codex User Scenario(초보자 Codex 사용자 시나리오)](./beginner-codex-user-scenario.md)를 참고하세요.

목표는 네 가지입니다.

- 같은 workspace folder(작업 폴더)를 쓴다.
- 같은 질문 순서로 선택한다.
- Final Installation Plan(최종 설치 계획) 문서를 먼저 확인한다.
- 사용자가 승인한 뒤에만 폴더 생성부터 설치까지 실행한다.

명령어, 폴더명, 파일명, option(옵션)처럼 번역하면 안 되는 값은 원문 그대로 둡니다. 그 외 기술 용어는 `Plan Mode(계획 모드)`, `Test Plan(테스트 계획)`처럼 영문/국문을 병기합니다.

## 1. Start Prompt(시작 요청)

초보자는 에이전트에게 repo link(레포 링크)와 짧은 요청만 줍니다.

```text
https://github.com/SocialSolidarityBank/bss-ai-boiler-plate
설치해줘
```

아래처럼 말해도 같은 뜻입니다.

```text
https://github.com/SocialSolidarityBank/bss-ai-boiler-plate
설치 시작해줘
```

에이전트는 이 짧은 요청을 초보자 표준 설치 요청으로 해석합니다. 바로 설치하지 않고, 먼저 선택지를 모두 확인하고 Final Installation Plan(최종 설치 계획)을 작성합니다.

## 2. Standard Workspace Folder(표준 작업 폴더)

기본 workspace folder(작업 폴더)는 아래 경로를 씁니다.

Windows:

```text
C:\Users\<사용자>\Documents\Codex\bss-ai-boiler-plate
```

Linux:

```text
~/Documents/Codex/bss-ai-boiler-plate
```

에이전트가 최종 승인 뒤 만드는 parent folder(부모 폴더)는 아래와 같습니다.

- `Documents/Codex`

마지막 `bss-ai-boiler-plate` 폴더는 `git clone`이나 installer bootstrap(설치 시작 단계)이 만듭니다.

이 경로를 쓰는 이유는 단순합니다.

- 다운로드 폴더와 바탕화면을 피하면 나중에 찾기 쉽습니다.
- 팀원마다 같은 위치를 쓰면 상태 설명과 재시작이 쉽습니다.
- `AI_BOILER_PLATE_DIR`를 같은 값으로 맞추면 bootstrap path(설치 시작 경로)도 통일됩니다.

## 3. Plan Mode Questions(계획 모드 질문)

에이전트는 아래 순서로 질문합니다. 질문은 초보자가 기능을 보고 고를 수 있게 제품명만 묻지 않습니다.

OS(운영체제):

```text
설치할 컴퓨터의 OS(운영체제)를 선택해 주세요.
1) Windows
2) Linux
```

Basic Environment(기본 환경):

```text
기본 환경은 개발 도구가 실행될 바탕 프로그램입니다.
패키지는 필요한 프로그램을 내려받아 설치하는 묶음입니다.
런타임은 Node.js나 Python처럼 개발 도구가 돌아가게 해주는 실행기입니다.
셸은 PowerShell이나 터미널처럼 명령을 입력하는 창입니다.
기본 환경을 전체 설치할까요?
1) 네, 전체 설치할게요
2) 설치하지 않을게요
```

AI CLI tools(AI CLI 도구):

```text
Codex 앱은 이미 설치했다고 보고, 터미널에서 쓰는 CLI 명령만 확인합니다.
1) Codex CLI 설치
2) Claude Code CLI 설치
3) Codex CLI + Claude Code CLI 설치
4) CLI 도구는 설치하지 않음
```

Matt Pocock Skills:

```text
무엇부터 해야 할지 잘 모를 때, 체계적으로 설계하고 작업할 수 있게 도와주는 스킬인 Matt Pocock Skills를 설치할까요?
1) 네 설치할게요
2) 설치하지 않을게요
```

Superpowers:

```text
아이디어가 있을 때 아이디어를 구체화해서 작업 계획까지 세워주는 스킬인 Superpowers를 설치할까요?
1) 네 설치할게요
2) 설치하지 않을게요
```

Superpowers mapping(매핑)은 `brainstorming` + `writing-plans`를 중심으로 둡니다. 필요하면 주요 workflow(작업 흐름) 스킬인 `executing-plans`, `subagent-driven-development`, `test-driven-development`, `requesting-code-review`, `finishing-a-development-branch`도 Final Installation Plan(최종 설치 계획)에 안내합니다.

Lazy-Codex:

```text
Codex를 사용할 때 코딩, 수정, 검증 작업을 구조적으로 도와주는 도구인 Lazy-Codex를 설치할까요?
1) 네 설치할게요
2) 설치하지 않을게요
```

Oh-My-Claudecode:

```text
Claude Code 사용을 쉽게 도와주는 도구인 Oh-My-Claudecode를 설치할까요?
1) 네 설치할게요
2) 설치하지 않을게요
```

## 4. Final Installation Plan(최종 설치 계획)

Final Check(최종 확인)는 질문이 아니라 Plan Mode(계획 모드)의 필수 산출물입니다.

에이전트는 설치 전에 반드시 아래 문구와 함께 Final Installation Plan(최종 설치 계획)을 보여줍니다.

```text
설치 전 계획부터 확인할게요.
Final Installation Plan(최종 설치 계획)을 보여드리겠습니다.
시작하려면 마지막에 "승인" 또는 "진행"이라고 말해주세요.
```

Final Installation Plan(최종 설치 계획)에는 최소한 아래 항목이 들어갑니다.

- 선택한 OS(운영체제)
- 생성할 workspace folder(작업 폴더)
- Basic Environment(기본 환경) 범위
- 설치할 AI CLI tools(AI CLI 도구)
- 추가 기능별 선택 결과: 설치 / 설치하지 않음
- 실제 실행할 command(명령)
- 설치 전에 사용자가 확인해야 할 사항

문서 승인 전에는 `mkdir`, `git clone`, `install.sh`, `windows/install.ps1`를 실행하지 않습니다.

## 5. Standard Execution Preset(표준 실행 프리셋)

`--standard` / `-Standard`는 승인된 Final Installation Plan(최종 설치 계획)을 실행할 때 쓰는 Standard Execution Preset(표준 실행 프리셋)입니다.

bootstrap(설치 시작 단계)에서 repo(레포)를 새로 받을 때 `--standard` / `-Standard`는 기본으로 아래 폴더를 씁니다.

- Windows: `C:\Users\<사용자>\Documents\Codex\bss-ai-boiler-plate`
- Linux: `~/Documents/Codex/bss-ai-boiler-plate`

`AI_BOILER_PLATE_DIR`를 직접 지정하면 그 경로가 우선입니다.

Linux:

```sh
./linux/install.sh --standard
```

Windows:

```powershell
.\windows\install.ps1 -Standard
```

Dry Run(미리보기 실행)은 같은 경로와 같은 option(옵션)에 `--dry-run` 또는 `-DryRun`만 붙입니다.

Linux:

```sh
./linux/install.sh --standard --dry-run
```

Windows:

```powershell
.\windows\install.ps1 -Standard -DryRun
```

## 6. After Install Check(설치 후 확인)

설치가 끝나면 installer(설치 프로그램)는 자동으로 아래 두 파일을 만듭니다.

- `latest-report.md`: 설치 결과를 텍스트로 정리한 report(리포트)
- `manual/index.html`: 초보자용 HTML manual(HTML 사용 매뉴얼)

HTML manual(HTML 사용 매뉴얼)에는 아래 내용이 반드시 들어갑니다.

- 무엇이 어디에 설치됐는지
- 각 도구의 purpose(용도)
- 처음 사용하는 방법
- 선택을 수정하거나 다시 설치하는 방법
- 문제가 생겼을 때 상태를 확인하는 방법

디자인은 장식보다 읽기 쉬움을 우선합니다. Pretendard font(프리텐다드 서체)를 우선 사용하고, point(점), line(선), surface(면)만 활용합니다. 색상은 black, grey, white, blue만 사용하며, box radius(박스 둥근 정도)는 4px에서 16px 범위로 둡니다.

그 다음 새 terminal(터미널)이나 새 PowerShell 창을 열고 status(상태)를 확인합니다.

Linux:

```sh
./linux/install.sh --status
```

Windows:

```powershell
.\windows\install.ps1 -Status
```

## 7. Standardization Rules(표준화 원칙)

이 표준은 다음을 고정합니다.

- 같은 workspace folder(작업 폴더)
- 같은 Plan Mode questions(계획 모드 질문)
- 같은 Final Installation Plan(최종 설치 계획) 형식
- 같은 Standard Execution Preset(표준 실행 프리셋)
- 사용자가 승인하기 전에는 설치하지 않는 원칙

즉, 사람마다 결과가 달라지는 가장 큰 이유인 "어디에 두었는지", "무엇을 선택했는지", "언제 설치를 시작했는지"를 먼저 통일합니다.

이 문서를 바꾸는 작업은 [Goal Mode Quality Gate(목표 모드 품질 게이트)](./goal-mode-quality-gate.md)를 통과해야 합니다.

```sh
scripts/qa/goal-mode-gate.sh --quick
```
