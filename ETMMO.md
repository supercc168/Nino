# ETMMO 旁路 Nino 开发约定

本目录是 **独立 git 仓库**（fork: `supercc168/Nino`），放在 etmmo 聚合根下仅图路径方便。

## 隔离铁律

| 项 | 要求 |
|---|---|
| VCS | **仅 git**；`svn info` 对本目录与 etmmo 根均应失败 |
| 与五棵 SVN WC | **零关联**：不在 Server/ClientServer/Client/Client2/WebManager 目录内 |
| 运行时 | ETMMO **不**引用本目录源码；只吃 `cn.etetet.yiuinino/Runtime/*.dll` |
| 提交 | Nino 改动 → `git push` 到 fork；DLL 进游戏 → 覆盖 yiuinino 后 **在 Client 树对该 external 做 SVN commit**（四树再 update） |
| 禁止 | NuGet Nino + 包内 DLL 双轨；把本仓 `svn add` 进任何 Files/* |

## 分支

- 默认开发分支示例：`etmmo/generator-harden-nino998`
- 上游对齐：`main`（当前与 `JasonXuDeveloper/Nino` identical 起点）

## 构建并安装 DLL 到 yiuinino

```bash
# 仅构建
./scripts/etmmo-build-install-dlls.sh --build-only

# 构建 + 写入四树 Packages（不 svn commit）
./scripts/etmmo-build-install-dlls.sh --install

# 预览将覆盖的路径与 md5
./scripts/etmmo-build-install-dlls.sh --install --dry-run
```

安装目标（每棵树各一份 working copy，同一 SVN URL）：

`{Server,ClientServer,Client,Client2}/Packages/cn.etetet.yiuinino/Runtime/`

- `Nino.Core.dll` ← `netstandard2.1` Release
- `Nino.Generator.dll` ← `netstandard2.0` Release
- 同步改 `Runtime/package.json` 的 version 备注（脚本写入 etmmo 后缀）

## 安装后必做（人工）

1. Server：`dotnet build ET.sln -c Debug --no-incremental`
2. 跑 `Test_NinoPolymorphicNPActionSerialization`
3. Unity：Domain Reload 后导出/加载一棵行为树
4. 旧 `Bin/Config/Skill/*.bytes` 抽检仍可反序列化
5. 通过后：在 **Client** WC 对 `Packages/cn.etetet.yiuinino` `svn commit`，余三树 `svn update`
6. 部署 bin 仍必须 `--no-incremental`

## 本 fork 相对上游的 ETMMO 补丁（摘要）

1. **NINO998/999**：诊断带异常类型 + 完整 `ToString()`，并写 `NinoGlobal.Error.g.cs`
2. **CSharpParser 成员排序**：`memberIndex` / `NinoExplicitOrder` 用 `TryGetValue`，避免 Sort 比较器抛 `KeyNotFoundException`（历史 NINO998 文案常为 key not present）

## 文档交叉引用

- etmmo：`Doc/Specs/2026-07-20_Nino使用审计与升级风险清单.md` §14
