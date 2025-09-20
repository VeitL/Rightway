德国驾照理论练习 App （Rightway）—完整开发文档
一、产品需求文档（PRD）
1. 背景与机会
- 德国理论考试官方支持德/12种外语，不含中文。
- 市面产品无中文学习层，本项目差异化：官方题库+中文解释+笔记+路标百科+多端同步。
2. 竞品研究（精要）
- Fahren Lernen：功能全，但强绑定驾校，无中文。
- Theorie24：多语支持，但无中文，统计浅。
- FahrschulApp：驾校导向，统计一般。
- WINDRIVE / iTheorie / ADAC App：无中文，功能差异化有限。
3. 合规与内容来源
	•	官方题库授权
	•	德国理论题库由 TÜV|DEKRA arge tp 21 维护。商用 App 必须获得其模块化授权（含题干/外语文本、静/动态图、路标图等），并遵守更新节奏与展示规范。fahrerlaubnis.tuev-dekra.de+1
	•	考试语言声明
	•	中文不是考试官方语言。考试模拟模式仅允许切换德语/官方外语；学习模式可叠加中文解释层，以免误导考生。ADAC
	•	路标素材版权
	•	StVO 法规文本与其官方图示属于“** amtliche Werke **”（UrhG §5），不受著作权保护；但不得直接搬运第三方绘制图像。建议依据 StVO/VwV-StVO/VzKat 自绘矢量 SVG（含编号/名称/要点），并注明依据来源。Gesetze im Internet+2Gesetze im Internet+2
	•	更新机制（2025 现状）
	•	2025-04 有题库更新并引入新题型；2025-10 官方宣布不更新（OFSA 2 过渡）。需在后端维护题库版本号与差分同步。tuev-verband.de+1

4. 目标用户 & 关键使用场景
	•	用户画像
	•	在德华语用户（中国大陆/港澳台/新马等背景），德语 B1–C1；多数能读英文；希望通过中文解释理解考点与陷阱。
	•	核心场景
	•	通勤碎片化刷题 → 先中文解释吃透逻辑，再用德/英原文做模拟；
	•	考前冲刺 → 错题回放、易错专题、题干“关键字高亮”、路标对照速查；
	•	课堂配合 → iPad 与 Web 大屏展示路标讲解与录像；
	•	记录复盘 → 每题可加个人笔记、插图/链接；生成学习报告给教练或自查。

5. 产品范围（MVP → v1.0）
5.1 学习与考试模块
	•	学习模式（带中文层）
	•	题干默认显示：德语或英语原文（与官方一致）+ 可展开中文解释（逐句对照、术语气泡、错因提示）。
	•	术语表：如 Vorfahrt, Vorschriftszeichen 等，提供中德英三语词条与例句。
	•	视频/动态图题：官方视频以授权素材播放；中文解释覆盖场景要点+判分逻辑。
	•	模拟考试模式
	•	严格遵循官方考试界面/布局/计时/计分，不显示中文层；支持 12 种外语选择与德语音频读题（若授权覆盖）。fahrerlaubnis.tuev-dekra.de
	•	错题&收藏&标注
	•	每题可添加私有笔记，支持 Markdown/图片；错题自动归档；一键生成“我的盲区”专题训练。
	•	学习策略
	•	间隔重复（SRS，近似 SM-2）：基于做题信心/对错/时长的 E-Factor 与间隔调整；弱项题优先复现；支持“今日计划/已完成/剩余时间”仪表盘。
5.2 路标百科（VzKat 对应）
	•	全量路标按 StVO/VzKat 编目：编号、类目、法条要点、常见混淆点、考试高频关联题链接；
	•	对比视图：例如 205 “Vorfahrt gewähren” vs 206 “Halt! Vorfahrt gewähren” vs 301 “Vorfahrtstraße”；
	•	搜索/过滤：按编号、中文/德语关键词、功能类目（警告/指示/附加牌）筛选；
	•	自绘 SVG + 暗色模式适配，注记关键视觉差异。Gesetze im Internet+1
