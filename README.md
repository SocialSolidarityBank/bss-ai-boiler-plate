# BSS AI Helper

![bss-ai-boiler-plate banner](docs/banner.png)

BSS AI Helper는 회사 PC에서 AI 개발 도구와 기본 개발 환경을 준비할 때 쓰는 설치 도우미입니다. 터미널 명령을 많이 모르는 분도 Codex에게 저장소를 맡기고, 질문에 답하면서 설치를 이어갈 수 있게 만든 도구입니다.

Codex는 OpenAI의 코딩 에이전트입니다. 이 저장소 폴더에서 Codex를 열고 `BSS AI Helper 실행해줘`라고 말하면, Codex가 현재 상태를 확인한 뒤 필요한 설치 스크립트를 실행하도록 도와줍니다. 설치 방법만 안내하고 끝내는 것이 아니라, 사용자가 승인하면 직접 설치를 시도합니다.

## 처음 쓰는 분을 위한 안내

Windows 회사 노트북을 기준으로 설명하면 흐름은 이렇게 단순합니다.

```sh
git clone https://github.com/socialsolidaritybank/bss-ai-boiler-plate.git ~/bss-ai-boiler-plate
cd ~/bss-ai-boiler-plate
codex
```

Codex가 열리면 이렇게 말합니다.

```text
BSS AI Helper 실행해줘
```

그 다음부터는 Codex가 `.\windows\install.ps1 -Status`로 먼저 상태를 확인하고, 이어서 무엇을 할지 물어봅니다. macOS나 Linux에서는 같은 확인을 `./install.sh --status` 또는 `./linux/install.sh --status`로 합니다.

설치 중에는 이런 질문이나 승인 요청이 나올 수 있습니다.

- 기본 도구를 설치할지, 지금은 상태만 볼지, 실패한 단계를 건너뛸지 고릅니다.
- GitHub 로그인 확인처럼 계정 연결이 필요한 일은 직접 승인해야 합니다.
- 관리자 권한, PowerShell 실행 정책, `winget`, Homebrew, Linux 패키지 매니저 같은 시스템 권한이 필요할 수 있습니다.
- 설치가 막히면 Codex가 실패 이유와 다음 행동을 보여주고, 다시 시도하거나 건너뛸 수 있게 합니다.

BSS AI Helper가 할 수 있는 일은 OS마다 조금 다릅니다. Windows에서는 `winget` 패키지, PowerShell profile, mise, AI 도구를 주로 다룹니다. macOS에서는 Xcode CLT, Homebrew, `Brewfile`, mise, zsh, AI 도구를 준비합니다. Linux에서는 배포판 패키지 매니저, 공식 사용자 설치 스크립트, mise, zsh, AI 도구를 다룹니다.

반대로 조용히 하지 않는 일도 있습니다. 비밀번호, 토큰, OAuth 코드는 저장하지 않습니다. GitHub 레포 생성, 커밋, 푸시, 원격 변경은 사용자가 명시적으로 요청하기 전에는 하지 않습니다. Docker는 별도 선택 항목입니다. Windows Docker Desktop은 라이선스와 재부팅 이슈가 있어 `-Yes`나 비대화형 실행에서 설치하지 않습니다. Linux는 `--with-docker`, `BSS_INSTALL_DOCKER=1`, `BSS_AI_HELPER_INSTALL_DOCKER=1` 중 하나로 허용해야 Docker를 진행합니다. macOS는 Colima VM 시작을 질문으로 확인합니다.

중간에 창을 닫았거나 실패했을 때는 다시 같은 폴더에서 Codex를 열고 `BSS AI Helper 실행해줘`라고 말하면 됩니다. 먼저 상태를 보고 이어서 진행합니다. 터미널에서 직접 확인하고 싶다면 아래 명령을 쓰면 됩니다.

```powershell
.\windows\install.ps1 -Status
```

```sh
./install.sh --status
./linux/install.sh --status
```

설치가 끝나면 터미널에서 `bss-ai-helper`, `ai-helper`, `bss-ai` 명령으로 상태 확인과 재시작 표면을 사용할 수 있습니다. 여기서 `bss-ai-helper`는 설치 후 쓰는 실행 명령 이름이고, clone할 GitHub 저장소 이름은 `bss-ai-boiler-plate`입니다. 현재 단계 목록은 macOS/Linux/Windows 모두 설치 단계 뒤에 `resume`, `report`를 포함합니다. `resume`은 다시 시작할 수 있는 명령을 준비하고, `report`는 마무리 리포트를 만듭니다.

## 개발자용 빠른 명령

macOS:

```sh
./install.sh --status
./install.sh --list
./install.sh --classic --dry-run --skip docker
./install.sh --dry-run --skip docker
```

