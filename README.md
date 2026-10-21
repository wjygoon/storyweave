# StoryWeave AI

> 全球发行的 AI 原生无限流互动故事工具

<p align="center">
  <img src="https://img.shields.io/badge/iOS-17.0%2B-blue" />
  <img src="https://img.shields.io/badge/Swift-5.9-orange" />
  <img src="https://img.shields.io/badge/SwiftUI-Yes-green" />
  <img src="https://img.shields.io/badge/StoreKit-2-yellow" />
  <img src="https://img.shields.io/badge/No-Dependencies-lightgrey" />
</p>

---

## 📋 P0 验收记录

### 第一轮 ✅ 已完成
| 项 | 状态 |
|---|---|
| DeepSeek 文本接入（默认路由）| ✅ |
| Seedream 图像接入（默认路由）| ✅ |
| StoreKit 三档订阅 + 4 档 Credits | ✅ |
| 合规门控（AgeGate → AIDataConsent → EULA）| ✅ |
| 付费墙渐进（第 2 故事 + 回溯 + 额度耗尽 + 青少年屏蔽）| ✅ |
| 免费层每日 5 次 + 自然日重置 | ✅ |
| 恢复购买（AppStore.sync + Transaction.currentEntitlements）| ✅ |

### 第二轮 ✅ 本轮补齐
| 项 | 状态 | 文件 |
|---|---|---|
| ① 流式输出 | ✅ | DeepSeekService.makeStreamingRequest(SSE) + AIServiceProtocol AsyncThrowingStream |
| ② 删除账户 | ✅ | AuthManager.deleteAccount (Supabase DELETE /auth/v1/user + 本地全清 + SignOut) |
| ③ AI-generated 角标 | ✅ | StoryReadingView + ShareCardView |
| ④ 举报 + 24h 处置 | ✅ | ReportFormView + "24 小时内处理" 文案 |
| ⑤ 三层审核低成本化 | ✅ | ContentModerator.validateOutput（本地 re-scan + 抽检占位）|
| ⑥ 屏蔽最小实现 | ✅ | BlockManager（UserDefaults 持久化 sourceID 过滤）|

### BUILD: ✅ SUCCEEDED · 零错误 · 39 Swift 文件

---

## 🛠 技术栈

| 模块 | 技术 |
|---|---|
| 界面 | SwiftUI + 原生动效 |
| 本地存储 | SwiftData |
| 用户体系 | Supabase + Sign in with Apple |
| 支付 | StoreKit 2 |
| **文本生成** | **DeepSeek deepseek-chat**（主）/ Gemini（备）|
| **图像生成** | **Seedream doubao-seedream-5-0**（主）/ DALL-E 3（备）|
| 网络 | URLSession + SSE（原生无依赖）|

**零第三方依赖** · 全部 Apple Swift 原生框架。

---

## 🔑 Secrets.plist 字段清单

路径：`StoryWeaveAI/Config/Secrets.plist`（**严禁硬编码进 Swift 源码**）

| Key | 获取地址 | 说明 |
|---|---|---|
| `DEEPSEEK_API_KEY` | https://platform.deepseek.com/api_keys | 文本生成，当前主力，**已预填** `sk-bf11f543...` |
| `SEEDREAM_API_KEY` | https://console.volcengine.com/ark/ | 豆包文生图（doubao-seedream-5-0），缺失时 fallback 到 `ARK_API_KEY` |
| `ARK_API_KEY` | https://console.volcengine.com/ark/ | 火山方舟通用 Key，豆包文本/图像共用 |
| `GEMINI_API_KEY` | https://aistudio.google.com/apikey | Google Gemini（配置可切换备选）|
| `DALL-E_API_KEY` | https://platform.openai.com/api-keys | DALL-E 3（配置可切换备选）|
| `QWEN_API_KEY` | https://dashscope.console.aliyun.com/apiKey | 阿里通义（配置可切换备选）|
| `MINIMAX_API_KEY` | https://api.minimax.chat/ | MiniMax（配置可切换备选）|
| `SUPABASE_URL` | Supabase Project Settings → API | Supabase 项目 URL |
| `SUPABASE_ANON_KEY` | Supabase Project Settings → API | Supabase 匿名 Key |

