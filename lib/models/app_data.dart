enum ArchiveKind { book, film, place }

extension ArchiveKindLabel on ArchiveKind {
  String get label {
    switch (this) {
      case ArchiveKind.book:
        return '书籍';
      case ArchiveKind.film:
        return '影视';
      case ArchiveKind.place:
        return '地点';
    }
  }

  String get actionLabel {
    switch (this) {
      case ArchiveKind.book:
        return '书籍已读';
      case ArchiveKind.film:
        return '影视已看';
      case ArchiveKind.place:
        return '去过地点';
    }
  }
}

class ArchiveEntry {
  const ArchiveEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.category,
    required this.date,
    required this.rating,
    required this.amount,
    this.creator,
    this.province,
    this.city,
    this.detail,
    this.expense,
    this.notes = '',
    required this.createdAt,
  });

  final String id;
  final ArchiveKind kind;
  final String title;
  final String category;
  final DateTime date;
  final int rating;
  final int amount;
  final String? creator;
  final String? province;
  final String? city;
  final String? detail;
  final double? expense;
  final String notes;
  final DateTime createdAt;

  ArchiveEntry copyWith({
    String? id,
    ArchiveKind? kind,
    String? title,
    String? category,
    DateTime? date,
    int? rating,
    int? amount,
    String? creator,
    String? province,
    String? city,
    String? detail,
    double? expense,
    String? notes,
    DateTime? createdAt,
  }) {
    return ArchiveEntry(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      category: category ?? this.category,
      date: date ?? this.date,
      rating: rating ?? this.rating,
      amount: amount ?? this.amount,
      creator: creator ?? this.creator,
      province: province ?? this.province,
      city: city ?? this.city,
      detail: detail ?? this.detail,
      expense: expense ?? this.expense,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'kind': kind.name,
      'title': title,
      'category': category,
      'date': date.toIso8601String(),
      'rating': rating,
      'amount': amount,
      'creator': creator,
      'province': province,
      'city': city,
      'detail': detail,
      'expense': expense,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ArchiveEntry.fromJson(Map<String, dynamic> json) {
    return ArchiveEntry(
      id: (json['id'] as String?) ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      kind: ArchiveKind.values.firstWhere(
        (ArchiveKind value) => value.name == json['kind'],
        orElse: () => ArchiveKind.book,
      ),
      title: (json['title'] as String?) ?? '未命名记录',
      category: (json['category'] as String?) ?? '其他',
      date:
          DateTime.tryParse((json['date'] as String?) ?? '') ?? DateTime.now(),
      rating: ((json['rating'] as num?)?.round() ?? 3).clamp(1, 5).toInt(),
      amount: ((json['amount'] as num?)?.round() ?? 1).clamp(1, 999).toInt(),
      creator: json['creator'] as String?,
      province: json['province'] as String?,
      city: json['city'] as String?,
      detail: json['detail'] as String?,
      expense: (json['expense'] as num?)?.toDouble(),
      notes: (json['notes'] as String?) ?? '',
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

const List<String> bookCategories = <String>[
  '小说',
  '历史',
  '心理',
  '社科',
  '传记',
  '哲学',
  '科技',
  '艺术',
  '学习',
  '其他'
];
const List<String> filmCategories = <String>[
  '剧情',
  '喜剧',
  '爱情',
  '动作',
  '科幻',
  '悬疑',
  '动画',
  '纪录片',
  '综艺',
  '其他'
];

const Map<String, List<String>> chinaCities = <String, List<String>>{
  '北京市': <String>['北京市'],
  '上海市': <String>['上海市'],
  '天津市': <String>['天津市'],
  '重庆市': <String>['重庆市'],
  '河北省': <String>['石家庄市', '秦皇岛市', '承德市'],
  '山西省': <String>['太原市', '大同市', '平遥县'],
  '内蒙古自治区': <String>['呼和浩特市', '包头市', '呼伦贝尔市'],
  '辽宁省': <String>['沈阳市', '大连市', '丹东市'],
  '吉林省': <String>['长春市', '吉林市', '延边州'],
  '黑龙江省': <String>['哈尔滨市', '齐齐哈尔市', '牡丹江市'],
  '江苏省': <String>['南京市', '苏州市', '无锡市'],
  '浙江省': <String>['杭州市', '宁波市', '温州市'],
  '安徽省': <String>['合肥市', '黄山市', '芜湖市'],
  '福建省': <String>['福州市', '厦门市', '泉州市'],
  '江西省': <String>['南昌市', '景德镇市', '九江市'],
  '山东省': <String>['济南市', '青岛市', '烟台市'],
  '河南省': <String>['郑州市', '洛阳市', '开封市'],
  '湖北省': <String>['武汉市', '宜昌市', '恩施市'],
  '湖南省': <String>['长沙市', '张家界市', '岳阳市'],
  '广东省': <String>['广州市', '深圳市', '珠海市'],
  '广西壮族自治区': <String>['南宁市', '桂林市', '北海市'],
  '海南省': <String>['海口市', '三亚市', '万宁市'],
  '四川省': <String>['成都市', '绵阳市', '乐山市'],
  '贵州省': <String>['贵阳市', '遵义市', '安顺市'],
  '云南省': <String>['昆明市', '大理市', '丽江市'],
  '西藏自治区': <String>['拉萨市', '林芝市', '日喀则市'],
  '陕西省': <String>['西安市', '延安市', '汉中市'],
  '甘肃省': <String>['兰州市', '敦煌市', '天水市'],
  '青海省': <String>['西宁市', '海西州', '玉树州'],
  '宁夏回族自治区': <String>['银川市', '中卫市', '吴忠市'],
  '新疆维吾尔自治区': <String>['乌鲁木齐市', '喀什市', '伊宁市'],
  '台湾省': <String>['台北市', '高雄市', '台中市'],
  '香港特别行政区': <String>['香港'],
  '澳门特别行政区': <String>['澳门'],
};

List<String> get provinceNames => chinaCities.keys.toList(growable: false);

List<ArchiveEntry> seedArchiveEntries() {
  ArchiveEntry entry({
    required ArchiveKind kind,
    required String title,
    required String category,
    required String date,
    int rating = 4,
    int amount = 1,
    String? creator,
    String? province,
    String? city,
    String? detail,
    double? expense,
    String notes = '',
  }) {
    return ArchiveEntry(
      id: '${kind.name}-$title-$date',
      kind: kind,
      title: title,
      category: category,
      date: DateTime.parse(date),
      rating: rating,
      amount: amount,
      creator: creator,
      province: province,
      city: city,
      detail: detail,
      expense: expense,
      notes: notes,
      createdAt: DateTime.parse(date).add(const Duration(hours: 9)),
    );
  }

  return <ArchiveEntry>[
    entry(
      kind: ArchiveKind.book,
      title: '活着',
      category: '文学',
      creator: '余华',
      date: '2026-05-20',
      rating: 5,
      notes: '人像一粒麦子，在风里仍然要发芽。',
    ),
    entry(
      kind: ArchiveKind.book,
      title: '浪浪地球2',
      category: '科幻',
      creator: '刘慈欣',
      date: '2026-04-18',
      rating: 4,
    ),
    entry(
      kind: ArchiveKind.book,
      title: '置身事内',
      category: '社科',
      creator: '兰小欢',
      date: '2026-03-06',
      rating: 5,
    ),
    entry(
      kind: ArchiveKind.book,
      title: '山月记',
      category: '文学',
      creator: '中岛敦',
      date: '2025-11-10',
      rating: 4,
    ),
    entry(
      kind: ArchiveKind.book,
      title: '艺术的故事',
      category: '艺术',
      creator: '贡布里希',
      date: '2024-07-12',
      rating: 5,
    ),
    entry(
      kind: ArchiveKind.film,
      title: '沙丘2',
      category: '科幻',
      creator: '丹尼斯·维伦纽瓦',
      date: '2026-05-02',
      rating: 5,
    ),
    entry(
      kind: ArchiveKind.film,
      title: '里斯本丸沉没',
      category: '纪录片',
      creator: '方励',
      date: '2026-04-09',
      rating: 5,
    ),
    entry(
      kind: ArchiveKind.film,
      title: '繁花',
      category: '剧情',
      creator: '王家卫',
      date: '2025-12-23',
      rating: 4,
      amount: 1,
    ),
    entry(
      kind: ArchiveKind.film,
      title: '机器人之梦',
      category: '动画',
      date: '2025-06-01',
      rating: 4,
    ),
    entry(
      kind: ArchiveKind.film,
      title: '隐入尘烟',
      category: '剧情',
      date: '2024-08-10',
      rating: 4,
    ),
    entry(
      kind: ArchiveKind.place,
      title: '杭州 · 西湖区',
      category: '城市漫步',
      province: '浙江省',
      city: '杭州市',
      detail: '西湖区',
      date: '2026-05-20',
      rating: 5,
      expense: 320,
      notes: '雨后湖面很安静。',
    ),
    entry(
      kind: ArchiveKind.place,
      title: '杭州 · 良渚',
      category: '博物馆',
      province: '浙江省',
      city: '杭州市',
      detail: '良渚',
      date: '2026-04-16',
      rating: 5,
      expense: 180,
    ),
    entry(
      kind: ArchiveKind.place,
      title: '宁波 · 老外滩',
      category: '城市漫步',
      province: '浙江省',
      city: '宁波市',
      date: '2026-02-08',
      rating: 4,
      expense: 260,
    ),
    entry(
      kind: ArchiveKind.place,
      title: '广州 · 沙面',
      category: '城市漫步',
      province: '广东省',
      city: '广州市',
      date: '2025-10-05',
      rating: 5,
      expense: 420,
    ),
    entry(
      kind: ArchiveKind.place,
      title: '深圳 · 南山',
      category: '展览',
      province: '广东省',
      city: '深圳市',
      date: '2025-09-16',
      rating: 4,
      expense: 530,
    ),
    entry(
      kind: ArchiveKind.place,
      title: '成都 · 宽窄巷子',
      category: '城市漫步',
      province: '四川省',
      city: '成都市',
      date: '2025-04-22',
      rating: 4,
      expense: 380,
    ),
    entry(
      kind: ArchiveKind.place,
      title: '大理 · 洱海',
      category: '自然',
      province: '云南省',
      city: '大理市',
      date: '2024-10-07',
      rating: 5,
      expense: 980,
    ),
    entry(
      kind: ArchiveKind.place,
      title: '昆明 · 滇池',
      category: '自然',
      province: '云南省',
      city: '昆明市',
      date: '2024-10-03',
      rating: 4,
      expense: 520,
    ),
    entry(
      kind: ArchiveKind.place,
      title: '上海 · 武康路',
      category: '城市漫步',
      province: '上海市',
      city: '上海市',
      date: '2024-05-19',
      rating: 4,
      expense: 360,
    ),
    entry(
      kind: ArchiveKind.place,
      title: '南京 · 秦淮河',
      category: '历史',
      province: '江苏省',
      city: '南京市',
      date: '2023-09-11',
      rating: 4,
      expense: 300,
    ),
    entry(
      kind: ArchiveKind.place,
      title: '厦门 · 鼓浪屿',
      category: '海边',
      province: '福建省',
      city: '厦门市',
      date: '2023-06-02',
      rating: 5,
      expense: 650,
    ),
    entry(
      kind: ArchiveKind.place,
      title: '西安 · 城墙',
      category: '历史',
      province: '陕西省',
      city: '西安市',
      date: '2022-08-13',
      rating: 4,
      expense: 420,
    ),
    entry(
      kind: ArchiveKind.place,
      title: '北京 · 798',
      category: '展览',
      province: '北京市',
      city: '北京市',
      date: '2022-04-18',
      rating: 4,
      expense: 280,
    ),
  ];
}
