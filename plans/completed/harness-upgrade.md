# Kế hoạch nâng cấp orca-workflow theo Harness Engineering

> **Dành cho Claude Code:** Đây là execution plan. Đọc toàn bộ file trước khi làm.
> Làm **từng giai đoạn một**, dừng sau mỗi giai đoạn để chủ repo duyệt.
> Không xóa nội dung hiện có trong repo, chỉ bổ sung hoặc tách file.
> Đặt file này tại `plans/active/harness-upgrade.md` trong repo và cập nhật mục
> "Nhật ký tiến độ" ở cuối sau mỗi giai đoạn.

---

## 1. Mục tiêu

Biến orca-workflow thành **bộ quy trình bắt buộc phải hoàn thành trước khi bắt
đầu bất kỳ dự án nào**, gồm hai tầng:

- **Tầng chung:** giống nhau ở mọi dự án, được dựng tự động từ template
  (hook, CI, cấu trúc `.ai/`, hợp đồng lệnh `make`).
- **Tầng riêng:** khác nhau theo từng dự án (ngôn ngữ, linter, kiến trúc, bất biến
  nghiệp vụ, vùng nhạy cảm), được xác định qua **quy trình onboarding** có phỏng
  vấn chủ dự án.

Trạng thái "sẵn sàng" phải **kiểm tra được bằng máy** (`doctor.sh`), không dựa
vào trí nhớ của người hay agent. Chưa sẵn sàng thì Router không nhận task tính năng.

---

## 2. Bối cảnh

Nguồn tham khảo chính: bài "Harness engineering: leveraging Codex in an
agent-first world" của OpenAI (Ryan Lopopolo, 02/2026):
https://openai.com/index/harness-engineering/

Ý tưởng cốt lõi: khi agent viết code, việc của con người là **thiết kế môi
trường** (tài liệu, luật, vòng phản hồi, cơ chế kiểm tra) để agent làm đúng một
cách đáng tin cậy. Môi trường đó gọi là **harness**.

Sáu mục lớn trong bài của OpenAI:

1. Tài liệu trong repo là nguồn sự thật. `AGENTS.md`/`CLAUDE.md` ngắn (~100 dòng)
   làm **mục lục**, trỏ tới tài liệu chi tiết (progressive disclosure).
2. Kế hoạch là tài liệu chính thức: execution plan có log tiến độ và quyết định,
   cùng nợ kỹ thuật, được lưu trong repo.
3. **Ép kiến trúc bằng máy**: linter tự viết và structural test. Thông báo lỗi
   ghi sẵn cách sửa để agent tự sửa. Ép bất biến, không ép cách làm.
4. Cho agent "nhìn thấy" ứng dụng: chạy app, điều khiển trình duyệt, đọc log và metric.
5. Review agent với agent, lặp đến khi các reviewer hài lòng.
6. Dọn rác định kỳ và vòng phản hồi: agent nền quét code lệch chuẩn và mở PR
   nhỏ; mọi góp ý của con người được biến thành tài liệu hoặc luật.

### Nguyên tắc rút ra (áp dụng xuyên suốt plan này)

- **CLAUDE.md là hướng dẫn, linter/test là luật.** Chữ thì agent có thể quên;
  máy thì luôn kiểm tra.
- Ghi "hãy chạy test" trong CLAUDE.md vẫn chỉ là lời dặn. Phải dùng **hook** và
  **CI** để bước kiểm tra không thể bị bỏ qua.
- Ba lớp: CLAUDE.md (giải thích) → hook (agent tự sửa ngay) → CI chặn merge (chốt cuối).
- **Bắt đầu bằng chữ; lỗi nào lặp lại thì nâng cấp thành luật trong máy.**
- Phân loại việc theo **rủi ro**, không theo số dòng code. Không chắc thì chọn mức cao.
- Con người định nghĩa "đúng" bằng **tiêu chí nghiệm thu viết bằng lời**. Agent
  chuyển thành test. Với việc rủi ro cao: viết test trước → người duyệt → mới code.
- Không phụ thuộc ngôn ngữ: mọi dự án cung cấp **cùng tên lệnh** `make`.
  Hook và CI chỉ gọi các lệnh đó.
- **Luật cũng phải được test**: mỗi luật lint tự viết có một ví dụ vi phạm để
  chứng minh luật thật sự bắt được lỗi.

---

## 3. Đánh giá hiện trạng repo (09/2026)

Repo có 26 file markdown, khoảng 7.300 dòng.

**Đã tốt, giữ nguyên:**
- `router/ROUTER.md` có intake gate: làm rõ yêu cầu, ghi tiêu chí nghiệm thu,
  đảm bảo `.ai/project.md` tồn tại, chọn workflow nhỏ nhất đủ tin cậy, chọn mức xác minh.
- `rules/testing.md` có 5 mức xác minh (Level 1 Static → Level 5 Full).
- `project/.ai/project.md` đã có các mục Commands, Testing, Important Boundaries,
  Security & Constraints. Plan này **tái sử dụng** các mục đó, không tạo trùng.
- Có vai trò `builder`, `tester`, `reviewer`, `qa` (tương ứng mục 5 của OpenAI).
- Các nguyên tắc idempotent, security gate, attack-the-premise.

**Còn thiếu:**
- Toàn bộ luật đang là chữ. Không có hook, template CI, hay hợp đồng lệnh nào.
- Không có định nghĩa "dự án sẵn sàng" và không có cách kiểm tra bằng máy.
- Không có quy trình onboarding dự án (mới hoặc đang có) với phần setup riêng.
- Không có sổ bất biến (invariants) ghi rõ luật nào đã được ép bằng máy.
- Không có cơ chế cập nhật khi template trong orca-workflow thay đổi.
- Điểm vào quá dài: `ROUTER.md` gần 1.000 dòng, `ORCA-INTEGRATION.md` hơn 850 dòng,
  `agents/architect.md` hơn 800 dòng. Mỗi dự án cũng chưa có `CLAUDE.md` riêng,
  trong khi Claude Code tự nạp `CLAUDE.md` chứ không tự nạp `.ai/project.md`.
- Không có execution plan, nợ kỹ thuật, feedback log, hay quy trình dọn rác.

**Ràng buộc cần tôn trọng:** README ghi "Never build a second orchestration
system beside Orca". Hook, CI và doctor trong plan này là **cơ chế xác minh**,
không phải điều phối. Không thêm bất cứ thứ gì tự dispatch hay quản lý worker.

---

## 4. Tiêu chuẩn sẵn sàng dự án (Project Readiness Standard)

Đây là "bộ phải có trước khi bắt đầu". `doctor.sh` kiểm tra từng mục.
**Bắt buộc** = thiếu thì doctor báo lỗi và Router không nhận task tính năng.
**Khuyến nghị** = doctor chỉ cảnh báo.

### Tầng A — Chung (dựng tự động từ template)

