# 私有地图数据说明

- 官方来源：天地图云中心“行政区划可视化”
- 来源页面：<https://cloudcenter.tianditu.gov.cn/administrativeDivision>
- 官方接口：`/api/portal/region/map?gb=156000000&level=2`
- 下载日期：2026-06-22
- 页面标注数据更新时间：2025 年 9 月

公开源码仓库不包含 `china_provinces.geojson`。发布安装包可内置该文件以保证旅途页地图正常展示；如在合法授权和合规前提下进行本地私有开发，也可将兼容的 GeoJSON 放置在本目录，文件名为 `china_provinces.geojson`。

缺少该文件时，App 其他功能仍可正常运行，地图区域会显示“地图数据未配置”。

地图数据不适用本项目的 MIT License。公开发布或传播地图数据、含地图数据的安装包及其构建产物前，应自行确认数据授权、地图审核和其他适用要求。
