/* Varied, low-risk fictional records with IDs shaped like the real H5 form. */
const regions = require('../src/regions.json');
const C = require('../src/core.js');
function largeArchive(perKind,seed = 20261011) {
  let state = seed >>> 0;
  const random = () => {
    state += 0x6D2B79F5;
    let t = state;
    t = Math.imul(t ^ t >>> 15,t | 1);
    t ^= t + Math.imul(t ^ t >>> 7,t | 61);
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
  const choose = (list) => list[Math.floor(random() * list.length)];
  const first = ['春日','夏夜','秋风','冬雪','远山','海边','森林','小城','晨光','星空','河畔','南方','北方','旧时','湖畔','晴空','午后','旅人','山谷','时光'];
  const second = ['故事','笔记','书店','来信','散步','花园','车站','航行','回声','相遇','手册','日记','旅行','四季','小路','茶馆','约定','记忆','风景','诗集'];
  const names = Array.from('林陈周李沈许苏叶方顾江赵张徐陆程韩唐刘黄');
  const given = Array.from('清安宁远舟星月明晓秋春雨云青文书南平景言');
  const bookCategories = ['小说','历史','心理','社科','传记','哲学','科技','艺术','学习','其他'];
  const filmCategories = ['剧情','喜剧','爱情','动作','科幻','悬疑','动画','纪录片','综艺','其他'];
  const cityNames = Object.entries(regions).flatMap(([province,cities]) => cities.map(city => province + '|' + city));
  const entries = [];
  for (const kind of ['book','film','place']) {
    for (let i = 0; i < perKind; i++) {
      const timestamp = Date.UTC(2018,0,1) + Math.floor(random() * (Date.UTC(2026,9,1) - Date.UTC(2018,0,1)));
      const [province,city] = choose(cityNames).split('|');
      entries.push({
        id:timestamp + '-' + random().toString(36).slice(2),kind,
        title:kind === 'place' ? city : choose(first) + choose(second) + '·' + choose(second) + ' ' + (i + 1),
        creator:kind === 'place' ? null : choose(names) + choose(given) + choose(given),
        category:kind === 'book' ? choose(bookCategories) : kind === 'film' ? choose(filmCategories) : undefined,
        province:kind === 'place' ? province : null,city:kind === 'place' ? city : null,
        date:new Date(timestamp).toISOString().slice(0,10) + 'T12:00:00',
        createdAt:new Date(timestamp).toISOString(),rating:1 + Math.floor(random() * 5),
        amount:kind === 'place' ? 1 : 1 + Math.floor(random() * 3)
      });
    }
  }
  return C.normalizeSnapshot({schema:C.SCHEMA,userName:'归途',entries,
    exportedAt:'2026-10-11T12:00:00.000Z',updatedAt:'2026-10-11T12:00:00.000Z'});
}
module.exports = {largeArchive};
