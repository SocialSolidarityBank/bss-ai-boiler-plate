# BSS AI Helper

BSS AI Helper는 비개발자도 Codex에서 질문에 답하며 개발 환경을 준비할 수 있게 돕는 설치 도우미입니다. 설치 방법만 안내하고 끝내지 않고, 사용자가 승인하면 가능한 범위에서 직접 설치를 시도합니다. 권한이 막히면 무엇을 허용해야 하는지 알려주고 다시 진행할 수 있게 합니다.

## 출처와 변경 이력

이 저장소는 [`foxion37/lazy-starter-kit`](https://github.com/foxion37/lazy-starter-kit)을 포크해 시작했습니다. BSS AI Helper는 그 위에 사회연대은행 사용 환경에 맞춘 질문형 설치 흐름, Codex 재시작 방식, 설치 기록, HTML 매뉴얼을 더해 다시 설계한 보일러플레이트입니다.

원본 README는 비교와 추적을 위해 보관했습니다.

- `README.upstream.ko.md`
- `README.upstream.en.md`

## 처음 시작하기

먼저 GitHub 레포를 clone하고, 정해진 폴더에서 Codex를 실행합니다.

```sh
git clone https://github.com/socialsolidaritybank/bss-ai-helper.git ~/bss-ai-helper
cd ~/bss-ai-helper
codex
```

Codex가 열리면 `BSS AI Helper 실행해줘`라고 말합니다. 다음에 Codex에서 같은 말을 하면 이어서 진행할 수 있습니다.

터미널에서는 설치 후 `bss-ai-helper`, `ai-helper`, `bss-ai`를 사용할 수 있습니다.

## 지원 범위

| OS | 실행 파일 | 주요 설치 방식 |
| --- | --- | --- |
| macOS | `install.sh` | Xcode CLT, Homebrew, `Brewfile`, mise, zsh, AI 도구 |
| Linux | `linux/install.sh` | 배포판 패키지 매니저, 공식 사용자 설치 스크립트, mise, zsh |
| Windows | `windows/install.ps1` | winget, PowerShell profile, mise, AI 도구 |

기본 설치는 멱등성, 즉 여러 번 실행해도 같은 상태를 유지하는 성질을 지킵니다.
이미 있는 도구는 건너뛰고, 셸 설정은 `bss-ai-boilerplate:*` 관리 블록 안에서만
갱신합니다.

## 빠른 확인

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

`Brewfile.bss`와 OS별 `bss-packages` 파일은 처음에는 비어 있습니다. 전 직원
장비에 기본으로 깔아도 되는 도구만 넣고, 라이선스나 보안 승인이 필요한 도구는
별도 단계로 분리하세요.

## 게시 준비

기본 clone 대상은 `https://github.com/socialsolidaritybank/bss-ai-helper.git`입니다. 이 lane은 게시 준비만 확인합니다. 커밋, 푸시, GitHub 레포 생성은 사용자가 명시적으로 요청하기 전에는 하지 않습니다.

환경 변수로 다른 원격을 지정해 테스트할 수 있습니다.

```sh
BSS_BOILERPLATE_REPO=https://github.com/socialsolidaritybank/bss-ai-helper.git ./install.sh --dry-run
```

```powershell
$env:BSS_BOILERPLATE_REPO = 'https://github.com/socialsolidaritybank/bss-ai-helper.git'
.\windows\install.ps1 -DryRun
```
