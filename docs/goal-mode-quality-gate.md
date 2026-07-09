# Goal Mode Quality Gate(목표 모드 품질 게이트)

이 문서는 초보자 표준 설치 workflow(작업 흐름)를 수정하거나 설치 결과물에 영향을 주는 모든 작업에서 품질을 균일하게 유지하기 위한 강제 루프입니다.

## 목적

에이전트나 사람이 아래 명세를 하나라도 놓치면 완료로 말하지 않습니다.

- 초보자 표준 설치는 Plan Mode(계획 모드)에서 먼저 질문한다.
- 설치 전 Final Installation Plan(최종 설치 계획)을 발행한다.
- 승인 전에는 폴더 생성, `git clone`, installer(설치 프로그램)를 실행하지 않는다.
- Windows/Linux 초보자 표준 경로를 유지한다.
- 설치 완료 후 `latest-report.md`와 `manual/index.html`을 생성한다.
- HTML manual(HTML 사용 매뉴얼)은 초보자 자연어, Pretendard, black/grey/white/blue, point(점)/line(선)/surface(면), 4px-16px radius(둥근 정도) 규칙을 지킨다.
- Superpowers는 Debug/Verify Pack이 아니라 Planning Pack(계획 스킬 묶음)으로 안내한다.

## /goal Loop(/goal 루프)

작업을 시작할 때 에이전트에게 아래처럼 요청합니다.

```text
/goal
목표: 이 레포의 초보자 표준 설치 명세를 지키면서 요청한 변경을 완료한다.
완료 조건: scripts/qa/goal-mode-gate.sh --quick 이 통과해야만 최종 답변한다.
```

작업 루프는 고정입니다.

1. Plan(계획): 변경 범위와 영향 파일을 정리한다.
2. Implement(구현): 문서, 스크립트, QA를 함께 수정한다.
3. Gate(게이트): `scripts/qa/goal-mode-gate.sh --quick`을 실행한다.
4. Repair(수정): 실패하면 최종 답변하지 않고 실패 항목을 고친다.
5. Repeat(반복): 게이트가 통과할 때까지 3-4번을 반복한다.
6. Final(최종): 통과한 검증 결과를 포함해서만 완료 답변한다.

merge(병합)나 push(푸시) 전에는 full gate(전체 게이트)를 실행합니다.

```sh
scripts/qa/goal-mode-gate.sh --full
```

## Hook(훅)

로컬 git hook(깃 훅)은 아래 명령으로 켭니다.

```sh
scripts/install-goal-hooks.sh
```

설정 후 동작은 다음과 같습니다.

- `pre-commit`: `scripts/qa/goal-mode-gate.sh --quick`
- `pre-push`: `scripts/qa/goal-mode-gate.sh --full`

Git의 `--no-verify`는 로컬 훅을 우회할 수 있습니다. 그래서 CI(지속 통합)에서도 같은 gate(게이트)를 실행해 최종 보호막을 둡니다.

## 에이전트 완료 규칙

Goal Gate(목표 게이트)가 실패하면 에이전트는 최종 완료 답변을 하지 않습니다.

허용되는 답변은 하나뿐입니다.

```text
Goal Gate(목표 게이트)가 실패해서 완료로 보고하지 않겠습니다.
실패 항목을 수정한 뒤 다시 검증하겠습니다.
```

통과 후에는 최종 답변에 아래 중 실제 실행한 항목을 포함합니다.

- `scripts/qa/goal-mode-gate.sh --quick`
- `scripts/qa/goal-mode-gate.sh --full`
- 추가로 실행한 OS별 smoke test(스모크 테스트)