5.3 学习数据与报表
	•	题层级指标：正确率、平均作答时长、首次/复练通过率、遗忘概率（SRS 推断）；
	•	章节/考点层级：法规主题、路标子类、视频题类型等维度雷达图与热力图；
	•	考试预测：结合“近 7 天正确率 × 题型权重 × 变体覆盖率”输出通过概率区间；
	•	导出 PDF/CSV 报告，分享给教练或打印。
5.4 同步与多平台
	•	平台：iOS & iPadOS（Xcode/SwiftUI）、Web（Next.js/React）；
	•	账号体系：Apple 登录 + 邮箱密码（可选 Google），后续可加微信登录（Web 端）；
	•	云同步：题进度、SRS 队列、笔记、标注、设置实时同步；离线可用，上线即后台补写。

6. 非功能需求
	•	性能：刷题页面 <200ms 首次交互就绪；题组切换 <500ms；视频题缓冲 <1s（命中缓存）。
	•	可靠性：99.9% 月可用性；断网可离线答题并队列同步。
	•	隐私/GDPR：最小化采集；笔记默认仅本用户可见；数据加密（At-Rest + In-Transit）；可一键导出与删除账号。
	•	无障碍：VoiceOver、动态字体；色盲安全调色；键盘可操作（Web）。
	•	本地化：中/德/英 UI 文案与术语库统一管理，采用专业术语表与审校流程。

7. 技术方案（建议）
7.1 客户端
	•	iOS / iPadOS：Swift 5.9+ / SwiftUI + Combine；本地缓存 Core Data（或 SQLite/GRDB）；BackgroundTasks 处理离线同步与增量更新；
	•	UI 架构：MVVM + Feature Modules（Learning, Exam, Signs, Notes, Analytics）；
	•	Web：Next.js + React + TypeScript；SSR/ISR 提升文库与百科 SEO。
7.2 后端与数据
	•	后端：Supabase（PostgreSQL + Row Level Security + Realtime）或 Firebase（Firestore + Auth）；
	•	同步：每条记录携带 updated_at 与 device_write_id 进行冲突合并（LWW + 笔记字段级 merge）；
	•	题库模型（核心表）
	•	questions（官方 question_id、class、points、media_refs、valid_from、valid_to、version_tag）；
	•	question_texts（lang=de/en 官方文本；cn_text=我们自有解释/译注）；
	•	variants（图/视频变体与元数据）；
	•	signs（VzKat 编码、SVG、释义、多语言名称、法条链接）；
	•	user_progress（per user per question：last_seen、streak、ease、interval、next_due、correct_count、avg_time_ms）；
	•	user_notes（富文本/图片、标签、私密/共享开关）；
	•	exams（模拟场次、成绩、错题清单快照、时长）。
	•	题库更新链路
	•	引入 “题库版本”（例如 2025-04, 2025-10）；服务端维护 delta；客户端按 ETag/If-None-Match 拉取差分；
	•	OFSA/题库公告监听任务，自动生成“更新说明”；（2025-10 为无更新）。vogel-system.de

8. 中文学习层（差异化设计）
	•	逐句对照：原文（德/英）逐句标注关键词（如 Rückwärtsfahren, Fußgängerüberweg）并附中文注释与典型错因；
	•	“陷阱高亮”：对常见误选项添加“为什么错”；
	•	术语库：中-德-英三向词条 + 例句 + 路标/法规引用；
	•	读题：德语 TTS（授权/系统语音），中文讲解音轨为自制；
	•	学习任务：每日 15–20 分钟 SRS 队列 + 高频错题专项；
	•	误用防护：考试模拟不显示中文，并提示“德/英原文为准，中文为学习辅助”。

9. 路标百科（内容规范）
	•	数据来源：StVO 法条/Anlage 1、2、VwV-StVO、VzKat 官方结构；我们自行绘制符号化 SVG 并保留 VzKat 编号与名称；在条目页附官方条文链接。Gesetze im Internet+2Gesetze im Internet+2
	•	版权合规：依据 UrhG §5（amtliche Werke） 原理，避免引用第三方受版权保护图像。Gesetze im Internet

