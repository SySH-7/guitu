# 0.3.1 界面图片来源

这些 PNG 由本地 v0.3.1 Flutter 源码的实际 Widget 树在 Flutter 3.24.5 / Dart 3.5.4 截图环境中渲染，使用演示数据；不是 AI 绘制的 UI，也不是 Android 真机截图。字体使用本机字体加载，设备状态栏不包含在图片中，因此细节可能与 Android 系统字体略有差异。

## 生成范围

- home / quick-entry：实际首页，6 本书、5 部影视、6 个去过的省市与示例记录；快捷悬浮入口使用实际组件。
- cover-source / confirm-title / book-prefill：真实封面选择、作品名称确认、预填表单界面；候选文字为演示输入。没有声称对某张封面完成真实设备 OCR。
- statistics：实际统计绘制，以同一组演示记录计算图表。
- travel-province / travel-city：实际足迹地图与列表。绘制时只在本地读取发布 APK 内置地图资源，GeoJSON 未写入公开交付目录，也不上传源码仓库。
- settings / settings-dark：实际用户页，包含相册批量导入地点与 JSON 数据管理。
- photo-consent / photo-review：实际授权说明与结果审核组件；扫描响应为预设 GPS 和拍摄时间输入，由项目真实本地省市匹配与到访聚合逻辑整理出审核结果。

## 验证与限制

截图脚本使用独立缓存工作目录，应用源码的功能与布局没有改动，原项目依赖和 Android 发布包没有改动。截图脚本只提供内存存储、相册扫描、定位与 OCR 的演示输入，不会读取作者的真实相册或记录。

这验证了界面的渲染、导航和展示状态，不能替代 Android 真机上的权限、相机、定位、OCR 准确率和性能测试。海报以这些软件界面为参照生成，生成海报与原始 PNG 应分别使用：原始 PNG 用于准确核对 UI，海报用于宣传。

界面源文件：lib/main.dart、lib/shell.dart、lib/screens/、lib/ui/quick_entry_flow.dart、lib/ui/photo_trip_discovery.dart、lib/ui/record_form_sheet.dart。旧版截图保留在上一级目录。
