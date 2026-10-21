# 完整汤谷候选后台证据

2026-10-20，`0.3.0-godot-candidate.1`。所有最终候选检查均使用 headless；不代表原生 GPU、系统键鼠、用户编辑器操作或前台性能通过。

- `verification.json`：最终候选版本、30项检查、55场景／4,250快照、构建与包校验。
- `source-manifest.json`、`candidate-source.tar.gz`：源码基点、工作区逐文件SHA-256及非PNG源码归档；PNG由清单和基点提交绑定。
- `clean-import.txt`、`clean-tests.txt`、`clean-scene.txt`、`export.txt`：无项目缓存导入、公开边界回归、完整场景、双平台构建与打包日志。
- `assets-first.txt`、`assets-repeat.txt`：两次转换均与原生成物相同，结果见汇总。
- `assets-negative-*.txt`、`assets-negative-verification.json`：缺失图片、越界裁切、重复帧名和非有限数值的真实失败结果。
- `edited-map-red.txt`：修复前合法编辑被拒绝的复现；`edited-map-green-export.txt`：修复后相同编辑通过完整预检及双平台导出。
- `edited-source-layout.json`、`edited-export-layout.json`、`edited-export-verification.json`：道路宽560→580后，源场景与导出Mac包读回的布局一致。
- `invalid-map-rejected.txt`：负尺寸道路被拒绝且定位Road1，退出码为1。
- `source-layout.json`、`exported-layout.json`：最终正式地图与最终Mac包headless读回数据一致。
- `architectures.txt`、`signature.txt`、`unzip-macos.txt`：真实二进制架构、签名和解压检查，退出码0；部分工具成功时没有标准输出。
- `behavior-mapping.json`：64项基线行为中55项规则轨迹通过、9项原生呈现待验。

所有编辑／非法配置用例在临时副本执行，未改写正式场景或冻结参照。临时路径记录供追溯，不作为交付包运行依赖。最终状态与AC矩阵见上级《Godot候选_验收记录.md》。本轮没有执行前台长时采样。
