# Rightway

Rightway 是一款面向在德学习者的驾照理论练习 App。该工作区包含 iOS/iPadOS 客户端的 SwiftUI 工程，以及满足 PRD 中 MVP 范围的基础模块骨架。

## 项目结构

- `Rightway.xcworkspace`：总工作区，引用了 `RightwayApp`。
- `RightwayApp/RightwayApp.xcodeproj`：iOS/iPadOS 主工程。
- `RightwayApp/App`：`@main` 入口与路由、特性开关。
- `RightwayApp/Core`：模型、服务、持久化、国际化。
- `RightwayApp/Modules`：学习、模拟考试、路标百科、笔记、分析等业务模块。
- `RightwayApp/Resources`：资产目录与 SVG 路标示例。
- `RightwayApp/Tests`：基础的单元测试与 UI 测试占位。

## 最低要求

- Xcode 16+
- iOS 17.0 运行时设备/模拟器
- Swift 5.9+

## 下一步建议

1. 接入实际题库与 Supabase 同步接口。
2. 依据授权素材替换 SVG 与媒体资源。
3. 扩展单元测试与 UI 测试覆盖核心流程。
4. 根据合规要求补充隐私/本地化文案校对流程。