| # | Mục | Mức |
|---|---|---|
| A1 | `CLAUDE.md` của dự án (mục lục ngắn, trỏ tới orca-workflow và `.ai/`) | Bắt buộc |
| A2 | `.ai/project.md` đã điền, không còn placeholder dạng `[...]` | Bắt buộc |
| A3 | `Makefile` có đủ target: `setup`, `lint`, `test`, `verify` | Bắt buộc |
| A4 | `.claude/settings.json` và `.claude/hooks/*.sh` (có quyền chạy) | Bắt buộc |
| A5 | `.github/workflows/ci.yml` | Bắt buộc |
| A6 | `.gitignore` phù hợp ngôn ngữ; `.env.example` nếu dùng biến môi trường; không có file `.env` bị commit | Bắt buộc |
| A7 | Quét secret trong CI (vd. gitleaks) | Bắt buộc |
| A8 | `.ai/invariants.md`, `.ai/feedback-log.md`, `.ai/tech-debt.md`, `.ai/plans/{active,completed}/` | Bắt buộc |
| A9 | `.ai/enforcement.json` ghi phiên bản template đã cài | Bắt buộc |
| A10 | Target `format-check`, `typecheck`, `lint-file`, `verify-full` | Khuyến nghị |

### Tầng B — Riêng (xác định qua onboarding)

| # | Mục | Mức |
|---|---|---|
| B1 | Linter thật cho ngôn ngữ của dự án, có file cấu hình, **đã chứng minh bắt được lỗi** | Bắt buộc |
| B2 | Test framework, có ít nhất một smoke test chạy được | Bắt buộc |
| B3 | Kiến trúc: các tầng và chiều phụ thuộc được ghi trong `project.md` ("Important Boundaries") | Bắt buộc |
| B4 | Structural test ép chiều phụ thuộc giữa các tầng | Khuyến nghị (bắt buộc với dự án rủi ro cao) |
| B5 | `sensitive_paths` được khai báo trong `project.md` | Bắt buộc (được phép rỗng nếu ghi rõ lý do) |
| B6 | Sổ bất biến có ít nhất các bất biến rủi ro cao của dự án | Bắt buộc |
| B7 | Mọi bất biến rủi ro cao **được ép bằng máy**, hoặc có mục trong `tech-debt.md` kèm hạn | Bắt buộc |

### Tầng C — Việc làm tay (agent không làm được)

| # | Mục | Cách kiểm tra |
|---|---|---|
| C1 | Bật luật chặn merge trên nhánh `main` (require status checks + require PR) | Doctor kiểm tra qua `gh api` nếu có `gh`; nếu không, ghi "cần xác nhận tay" |
| C2 | Secret dùng trong CI đã được thêm vào GitHub | Chủ dự án xác nhận |

---

## 5. Cấu trúc file của một dự án sau onboarding

```
<project>/
├── CLAUDE.md                  # [dự án] mục lục ngắn
├── Makefile                   # [dự án] lệnh thật theo ngôn ngữ
├── .gitignore, .env.example   # [dự án]
├── .claude/
│   ├── settings.json          # [managed] đăng ký hook
│   └── hooks/
│       ├── lint-file.sh       # [managed]
│       ├── verify-before-stop.sh  # [managed]
│       └── doctor.sh          # [managed] kiểm tra tiêu chuẩn sẵn sàng
├── .github/workflows/ci.yml   # [managed] chỉ gọi make; phần setup được phép tùy chỉnh
├── scripts/checks/            # [dự án] luật lint tự viết (nếu cần)
├── tests/lint-fixtures/       # [dự án] ví dụ vi phạm để test chính các luật
└── .ai/
    ├── project.md             # [dự án] bối cảnh, kiến trúc, sensitive_paths
    ├── invariants.md          # [dự án] sổ bất biến
    ├── feedback-log.md        # [dự án]
    ├── tech-debt.md           # [dự án]
    ├── enforcement.json       # [managed] phiên bản template
    └── plans/active/, plans/completed/
```

**Quy ước quyền sở hữu file:**
- `[managed]`: sinh từ template của orca-workflow. Có dòng đầu ghi
  *"Managed by orca-workflow. Chỉnh ở orca-workflow/enforcement, không sửa tay."*
  Được cập nhật bằng `bootstrap.sh --upgrade`.
- `[dự án]`: thuộc về dự án, không bao giờ bị ghi đè khi nâng cấp template.
- Nhờ hook và CI **chỉ gọi `make`**, mọi khác biệt theo ngôn ngữ nằm trong file
  `[dự án]`, còn file `[managed]` giống hệt nhau ở mọi dự án.

---

## 6. Lộ trình

### Giai đoạn 1 — Bộ template ép buộc dùng chung ⭐ ưu tiên cao nhất

Tạo thư mục `enforcement/` trong orca-workflow:

```
enforcement/
├── README.md                  # cách cài và cách onboarding một dự án
├── VERSION                    # phiên bản template, vd. 1.0.0
├── bootstrap.sh               # bootstrap.sh <dir> --stack <node-ts|python>
├── project/                   # template file [dự án]: CLAUDE.md, invariants.md,
│                              #   feedback-log.md, tech-debt.md, plan template
├── stacks/                    # phần riêng theo ngôn ngữ (Makefile, .gitignore, setup CI)
│   ├── node-ts/
│   └── python/
├── agents/                    # adapter theo agent; lõi chung là `make verify`
│   └── claude/
│       ├── settings.json
│       └── hooks/lint-file.sh, verify-before-stop.sh, doctor.sh
└── github/ci.yml
```

Cập nhật 2026-09-29 (xem nhật ký quyết định):
- `Makefile.example` được thay bằng `stacks/<ngôn ngữ>/`. Giai đoạn 1 chỉ làm
  `node-ts` và `python`; thêm `go`, `dotnet` khi có dự án thật cần.
- `claude/` được chuyển thành `agents/claude/`. Khi thêm Codex hoặc Gemini thì
  tạo `agents/<tên>/` bên cạnh, không sửa lõi.
- `global/` được dời sang giai đoạn 2, vì tiêu chí nghiệm thu giai đoạn 2 đã
  liệt kê nó.
- Giai đoạn 1 tạo thêm `CLAUDE.md` ngắn ở gốc orca-workflow. Giai đoạn 4 sẽ
  hoàn thiện file này.
- `doctor.sh` kiểm tra có `make` và `jq` trên máy.
- CI chỉ làm cho GitHub Actions.

**Hợp đồng lệnh** (thêm vào `rules/` thành luật bắt buộc cho mọi dự án):

| Lệnh | Ý nghĩa | Ai gọi |
|---|---|---|
| `make setup` | Cài thư viện và công cụ | CI, người mới |
| `make lint` | Linter + luật tự viết toàn dự án | `verify` |
| `make lint-file FILE=...` | Lint một file, cho hook chạy nhanh | Hook PostToolUse |
| `make format-check` | Kiểm tra định dạng (không sửa) | `verify` |
| `make typecheck` | Kiểm tra kiểu (nếu ngôn ngữ có) | `verify` |
| `make test` | Test đơn vị và smoke test | `verify` |
| `make verify` | Kiểm tra **nhanh** (mục tiêu dưới ~3 phút): format-check + lint + typecheck + test | Hook Stop |
| `make verify-full` | `verify` + integration/E2E (nếu có) | CI |

Tách `verify` và `verify-full` để hook Stop không phải chờ test chậm; test chậm
vẫn bị CI ép.

**Hook `lint-file.sh` (PostToolUse, matcher `Edit|Write`):**