10. 商业模式与定价（建议）
	•	Freemium：
	•	免费：每日限量练题、路标百科基础版、基础统计；
	•	Pro（建议 12.99–19.99€ / 90 天）：全题库、无限模拟、SRS、深度统计、错题/笔记、导出、iCloud/云备份；
	•	中文学习包：随 Pro 免费或作独立内购（例如 4.99–9.99€）。
	•	参考：Theorie24 GOLD 常见 9.99€；Fahren Lernen 多通过驾校售卖，单人成本常见 ~50–80€。Die Führerschein App | THEORIE24+2cheapcharts.com+2

11. 里程碑（建议）
	•	M0（法律/授权）：签订 arge tp 21 授权、明确可用模块（题干/翻译/媒体/布局）。fahrerlaubnis.tuev-dekra.de
	•	M1（8 周）：iOS/iPadOS MVP（学习模式 + 路标百科 + 基础同步 + SRS v1）；
	•	M2（+6 周）：模拟考试模式（官方布局/计分）、错题与笔记、学习报告导出；
	•	M3（+4 周）：Web Beta、团队/教练分享、可选组织账号；
	•	M4（持续）：题库版本更新自动化、A/B 学习策略、AI 讲解增强。

12. 风险与对策
	•	题库授权风险：未获授权前不得使用/仿制题干与图片；先上线“路标百科 + 学习方法 + 法规精讲”作为冷启动。fahrerlaubnis.tuev-dekra.de
	•	误导风险：中文为学习层，考试层仅官方语言；显眼提示与模式隔离。ADAC
	•	更新滞后：建立“版本号 + 差分”机制，监控 4/10 月变更（2025-10 为无更新的特例）。vogel-system.de

13. 关键体验验收标准（摘选）
	•	学习页
	•	Given 已登录用户，When 打开题目，Then 500ms 内展示德/英原文与“展开中文解释”按钮；支持一键术语高亮。
	•	模拟考试
	•	Given 开始考试，When 进入题目，Then 界面布局/流程与官方示例一致（语言=德/官方外语，计分/计时正确）。fahrerlaubnis.tuev-dekra.de
	•	SRS 队列
	•	Given 完成每日任务，When 次日进入，Then 队列自动生成新旧混合 30–50 题，弱项提权≥30%。
	•	同步
	•	Given 离线答题 100 题，When 网络恢复，Then 60s 内完成进度/笔记一致化，无丢失/重复。
	•	路标对比
	•	Given 搜索“Vorfahrt”，When 选择 205/206/301，Then 展示三者图标、适用规则与“典型考点差异”。

14. 与 Codex（或任何 Copilot）协作建议
	•	Xcode 项目脚手架（建议要点）
	•	Modules/：Learning, Exam, Signs, Notes, Analytics, Auth, Sync
	•	Core/：Models（SwiftData/Core Data）、Services（API、SRS）、Theme、Localization
	•	Feature Flags：ENABLE_CN_LAYER, EXAM_OFFICIAL_MODE
	•	第一批任务（可直接给 Codex 的 Prompt 纲要）
	•	使用 SwiftUI 创建三分栏学习界面（题干/中文解释/术语侧栏）；
	•	定义 QuestionProgress 模型（SRS 字段：ease, interval, repetitions, lastAnswerCorrect, nextDue）；
	•	建立 SignsView：支持编号/关键词搜索 + 两列对比；
	•	接入 Supabase：Auth + Realtime + Row Level Security（以 user_id 隔离）；
	•	实现离线缓存与冲突合并（LWW + 富文本笔记字段级合并）。

15. 隐私与合规清单（上线必过）
	•	✅ arge tp 21 商用授权（覆盖题干、翻译、媒体、UI 规范）并保留审计记录。fahrerlaubnis.tuev-dekra.de
	•	✅ App Store 隐私清单（数据收集用途最小化）
	•	✅ GDPR：数据导出、删除、处理协议（DPA）
	•	✅ 法规来源与路标 SVG 自绘说明（UrhG §5 依据）Gesetze im Internet

16. KPI（首季度）
	•	学习留存（D7 ≥ 35%）；
	•	模拟考试完成率（人均 ≥ 5 场）；
	•	错题转化（被纠正题目 7 天内复练通过率 ≥ 70%）；
	•	词汇掌握（术语测验正确率 ≥ 80%）；
	•	退款率 < 2%。
