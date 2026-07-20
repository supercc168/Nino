# ETMMO 旁路 Nino 开发约定

本目录是 **独立 git 仓库**（fork: `supercc168/Nino`）。

## 分支策略（wire 兼容）

| 分支 | 基线 | 用途 |
|---|---|---|
| `etmmo/wire-compat-beta47` | `d46627c`（官方 beta.47，**不含** parent-first） | **生产**：诊断 + Sort TryGetValue |
| `etmmo/generator-harden-nino998` | 含 parent-first | **破坏旧 bytes**；禁止装 yiuinino |

## 同源双 TFM 安装

```bash
VERSION_SUFFIX=etmmo.3 ./scripts/etmmo-build-install-dlls.sh --install
```

| 路径 | TFM | 消费者 |
|---|---|---|
| `yiuinino/Runtime/Nino.Core.dll` | netstandard2.1 | Unity |
| `yiuinino/DotNet~/Nino.Core.dll` | net8.0 | Server/CS DotNet 运行时 |
| `yiuinino/Runtime/Nino.Generator.dll` | netstandard2.0 | Unity + DotNet Analyzer |

**禁止** Server 引用 `Runtime/Nino.Core.dll`（net10 `OverflowException`）。  
**禁止** 长期用 NuGet `Nino.Serialization` 替代 fork net8 Core（会落后于旁路改动）。  
**禁止** parent-first Generator 装包，除非全量重导行为树。

## 补丁

1. NINO998 诊断  
2. CSharpParser Sort TryGetValue  
3. 不含 parent-first  
