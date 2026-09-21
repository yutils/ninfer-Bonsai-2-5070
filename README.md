# Bonsai 2 27B · NInfer on RTX 5070（Windows）

基于 **[CraneBW/ninfer-ternary-bonsai-ada](https://github.com/CraneBW/ninfer-ternary-bonsai-ada)**
在 Windows / RTX 5070 上编译并跑通。

> 上游仓库是 **Ada（sm_89）+ Linux** 的移植（实机 RTX 4070 Ti SUPER）。
> 本机是 **RTX 5070（Blackwell, sm_120a）**，12 GB 显存。
> 引擎的参考架构本来就是 `sm_120a`（上游在 RTX 5090 上调优），所以内核路径是现成的，
> 只是 `device.h` 缺 Blackwell 的 SM 计数分支、Windows 下又没有 FFmpeg —— 见「四、我为 5070 做的适配」。

---
## 省流说明
- 第一步构建编译，双击 build.bat 等待10分钟。出现build文件夹，并且- build\apps\ninfer-serve.exe等文件齐全就构建成功。
- 第二步把ternary-bonsai2-27b.ninfer文件放入文件夹，路径是artifacts\ternary-bonsai2-27b.ninfer
- 第三步双击start-server.bat启动服务。
- 第四步启动chat.bat 聊天验证
- 然后就接入各种编程工具测试了。


## 一、一键启动（日常只用两个 bat）

| 想做的事 | 双击 | 说明 |
|---|---|---|
| **启动服务** | `start-server.bat` | 加载模型并监听 `127.0.0.1:8080`，**先开它** |
| **开始聊天** | `chat.bat` | 终端多轮对话，每轮结束打印 token 数与速度 |
| 复跑正确性验收 | `run-ppl.bat` | 困惑度（PPL），怀疑模型跑偏时才用 |
| 重新编译 | `build.bat` | 只在你改了 C++ 源码后才需要 |

`chat.bat` 内命令：`/clear` 清空 · `/think` 开关思维链 · `/temp 0.8` · `/max 4096` · `/stats` 重看统计 · `/exit`

每轮回答结束会打印一行统计，例如：

```
── 输出 259 tok · 62.0 tok/s · 提示 112 tok(缓存 55) · 合计 371 tok · 用时 4.2s
   · 首字 728ms · 解码 74.8 tok/s · 预填 78.4 tok/s
```

「缓存 55」是多轮对话命中的前缀缓存（prompt tokens 不用重算）。

---

## 二、验收结果（RTX 5070 实测）

| 判据 | 目标 | 实测 |
|---|---|---|
| 编译 | `BUILD OK` | ✅ 537 个构建目标全过 |
| `engine ready` | 打印引擎就绪 | ✅ `qwen3.8-27b/groupwise-int` |
| 生成正确 | "The capital of France is" → Paris | ✅ 输出 **Paris** |
| **PPL**（数值口径） | 正确 = 个位数~十几；错 = **几百** | ✅ **4.58849** |
| 权重体积 | — | ✅ 6.70 GiB（开 MTP 7.12 GiB） |
| 纯解码 | — | 50.2 tok/s |
| **MTP draft=3** | — | ✅ **101.6 tok/s**，接受率 49.5%（2.49 tok/轮） |
| 评分吞吐 | — | 381.8 tok/s |
| HTTP `/v1/models` | 列出模型 | ✅ `{"id":"bonsai2-27b","max_model_len":32768}` |
| 中文多轮 | 通顺 | ✅ 中文推理链 + 正确回答，前缀缓存命中 |

> PPL 用的是 `eval\ppl_sample.txt`（约 1790 token 的技术英文）。
> **换语料会得到不同的绝对值**，判据只看量级：个位数~十几 = 正确，几百 = 权重格式解释错了。

---

## 三、目录结构

```
E:\ninfer-Bonsai\
  repo\                      GitHub 仓库源码（CraneBW/ninfer-ternary-bonsai-ada）
  build\apps\                ★ 编译产物 ninfer.exe / ninfer-serve.exe / ninfer-perplexity.exe
  artifacts\
    ternary-bonsai2-27b.ninfer   ★ 打包好的三元制品（10.5 GiB）
    qwen3_8_27b.ninfer           打包模板（借它的 vision/mtp/frontend 对象）
  models\                    GGUF 源权重（Ternary-Bonsai-2-27B-PQ2_0 / -mmproj）
  eval\ppl_sample.txt        PPL 语料
  start-server.bat / chat.bat / run-ppl.bat / build.bat
  build.sh                   本 agent 用的编译脚本（手工拼 MSVC 环境，等价于 build.bat）
```

**制品来源**：沿用上一次从 `models\Ternary-Bonsai-2-27B-PQ2_0.gguf` 打好的 `.ninfer`。
它与本仓库是**同一个 v2 容器格式**，已用仓库自带的 `tools/artifact/inspect.py` 验证：

```
model_id: qwen3.8-27b
weights_id: groupwise-int
objects: 1192 (1186 tensors, 6 resources)
formats: {'PQ2_0_G128': 322, 'BF16': 627, 'Q4G64_F16S': 55, ...}
```

所以**不需要重新打包**，省掉约 20 GB 下载。要重打的话见 `pack/`（需另取打包器）。

---

## 四、我为 5070 做的适配

上游仓库开箱编译在 Windows 上会卡在三处，改动都尽量小：

| # | 问题 | 改动 |
|---|---|---|
| 1 | `src/core/device.h` 只有 `NINFER_SM86` / `NINFER_SM89`，Blackwell 编译直接 `#error` | 加 `NINFER_SM120` 分支（`kTargetSmCount = 48`，RTX 5070 的 SM 数） |
| 2 | 根 `CMakeLists.txt` 只对 `89` 定义架构宏，`120a` 不定义任何宏 | 加 `if(CMAKE_CUDA_ARCHITECTURES MATCHES "^120")` → `NINFER_SM120=1` |
| 3 | Windows 无系统 FFmpeg，CMake 硬编码 `ffmpeg/include`、`ffmpeg/lib`，configure 直接失败 | 新增 `NINFER_DISABLE_MEDIA` 选项；并给 `src/media/decode/decode.cpp` 的无 FFmpeg 分支补 `inspect_image` / `inspect_video` 两个桩（否则链接 LNK2019） |

**代价**：没有 FFmpeg → **不支持图片/视频输入**，`models\*-mmproj-Q8_0.gguf` 用不上。纯文本不受影响。
（`repo\ffmpeg` 目录留空是故意的；想开多模态就放进 FFmpeg dev 包并去掉 `-DNINFER_DISABLE_MEDIA=ON`。）

架构用 `120a`：这是上游的**参考实现架构**，warp-specialized TMA / NVFP4 / k8v4 内核
（在 sm_89 构建里被 stub 掉的那批）在 120a 下是完整编译的 —— 比 sm_89 适配版能用到更多内核路径。

---

## 五、调参数

### 改模型名 / 上下文 / KV 格式

都在 `start-server.bat` 顶部：

```bat
set "CTX=32768"          :: 上下文上限（token）
set "MODELID=bonsai2-27b" :: 对外模型名，客户端 "model" 必须一致
set "KVTYPE=fp8"         :: bf16 | fp8 | int8 | nvfp4 | k8v4
set "PORT=8080"
set "DRAFT=3"         :: MTP 投机解码草稿 token 数，0 = 关闭
```

**KV 格式影响可达上下文**。先把账算清楚（5070 12 GB，`--kv-capacity auto`）：

| `--kv-dtype` | 每 token KV | 12 GB 理论上限 | 实测 |
|---|---|---|---|
| `bf16` | 64 KiB | ~44k | — |
| `fp8` / `int8` | 32 KiB | **~88k** | 32768 ✅ / 65536 ✅ / 98304 ❌ |
| `k8v4` | 24 KiB | ~118k | 未测 |
| `nvfp4` | 16 KiB | ~174k | 未测 |

12 GB 的账：权重 7.12 GiB ＋ CUDA 上下文等 ~0.8 GiB → 只剩 **4.08 GiB**；
引擎再扣 ~0.34 GiB 运行时 ＋ **1 GiB 强制余量** → 真正能分给 KV 的只有 **~2.74 GiB**。

> **为什么作者能开 238k，你不行**：作者的 RTX 4070 Ti SUPER 是 **16 GB（16376 MiB）**，不是 12 GB。
> README 那句 `VRAM 7.12 GiB` 是**权重体积**，不是显卡容量。
> 16 GB 扣掉同样的 7.12 GiB 权重 ＋ 1 GiB 余量后还有 **~7.3 GiB 给 KV**，
> 正好等于 `238k × 32 KiB`(fp8) 或 `120k × 64 KiB`(bf16) —— 两个数完全对得上。
> **纯粹是显存少了 4 GB，不是配置没调好。**

想在 12 GB 上摸到 200k，唯一的路是 `nvfp4` ＋ 关掉 MTP：

```
set "KVTYPE=nvfp4"     :: 16 KiB/token
rem start-server.bat 里删掉 --spec mtp --draft-tokens 3 → 权重 7.12 → 6.70 GiB，多出 0.42 GiB
```

预算 ~3.16 GiB vs 需求 `200k × 16 KiB = 3.05 GiB`，**勉强能起**。代价要认：
没有 MTP 解码从 ~101 掉到 ~50 t/s；nvfp4 的长上下文召回作者没验过（他只验了 fp8 6/6）。
想要作者的体验，换 **5070 Ti（16 GB）** 是直接解。

> `--max-context` 只是**单条序列**的逻辑上限，真正吃显存的是 `--kv-capacity`；
> 并发 2 条各 200k 在 12 GB 上不可能。

实测日志：

```
max-context 32768 → 起，free after startup 2.37 GiB
max-context 65536 → 起，free after startup 1.37 GiB
max-context 98304 → 失败：minimum Engine runtime reservation requires 3.34 GiB
                    + 1.00 GiB headroom, but only 4.08 GiB available after weights
```

**推荐 32768**：余量足，并发更稳。想要更大就 65536，别再往上。

> `--kv-capacity auto` 会按显存自算并在放不下时明确报错，不用手算。

### 其它常用开关

```
--spec mtp --draft-tokens 3   投机解码（实测 50 → 101 tok/s）
--max-concurrency 2           并发请求数
--cors                        允许浏览器跨域
--wddm-evictable-budget       按总显存而不是 WDDM 进程预算来规划（Windows 独显）
--vision                      启用视觉（需要 FFmpeg，当前构建不支持）
```

---

## 六、HTTP 接口

服务是 **OpenAI + Anthropic 双协议**，Base URL `http://127.0.0.1:8080/v1`。

```powershell
curl.exe http://127.0.0.1:8080/v1/models
curl.exe http://127.0.0.1:8080/v1/chat/completions -H "Content-Type: application/json" ^
  -d "{\"model\":\"bonsai2-27b\",\"messages\":[{\"role\":\"user\",\"content\":\"你好\"}],\"max_tokens\":200}"
```

- 思维链在 `reasoning_content` 字段（流式下是同名 delta），只渲染 `content` 会看到长时间空白
- 流式请求带 `stream_options:{include_usage:true}` 时，末帧会回 `usage` 和 `timings`
- 第三方工具怎么接（opencode / Claude Code / Continue / Cline 等）见 **`接入指南.md`**

---

## 七、排错

| 现象 | 原因 / 处理 |
|---|---|
| `chat.bat` 连不上 | 先双击 `start-server.bat`，等窗口出现 `listening on ...` 再聊 |
| 双击 bat 出现一堆乱码 / `不是内部或外部命令` | bat 被存成了 UTF-8，cmd 按 GBK 读会读断行。本仓库的 bat **已统一为 GBK + CRLF**，别用记事本另存为 UTF-8 |
| 客户端报 `model_not_found` | `"model"` 必须写成 `bonsai2-27b`（或你改的 `MODELID`） |
| 显存不足 / startup failed | 调小 `CTX`，或把 `KVTYPE` 换成 `int8` / `nvfp4` |
| 重编译报 `LNK1104 无法打开 ninfer-serve.exe` | **先停掉正在运行的服务**，exe 被占用 |
| 中文 `ninfer.exe --prompt` 报 NFC 归一化失败 | 走 `chat.bat`（HTTP），或 CLI 的 `--messages <json>` |
| 服务端看不到请求 | 服务窗口会打印 `req#N started`，没有这行说明请求没到服务端 |

---

## 八、手动命令（不用 bat 时）

```bat
build\apps\ninfer-serve.exe artifacts\ternary-bonsai2-27b.ninfer ^
  --host 127.0.0.1 --port 8080 --model-id bonsai2-27b ^
  --max-context 32768 --kv-capacity auto --kv-dtype fp8 ^
  --max-concurrency 2 --spec mtp --draft-tokens 3 --cors
```

```bat
build\apps\ninfer.exe artifacts\ternary-bonsai2-27b.ninfer ^
  --prompt "The capital of France is" --max-new 60 --max-context 32768 --kv-dtype fp8
```

工具链：MSVC 14.44 / Windows SDK 10.0.26100 / CMake+Ninja（VS2022 BuildTools 自带）/ CUDA 13.3。
仓库要求 CUDA ≥ 13.1。
