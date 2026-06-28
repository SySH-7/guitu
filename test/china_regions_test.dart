import 'package:flutter_test/flutter_test.dart';
import 'package:guitu/models/china_regions.dart';

void main() {
  test('省级地区列表完整且城市选项不再限制为三个', () {
    expect(chinaCities, hasLength(34));

    const Set<String> singleRegion = <String>{
      '北京市',
      '上海市',
      '天津市',
      '重庆市',
      '香港特别行政区',
      '澳门特别行政区',
    };
    for (final MapEntry<String, List<String>> entry in chinaCities.entries) {
      expect(entry.value, isNotEmpty, reason: '${entry.key}不能没有地点选项');
      expect(entry.value.toSet(), hasLength(entry.value.length),
          reason: '${entry.key}存在重复地点');
      if (!singleRegion.contains(entry.key)) {
        expect(entry.value.length, greaterThan(3),
            reason: '${entry.key}应提供完整的可滚动城市列表');
      }
    }
  });

  test('各区域包含代表性城市及地州', () {
    expect(chinaCities['河北省'], containsAll(<String>['石家庄市', '唐山市', '衡水市']));
    expect(chinaCities['海南省'], containsAll(<String>['海口市', '三沙市', '万宁市']));
    expect(chinaCities['新疆维吾尔自治区'],
        containsAll(<String>['乌鲁木齐市', '喀什地区', '伊犁哈萨克自治州']));
    expect(chinaCities['台湾省'], containsAll(<String>['台北市', '台中市', '高雄市']));
  });
}