```bash
#!/bin/bash
# Managed by orca-workflow. Chỉnh ở orca-workflow/enforcement, không sửa tay.
[ "$ORCA_SKIP_HOOKS" = "1" ] && exit 0
file=$(jq -r '.tool_input.file_path // empty')
[ -z "$file" ] && exit 0
make -n lint-file FILE="$file" >/dev/null 2>&1 || exit 0
if ! out=$(make lint-file FILE="$file" 2>&1); then
  echo "Linter báo lỗi ở $file. Hãy sửa theo hướng dẫn trong thông báo:" >&2
  echo "$out" >&2
  exit 2
fi
exit 0
```

**Hook `verify-before-stop.sh` (Stop):**

```bash
#!/bin/bash
# Managed by orca-workflow. Chỉnh ở orca-workflow/enforcement, không sửa tay.
[ "$ORCA_SKIP_HOOKS" = "1" ] && exit 0
input=$(cat)
# Chống vòng lặp vô tận: đã bị bắt làm lại một lần thì cho dừng (CI là chốt cuối)
if [ "$(echo "$input" | jq -r '.stop_hook_active')" = "true" ]; then
  exit 0
fi
if ! out=$(make verify 2>&1); then
  echo "Chưa được kết thúc: 'make verify' còn lỗi. Hãy sửa rồi thử lại:" >&2
  echo "$out" >&2
  exit 2
fi
exit 0
```