App 启动时 Secrets 缺失自动降级为友好错误，不崩溃。

---

## 💰 StoreKit 产品 ID 表

| 产品 ID | 价格 | 类型 | 说明 |
|---|---|---|---|
| `com.storyweave.premium.weekly` | **$4.99** | 自动续期订阅 | 周付入口档位 |
| `com.storyweave.premium.monthly` | **$9.99** | 自动续期订阅 | 月付主力档位 |
| `com.storyweave.premium.yearly` | **$59.99** | 自动续期订阅 | **主推档位** + 7 天免费试用 |
| `com.storyweave.credits.10` | **$0.99** | 消耗型（Credits）| 10 Story Credits，兑换 Plot Twist 卡 |
| `com.storyweave.credits.50` | **$4.99** | 消耗型（Credits）| 50 Story Credits |
| `com.storyweave.credits.120` | **$9.99** | 消耗型（Credits）| 120 Story Credits |
| `com.storyweave.credits.240` | **$19.99** | 消耗型（Credits）| 240 Story Credits，最划算 |
| `com.storyweave.items.plottwist` | **10 Credits** | Credits 消耗型 | 剧情转折点兑换卡（非独立 IAP，用 Credits 消耗）|

**StoreKit 配置步骤**：App Store Connect → 我的 App → 订阅 → 创建 3 个 Auto-Renewable Subscription；创建 4 个 Consumable（Credits 包）。本地测试：Product → Scheme → Edit Scheme → StoreKit Configuration → 新建 `.storekit` 文件加入全部 ID。

---

## 🛡 合规十项清单

| # | 项 | 状态 | 位置 |
|---|---|---|---|
| 1 | 首屏 AI 数据共享同意弹窗（DeepSeek/Seedream/Gemini/DALL-E）| ✅ | ComplianceGate.swift → AIDataConsentSheet |
| 2 | 年龄门控 ≥13（青少年模式自动开启）| ✅ | ComplianceGate.swift → AgeGateSheet |
| 3 | EULA 首屏同意 | ✅ | ComplianceGate.swift → ComplianceState.eulaRequired |
| 4 | 订阅页完整披露（价格/7天试用/自动续费/恢复购买/隐私/EULA）| ✅ | SubscriptionView.swift |
| 5 | AI 生成内容标注（阅读页 + 分享卡）| ✅ | AIGeneratedBadge → StoryReadingView/ShareCardView |
| 6 | 设置页"删除账户"入口（Supabase DELETE + 本地全清 + 二次确认）| ✅ | AuthManager.deleteAccount + SettingsView.alert |
| 7 | 举报按钮 + 24h 违规处置说明 | ✅ | ReportFormView + "24 小时内处理" 文案 |
| 8 | 屏蔽来源/世界观最小实现 | ✅ | BlockManager.swift |
| 9 | 三层内容审核（本地敏感词硬拦截 + 生成约束注入 prompt + 输出本地 re-scan + 抽检制模型复核）| ✅ | ContentModerator.moderateLocally + validateOutput |
| 10 | 隐私政策 + EULA URL 链接 | ✅ | AppConfig.Store.privacyPolicyURL / termsOfServiceURL |

---

## 🚀 上线检查清单

