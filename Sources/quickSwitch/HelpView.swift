import SwiftUI

/// In-app user guide, shown from the right-click menu. Self-contained so it works
/// in the bundled .app without external files.
struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                section("添加(四类)", rows: [
                    "应用 — 从访达拖入 / 点 + / 右键「添加正在运行的应用」",
                    "文件 — 从访达拖入 / 点 +;点击用默认程序打开",
                    "文件夹 — 从访达拖入 / 点 +;点击在访达打开",
                    "网页 — 右键「添加网址…」粘贴链接;或拖地址栏的网址",
                ])

                section("日常操作", rows: [
                    "左键点图标 = 切换 / 打开",
                    "再点已在前台的 App = 隐藏它,回到上一个 App(设置里可关)",
                    "拖图标到另一个上 = 调整顺序",
                    "拖条上任意空白处 = 移动整条",
                    "右键图标 = 重命名 / 移除",
                    "悬停图标 = 显示名称",
                    "菜单栏右上角的网格图标 = 兜底入口(设置 / 教程 / 退出 / 移回中央)",
                ])

                section("贴边自动隐藏", rows: [
                    "把整条拖到屏幕左 / 右边缘 → 滑出去只留一条细痕",
                    "鼠标靠近细痕 → 自动弹出;移开一会儿 → 缩回",
                ])

                section("设置(右键 →「设置…」)", rows: [
                    "方向(横 / 竖)、是否显示 + 按钮",
                    "图标大小 / 圆角 / 背景透明度 / 间距 / 内边距",
                    "窗口置顶、开机自启、恢复默认样式",
                ])

                section("加不进来 / 切不过去?", rows: [
                    "程序坞直接拖 App 无效(macOS 限制)→ 用「添加正在运行的应用」或从访达拖",
                    "拖浏览器标签页无效 → 拖地址栏网址,或用「添加网址…」",
                    "分发给别人首次打开被拦 → 系统设置→隐私与安全性→「仍要打开」",
                    "找不到条了 → 点菜单栏网格图标 →「把快捷条移回屏幕中央」",
                    "某 App 切不过去 → 终端运行:log stream --predicate 'subsystem == \"com.shiqi.quickSwitch\"' --level info,点该图标看原因",
                ])

                section("隐私", rows: [
                    "只用系统标准接口打开 App,无需辅助功能 / 录屏等敏感权限,不收集任何数据。",
                ])
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("quickSwitch 使用教程").font(.title2.bold())
            Text("一条桌面悬浮快捷条:把常用 App / 文件 / 文件夹 / 网页钉上,点一下就切过去。")
                .foregroundStyle(.secondary)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func section(_ title: String, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            ForEach(rows, id: \.self) { row in
                HStack(alignment: .top, spacing: 6) {
                    Text("•").foregroundStyle(.secondary)
                    Text(row).fixedSize(horizontal: false, vertical: true)
                }
                .font(.callout)
            }
        }
    }
}
