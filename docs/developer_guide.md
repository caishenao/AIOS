# AIOS (Home Steward) 开发者指南 & 架构文档

本开发文档系统性地梳理了 AIOS (Home Steward) 已完成的工作、系统实现的功能，以及下一步的研发规划。

---

## 一、系统架构总览 (Architecture Overview)

AIOS 采用 **100% 客户端去中心化无头架构 (Client-Side Serverless Mesh)**，舍弃了传统昂贵的中心化后端。系统由两个核心部分组成：
1. **Flutter 智能终端应用 (apps/client_flutter)**：作为感知、呈现与交互终端。它通过本地语音/文本接收意图，调用大模型（Gemini/OpenAI/Claude）将意图翻译为工具调用链（Tool Calling），并通过网络就近调度集群资源，最终将指令以 A2UI 渲染为原生页面。
2. **边缘无界面守护进程 (apps/headless_daemon)**：部署在 Linux 服务器或边缘网卡网关上，直接调用底层硬件能力、执行系统命令或脚本、读写文件、并汇总控制其连接的物联网设备。

```
+---------------------------------------+                  +---------------------------------------+
|        AIOS Flutter Client            |                  |         Headless Daemon Node          |
|      (Desktop / Mobile / TV)          |                  |        (Linux Server / IoT GW)        |
+---------------------------------------+                  +---------------------------------------+
|                                       |                  |                                       |
|  +---------------------------------+  |  UDP Broadcast   |  +---------------------------------+  |
|  |    Discovery & Mesh Scanner     | <================== |  |    Discovery Heartbeat (12100)  |  |
|  +---------------------------------+  |                  |  +---------------------------------+  |
|                                       |                  |                                       |
|  +---------------------------------+  |                  |  +---------------------------------+  |
|  |    Local Agent Service          |  |  REST API (HTTP) |  |  |   Command/Script Executor       |  |
|  |    - LLM Prompt Injector        |  |                  |  |   - File Read/Write (Upload/DN) |  |
|  |    - Federated Tools Router     |  | -------------->  |  |   - IoT Gateway Simulator       |  |
|  |    - Platform OS Automation     |  |                  |  |     (gateway_devices.json)      |  |
|  +---------------------------------+  |                  |  +---------------------------------+  |
|                                       |                  |                                       |
+---------------------------------------+                  +---------------------------------------+
```

---

## 二、已完成的工作 (Completed Work)

### 1. 独立 Dart 无头守护进程 CLI 应用
开发了独立运行在 Dart Console 环境的 `apps/headless_daemon`，不依赖任何 GUI 或重量级后台服务：
- **能力动态配置**：可以通过命令行参数配置设备名称、接口端口、以及开启/关闭特定的管理能力（如 `command_exec`、`file_upload`、`iot_data`、`iot_control`）。
- **设备配置动态读取/写入**：网关的 IoT 设备信息通过本地 `gateway_devices.json` 维护，支持按实际物理设备动态修改并保存状态。
- **二进制传输机制**：新增了文件下载端点，并在文件上传与下载中自动进行 Base64 编解码，实现了图片、压缩包、二进制执行程序等复杂媒介文件的互传。

### 2. 局域网自发现网格
- **广播心跳**：守护进程启动后，会在后台每 5 秒向端口 `12100` 广播 UDP 数据包，表明身份、能力清单和 TCP 路由端口。
- **客户端多维发现**：客户端的 `DiscoveryService` 在 native 平台上启动 Raw UDP 绑定监听，能够瞬间捕获并解析广播，自动将其加载并呈现在大模型的认知注册表中。

### 3. 本地大模型智能调度与工具注册
- **动态上下文注入**：大模型生成 Prompt 前，`LocalAgentService` 会自动拉取当前所有的在线节点，并将每个网关下**真实挂载的 IoT 设备状态**以 `<DiscoveredClusterNodes>` 格式注入 Prompt。
- **联邦工具链 (Federated Tools)**：面向大模型核心注册了五大编排工具：
  - `daemon_execute_command`：在指定网关运行 Shell 指令。
  - `daemon_execute_script`：上传并运行复杂的临时脚本。
  - `daemon_upload_file`：上传文件（支持二进制 Base64）。
  - `daemon_download_file`：下载文件（支持二进制 Base64）。
  - `daemon_get_iot_data` 与 `daemon_control_iot_device`：查询和调节网关连接的真实设备。

### 4. 终端硬件控制自动化
- 客户端实现了根据运行操作系统动态授权的本地控制功能：
  - **Android**：集成 loopback 进程 ADB 命令，可快速对界面截图、模拟触控和按键。
  - **Windows**：集成 PowerShell 脚本调用、屏幕截屏、模拟鼠标指针移动与按键点击.
  - **Linux**：提供直接执行底层 Shell 指令的能力。

