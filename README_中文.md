# 投稿复现包说明

本复现包用于核查并复现论文的计算证据，包含作者编写的MATLAB仿真代码、数据加工和图表脚本、公开派生标定输入、冻结结果、随机种子、正式图表及校验清单。

本文属于**经验知情仿真**，不是企业现场部署验证。圣保罗订单与天气为同城公开代理输入；DJI Matrice 100能耗数据来自另一地点，仅作为外部工程包络。

## 推荐检查顺序

1. 阅读`CLAIM_BOUNDARIES.md`和`DATA_SOURCES.md`。
2. 运行`python verify_package.py`检查文件、散列和标识清理情况。
3. 在MATLAB中运行`run_verify_frozen_release`检查冻结实验不变量。
4. 运行`run_postprocess_from_frozen`，从冻结MAT结果重新生成统计CSV和七幅图。
5. 运行`python create_submission_tables.py`重新生成Word表格。
6. 如有文件更新，依次运行`python build_artifact_manifest.py`和`python build_public_package_manifest.py`。

完整重跑需要MATLAB R2024b、YALMIP 20230622和Gurobi 10.0.1。完整重跑会覆盖冻结结果目录，只能在复现包副本中执行。

公开包没有包含第三方原始数据、商业软件或密钥。两个决策步数据表中的`order_ids`列已经删除。作者编写的MATLAB和Python代码采用MIT许可证；作者原创的文档、图表、清单和冻结仿真输出采用CC BY 4.0；派生标定输入继续受`LICENSE_SCOPE.md`和`DATA_SOURCES.md`所列上游条款约束，不作笼统再许可。

公开版1.0.0于2026年9月4日冻结，当前确认的发布创建者为Wenjie Huang和Jiang Zhou。GitHub地址和Zenodo DOI将在记录建立后写入本说明与`CITATION.cff`。后续如调整作者或文件内容，应创建新版本，不应静默改写已归档版本。

- GitHub仓库：https://github.com/Corn6947/closed-loop-plan-governance-drone-delivery
- 1.0.0正式发布页：https://github.com/Corn6947/closed-loop-plan-governance-drone-delivery/releases/tag/v1.0.0
- Zenodo归档：预留并发布DOI后补入
