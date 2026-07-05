# ai-boiler-plate

![ai-boiler-plate banner](docs/banner.png)

ai-boiler-plate는 비개발자도 Claude나 Codex 같은 코딩 에이전트 앱에서 질문에 답하며 개발 환경을 준비할 수 있게 돕는 보일러플레이트입니다. 설치 명령을 먼저 외우는 흐름이 아니라, 사용자가 에이전트에게 저장소 링크를 주고 승인하면 가능한 범위에서 직접 설치를 시도합니다. 권한이 막히면 무엇을 허용해야 하는지 알려주고 다시 진행할 수 있게 합니다.

## 출처와 변경 이력

이 저장소는 [`foxion37/lazy-starter-kit`](https://github.com/foxion37/lazy-starter-kit)을 포크해 시작했습니다. ai-boiler-plate는 그 위에 사회연대은행 사용 환경에 맞춘 질문형 설치 흐름, 코딩 에이전트 재시작 방식, 설치 기록, HTML 매뉴얼을 더해 다시 설계한 보일러플레이트입니다.

원본 README는 비교와 추적을 위해 보관했습니다.

- `README.upstream.ko.md`
- `README.upstream.en.md`

## 처음 시작하기

가장 쉬운 첫 실행은 터미널이 아니라 코딩 에이전트 앱에서 시작합니다.

1. Claude, Codex, Cursor 같은 코딩 에이전트 앱을 엽니다.
2. 이 저장소 링크 `https://github.com/socialsolidaritybank/ai-boiler-plate`를 전달합니다.
3. `보일러 플레이트 시작해줘`라고 말합니다.

에이전트는 저장소를 열고 현재 상태를 확인한 뒤, 한 번에 하나씩 질문하며 설치를 이어갑니다. 다음에도 같은 앱에서 `보일러 플레이트 시작해줘`라고 말하면 이어서 진행할 수 있습니다.

PowerShell이나 터미널 명령은 고급 사용자, QA, 장애 복구용 fallback입니다. 기존 설치 사용자를 위한 옛 alias는 한 릴리스 동안 호환용으로만 남기고 새 안내에서는 ai-boiler-plate를 기준으로 설명합니다.

에이전트가 사업성(business viability), 상업적 판단(commercial judgment), 고객 가치 검증 같은 business judgment가 필요한 질문을 만나면, 설정되어 있거나 눈에 보이는 G-stack office-hours repo/link를 먼저 사용합니다. 보이지 않을 때만 그 순간 사용자에게 G-stack office-hours repo/link를 물어봅니다.

## Required AI skill setup

Matt Pocock Skills are required setup for this boilerplate. Run:

```sh
npx skills@latest add mattpocock/skills
```

Then ask your Claude/Codex agent:

```text
/setup-matt-pocock-skills
```

LazyCodex, oh-my-claudecode, Hermes, and similar add-ons stay optional and are installed only after explicit opt-in.

## 지원 범위

| OS | 실행 파일 | 주요 설치 방식 |
| --- | --- | --- |
| macOS | `install.sh` | Xcode CLT, Homebrew, `Brewfile`, mise, zsh, AI 도구 |
| Linux | `linux/install.sh` | 배포판 패키지 매니저, 공식 사용자 설치 스크립트, mise, zsh |
| Windows | `windows/install.ps1` | winget, PowerShell profile, mise, AI 도구 |

기본 설치는 멱등성, 즉 여러 번 실행해도 같은 상태를 유지하는 성질을 지킵니다.
이미 있는 도구는 건너뛰고, 셸 설정은 `ai-boiler-plate:*` 관리 블록 안에서만
갱신합니다.

## 터미널 fallback / QA 확인

```sh
./install.sh --status
./install.sh --list
./install.sh --classic --dry-run --skip docker
./install.sh --dry-run --skip docker
./linux/install.sh --dry-run --skip docker
```

Windows:

```powershell
.\windows\install.ps1 -Status
.\windows\install.ps1 -List
.\windows\install.ps1 -DryRun -Skip docker
```

`--status`는 저장된 진행 상태만 보여주는 읽기 전용 확인입니다. `--classic`은 개발자와 CI가 기존 단계형 설치를 그대로 실행할 때 씁니다. 고급 옵션인 `--dry-run`, `--only`, `--skip`, `--list`도 계속 사용할 수 있습니다.

## 회사별로 바꿀 곳

| 목적 | 파일 |
| --- | --- |
| macOS 기본 도구 | `Brewfile` |
| macOS 사내 추가 도구 | `Brewfile.bss` |
| Linux 사내 추가 패키지 | `linux/config/bss-packages.sh` |
| Windows 사내 추가 패키지 | `windows/config/bss-packages.ps1` |
| macOS/Linux 셸 블록 | `config/zshrc.block.sh`, `linux/config/zshrc.block.sh` |
| Windows PowerShell 블록 | `windows/config/profile.block.ps1` |
| AI agent 설치 | `scripts/07-agents.sh`, `linux/scripts/07-agents.sh`, `windows/scripts/07-agents.ps1` |
| 스킬/플러그인 교체 범위 | `docs/extension-points.md` |

`Brewfile.bss`와 OS별 `bss-packages` 파일은 처음에는 비어 있습니다. 전 직원
장비에 기본으로 깔아도 되는 도구만 넣고, 라이선스나 보안 승인이 필요한 도구는
별도 단계로 분리하세요.

핵심 설치 요소(Homebrew/winget/Linux package manager, mise, rustup, uv, bun,
PowerShell/zsh, Git/GitHub, Docker/Colima, status/resume/report)는 v1 기본값으로
고정합니다. 이후 교체는 스킬, 플러그인, 선택 add-on 레이어에서만 진행합니다.
범위와 체크리스트는 [`docs/extension-points.md`](docs/extension-points.md)를
기준으로 봅니다.

## 게시 준비

기본 공개 대상은 `https://github.com/socialsolidaritybank/ai-boiler-plate.git`입니다. 이 lane은 게시 준비만 확인합니다. 커밋, 푸시, GitHub 레포 생성은 사용자가 명시적으로 요청하기 전에는 하지 않습니다.

환경 변수로 다른 원격을 지정해 테스트할 수 있습니다.

```sh
AI_BOILER_PLATE_REPO=https://github.com/socialsolidaritybank/ai-boiler-plate.git ./install.sh --dry-run
```

```powershell
$env:AI_BOILER_PLATE_REPO = 'https://github.com/socialsolidaritybank/ai-boiler-plate.git'
.\windows\install.ps1 -DryRun
```

`BSS_BOILERPLATE_REPO` 같은 옛 환경 변수 이름은 기존 설치 사용자를 위한 deprecated compatibility alias로만 다룹니다. 새 문서와 새 자동화에서는 `AI_BOILER_PLATE_REPO`를 사용하세요.