Linux:

```sh
./linux/install.sh --status
./linux/install.sh --list
./linux/install.sh --classic --dry-run --skip docker
./linux/install.sh --wizard
./linux/install.sh --dry-run --skip docker
./linux/install.sh --yes --with-docker
```

Windows:

```powershell
.\windows\install.ps1 -Status
.\windows\install.ps1 -List
.\windows\install.ps1 -Classic -DryRun -Skip docker
.\windows\install.ps1 -Wizard
.\windows\install.ps1 -DryRun -Skip docker
```

`--status`와 Windows `-Status`는 저장된 진행 상태만 읽는 확인 명령입니다. `--classic`과 Windows `-Classic`은 개발자와 CI가 기존 단계형 설치를 실행할 때 씁니다. `--wizard`와 Windows `-Wizard`는 질문형 설치를 명시적으로 시작합니다. Linux의 `--wizard`는 pipe 입력이면 `/dev/tty`를 찾고, 터미널이 없으면 classic 경로로 돌아갑니다. Windows의 `-Wizard`는 콘솔이나 전달된 입력에서 답을 읽을 수 있을 때만 질문을 진행합니다.

## 관리 마커와 호환성

셸과 PowerShell profile에는 `bss-ai-boilerplate:*` 관리 블록이 남아 있을 수 있습니다. 제품 이름은 BSS AI Helper지만, 이 마커는 이미 설치된 사용자 환경과의 호환성을 위해 유지합니다.

무서운 경고가 아니라 중복 수정을 막는 표식입니다. 설치 스크립트는 이 블록 안에서만 관리 내용을 갱신합니다. 예전 마커를 강제로 이름 변경하지 않고, 설치/제거 스크립트가 필요한 범위에서만 정리합니다.

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

`Brewfile.bss`와 OS별 `bss-packages` 파일은 처음에는 비어 있습니다. 전 직원 장비에 넣어도 되는 도구만 추가하고, 라이선스나 보안 승인이 필요한 도구는 별도 절차로 다루는 편이 안전합니다.

## 배포 저장소와 게시 준비

기본 clone 대상은 `https://github.com/socialsolidaritybank/bss-ai-boiler-plate.git`입니다.

회사 fork나 이름이 바뀐 배포 저장소를 써야 한다면 설치 기본값을 바꾸지 말고 실행할 때 `BSS_BOILERPLATE_REPO`로 넘기면 됩니다.

```sh
BSS_BOILERPLATE_REPO=https://github.com/socialsolidaritybank/bss-ai-boiler-plate.git ./install.sh --dry-run
```

```powershell
$env:BSS_BOILERPLATE_REPO = 'https://github.com/socialsolidaritybank/bss-ai-boiler-plate.git'
.\windows\install.ps1 -DryRun
```

이 lane은 게시 준비를 읽기 전용으로 확인합니다. 커밋, 푸시, GitHub 레포 생성, 원격 변경은 사용자가 명시적으로 요청한 뒤에만 합니다.

## English Summary

BSS AI Helper is a Korean-first installer helper for company staff who want Codex to prepare a development environment with guided questions. Clone `https://github.com/socialsolidaritybank/bss-ai-boiler-plate`, run `codex`, and ask `BSS AI Helper 실행해줘`. Codex checks status first, then helps run the macOS, Linux, or Windows installer.

The installer keeps status and resume/report surfaces, supports classic automation commands, and preserves `bss-ai-boilerplate:*` profile markers for compatibility. Docker is opt-in, secrets are not stored, and repository publishing actions are read-only unless the user explicitly asks for Git changes.

## 참고 자료

- [OpenAI Codex CLI docs](https://developers.openai.com/codex/cli)
- [OpenAI Codex repository](https://github.com/openai/codex)
- [Microsoft WinGet docs](https://learn.microsoft.com/en-us/windows/package-manager/winget/)
- [GitHub Actions workflow syntax](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions)
- [humanize-korean source: epoko77-ai/im-not-ai](https://github.com/epoko77-ai/im-not-ai)

## 출처와 변경 이력

이 저장소는 [Heoooooon/lazy-starter-kit](https://github.com/Heoooooon/lazy-starter-kit)을 포크해서 시작했고, 지금은 사회연대은행 사용 환경에 맞춘 BSS AI Helper로 운영합니다. 현재 공개 저장소와 릴리스 대상은 `https://github.com/socialsolidaritybank/bss-ai-boiler-plate`입니다.

원본 출처와 README 스냅샷은 비교와 라이선스 추적을 위해 보관했습니다.

- `README.upstream.ko.md`
- `README.upstream.en.md`