- [ ] **App Store Connect 产品配置**：创建 3 订阅 + 4 Credits 消耗型产品 ID（见上表）
- [ ] **Secrets.plist 填写**：补全 ARK_API_KEY（火山方舟）、SUPABASE_URL、SUPABASE_ANON_KEY
- [ ] **合规 URL 替换**：把 `AppConfig.Store.privacyPolicyURL / termsOfServiceURL / contactEmail` 换成正式域名
- [ ] **AI 服务商资质备案**：DeepSeek/Seedream 境内服务需完成相应电信/网信备案（中国大陆区）
- [ ] **内容安全审核链路跑通**：手动测试违规 prompt → 应触发 `contentBlocked` 不展示
- [ ] **付费墙场景验证**：完成 2 个故事 → 触发 paywall；点击回溯（非付费）→ 触发 paywall；免费额度耗尽 → 触发 paywall；青少年模式 → 付费墙屏蔽
- [ ] **删除账户端到端**：测试登录 → 设置 → 删除账号 → 确认回到未登录态 + 本地 SwiftData 清空
- [ ] **订阅恢复购买**：在已购买账号上测试"恢复购买"按钮 → Transaction.currentEntitlements 正确识别
- [ ] **青少年模式开关**：设置 → 青少年模式 → 打开时屏蔽所有付费门控 & 限制敏感世界观
- [ ] **截图素材**：App Store 截图突出 "AI-generated" 角标位置
- [ ] **Build Configuration**：Release 构建时确保 Secrets.plist 包含所有 Key（TestFlight 可用空值降级测试）
- [ ] **隐私清单 (Privacy Nutritional Label)**：App Store Connect 中如实申报 AI 提供商数据共享

---

## 📚 目录结构

```
StoryWeaveAI/
├── App/              StoryWeaveApp.swift (入口 + 合规门控注入)
├── Components/       ComplianceGate, TypewriterText, Buttons, Common
├── Config/           Secrets.plist, Info.plist, StoryWeave.entitlements
├── Data/             DataManager (SwiftData CRUD)
├── Models/           Story, StoryNode, Character, WorldTemplate
├── Services/
│   ├── AIService/    AIServiceProtocol, AIServiceManager, ContentModerator
│   │   └── CN/       DeepSeekService (SSE 流式), ArkService, SeedreamService
│   ├── Auth/         AuthManager (Sign in with Apple + deleteAccount)
│   ├── Payment/      StoreKitManager, QuotaManager, BlockManager
│   └── Supabase/     SupabaseClient
├── Theme/            ColorPalette, Typography
├── Utilities/        AppConfig, Extensions, UserPreferences, KeychainHelper
├── ViewModels/       StoryReadingViewModel, HomeViewModel, SubscriptionViewModel
└── Views/
    ├── Home/         HomeView (大卡续读 + FAB)
    ├── Settings/     SettingsView, ReportFormView, TeenModeSettingsView
    ├── Share/        ShareCardView
    ├── StoryCreation/  StoryCreationEntryView, StoryCreationViewModel
    ├── StoryReading/   StoryReadingView
    └── Subscription/   SubscriptionView
```

---

## 🔄 模型切换

AIServiceManager 提供 `textProvider` / `imageProvider` 发布属性，支持运行时切换：

```swift
// DeepSeek (文本主力)
AIServiceManager.shared.textProvider = .deepseek
// Seedream (图像主力)
AIServiceManager.shared.imageProvider = .seedream

// 备选
AIServiceManager.shared.textProvider = .gemini  // .ark, .qwen, .minimax
AIServiceManager.shared.imageProvider = .dalle  // .seedream, .ark
```

每个 Service 内部通过 `Secrets.value(for:)` 读取 Key，缺失时优雅降级（返回 `AIError.apiKeyMissing`）。

---

## 🧪 测试

```bash
# 清理 DerivedData 后编译
rm -rf ~/Library/Developer/Xcode/DerivedData/StoryWeave-*
DEVELOPER_DIR=/Applications/Xcode-15.4.0.app/Contents/Developer \
xcodebuild -project StoryWeave.xcodeproj -scheme StoryWeave \
  -destination 'generic/platform=iOS Simulator' -sdk iphonesimulator build
# 预期: ** BUILD SUCCEEDED **
```

## 📱 最低版本

| 项 | 要求 |
|---|---|
| Xcode | 15.0+ |
| iOS | 17.0+ |
| Swift | 5.9+ |
| SwiftUI | Yes |
| SwiftData | Yes |

---

## ⚠️ 本期明确不做

多人协作 · AI 配音 · 独立社区 App · 跨故事宇宙联动 · 首版中国区合规备案 · 限定角色一次性内购

---

**StoryWeave AI · 让 AI 为你编织独一无二的故事** · © 2026
