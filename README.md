# 墨阅 LeafReader

一个用 SwiftUI 写的本地阅读器，支持 **TXT / EPUB / PDF**。面向个人签名（免费 Apple ID，7 天续签）安装，不依赖 App Store，也不使用需要开发者账号的能力。

## 为什么是这套方案

iOS 的 `.ipa` 只能由 macOS 上的 Xcode 工具链产出，而开发机是 Windows。所以采用：

- **Windows 上写代码**：VS Code + Git + GitHub CLI
- **GitHub Actions 的 macOS runner 编译**：`xcodegen` 生成工程 → `xcodebuild` 编译 → 打包未签名 `.ipa`
- **手机上用 Sideloadly 个人签名安装**（7 天续签一次）

工程文件（`.xcodeproj`）不入库，统一由 `project.yml` 通过 [XcodeGen] 生成，这样 Windows 上不需要维护 pbxproj。

[XcodeGen]: https://github.com/yonaskolb/XcodeGen

## 目录结构

```
project.yml                  # 工程定义（XcodeGen）
.github/workflows/build.yml  # 云端构建：产出未签名 ipa
LeafReader/
  App/                       # 入口 + URL 打开回调
  Models/                    # Book / ReadingDocument / 阅读偏好
  Store/LibraryStore.swift    # 书库：导入、删除、进度持久化
  Reader/
    BookLoader.swift          # 按格式分发
    EpubParser.swift          # EPUB 解包 + OPF/nav/ncx 解析
    TextDecoder.swift         # TXT 编码探测（UTF-8/GB18030/UTF-16…）
    TextBookBuilder.swift     # TXT → 分段 HTML
    WebReaderView.swift       # WKWebView 渲染（TXT/EPUB 共用）
    PDFReaderView.swift       # PDFKit
    ReaderStyle.swift         # 注入的 CSS / JS
    ReaderView.swift          # 阅读界面 + 菜单
  UI/                        # 书架、设置、目录、文件选择器
  Assets.xcassets/           # 图标与主题色
tools/
  make_icon.ps1              # 重新生成 1024 图标
  check_sources.py           # 无 Mac 时的离线静态检查
```

## 数据存放

```
Application Support/LeafReader/
  library.json               # 书库索引（标题、进度、封面等）
  Books/<UUID>/<原文件>       # 书籍文件
  Books/<UUID>/cover.jpg     # EPUB 封面（可选）
  Books/<UUID>/text/         # TXT 拆分后的 HTML 缓存
  Books/<UUID>/epub/         # EPUB 解压目录
```

## 构建

推送到 `main` 或手动触发 **Build** workflow，约 3–6 分钟后在运行页面的 Artifacts 里下载：

- `LeafReader-unsigned-ipa` → `LeafReader-unsigned.ipa`
- `build-log`（失败时用来看编译报错）

## 安装

Windows 上用 Sideloadly 选择 `LeafReader-unsigned.ipa`，用自己的 Apple ID 签名后安装。到期前重新签名覆盖安装即可，书籍和进度都在 App 沙盒内，覆盖安装不会丢。

## 个人签名的能力边界（设计约束）

免费 Apple ID 签名不支持：推送通知、iCloud/CloudKit、App Groups、Background Modes 中的多数能力、部分 Keychain 共享。因此本项目：

- 全部数据存本地沙盒，不做云同步
- 不使用推送、不依赖 iCloud
- 只使用 Foundation / SwiftUI / PDFKit / WebKit 这些系统框架

## 已实现

- [x] 书架网格、封面、阅读进度展示
- [x] 导入 TXT / EPUB / PDF（文件选择器，支持多选）
- [x] 从其他 App「用…打开」导入
- [x] TXT：编码自动识别、按 6 万字分段、章节列表跳转
- [x] EPUB：解包、OPF/spine 解析、nav/ncx 目录、章节渲染
- [x] PDF：PDFKit 连续翻页、页码记忆
- [x] 阅读进度记忆（章节 + 章内位置 / PDF 页码）
- [x] 排版设置：字号、行距、边距、字体、四套背景主题
- [x] 点击正文切换沉浸模式
- [x] 删除书籍、标记未读

## 后续可做

- [ ] 分页（横向翻页）模式与页码计算
- [ ] 书签与批注、全文搜索
- [ ] 阅读统计、书架排序与分组
- [ ] EPUB 内嵌字体、脚注跳转处理

## 本地检查

没有 macOS 时可以先跑：

```powershell
py -3 tools/check_sources.py
```

它会检查 Swift 源码的括号/字符串平衡与资源完整性，能挡掉大部分低级错误；类型层面的错误以 GitHub Actions 的编译结果为准。