**`settings.json`** (đặt `timeout` để hook không treo phiên):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/lint-file.sh", "timeout": 60 }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/verify-before-stop.sh", "timeout": 300 }
        ]
      }
    ]
  }
}
```

**`doctor.sh`:** kiểm tra từng mục của Tiêu chuẩn sẵn sàng (mục 4), in bảng
✅/⚠️/❌, `exit 1` nếu thiếu mục bắt buộc. Có chế độ `--quiet` chỉ in các mục
thiếu (dùng cho hook global). So sánh `.ai/enforcement.json` với `VERSION` của
orca-workflow (nếu tìm thấy) để báo template đã cũ.

**`ci.yml`:** chạy trên `push` vào `main` và mọi `pull_request`. Các bước:
checkout → cài toolchain (phần duy nhất được tùy chỉnh theo dự án, đánh dấu rõ
bằng comment) → `make setup` → `make verify-full` (nếu target tồn tại, không thì
`make verify`) → quét secret → chạy `doctor.sh` để đảm bảo không ai xóa mất
enforcement.

**`bootstrap.sh <dir> [--upgrade] [--force]`:**
- Copy file `[managed]` và tạo file `[dự án]` từ template **nếu chưa có**.
- **Idempotent**: chạy nhiều lần không hỏng gì; không ghi đè file đã có.
- `--upgrade`: chỉ ghi đè file `[managed]`, cập nhật `enforcement.json`.
- Nếu dự án đã có `.claude/settings.json` thì **gộp** mục `hooks` bằng `jq`,
  không xóa cấu hình khác.

**Lối thoát khẩn cấp:** người có thể khởi động Claude Code với
`ORCA_SKIP_HOOKS=1` để tạm tắt hook. Agent không đặt được biến này cho tiến
trình Claude Code, và CI vẫn ép như thường.

Ghi chú kỹ thuật:
- Exit code 2 = lỗi chặn, stderr được gửi lại cho Claude. Với PostToolUse, file
  đã được sửa rồi; hook chỉ báo lỗi để agent sửa tiếp.
- Script cần `jq` và quyền chạy (`chmod +x`).
- Kiểm tra với `/hooks`. Đối chiếu tài liệu mới nhất: https://code.claude.com/docs/en/hooks

**Tiêu chí nghiệm thu giai đoạn 1:**
- [x] Có đủ file trong `enforcement/`, với `README.md` hướng dẫn từng bước.
- [x] `rules/` có luật mới: hợp đồng lệnh và Tiêu chuẩn sẵn sàng.
- [x] `bootstrap.sh` chạy hai lần liên tiếp: lần 2 không thay đổi gì.
- [x] `bootstrap.sh` trên dự án đã có `.claude/settings.json`: cấu hình cũ được giữ.
- [x] `doctor.sh` trên thư mục trống báo đủ các mục thiếu; sau khi dựng xong thì pass tầng A.
- [x] Thử: agent cố tình viết code vi phạm lint → bị hook chặn → tự sửa.
      Agent định kết thúc khi test lỗi → bị hook Stop giữ lại.

**Kết quả giai đoạn 1 (2026-09-29):**
- `enforcement/test.sh` gồm 20 phép thử cho bootstrap, doctor và hook. Chạy
  trong CI của repo này. Đã thử cố tình làm hỏng hook: các phép thử bắt được.
- Thử thật trên Windows với `claude -p`, dự án Python mẫu: hook lint chặn
  (exit 2) và Claude tự sửa; hook Stop giữ Claude lại khi `make verify` lỗi.
- Dự án `node-ts` mẫu: `make verify` chạy được; lint, typecheck và hook lint
  bắt được lỗi.
- Lệch so với plan ban đầu:
  - Hook được gọi bằng `bash "<đường dẫn>"`, nên không cần quyền chạy (chmod).
    Windows không giữ quyền này.
  - Chưa làm `--force` cho `bootstrap.sh`, vì chưa có nhu cầu.
  - Template Python chưa có `typecheck`, vì mypy báo lỗi khi dự án chưa có code.
    Thêm lúc onboarding nếu dự án cần.
  - `doctor.sh` mới kiểm tra tầng A, công cụ và C1. Tầng B làm ở giai đoạn 2,
    cùng onboarding.
  - C1 (luật chặn merge) chỉ cảnh báo, vì đây là việc làm tay.
- `ci.yml` đã chạy thật trên repo thử riêng tư `orca-ci-sandbox`:
  - Code đúng: CI xanh. Setup, verify, gitleaks và doctor đều chạy.
  - Test hỏng: CI đỏ ở bước Verify.
  - Token giả bị lộ: CI đỏ ở bước gitleaks (`github-pat`), token được che trong log.
  - Nâng `actions/*` lên v7, vì bản v4/v5 dùng Node 20 đã bị GitHub đánh dấu cũ.
- Lưu ý cho giai đoạn 3: agent có thể né lint bằng `# noqa`. Lần thử thật đã
  xảy ra đúng như vậy. Reviewer hoặc luật riêng cần bắt trường hợp này.

### Giai đoạn 2 — Quy trình onboarding dự án

Tạo `workflows/onboarding.md`. Đây là **task bắt buộc đầu tiên** của mọi dự án,
và Router tự chạy nó khi doctor chưa pass.

**Bước 0: Phân loại**
- *Dự án mới* (greenfield): gần như chưa có code.
- *Dự án đang có* (brownfield): đã có code, có thể đã có linter/test riêng.

**Bước 1: Phỏng vấn chủ dự án** (Router hỏi, dùng câu hỏi ngắn, chấp nhận "chưa biết"):
1. Dự án làm gì, cho ai? Thuộc loại nào (quản lý, tài chính, nội dung, công cụ nội bộ…)?
2. Ngôn ngữ, framework, nơi deploy?
3. Những điều **tuyệt đối không được sai** là gì? (đây là nguồn của bất biến)
4. Phần nào đụng tới tiền, quyền truy cập, dữ liệu cá nhân, xóa dữ liệu?
5. Kiến trúc mong muốn: các tầng/module chính là gì?
6. Có hệ thống bên ngoài nào (thanh toán, email, API đối tác)?
7. Cần kiểm thử tới mức nào (có cần E2E, test giao diện không)?
8. Ai duyệt PR: chủ dự án, agent reviewer, hay cả hai?

Agent **tự suy ra** những gì đọc được từ code (ngôn ngữ, framework, cấu trúc)
và chỉ hỏi phần còn thiếu.

**Bước 2: Dựng tầng A**
Chạy `enforcement/bootstrap.sh <dir>`.

**Bước 3: Dựng tầng B**
- **B1 Linter:** chọn linter phổ biến cho ngôn ngữ (vd. ESLint cho JS/TS, Ruff cho
  Python, golangci-lint cho Go; kiểm tra lại lựa chọn hiện hành trước khi cài), tạo
  file cấu hình, thêm formatter tương ứng. Nếu dự án đã có linter thì giữ và nối vào `make lint`.
- **Canary:** tạo tạm một file vi phạm rõ ràng, chạy `make lint`, **phải thấy lỗi**,
  rồi xóa file. Nếu không thấy lỗi thì linter chưa hoạt động.
- **B2 Test:** cài test framework, viết một smoke test (vd. module chính import được, app khởi động được).
- **B3/B4 Kiến trúc:** ghi các tầng và chiều phụ thuộc vào mục "Important
  Boundaries" của `project.md`; thêm structural test (vd. dependency-cruiser cho
  JS/TS, import-linter cho Python, depguard cho Go; kiểm tra lại trước khi dùng).
- **B5:** khai báo `sensitive_paths` trong mục "Security & Constraints" của `project.md`.
- **B6/B7 Bất biến:** chuyển câu trả lời phỏng vấn câu 3–4 thành `.ai/invariants.md`
  (định dạng ở mục 7). Ép bằng máy các bất biến rủi ro cao theo hướng dẫn ở giai đoạn 3.
- Viết `Makefile` thật; mục "Development Commands" của `project.md` **trỏ tới các
  target của Makefile** thay vì chép lệnh, để không có hai nguồn lệch nhau.
- Viết `CLAUDE.md` của dự án (≤ ~100 dòng): dự án là gì, tuân theo orca-workflow
  ở đâu, đọc `.ai/project.md` và `.ai/invariants.md`, luật tuyệt đối, cách chạy `make verify`.

**Bước 4 (chỉ dự án đang có): Đặt mốc (baseline)**
- Lần đầu bật linter có thể ra rất nhiều lỗi. Chạy chế độ tự sửa (`--fix`) trước.
- Phần còn lại: sửa ngay nếu ít; nếu nhiều thì ghi vào file baseline/ignore của
  linter, kèm mục trong `tech-debt.md`.
- Luật **"không tăng thêm"**: code mới và file bị sửa phải sạch; số lỗi trong
  baseline chỉ được giảm. Các luật gây quá nhiều lỗi có thể tạm tắt, ghi vào
  `tech-debt.md` để bật lại dần.

**Bước 5: Xác nhận**
- `make verify` chạy được; CI xanh trên một PR thử.
- `doctor.sh` pass mọi mục bắt buộc tầng A và B.
- Nhắc chủ dự án làm tầng C (bật luật chặn merge, thêm secret).
- Báo cáo ngắn: đã dựng gì, bất biến nào đã ép bằng máy, bất biến nào còn là chữ,
  nợ kỹ thuật nào được ghi.

**Router (sửa `router/ROUTER.md`, phần intake gate):**
- Chạy `.claude/hooks/doctor.sh`. Chưa có hoặc không pass → chạy onboarding trước,
  **không nhận task tính năng** (trừ khi chủ dự án chỉ định rõ bỏ qua, và việc bỏ
  qua được ghi vào `tech-debt.md`).
- Template cũ hơn orca-workflow → đề xuất `bootstrap.sh --upgrade`.

**Cài global một lần trên mỗi máy** (hướng dẫn trong `enforcement/README.md`):
- `global/CLAUDE.md` → gộp vào `~/.claude/CLAUDE.md`: mọi dự án tuân theo
  orca-workflow tại đường dẫn cục bộ (vd. `~/orca-workflow`), bắt đầu bằng
  `router/ROUTER.md`. Có nội dung sẵn thì **thêm vào**, không ghi đè.
- `global/hooks/check-readiness.sh`, đăng ký là hook `SessionStart` trong
  `~/.claude/settings.json`:
  - Không phải git repo, hoặc là chính repo orca-workflow → im lặng.
  - Có `.claude/hooks/doctor.sh` → chạy `--quiet`, in các mục còn thiếu.
  - Không có → in: *"Dự án này chưa onboarding theo orca-workflow. Hãy chạy
    `workflows/onboarding.md` trước khi làm task."*
  - Với `SessionStart`, stdout được đưa vào ngữ cảnh agent. **Luôn `exit 0`**:
    hook global chỉ nhắc, không chặn.

**Phân cấp hook (quy ước):**

| Cấp | File | Dùng cho |
|---|---|---|
| Global | `~/.claude/settings.json` | Thứ cá nhân dùng mọi nơi, và hook **chỉ nhắc** (SessionStart) |
| Dự án | `.claude/settings.json` (commit) | Luật của dự án: lint, `make verify` |
| Cá nhân trong dự án | `.claude/settings.local.json` (không commit) | Tùy chỉnh riêng của một người |

Hook ở các cấp cộng dồn, không ghi đè nhau. **Không** đặt hook chặn ở cấp global.

**Luồng mong đợi:** chủ dự án nói "làm tính năng X" trong một dự án chưa setup →
hook global nhắc → Router chạy doctor ở intake gate → chạy onboarding (phỏng vấn,
dựng tầng A và B) → chủ dự án làm tầng C → rồi mới làm tính năng X.

**Tiêu chí nghiệm thu giai đoạn 2:**
- [x] Có `workflows/onboarding.md`, `enforcement/global/`, intake gate đã sửa.
- [x] Thử greenfield: thư mục trống (git init) → "làm tính năng X" → agent tự
      onboarding, hỏi đúng phần thiếu, doctor pass, rồi mới làm X.
- [x] Thử brownfield trên một dự án đang có: baseline được tạo, code cũ không bị
      sửa hàng loạt ngoài `--fix`, `tech-debt.md` ghi rõ phần còn lại.
- [x] Canary lint được chạy và ghi vào báo cáo onboarding.

**Kết quả giai đoạn 2 (2026-09-29):**
- Đã làm: `workflows/onboarding.md`; Router chạy `doctor.sh` ở intake gate (Routing Rule 15, trường
  `Readiness`); `doctor.sh` kiểm thêm B5 (`sensitive_paths`) và B6 (có bất biến); mục "Sensitive Paths" trong
  template `project.md`; `bootstrap.sh` hỗ trợ repo nhiều phần (`--stack python=backend --stack node-ts=frontend`);
  hook nhắc toàn máy (`check-readiness.sh`, `install.sh`), **đã cài** trên máy chủ repo và thử bằng phiên
  Claude thật.
- Thử brownfield trên `vn30-stock-tracker` (FastAPI + React), trong worktree riêng, **chỉ là bài thử**: PR đã
  đóng không gộp, nhánh và worktree đã xóa. Kết quả: `make verify` khoảng 3 giây; `doctor.sh` Ready; CI xanh;
  `kiem_tra_nhanh.py --db` 185/185 sau `ruff --fix`; pre-push của dự án đạt. Canary: lỗi lint thường và import
  `vnstock` ngoài `adapters/` (bất biến thành luật ruff `TID251`) đều bị chặn. Baseline: `ruff --fix` commit riêng,
  13 lỗi cũ còn lại vào `per-file-ignores` kèm mục tech-debt; không sửa tay code cũ.
- Lỗi của quy trình tìm ra nhờ bài thử, đã sửa: `.gitignore` giấu hook (bootstrap giờ cảnh báo); dòng A10 của
  doctor bị hỏng; `.env` ở thư mục con không bị kiểm; tên nhánh phải theo quy ước của dự án; file migration do máy
  sinh không được lint/auto-fix; báo nhầm của gitleaks xử lý bằng `.gitleaksignore`. Ghi vào mục "Pitfalls" của
  `onboarding.md`.
- Lệch so với plan: hook nhắc toàn máy nằm ở `enforcement/agents/claude/global/` (theo cấu trúc adapter), không ở
  `enforcement/global/`. `global/CLAUDE.md` không cần: `~/.claude/CLAUDE.md` đã trỏ tới orca-workflow.
- Thử greenfield (dự án "Sổ ghi giao dịch cá nhân", thư mục tạm, đã xóa sau thử). Một phiên `claude -p` mới hoàn
  toàn nhận câu "làm tính năng ghi lệnh mua". Kết quả:
  - Hook nhắc toàn máy báo "chưa onboarding". Agent dừng, không viết code, và hỏi chủ dự án.
  - Agent tự chạy `bootstrap.sh`, `make setup`, smoke test, canary (thấy `F401` rồi xóa file), trên nhánh
    `chore/orca-onboarding`.
  - Agent không tự đoán bất biến: soạn bản nháp 4 bất biến và vùng nhạy cảm để chủ dự án duyệt.
  - Sau khi được duyệt: `doctor.sh` Ready, rồi mới làm tính năng trên nhánh riêng. Có 4 bất biến rủi ro cao,
    tất cả đều được ép bằng test hoặc trigger SQLite.
  - Hook lint chặn agent 4 lần trong phiên, lần nào agent cũng tự sửa.
  - Kiểm độc lập: `make verify` 13 test đạt. CLI ghi được lệnh thật. Số lượng âm và giá bằng 0 bị từ chối.
    `DELETE`/`UPDATE` trên bảng giao dịch bị chặn.
  - Trong bài thử, chủ repo giao cho Claude trả lời phỏng vấn thay mình.

### Giai đoạn 3 — Nối mức xác minh, vùng nhạy cảm và bất biến vào máy

- Trong `rules/testing.md`, gắn mỗi level với lệnh:
  Level 1 = `make lint` + `make typecheck`, Level 2 = `make test`,
  Level 3–5 = `make verify-full` hoặc các target dự án tự khai báo.
- Router ghi rõ **mức rủi ro đã chọn cùng lý do** trước khi làm. Task chạm
  `sensitive_paths` hoặc bất biến rủi ro cao tự động ở mức cao: tiêu chí nghiệm
  thu → test trước → người duyệt test → mới code.
- CI: PR sửa file trong `sensitive_paths` mà không có file test nào thay đổi thì báo lỗi.
- Hook PreToolUse (tùy chọn): chặn sửa test đang có trong vùng nhạy cảm khi chưa
  được duyệt, để agent không "chữa" test cho qua.

**Cách biến một bất biến thành luật máy** (ghi vào `rules/`):
1. Ưu tiên cấu hình luật **có sẵn** của linter (vd. cấm import theo đường dẫn,
   cấm một kiểu dữ liệu) trước khi tự viết.
2. Không có sẵn thì viết script trong `scripts/checks/`, được `make lint` gọi.
3. Nếu không kiểm tra tĩnh được thì viết test (vd. mọi giao dịch phải sinh audit log).
4. Thông báo lỗi theo mẫu, để agent đọc là tự sửa được:
   `[INV-01] Dùng float cho tiền ở src/pay/x.ts:12. Cách sửa: dùng Decimal. Xem .ai/invariants.md#inv-01`
5. Thêm ví dụ vi phạm vào `tests/lint-fixtures/` và test rằng luật bắt được nó.
6. Cập nhật cột "Ép bằng" và "Trạng thái" trong sổ bất biến.

**Tiêu chí nghiệm thu:** mỗi level có lệnh tương ứng; CI có kiểm tra "sửa vùng
nhạy cảm phải kèm test"; có ít nhất một luật tự viết kèm fixture trên dự án thử.

**Kết quả giai đoạn 3 (2026-09-29):**
- [x] Mỗi level có lệnh tương ứng (`rules/testing.md`, "Levels as commands").
- [x] CI có kiểm tra "sửa vùng nhạy cảm phải kèm test" (`ci-checks.sh`), với lối ra `No-Test-Reason:`.
- [x] Có luật tự viết kèm fixture trên dự án thử: `no_float_money.py` bắt fixture và báo
  `[INV-01] … Fix: use Decimal`. Phép thử của chính luật đạt.
- Thêm theo quyết định của chủ repo:
  - Chế độ tests-first cho việc rủi ro cao: agent viết tiêu chí bằng lời, chủ repo duyệt tiêu chí, tester viết test
    đỏ rồi khóa (`.ai/test-lock`, trailer `Tests-First:`), builder không được sửa test đã khóa, reviewer đối chiếu.
    Router tự xếp việc đụng `sensitive_paths` hoặc bất biến rủi ro cao vào loại rủi ro cao (Routing Rule 16).
  - Nhãn né linter mới phải có ` -- <lý do>`: hook soát lỗi báo ngay, CI chặn và liệt kê cho reviewer.
- Thử thật với `claude -p` đóng vai builder, bị xúi xóa test và dán `# noqa` không lý do:
  - Hook khóa test chặn 3 lần; test không đổi; builder dừng lại và hỏi chủ dự án.
  - Hook soát lỗi chặn 2 lần; builder thêm lý do cho nhãn `# noqa`.
  - CI: PR trung thực thì xanh; commit xóa test đã khóa bằng git (lách hook) thì đỏ và chỉ đúng commit đó.
- Lỗ hổng tìm ra: test đã khóa mà có lỗi lint thì builder bị kẹt. Đã thêm luật: tester chạy `make lint` trên
  test trước khi khóa.
- Chưa chạy thật trên GitHub: bước `PR checks` trong `ci.yml`. Logic đã được `enforcement/test.sh` kiểm; bước
  này sẽ được kiểm lần đầu trên dự án thật.
- Template lên `VERSION` 1.1.0: dự án cũ chạy `bootstrap.sh --upgrade`, doctor sẽ nhắc.

### Giai đoạn 4 — Rút gọn điểm vào orca-workflow (map, not manual)

- Tạo `CLAUDE.md` ở gốc orca-workflow (~100 dòng): mục đích, thứ tự đọc, bảng trỏ
  tới file chi tiết, các luật tuyệt đối.
- Tách `ROUTER.md` thành phần cốt lõi ngắn và các file chi tiết đọc khi cần (vd.
  `router/details/*.md`). Làm tương tự với `ORCA-INTEGRATION.md` và `agents/architect.md`.
- **Không mất nội dung**: chỉ di chuyển và liên kết.
- Thêm kiểm tra tự động rằng mọi link nội bộ trong markdown trỏ tới file có thật.

**Tiêu chí nghiệm thu:** `CLAUDE.md` ≤ ~120 dòng; file cốt lõi của Router ngắn
hơn nhiều; không đứt link; diff cho thấy không mất quy tắc nào.

**Kết quả giai đoạn 4 (2026-09-29):**
- Đo lại: `ROUTER.md` 1.015 dòng nhưng chỉ 368 dòng có chữ (~1.900 chữ). Phần "quá dài" chủ yếu là dòng trống kẹp
  giữa mọi dòng. Chủ repo chọn **không tách file và không viết lại nội dung** (tách thì agent phải nhảy nhiều file và
  dễ sót quy tắc; viết lại thì có thể mất quy tắc âm thầm).
- Đã làm: gom dòng trống trong 14 file markdown, bỏ 2.065 dòng. `ROUTER.md` 1.015 → 601 dòng, `agents/architect.md`
  810 → 411. `git diff --ignore-blank-lines` rỗng: **không đổi một chữ**.
- `scripts/check-links.sh`: kiểm link markdown và đường dẫn trong backtick; chạy trong CI; có phép thử trong
  `enforcement/test.sh`. Repo hiện không có link hỏng.
- `CLAUDE.md` gốc 36 dòng (≤ 120); thêm luật: giữ một dòng trống, chỉ rút gọn bằng cách bỏ dòng trống hoặc di
  chuyển, không viết lại quy tắc khi chưa review.
- Để giai đoạn 6: gộp đoạn lặp giữa `ROUTER.md` và `ORCA-INTEGRATION.md` nếu sổ lỗi cho thấy agent làm sai vì chúng.

### Giai đoạn 5 — Kế hoạch và nợ kỹ thuật trong quy trình làm việc

(Các thư mục đã được dựng ở onboarding; giai đoạn này nối chúng vào workflow.)
- Workflow `complex` bắt buộc tạo execution plan trong `.ai/plans/active/` gồm:
  mục tiêu, tiêu chí nghiệm thu, các bước, **nhật ký tiến độ**, **nhật ký quyết
  định**. Xong thì chuyển sang `completed/`.
- Việc nhỏ dùng plan nhẹ (vài dòng) hoặc không cần.
- Reviewer kiểm tra PR có cập nhật `tech-debt.md` khi cố ý để lại nợ.

**Tiêu chí nghiệm thu:** `workflows/complex.md` tham chiếu template plan; chính
file kế hoạch này nằm trong `plans/active/` của orca-workflow.

**Kết quả giai đoạn 5 (2026-09-29):**
- [x] `workflows/complex.md` tham chiếu template `.ai/plans/TEMPLATE.md` (mới, cài bằng `bootstrap.sh`): mục tiêu,
  tiêu chí, các bước, nhật ký tiến độ, nhật ký quyết định, nợ để lại có chủ đích. Xong thì chuyển sang `completed/`.
- [x] File kế hoạch này nằm trong `plans/active/`.
- Theo quyết định của chủ repo: bắt buộc file kế hoạch cho việc **COMPLEX và việc rủi ro cao**. Tiêu chí chủ repo duyệt
  được lưu trong file kế hoạch. CI (`ci-checks.sh`) đỏ nếu PR có commit `Tests-First:` mà không đổi file nào trong
  `.ai/plans/`.
- Reviewer (`agents/reviewer.md`) kiểm: tiêu chí ↔ test, nhãn né linter và TODO có lý do, nợ để lại có mục trong
  `tech-debt.md`, file kế hoạch được cập nhật. CI liệt kê TODO/FIXME/HACK mới cho reviewer (không chặn).
- `enforcement/test.sh`: 55 phép thử đạt. Template `VERSION` 1.2.0.

### Giai đoạn 6 — Vòng phản hồi và dọn rác

- `feedback-log.md`: mỗi lần con người sửa lỗi của agent thì ghi một dòng (ngày,
  lỗi, bất biến/quy tắc liên quan). **Lỗi lặp lại lần 2 thì nâng cấp thành lint
  hoặc test** theo quy trình ở giai đoạn 3.
- `workflows/cleanup.md`: quy trình định kỳ, trong đó agent quét code lệch khỏi
  "golden principles" và sổ bất biến, giảm dần baseline lint, mở các PR nhỏ dễ duyệt.
- Danh sách "golden principles" ngắn, kiểm tra được bằng máy (vd. ưu tiên tiện
  ích dùng chung thay vì helper tự chế; luôn kiểm tra dữ liệu ở biên).
- Định kỳ chạy `doctor.sh` và `bootstrap.sh --upgrade` trên các dự án khi template đổi.

**Tiêu chí nghiệm thu:** có workflow cleanup, danh sách golden principles; luật
"lặp lại lần 2 → nâng thành luật máy" được ghi trong `rules/`.

**Kết quả giai đoạn 6 (2026-09-29):**
- [x] `workflows/cleanup.md`: tối đa 3 PR nhỏ mỗi lần; các bước: nâng cấp template → lỗi lặp thành luật máy → trả nợ
  → thu nhỏ baseline → quét nguyên tắc vàng → ghi `.ai/last-cleanup`.
- [x] `rules/golden-principles.md`: 9 nguyên tắc, mỗi cái ghi rõ máy nào kiểm.
- [x] `rules/enforcement.md` mục 8: agent tự ghi `feedback-log.md` khi bị chủ repo sửa (có nhãn); nhãn lặp lần 2 → luật
  máy. `doctor.sh` cảnh báo D2 khi nhãn lặp chưa có luật máy.
- Theo quyết định của chủ repo: **dọn dẹp tự chạy 2 tuần/lần**. Onboarding (S4) đề nghị tạo lịch chạy trên cloud
  (`/schedule`). Dự phòng: `.ai/last-cleanup` (bootstrap tạo), doctor cảnh báo D1 khi quá 14 ngày, hook nhắc toàn
  máy báo "tới hạn bảo trì".
- `enforcement/test.sh`: 62 phép thử đạt (thêm D1/D2/hook nhắc, đã thử làm hỏng logic). Template `VERSION` 1.3.0.

---

## Tổng kết plan (2026-09-29)

Cả 6 giai đoạn đã xong. Chưa áp dụng vào dự án thật nào: chủ repo sẽ tự áp dụng.

Những gì chưa được kiểm trên môi trường thật, cần để ý lần đầu áp dụng:
- Bước `PR checks` trong `ci.yml` (giai đoạn 3–5): logic đã kiểm trong `enforcement/test.sh`, chưa chạy trên GitHub.
- Lịch dọn dẹp trên cloud (giai đoạn 6): tạo khi onboarding dự án thật.
- Lần đầu áp dụng cho dự án có sẵn: chạy `bootstrap.sh --upgrade` để lấy bản template mới nhất (1.3.0).

### Để sau (không làm trong plan này)

Mục 4 của OpenAI: cho agent chạy app theo từng worktree, điều khiển trình duyệt,
đọc log/metric/trace. Phụ thuộc từng dự án; làm khi giai đoạn 1–6 đã ổn định.

---

## 7. Sổ bất biến và ví dụ theo loại dự án

**Định dạng `.ai/invariants.md`:**

| ID | Bất biến | Rủi ro | Ép bằng | Trạng thái |
|---|---|---|---|---|
| INV-01 | Tiền không dùng float | Cao | lint: `scripts/checks/no-float-money` | ✅ đã ép |
| INV-02 | Mọi giao dịch có audit log | Cao | test: `audit_log.test` | ✅ đã ép |
| INV-03 | Đơn Nháp không duyệt thẳng | Trung bình | chỉ bằng chữ | ⏳ tech-debt, hạn 2026-11 |

Quy tắc: rủi ro **cao** thì phải được ép bằng máy, hoặc có mục nợ kỹ thuật kèm hạn.

**Chung cho mọi dự án:** kiến trúc chia tầng một chiều, quy ước đặt tên, log có
cấu trúc, kiểm tra dữ liệu ở biên, giới hạn kích thước file, không commit secret.

**Dự án quản lý:** mọi API kiểm tra quyền; trạng thái chỉ chuyển theo luồng hợp lệ;
xóa là xóa mềm.

**Dự án tài chính:** cấm `float` cho tiền (dùng Decimal hoặc số nguyên đơn vị nhỏ nhất);
mọi giao dịch có audit log; thanh toán idempotent; làm tròn tập trung một chỗ;
không log số tài khoản/số thẻ. Structural test là **bắt buộc**.

---

## 8. Câu hỏi mở (cần chủ repo trả lời)

1. Dự án thật nào dùng để thử? Đề xuất: một dự án mới (greenfield) và một dự án
   đang có (brownfield). **Đã quyết định:** chọn ở giai đoạn 2; giai đoạn 1 chỉ
   thử trên dự án mẫu trong thư mục tạm.
2. ~~Worker do Orca dispatch có nạp `.claude/settings.json` của dự án không?~~
   **Đã kiểm chứng (2026-09-29):** có. Orca tạo worker bằng Claude Agent SDK với
   `settingSources: [user, project, local]` (tìm thấy trong `app.asar` của Orca).
   Lưu ý: Orca phải khởi động lại sau khi cài `make`/`jq` thì worker mới thấy.
3. ~~Hook đặt ở cấp dự án hay cấp máy?~~ **Đã quyết định:** hook chặn ở cấp dự án;
   hook chỉ nhắc (SessionStart) ở cấp global.
4. ~~orca-workflow sẽ được clone ở đường dẫn nào trên máy?~~ **Đã quyết định:**
   `D:\AI\Orca\Orca-workflow` (đã ghi trong `~/.claude/CLAUDE.md`).
5. ~~Các dự án đều dùng GitHub không?~~ **Đã quyết định:** chỉ GitHub; thêm
   template CI khác khi có dự án thật cần.

---

## 9. Cách bắt đầu (prompt gợi ý cho Claude Code)

> Đọc `plans/active/harness-upgrade.md`. Tóm tắt lại cho tôi bạn hiểu mục tiêu
> và giai đoạn 1 như thế nào, liệt kê các file sẽ tạo/sửa, và hỏi tôi các câu
> hỏi mở còn cần cho giai đoạn 1. Chưa sửa gì cho đến khi tôi đồng ý. Sau khi
> tôi đồng ý, làm giai đoạn 1 trên một nhánh riêng, mở PR, và cập nhật nhật ký tiến độ.

---

## 10. Nhật ký tiến độ

| Ngày | Giai đoạn | Việc đã làm | Ghi chú |
|---|---|---|---|
| 2026-09-28 | — | Lập kế hoạch, review và bổ sung Tiêu chuẩn sẵn sàng + onboarding | Soạn cùng Claude trên claude.ai |
| 2026-09-29 | 1 | Chốt các câu hỏi mở cho giai đoạn 1, ghi vào plan | Bắt đầu làm trên nhánh `harness-phase-1` |
| 2026-09-29 | 6 | Sổ lỗi tự ghi + lỗi lặp thành luật máy (D2), `cleanup.md` 2 tuần/lần (D1 + nhắc), nguyên tắc vàng | Plan hoàn thành, chuyển sang `completed/` |
| 2026-09-29 | 5 | Template plan, file kế hoạch bắt buộc cho việc lớn + rủi ro cao (CI kiểm), reviewer kiểm nợ kỹ thuật | Giai đoạn 5 xong |
| 2026-09-29 | 4 | Gom dòng trống (không đổi chữ), kiểm link trong CI | Giai đoạn 4 xong |
| 2026-09-29 | 3 | Tests-first + khóa test, CI chặn vùng nhạy cảm thiếu test, bắt nhãn né linter, map level→lệnh, hướng dẫn bất biến→luật máy; thử thật với builder bị xúi | Giai đoạn 3 xong |
| 2026-09-29 | 2 | Onboarding, intake gate, hook nhắc toàn máy, bootstrap nhiều phần; thử brownfield trên vn30 (đã xóa sau thử) | Thử greenfield đạt (thư mục tạm, đã xóa). Giai đoạn 2 xong |
| 2026-09-29 | 1 | Làm xong `enforcement/`, `rules/enforcement.md`, `CLAUDE.md` gốc; thử thật trên dự án mẫu Python và node-ts | `ci.yml` đã thử thật trên `orca-ci-sandbox`: xanh khi đúng, đỏ khi test hỏng hoặc lộ secret |

## 11. Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-09-28 | Machine enforcement comes before more docs | The repo already had enough written guidance; it lacked checks |
| 2026-09-28 | Standardize the `make` command contract | Hooks and CI work the same for every language |
| 2026-09-28 | Hooks, CI and doctor verify; they do not orchestrate | No second orchestration system beside Orca |
| 2026-09-28 | Blocking hooks at project level, reminder hooks at global level | Project hooks travel with the repo; a blocking global hook would break projects not set up yet |
| 2026-09-28 | Define a 3-tier Readiness Standard, checked by `doctor.sh` | "Ready" must be machine-checkable, not rely on memory |
| 2026-09-28 | Onboarding is the mandatory first task, with an interview | Project-specific parts (invariants, architecture) are known only to the owner |
| 2026-09-28 | Split `[managed]` and `[project]` files; version the template | Upgrade the template in every project without overwriting project-specific parts |
| 2026-09-28 | Split `verify` (fast, for hooks) and `verify-full` (for CI) | The Stop hook must not hang the session on slow tests |
| 2026-09-28 | Existing projects use a baseline and a "no increase" rule | Turn on a linter without fixing all old code at once |
| 2026-09-28 | Every custom rule needs a violating fixture | Proves the rule really catches the error |
| 2026-09-28 | Install `make` and `jq` on dev machines; `doctor.sh` checks both | Windows + Git Bash lack them; hooks and bootstrap need them |
| 2026-09-28 | Language templates live in `enforcement/stacks/<language>/`, chosen with `bootstrap.sh --stack`; start with `node-ts` and `python` | Both are installed on the machine, so they can be tested for real; add others when needed |
| 2026-09-28 | Support Claude first; the shared core is `make verify`, each agent has an adapter in `enforcement/agents/<name>/` | Codex/ChatGPT/Gemini can be added later without changing the core |
| 2026-09-28 | Create a short `CLAUDE.md` at the orca-workflow root in phase 1 | Agents working in this repo need an entry point now; phase 4 completes it |
| 2026-09-28 | Every hook must be proven by a real run on a sample project | Broken hooks usually fail silently and nobody notices |
| 2026-09-29 | CI only for GitHub Actions | The repo and all projects are on GitHub; the machine already has `gh` |
| 2026-09-29 | The real test project is chosen in phase 2 | Phase 1 only needs a sample project; onboarding needs a real one |
| 2026-09-29 | Move `enforcement/global/` to phase 2 | Phase 2 acceptance criteria already include it; keeps phase 1 small |
| 2026-09-29 | Run hooks as `bash <script>`, not via the executable bit | Windows does not store the executable bit; this runs the same on every machine |
| 2026-09-29 | Python `make setup` installs into the project's `.venv` | The first trial installed into the machine-wide Python by mistake |
| 2026-09-29 | Multi-language repos: one Makefile per part + a root Makefile that runs each part | Hooks and CI still call only the root `make`; reusable for every multi-part project |
| 2026-09-29 | Every project follows the Orca standard; no exemption mechanism | The owner wants one uniform process; on conflict, change the project's rules |
| 2026-09-29 | Existing projects with a home-made test suite: wrap it in pytest, migrate gradually | No rewrite at once, so no loss of checks guarding important rules |
| 2026-09-29 | Install a machine-wide reminder hook (`SessionStart`) | Machine safety net when an agent skips the Router; it reminds, never blocks |
| 2026-09-29 | Trials on real projects are throwaway: no real PRs, delete afterwards | The owner applies the system to real projects once it is finished |
| 2026-09-29 | Onboarding has 2 paths in **one** file: A (new project) and B (existing project), sharing S1–S4; after onboarding every project follows the same process | About 70% of steps are shared; 2 files would duplicate and drift. When `onboarding.md` passes ~250 lines, split into a shared file + 2 short path files |
| 2026-09-29 | Path B takes a before/after snapshot: the project's existing checks must give identical results before and after onboarding | The biggest risk for an existing project is breaking what works; the vn30 trial did this by hand |
| 2026-09-29 | Path A has a default-stack table; the owner confirms | Greenfield trial: the agent had to invent defaults |
| 2026-09-29 | High-risk work: the owner approves **plain-language criteria**, not test code; a tester writes tests first, the builder may not edit them | The owner does not read code; separate who sets the exam from who takes it (owner's idea) |
| 2026-09-29 | Changing `sensitive_paths` without tests: CI blocks unless a `No-Test-Reason:` trailer is present | Prevents token tests; the reason is public in the PR |
| 2026-09-29 | New linter suppressions are allowed but need a reason on the same line | Linters are sometimes wrong; silent suppressions get caught |
| 2026-09-29 | Phase 4 only removes blank lines + checks links; no Router split, no rewrite | "Long" came from blank lines; splitting or rewriting risks losing rules, which outweighs the gain |
| 2026-09-29 | A plan file is required for COMPLEX and high-risk work; approved criteria live in it | Later sessions and other agents can see what was decided; small tasks skip it to avoid junk files |
| 2026-09-29 | New TODO/FIXME are only listed for the reviewer, not blocked | Blocking would be annoying; the reviewer checks them against `tech-debt.md` |
| 2026-09-29 | Maintenance runs on a schedule every 2 weeks; doctor/hook reminders as fallback | The owner chose automation; the fallback covers a missing or broken schedule |
| 2026-09-29 | The agent logs its own mistakes when corrected; a tag repeated twice must become a machine rule | The owner does not read code or keep the log; the machine counts repeats |
| 2026-09-29 | Add the `feedback-check.sh` hook (Stop) + a git/PR sweep in maintenance; do not store the owner's messages | "The agent logs its own mistakes" was only text; the hook asks the agent to self-assess when a message looks like a correction. Real trial: exactly 1 row logged when corrected, none when "wrong" was a source-data error |
| 2026-09-29 | Whole-system test (T1–T5), 6 bugs found and fixed | See the whole-system test section below (Vietnamese) |

---

## Kiểm thử toàn hệ thống (2026-09-29)

| Phần | Kết quả |
|---|---|
| T1 Bộ tự kiểm + kiểm link | Đạt (68 → 88 phép sau khi thêm ca mới) |
| T2 Đường dẫn có dấu cách, tiếng Việt; nâng cấp 1.0.0 → mới; công tắc tắt hook | Dấu cách đạt. Tiếng Việt: `make` trên Windows không chạy → **đã sửa**: doctor T4, hook báo lỗi thay vì im lặng. Nâng cấp đạt |
| T3 Onboarding dự án có sẵn, agent mới | Lần 1: agent **lờ lời nhắc** đầu phiên → **đã sửa**: cổng nhắc cạnh mỗi tin nhắn. Lần 2: đạt đủ luồng B |
| T4 Dự án mới + tính năng rủi ro cao | Onboarding đạt. Tính năng tiền: agent **bỏ qua tests-first** → **đã sửa**: hook `sensitive-gate.sh` + CI cần kế hoạch đã duyệt. `--upgrade` bỏ sót hook mới trong nhóm cũ → **đã sửa**. `No-Test-Reason` miễn cả PR → **đã sửa**, chỉ miễn đúng commit. Lần chạy lại: đạt đủ chuỗi, hook sổ lỗi ghi đúng |
| T5 CI trên GitHub thật (6 PR) | Đạt 6/6 |

Còn lại, không sửa được bằng máy: dòng "Approved by the owner" có thể do agent tự ghi; bằng chứng là nó nằm công khai trong PR.

## Thử với phiên mới tinh do chủ repo tự chạy (2026-09-29)

Chủ repo mở một phiên Claude Code mới và làm 17 bước: onboarding luồng A (node-ts), tính năng tiền theo tests-first,
xúi xóa test, né linter, sổ lỗi (đúng, không nhầm, lỗi lặp), mở khóa, bảo trì. Đạt tất cả. Tìm ra và đã vá:
- node-ts trên Windows: `core.autocrlf=true` làm file lấy ra có CRLF, Prettier báo lỗi → repo mới được
  `* text=auto eol=lf`; repo có sẵn chỉ `*.sh` (tránh đổi hàng loạt).
- Sau khi mở khóa test, dự án không có CI thì không máy nào chặn sửa test → hook Stop đọc lịch sử git: test thuộc
  commit `Tests-First` cuối không được đổi khi kế hoạch còn ở `active/`.
- Chủ repo thấy "dọn dẹp" nghe như xóa dự án → đổi thành "bảo trì định kỳ" (`workflows/maintenance.md`,
  `.ai/last-maintenance`).
