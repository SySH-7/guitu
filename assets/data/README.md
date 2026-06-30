# 私有地图数据说明

- 官方来源：天地图云中心“行政区划可视化”
- 来源页面：<https://cloudcenter.tianditu.gov.cn/administrativeDivision>
- 省级数据接口：`/api/portal/region/map?gb=156000000&level=2`
- 市级数据接口：按省级行政区 `gb` 分别请求 `/api/portal/region/map?gb={provinceGb}&level=3` 后合并
- 下载日期：2026-06-30
- 页面标注数据更新时间：2025 年 9 月

公开源码仓库不包含 `china_provinces.geojson` 和 `china_cities.geojson`。发布安装包可内置这些文件以保证旅途页省级/市级足迹地图正常展示；如在合法授权和合规前提下进行本地私有开发，也可将兼容的 GeoJSON 放置在本目录，文件名分别为：

- `china_provinces.geojson`
- `china_cities.geojson`

缺少对应文件时，App 其他功能仍可正常运行，对应地图区域会显示“地图数据未配置”。

市级足迹地图优先使用天地图市级行政区划面数据。对于数据源中未提供独立市级面的直辖市、港澳台及部分省直管或特殊县级区域，应用使用同源省级行政区划面作为可视化兜底，以避免足迹区域空缺。

地图数据不适用本项目的 MIT License。公开发布或传播地图数据、含地图数据的安装包及其构建产物前，应自行确认数据授权、地图审核和其他适用要求。
