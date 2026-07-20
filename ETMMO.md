# ETMMO 旁路 Nino 开发约定

本目录是 **独立 git 仓库**（fork: `supercc168/Nino`）。

## 分支策略（wire 兼容）

| 分支 | 基线 | 用途 |
|---|---|---|
| `etmmo/wire-compat-beta47` | `d46627c`（官方 beta.47 Unity DLL 更新点，**不含** parent-first） | **生产候选**：NINO998 诊断 + Sort TryGetValue |
| `etmmo/generator-harden-nino998` | 较新 main（含 623f9eb parent-first） | **破坏旧 bytes**；禁止直接装 yiuinino |

装进 `yiuinino` 的 Generator 不得改变成员序列化顺序，除非全量重导行为树。

## 构建

```bash
VERSION_SUFFIX=etmmo.2 ./scripts/etmmo-build-install-dlls.sh --install
```

## 补丁

1. NINO998/999 完整异常诊断
2. CSharpParser Sort TryGetValue（不改排序语义）
3. 不含 parent-first AddMembers
