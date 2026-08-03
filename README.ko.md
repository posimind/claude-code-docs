# Claude Code 문서 미러

[English](README.md) | **한국어**

[![Last Update](https://img.shields.io/github/last-commit/posimind/claude-code-docs/main.svg?label=docs%20updated)](https://github.com/posimind/claude-code-docs/commits/main)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)]()
[![Beta](https://img.shields.io/badge/status-early%20beta-orange)](https://github.com/posimind/claude-code-docs/issues)

https://code.claude.com/docs/en/ 의 Claude Code 문서를 3시간 간격으로 로컬에 미러링하고, Claude가 그 미러를 자동으로 쓰도록 훅으로 연결합니다. Anthropic 문서가 차단된 네트워크에서도 문서 질문이 계속 동작합니다.

## 이 프로젝트가 추구하는 것

Claude Code에 "PreToolUse 훅은 어떻게 설정하나요?"라고 물으면, Claude는 질문을 `claude-code-guide` 서브에이전트에 위임하고, 이 에이전트는 `code.claude.com`을 가져와 답을 찾습니다. 문서가 웹에 있으니 당연한 기본값입니다 — `*.claude.*`가 차단된 네트워크에 들어가기 전까지는. 차단된 순간 실패는 깔끔하지 않습니다. Claude는 세 가지 방식으로 무너집니다:

| 실패 양상 | 결과 |
| :-------- | :--- |
| 학습 시점 지식으로 답변 | 이미 바뀐 옵션명과 경로를 자신 있게 안내 |
| 환각 | 존재하지 않는 훅 이벤트나 CLI 플래그를 그럴듯하게 생성 |
| 우회 검색 시도 | 가져오기 실패 → 재시도 → 검색엔진 → 블로그 — 토큰과 시간만 쓰고 정확도는 얻지 못함 |

이 프로젝트는 그 웹 의존을 제거합니다: 문서는 디스크에 있고, 스스로 최신을 유지하며, Claude가 자동으로 사용합니다.

설계를 이끄는 목표는 세 가지입니다:

- **언제나 읽을 수 있는 문서.** 전체 문서 세트(작성 시점 기준 174개 페이지)를 로컬에 미러링하고 3시간마다 동기화합니다 — 빠른 회선에서든, 사내 프록시 뒤에서든, 완전한 오프라인에서든 같은 문서를 똑같이 볼 수 있습니다.
- **시키지 않아도 로컬 파일로 답하는 Claude.** 미러만으로는 부족합니다. 복사본의 존재를 Claude에게 알려주는 장치가 없기 때문입니다. 훅 두 개가 그 틈을 메웁니다: `WebFetch`에 걸린 `PreToolUse` 훅이 모든 `code.claude.com` 가져오기를 미러된 파일 읽기로 바꾸고, `SubagentStart` 훅이 문서 질문을 위임받는 서브에이전트인 `claude-code-guide`에게 첫 동작 전에 미러 위치를 알려줍니다.
- **방해하지 않는 최신성.** 업데이트는 백그라운드에서, 미러 자체의 갱신 주기인 3시간에 최대 1회 일어나며, 모든 네트워크 호출에 시간 상한이 있습니다 — 패킷을 조용히 버리는 네트워크에서도 동기화 장치가 읽기를 지연시킬 수 없습니다.

결과적으로 문서 질문은 미러에서 답을 얻습니다 — 정상 네트워크에서는 가져오기보다 빠르고, 차단된 네트워크에서는 그 방법으로만 동작합니다.

> ⚠️ **초기 베타입니다.** 이상 동작을 발견하면 [이슈를 등록](https://github.com/posimind/claude-code-docs/issues)해 주세요.

## 설치

macOS와 Linux를 지원합니다 (Windows: [실험적 Git Bash 우회](#windows-git-bash-실험적), [기여 환영](#기여와-알려진-문제)). `git`, `jq`, `curl`이 필요하며, Linux에서는 `jq`를 먼저 설치해야 할 수 있습니다 (`apt install jq` / `yum install jq`).

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

### 설치 확인

```bash
# 1) 명령 파일이 존재하는지
ls ~/.claude/commands/claude-docs.md

# 2) 훅 3개가 모두 등록됐는지
jq '.hooks | to_entries[] | .key as $e | .value[]
    | select((.hooks[0].command // "") | contains("claude-code-docs"))
    | "\($e) [\(.matcher)]"' ~/.claude/settings.json
```

두 번째 명령의 기대 출력은 정확히 다음과 같습니다:

```
"PreToolUse [Read]"
"PreToolUse [WebFetch]"
"SubagentStart [claude-code-guide]"
```

### 명령어 이름 변경

설치 시 `CLAUDE_DOCS_COMMAND_NAME`을 지정하면 `/claude-docs` 대신 다른 이름을 쓸 수 있습니다 (영문자, 숫자, 하이픈, 밑줄):

```bash
curl -fsSL https://raw.githubusercontent.com/posimind/claude-code-docs/main/install.sh -o /tmp/install.sh
CLAUDE_DOCS_COMMAND_NAME=cdocs bash /tmp/install.sh   # → /cdocs hooks
```

선택한 이름은 `~/.claude-code-docs/.command_name`에 기록되어, 제거 시 환경 변수를 다시 지정하지 않아도 올바른 명령 파일이 삭제됩니다. 이름을 바꿔도 훅에는 영향이 없습니다 — 훅은 명령어 이름이 아니라 헬퍼 스크립트 경로에 묶여 있습니다.

### Windows (Git Bash, 실험적)

> ⚠️ **공식 지원 플랫폼이 아닙니다.** 설치 스크립트는 macOS와 Linux만 허용하며, 아래는 이 저장소가 검증하는 구성이 아닌 우회 절차입니다. 널리 배포하기 전에 직접 검증하세요 — 그리고 설치 스크립트를 다시 실행하면 5단계와 6단계가 되돌아갈 수 있다는 점에 유의하세요.

이 우회가 성립하는 근거는 Claude Code 자체의 훅 실행 방식입니다. shell 형식의 훅 명령은 macOS/Linux에서는 `sh -c`로, **Windows에서는 Git Bash로** 전달되며, Git Bash가 없을 때만 PowerShell로 폴백합니다. 즉 Git for Windows만 설치되어 있으면 `~/.claude-code-docs/claude-docs-helper.sh`를 훅 명령으로 그대로 쓸 수 있습니다.

가는 길에 네 가지가 걸립니다. 아래 순서대로 처리하면 됩니다: Git Bash에는 `jq`가 없고, CRLF 줄바꿈이 스크립트를 깨뜨리며, `column`이 없는 데다 Windows 자체의 `timeout.exe`가 GNU `timeout`을 가리고, 설치 스크립트의 OS 검사가 `msys`를 거부합니다.

**0단계 — Git for Windows와 jq.** Git for Windows에는 `git`, `bash`, `curl`이 들어 있지만 `jq`는 포함되지 않습니다:

```powershell
winget install jqlang.jq
```

설치 후 **새** Git Bash 창에서 확인하세요 (`jq.exe`를 `C:\Program Files\Git\usr\bin`에 직접 넣어도 됩니다):

```bash
git --version && curl --version | head -1 && jq --version
```

**1단계 — `$HOME`이 `%USERPROFILE%`과 같아야 합니다.** Git Bash의 `$HOME`과 Claude Code가 보는 `%USERPROFILE%`이 다르면, 설치는 성공해도 훅과 명령이 Claude Code가 읽지 않는 위치에 만들어집니다.

```bash
echo "$HOME"                        # /c/Users/<사용자> 형태여야 합니다
cmd.exe /c "echo %USERPROFILE%"     # C:\Users\<사용자>
```

두 값이 다르면 Windows 시스템 환경변수 `HOME`을 `%USERPROFILE%`로 지정하고 Git Bash를 다시 여세요.

**2단계 — CRLF 줄바꿈 방지 (가장 흔한 실패 원인).** 저장소에 `.gitattributes`가 없고 Git for Windows의 기본값은 `core.autocrlf=true`라서, 그대로 clone하면 셸 스크립트가 CRLF로 저장되고 bash는 `$'\r': command not found`로 실패합니다. 설치 전에:

```bash
git config --global core.autocrlf input
```

이미 CRLF로 받았다면 재체크아웃으로 복구합니다:

```bash
cd ~/.claude-code-docs
git config core.autocrlf input
git rm --cached -r . > /dev/null
git reset --hard

# 확인: 출력에 \r 이 보이면 아직 CRLF 상태입니다
head -1 install.sh | od -c | head -2
```

**3단계 — `column` shim 만들기.** Git Bash에는 `column`이 없어서, `set -e` 아래에서 토픽 목록 출력(설치 스크립트 마지막, 인자 없는 `/claude-docs`, 검색 실패 시 목록)이 그 지점에서 끊깁니다. `column`은 정렬만 담당하므로 `cat`으로 대체해도 기능 손실은 없습니다 — 다단 정렬 대신 한 줄에 하나씩 나올 뿐입니다. 관리자 권한 Git Bash에서 (`/usr/bin`은 `C:\Program Files\Git\usr\bin`):

```bash
printf '#!/bin/sh\nexec cat\n' > /usr/bin/column
chmod +x /usr/bin/column
column < /dev/null && echo "column shim OK"
```

**4단계 — 어떤 `timeout`이 잡히는지 확인.** 헬퍼는 `timeout` 명령이 있으면 그것으로 네트워크 git 호출에 상한을 겁니다 (`timeout 15 git fetch …`). 그런데 Git Bash의 PATH에는 Windows의 `C:\Windows\System32\timeout.exe` — 전혀 무관한 대기 유틸리티 — 가 잡힐 수 있고, 이 경우 상한이 걸린 모든 git 호출이 문법 오류로 실패합니다. 헬퍼는 이를 "GitHub 불통"으로 해석해 **조용히 낡은 문서를 계속 제공**하게 됩니다.

```bash
type -a timeout
timeout 1 true; echo "exit=$?"      # exit=0 이면 GNU timeout — 정상
```

GNU가 아니라면 GNU coreutils의 `timeout.exe`를 `/usr/bin`에 넣는 것이 깔끔한 해결책입니다. 임시 방편으로는 통과형 shim도 동작하지만, 시간 상한을 포기하는 대가가 있습니다 — 죽은 네트워크에서 git이 오래 매달릴 수 있습니다:

```bash
printf '#!/bin/sh\nshift\nexec "$@"\n' > /usr/bin/timeout
chmod +x /usr/bin/timeout
```

**5단계 — OS 게이트 패치 후 설치.** `install.sh`는 `$OSTYPE`가 `darwin*` 또는 `linux-gnu*`가 아니면 즉시 종료하는데, Git Bash의 `$OSTYPE`는 `msys`입니다. 내려받아 해당 분기 한 줄만 넓히세요:

```bash
curl -fsSL https://raw.githubusercontent.com/posimind/claude-code-docs/main/install.sh -o install.sh

# 파일 상단의 OS 감지 블록에서:
#   변경 전: elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
#   변경 후: elif [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ]]; then
sed -i 's|elif \[\[ "$OSTYPE" == "linux-gnu"\* \]\]; then|elif [[ "$OSTYPE" == "linux-gnu"* \|\| "$OSTYPE" == msys* \|\| "$OSTYPE" == cygwin* ]]; then|' install.sh

grep -n 'OSTYPE' install.sh   # 패치 확인
bash -n install.sh            # 문법 검사
bash install.sh               # 설치
```

이 게이트는 OS를 분류하는 역할뿐이고, 설치 스크립트의 나머지 로직은 OS별로 분기하지 않습니다.

**6단계 — 훅 셸을 bash로 고정 (권장).** 기본값이 이미 Git Bash이지만, `"shell": "bash"`를 명시하면 PowerShell 폴백 가능성을 차단합니다. 아래 명령은 `claude-code-docs` 훅에만 필드를 추가하며, 직접 만든 훅은 건드리지 않습니다:

```bash
jq '
def fix(list): [ (list // [])[]
  | if ((((.hooks // [])[0].command) // "") | contains("claude-code-docs"))
    then .hooks[0].shell = "bash" else . end ];
.hooks.PreToolUse = fix(.hooks.PreToolUse)
| .hooks.SubagentStart = fix(.hooks.SubagentStart)
' ~/.claude/settings.json > ~/.claude/settings.json.tmp \
  && mv ~/.claude/settings.json.tmp ~/.claude/settings.json
```

> 설치 스크립트를 다시 실행하면 훅이 새로 기록되면서 `shell` 필드가 사라집니다 — 업데이트 후에는 이 단계를 한 번 더 실행하세요.

**7단계 — 검증.** [설치 확인](#설치-확인)의 명령을 실행한 뒤, 헬퍼를 단독으로 실행해 보세요 — CRLF나 jq 문제가 남아 있으면 여기서 드러납니다:

```bash
~/.claude-code-docs/claude-docs-helper.sh -t
```

Claude Code를 재시작하고 `/claude-docs -t`가 `✅ You have the latest documentation`을 출력하는지 확인하세요. 여기까지 통과하면 사용법은 macOS/Linux와 완전히 동일합니다.

참고 두 가지: 훅이 실행 권한 문제로 실패하면 명령을 `bash ~/.claude-code-docs/claude-docs-helper.sh <서브커맨드>` 형태로 바꾸면 우회됩니다. `uninstall.sh`에는 OS 게이트가 없어 그대로 동작하지만, 3–4단계에서 만든 shim은 직접 지워야 합니다.

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

페이지를 읽으면 `✅ You have the latest docs (v0.4.1, main)` 같은 최신 상태 표시가 먼저 출력됩니다. `what's new`는 최근 문서 커밋의 링크와 변경된 페이지 목록을 보여줍니다. `changelog`는 동기화 워크플로가 Claude Code 저장소에서 미러링해 둔 공식 `CHANGELOG.md`를 읽습니다 — 다른 모든 페이지처럼 오프라인에서도 동작합니다. 존재하지 않는 주제를 입력해도 오류가 나지 않습니다: 헬퍼가 입력에서 키워드를 추출해 일치하는 주제 후보를 대신 보여줍니다.

`-t`는 동기화 판정, 브랜치, 버전을 함께 출력합니다:

```
✅ You have the latest documentation    # 또는: ⚠️ behind by N commit(s) / ⚠️ Could not sync with GitHub
📍 Branch: main
📦 Version: 0.4.1
```

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

한 줄로 요약하면: ①이 문서를 GitHub에 발행하고, ②가 그것을 게으르게 당겨오며, ③이 Claude의 시선을 웹에서 디스크로 돌립니다.

### ① 원격 미러 — 일정에 따라 도는 발행자

이 저장소의 GitHub Actions 워크플로(`.github/workflows/update-docs.yml`)가 3시간 고정 cron으로 `code.claude.com`의 모든 페이지를 가져와 변경분을 커밋합니다. GitHub 인프라에서 실행됩니다:

- 누가 Claude Code를 쓰든 말든 일어납니다 — 사용자의 머신은 전혀 관여하지 않습니다
- 시스템 전체에서 `code.claude.com`에 접속하는 **유일한** 지점입니다
- 이 3시간 주기가 하류 전체의 "최신"을 정의합니다 — 최대 지연은 3시간입니다

매 실행은 같은 파이프라인(`scripts/fetch_claude_docs.py`)을 거칩니다:

1. `https://code.claude.com/docs/sitemap.xml`에서 페이지 목록을 발견 (실패 시 레거시 sitemap으로 폴백)
2. 각 페이지를 **HTML이 아니라 원본 마크다운으로** 가져오기 — `<페이지 URL>.md`를 직접 요청하므로 파싱·재가공 단계가 없습니다
3. 받은 내용 검증 (HTML이 섞여 오지 않았는지, 최소 길이, 마크다운 구조) — 검증에 실패한 페이지는 저장하지 않습니다
4. 실패한 페이지는 지수 백오프로 3회 재시도, 그래도 실패하면 이전 사본을 그대로 유지
5. 중첩 경로는 `__`로 평탄화 (`/docs/en/agent-sdk/python` → `agent-sdk__python.md`)
6. 파일별 SHA-256 해시·원본 URL·수집 시각을 `docs/docs_manifest.json`에 기록
7. 실제로 변한 것이 있을 때만 커밋 — 빈 커밋을 만들지 않습니다

문서 사이트에서 오지 않는 유일한 페이지는 `changelog.md`로, `anthropics/claude-code` 저장소의 `CHANGELOG.md`에서 미러링합니다.

수집이 중간에 실패하면 워크플로는 **아무것도 커밋하지 않고** — 매니페스트와 어긋난 반쪽 상태의 미러가 발행되는 일은 없습니다 — 저장소에 자동으로 이슈를 생성합니다.

### ②③ 로컬 설치본 — 이벤트에 반응하는 소비자

`~/.claude-code-docs`의 설치본은 공식 사이트에 접속하지 않습니다. 하는 일은 두 가지이며, 둘 다 일정이 아니라 사용에 의해서만 촉발됩니다 — Claude를 쓰지 않는 동안 머신에서는 아무것도 돌지 않습니다.

**③ Claude를 로컬 파일로 연결** — 질문할 때마다, 즉시, 네트워크 없이:

- Claude Code 질문이 `claude-code-guide`에 위임되면 그 에이전트는 미러 위치가 이미 주입된 채 시작합니다
- `code.claude.com` 가져오기는 거부되고 미러된 파일이 대신 안내됩니다
- 마지막 동기화가 1분 전이든 네트워크가 일주일째 끊겨 있든 똑같이 동작합니다 (자세한 구조는 [오프라인 및 제한된 네트워크](#오프라인-및-제한된-네트워크) 참고)

**② 스스로 최신 유지** — 반응형으로, 스로틀 하에:

```
Claude가 파일을 Read
  → PreToolUse[Read] 발동 → claude-docs-helper.sh hook-check
  → 읽는 파일이 ~/.claude-code-docs 밖?  → 즉시 종료 (아무 일도 하지 않음)
  → 미러 안이면 → .last_check 타임스탬프 확인
       · 3시간이 지나지 않았으면 → 그대로 종료
       · 지났으면 → git fetch (15초 상한) → 뒤처져 있을 때만 pull (30초 상한)
  → 성공이든 실패든 항상 exit 0
```

- **미러 밖 파일 읽기는 즉시 통과합니다.** 프로젝트 소스코드를 읽을 때 git fetch를 기다리는 일은 없습니다.
- **훅은 언제나 exit 0으로 끝납니다.** `PreToolUse` 훅의 exit 2는 툴 호출 자체를 차단하므로, GitHub 불통이 Claude의 파일 읽기를 막는 상황은 원천적으로 생기지 않습니다.
- **3시간 스로틀**은 ①의 발행 주기와 같습니다 — 그보다 자주 확인해도 새 것이 있을 수 없습니다. 타임스탬프는 설치 시점에도 기록되고(설치 몇 초 뒤의 무의미한 재확인 방지), 매번 fetch **직전**에 갱신되므로 죽은 네트워크의 타임아웃 비용은 읽기마다가 아니라 3시간에 한 번입니다.
- **시간 상한(fetch 15초 / pull 30초)**은 패킷을 조용히 버리는 네트워크에서도 유지됩니다. `timeout(1)`에 의존하며, 이것이 없는 stock macOS에서는 curl 저속 중단으로 폴백합니다 — 멈춘 전송은 끊지만 매달린 연결은 못 끊는 best-effort입니다.
- **뒤처졌을 때만 pull합니다.** 로컬이 origin과 같거나 앞서 있으면 아무것도 하지 않으므로, 로컬 수정본을 덮어쓰지 않습니다.
- `/claude-docs -t`는 스로틀을 우회해 지금 즉시 동기화합니다.

한 가지 더: `install.sh`나 헬퍼 스크립트 템플릿을 바꾸는 업데이트는 설치 스크립트 재실행이 필요한데, 훅은 그렇게 할 수 없습니다 — 지금 실행 중인 스크립트를 다시 렌더링하는 꼴이 되기 때문입니다. 그래서 훅은 `.needs_reinstall` 마커만 남기고, **다음번 사용자 명령**이 이를 대신 처리합니다. 문서만 바뀐 업데이트 — 거의 전부가 그렇습니다 — 는 이 경로에 아예 들어오지 않습니다.

### 한눈에 비교

| | ① 원격 미러 동기화 | ②③ 로컬 설치본 |
| :- | :---------------- | :------------- |
| 실행 위치 | GitHub 인프라 | 사용자의 머신 |
| 트리거 | 3시간 cron 일정 | Claude의 읽기 / 가져오기 / 질문 |
| 접속 대상 | `code.claude.com` | `github.com`만 |
| 유휴 상태일 때 | 3시간마다 계속 발행 | 아무것도 하지 않음 |
| 실패하면 | 커밋 없이 이슈 생성, 다음 주기에 재시도 | 캐시된 문서를 계속 제공, 읽기는 절대 차단되지 않음 |

## 오프라인 및 제한된 네트워크

### 가져오기 리다이렉트

`WebFetch` 훅이 `code.claude.com` URL을 `docs_manifest.json`으로 조회한 뒤, Claude가 보게 될 사유에 로컬 경로를 담아 가져오기를 거부합니다:

```
WebFetch https://code.claude.com/docs/en/agent-sdk/python
  -> denied: "This page is mirrored locally and code.claude.com is not
              reachable from this network. Read
              ~/.claude-code-docs/docs/agent-sdk__python.md instead."
```

URL은 두 단계로 해석됩니다. 먼저 쿼리 문자열·프래그먼트·끝의 `.md`·후행 슬래시를 제거한 뒤:

1. **매니페스트 정확 일치** — `docs_manifest.json`의 `original_url` 항목과 대조합니다 (권위 있는 경로)
2. **명명 규칙 폴백** — 없으면 `/docs/en/` 이후 경로를 `__`로 평탄화해 파일 존재 여부를 확인합니다 (마지막 동기화 이후 새로 생긴 페이지 대응)

| URL | 결과 |
| :-- | :--- |
| `/docs/en/hooks` | `docs/hooks.md` |
| `/docs/en/agent-sdk/python` | `docs/agent-sdk__python.md` |
| `/docs/en/hooks#pretooluse` | `docs/hooks.md` (프래그먼트 제거 후 조회) |
| 미러에 없는 페이지 | 가져오기는 여전히 거부하되, 미러에 대한 `ls`와 `grep`을 안내 |
| `https://example.com/…` | 변환 없음 — 다른 호스트는 그대로 통과 |

### `claude-code-guide` 서브에이전트 유도

`SubagentStart` 훅이 에이전트의 첫 동작 전에 컨텍스트를 주입합니다: 미러의 위치와 문서 개수(실행 시점에 세어서 넣습니다), 네트워크가 차단되어 있으니 로컬 파일로 답하라는 지시, 페이지 찾는 방법(`Read <주제>.md` 또는 `grep -ril '<키워드>'`), 밑줄 두 개 평탄화 규칙, 그리고 `docs_manifest.json`이 모든 파일을 공식 URL로 되짚어 주므로 그 URL은 인용하되 가져오지는 말라는 안내입니다.

두 훅이 각각 다른 경로를 막습니다: `SubagentStart` 컨텍스트가 애초에 웹으로 가지 않게 만들고, `WebFetch` 가드가 그래도 가려는 시도를 잡아챕니다. 이 이중 구조 덕분에 사용자 쪽 추가 동작이 0이 됩니다.

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

**`-t`가 "Could not sync with GitHub"를 출력** — 네트워크에서 GitHub 자체에 접근할 수 없는 상태입니다. 이 상태에서도 캐시된 문서 읽기는 정상 동작합니다. Windows라면 `timeout` 충돌([Windows 섹션](#windows-git-bash-실험적) 4단계)을 먼저 의심하세요.

**(Windows) `$'\r': command not found`** — CRLF로 clone된 상태입니다. Windows 섹션 2단계로 재체크아웃하세요.

**(Windows) 토픽 목록이 중간에 끊김** — `column` 미설치입니다. Windows 섹션 3단계의 shim을 만드세요.

**(Windows) `Unsupported OS type: msys`** — OS 게이트가 패치되지 않았습니다. Windows 섹션 5단계를 참고하세요.

## 제거

```bash
~/.claude-code-docs/uninstall.sh    # 또는 /claude-docs uninstall 로 안내 보기
```

명령어, 훅, 설치 디렉터리를 제거합니다. 수동 제거는 [UNINSTALL.md](UNINSTALL.md)를 참고하세요.

## 신뢰와 보안

Claude Code에 훅으로 끼어드는 외부 스크립트를 설치하는 일이므로, 근거를 하나씩 짚어 봅니다.

**무결성 — 내용이 조작되지 않았음을 어떻게 아는가.** 수집 파이프라인은 전자동이며 사람이 편집하는 단계가 없습니다. 수집 스크립트(`scripts/fetch_claude_docs.py`)와 워크플로 정의가 이 저장소에 공개되어 있어 직접 읽을 수 있습니다. 페이지는 공식 사이트가 제공하는 원본 마크다운 그대로 저장됩니다 — 요약이나 재작성 단계가 없습니다. 파일마다 SHA-256 해시·원본 URL·수집 시각이 `docs/docs_manifest.json`에 기록되므로, 변조 여부를 기계적으로 검증할 수 있습니다:

```bash
# 기록된 해시와 실제 파일 해시 비교
cd ~/.claude-code-docs
jq -r '.files["hooks.md"]' docs/docs_manifest.json
sha256sum docs/hooks.md
```

모든 변경이 커밋으로 남으므로 전체 히스토리가 곧 감사 로그입니다 — 어떤 문장이 언제 어떤 커밋으로 바뀌었는지 추적됩니다. 그리고 답변에는 항상 공식 URL(`📖 Official page: …`)이 따라붙어 언제든 원문 대조가 가능합니다.

**네트워크 경계.** 로컬 설치본은 `code.claude.com`에 단 한 번도 접속하지 않습니다 — 차단된 도메인을 우회하는 프록시나 터널이 아니라, 이미 공개된 콘텐츠의 정적 사본입니다. 접속하는 유일한 외부 호스트는 HTTPS를 통한 `github.com`이며, 용도는 `git fetch` / `git pull`뿐입니다. (설치 시점에 한해 `raw.githubusercontent.com`에서 설치 스크립트와, 템플릿 누락 시의 복구용 헬퍼 템플릿을 추가로 내려받습니다.)

**외부로 나가는 데이터 없음.** 훅이 하는 일은 로컬 파일 읽기와 URL 문자열 매핑이 전부입니다 — 질문, 코드, 프롬프트가 밖으로 나갈 경로가 없습니다. 텔레메트리·분석 코드가 없고, 모든 파일 접근이 `~/.claude-code-docs` 안으로 제한됩니다. `WebFetch`와 `SubagentStart` 훅은 JSON 결정과 컨텍스트를 출력할 뿐 네트워크를 건드리지 않으며, 네트워크 호출이 일어나는 유일한 지점은 동기화 경로의 GitHub 대상 git 명령입니다. 명령 인자는 셸 메타문자와 제어문자를 제거한 뒤 처리합니다.

**설치 흔적과 원복.** 변경되는 대상은 정확히 셋입니다: `~/.claude/settings.json`(훅 3개), `~/.claude/commands/<이름>.md`(명령), `~/.claude-code-docs/`(설치 디렉터리). 훅은 명령 문자열에 `claude-code-docs`가 포함된 항목으로만 매칭해 제거합니다 — 직접 추가한 훅은 절대 건드리지 않습니다. `uninstall.sh`는 이 모두를 제거하되 `settings.json`은 먼저 백업하고, 설치 디렉터리에 커밋되지 않은 변경이 있으면 지우지 않고 보존합니다.

**더 강한 통제가 필요하다면.** 설치 스크립트를 내려받아 읽고 나서 실행하거나, 저장소를 fork해 자신의 fork에서 설치하세요. GitHub 자체가 막힌 환경이라면 사내 git 서버로 미러링한 뒤 remote만 교체하면 됩니다:

```bash
cd ~/.claude-code-docs
git remote set-url origin https://git.internal.example.com/mirror/claude-code-docs.git
git pull
```

훅은 `origin`이 어디를 가리키든 동작하고 업데이트도 계속 `origin`에서 pull하므로 교체가 유지됩니다. 다만 디렉터리가 지워져 설치 스크립트가 새로 clone하는 경로를 타면 다시 `posimind`에서 받아옵니다 — 공식 지원 시나리오가 아니므로 도입 전에 검증하세요.

## 한계

- **커뮤니티 미러이며 Anthropic 공식 제공물이 아닙니다** — 헬퍼 출력에도 `COMMUNITY MIRROR - NOT AFFILIATED WITH ANTHROPIC`이 명시됩니다
- **공식 문서 대비 최대 3시간 지연** — 방금 갱신된 페이지는 아직 반영 전일 수 있습니다
- **초기 베타** — 특이한 네트워크 구성에서 자동 업데이트가 실패하거나, 일부 문서 내 링크가 해석되지 않을 수 있습니다
- **Windows는 공식 지원 대상이 아닙니다** — [Git Bash 우회](#windows-git-bash-실험적)로 동작시킬 수 있지만 저장소가 검증하는 구성이 아니며, 설치 스크립트 업데이트가 패치를 되돌릴 수 있습니다
- **훅이 커버하지 못하는 경로가 하나 있습니다**: Claude가 아무것도 조회하지 않고 기억만으로 답하는 경우입니다. 설계상 그때는 아무것도 발동하지 않습니다 — 정확성이 중요하면 `/claude-docs`로 조회를 강제하세요

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
