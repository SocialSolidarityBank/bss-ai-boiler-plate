# BSS AI Helper

![bss-ai-boiler-plate banner](docs/banner.png)

BSS AI Helper는 회사 PC에 AI 개발 도구와 기본 개발 환경을 준비해 주는 설치 도우미입니다. 터미널 명령이 낯선 분도 Codex를 켠 뒤 질문에 답하면서 설치를 진행할 수 있습니다.

Codex는 OpenAI의 코딩 에이전트입니다. 이 저장소 폴더에서 Codex를 열고 `BSS AI Helper 실행해줘`라고 말하면, Codex가 먼저 현재 상태를 확인합니다. 그다음 필요한 설치 스크립트를 실행해도 되는지 물어보고, 사용자가 승인하면 직접 설치를 진행합니다.

## 처음 쓰는 분을 위한 안내

Windows 회사 노트북을 기준으로 보면 시작 방법은 간단합니다.

```sh
git clone https://github.com/socialsolidaritybank/bss-ai-boiler-plate.git ~/bss-ai-boiler-plate
cd ~/bss-ai-boiler-plate
codex
```

Codex가 열리면 이렇게 말합니다.

```text
BSS AI Helper 실행해줘
```

이후에는 Codex가 `.\windows\install.ps1 -Status`로 먼저 설치 상태를 확인합니다. 그런 다음 설치를 계속할지, 상태만 볼지, 특정 단계를 건너뛸지 물어봅니다. macOS나 Linux에서는 같은 확인을 `./install.sh --status` 또는 `./linux/install.sh --status`로 합니다.

설치 중에는 이런 질문이나 승인 요청이 나올 수 있습니다.

- 기본 도구를 설치할지, 지금은 상태만 볼지, 실패한 단계를 건너뛸지 선택합니다.
- GitHub 로그인처럼 계정 연결이 필요한 일은 사용자가 직접 승인해야 합니다.
- 관리자 권한, PowerShell 실행 정책, `winget`, Homebrew, Linux 패키지 매니저처럼 PC 설정과 관련된 확인이 나올 수 있습니다.
- 설치가 막히면 Codex가 실패 이유를 보여주고, 다시 시도하거나 해당 단계를 건너뛸 수 있게 안내합니다.

BSS AI Helper가 준비하는 항목은 운영체제마다 조금 다릅니다. Windows에서는 `winget` 패키지, PowerShell 설정, mise, AI 도구를 주로 다룹니다. macOS에서는 Xcode CLT, Homebrew, `Brewfile`, mise, zsh, AI 도구를 준비합니다. Linux에서는 배포판 패키지 매니저, 공식 사용자 설치 스크립트, mise, zsh, AI 도구를 다룹니다.

사용자 몰래 하지 않는 일도 정해 두었습니다. 비밀번호, 토큰, OAuth 코드는 저장하지 않습니다. GitHub 저장소 생성, 커밋, 푸시, 원격 저장소 변경은 사용자가 명시적으로 요청하기 전에는 하지 않습니다. Docker도 자동으로 설치하지 않습니다. Windows Docker Desktop은 라이선스와 재부팅 이슈가 있어 `-Yes`나 비대화형 실행에서는 설치하지 않습니다. Linux는 `--with-docker`, `BSS_INSTALL_DOCKER=1`, `BSS_AI_HELPER_INSTALL_DOCKER=1` 중 하나로 허용해야 Docker 설치를 진행합니다. macOS는 Colima VM을 시작해도 되는지 먼저 확인합니다.

중간에 창을 닫았거나 설치가 실패해도 처음부터 다시 할 필요는 없습니다. 같은 폴더에서 Codex를 다시 열고 `BSS AI Helper 실행해줘`라고 말하면 됩니다. Codex가 먼저 상태를 확인한 뒤 이어서 진행합니다. 터미널에서 직접 상태를 보고 싶다면 아래 명령을 쓰면 됩니다.

