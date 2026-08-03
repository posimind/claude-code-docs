# Claude Code 문서 미러

[English](README.md) | **한국어**

[![Last Update](https://img.shields.io/github/last-commit/posimind/claude-code-docs/main.svg?label=docs%20updated)](https://github.com/posimind/claude-code-docs/commits/main)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)]()
[![Beta](https://img.shields.io/badge/status-early%20beta-orange)](https://github.com/posimind/claude-code-docs/issues)

https://code.claude.com/docs/en/ 의 Claude Code 문서를 로컬에 미러링하며, 3시간마다 갱신됩니다.

## Anthropic 문서가 차단된 네트워크를 위해

**이 fork는 `code.claude.com`을 비롯한 Anthropic 문서 호스트에 접근할 수 없는 환경에서 Claude Code를 쓸 수 있도록 만들어졌습니다** — 사내 프록시, 망분리 네트워크, 아웃바운드가 필터링된 CI 환경 등입니다.

이런 환경에서 Claude Code에 대해 질문하면 특정한 방식으로 실패합니다. Claude가 그런 질문을 위임하는 내장 `claude-code-guide` 서브에이전트가 공식 문서를 `WebFetch`로 가져오려다 네트워크 오류를 받고, 기억에 의존해 답하거나 아예 답하지 못합니다. 문서를 로컬에 복사해 두는 것만으로는 해결되지 않습니다. 그 복사본이 있다는 사실을 에이전트에게 알려주는 장치가 없기 때문입니다.

그래서 이 fork는 문서를 미러링하는 데 그치지 않고 **Claude가 그 미러를 쓰도록 연결합니다**:

- **가져오기를 리다이렉트합니다.** `WebFetch`에 걸린 `PreToolUse` 훅이 모든 `code.claude.com` URL을 가로채 미러된 파일로 변환하고, 그 파일 경로를 알려주면서 가져오기를 거부합니다. 덕분에 Claude는 실패하는 대신 해당 파일을 읽습니다.
- **서브에이전트에게 미러의 존재를 알립니다.** `SubagentStart` 훅이 `claude-code-guide`가 실행되기 전에 미러 위치, 문서 개수, 파일 명명 규칙을 컨텍스트에 주입합니다. 그 결과 에이전트는 처음부터 로컬 경로를 검색하며 네트워크에 손을 대지 않습니다.

두 훅 모두 자동으로 설치됩니다. 자세한 내용은 [오프라인 및 제한된 네트워크](#오프라인-및-제한된-네트워크)를, 설정 파일에 정확히 무엇이 기록되는지는 [보안 참고 사항](#보안-참고-사항)을 확인하세요.

## ⚠️ 초기 베타 안내

**초기 베타 릴리스입니다**. 오류나 예상치 못한 동작이 있을 수 있습니다. 문제를 발견하면 [이슈를 등록](https://github.com/posimind/claude-code-docs/issues)해 주세요. 여러분의 피드백이 이 도구를 개선합니다.

## 🆕 버전 0.3.3 — 체인지로그 통합

**이번 버전의 새로운 기능:**
- 📋 **Claude Code 체인지로그**: `/claude-docs changelog`로 공식 릴리스 노트 확인
- 🍎 **macOS 완전 호환**: Mac 사용자를 위한 셸 호환성 문제 수정
- 🐧 **Linux 지원**: Ubuntu, Debian 등에서 테스트 완료
- 🔧 **설치 스크립트 개선**: 업데이트와 예외 상황 처리 개선

업데이트하려면:
```bash
curl -fsSL https://raw.githubusercontent.com/posimind/claude-code-docs/main/install.sh | bash
```

## 왜 필요한가

- **Anthropic에 접근하지 않아도 동작** — `code.claude.com`이 차단되어도 문서를 계속 볼 수 있고, Claude가 자동으로 그쪽을 보게 됩니다
- **빠른 접근** — 웹에서 가져오는 대신 로컬 파일을 읽습니다
- **자동 업데이트** — 최신 문서를 따라가려 시도합니다
- **변경 추적** — 시간에 따라 문서가 어떻게 바뀌었는지 확인할 수 있습니다
- **Claude Code 체인지로그** — 공식 릴리스 노트와 버전 이력에 빠르게 접근
- **더 나은 Claude Code 통합** — Claude가 문서를 더 효과적으로 탐색할 수 있습니다

## 플랫폼 호환성

- ✅ **macOS**: 완전 지원 (macOS 12+ 에서 테스트)
- ✅ **Linux**: 완전 지원 (Ubuntu, Debian, Fedora 등)
- ⏳ **Windows**: 아직 미지원 — [기여를 환영합니다](#기여하기)!

### 사전 요구 사항

다음이 설치되어 있어야 합니다:
- **git** — 저장소 클론 및 업데이트용 (대개 기본 설치되어 있음)
- **jq** — 자동 업데이트 훅의 JSON 처리용 (macOS는 기본 설치, Linux는 `apt install jq` 또는 `yum install jq` 필요할 수 있음)
- **curl** — 설치 스크립트 다운로드용 (대개 기본 설치되어 있음)
- **Claude Code** — 당연히 :)

## 설치

다음 한 줄이면 됩니다:

```bash
curl -fsSL https://raw.githubusercontent.com/posimind/claude-code-docs/main/install.sh | bash
```

수행되는 작업:
1. `~/.claude-code-docs`에 설치 (기존 설치가 있으면 이전)
2. `/claude-docs` 슬래시 명령 생성 — 인자를 도구에 전달하고 문서 위치를 알려줍니다 (이름 변경은 `CLAUDE_DOCS_COMMAND_NAME` 사용, [명령어 이름 변경](#명령어-이름-변경) 참고)
3. `~/.claude/settings.json`에 훅 3개 등록 — 모두 동일한 헬퍼 스크립트를 호출합니다:
   - `Read`에 걸린 `PreToolUse` — Claude가 `~/.claude-code-docs`에서 읽을 때 최신 문서를 pull (최대 3시간에 1회)
   - `WebFetch`에 걸린 `PreToolUse` — `code.claude.com` 가져오기를 미러된 파일로 리다이렉트
   - `claude-code-guide`에 걸린 `SubagentStart` — 해당 서브에이전트에게 미러 위치를 알림

   직접 추가한 훅은 건드리지 않습니다. [오프라인 및 제한된 네트워크](#오프라인-및-제한된-네트워크)를 참고하세요.

**참고**: 훅은 세션이 시작될 때 로드되므로, 설치 후 Claude Code를 재시작해야 합니다.

**참고**: 명령어는 `/claude-docs (user)`로 표시됩니다. 뒤의 "(user)"는 사용자가 만든 명령임을 뜻합니다.

## 사용 방법

문서에 접근하는 방법은 두 가지이며, 훅이 추가된 이후로는 첫 번째 방법으로 대부분 해결됩니다.

### 그냥 물어보기 — 명령어 불필요

훅은 평범한 질문에도 동작합니다. Claude Code에 대해 자연어로 물어보면 미러가 자동으로 사용됩니다:

```
PreToolUse 훅은 어떻게 설정하나요?
훅과 MCP의 차이가 뭔가요?
서브에이전트를 백그라운드로 실행할 수 있나요?
```

Claude가 질문을 `claude-code-guide` 서브에이전트에 넘기면, 그 에이전트는 미러 위치를 아는 상태로 시작해 로컬 파일을 읽습니다. 서브에이전트든 메인 대화든 `code.claude.com`을 가져오려 하면 그 요청이 로컬 읽기로 바뀝니다. 명령어를 외울 필요가 없고, 차단된 네트워크에서도 동작합니다.

한 가지 유의점: Claude가 이미 답을 안다고 판단해 아무것도 조회하지 않으면 훅은 발동하지 않습니다. 가져올 것도, 유도할 서브에이전트도 없기 때문입니다. 문서를 반드시 참조하게 하려면 아래 명령어를 쓰세요.

### `/claude-docs` — 특정 페이지 직접 읽기

특정 페이지를 원문 그대로 보거나, 미러가 얼마나 최신인지 확인하거나, 무엇이 바뀌었는지 볼 때는 여전히 명령어가 적합합니다:

```bash
/claude-docs hooks        # hooks 문서를 즉시 읽기
/claude-docs mcp          # MCP 문서를 즉시 읽기
/claude-docs memory       # memory 문서를 즉시 읽기
```

다음과 같이 표시됩니다: `📚 Reading from local docs (run /claude-docs -t to check freshness)`

### -t 플래그로 동기화 상태 확인
```bash
/claude-docs -t           # GitHub과의 동기화 상태 표시
/claude-docs -t hooks     # 동기화 상태 확인 후 hooks 문서 읽기
/claude-docs -t mcp       # 동기화 상태 확인 후 MCP 문서 읽기
```

### 새로운 변경 사항 보기
```bash
/claude-docs what's new   # 최근 문서 변경 사항을 diff와 함께 표시
```

### Claude Code 체인지로그 읽기
```bash
/claude-docs changelog    # 공식 릴리스 노트와 버전 이력 읽기
```

체인지로그 기능은 공식 Claude Code 저장소에서 최신 릴리스 노트를 직접 가져와 각 버전의 변경 사항을 보여줍니다.

### 제거
```bash
/claude-docs uninstall    # claude-code-docs를 완전히 제거하는 명령 안내
```

### 어느 쪽을 쓸 것인가

| 하고 싶은 것 | 방법 |
| :----------- | :--- |
| Claude Code 관련 질문에 답을 얻기 | 그냥 물어보기 — 훅이 미러로 유도합니다 |
| 특정 페이지 전문 보기 | `/claude-docs hooks` |
| 문서를 확실히 참조하게 하기 | `/claude-docs <주제>` 또는 `/claude-docs <질문>` |
| 미러가 얼마나 최신인지 확인 | `/claude-docs -t` |
| 최근 문서 변경 사항 | `/claude-docs what's new` |
| 릴리스 노트 | `/claude-docs changelog` |

명령어는 자연어도 받습니다. 조회 여부를 Claude의 판단에 맡기지 않고 강제하고 싶을 때 유용합니다:

```bash
/claude-docs 어떤 환경 변수가 있고 어떻게 쓰나요?
/claude-docs 훅과 MCP의 차이를 설명해줘
/claude-docs 인증을 언급한 부분을 모두 찾아줘
```

### 명령어 이름 변경

기본 명령어는 `/claude-docs`입니다. 다른 이름을 쓰려면 설치 시 `CLAUDE_DOCS_COMMAND_NAME`을 지정하세요:

```bash
curl -fsSL https://raw.githubusercontent.com/posimind/claude-code-docs/main/install.sh -o /tmp/install.sh
CLAUDE_DOCS_COMMAND_NAME=cdocs bash /tmp/install.sh

# 이제 /cdocs 사용
/cdocs hooks
/cdocs mcp
```

영문자, 숫자, 하이픈, 밑줄로 이루어진 이름이면 무엇이든 됩니다: `cdocs`, `claude-code-docs` 등. 이 이름은 명령 파일(`~/.claude/commands/<이름>.md`)과 헬퍼 스크립트가 출력하는 도움말에 사용됩니다.

설치 스크립트는 선택한 이름을 `~/.claude-code-docs/.command_name`에 기록합니다. 따라서 제거할 때 환경 변수를 다시 지정하지 않아도 올바른 명령 파일이 삭제됩니다.

명령어 이름을 바꿔도 훅에는 영향이 없습니다. 훅은 명령어 이름이 아니라 헬퍼 스크립트 경로에 묶여 있기 때문입니다.

## 업데이트 동작 방식

문서는 다음과 같이 최신 상태를 유지하려 합니다:
- GitHub Actions가 주기적으로 실행되어 새 문서를 가져옵니다
- 미러를 읽을 때(훅 또는 `/claude-docs`) GitHub에 업데이트를 확인하되, 최대 3시간에 1회만 확인합니다 — 미러 자체가 3시간 간격으로 갱신되므로 더 자주 확인해도 새 내용이 있을 수 없습니다
- 업데이트가 있으면 pull합니다
- 이때 "🔄 Updating documentation..." 메시지가 보일 수 있습니다
- `/claude-docs -t`는 항상 GitHub에 접속하므로, 즉시 동기화를 강제할 때 사용하세요

참고: 자동 업데이트가 실패하면 설치 스크립트를 다시 실행해 최신 버전을 받을 수 있습니다.

## 오프라인 및 제한된 네트워크

공식 문서에 접근할 수 없을 때 Claude를 미러에 붙들어 두는 훅이 두 개 있습니다. 둘 다 설치된 헬퍼 스크립트를 실행하며, 설치 스크립트가 등록합니다.

### 가져오기 리다이렉트

`WebFetch`에 걸린 `PreToolUse` 훅이 `code.claude.com` URL을 가로채 `docs_manifest.json`으로 조회한 뒤, Claude가 보게 될 사유에 로컬 경로를 담아 가져오기를 거부합니다:

```
WebFetch https://code.claude.com/docs/en/agent-sdk/python
  -> denied: "This page is mirrored locally and code.claude.com is not
              reachable from this network. Read
              ~/.claude-code-docs/docs/agent-sdk__python.md instead."
```

중첩된 경로는 밑줄 두 개로 평탄화되며(`/docs/en/agent-sdk/python` → `agent-sdk__python.md`), 앵커·쿼리 문자열·끝의 `.md`는 조회 전에 모두 제거됩니다. 다른 호스트의 URL은 그대로 통과합니다. 미러에 없는 페이지라면 훅은 여전히 가져오기를 거부하되, 특정 파일 대신 미러 전체에 대한 `ls`와 `grep`을 안내합니다.

### `claude-code-guide` 서브에이전트 유도

`claude-code-guide`는 Claude가 Claude Code 관련 질문을 위임하는 내장 서브에이전트입니다. 그대로 두면 `WebFetch`부터 시도하고, 제한된 네트워크에서는 실패합니다.

이 에이전트에 매칭된 `SubagentStart` 훅이 에이전트가 첫 동작을 하기 전에 미러 정보를 컨텍스트에 주입합니다. 주입되는 내용은 다음과 같습니다:

- 미러의 위치와 문서 개수
- `code.claude.com`에 접근할 수 없으므로 로컬 파일로 답하라는 지시
- 페이지를 찾는 방법 — `Read <주제>.md`, 또는 미러 전체에 대한 `grep -ril '<키워드>'`
- 중첩 페이지는 경로가 밑줄 두 개로 평탄화된다는 규칙
- `docs_manifest.json`이 모든 파일을 원본 URL로 되짚어 주며, 그 URL은 인용하되 가져오지는 말라는 안내

그 결과 에이전트는 네트워크가 막혔음을 뒤늦게 발견하고 우회하는 대신, 처음부터 로컬 경로를 검색합니다.

다른 에이전트까지 적용하려면 `~/.claude/settings.json`의 `SubagentStart` matcher에 이름을 추가하세요. matcher는 정규식이므로 `claude-code-guide|my-docs-agent` 형태로 쓸 수 있습니다.

### 동작 확인

훅은 세션이 시작될 때 로드되므로 설치 후 Claude Code를 재시작하세요. 재시작 없이 훅을 직접 실행해 볼 수도 있습니다:

```bash
# 로컬 파일을 지목하는 deny 결정이 출력되어야 합니다
echo '{"tool_input":{"url":"https://code.claude.com/docs/en/hooks"}}' \
  | ~/.claude-code-docs/claude-docs-helper.sh webfetch-guard

# 서브에이전트에 주입되는 컨텍스트가 출력되어야 합니다
echo '{"agent_type":"claude-code-guide"}' \
  | ~/.claude-code-docs/claude-docs-helper.sh subagent-context
```

네트워크가 정상인 환경에서도 두 훅은 유지할 가치가 있습니다. 로컬 읽기가 네트워크 가져오기보다 빠르기 때문입니다.

## 이전 버전에서 업데이트

어떤 버전을 쓰고 있든 다음을 실행하면 됩니다:

```bash
curl -fsSL https://raw.githubusercontent.com/posimind/claude-code-docs/main/install.sh | bash
```

설치 스크립트가 이전과 업데이트를 자동으로 처리합니다.

## 문제 해결

### 명령어를 찾을 수 없음
`/claude-docs`가 "command not found"를 반환한다면:
1. 명령 파일이 있는지 확인: `ls ~/.claude/commands/claude-docs.md`
2. Claude Code를 재시작해 명령을 다시 로드
3. 설치 스크립트를 다시 실행

### Claude가 여전히 공식 문서를 가져오려 함
Claude Code 관련 질문에서 여전히 `WebFetch`가 실패한다면:
1. Claude Code를 재시작 — 훅은 세션 시작 시 로드됩니다
2. 훅이 등록되었는지 확인:
   ```bash
   jq '.hooks | to_entries[] | .key as $e | .value[]
       | select((.hooks[0].command // "") | contains("claude-code-docs"))
       | "\($e) [\(.matcher)]"' ~/.claude/settings.json
   ```
   `PreToolUse [Read]`, `PreToolUse [WebFetch]`, `SubagentStart [claude-code-guide]`가 보여야 합니다
3. 훅을 직접 실행해 헬퍼가 동작하는지 확인 — [동작 확인](#동작-확인) 참고
4. Claude가 아무것도 조회하지 않고 답했다면, 훅이 발동하지 않는 것이 설계상 정상입니다. `/claude-docs`로 다시 물어 조회를 강제하세요

### 문서가 갱신되지 않음
문서가 오래되어 보인다면:
1. `/claude-docs -t`로 동기화 상태를 확인하고 업데이트를 강제
2. 수동 업데이트: `cd ~/.claude-code-docs && git pull`
3. GitHub Actions가 실행 중인지 확인: [Actions 보기](https://github.com/posimind/claude-code-docs/actions)

### 설치 오류
- **"git/jq/curl not found"**: 누락된 도구를 먼저 설치하세요
- **"Failed to clone repository"**: 인터넷 연결을 확인하세요
- **"Failed to update settings.json"**: `~/.claude/settings.json`의 파일 권한을 확인하세요

## 제거

문서 통합을 완전히 제거하려면:

```bash
/claude-docs uninstall
```

또는 다음을 실행하세요:
```bash
~/.claude-code-docs/uninstall.sh
```

수동 제거 방법은 [UNINSTALL.md](UNINSTALL.md)를 참고하세요.

## 보안 참고 사항

- 설치 스크립트는 `~/.claude/settings.json`을 수정해 훅 3개를 추가합니다. 모두 `~/.claude-code-docs`의 동일한 헬퍼 스크립트를 실행합니다:
  - `Read`에 걸린 `PreToolUse` — 문서 파일을 읽을 때 `git pull` 실행 (최대 3시간에 1회)
  - `WebFetch`에 걸린 `PreToolUse` — `code.claude.com` 가져오기를 거부하고 로컬 파일을 대신 알려줌. 다른 호스트는 무시
  - `claude-code-guide`에 걸린 `SubagentStart` — 해당 서브에이전트의 컨텍스트에 미러 위치를 주입
- 이전 설치의 훅은 설치 시와 제거 시에 모두 삭제됩니다. 명령에 `claude-code-docs`가 포함되어 있는지로 판별하므로, 직접 추가한 훅은 그대로 남습니다
- 모든 작업은 문서 디렉터리로 한정됩니다
- 외부로 데이터를 전송하지 않습니다 — 전부 로컬에서 처리됩니다
- **저장소 신뢰**: 설치 스크립트는 HTTPS로 GitHub에서 클론합니다. 보안을 더 강화하려면:
  - 저장소를 fork해서 자신의 fork에서 설치
  - 직접 클론한 뒤 로컬 디렉터리에서 설치 스크립트 실행
  - 설치 전에 모든 코드를 검토

## 변경 이력

### v0.3.3 (최신)
- Claude Code 체인지로그 통합 추가 (`/claude-docs changelog`)
- macOS 사용자를 위한 셸 호환성 수정 (zsh/bash)
- 문서와 오류 메시지 개선
- 플랫폼 호환성 뱃지 추가

### v0.3.2
- 자동 업데이트 기능 수정
- 로컬 저장소 변경 처리 개선
- 업데이트 중 오류 복구 개선

## 기여하기

**기여를 환영합니다!** 커뮤니티 프로젝트이며 여러분의 도움이 필요합니다:

- 🪟 **Windows 지원**: Windows 호환성 추가를 돕고 싶으신가요? [저장소를 fork](https://github.com/posimind/claude-code-docs/fork)하고 PR을 보내주세요!
- 🐛 **버그 리포트**: 동작하지 않는 부분을 발견했나요? [이슈를 등록](https://github.com/posimind/claude-code-docs/issues)해 주세요
- 💡 **기능 제안**: 아이디어가 있나요? [논의를 시작](https://github.com/posimind/claude-code-docs/issues)해 주세요
- 📝 **문서**: 문서 개선이나 예제 추가를 도와주세요

Claude Code 자체를 활용해 기능을 만들 수도 있습니다. 저장소를 fork하고 Claude에게 도움을 받아보세요!

## 알려진 문제

초기 베타이므로 다음과 같은 문제를 겪을 수 있습니다:
- 일부 네트워크 구성에서 자동 업데이트가 실패할 수 있습니다
- 일부 문서 링크가 올바르게 연결되지 않을 수 있습니다

여기에 없는 문제를 발견하면 [알려주세요](https://github.com/posimind/claude-code-docs/issues)!

## 라이선스

문서 내용의 저작권은 Anthropic에 있습니다.
이 미러 도구는 오픈 소스이며, 기여를 환영합니다!

## Fork 안내

이 저장소는 원본 Claude Code 문서 미러인 **[ericbuess/claude-code-docs](https://github.com/ericbuess/claude-code-docs)** 에서 fork되었습니다. 미러 자체와 동기화 워크플로, `/docs` 헬퍼에 대한 공은 모두 원본 프로젝트와 그 기여자들에게 있습니다.

이 fork는 Anthropic 문서 호스트가 차단된 네트워크를 위해 만들어졌습니다. 달라진 점은 다음과 같습니다:

- **오프라인 훅** — `code.claude.com` 가져오기를 미러된 파일로 리다이렉트하는 `WebFetch`용 `PreToolUse` 훅, 그리고 `claude-code-guide` 서브에이전트가 네트워크 대신 미러를 검색하도록 알려주는 `SubagentStart` 훅. 이 fork가 존재하는 이유입니다.
- **이 fork를 바라보도록 변경** — 설치·제거 스크립트, 헬퍼 스크립트, 문서가 이제 `posimind/claude-code-docs`에서 클론하고 pull합니다. 설치된 사본은 upstream이 아니라 이 저장소를 추적합니다.
- **문서 URL 갱신** — Anthropic이 `docs.anthropic.com/en/docs/claude-code`에서 `code.claude.com/docs/en`으로 옮긴 것을 반영했습니다. 여기에는 `fetch_claude_docs.py`의 sitemap 실패 시 폴백 경로도 포함됩니다. 이 폴백은 옛 base URL에 새 형식의 페이지 경로를 붙이고 있었습니다.
- **슬래시 명령 이름 변경** — 다른 도구와 충돌하지 않도록 `/docs`를 `/claude-docs`로 바꾸었고, 이제 `CLAUDE_DOCS_COMMAND_NAME`으로 이름을 설정할 수 있습니다.
- **설치·제거 스크립트 버그 수정** — 제거 스크립트는 `~/.claude-code-docs`를 지울 수 없었습니다. 경로 패턴이 점으로 시작하는 디렉터리명에 매칭되지 않았기 때문입니다. 또한 설치 스크립트는 자신이 실행된 디렉터리를 구버전 설치로 간주해 삭제했고, 저장소를 클론한 디렉터리 안에서 설치 스크립트를 실행하면 그 클론이 사라졌습니다.

미러 자체에 관한 것은 계속 upstream이 담당합니다. 오프라인 훅이나 이 fork의 패키징에 한정된 문제는 [여기](https://github.com/posimind/claude-code-docs/issues)에 등록해 주세요.