### 5. UI 与视听优化
- **Siri-like 声音波形**：重构了动态声音包络绘制算法，在录音和聆听状态时绘制富有律动感的光晕正弦波。
- **真实地图定位**：将 CustomPaint 模拟地图升级为 Yandex 静态图集成，支持精准绘制导航点与多标线路由。
- **UI 渲染后端解耦**：将 `GenUiSurface` 与具体的 JSON Catalog 渲染引擎进行解耦，设计了抽象 `RenderBackend` 接口与 Riverpod 动态提供者。在设置页添加了渲染引擎模式切换卡，支持在 `JSON (Dynamic Catalog)` 与 `RFW (Remote Flutter Widgets)` 后端间动态热切换。

### 6. 本地 Screen-Parser 屏幕多模态理解
为了解决全屏截图上传云端 VLM 存在的耗时长（3-10秒）、网络流量大、隐私风险和 Token 成本高的问题，新增了**三级瀑布式 Screen-Parser 解析引擎**：
- **Tier 1 (Flutter 语义树)**：对于 App 自身界面，遍历内存中的 `SemanticsNode` 直接导出 UI 结构 JSON，耗时 <1ms，零开销。
- **Tier 2 (平台无障碍 API)**：对于系统内任意第三方应用窗口，利用 Windows UI Automation、Android uiautomator、Linux AT-SPI 等原生无障碍 API 动态解析出前台窗口的 UI 树 JSON，耗时 10-50ms。
- **Tier 3 (本地 OmniParser 视觉服务)**：在无障碍 API 失败的极端不透明 UI 下，对接本地部署的 YOLOv8 icon 目标检测 + Florence-2 图像描述模型，完成视觉元素到 JSON 坐标树的转换。
- **远程无头端扩展**：在 Headless Daemon 中增加了 `/screen-structure` 与 `/parse-screenshot` 接口，赋予远端边缘节点本地屏幕结构提取与视觉分析代理能力。
- **智能工具链集成**：大模型可以通过 `get_screen_structure` 和 `daemon_get_screen_structure` 精准寻找按钮/输入框的坐标 bounds，从而配合 `simulate_mouse` 进行高效精确的桌面级 GUI 自动化操控。

### 7. 免 Key 网页搜索集成 (Local Web Search)
- **去中心化本地搜索**：通过本地 HTTP 客户端异步获取 DuckDuckGo Lite 纯净页面数据，完全避免了第三方搜索 API 对 API Key 及网络代理费用的依赖。
- **高阶文本解码**：内置了 `_decodeHtml` 解析器，自动转换搜索结果中的 HTML 转义实体，并将搜索出的 Titles、URLs 和 Snippets 聚合成 Markdown 格式直接回馈大模型，使得 Steward 具备实时联网获取新闻、天气及学术资料的能力。

---

## 三、已实现的功能 (Features Implemented)

| 功能模块 | 对应技术点 | 实现效果 |
| :--- | :--- | :--- |
| **设备自组网** | UDP 组播/mDNS 服务侦听 | 守护进程通电即发现，自动接入 AIOS 集群网络。 |
| **真实设备适配** | `gateway_devices.json` 动态持久化 | 网关设备不再是虚构的假数据，修改本地 JSON 文件立刻同步至 LLM 认知。 |
| **双向大文件互传** | Base64 编解码与流控 | 支持从服务器下载日志/截图，以及向网关上传脚本和升级包。 |
| **分布式命令控制** | 子进程控制 + 远端 API 路由 | 大模型可以跨平台让服务器进行系统升级、运行诊断指令或运行自动化脚本。 |
| **本地自动化操控** | native 执行器 (ADB/Win32/Process) | 根据平台赋予 AI 对当前的显示屏进行图像化审查和交互按键的控制力。 |
| **高档视听反馈** | Siri 动效波形与真实街区导航地图 | 极具未来感的精致首屏体验。 |
| **渲染契约解耦** | Riverpod + RenderBackend 抽象层 | 一键在内置的 JSON Catalog 与 RFW 动态渲染引擎间进行热切换，渲染后端完全解耦。 |
| **本地屏幕结构解析** | 三级瀑布式 Screen-Parser (Semantics/A11y/OmniParser) | 毫秒级提取 UI 树 JSON，规避全屏截图上传，解析性能和隐私安全极大提升。 |
| **联网搜索整合** | 本地免 Key 网页搜索器 (DuckDuckGo Lite Web Scraper) | 无需云端 Search API Key，本地极速爬取最新实时信息与参考数据，大幅扩展知识面。 |

---

## 四、安全与隐私 (Security & Privacy)

