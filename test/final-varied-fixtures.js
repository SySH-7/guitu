/* Repeatable, fictional acceptance data. Never uploaded to a real account. */
const fs = require('node:fs');
const path = require('node:path');
const regions = require('../src/regions.json');

const BOOK_CATEGORIES = ['小说','历史','心理','社科','传记','哲学','科技','艺术','学习','其他'];
const FILM_CATEGORIES = ['剧情','喜剧','爱情','动作','科幻','悬疑','动画','纪录片','综艺','其他'];
const HISTORIC_DATES = [
  '1999-12-31','2000-01-01','2000-02-29','2004-02-29','2012-12-31','2016-02-29',
  '2020-02-29','2020-04-30','2023-02-28','2023-12-31','2024-02-29','2025-12-31'
];
const CURRENT_DATES = [
  '2026-01-01','2026-01-31','2026-02-28','2026-03-31','2026-04-30',
  '2026-05-31','2026-06-30','2026-07-31','2026-08-31','2026-09-30','2026-10-16'
];
const PLACE_CHOICES = [
  ['北京市','北京市'],['上海市','上海市'],['天津市','天津市'],['重庆市','重庆市'],
  ['四川省','成都市'],['福建省','厦门市'],['内蒙古自治区','呼伦贝尔市'],
  ['新疆维吾尔自治区','乌鲁木齐市'],['西藏自治区','拉萨市'],['海南省','三亚市'],
  ['浙江省','杭州市'],['广东省','广州市'],['台湾省','台北市'],['台湾省','高雄市'],
  ['香港特别行政区','香港特别行政区'],['澳门特别行政区','澳门特别行政区'],
  ['广西壮族自治区','桂林市'],['黑龙江省','哈尔滨市']
];

function variedArchive() {
  PLACE_CHOICES.forEach(([province,city]) => {
    if (!regions[province]?.includes(city)) throw new Error('Invalid fixture city: ' + province + '/' + city);
  });
  const entries = [];
  const settings = {book:[73,30],film:[67,30],place:[60,24]};
  const first = ['雨后','晨光','秋日','长夏','晴空','冬夜','山间','海风','河畔','四季','茶香','小城'];
  const second = ['纸舟','来信','散步','书店','回声','日记','花园','约定','航行','车站','诗集'];
  for (const [kind,[count,currentCount]] of Object.entries(settings)) {
    for (let i=0;i<count;i++) {
      const day = i < currentCount ? CURRENT_DATES[(i * 7) % CURRENT_DATES.length]
        : HISTORIC_DATES[(i-currentCount) % HISTORIC_DATES.length];
      const [province,city] = PLACE_CHOICES[(i * 7) % PLACE_CHOICES.length];
      let title = first[i % first.length] + second[(i * 3) % second.length] + ' · ' + (kind === 'book' ? '卷' : '集') + (i+1);
      if (kind === 'book' && i === 0) title = 'RAIN & "纸舟" <晨光>：é / e\u0301 / ☕ / 📚';
      if (kind === 'film' && i === 0) title = '小城的 "LIGHT" & <夜航> · 🎬';
      if (kind === 'book' && i === 1) title = '春'.repeat(60);
      if (kind === 'film' && i === 1) title = '海'.repeat(60);
      if (kind === 'film' && i === 3) title = 'Echo'.repeat(15);
      entries.push({
        id:'final-varied-' + kind + '-' + String(i+1).padStart(3,'0'),kind,
        title:kind === 'place' ? city : title,date:day + 'T12:00:00',
        rating:(i % 5)+1,amount:kind === 'place' ? 1 : i === 2 ? 999 : [1,2,1,3,5,1,7][i % 7],
        creator:kind === 'place' || i % 4 === 0 ? null : i === 1 ? '林'.repeat(30) : ['林清禾','周远舟','许安宁','苏雨'][i % 4],
        ...(kind === 'place' ? {province,city} : {category:(kind === 'book' ? BOOK_CATEGORIES : FILM_CATEGORIES)[i % 10]}),
        createdAt:day + 'T08:00:' + String(i % 60).padStart(2,'0') + '.000Z'
      });
    }
  }
  // Deterministically interleave kinds and dates, so the app must do the sorting.
  const interleaved = entries.map((entry,index) => ({entry,rank:(index * 97) % 211}))
    .sort((a,b) => a.rank-b.rank).map(({entry}) => entry);
  return {
    schema:'guitu.archive.v1',userName:'归途',darkMode:false,avatarIndex:0,
    updatedAt:'2026-10-16T01:20:00.000Z',exportedAt:'2026-10-16T01:20:00.000Z',entries:interleaved
  };
}

if (require.main === module) {
  const target = path.join(__dirname,'final-varied-archive.json');
  const archive = variedArchive();
  fs.writeFileSync(target,JSON.stringify(archive,null,2) + '\n');
  console.log(JSON.stringify({file:target,entries:archive.entries.length,
    years:[...new Set(archive.entries.map((entry) => entry.date.slice(0,4)))].sort(),
    kinds:Object.fromEntries(['book','film','place'].map((kind) => [kind,archive.entries.filter((entry) => entry.kind === kind).length]))},null,2));
}
module.exports = {variedArchive};
