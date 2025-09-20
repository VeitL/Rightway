# agents.md — Rightway 仓库内协作与自动化代理规范

> 目的：让人类开发者与代码代理（如 Cursor/Copilot/Claude/Copilot‑Workspace 等）在同一套“规则与循环”下高效协作，保证**每次代码修改**都能被**可重复构建**且**文档同步更新**。

---

## 0. 仓库默认结构（建议）
```
Rightway/
├─ Rightway.xcworkspace
├─ RightwayApp/                # iOS App（SwiftUI）
├─ RightwayAppTests/           # 单元/界面测试
├─ Scripts/                    # 自动化脚本（可选）
├─ Docs/
│  ├─ requirements.md          # 需求文档（Requirements Document）
│  └─ todo.md                  # 待办/进行中（To‑Do / Progress）
└─ Fastfile / Makefile         # 可选的自动化入口
```

> 路径若不同，请在“本地定制”小节覆盖声明。

---

## 1) **权威构建命令（必须遵循）**
每次修改代码后必须执行以下构建命令（iOS 模拟器：iPhone 16 / iOS 18.5）：

```bash
xcodebuild -workspace Rightway.xcworkspace -scheme RightwayApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' build
```

- 构建成功（ExitCode=0）视为“可集成”；构建失败则**不得**提交或合并。  
- 代理在重构/批量替换后，必须以此命令做**回归构建**。

---

## 2) 日常循环（Loop）——**修改 → 构建 → 文档同步**
**任何**代码修改完成后：

1. **Build**：运行上面的权威构建命令；  
2. **若无错误**（构建成功）：  
   - 更新 `Rightway_Development_Guide.md`（需求文档）：同步新增/修改/删除的功能点、接口、模型、屏幕；  
   - 更新 `TODO.md`（待办/进度）：将完成项移至 “Done”，新发现的事项进入 “Inbox/Backlog”；  
3. **若有错误**：**不得**改动文档；先修复构建错误，再回到第 1 步。

> 这条规则对 **人类与代理**一视同仁。任何自动 PR 在 CI 里必须重跑该构建命令。

---

## 3) Pull Request（PR）守则
**每个 PR 必须满足下列清单**：

- [ ] 本地已运行权威构建命令，**成功**；  
- [ ] 构建成功后，已更新 `Rightway_Development_Guide.md` 与 `TODO.md`；  
- [ ] 变更描述明确（动机/范围/影响面）；  
- [ ] 命名/可读性/可维护性达标（避免魔法数/重复代码）。

**Commit 格式**（建议 Conventional Commits）：
```
feat: add spaced‑repetition engine v1
fix: resolve crash when loading traffic signs svg
docs: update requirements and todo after build success
chore: bump deployment target to iOS 18.5
```

---

## 4) 对“代码代理”的特别要求
- **只修改**与任务相关的目录（`RightwayApp`, `RightwayAppTests`），**勿**擅自移动/删除 workspace、签名配置等关键文件；  
- **任何重构**后必须立刻运行权威构建命令；  
- 构建成功后，**自动补记**到 `Docs/requirements.md` 与 `Docs/todo.md`（以 Markdown 列表或表格形式记录变更）；  
- 不得引入未使用依赖；不在 PR 中混入无关重命名。

---

## 5) 文档维护规范
**Docs/requirements.md（需求文档）**：
- 建议结构：`目标 / 用户 / 核心流程 / 功能清单 / 数据模型 / 非目标 / 风险与依赖 / 里程碑`；  
- 当实现发生变化（新增 API 字段、视图状态、约束等），**紧随构建成功**后更新。

**Docs/todo.md（代办/进度）**：
- 建议列：`ID | 模块 | 描述 | 优先级 | 状态 | 负责人 | 预估 | 实际 | 备注`；  
- 状态流转：`Inbox → To‑Do → In‑Progress → Review → Done`；  
- PR 合并时，将对应条目标记 **Done** 并追加 commit 哈希。

> 最佳实践：把两份文档视为“**单一事实来源（SSoT）**”。任何合并进主干的功能，文档都要能追溯。

---

## 6) 可选自动化（推荐）
- **Makefile**：
  ```Makefile
  build-sim:
		xcodebuild -workspace Rightway.xcworkspace -scheme RightwayApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' build

  ci: build-sim
		@echo "✅ Build OK. Remember to update Docs/requirements.md and Docs/todo.md."
  ```
- **Git Hook**：在 `pre-push` 中调用 `make build-sim`，失败即阻止推送；  
- **CI**：GitHub Actions / GitLab CI 复用同一构建命令，作为集成 Gate。

---

## 7) 失败与回滚
- 构建失败或引入回归：**立即回退**该修改（或热修复），并在 `Docs/todo.md` 增加“回归缺陷”记录；  
- 回滚后重走“修改 → 构建 → 文档同步”流程。

---

## 8) 本地定制（可覆盖）
- 若你的模拟器目标或 scheme 不同，请在此处注明并全员对齐：  
  - `-scheme`：RightwayApp（若变更请写明）；  
  - `-destination`：`iPhone 16 / iOS 18.5`（若无此 Runtime，请在 Xcode 安装或统一替代目标）。

> **无论定制如何，必须遵守**：**修改 → 构建 →（成功）文档同步** 的闭环。
