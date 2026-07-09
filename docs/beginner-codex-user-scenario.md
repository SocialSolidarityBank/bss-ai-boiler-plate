# Beginner Codex User Scenario(초보자 Codex 사용자 시나리오)

이 문서는 Codex를 처음 설치한 초보자가 `bss-ai-boiler-plate`로 개발 환경을 준비할 때 실제로 어떤 흐름을 만나게 되는지 정리한 user scenario(사용자 시나리오)입니다.

초보자는 terminal(터미널) 명령을 먼저 외우지 않습니다. Codex에게 repo link(레포 링크)를 주고, Plan Mode(계획 모드)에서 선택지를 확인한 뒤, Final Installation Plan(최종 설치 계획)을 승인하면 설치가 시작됩니다.

## 1. Starting Point(시작 상태)

초보자는 아래 상태에서 시작합니다.

- Codex app(Codex 앱)을 설치했다.
- Git, GitHub, Node.js, Python, shell(셸), Docker 같은 개발 도구는 잘 모른다.
- 어디에 folder(폴더)를 만들어야 하는지 모른다.
- 어떤 AI skill(스킬)이나 add-on(추가 기능)을 설치해야 하는지 모른다.

이 시점에서 초보자에게 요구하는 행동은 하나입니다.

```text
Codex를 열고 아래 요청 문구를 붙여넣는다.
```

## 2. First Prompt(첫 요청)

초보자는 Codex에 repo link(레포 링크)와 짧은 요청만 입력합니다.

```text
https://github.com/SocialSolidarityBank/bss-ai-boiler-plate
설치해줘
```

아래처럼 말해도 같은 뜻입니다.

```text
https://github.com/SocialSolidarityBank/bss-ai-boiler-plate
설치 시작해줘
```

Codex는 이 짧은 요청을 초보자 표준 설치 요청으로 해석합니다. 바로 설치하지 않고, 먼저 현재 repo(레포)를 확인하고 Plan Mode(계획 모드)로 설치 계획을 세웁니다.

## 3. Codex Explains The Process(Codex의 첫 안내)

Codex는 초보자에게 대략 이렇게 설명합니다.

```text
설치 전 계획부터 확인할게요.
질문을 마치면 Final Installation Plan(최종 설치 계획)을 보여드리겠습니다.
시작하려면 마지막에 "승인" 또는 "진행"이라고 말해주세요.
```

초보자가 이해해야 할 핵심은 세 가지입니다.

- 지금은 planning(계획) 단계다.
- 아직 설치는 시작되지 않았다.
- 마지막에 Final Installation Plan(최종 설치 계획)을 보고 `승인` 또는 `진행`이라고 말해야 실행된다.

## 4. Questions In Plan Mode(계획 모드 질문)

Codex는 질문을 한 번에 몰아서 던지지 않고, 초보자가 이해할 수 있게 하나씩 묻습니다.

첫 번째 질문은 OS(운영체제)입니다.

```text
설치할 컴퓨터의 OS(운영체제)를 선택해 주세요.
1) Windows
2) Linux
```

그다음 Basic Environment(기본 환경)를 확인합니다.

```text
기본 환경은 개발 도구가 실행될 바탕 프로그램입니다.
패키지는 필요한 프로그램을 내려받아 설치하는 묶음입니다.
런타임은 Node.js나 Python처럼 개발 도구가 돌아가게 해주는 실행기입니다.
셸은 PowerShell이나 터미널처럼 명령을 입력하는 창입니다.
기본 환경을 전체 설치할까요?
1) 네, 전체 설치할게요
2) 설치하지 않을게요
```

그다음 AI CLI tools(AI CLI 도구)를 확인합니다.

```text
Codex 앱은 이미 설치했다고 보고, 터미널에서 쓰는 CLI 명령만 확인합니다.
1) Codex CLI 설치
2) Claude Code CLI 설치
3) Codex CLI + Claude Code CLI 설치
4) CLI 도구는 설치하지 않음
```

## 5. Add-On Questions(추가 기능 질문)

초보자는 제품 이름을 몰라도 기능을 보고 선택할 수 있어야 합니다. Codex는 아래처럼 하나씩 묻습니다.

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

Codex helper:

```text
Codex를 사용할 때 코딩, 수정, 검증 작업을 구조적으로 도와주는 도구인 Lazy-Codex를 설치할까요?
1) 네 설치할게요
2) 설치하지 않을게요
```

Claude Code helper:

```text
Claude Code 사용을 쉽게 도와주는 도구인 Oh-My-Claudecode를 설치할까요?
1) 네 설치할게요
2) 설치하지 않을게요
```

초보자에게 중요한 점은 "모르면 설치하지 않아도 된다"는 것입니다. Plan Mode(계획 모드)는 정답 맞히기가 아니라 설치 범위를 안전하게 정하는 단계입니다.

## 6. Final Installation Plan(최종 설치 계획)

질문이 끝나면 Codex는 반드시 Final Installation Plan(최종 설치 계획)을 보여줍니다.

이 문서에는 아래 내용이 들어갑니다.

