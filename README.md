# BSS AI Helper

![bss-ai-boiler-plate banner](docs/banner.png)

BSS AI Helper는 비개발자도 Codex에서 질문에 답하며 개발 환경을 준비할 수 있게 돕는 설치 도우미입니다. 설치 방법만 안내하고 끝내지 않고, 사용자가 승인하면 가능한 범위에서 직접 설치를 시도합니다. 권한이 막히면 무엇을 허용해야 하는지 알려주고 다시 진행할 수 있게 합니다.

## 출처와 변경 이력

이 저장소는 기존 macOS 개발환경 설치 키트를 바탕으로 시작했고, 지금은 사회연대은행 사용 환경에 맞춘 BSS AI Helper로 운영합니다. 현재 공개 저장소와 릴리스 대상은 `https://github.com/socialsolidaritybank/bss-ai-helper`입니다.

원본 출처와 README 스냅샷은 비교와 라이선스 추적을 위해 보관했습니다.

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
현재 단계 목록은 macOS/Linux/Windows 모두 설치 단계 뒤에 `resume`, `report`를
포함합니다. 즉 `--list`/`-List`는 플랫폼별 설치 단계와 다시 시작 표면, 마무리
리포트 단계를 함께 보여줍니다.

`bss-ai-boilerplate:*`는 현재도 호환성을 위해 쓰는 내부 관리 마커입니다. 제품 이름은
BSS AI Helper지만, 이미 설치된 사용자 profile 블록을 이 작업에서 강제로 이름 변경하지
않습니다. 예전 마커는 설치/제거 스크립트가 중복 방지를 위해 필요한 범위에서만 정리합니다.

## 설치 모드 계약

- 터미널에서 직접 실행하면 가능한 경우 질문형 wizard가 먼저 열립니다.
- 자동화와 CI는 `--classic` 또는 Windows의 `-Classic`으로 기존 단계형 설치를 실행합니다.
- pipe나 리디렉션처럼 입력이 비대화형이면 질문을 조용히 건너뛰지 않고 classic 경로로 갑니다. Linux의 `--wizard`는 `/dev/tty`가 있으면 거기서 답을 읽고, 없으면 classic으로 돌아갑니다. Windows의 `-Wizard`는 콘솔이나 전달된 입력에서 답을 읽을 수 있을 때만 질문을 진행합니다.
- `--status`와 Windows `-Status`는 저장된 진행 상태만 읽는 확인 명령입니다.
- Docker는 명시적 opt-in입니다. macOS는 Colima VM 시작을 질문으로 확인하고, Linux는 `--yes`에서 Docker를 건너뛰며 `--with-docker`, `BSS_INSTALL_DOCKER=1`, 또는 `BSS_AI_HELPER_INSTALL_DOCKER=1`이 있어야 설치를 허용합니다. Windows Docker Desktop은 라이선스와 재부팅 이슈 때문에 `-Yes`나 비대화형 실행에서 설치하지 않습니다.

## 빠른 확인

```sh
./install.sh --status
./install.sh --list
./install.sh --classic --dry-run --skip docker
./install.sh --dry-run --skip docker
./linux/install.sh --status
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
