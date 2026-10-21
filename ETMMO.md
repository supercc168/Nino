# ETMMO 旁路 Nino 开发约定

本目录是 **独立 git 仓库**（fork: `supercc168/Nino`，upstream: `JasonXuDeveloper/Nino`）。

## 分支策略

| 分支 | 基线 | 用途 |
|---|---|---|
| `main` | `79e507b9`（upstream main，`4.0.0-rc.6` + 后续 perf） | 与上游对齐；不含 etmmo 补丁 |
| `etmmo/wire-compat-beta47` | `d46627c`（官方 beta.47） | **ET 当前生产**：NINO998 诊断 + Sort TryGetValue 补丁 |
| `etmmo/rc6` | `79e507b9` | rc.6 基线 + 本脚本；**待上游修泛型 formatter 缺陷后才能投产** |

上游同步：

```bash
git fetch upstream            # upstream = https://github.com/JasonXuDeveloper/Nino
git checkout main && git merge --ff-only upstream/main
git checkout etmmo/rc6 && git merge main
```

## 同源多 TFM 安装

```bash
VERSION_SUFFIX=etmmo.4 ./scripts/etmmo-build-install-dlls.sh --install --root /Users/doge/git/etmmo-framework
VERSION_SUFFIX=etmmo.4 ./scripts/etmmo-build-install-dlls.sh --install --root /Users/doge/svn/etmmo --trees "Client ClientServer Server Client2"
```

产物（同一 commit）：

| 路径 | TFM | 消费者 |
|---|---|---|
| `yiuinino/Runtime/Nino.Core.dll` | netstandard2.1 | Unity |
| `yiuinino/Runtime/Nino.Generator.dll` | netstandard2.0 | Unity + DotNet Analyzer |
| `yiuinino/Runtime/Nino.UnityTypes.dll` | netstandard2.1 | Unity（AnimationCurve/Gradient/RectOffset） |
| `yiuinino/DotNet~/Nino.Core.dll` | net8.0 | Server/CS DotNet 运行时 |

**禁止** Server 引用 `Runtime/Nino.Core.dll`（net10 `OverflowException`）。
**禁止** 长期用 NuGet `Nino.Serialization` 替代 fork net8 Core（会落后于旁路改动）。

## rc.6 升级阻断项（2026-10-21 实测，见 `docs/` 同源证据）

1. **wire 不兼容**：v4 重写（上游 `fa9b6a0f` 2026-10-14）后与 beta.47 互不可读；交叉实验双向报错
   （旧头 `F7CD4F01` vs 新头 `5D602149`）。ET 现有 2101 个 `[NinoType]`、行为树/Slate/Box2D 资产需全量重导。
2. **开放泛型 formatter 生成缺陷**（上游 bug）：`class G<T> : 非泛型NinoType基类` 生成
   `.__WriteSubtype(...)` / `AsBaseSlot<TSub, >` 非法代码；ET 的 `NP_BBValueBase<T>` 直接中招。
3. **API 移除**：`INinoBufferWriter`、`NinoDeserializer.Deserialize(span,Type)`、`DeserializeRefBoxed`、
   `Deserialize(out T, ref Reader)` → 改为 `DeserializeBoxed(...)` / `Deserialize<T>(ref Reader)`。
4. **诊断升级为 error**：NINO023（struct 无成员，`NP_EntityRef`）、NINO005（`[NinoConstructor]`
   参数无同名成员，`NP_BlackBoardRelationData(Type limitType)`）。

结论：rc.6 可用于新工程；ET 现网要投产须先完成 1-4 的迁移与资产重导。