- 密钥与会话凭证仅持久化于渲染适配器及守护进程本地，网络传输不跨出家庭路由器局域网边界。
- 本地自动化设备控制（截屏、ADB 控制等）均限制在应用自身沙盒或本地环回接口上运行。
- **双向鉴权与配对安全**：所有敏感接口（命令执行、文件传输、自动化等）必须通过 HTTP Authorization Bearer Token (配对码) 校验，客户端首次接入时需要进行握手配对。
- **人机安全确认 (HITL)**：涉及敏感系统操作（如 Shell 命令/脚本执行）时，客户端展示高档毛玻璃确认弹窗，由用户手动授权，杜绝大模型越权操作危险。

---

## 五、已完成的高级集成功能 (Advanced Features Completed)

### 1. 通信安全与握手鉴权、人机确认（HITL）
- **双向握手鉴权**：守护进程在首次启动时自动生成唯一的 UUID 配对 Token 并存储在本地。除 `/agent-card` 描述接口外，所有控制端点均要求在 HTTP 请求标头中携带 `Authorization: Bearer <token>` 否则拦截并返回 401 提示。
- **配置页密码配对**：客户端 `A2AAgentRegistry` 扩展了配对码存储，并在设置页为每个集群节点提供状态图标与 Token 手动配对/重置功能，且进行本地持久化（`shared_preferences`）。
- **人机确认机制 (Human-in-the-Loop)**：客户端设计了高档毛玻璃效果的确认弹窗。在 LLM 企图调用敏感的系统指令（`exec_powershell`/`exec_shell`/`daemon_execute_command`等）前，调用会被挂起（通过 `Completer<bool>` 异步锁），由用户显式点选“允许”或“拒绝”。若拒绝，安全退出并返回“User rejected operation”给 LLM。

### 2. 动态技能 UI 模板分发 (RFW Remote Widget Catalog Distribution)
- **动态组件定义与下发**：允许无界面节点直接将编译好的 RFW 动态组件下发至客户端。我们在 Headless Daemon 的 `/agent-card` 端点中附加了自定义 RFW 描述文本 `rfw_widgets`，当客户端自发现或连接节点时，自动注册到客户端 of RFW `Runtime`。
- **RfwRenderBackend 混合引擎**：客户端实现了一个高表现力的 RFW 混合渲染引擎。它把标准的布局卡片（Column, Row, ListView）交由 Flutter 高级预置组件渲染，遇到 `DaemonSensorCard` 等自定义组件时，自动读取 runtime 中由 Daemon 下发的 RFW 模板包，并将 props 注入 RFW `DynamicContent` 渲染成原生组件。

### 3. 深度无头浏览器自动化 (Headless Browser Automation)
- **集成 Puppeteer 引擎**：在 Headless Daemon 引入了基于 CDP 协议的轻量级 Puppeteer 浏览器自动化引擎，支持在服务器端无头执行网页浏览。
- **序列化链式执行 (POST /browser-action)**：为 LLM 开发了支持链式操作的原子交互网关，支持单次请求连续完成 `goto` -> `click` -> `type` -> `get_text` -> `screenshot`（截图） -> `close` 交互。
- **智能联网交互工具**：客户端为 Gemini/OpenAI/Claude 等所有 LLM 核心注册了 `daemon_browser_action` 联邦工具，LLM 可调用此工具让远端节点自动执行表单填充、数据采集与截图审计。

### 4. 离线紧急模式与边缘智能 Fallback (Offline Mode & Local AI Fallback)
- **三级降级离线架构**：
  - **云端大模型 (Layer 1)**：在联网正常时由在线 API 执行复杂的多模态规划。
  - **局域网 Ollama (Layer 2)**：当在线 API 因断网、超时发生异常时，客户端 `LocalAgentService` 自动降级为调用本地守护进程的 `POST /offline-chat` 端点，该端点会自动将请求转发给本地运行的 Ollama 模型（例如 `qwen2.5:0.5b`）。
  - **本地规则与正则意图解析 (Layer 3)**：若本地 Ollama 实例未运行，守护进程会无缝降级到本地规则/正则意图解析引擎，对控制指令进行模糊语义匹配，自动将意图转换为 `control_iot_device` 的结构化工具调用，再利用客户端的本地 API 完成智能应急反馈。

---

## 六、下一步研发规划 (Next Steps)

### 1. 多模态摄像头实时巡检
- 将网关的 `MediaPlayer` 组件扩展为能够直连 Daemon 端挂载的多媒体 USB/IP 摄像头，实现低延迟实时 WebRTC 画面采集。
- 允许 LLM 触发定时屏幕抓取和目标检测，发现宠物活动或安全警报时，通过推送通知客户端。

### 2. 多智能体协作协议 (A2A Multi-Agent Collaboration)
- 支持各个无头节点间自主发起任务委派与状态同步。例如，服务器节点遭遇硬盘空间不足时，自动委托备份节点创建远程数据转储路径。
- 实现共享式黑板记忆（Shared Blackboard Memory），让局域网内的所有节点共享一个动态同步的分布式 KV 记忆网络。

