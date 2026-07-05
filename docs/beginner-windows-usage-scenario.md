# Windows 초보 사용자 시나리오

이 문서는 Todo 1 범위에 포함된 계획 문서다. 비개발자 Windows 사용자가
`ai-boiler-plate`를 처음 시작할 때 Claude/Codex 스타일 코딩 에이전트 앱을
먼저 쓰는 흐름을 확인하기 위해 둔다.

## 성공 기준

- 사용자는 터미널 명령을 먼저 외우지 않아도 시작할 수 있다.
- 에이전트는 한 번에 하나의 질문만 하며 상태를 저장하고 이어서 진행한다.
- PowerShell이나 터미널은 fallback, 고급 사용자, QA 확인용으로만 안내한다.
- Matt Pocock Skills setup은 필수로 안내한다.
- LazyCodex, oh-my-claudecode, Hermes, Superpowers 같은 add-on은 사용자가 명시적으로 선택할 때만 설치한다.
- Superpowers를 선택하면 초보자 기본값은 Debug/Verify Pack만 설치하고, 전체 workflow/plugin은 고급 수동 옵션으로 안내한다.
- 사업성, 상업적 판단, 고객 가치 검증 질문은 보이는 G-stack office-hours repo/link를 먼저 쓰고, 없을 때만 사용자에게 물어본다.
- 비밀번호, 토큰, OAuth 코드, 런타임 홈 인증 파일은 저장하거나 수정하지 않는다.

## 1. 에이전트 앱에서 시작

사용자는 Claude, Codex 같은 코딩 에이전트 앱을 열고 아래 두 줄을 붙여넣는다.

```text
https://github.com/socialsolidaritybank/ai-boiler-plate
보일러 플레이트 시작해줘
```

에이전트는 현재 저장소 상태를 확인하고, Windows에서는 읽기 전용 상태 확인을
우선 실행한다.

```powershell
.\windows\install.ps1 -Status
```

처음 사용자에게는 PowerShell 명령을 먼저 요구하지 않는다. 명령 실행은 에이전트가
대신 하거나, 사용자가 직접 확인해야 하는 fallback/QA 상황에서만 짧게 안내한다.

## 2. 한 번에 하나씩 묻기

설치 흐름은 여러 선택지를 한꺼번에 던지지 않는다. 각 단계는 질문 하나, 선택 하나,
상태 저장 하나로 끝난다.

예상 단계:

```text
1. 기본 설치 준비
2. GitHub 연결
3. AI 도구 선택
4. Matt Pocock Skills setup
5. 선택 add-on 확인
6. 리포트와 수동 안내서 생성
```

사용자가 중간에 멈추면 저장된 state를 보고 같은 자리에서 이어간다.

## 3. 기본 설치 준비

에이전트는 Git, GitHub CLI, Node.js, Python 같은 기본 도구가 있는지 확인한다.
없는 항목은 설치 후보로 설명하고 사용자에게 한 번에 하나씩 물어본다.

초보자에게 설명할 때는 개발 용어를 짧게 풀어쓴다.

- Git: 작업 기록을 남기는 도구
- GitHub: 작업물을 보관하고 공유하는 서비스
- Node.js/Python: 여러 개발 도구가 실행될 때 쓰는 기반 프로그램
- PATH: PowerShell이 프로그램을 찾는 경로 목록

## 4. GitHub 연결

GitHub 계정이 없으면 가입 링크를 먼저 안내한다. 계정이 있으면 `gh auth login`을
통해 로그인 상태를 확인한다.

비밀번호, 토큰, OAuth 코드는 문서나 설정 파일에 저장하지 않는다. 로그인은 GitHub
CLI와 브라우저의 공식 흐름에 맡긴다.

## 5. AI 도구와 Matt Pocock setup

AI 도구 선택은 Codex, Claude, 둘 다, 나중에 정하기처럼 명확한 선택지만 보여준다.
선택한 도구만 설치하거나 확인한다.

Matt Pocock Skills는 필수 setup으로 안내한다.

```powershell
npx skills@latest add mattpocock/skills
```

설치 뒤 에이전트에는 다음 setup 명령을 입력하도록 안내한다.

```text
/setup-matt-pocock-skills
```

`~/.codex/skills`, `~/.claude/skills`, `~/.agents/skills` 같은 런타임 홈에는 직접
쓰지 않는다. 필요한 경우 공식 설치 명령이나 repo-local SSOT 흐름만 사용한다.

## 6. 선택 add-on

선택 add-on은 기본값으로 설치하지 않는다. 사용자가 필요하다고 선택한 경우에만
무엇이 설치되는지, 왜 필요한지, 건너뛰면 어떤 차이가 있는지 설명한다.

권장 기본 선택:

```text
선택 add-on은 지금 설치하지 않음
```

사용자가 나중에 원하면 상태를 보고 해당 단계만 다시 실행한다.

## 7. 사업 판단 질문

설치나 설정 중 사업성, 상업적 판단, 고객 가치 검증 같은 질문이 나오면
`ai-boiler-plate`가 임의로 판단하지 않는다.

처리 순서:

1. 이미 설정되어 있거나 화면에 보이는 G-stack office-hours repo/link를 먼저 사용한다.
2. 보이는 repo/link가 없으면 그때 사용자에게 요청한다.
3. 비공개 URL, 로컬 절대 경로, 운영 ID는 문서에 하드코딩하지 않는다.

## 8. 상태, 이어가기/재실행, 리포트, 수동 안내서

진행 상태는 status로 확인한다.

```powershell
.\windows\install.ps1 -Status
```

설치가 중단되면 저장된 state를 기준으로 resume한다. 마무리 단계에서는 사용자가
무엇을 설치했는지, 무엇을 건너뛰었는지, 다음에 무엇을 하면 되는지 report와
manual로 남긴다.

브라우저로 HTML manual을 열어야 할 때는 자동으로 열지 않고 사용자에게 먼저 묻는다.

## 9. fallback/QA 명령

고급 사용자나 QA 담당자는 필요할 때만 PowerShell에서 직접 실행할 수 있다.

```powershell
git clone https://github.com/socialsolidaritybank/ai-boiler-plate.git
cd .\ai-boiler-plate
.\windows\install.ps1 -Status
.\windows\install.ps1 -DryRun
```

이 명령들은 기본 시작 경로가 아니라 확인용이다. 일반 초보 사용자에게는 에이전트 앱
시작 흐름을 먼저 안내한다.

## 10. 금지 사항

- 비밀번호, 토큰, OAuth 코드를 저장하지 않는다.
- 런타임 홈 인증 파일이나 skill 폴더에 직접 쓰지 않는다.
- 커밋, 푸시, 원격 저장소 변경은 사용자가 명시적으로 요청하기 전에는 하지 않는다.
- 선택 add-on을 묻지 않고 설치하지 않는다.
- 사업 판단용 G-stack private URL이나 로컬 경로를 문서에 박아 넣지 않는다.
