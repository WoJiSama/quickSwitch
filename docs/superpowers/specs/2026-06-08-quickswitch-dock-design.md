# quickSwitch 设计文档

- **日期**: 2026-06-08
- **状态**: 待评审 (Draft)
- **平台**: macOS (Apple Silicon + Intel)
- **技术栈**: Swift / SwiftUI + AppKit,无第三方依赖

---

## 1. 背景与目标

做一个**轻量的 macOS 桌面挂件**:屏幕上常驻一条悬浮、置顶、可拖动的迷你横条(迷你 Dock),上面排列着用户挑选的若干 App 的真实图标。点哪个图标就切换到哪个 App——在运行就激活到前台,没运行就启动它。

灵感来自 Codex 的桌面小宠物,但定位收敛为**实用的"快速切换条"**,而非会动的宠物精灵。

### 核心价值

- 一眼可见、一点直达,绕开 ⌘Tab 翻找
- 极轻:原生、无依赖、几 MB、毫秒级启动、几乎不占内存
- 零敏感权限,不吓人也不触发安全提示

---

## 2. 非目标 (YAGNI)

明确**先不做**,避免把轻量工具做成小型软件:

- ❌ 每个 App 单独配全局快捷键(需要监听全局热键 + 表格 UI,复杂度高)
- ❌ 会动的宠物精灵 / 帧动画形象
- ❌ 独立的"完整设置窗口"(用右键管理 + 迷你 popover 替代)
- ❌ 跨平台(仅 macOS)
- ❌ 上架 App Store / 沙盒化(初版本地分发即可)

---

## 3. 核心交互

| 操作 | 行为 |
|---|---|
| **左键图标** | 切换到该 App:运行中 → 激活到前台;未运行 → 启动 |
| **右键图标** | 弹出菜单 →「移除」 |
| **拖动图标** | 在条内重新排序 |
| **拖 `.app` 到条上** | 添加该 App(自动解析图标与 bundle id) |
| **点末尾 `+`** | 弹系统文件选择器(默认定位 `/Applications`)选 App 添加 |
| **右键空白处** | 弹迷你设置 popover(图标大小 / 开机自启 / 置顶 / 退出) |
| **拖动整条** | 把横条移动到屏幕任意位置 |

### 关键设计决策:添加体验

App 在系统中以 **bundle id**(如 `com.google.Chrome`)定位。绝不让用户手填 bundle id——只要拿到一个 `.app` 的 URL(拖入或文件选择器),即可用 `Bundle(url:).bundleIdentifier` 自动读出 id,用 `NSWorkspace.icon(forFile:)` 自动取高清图标。用户全程无需了解 bundle id,也无需准备图标素材。

---

## 4. 技术选型与理由

| 选型 | 决定 | 理由 |
|---|---|---|
| 语言/UI | Swift + SwiftUI(内容)+ AppKit(窗口/系统) | macOS 原生最轻、切 App 一行代码、无运行时负担 |
| 窗口 | 无边框 `NSPanel` | 可做置顶、不抢焦点、可拖动的悬浮条 |
| 切换 | `NSWorkspace` | 系统标准 API,无需任何权限 |
| 持久化 | `UserDefaults` | 只存一个 bundle id 数组 + 少量开关,无需文件/数据库 |
| 开机自启 | `SMAppService`(ServiceManagement) | 现代官方 API,替代已废弃的 Login Items |
| 工程 | Xcode 项目 | 方便配 `Info.plist`、`LSUIElement`、签名、直接运行/打包 |
| 依赖 | 无 | 保持极轻 |

---

## 5. 架构与模块

小文件、单一职责、高内聚低耦合。每个模块都能独立回答"做什么 / 怎么用 / 依赖谁"。

```
quickSwitch/
├── App/
│   ├── QuickSwitchApp.swift     // @main、生命周期、装载面板与注入 Store
│   └── DockPanel.swift          // 无边框 NSPanel:floating 置顶 + 可拖动 + 不抢焦点
├── Models/
│   └── AppItem.swift            // 不可变 struct:bundleID / displayName
├── Stores/
│   ├── AppListStore.swift       // [AppItem] 的增/删/排序 + UserDefaults 持久化(唯一真相源)
│   └── PreferencesStore.swift   // 图标大小 / 开机自启 / 置顶 等全局选项
├── Services/
│   ├── AppSwitcher.swift        // 封装 NSWorkspace 切换;依赖 WorkspaceProviding protocol(可注入 mock)
│   ├── AppResolver.swift        // .app URL → AppItem;校验合法性,失败可拒绝
│   └── LoginItemManager.swift   // SMAppService 开机自启的开/关/查询
└── Views/
    ├── DockBarView.swift        // 横向图标条:HStack + 拖入接收 + onMove 排序 + "+" 按钮
    ├── DockIconView.swift       // 单个图标:左键点击 / 右键菜单 / 失效灰显状态
    └── SettingsPopover.swift    // 巴掌大设置面板
```