二、Sprint 1 Starter Kit 摘要
0. 技术栈与约束
	•	iOS/iPadOS：Xcode 16 / Swift 5.9+ / SwiftUI + Combine / BackgroundTasks / SwiftData 或 Core Data（本文以 Core Data 为例）。
	•	Web（后续）：Next.js 14 + React + TypeScript。
	•	后端：Supabase（PostgreSQL + RLS + Realtime + Storage）。
	•	多语言：中/德/英，UI 与内容分层；官方考试语言仍以德语/12 外语为准，中文为学习层。
	•	Xcode 项目结构（建议）
Rightway (workspace)
└─ RightwayApp (iOS/iPadOS)
├─ App/
│ ├─ FSEduApp.swift // @main
│ ├─ AppRouter.swift // 路由/Tab 配置
│ └─ FeatureFlags.swift // ENABLE_CN_LAYER, EXAM_OFFICIAL_MODE
├─ Core/
│ ├─ Models/ // 纯模型（Swift）
│ │ ├─ Question.swift
│ │ ├─ Sign.swift
│ │ ├─ SRS.swift
│ │ └─ UserProgress.swift
│ ├─ Services/
│ │ ├─ APIClient.swift // Supabase/REST/RPC 网关
│ │ ├─ SyncService.swift // 增量同步 + 冲突合并
│ │ ├─ MediaCache.swift // 图片/视频缓存
│ │ └─ AuthService.swift // Apple/邮箱登录
│ ├─ Persistence/
│ │ ├─ CoreDataStack.swift
│ │ └─ Entities.xcdatamodeld // 本地缓存实体
│ └─ Localization/
│ ├─ Strings.zh-Hans.json
│ ├─ Strings.de.json
│ └─ Strings.en.json
├─ Modules/
│ ├─ Learning/ // 学习模式（中文解释层）
│ │ ├─ Views/
│ │ │ ├─ LearnHomeView.swift
│ │ │ ├─ QuestionCardView.swift
│ │ │ └─ TermPopoverView.swift
│ │ └─ ViewModels/
│ │ └─ LearningViewModel.swift
│ ├─ Exam/ // 模拟考试（仅德/12外语）
│ │ ├─ Views/
│ │ │ ├─ ExamHomeView.swift
│ │ │ └─ ExamSheetView.swift
│ │ └─ ViewModels/
│ │ └─ ExamViewModel.swift
│ ├─ Signs/ // 路标百科（自绘 SVG）
│ │ ├─ Views/
│ │ │ ├─ SignsHomeView.swift
│ │ │ ├─ SignDetailView.swift
│ │ │ └─ SignCompareView.swift
│ │ └─ ViewModels/
│ │ └─ SignsViewModel.swift
│ ├─ Notes/
│ │ ├─ Views/NotesView.swift
│ │ └─ ViewModels/NotesViewModel.swift
│ └─ Analytics/
│ ├─ Views/AnalyticsDashboardView.swift
│ └─ ViewModels/AnalyticsViewModel.swift
├─ Resources/
│ ├─ Assets.xcassets
│ ├─ SVG/
│ │ ├─ 205_Vorfahrt_gewaehren.svg
│ │ ├─ 206_Halt_Vorfahrt.svg
│ │ └─ 301_Vorfahrtstrasse.svg
│ └─ Fonts/
└─ Tests/
├─ Unit/
└─ UI/
2) SwiftPM 依赖（Package.swift 片段）
	•	supabase-swift（或直接 REST/RPC）：Supabase 客户端。
	•	SDWebImageSwiftUI（可选）：图像加载与缓存。
	•	SwiftSVG（或自绘 Path）：渲染自绘 SVG 路标。
	•	MarkdownUI：题目笔记的 Markdown 渲染。
生产中如需最小依赖，可移除第三方 SVG，改用 SF Symbols + 自绘 Path。
3) 同步策略（增量与冲突合并）
	•	客户端保存 updated_at 与 device_write_id；以 LWW（Last-Write-Wins）为默认冲突策略，笔记字段支持“段落级合并”。
	•	首次启动拉取：/delta?since=etag。成功后写入新 etag。
	•	离线队列：Core Data PendingOp 表（insert/update/delete），网络恢复后批量提交。