```powershell
.\windows\install.ps1 -Status
```

```sh
./install.sh --status
./linux/install.sh --status
```

설치가 끝나면 터미널에서 `bss-ai-helper`, `ai-helper`, `bss-ai` 명령을 사용할 수 있습니다. 이 명령으로 설치 상태를 확인하거나, 중간에 멈춘 작업을 다시 이어갈 수 있습니다. 여기서 `bss-ai-helper`는 설치 후 쓰는 실행 명령 이름이고, clone할 GitHub 저장소 이름은 `bss-ai-boiler-plate`입니다. macOS/Linux/Windows 모두 설치 단계 뒤에 `resume`, `report` 단계가 있습니다. `resume`은 다시 이어서 실행할 명령을 준비하고, `report`는 마무리 리포트를 만듭니다.

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

`--status`와 Windows `-Status`는 저장된 진행 상태만 읽는 확인 명령입니다. `--classic`과 Windows `-Classic`은 개발자와 CI가 기존 단계형 설치를 실행할 때 씁니다. `--wizard`와 Windows `-Wizard`는 질문을 보면서 설치하고 싶을 때 씁니다. Linux의 `--wizard`는 파이프로 실행했을 때도 사용자가 답할 수 있는 터미널을 찾습니다. 답을 받을 터미널이 없으면 경고를 보여주고 기본 단계형 설치로 돌아갑니다. Windows의 `-Wizard`도 답을 읽을 수 있을 때만 질문을 진행합니다.

## 관리 마커와 호환성

셸과 PowerShell profile에는 `bss-ai-boilerplate:*`라는 관리 표시가 남아 있을 수 있습니다. 제품 이름은 BSS AI Helper지만, 이미 설치된 사용자 환경이 깨지지 않도록 이 표시는 유지합니다.

이 표시는 무서운 경고가 아니라 중복 수정을 막기 위한 구분선입니다. 설치 스크립트는 이 블록 안의 내용만 갱신합니다. 예전 표시 이름을 억지로 바꾸지 않고, 설치와 제거에 필요한 범위에서만 정리합니다.

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

`Brewfile.bss`와 OS별 `bss-packages` 파일은 처음에는 비어 있습니다. 모든 직원 장비에 설치해도 되는 도구만 넣어 주세요. 라이선스나 보안 승인이 필요한 도구는 별도 절차로 다루는 편이 안전합니다.

## 배포 저장소와 게시 준비

기본 clone 대상은 `https://github.com/socialsolidaritybank/bss-ai-boiler-plate.git`입니다.

회사 fork나 이름이 다른 배포 저장소를 써야 한다면, 설치 스크립트를 직접 고치지 말고 실행할 때 `BSS_BOILERPLATE_REPO`로 넘기면 됩니다.

```sh
BSS_BOILERPLATE_REPO=https://github.com/socialsolidaritybank/bss-ai-boiler-plate.git ./install.sh --dry-run
```

```powershell
$env:BSS_BOILERPLATE_REPO = 'https://github.com/socialsolidaritybank/bss-ai-boiler-plate.git'
.\windows\install.ps1 -DryRun
```

이 검사는 게시 준비 상태를 읽기 전용으로 확인합니다. 커밋, 푸시, GitHub 저장소 생성, 원격 저장소 변경은 사용자가 명시적으로 요청한 뒤에만 합니다.

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

이 저장소는 [Heoooooon/lazy-starter-kit](https://github.com/Heoooooon/lazy-starter-kit)을 포크해서 시작했습니다. 지금은 사회연대은행 사용 환경에 맞춘 BSS AI Helper로 운영합니다. 현재 공개 저장소와 릴리스 대상은 `https://github.com/socialsolidaritybank/bss-ai-boiler-plate`입니다.

원본 출처와 README 스냅샷은 비교와 라이선스 추적을 위해 보관했습니다.

- `README.upstream.ko.md`
- `README.upstream.en.md`