- 선택한 OS(운영체제)
- 만들 workspace folder(작업 폴더)
- 설치할 Basic Environment(기본 환경)
- 설치할 AI CLI tools(AI CLI 도구)
- 추가 기능별 선택 결과
- 실제 실행할 command(명령)
- 설치 전에 확인해야 할 사항

예시는 아래와 같습니다.

```text
Final Installation Plan(최종 설치 계획)

OS(운영체제): Windows
Workspace Folder(작업 폴더):
C:\Users\<사용자>\Documents\Codex\bss-ai-boiler-plate

Basic Environment(기본 환경):
winget, Git, GitHub CLI, runtime(런타임), PowerShell profile

AI CLI Tools(AI CLI 도구):
Codex CLI + Claude Code CLI

Add-ons(추가 기능):
Matt Pocock Skills: 설치
Superpowers Planning Pack: 설치
Lazy-Codex: 설치하지 않음
Oh-My-Claudecode: 설치하지 않음

Execution(실행):
사용자가 승인하면 표준 폴더를 만들고 repo를 준비한 뒤
windows/install.ps1 -Standard 흐름으로 설치합니다.
```

이 단계까지는 설치가 아닙니다. 초보자는 문서를 보고 `승인` 또는 `진행`이라고 말해야 설치가 시작됩니다.

## 7. Execution After Approval(승인 후 실행)

초보자가 승인하면 Codex는 폴더 생성부터 한 번에 진행합니다.

Windows 기준으로는 아래 순서가 됩니다.

```text
1. Documents\Codex 폴더 확인 또는 생성
2. bss-ai-boiler-plate repo 준비
3. AI_BOILER_PLATE_DIR 설정
4. windows/install.ps1 -Standard 실행
5. 선택한 add-on 설치 또는 보류 기록
6. latest-report.md와 manual/index.html 생성
7. status(상태)와 next steps(다음 단계) 안내
```

설치가 완료되면 Codex는 초보자가 바로 찾을 수 있게 아래처럼 안내합니다.

```text
설치 결과를 쉬운 말로 정리했습니다.
결과 리포트: C:\Users\<사용자>\.ai-boiler-plate\latest-report.md
HTML 사용 매뉴얼: C:\Users\<사용자>\.ai-boiler-plate\manual\index.html
매뉴얼에는 무엇이 어디에 설치됐는지, 용도, 수정/재설치 방법이 들어 있습니다.
```

Linux도 같은 구조입니다. 다만 실행 파일만 다릅니다.

Linux:

```sh
./linux/install.sh --standard
```

Windows:

```powershell
.\windows\install.ps1 -Standard
```

## 8. When Something Stops(중간에 멈췄을 때)

초보자 설치에서는 중간에 멈출 수 있습니다.

예를 들면 아래 상황입니다.

- GitHub login(GitHub 로그인)이 필요하다.
- Windows에서 권한 확인 창이 뜬다.
- 네트워크가 느리다.
- 새 PowerShell 창을 열어야 한다.
- 설치된 프로그램을 다시 인식하려면 terminal(터미널)을 재시작해야 한다.

이때 Codex는 실패로 끝내지 않고 다음 중 하나를 안내합니다.

```text
1) 이어서 진행
2) 상태만 확인
3) 설명만 보기
```

초보자는 다시 Codex에 이렇게 말하면 됩니다.

```text
보일러 플레이트 시작해줘
```

또는:

```text
AI 세팅 이어서 해줘
```

## 9. End State(완료 상태)

설치가 끝나면 초보자는 아래 상태가 됩니다.

- 표준 workspace folder(작업 폴더)가 생겼다.
- Git/GitHub 기본 설정이 준비됐다.
- Node.js, Python 같은 runtime(런타임)이 준비됐다.
- Codex CLI 또는 Claude Code CLI 같은 AI CLI tool(AI CLI 도구)을 사용할 수 있다.
- 선택한 skill(스킬)과 add-on(추가 기능)이 설치되었거나 보류로 기록됐다.
- 다음에 문제가 생겨도 Codex에게 이어서 요청할 수 있다.

마지막 확인은 새 terminal(터미널)이나 새 PowerShell 창에서 진행합니다.

Linux:

```sh
./linux/install.sh --status
```

Windows:

```powershell
.\windows\install.ps1 -Status
```

## 10. Facilitator Notes(진행자 메모)

초보자 교육에서는 아래 원칙을 지킵니다.

- 처음부터 terminal(터미널)을 열라고 하지 않는다.
- "모르면 나중에"를 정상 선택지로 설명한다.
- 설치 전 Final Installation Plan(최종 설치 계획)을 반드시 보여준다.
- 참가자마다 workspace folder(작업 폴더)를 통일한다.
- 권한, 로그인, 재시작이 필요한 순간에는 멈춰서 설명한다.
- 설치가 끝난 뒤에는 새 terminal(터미널)을 열어 status(상태)만 확인한다.

진행자가 초보자에게 강조할 한 문장은 이것입니다.

```text
지금 바로 설치하는 게 아니라, Codex가 먼저 계획을 세우고 확인받은 다음 설치합니다.
```