4) QA 验收用例（Sprint 1）
	•	学习页 500ms 内出现；中文层可显隐；选项点击给出反馈。
	•	路标百科按编号/关键词检索；205/206/301 可在 Compare 视图并排对比。
	•	断网答题 20 题，恢复后 60s 内进度与笔记一致。
5) 法务与合规落地（开发期必须落实）
	•	与 TÜV|DEKRA arge tp 21 签订题库授权（题干/媒体/外语文本/UI 规范）。
	•	中文解释明确为“学习层”，模拟考试严格使用官方语言与计分 UI。
	•	路标图形均为自绘 SVG，并在百科页脚注明依据 StVO/VwV-StVO/VzKat。



德国驾照理论练习 App （Rightway）—开发文档补充
=============================================

练车记录模块扩展
------------------
- 练车计时器：用户到驾校点击“开始计时”后，App 自动启动计时、路由采样与录音。
- 定位追踪：接入 CoreLocation，定期记录经纬度路由点并写入 DrivingSessionStore。
- 语音录制：使用 AVAudioRecorder（iOS）在练车期间录音，生成 M4A 文件并附加到练车笔记。
- 练车报告：结束练车后自动生成练车记录（日期、时长、金额、路线点等），并自动标记第 N 次练车。
- 行驶里程：根据 routeSamples 计算总距离，并在报告/历史卡片中展示，以便回顾练习强度。
- 练车笔记：支持文字、图片、画板（占位）与音频附件，写入 NoteCategory.practice，出现在“练车笔记”分类。
- 地图回放：DrivingSessionDetailView 中的地图支持展示所有轨迹点，以及以波形图标标注的音频锚点；点击锚点或列表项，可弹出带进度条/拖拽控制的音频播放器。
- 音频锚点：录音开始时间与轨迹时间对齐，按 30s 采样生成 audioWaypoints（timestamp + timeOffset + 坐标），为后续语音转写与文字标注预留数据结构。
- 媒体持久化：录音/图片在生成报告时迁移至 Documents/PracticeMedia 下，保证历史报告可回放；NoteAttachment 保留持久化 URL。
- 待办：集成语音转文字服务（Speech.framework 或云转写），将 transcript 绑定到 audioWaypoints 后在地图上联动展示。

权限与安全
-----------
- Info.plist 新增：
  - NSLocationWhenInUseUsageDescription：允许记录练车路线。
  - NSMicrophoneUsageDescription：用于记录练车期间的语音。
- iOS 首次使用定位或录音时会弹出权限对话框；未授权时开关会自动关闭。

模块联动
--------
- DrivingSessionStore 管理练车会话（计时、路线采样、录音文件）。
- DrivingSessionStore 还负责记录音频开始时间与 audioWaypoints（时间偏移 + 坐标），供地图与未来的语音转写使用。
- DrivingPracticeViewModel 根据权限控制录音/定位，并在结束时生成练车笔记与媒体持久化。
- Notes 模块按“习题笔记”“练车笔记”分类；练车笔记可显示附件图标（图片、画板、音频）。

后续增强建议
------------
- 使用 CoreLocation 背景定位/路线回放。
- 将画板占位替换为真实 Canvas，并持久化手写内容。
- 语音转写：结合苹果 Speech 或第三方云服务，将音频拆分为可搜索文本，并与音频锚点同步显示在地图/时间轴。

学习模块增强
-----------
- 题目支持收藏/取消收藏，自动加入“盲区”列表，便于针对错误题快速复习。
- 新增“题目笔记”弹窗，可插入文字与附件（iOS 支持图片上传），笔记写入 `NoteCategory.study`。
- 学习页入口增加“术语表”按钮，跳转到 Glossary 模块。
- 学习界面采用原生单列布局：题干主内容 + 细灰中文解释直接置于原文下方，避免额外列对初版视觉造成干扰。

术语表（Glossary）模块
-----------------------
- 使用官方 Wordmark/Monogram 资产展示品牌元素，并支持术语搜索、分类筛选。
- 每个术语包含中文解释、例句及关联题目，未来可扩展为点击跳转题目详情。

其他
----
- 项目结构已纳入 Glossary 模块文件；AppContext 暴露 GlossaryStore；AppIcon 与品牌图集更新为最新版本。