### 可测试性

`AppSwitcher` 不直接调用 `NSWorkspace.shared`,而是依赖一个 `WorkspaceProviding` protocol(暴露"是否在运行 / 激活 / 启动"三个能力)。生产用真实实现,测试注入 mock,从而单测"在跑→激活、没跑→启动"两条分支。

---

## 6. 数据模型

```swift
struct AppItem: Equatable, Identifiable {
    let bundleID: String      // 唯一标识,如 "com.google.Chrome"
    let displayName: String   // 展示名,如 "Google Chrome"
    var id: String { bundleID }
}
```

- **不可变**:增删排序都返回/替换数组,不就地改字段。
- **图标不入模型**:运行时按 bundleID 向 `NSWorkspace` 实时取,避免存图片、避免图标过期。

持久化形态:`UserDefaults` 中存
- `appBundleIDs: [String]`(顺序即展示顺序)
- 偏好项若干(见 `PreferencesStore`)

---

## 7. 数据流

单向数据流,Store 为唯一真相源,所有变更经过 Store 方法。

```
启动
  └─ AppListStore 读 UserDefaults([bundleID]) ─┐
                                               ├─ DockBarView 渲染
                                  PreferencesStore 读偏好 ─┘
                                  (图标按 bundleID 实时取自 NSWorkspace)

左键图标 → AppSwitcher.switch(to: bundleID)
            ├─ 运行中 → activate
            └─ 未运行 → openApplication(launch)

拖入 / "+" → URL → AppResolver.resolve(url) → AppItem
            → AppListStore.add(item) → 自动持久化 → 视图刷新

右键移除  → AppListStore.remove(bundleID) → 自动持久化
拖动排序  → AppListStore.move(from:to:)   → 自动持久化

设置 popover → PreferencesStore 改值
            ├─ 置顶层级 → 调整 NSPanel.level
            ├─ 图标大小 → 触发重渲染
            └─ 开机自启 → LoginItemManager.set(enabled)
```

---

## 8. 错误处理

绝不静默吞错,也绝不因单点异常崩溃:

| 场景 | 处理 |
|---|---|
| 拖入的不是合法 `.app` / 读不到 bundleID | `AppResolver` 返回失败;图标条轻微抖动反馈,不入列 |
| bundleID 对应的 App 已被卸载 | 图标灰显占位符,右键可移除,点击给提示 |
| 切换 / 启动失败(被删、损坏) | 该图标短暂标红 + tooltip 说明 |
| 重复添加同一个 App | 忽略并轻提示(已存在),不产生重复项 |
| UserDefaults 读到脏数据 | 跳过非法项,保留其余,不崩 |

---

## 9. 权限与打包

- **权限**:无敏感权限。切换 App 只用 `NSWorkspace`(激活/启动,非模拟点击),不需要辅助功能/录屏/自动化授权。
- **后台形态**:`Info.plist` 设 `LSUIElement = YES`——不进 Dock、不进 ⌘Tab,纯后台挂件。
- **开机自启**:`SMAppService.mainApp.register()`,用户在 popover 里开关。
- **产物**:一个几 MB 的 `.app`,本地分发;首版可用本地签名(ad-hoc)或开发者签名。

---

## 10. 测试策略(目标 80%+ 覆盖)

纯逻辑层全部单测;UI 层(NSPanel/SwiftUI)以手动验证 + 少量快照为主。

| 测试文件 | 覆盖 |
|---|---|
| `AppListStoreTests` | add / remove / move / 去重;UserDefaults 持久化往返;脏数据跳过 |
| `AppResolverTests` | 合法 `.app` 解析出正确 bundleID/name;非法路径被拒 |
| `AppSwitcherTests` | mock `WorkspaceProviding`:在跑→activate、没跑→launch、失败路径 |
| `PreferencesStoreTests` | 默认值正确;读写往返 |

遵循 TDD:先写测试(RED)→ 最小实现(GREEN)→ 重构(IMPROVE)。

---

## 11. 里程碑(供实现计划拆分参考)

1. **骨架**:Xcode 项目 + `LSUIElement` + 一个能显示的悬浮置顶可拖 `NSPanel`
2. **切换核心**:`AppSwitcher` + `WorkspaceProviding`(含单测),写死 1-2 个 App 验证点击切换
3. **列表与持久化**:`AppItem` + `AppListStore`(含单测)+ UserDefaults
4. **添加/移除/排序**:`AppResolver`(含单测)+ 拖入 / `+` / 右键移除 / onMove
5. **设置**:`PreferencesStore` + `SettingsPopover` + `LoginItemManager`(图标大小/置顶/开机自启)
6. **打磨**:错误反馈(抖动/灰显/标红)、图标实时取、收尾

---

## 12. 开放问题

- 暂无阻塞性问题。签名方式(ad-hoc vs 开发者证书)在打包阶段按你手头的证书情况再定。
