# Claude Code 문서 미러

[English](README.md) | **한국어**

[![Last Update](https://img.shields.io/github/last-commit/posimind/claude-code-docs/main.svg?label=docs%20updated)](https://github.com/posimind/claude-code-docs/commits/main)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)]()
[![Beta](https://img.shields.io/badge/status-early%20beta-orange)](https://github.com/posimind/claude-code-docs/issues)

https://code.claude.com/docs/en/ 의 Claude Code 문서를 3시간 간격으로 로컬에 미러링하고, Claude가 그 미러를 자동으로 쓰도록 훅으로 연결합니다. Anthropic 문서가 차단된 네트워크에서도 문서 질문이 계속 동작합니다.

## 이 프로젝트가 추구하는 것

Claude Code 문서는 웹에 있고, Claude는 그에 대한 질문에 답할 때마다 웹에 손을 뻗습니다. 이 프로젝트는 그 의존을 제거합니다: 문서는 디스크에 있고, 스스로 최신을 유지하며, Claude가 자동으로 사용합니다.

설계를 이끄는 목표는 세 가지입니다:

- **언제나 읽을 수 있는 문서.** 전체 문서를 로컬에 미러링하고 3시간마다 동기화합니다 — 빠른 회선에서든, 사내 프록시 뒤에서든, 완전한 오프라인에서든 같은 문서를 똑같이 볼 수 있습니다.
- **시키지 않아도 로컬 파일로 답하는 Claude.** 미러만으로는 부족합니다. 복사본의 존재를 Claude에게 알려주는 장치가 없기 때문입니다. 훅 두 개가 그 틈을 메웁니다: `WebFetch`에 걸린 `PreToolUse` 훅이 모든 `code.claude.com` 가져오기를 미러된 파일 읽기로 바꾸고, `SubagentStart` 훅이 문서 질문을 위임받는 서브에이전트인 `claude-code-guide`에게 첫 동작 전에 미러 위치를 알려줍니다.
- **방해하지 않는 최신성.** 업데이트는 백그라운드에서, 미러 자체의 갱신 주기인 3시간에 최대 1회 일어나며, 모든 네트워크 호출에 시간 상한이 있습니다 — 패킷을 조용히 버리는 네트워크에서도 동기화 장치가 읽기를 지연시킬 수 없습니다.

결과적으로 문서 질문은 미러에서 답을 얻습니다 — 정상 네트워크에서는 가져오기보다 빠르고, 차단된 네트워크에서는 그 방법으로만 동작합니다.

> ⚠️ **초기 베타입니다.** 이상 동작을 발견하면 [이슈를 등록](https://github.com/posimind/claude-code-docs/issues)해 주세요.

## 설치

macOS와 Linux를 지원합니다 (Windows: [기여 환영](#기여와-알려진-문제)). `git`, `jq`, `curl`이 필요하며, Linux에서는 `jq`를 먼저 설치해야 할 수 있습니다 (`apt install jq` / `yum install jq`).

```bash
curl -fsSL https://raw.githubusercontent.com/posimind/claude-code-docs/main/install.sh | bash
```

같은 명령으로 어떤 버전이든 업데이트·복구할 수 있습니다.

수행되는 작업:

1. `~/.claude-code-docs`에 설치 (기존 설치가 있으면 이전)
2. `/claude-docs` 슬래시 명령 생성 (Claude Code 명령 목록에는 `/claude-docs (user)`로 표시)
3. `~/.claude/settings.json`에 훅 3개 등록 — 모두 동일한 헬퍼 스크립트를 실행하며, 직접 추가한 훅은 건드리지 않습니다:

| 훅 | 역할 |
| :- | :--- |
| `Read`에 걸린 `PreToolUse` | Claude가 미러에서 읽을 때 미러를 동기화, 최대 3시간에 1회 |
| `WebFetch`에 걸린 `PreToolUse` | `code.claude.com` 가져오기를 미러된 파일로 리다이렉트 |
| `claude-code-guide`에 걸린 `SubagentStart` | 해당 서브에이전트에게 미러 위치를 알림 |

**설치 후 Claude Code를 재시작하세요** — 훅은 세션이 시작될 때 로드됩니다.

### 명령어 이름 변경

설치 시 `CLAUDE_DOCS_COMMAND_NAME`을 지정하면 `/claude-docs` 대신 다른 이름을 쓸 수 있습니다 (영문자, 숫자, 하이픈, 밑줄):

```bash
curl -fsSL https://raw.githubusercontent.com/posimind/claude-code-docs/main/install.sh -o /tmp/install.sh
CLAUDE_DOCS_COMMAND_NAME=cdocs bash /tmp/install.sh   # → /cdocs hooks
```

선택한 이름은 `~/.claude-code-docs/.command_name`에 기록되어, 제거 시 환경 변수를 다시 지정하지 않아도 올바른 명령 파일이 삭제됩니다. 이름을 바꿔도 훅에는 영향이 없습니다 — 훅은 명령어 이름이 아니라 헬퍼 스크립트 경로에 묶여 있습니다.

## 사용 방법

### 그냥 물어보기 — 명령어 불필요

Claude Code에 대해 자연어로 물어보면 훅이 조회를 미러로 유도합니다:

```
PreToolUse 훅은 어떻게 설정하나요?
훅과 MCP의 차이가 뭔가요?
```

`claude-code-guide` 서브에이전트는 미러 위치를 아는 상태로 시작하고, 서브에이전트든 메인 대화든 `code.claude.com`을 가져오려 하면 그 요청이 로컬 읽기로 바뀝니다. 한 가지 유의점: Claude가 아무것도 조회하지 않고 기억으로 답하면 훅은 발동하지 않습니다. 조회를 강제하려면 명령어를 쓰세요.

### `/claude-docs` 명령

```bash
/claude-docs               # 전체 문서 주제 목록
/claude-docs hooks         # 특정 페이지 전문 읽기
/claude-docs -t            # 지금 GitHub과 동기화하고 상태 표시
/claude-docs -t hooks      # 동기화 강제 후 페이지 읽기
/claude-docs what's new    # 최근 문서 변경 사항
/claude-docs changelog     # Claude Code 공식 릴리스 노트
/claude-docs uninstall     # 제거 방법 안내
```

페이지를 읽으면 `✅ You have the latest docs (v0.4.1, main)` 같은 최신 상태 표시가 먼저 출력됩니다. `what's new`는 최근 문서 커밋의 링크와 변경된 페이지 목록을 보여줍니다. `changelog`는 동기화 워크플로가 Claude Code 저장소에서 미러링해 둔 공식 `CHANGELOG.md`를 읽습니다 — 다른 모든 페이지처럼 오프라인에서도 동작합니다.

명령어는 자연어도 받습니다. 조회 여부를 Claude의 판단에 맡기지 않고 강제하고 싶을 때 유용합니다:

```bash
/claude-docs 어떤 환경 변수가 있고 어떻게 쓰나요?
/claude-docs 인증을 언급한 부분을 모두 찾아줘
```

| 하고 싶은 것 | 방법 |
| :----------- | :--- |
| Claude Code 관련 질문에 답을 얻기 | 그냥 물어보기 — 훅이 미러로 유도합니다 |
| 특정 페이지 전문 보기 | `/claude-docs hooks` |
| 문서를 확실히 참조하게 하기 | `/claude-docs <주제 또는 질문>` |
| 미러가 얼마나 최신인지 확인 | `/claude-docs -t` |
| 최근 문서 변경 사항 | `/claude-docs what's new` |
| 릴리스 노트 | `/claude-docs changelog` |

## 동작 방식 — 서로 다른 두 층

파이프라인은 성격이 전혀 다른 두 층으로 이루어져 있습니다: 클라우드에서 **일정에 따라 도는 발행자**와, Claude를 실제로 사용할 때만 사용자의 머신에서 움직이는 **이벤트 반응형 소비자**입니다.

```
code.claude.com                          (공식 문서)
      │
      │  ① GitHub Actions — 3시간마다, GitHub 인프라에서
      ▼
github.com/posimind/claude-code-docs     (원격 미러)
      │
      │  ② git pull — Claude가 읽을 때, 3시간에 최대 1회
      ▼
~/.claude-code-docs                      (로컬 미러)
      │
      │  ③ 훅 — 질문할 때마다, 즉시, 네트워크 불필요
      ▼
Claude
```

### ① 원격 미러 — 일정에 따라 도는 발행자

이 저장소의 GitHub Actions 워크플로가 3시간 고정 cron으로 `code.claude.com`의 모든 페이지를 가져와 변경분을 커밋합니다. GitHub 인프라에서 실행됩니다:

- 누가 Claude Code를 쓰든 말든 일어납니다 — 사용자의 머신은 전혀 관여하지 않습니다
- 시스템 전체에서 `code.claude.com`에 접속하는 **유일한** 지점입니다
- 이 3시간 주기가 하류 전체의 "최신"을 정의합니다

### ②③ 로컬 설치본 — 이벤트에 반응하는 소비자

`~/.claude-code-docs`의 설치본은 공식 사이트에 접속하지 않습니다. 하는 일은 두 가지이며, 둘 다 일정이 아니라 사용에 의해서만 촉발됩니다 — Claude를 쓰지 않는 동안 머신에서는 아무것도 돌지 않습니다.

**③ Claude를 로컬 파일로 연결** — 질문할 때마다, 즉시, 네트워크 없이:

- Claude Code 질문이 `claude-code-guide`에 위임되면 그 에이전트는 미러 위치가 이미 주입된 채 시작합니다
- `code.claude.com` 가져오기는 거부되고 미러된 파일이 대신 안내됩니다
- 마지막 동기화가 1분 전이든 네트워크가 일주일째 끊겨 있든 똑같이 동작합니다 (자세한 구조는 [오프라인 및 제한된 네트워크](#오프라인-및-제한된-네트워크) 참고)

**② 스스로 최신 유지** — 반응형으로, 스로틀 하에:

- Claude가 미러를 읽거나 `/claude-docs`를 실행하면 헬퍼가 GitHub 미러에서 새 커밋을 pull하되, 3시간에 최대 1회만 — ①이 그보다 자주 발행하지 않으므로 더 자주 확인해도 새 내용이 있을 수 없습니다
- 모든 네트워크 호출에 시간 상한(fetch 15초, pull 30초)이 있고 실패는 조용합니다: 오프라인이면 캐시된 사본을 그대로 읽습니다
- `/claude-docs -t`는 스로틀을 우회해 지금 즉시 동기화합니다

### 한눈에 비교

| | ① 원격 미러 동기화 | ②③ 로컬 설치본 |
| :- | :---------------- | :------------- |
| 실행 위치 | GitHub 인프라 | 사용자의 머신 |
| 트리거 | 3시간 cron 일정 | Claude의 읽기 / 가져오기 / 질문 |
| 접속 대상 | `code.claude.com` | `github.com`만 |
| 유휴 상태일 때 | 3시간마다 계속 발행 | 아무것도 하지 않음 |
| 실패하면 | 다음 주기에 재시도 | 캐시된 문서를 계속 제공, 읽기는 절대 차단되지 않음 |

## 오프라인 및 제한된 네트워크

### 가져오기 리다이렉트

`WebFetch` 훅이 `code.claude.com` URL을 `docs_manifest.json`으로 조회한 뒤, Claude가 보게 될 사유에 로컬 경로를 담아 가져오기를 거부합니다:

```
WebFetch https://code.claude.com/docs/en/agent-sdk/python
  -> denied: "This page is mirrored locally and code.claude.com is not
              reachable from this network. Read
              ~/.claude-code-docs/docs/agent-sdk__python.md instead."
```

중첩된 경로는 밑줄 두 개로 평탄화되며(`/docs/en/agent-sdk/python` → `agent-sdk__python.md`), 앵커·쿼리 문자열·끝의 `.md`는 조회 전에 제거됩니다. 다른 호스트의 URL은 그대로 통과합니다. 미러에 없는 페이지도 가져오기는 거부하되, 특정 파일 대신 미러 전체에 대한 `ls`와 `grep`을 안내합니다.

### `claude-code-guide` 서브에이전트 유도

`SubagentStart` 훅이 에이전트의 첫 동작 전에 컨텍스트를 주입합니다: 미러의 위치와 문서 개수, 네트워크가 차단되어 있으니 로컬 파일로 답하라는 지시, 페이지 찾는 방법(`Read <주제>.md` 또는 `grep -ril '<키워드>'`), 밑줄 두 개 평탄화 규칙, 그리고 `docs_manifest.json`이 모든 파일을 공식 URL로 되짚어 주므로 그 URL은 인용하되 가져오지는 말라는 안내입니다.

다른 에이전트까지 적용하려면 `~/.claude/settings.json`의 `SubagentStart` matcher를 확장하세요 — 정규식이므로 `claude-code-guide|my-docs-agent` 형태로 쓸 수 있습니다.

### 동작 확인

```bash
# 로컬 파일을 지목하는 deny 결정이 출력되어야 합니다
echo '{"tool_input":{"url":"https://code.claude.com/docs/en/hooks"}}' \
  | ~/.claude-code-docs/claude-docs-helper.sh webfetch-guard

# 서브에이전트에 주입되는 컨텍스트가 출력되어야 합니다
echo '{"agent_type":"claude-code-guide"}' \
  | ~/.claude-code-docs/claude-docs-helper.sh subagent-context
```

## 문제 해결

**`/claude-docs`를 찾을 수 없음** — `ls ~/.claude/commands/claude-docs.md`로 확인하고, Claude Code를 재시작하거나 설치 스크립트를 다시 실행하세요.

**Claude가 여전히 공식 문서를 가져오려 함** — Claude Code를 재시작한 뒤(훅은 세션 시작 시 로드), 훅 등록을 확인하세요:

```bash
jq '.hooks | to_entries[] | .key as $e | .value[]
    | select((.hooks[0].command // "") | contains("claude-code-docs"))
    | "\($e) [\(.matcher)]"' ~/.claude/settings.json
```

`PreToolUse [Read]`, `PreToolUse [WebFetch]`, `SubagentStart [claude-code-guide]`가 보여야 합니다. Claude가 아무것도 조회하지 않고 답했다면 훅이 발동하지 않는 것이 설계상 정상입니다 — `/claude-docs`로 다시 물어 조회를 강제하세요.

**문서가 갱신되지 않음** — `/claude-docs -t`로 동기화를 강제하거나, `cd ~/.claude-code-docs && git pull`을 실행하고, [GitHub Actions](https://github.com/posimind/claude-code-docs/actions)가 돌고 있는지 확인하세요.

## 제거

```bash
~/.claude-code-docs/uninstall.sh    # 또는 /claude-docs uninstall 로 안내 보기
```

명령어, 훅, 설치 디렉터리를 제거합니다. 수동 제거는 [UNINSTALL.md](UNINSTALL.md)를 참고하세요.

## 보안 참고 사항

- 설치 스크립트는 `~/.claude/settings.json`에 위의 훅 3개를 추가하며, 모두 `~/.claude-code-docs`의 동일한 헬퍼 스크립트를 실행합니다
- 이전 설치의 훅은 설치·제거 시 모두 삭제됩니다. 명령에 `claude-code-docs`가 포함되어 있는지로 판별하므로, 직접 추가한 훅은 그대로 남습니다
- 모든 작업은 문서 디렉터리로 한정되며, 외부로 데이터를 전송하지 않습니다
- **저장소 신뢰**: 설치 스크립트는 HTTPS로 GitHub에서 클론합니다. 더 통제하려면 저장소를 fork해 자신의 fork에서 설치하거나, 직접 클론해 코드를 검토한 뒤 실행하세요

## 변경 이력

### v0.4.1 (최신)

- 자동 업데이트 훅이 실제로 동작합니다: v0.3부터 no-op이어서, 슬래시 명령을 우연히 실행하기 전까지 설치본이 낡은 채 방치됐습니다
- 업데이트는 미러 자체의 갱신 주기인 3시간에 1회로 스로틀되며, `/claude-docs -t`로는 여전히 즉시 동기화할 수 있습니다
- 네트워크 git 호출에 시간 상한(fetch 15초, pull 30초)을 두어, 차단된 네트워크가 Claude의 읽기를 지연시킬 수 없습니다
- 설치 스크립트는 업데이트가 실제로 그것을 변경했을 때만 재실행되며, 훅 내부에서는 절대 실행되지 않습니다
- 오프라인 수정: GitHub에 접근할 수 없어도 `-t`와 주제 목록이 출력 전에 죽지 않습니다
- README를 실제 동작에 맞게 재작성 (존재하지 않는 출력 메시지, "diff와 함께" 서술, `changelog`에 대한 잘못된 설명 제거)

### v0.3.3 (upstream)

- Claude Code 체인지로그 통합 (`/claude-docs changelog`), macOS 셸 호환성 수정, 플랫폼 뱃지

## 기여와 알려진 문제

기여를 환영합니다 — Windows 지원, 버그 리포트, 기능 제안, 문서: [이슈](https://github.com/posimind/claude-code-docs/issues) 또는 PR을 보내주세요. 알려진 문제: 특이한 네트워크 구성에서 자동 업데이트가 실패할 수 있고, 일부 문서 링크가 연결되지 않을 수 있습니다.

## 라이선스

문서 내용의 저작권은 Anthropic에 있습니다. 미러 도구는 오픈 소스이며, 기여를 환영합니다.

## Fork 안내

이 저장소는 원본 Claude Code 문서 미러인 **[ericbuess/claude-code-docs](https://github.com/ericbuess/claude-code-docs)** 에서 fork되었습니다. 미러 자체와 동기화 워크플로, `/docs` 헬퍼에 대한 공은 모두 원본 프로젝트와 그 기여자들에게 있습니다. 미러 자체에 관한 것은 계속 upstream이 담당하며, 이 fork에 한정된 문제는 [여기](https://github.com/posimind/claude-code-docs/issues)에 등록해 주세요.

fork 이후 달라진 점 전체:

- **오프라인 훅** — 위에서 설명한 `WebFetch` 리다이렉트와 `claude-code-guide` 컨텍스트 주입. 이 프로젝트를 규정하는 핵심 기능입니다
- **동작하는 자동 업데이트** (v0.4.1) — `Read` 훅이 이제 실제로 미러를 동기화합니다. 3시간 스로틀, 시간 상한이 걸린 네트워크 호출, 조건부이며 훅에서 안전한 설치 스크립트 재실행을 포함합니다
- **이 fork를 바라보도록 변경** — 설치·제거 스크립트, 헬퍼 스크립트, 문서가 `posimind/claude-code-docs`에서 클론하고 pull하므로, 설치된 사본은 upstream이 아니라 이 저장소를 추적합니다
- **문서 URL 갱신** — Anthropic이 `docs.anthropic.com/en/docs/claude-code`에서 `code.claude.com/docs/en`으로 옮긴 것을 반영했습니다. 옛 base URL에 새 형식의 경로를 붙이던 `fetch_claude_docs.py`의 sitemap 실패 폴백 수정을 포함합니다
- **슬래시 명령 이름 변경** — 다른 도구와 충돌하지 않도록 `/docs`를 `/claude-docs`로 바꾸었고, `CLAUDE_DOCS_COMMAND_NAME`으로 설정할 수 있습니다
- **설치·제거 스크립트 버그 수정** — 제거 스크립트가 `~/.claude-code-docs`를 지우지 못하던 문제(점으로 시작하는 디렉터리를 패턴이 놓침), 설치 스크립트가 자신이 실행된 디렉터리를 지우던 문제를 고쳤고, 템플릿을 `mv`로 렌더링해 실행 중인 헬퍼 스크립트를 다시 렌더링해도 안전합니다
- **동기화 워크플로 수정** — 변경이 없을 때 빈 커밋을 만들지 않습니다
- **한국어 README** — 이 문서입니다
