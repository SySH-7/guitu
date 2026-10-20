(() => {
  'use strict';
  const C = GuituCore;
  const app = document.getElementById('app');
  const BOOK_CATEGORIES = ['小说','历史','心理','社科','传记','哲学','科技','艺术','学习','其他'];
  const FILM_CATEGORIES = ['剧情','喜剧','爱情','动作','科幻','悬疑','动画','纪录片','综艺','其他'];
  const KIND_NAME = {book:'阅读', film:'影视', place:'旅途'};
  // Inline vector icons keep the native visual language without font/network dependencies.
  function icon(name) {
    const paths = {
      book:'<path d="M12 5.5C9 3.5 5.5 3.5 3 4.5v15c2.5-1 6-1 9 1 3-2 6.5-2 9-1v-15c-2.5-1-6-1-9 1Z"/><path d="M12 5.5v15"/>',
      film:'<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 4v16M17 4v16M3 9h4m-4 6h4M17 9h4m-4 6h4M7 8h10M7 16h10"/>',
      place:'<path d="M20 10c0 6-8 12-8 12S4 16 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/>',
      home:'<path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1Z"/>',
      map:'<path d="m3 5 6-2 6 2 6-2v16l-6 2-6-2-6 2ZM9 3v16M15 5v16"/>',
      person:'<circle cx="12" cy="7" r="4"/><path d="M4 21v-2a8 8 0 0 1 16 0v2Z"/>',
      sun:'<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.5 1.5m11 11L19 19M5 19l1.5-1.5m11-11L19 5"/>',
      moon:'<path d="M20.5 14A9 9 0 0 1 10 3.5 9 9 0 1 0 20.5 14Z"/>',
      cloud:'<path d="M7 19a5 5 0 0 1-1-9.9 6.5 6.5 0 0 1 12.5-1.6A5.8 5.8 0 0 1 18 19Z"/>',
      help:'<circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 1 1 4.2 1.8c-1 .8-1.7 1.2-1.7 2.7M12 17h.01"/>',
      plus:'<path d="M12 4v16M4 12h16"/>'
    };
    return '<svg class="ui-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">' + (paths[name] || paths.book) + '</svg>';
  }
  const KIND_ICON = {book:icon('book'), film:icon('film'), place:icon('place')};
  const AK_KEY = 'guitu-tieba-map-ak';
  let snapshot = C.emptySnapshot();
  let localKey = 'guitu-v022:local';
  let localStorageArea = localStorage;
  let dirty = false;
  let cloud = null;
  let cloudReadCapture = null;
  let cloudBase = null;
  let cloudState = 'loading';
  let cloudError = '';
  let identity = null;
  let tab = 'home';
  let modal = null;
  let modalScrollPosition = null;
  let kindFilter = 'all';
  let year = new Date().getFullYear();
  let query = '';
  const recordLimits = {home:10,books:10,travel:10,search:10};
  let selectedRegion = '';
  let map = null;
  let travelRoot = null;
  let travelSignature = '';
  const cityMarkers = new Map();
  const cityPointCache = new Map();
  const geocodeQueue = [];
  const queuedCities = new Set();
  let activeGeocodes = 0;
  let pendingGeocodeRetries = 0;
  let markerMap = null;
  let mapActive = false;
  let mapLoading = null;
  let mapGeneration = 0;
  let mapLoadAttempts = 0;
  let cloudBusy = false;
  let warningReadyAt = 0;
  let warningTimer = null;
  let uploadPhase = '';
  let uploadFinishedAt = '';
  let quota = {week:C.weekKey(),used:0,remaining:5};

  const esc = (value) => String(value == null ? '' : value).replace(/[&<>"']/g, (char) =>
    ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  const dateOnly = (value) => String(value || '').slice(0,10);
  const shortDate = (value) => dateOnly(value).replace(/-/g,'.');
  const mapAk = () => localStorage.getItem(AK_KEY) || GUITU_BUILD_AK || '';
  const errorText = (error) => String(error?.message || error || '请稍后重试');
  const updateTheme = () => document.body.classList.toggle('dark', snapshot.darkMode);
  function withTimeout(work,milliseconds) {
    let timer;
    return Promise.race([
      Promise.resolve().then(work),
      new Promise((_,reject) => { timer = setTimeout(() => reject(new Error('timeout')),milliseconds); })
    ]).finally(() => clearTimeout(timer));
  }
  function toast(message) {
    document.querySelector('.toast')?.remove();
    const element = document.createElement('div');
    element.className = 'toast';
    element.textContent = message;
    document.body.appendChild(element);
    setTimeout(() => element.remove(), 3800);
  }
  function storageRead() {
    try {
      const raw = localStorageArea.getItem(localKey);
      if (!raw) return null;
      const parsed = JSON.parse(raw);
      return {snapshot:C.normalizeSnapshot(parsed.snapshot), dirty:parsed.dirty === true};
    } catch (error) {
      cloudError = '本地草稿读取失败：' + String(error.message || error);
      return null;
    }
  }
  function storageWrite() {
    localStorageArea.setItem(localKey, JSON.stringify({snapshot,dirty}));
  }
  function sameArchiveContent(left,right) {
    const view = (value) => JSON.stringify({userName:value.userName,darkMode:value.darkMode,
      avatarIndex:value.avatarIndex,entries:value.entries});
    return view(left) === view(right);
  }
  function statusLabel() {
    if (cloudState === 'ok') return '已同步到贴吧云端';
    if (cloudState === 'saving') return '正在保存到云端';
    if (cloudState === 'pending' || cloudState === 'conflict') {
      return localStorageArea === sessionStorage ? '本次打开临时保存' : '本机已保存';
    }
    if (cloudState === 'error') return '云端操作未完成';
    if (cloudState === 'local') return localStorageArea === sessionStorage ? '本次打开临时保存' : '本机已保存';
    return '正在读取';
  }
  function updateStatus() {
    const element = document.getElementById('cloud-status');
    if (!element) return;
    element.innerHTML = '<span class="status-dot ' + (cloudState === 'ok' ? 'ok' : cloudState === 'error' || cloudState === 'conflict' ? 'error' : '') + '"></span>' + esc(statusLabel());
    document.querySelectorAll('[data-cloud-manage]').forEach((button) => {
      button.disabled = !cloud || cloudBusy;
    });
  }
  function markChanged() {
    snapshot.updatedAt = new Date().toISOString();
    snapshot.exportedAt = snapshot.updatedAt;
    dirty = true;
    storageWrite();
    cloudState = cloud ? 'pending' : 'local';
    render();
  }
  function keepCloudReadsFresh() {
    if (location.protocol === 'file:') return;
    const open = XMLHttpRequest.prototype.open;
    let sequence = 0;
    XMLHttpRequest.prototype.open = function(method,url,...args) {
      if (String(method).toUpperCase() === 'GET') {
        try {
          const request = new URL(String(url),location.href);
          if (request.origin === location.origin && request.pathname === '/c/s/game/payloadDownload') {
            if (location.hostname === 'tieba.baidu.com') request.searchParams.set('_guitu_read',Date.now() + '-' + (++sequence));
            const gameId = new URLSearchParams(location.search).get('game_id');
            if (cloudReadCapture && gameId && request.searchParams.get('game_id') === gameId)
              cloudReadCapture.push(this);
            url = request.href;
          }
        } catch (_) { /* Leave unrelated SDK requests as supplied. */ }
      }
      return open.call(this,method,url,...args);
    };
  }
  function verifiedCloudResponse(xhr) {
    if (xhr.readyState !== 4 || xhr.status < 200 || xhr.status >= 300) throw new Error('unconfirmed cloud response');
    if (xhr.responseURL) {
      const url = new URL(xhr.responseURL,location.href);
      if (url.origin !== location.origin || url.pathname !== '/c/s/game/payloadDownload')
        throw new Error('unexpected cloud response');
    }
    const body = xhr.responseType === 'json' ? xhr.response : JSON.parse(xhr.responseText);
    if (!C.isObject(body)) throw new Error('invalid cloud response');
    // Check the current SDK's success fields before it discards response errors.
    const code = body.error_code !== undefined ? body.error_code : body.no !== undefined ? body.no : body.errno;
    if (String(code) !== '0' || !Object.prototype.hasOwnProperty.call(body,'data'))
      throw new Error('cloud response did not confirm success');
    if (body.data === null) return {};
    if (!C.isObject(body.data)) throw new Error('invalid cloud response data');
    const payload = body.data.payload;
    if (payload === undefined || payload === null || payload === '') return {};
    if (typeof payload !== 'string') throw new Error('invalid cloud payload');
    const remote = JSON.parse(payload);
    if (!C.isObject(remote)) throw new Error('invalid cloud archive');
    return remote;
  }
  async function downloadVerifiedCloud(milliseconds) {
    // File previews use injected local test SDKs; deployed HTTPS reads require wire evidence.
    if (location.protocol === 'file:') return withTimeout(() => cloud.downloadData(),milliseconds);
    if (cloudReadCapture) throw new Error('cloud read already in progress');
    const capture = [];
    cloudReadCapture = capture;
    try {
      const remote = await withTimeout(() => cloud.downloadData(),milliseconds);
      if (capture.length !== 1) throw new Error('cloud read could not be verified');
      const verified = verifiedCloudResponse(capture[0]);
      if (!C.isObject(remote) || JSON.stringify(remote) !== JSON.stringify(verified))
        throw new Error('cloud archive did not match its response');
      return verified;
    } finally {
      if (cloudReadCapture === capture) cloudReadCapture = null;
    }
  }
  async function waitForTieba() {
    if (window.tieba && typeof window.tieba.downloadData === 'function' && typeof window.tieba.uploadData === 'function') return window.tieba;
    if (location.protocol === 'file:') return null;
    for (let attempt = 0; attempt < 80; attempt++) {
      if (window.tieba && typeof window.tieba.downloadData === 'function' && typeof window.tieba.uploadData === 'function') return window.tieba;
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    return null;
  }
  async function boot() {
    app.innerHTML = '<div class="boot"><span class="brand-mark">归</span><strong>归途</strong><span>正在准备你的记录…</span></div>';
    cloud = await waitForTieba();
    if (cloud) keepCloudReadsFresh();
    if (cloud && typeof cloud.getUserInfo === 'function') {
      try { identity = cloud.getUserInfo(); } catch (_) { identity = null; }
    }
    const account = identity && (identity.user_id || identity.uid);
    localKey = 'guitu-v022:' + (account ? String(account) : cloud ? 'tieba-unknown' : 'local');
    localStorageArea = cloud && !account ? sessionStorage : localStorage;
    const local = storageRead();
    if (local) { snapshot = local.snapshot; dirty = local.dirty; }
    if (cloud) {
      try {
        const remote = await downloadVerifiedCloud(6000);
        if (!C.isObject(remote)) throw new Error('downloadData 未返回 JSON 对象');
        quota = C.quotaInfo(remote);
        const saved = remote[C.CLOUD_KEY];
        cloudBase = JSON.stringify(saved || null);
        if (saved) {
          const remoteSnapshot = C.readCloudSnapshot(saved);
          if (local && !sameArchiveContent(snapshot,remoteSnapshot)) {
            dirty = true;
            cloudState = 'conflict';
            cloudError = '本机和云端记录不同。下载可合并，保存可更新云端。';
          } else {
            snapshot = remoteSnapshot;
            dirty = false;
            storageWrite();
            cloudState = 'ok';
          }
        } else {
          cloudState = dirty ? 'pending' : 'local';
        }
      } catch (_) {
        cloudState = 'error';
        cloudError = '云端暂时无法读取，请稍后重试';
      }
    } else {
      cloudState = 'local';
    }
    let sampleAdded = 0;
    if (GUITU_SAMPLE_ARCHIVE) {
      const marker = localKey + ':fictional-seed-v1';
      if (localStorageArea.getItem(marker) !== '1') {
        const merged = C.mergeSnapshots(snapshot,GUITU_SAMPLE_ARCHIVE);
        sampleAdded = merged.entries.length - snapshot.entries.length;
        if (sampleAdded) {
          snapshot = merged;
          snapshot.updatedAt = new Date().toISOString();
          snapshot.exportedAt = snapshot.updatedAt;
          dirty = true;
          storageWrite();
          if (cloudState !== 'error') cloudState = cloud ? 'pending' : 'local';
        }
        localStorageArea.setItem(marker,'1');
      }
    }
    updateTheme();
    render();
    if (sampleAdded) toast('已加入 ' + sampleAdded + ' 条虚构测试记录；不会自动上传云端');
  }

  function recordTile(entry) {
    const meta = entry.kind === 'place'
      ? [entry.province,entry.city].filter(Boolean).join(' · ')
      : [entry.creator,entry.category,entry.amount > 1 ? entry.amount + (entry.kind === 'book' ? ' 册' : ' 季') : ''].filter(Boolean).join(' · ');
    return '<button class="record card" data-action="detail" data-id="' + esc(entry.id) + '">' +
      '<span class="record-icon ' + entry.kind + '">' + KIND_ICON[entry.kind] + '</span>' +
      '<span class="record-main"><span class="record-title">' + esc(entry.title) + '</span><span class="record-meta">' + esc(meta) + '</span>' +
      '<span class="record-bottom"><span class="record-rating" aria-label="评分 ' + entry.rating + ' / 5">' + '★'.repeat(entry.rating) + '☆'.repeat(5-entry.rating) + '</span>' +
      '<span class="record-date">' + esc(shortDate(entry.date)) + '</span></span></span></button>';
  }
  const sortedEntries = () => snapshot.entries.slice().sort((a,b) => new Date(b.date) - new Date(a.date));
  function recordsForList(key) {
    const entries = sortedEntries();
    if (key === 'travel') return entries.filter((entry) => entry.kind === 'place');
    if (key === 'books') return entries.filter((entry) => entry.kind !== 'place' && new Date(entry.date).getFullYear() === year &&
      (kindFilter === 'all' || entry.kind === kindFilter) && (!query ||
        (entry.title + (entry.creator || '') + entry.category).toLowerCase().includes(query.toLowerCase())));
    if (key === 'search') return entries.filter((entry) =>
      (entry.title + (entry.creator || '') + (entry.category || '') + (entry.province || '') +
        (entry.city || '') + entry.notes).toLowerCase().includes(query.toLowerCase()));
    return entries;
  }
  function recordListHtml(key,entries,emptyTitle,emptySubtitle) {
    const shown = Math.min(recordLimits[key],entries.length);
    return '<div class="records" id="records-' + key + '">' +
      (entries.length ? entries.slice(0,shown).map(recordTile).join('') : empty(emptyTitle,emptySubtitle)) + '</div>' +
      (shown < entries.length ? '<button class="load-more" data-action="load-more" data-list="' + key + '">查看更多 · 还剩 ' +
        (entries.length - shown) + ' 条</button>' : '');
  }
  function loadMoreRecords(key,button) {
    if (!Object.prototype.hasOwnProperty.call(recordLimits,key)) return;
    const list = document.getElementById('records-' + key);
    if (!list) return;
    const entries = recordsForList(key);
    const start = Math.min(recordLimits[key],entries.length);
    const end = Math.min(start + 10,entries.length);
    list.insertAdjacentHTML('beforeend',entries.slice(start,end).map(recordTile).join(''));
    recordLimits[key] = end;
    if (end >= entries.length) button.remove();
    else button.textContent = '查看更多 · 还剩 ' + (entries.length - end) + ' 条';
  }
  function empty(title, subtitle) {
    return '<div class="card empty"><div class="empty-icon">🍃</div><strong>' + esc(title) + '</strong><span>' + esc(subtitle) + '</span></div>';
  }
  function homePage() {
    const recent = recordsForList('home');
    return '<section class="hero"><div class="eyebrow">YOUR JOURNEY · 0.2.2</div><h1>把喜欢的日子，<br>收进自己的归途。</h1>' +
      '<p>读过的书、看过的电影、去过的地方，都有迹可循。</p><button class="primary" data-action="add">＋ 记录这一刻</button></section>' +
      '<div class="stat-grid">' + statCard('book',C.count(snapshot.entries,'book'),'阅读记录','册') +
      statCard('film',C.count(snapshot.entries,'film'),'影视记录','部/季') +
      statCard('place',C.count(snapshot.entries,'place'),'旅途记录','次') + '</div>' +
      '<div class="section-head"><h2>最近记录</h2><button data-action="search">搜索全部</button></div>' +
      recordListHtml('home',recent,'从第一条记录开始','点按下方＋，留下此刻的书影与足迹');
  }
  function statCard(kind,value,label,unit) {
    return '<div class="card stat ' + kind + '" style="--count-digits:' + String(value).length + '"><span class="stat-icon">' + KIND_ICON[kind] + '</span><div class="label">' + label + '</div>' +
      '<div class="stat-value"><div class="num">' + value + '</div><small>' + unit + '</small></div></div>';
  }
  function chartPage() {
    const options = Array.from(new Set([new Date().getFullYear(), ...snapshot.entries.filter((x) => x.kind !== 'place').map((x) => new Date(x.date).getFullYear())])).sort((a,b) => b-a);
    const book = C.monthly(snapshot.entries,'book',year);
    const film = C.monthly(snapshot.entries,'film',year);
    const max = Math.max(1,...book,...film);
    const bars = book.map((value,index) => '<div class="bar-pair" title="' + (index+1) + '月 阅读' + value + ' 影视' + film[index] + '"><i class="bar book" style="height:' + (value/max*100) + '%"></i><i class="bar film" style="height:' + (film[index]/max*100) + '%"></i></div>').join('');
    const categoryBlock = (kind,color) => {
      const data = C.categories(snapshot.entries,kind,year);
      const values = Object.entries(data).sort((a,b) => b[1]-a[1]);
      const ceiling = Math.max(1,...values.map((x) => x[1]));
      return '<div class="card chart"><h3>' + (kind === 'book' ? '阅读类型' : '影视类型') + '</h3>' +
        (values.length ? values.map(([name,value]) => '<div class="category-row"><span>' + esc(name) + '</span><span class="category-track"><b style="width:' + (value/ceiling*100) + '%;background:' + color + '"></b></span><strong>' + value + '</strong></div>').join('') : '<p class="subtle">这一年还没有记录</p>') + '</div>';
    };
    const records = recordsForList('books');
    return '<h1 class="page-title">书影时光</h1><p class="subtle">看见每一年读过和看过的故事。</p>' +
      '<div class="chips">' + options.map((value) => '<button data-action="year" data-year="' + value + '" class="' + (year === value ? 'active' : '') + '">' + value + '</button>').join('') + '</div>' +
      '<div class="card chart"><h3>每月记录</h3><div class="bars">' + bars + '</div><div class="axis"><span>1月</span><span>3月</span><span>6月</span><span>9月</span><span>12月</span></div><div class="legend"><span><i class="book"></i>阅读 ' + book.reduce((a,b)=>a+b,0) + '</span><span><i class="film"></i>影视 ' + film.reduce((a,b)=>a+b,0) + '</span></div></div>' +
      categoryBlock('book','var(--orange)') + categoryBlock('film','var(--blue)') + yearlyChart() +
      '<div class="section-head"><h2>全部书影</h2><button data-action="search">搜索</button></div>' +
      '<div class="chips">' + [['all','全部'],['book','阅读'],['film','影视']].map(([value,label]) => '<button data-action="filter" data-filter="' + value + '" class="' + (kindFilter === value ? 'active' : '') + '">' + label + '</button>').join('') + '</div>' +
      (query ? '<p class="subtle">搜索：' + esc(query) + ' <button class="secondary" data-action="clear-search">清除</button></p>' : '') +
      recordListHtml('books',records,'这里还没有书影','点按＋添加第一条记录');
  }
  function yearlyChart() {
    const years = Array.from(new Set(snapshot.entries.filter((entry) => entry.kind !== 'place')
      .map((entry) => new Date(entry.date).getFullYear()).concat(new Date().getFullYear()))).sort((a,b) => a-b);
    const series = years.map((value) => ({year:value,
      book:C.count(snapshot.entries.filter((entry) => new Date(entry.date).getFullYear() === value),'book'),
      film:C.count(snapshot.entries.filter((entry) => new Date(entry.date).getFullYear() === value),'film')}));
    const ceiling = Math.max(1,...series.flatMap((point) => [point.book,point.film]));
    const x = (index) => 32 + index * (256 / Math.max(1,series.length - 1));
    const y = (value) => 112 - value / ceiling * 82;
    const path = (kind) => series.map((point,index) => (index ? 'L' : 'M') + x(index) + ',' + y(point[kind])).join(' ');
    return '<div class="card chart"><h3>年度阅读 / 观影趋势</h3><svg class="trend" viewBox="0 0 320 145" role="img" aria-label="年度阅读与观影数量趋势">' +
      '<path d="M32 112H288" class="trend-axis"/>' +
      '<path d="' + path('book') + '" class="trend-book"/><path d="' + path('film') + '" class="trend-film"/>' +
      series.map((point,index) => '<circle cx="' + x(index) + '" cy="' + y(point.book) + '" r="3" class="trend-book-dot"><title>' + point.year + ' 阅读 ' + point.book + '</title></circle>' +
        '<circle cx="' + x(index) + '" cy="' + y(point.film) + '" r="3" class="trend-film-dot"><title>' + point.year + ' 影视 ' + point.film + '</title></circle>').join('') +
      '</svg><div class="trend-labels"><span>' + years[0] + '</span><span>' + years[years.length - 1] + '</span></div></div>';
  }
  function cityVisits() {
    const visits = new Map();
    snapshot.entries.filter((entry) => entry.kind === 'place').forEach((entry) => {
      if (!entry.province || !entry.city) return;
      const key = entry.province + '|' + entry.city;
      const visit = visits.get(key) || {key,province:entry.province,city:entry.city,count:0};
      visit.count++;
      visits.set(key,visit);
    });
    return [...visits.values()].sort((a,b) => b.count-a.count || a.city.localeCompare(b.city,'zh'));
  }
  function travelPage() {
    const visits = cityVisits();
    const places = recordsForList('travel');
    return '<h1 class="page-title">旅途足迹</h1><p class="subtle">收藏途经的地方，也收藏一路上的心情。</p>' +
      '<div class="stat-grid travel-stats"><div class="card stat place"><div class="num">' + visits.length + '</div><div class="label">去过的城市</div></div>' +
      '<div class="card stat place"><div class="num">' + places.length + '</div><div class="label">旅途记录</div></div></div>' +
      '<div class="section-head map-heading"><h2>城市足迹</h2>' +
      (mapAk() ? '<button class="secondary" data-action="map-reset">查看全图</button>' : '') + '</div>' +
      '<p class="subtle map-load-status" id="marker-status" hidden></p>' +
      '<div class="map-frame" id="map-frame"><div class="map-canvas" id="map-canvas"></div>' +
      (mapAk() ? '<div class="map-shield" aria-hidden="true"></div><button class="map-exit" id="map-mode-button" data-action="map-toggle" aria-pressed="false">操作地图</button>' :
        '<div class="map-fallback"><div><strong>地图暂不可用</strong>下方足迹列表仍可正常使用。</div></div>') + '</div>' +
      '<div class="section-head"><h2>去过的城市</h2><span class="subtle">' + visits.length + ' 个</span></div>' +
      (visits.length ? '<div class="visit-grid">' + visits.map((visit) => '<button class="visit ' + (selectedRegion === visit.key ? 'selected' : '') +
        '" data-action="region" data-region="' + esc(visit.key) + '"><strong>' + esc(visit.city) + '</strong><small>' +
        esc(visit.province) + ' · ' + visit.count + ' 次记录</small></button>').join('') + '</div>' : empty('还没有城市足迹','添加地点记录，留下第一处足迹')) +
      '<div class="section-head"><h2>旅途记录</h2></div>' + recordListHtml('travel',places,'尚无旅途记录','点按＋记录一段旅程') +
      '<p class="footer-note">底图和城市指针来自百度地图；每座去过的城市只显示一个指针，记录次数见下方列表。</p>';
  }
  function settingsPage() {
    return '<h1 class="page-title">我的归途</h1><p class="subtle">掌管自己的记录、主题与备份。</p>' +
      '<div class="card pad profile-card"><span class="profile-avatar">' + icon('book') + '</span><div><div class="eyebrow">个人档案</div><h2>归途</h2>' +
      '<p class="subtle">' + snapshot.entries.length + ' 条记录 · 记录生活的每一刻</p></div></div>' +
      '<div class="settings-grid"><div class="card settings-row"><span class="settings-icon">' + icon('sun') + '</span><div><strong>深色模式</strong><small>跟随你的阅读习惯</small></div><button class="secondary" data-action="theme">' + (snapshot.darkMode ? '关闭' : '开启') + '</button></div>' +
      '<div class="card settings-row"><span class="settings-icon">' + icon('cloud') + '</span><div><strong>云端保存</strong><small>备份和恢复你的记录</small></div><button class="secondary" data-action="page" data-page="cloud">进入</button></div>' +
      '<div class="card settings-row"><span class="settings-icon">' + icon('help') + '</span><div><strong>更多帮助</strong><small>备份、换设备与导入导出</small></div><button class="secondary" data-action="page" data-page="help">查看</button></div></div>';
  }
  function cloudPage() {
    return '<button class="back-link" data-action="page" data-page="settings">‹ 返回我的</button><h1 class="page-title">云端保存</h1>' +
      '<p class="subtle">本机记录会留在当前设备。需要时手动保存到贴吧云端。</p>' +
      (localStorageArea === sessionStorage ?
        '<p class="note warn">当前环境未取得贴吧账号标识，记录只在本次打开期间暂存；无法确认这里的云端记录属于你的手机账号。</p>' : '') +
      '<div class="card pad"><strong>本周剩余云端保存次数：' + quota.remaining + ' / 5</strong>' +
      (uploadPhase ? '<p class="note" role="status">最近一次保存：' + esc(uploadPhase) +
        (uploadFinishedAt ? ' · ' + esc(uploadFinishedAt) : '。请保持归途打开，可浏览其他页面后返回查看。') + '</p>' : '') +
      '<p class="subtle">次数提醒可能因多设备同时使用而不准确。</p>' +
      (!cloud ? '<p class="note warn">当前未连接贴吧云端，可先管理本机备份。</p>' : '') +
      (cloudError ? '<p class="note warn">' + esc(cloudError) + '</p>' : '') +
      '<button class="primary wide" data-action="cloud-push" data-cloud-manage>保存到云端</button></div>' +
      '<div class="settings-grid"><div class="card settings-row"><div><strong>从云端下载到本机</strong><small>合并记录，不删除本机已有内容</small></div><button class="secondary" data-action="cloud-pull" data-cloud-manage>下载</button></div>' +
      '<div class="card settings-row"><div><strong>查看云端已保存数据</strong><small>查看记录数量和保存时间</small></div><button class="secondary" data-action="cloud-view" data-cloud-manage>查看</button></div>' +
      '<div class="card settings-row"><div><strong>删除云端数据</strong><small>只删除云端归途记录</small></div><button class="danger" data-action="cloud-delete" data-cloud-manage>删除</button></div>' +
      '<div class="card settings-row"><div><strong>本机数据管理</strong><small>复制备份、粘贴导入或清空</small></div><button class="secondary" data-action="page" data-page="local-data">进入</button></div></div>';
  }
  function localDataPage() {
    return '<button class="back-link" data-action="page" data-page="cloud">‹ 返回云端保存</button><h1 class="page-title">本机数据管理</h1>' +
      '<p class="subtle">备份文本可用于更换设备或恢复记录。</p><div class="settings-grid">' +
      '<div class="card settings-row"><div><strong>复制备份文本</strong><small>复制后请妥善保存在设备外</small></div><button class="secondary" data-action="export-text">复制</button></div>' +
      '<div class="card settings-row"><div><strong>粘贴导入</strong><small>检查格式后合并到本机</small></div><button class="secondary" data-action="import">导入</button></div>' +
      '<div class="card settings-row"><div><strong>清空本机记录</strong><small>不会删除云端已保存内容</small></div><button class="danger" data-action="clear">清空</button></div></div>';
  }
  function helpPage() {
    return '<button class="back-link" data-action="page" data-page="settings">‹ 返回我的</button><h1 class="page-title">更多帮助</h1>' +
      '<div class="card pad help-copy"><h2>如何备份、导入和导出数据</h2>' +
      '<p><strong>本机数据</strong>是保存在这台设备上的记录。换设备或清除贴吧数据前，先备份。</p>' +
      '<p><strong>云端保存</strong>会把本机记录复制到当前贴吧账号的云端，不会清掉本机内容。更换设备后，登录同一账号，在“云端保存”中下载；下载会合并记录。</p>' +
      '<p><strong>手动备份</strong>可在“云端保存 → 本机数据管理”复制备份文本，妥善保管。需要恢复时，在新设备粘贴导入。备份文本是归途记录的副本。</p>' +
      '<p>云端和本机各有一份记录。修改本机记录后，需要再次点“保存到云端”才会更新云端。</p></div>';
  }
  function pageBody() {
    if (tab === 'books') return chartPage();
    if (tab === 'travel') return travelPage();
    if (tab === 'settings') return settingsPage();
    if (tab === 'cloud') return cloudPage();
    if (tab === 'local-data') return localDataPage();
    if (tab === 'help') return helpPage();
    if (tab === 'search') return searchPage();
    return homePage();
  }
  function searchPage() {
    const records = recordsForList('search');
    return '<h1 class="page-title">搜索记录</h1><p class="subtle">关键词：' + esc(query) + '</p>' +
      '<button class="secondary" data-action="search">换个关键词</button><div class="section-head"><h2>搜索结果</h2><span class="subtle">' + records.length + ' 条</span></div>' +
      recordListHtml('search',records,'没有找到记录','换个关键词再试试');
  }
  function navButton(value, icon, label) {
    return '<button data-action="tab" data-tab="' + value + '" class="' + (tab === value || value === 'settings' && ['cloud','local-data','help'].includes(tab) ? 'active' : '') + '">' + icon + label + '</button>';
  }
  function currentTravelSignature() {
    return JSON.stringify(snapshot.entries.filter((entry) => entry.kind === 'place')
      .map((entry) => [entry.id,entry.province,entry.city,entry.title,entry.date]));
  }
  function refreshTravelContent() {
    const replacement = document.createElement('div');
    replacement.innerHTML = travelPage();
    const oldFrame = travelRoot.querySelector('#map-frame');
    replacement.querySelector('#map-frame').replaceWith(oldFrame);
    travelRoot.replaceChildren(...Array.from(replacement.childNodes));
    travelSignature = currentTravelSignature();
  }
  function render() {
    updateTheme();
    leaveMapMode();
    // Capture the page position before replacing DOM; keep it through modal rerenders.
    if (modal && !modalScrollPosition) {
      modalScrollPosition = {x:window.scrollX,y:window.scrollY};
      document.body.style.top = -modalScrollPosition.y + 'px';
      document.body.style.setProperty('--modal-scroll-y',modalScrollPosition.y + 'px');
      document.documentElement.classList.add('modal-open');
    }
    if (travelRoot?.parentElement && travelRoot.parentElement !== document.body) {
      travelRoot.classList.add('travel-cached');
      document.body.appendChild(travelRoot);
    }
    app.innerHTML = '<div class="app-shell"><header class="topbar"><div class="brand"><span class="brand-mark">归</span>归途</div>' +
      '<div class="top-actions"><span class="status-text" id="cloud-status"></span><button class="icon-btn" data-action="theme" aria-label="切换深色模式">' + icon(snapshot.darkMode ? 'sun' : 'moon') + '</button></div></header>' +
      '<main>' + (tab === 'travel' ? '<div id="travel-slot"></div>' : pageBody()) + '</main></div>' +
      '<nav class="nav" aria-label="主导航">' + navButton('home',icon('home'),'首页') + navButton('books',icon('book'),'书影') +
      '<button class="plus" data-action="add" aria-label="新增记录">' + icon('plus') + '</button>' + navButton('travel',icon('map'),'旅途') + navButton('settings',icon('person'),'我的') + '</nav>' +
      (modal ? modalHtml() : '');
    updateStatus();
    updateUploadWarning();
    if (tab === 'travel') {
      if (!travelRoot) {
        travelRoot = document.createElement('div');
        travelRoot.id = 'travel-content';
        travelRoot.innerHTML = travelPage();
        travelSignature = currentTravelSignature();
        document.getElementById('travel-slot').appendChild(travelRoot);
        if (mapAk()) initMap();
      } else {
        const changed = travelSignature !== currentTravelSignature();
        if (changed) refreshTravelContent();
        travelRoot.classList.remove('travel-cached');
        document.getElementById('travel-slot').appendChild(travelRoot);
        if (map && typeof map.checkResize === 'function') requestAnimationFrame(() => map?.checkResize());
        if (changed && map && window.BMap) {
          showCityMarkers(window.BMap,map);
        }
      }
    }
    if (!modal && modalScrollPosition) {
      const position = modalScrollPosition;
      modalScrollPosition = null;
      const root = document.documentElement;
      const behavior = root.style.scrollBehavior;
      root.style.scrollBehavior = 'auto';
      root.classList.remove('modal-open');
      document.body.style.removeProperty('top');
      document.body.style.removeProperty('--modal-scroll-y');
      window.scrollTo(position.x,position.y);
      root.style.scrollBehavior = behavior;
    }
  }

  function field(label,name,type,value,required,extra) {
    return '<div class="field"><label for="f-' + name + '">' + label + (required ? ' *' : '') + '</label><input id="f-' + name + '" name="' + name + '" type="' + type + '" value="' + esc(value || '') + '" ' + (required ? 'required ' : '') + (extra || '') + '></div>';
  }
  function selectField(label,name,values,selected) {
    return '<div class="field"><label for="f-' + name + '">' + label + '</label><select id="f-' + name + '" name="' + name + '">' +
      values.map((value) => '<option value="' + esc(value) + '" ' + (value === selected ? 'selected' : '') + '>' + esc(value) + '</option>').join('') + '</select></div>';
  }
  function modalHtml() {
    let title = '';
    let body = '';
    if (modal.type === 'choose') {
      title = '记录这一刻';
      body = '<div class="choice-grid">' + [['book','阅读','书籍、作者与完成日期'],['film','影视','片名、导演、类型与评分'],['place','地点','省市与抵达日期']]
        .map(([kind,label,sub]) => '<button class="choice" data-action="choose-kind" data-kind="' + kind + '"><span class="choice-icon">' + KIND_ICON[kind] + '</span><span><b>' + label + '</b><small>' + sub + '</small></span></button>').join('') + '</div>';
    } else if (modal.type === 'form') {
      const kind = modal.kind;
      title = '新增' + KIND_NAME[kind];
      body = '<form id="entry-form" data-kind="' + kind + '">' +
        (kind === 'place' ? selectField('省份 *','province',Object.keys(GUITU_REGIONS),Object.keys(GUITU_REGIONS)[0]) +
          selectField('城市 *','city',GUITU_REGIONS[Object.keys(GUITU_REGIONS)[0]],GUITU_REGIONS[Object.keys(GUITU_REGIONS)[0]][0]) :
          field(kind === 'book' ? '书籍名' : '影视名','title','text','',true,'maxlength="' + C.TEXT_LIMITS.title + '" placeholder="最多 ' + C.TEXT_LIMITS.title + ' 字"') +
          field(kind === 'book' ? '作者名' : '导演名','creator','text','',false,'maxlength="' + C.TEXT_LIMITS.creator + '" placeholder="最多 ' + C.TEXT_LIMITS.creator + ' 字"') +
          selectField('类型 *','category',kind === 'book' ? BOOK_CATEGORIES : FILM_CATEGORIES,kind === 'book' ? BOOK_CATEGORIES[0] : FILM_CATEGORIES[0])) +
        '<div class="form-row">' + field('完成 / 抵达日期','date','date',C.today(),true,'max="' + C.today() + '"') +
        (kind === 'place' ? selectField('旅途评分','rating',['1','2','3','4','5'],'4') : field(kind === 'book' ? '册数' : '季数','amount','number','1',true,'min="1" max="999"')) + '</div>' +
        (kind === 'place' ? '' : selectField('评分','rating',['1','2','3','4','5'],'4')) +
        '<button class="primary wide" type="submit">保存记录</button></form>';
    } else if (modal.type === 'detail') {
      const entry = snapshot.entries.find((x) => x.id === modal.id);
      if (!entry) { modal = null; return ''; }
      title = entry.title;
      body = '<p class="subtle">' + KIND_NAME[entry.kind] + ' · ' + esc(dateOnly(entry.date)) + ' · ' + entry.rating + '/5</p>' +
        '<p>' + esc([entry.province,entry.city,entry.creator,entry.category].filter(Boolean).join(' · ')) + '</p>' +
        '<div class="form-actions"><button class="secondary" data-action="close">返回</button><button class="danger" data-action="delete" data-id="' + esc(entry.id) + '">删除记录</button></div>';
    } else if (modal.type === 'search') {
      title = '搜索记录';
      body = '<form id="search-form">' + field('书名、片名或城市','query','search',query,false,'autofocus') + '<button class="primary wide">搜索</button></form>';
    } else if (modal.type === 'upload-warning') {
      title = '保存前请确认';
      const sizeText = modal.size == null ? '正在确认上传大小…' : '本次上传：' + formatUploadSize(modal.size);
      const sizeNote = modal.error || (modal.oversize ? '数据过大，无法上传。请先在本机数据管理中复制备份。' : '');
      body = '<p>记录由第三方托管。请勿上传涉政、侮辱、色情等违规内容，如有违反，相关后果由您自行承担。</p>' +
        '<p class="subtle">本机记录保留，保存成功才扣除本周次数。</p>' +
        '<p id="upload-size" class="note ' + (sizeNote ? 'warn' : '') + '" role="status"><strong>' + esc(sizeText) +
        '</strong><br>单次上限：' + (C.CLOUD_UPLOAD_LIMIT / 1000) + ' KB（压缩后上传大小）' +
        (sizeNote ? '<br>' + esc(sizeNote) : '') + '</p>' +
        '<button class="primary wide" id="upload-acknowledge" data-action="upload-acknowledge" disabled>正在确认上传大小…</button>';
    } else if (modal.type === 'import') {
      title = '导入备份';
      body = '<p class="subtle">把归途的备份文本粘贴到下方。导入前会检查内容，已有记录会保留。</p><form id="import-form">' +
        '<div class="field"><label for="f-import-json">备份文本</label><textarea id="f-import-json" name="json" class="import-text" placeholder="长按此处粘贴备份文本"></textarea></div>' +
        '<button class="secondary wide" type="button" data-action="paste-import">读取剪贴板</button>' +
        '<button class="primary wide" type="submit">检查并导入</button></form>';
    } else if (modal.type === 'export-text') {
      title = '复制备份文本';
      body = '<p class="subtle">复制后请妥善保管。恢复时可在“粘贴导入”中使用。</p>' +
        '<div class="field"><textarea id="export-json" class="backup-text" readonly>' + esc(JSON.stringify(snapshot,null,2)) + '</textarea></div>' +
        '<button class="primary wide" data-action="copy-export">复制全部</button>';
    } else if (modal.type === 'cloud-view') {
      title = '云端已保存数据';
      if (!modal.archive) body = '<p class="subtle">云端还没有保存归途记录。</p>';
      else {
        const rows = [['书籍',modal.archive.entries.filter((entry) => entry.kind === 'book').length],
          ['影视',modal.archive.entries.filter((entry) => entry.kind === 'film').length],
          ['旅途 / 地点',modal.archive.entries.filter((entry) => entry.kind === 'place').length]];
        const formatted = new Intl.DateTimeFormat('zh-CN',{timeZone:'Asia/Shanghai',year:'numeric',month:'2-digit',day:'2-digit',
          hour:'2-digit',minute:'2-digit',hour12:false}).format(new Date(modal.archive.updatedAt));
        body = '<div class="card pad summary-list">' + rows.map(([name,count]) =>
          '<div><span>' + name + '</span><strong>' + count + ' 条</strong></div>').join('') +
          '<div><span>最近保存时间</span><strong>' + esc(formatted) + '</strong></div></div>';
      }
    }
    return '<div class="modal-wrap" data-action="backdrop"><div class="modal" role="dialog" aria-modal="true" aria-label="' + esc(title) + '">' +
      '<div class="modal-head"><h2>' + esc(title) + '</h2><button class="icon-btn" data-action="close" aria-label="关闭">×</button></div>' + body + '</div></div>';
  }
  function leaveMapMode() {
    setMapMode(false);
  }
  function setMapMode(active) {
    mapActive = active;
    document.documentElement.classList.toggle('map-mode',active);
    document.getElementById('map-frame')?.classList.toggle('active',active);
    const button = document.getElementById('map-mode-button');
    if (button) {
      button.textContent = active ? '完成地图操作' : '操作地图';
      button.setAttribute('aria-pressed',String(active));
    }
    if (map) {
      if (active && typeof map.enableDragging === 'function') map.enableDragging();
      if (!active && typeof map.disableDragging === 'function') map.disableDragging();
      if (active && typeof map.enableScrollWheelZoom === 'function') map.enableScrollWheelZoom();
      if (!active && typeof map.disableScrollWheelZoom === 'function') map.disableScrollWheelZoom();
    }
  }
  function loadBaiduMap() {
    if (window.BMap) return Promise.resolve(window.BMap);
    if (mapLoading) return mapLoading;
    mapLoading = new Promise((resolve,reject) => {
      window.BMAP_PROTOCOL = 'https';
      window.BMapGL_loadScriptTime = Date.now();
      if (!document.querySelector('link[data-bmapgl-ui]')) {
        const style = document.createElement('link');
        style.rel = 'stylesheet';
        style.dataset.bmapglUi = '4.0';
        style.href = 'https://api.map.baidu.com/res/webgl/10/bmap-v4.css';
        document.head.appendChild(style);
      }
      const script = document.createElement('script');
      // The /api wrapper uses document.write, which browsers ignore for a script inserted after page load.
      script.src = 'https://api.map.baidu.com/getscript?v=4.0&ak=' + encodeURIComponent(mapAk()) + '&services=';
      script.onload = () => window.BMap ? resolve(window.BMap) : reject(new Error('地图脚本加载后未提供 BMap'));
      script.onerror = () => reject(new Error('百度地图脚本加载失败，请检查 AK 与 Referer 白名单'));
      document.head.appendChild(script);
    });
    mapLoading.catch(() => { mapLoading = null; });
    return mapLoading;
  }
  let currentCityVisits = new Map();
  function validCityPoint(value) {
    const lng = Number(value?.lng ?? value?.[0]);
    const lat = Number(value?.lat ?? value?.[1]);
    return Number.isFinite(lng) && Number.isFinite(lat) && lng >= 72 && lng <= 136 && lat >= 2 && lat <= 55
      ? [lng,lat] : null;
  }
  function cacheCityPoint(key,point) {
    cityPointCache.set(key,point);
  }
  function knownCityPoint(visit) {
    const capital = GUITU_REGIONS[visit.province]?.[0];
    const provinceCenter = capital === visit.city ? validCityPoint(GUITU_PROVINCE_POINTS[visit.province]) : null;
    return provinceCenter || validCityPoint(GUITU_CITY_POINTS[visit.key]);
  }
  function updateMarkerStatus() {
    const status = travelRoot?.querySelector('#marker-status');
    if (!status) return;
    const total = currentCityVisits.size;
    const shown = [...cityMarkers.keys()].filter((key) => currentCityVisits.has(key)).length;
    status.hidden = !total || shown === total;
    if (status.hidden) return;
    status.textContent = '已显示 ' + shown + ' / ' + total + ' 个城市指针。';
    if (geocodeQueue.length || activeGeocodes || pendingGeocodeRetries) status.textContent += '其余城市正在定位…';
    else {
      const missing = [...currentCityVisits.values()].filter((visit) => !cityMarkers.has(visit.key));
      status.textContent += '暂未定位：' + missing.slice(0,3).map((visit) => visit.city).join('、') +
        (missing.length > 3 ? '等城市。' : '。');
      const retry = document.createElement('button');
      retry.className = 'text-link';
      retry.dataset.action = 'retry-markers';
      retry.textContent = '重试';
      status.appendChild(retry);
    }
  }
  function addCityMarker(BMap,instance,visit,point) {
    if (cityMarkers.has(visit.key) || map !== instance || typeof BMap.Marker !== 'function') return;
    const marker = new BMap.Marker(new BMap.Point(point[0],point[1]));
    if (typeof marker.setTitle === 'function') marker.setTitle(visit.city + ' · ' + visit.count + ' 次记录');
    if (typeof marker.addEventListener === 'function') marker.addEventListener('click',() => {
      selectedRegion = visit.key;
      focusCity(visit.key);
      document.querySelectorAll('.visit').forEach((item) => item.classList.toggle('selected',item.dataset.region === visit.key));
    });
    instance.addOverlay(marker);
    cityMarkers.set(visit.key,marker);
    updateMarkerStatus();
  }
  function pumpCityGeocodes(BMap,instance) {
    if (map !== instance) return;
    if (typeof BMap.Geocoder !== 'function') {
      geocodeQueue.length = 0;
      queuedCities.clear();
      updateMarkerStatus();
      return;
    }
    while (activeGeocodes < 4 && geocodeQueue.length) {
      const {visit,attempt} = geocodeQueue.shift();
      if (!currentCityVisits.has(visit.key) || cityMarkers.has(visit.key)) {
        queuedCities.delete(visit.key);
        continue;
      }
      activeGeocodes++;
      let finished = false;
      const finish = (result) => {
        if (finished) return;
        finished = true;
        clearTimeout(timer);
        activeGeocodes--;
        const point = validCityPoint(result?.point || result);
        if (point) {
          queuedCities.delete(visit.key);
          cacheCityPoint(visit.key,point);
          const current = currentCityVisits.get(visit.key);
          if (current) addCityMarker(BMap,instance,current,point);
          if (selectedRegion === visit.key) focusCity(visit.key);
        } else if (attempt < 2 && currentCityVisits.has(visit.key)) {
          pendingGeocodeRetries++;
          setTimeout(() => {
            pendingGeocodeRetries--;
            if (map === instance && currentCityVisits.has(visit.key) && !cityMarkers.has(visit.key)) {
              geocodeQueue.push({visit,attempt:attempt+1});
              pumpCityGeocodes(BMap,instance);
            } else queuedCities.delete(visit.key);
            updateMarkerStatus();
          },attempt === 0 ? 1200 : 2500);
        } else queuedCities.delete(visit.key);
        updateMarkerStatus();
        pumpCityGeocodes(BMap,instance);
      };
      const timer = setTimeout(() => finish(null),10000);
      const address = attempt === 2 || visit.province === visit.city ? visit.city : visit.province + visit.city;
      try { new BMap.Geocoder().getPoint(address,finish,visit.city); }
      catch (_) { finish(null); }
    }
    updateMarkerStatus();
  }
  function showCityMarkers(BMap,instance) {
    if (typeof BMap.Marker !== 'function') return;
    if (markerMap !== instance) { cityMarkers.clear(); markerMap = instance; }
    const visits = cityVisits();
    currentCityVisits = new Map(visits.map((visit) => [visit.key,visit]));
    for (const [key,marker] of cityMarkers) {
      if (!currentCityVisits.has(key)) {
        if (typeof instance.removeOverlay === 'function') instance.removeOverlay(marker);
        cityMarkers.delete(key);
      }
    }
    visits.forEach((visit) => {
      const marker = cityMarkers.get(visit.key);
      if (marker) {
        if (typeof marker.setTitle === 'function') marker.setTitle(visit.city + ' · ' + visit.count + ' 次记录');
        return;
      }
      const point = cityPointCache.get(visit.key) || knownCityPoint(visit);
      if (point) addCityMarker(BMap,instance,visit,point);
      else if (!queuedCities.has(visit.key)) { queuedCities.add(visit.key); geocodeQueue.push({visit,attempt:0}); }
    });
    updateMarkerStatus();
    pumpCityGeocodes(BMap,instance);
  }
  function fitChinaViewport(BMap,instance) {
    const bounds = [new BMap.Point(72.5,2.5),new BMap.Point(135.5,54.5)];
    if (typeof instance.getViewport === 'function') {
      const viewport = instance.getViewport(bounds,{margins:[10,10,10,10]});
      if (viewport?.center && Number.isFinite(viewport.zoom)) {
        instance.centerAndZoom(viewport.center,viewport.zoom);
        return;
      }
    }
    if (typeof instance.setViewport === 'function') instance.setViewport(bounds,{margins:[10,10,10,10]});
    else instance.centerAndZoom(new BMap.Point(104,32),3);
  }
  async function initMap() {
    const canvas = document.getElementById('map-canvas');
    if (!canvas) return;
    const thisCanvas = canvas;
    const generation = mapGeneration;
    mapLoadAttempts++;
    document.getElementById('map-frame')?.classList.add('map-unavailable');
    const modeButton = document.getElementById('map-mode-button');
    if (modeButton) modeButton.hidden = true;
    canvas.innerHTML = '<div class="map-fallback">地图加载中…</div>';
    try {
      const BMap = await loadBaiduMap();
      if (document.getElementById('map-canvas') !== thisCanvas || generation !== mapGeneration) return;
      canvas.innerHTML = '';
      map = new BMap.Map(canvas,{
        minZoom:3,maxZoom:12,enableMapClick:false,enableRotate:false,enableTilt:false,
        enableRotateGestures:false,enableTiltGestures:false
      });
      mapLoadAttempts = 0;
      document.getElementById('map-frame')?.classList.remove('map-unavailable');
      if (modeButton) modeButton.hidden = false;
      fitChinaViewport(BMap,map);
      if (!mapActive && typeof map.disableDragging === 'function') map.disableDragging();
      if (!mapActive && typeof map.disableScrollWheelZoom === 'function') map.disableScrollWheelZoom();
      const currentMap = map;
      showCityMarkers(BMap,currentMap);
      if (selectedRegion) focusCity(selectedRegion);
      const frame = document.getElementById('map-frame');
      frame?.addEventListener('touchmove',(event) => { if (mapActive) event.stopPropagation(); },{passive:true});
      let resizeTimer;
      window.addEventListener('resize',() => {
        clearTimeout(resizeTimer);
        resizeTimer = setTimeout(() => {
          if (map !== currentMap || tab !== 'travel') return;
          if (typeof currentMap.checkResize === 'function') currentMap.checkResize();
          if (!selectedRegion) fitChinaViewport(BMap,currentMap);
        },150);
      });
    } catch (error) {
      if (document.getElementById('map-canvas') !== thisCanvas || generation !== mapGeneration) return;
      if (mapLoadAttempts < 2) {
        canvas.innerHTML = '<div class="map-fallback">地图连接较慢，正在重试…</div>';
        setTimeout(() => { if (!map && document.getElementById('map-canvas') === thisCanvas) initMap(); },2500);
      } else {
        document.getElementById('map-frame')?.classList.add('map-unavailable');
        canvas.innerHTML = '<div class="map-fallback"><div><strong>地图暂时无法加载</strong>' +
          '<button class="secondary" data-action="retry-map">重试地图</button><span>下方足迹列表仍可使用。</span></div></div>';
      }
    }
  }
  function focusCity(key) {
    if (!map || !window.BMap) return;
    const visit = currentCityVisits.get(key);
    if (!visit) return;
    const point = cityPointCache.get(key) || knownCityPoint(visit);
    if (!point) { showCityMarkers(window.BMap,map); return; }
    map.centerAndZoom(new window.BMap.Point(point[0],point[1]),7);
  }
  async function readCloudObject() {
    try {
      const remote = await downloadVerifiedCloud(15000);
      if (!C.isObject(remote)) throw new Error('invalid response');
      quota = C.quotaInfo(remote);
      return remote;
    } catch (_) { throw new Error('云端暂不可用，请稍后重试'); }
  }
  const formatUploadSize = (size) => (Math.ceil(size / 100) / 10).toFixed(1) + ' KB';
  function updateUploadWarning() {
    const button = document.getElementById('upload-acknowledge');
    if (!button) return;
    const left = Math.max(0,Math.ceil((warningReadyAt - Date.now()) / 1000));
    button.disabled = modal?.status !== 'ready' || modal.oversize || left > 0;
    button.textContent = modal?.status === 'loading' ? '正在确认上传大小…' :
      modal?.status === 'error' ? '暂时无法上传' : modal?.oversize ? '超过大小上限，无法上传' :
      '我已知晓，确认内容不含违规信息' + (left ? '（' + left + ' 秒）' : '');
  }
  function previewCloudUpload(remote) {
    const local = C.normalizeSnapshot(snapshot);
    const existing = remote[C.CLOUD_KEY] ? C.readCloudSnapshot(remote[C.CLOUD_KEY]) : null;
    const changed = JSON.stringify(remote[C.CLOUD_KEY] || null) !== cloudBase;
    const outgoing = changed && existing ? C.mergeSnapshots(local,existing) : local;
    outgoing.updatedAt = new Date().toISOString();
    outgoing.exportedAt = outgoing.updatedAt;
    const envelope = C.mergeCloudEnvelope(remote,outgoing);
    const allowance = C.quotaInfo(remote);
    if (!allowance.remaining) throw new Error('本周 5 次云端保存次数已用完，请下周再试');
    envelope[C.QUOTA_KEY] = {week:allowance.week,used:allowance.used + 1};
    return C.cloudUploadSize(envelope);
  }
  async function showUploadWarning() {
    if (!cloud || cloudBusy) { toast('云端暂不可用，请稍后重试'); return; }
    if (!quota.remaining && quota.week === C.weekKey()) { toast('本周 5 次云端保存次数已用完，请下周再试'); return; }
    warningReadyAt = Date.now() + 5000;
    const warning = {type:'upload-warning',status:'loading',size:null,oversize:false};
    modal = warning;
    cloudBusy = true;
    render();
    clearInterval(warningTimer);
    warningTimer = setInterval(() => {
      if (modal?.type !== 'upload-warning') { clearInterval(warningTimer); warningTimer = null; return; }
      updateUploadWarning();
    },250);
    try {
      const remote = await readCloudObject();
      if (modal !== warning) return;
      warning.size = previewCloudUpload(remote);
      warning.oversize = warning.size > C.CLOUD_UPLOAD_LIMIT;
      warning.status = 'ready';
    } catch (error) {
      if (modal !== warning) return;
      warning.status = 'error';
      warning.error = errorText(error);
    } finally {
      cloudBusy = false;
      if (modal === warning) render();
      else updateStatus();
    }
  }
  async function cloudOperation(label,work) {
    if (!cloud) { toast('请在贴吧中登录后使用云端保存'); return; }
    if (cloudBusy) return;
    cloudBusy = true;
    updateStatus();
    try { await work(); }
    catch (error) {
      cloudError = label + '失败：' + errorText(error);
      cloudState = 'error';
      if (label === '保存到云端') {
        uploadPhase = '失败：' + errorText(error);
        uploadFinishedAt = new Date().toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit'});
      }
      toast(cloudError);
    } finally {
      cloudBusy = false;
      updateStatus();
      if (tab === 'cloud') render();
    }
  }
  async function viewCloudArchive() {
    await cloudOperation('查看云端',async () => {
      const remote = await readCloudObject();
      let archive = null;
      if (remote[C.CLOUD_KEY]) {
        try { archive = C.readCloudSnapshot(remote[C.CLOUD_KEY]); }
        catch (_) { throw new Error('云端记录暂时无法读取，请联系开发者'); }
      }
      modal = {type:'cloud-view',archive};
      cloudError = '';
      render();
    });
  }
  async function pullCloudArchive() {
    await cloudOperation('下载云端记录',async () => {
      const remote = await readCloudObject();
      if (!C.isObject(remote[C.CLOUD_KEY])) throw new Error('云端还没有归途记录');
      let incoming;
      try { incoming = C.readCloudSnapshot(remote[C.CLOUD_KEY]); }
      catch (_) { throw new Error('云端记录暂时无法读取，请联系开发者'); }
      const merged = C.mergeSnapshots(snapshot,incoming);
      const added = merged.entries.length - snapshot.entries.length;
      if (!window.confirm('将云端 ' + incoming.entries.length + ' 条记录合并到本机，新增 ' + added +
          ' 条。本机已有记录（包括同一记录的本机修改）会保留，不会覆盖。继续吗？')) return;
      if (added) {
        snapshot = merged;
        snapshot.updatedAt = new Date().toISOString();
        snapshot.exportedAt = snapshot.updatedAt;
        dirty = true;
        storageWrite();
      }
      cloudBase = JSON.stringify(remote[C.CLOUD_KEY]);
      cloudState = sameArchiveContent(snapshot,incoming) ? 'ok' : 'pending';
      cloudError = '';
      modal = null;
      render();
      toast(added ? '已从云端合并 ' + added + ' 条记录' : '本机已有这些记录，无需添加');
    });
  }
  async function pushLocalArchive() {
    await cloudOperation('保存到云端',async () => {
      uploadPhase = '正在准备'; uploadFinishedAt = '';
      if (tab === 'cloud') render();
      const localCopy = C.normalizeSnapshot(snapshot);
      const before = await readCloudObject();
      const allowance = C.quotaInfo(before);
      let existing = null;
      if (before[C.CLOUD_KEY]) {
        try { existing = C.readCloudSnapshot(before[C.CLOUD_KEY]); }
        catch (_) { throw new Error('云端记录暂时无法读取，请联系开发者'); }
      }
      const changedElsewhere = JSON.stringify(before[C.CLOUD_KEY] || null) !== cloudBase;
      if (existing && !changedElsewhere && sameArchiveContent(localCopy,existing)) {
        cloudState = 'ok';
        cloudError = '';
        toast('云端已有最新记录，无需再次保存');
        uploadPhase = '云端已有最新记录';
        uploadFinishedAt = new Date().toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit'});
        return;
      }
      if (!allowance.remaining) throw new Error('本周 5 次云端保存次数已用完，请下周再试');
      const outgoing = changedElsewhere && existing ? C.mergeSnapshots(localCopy,existing) : localCopy;
      C.validateSnapshotText(outgoing);
      const extra = outgoing.entries.length - localCopy.entries.length;
      const message = '将本机 ' + localCopy.entries.length + ' 条记录保存到云端。' +
        (changedElsewhere ? '云端近期有其他修改，将保留云端独有的 ' + extra + ' 条记录。' :
          existing ? '云端现有 ' + existing.entries.length + ' 条记录会更新为本机内容。' : '云端将新增这份存档。') +
        '本机记录不会改变，本周次数将减少 1 次。继续吗？';
      if (!window.confirm(message)) return;
      const latest = await readCloudObject();
      if (JSON.stringify(latest) !== JSON.stringify(before)) throw new Error('云端内容刚刚变化，请重新操作');
      outgoing.updatedAt = new Date().toISOString();
      outgoing.exportedAt = outgoing.updatedAt;
      cloudState = 'saving';
      uploadPhase = '正在准备保存';
      updateStatus();
      if (tab === 'cloud') render();
      const beforeWrite = await readCloudObject();
      if (JSON.stringify(beforeWrite) !== JSON.stringify(latest)) throw new Error('云端内容刚刚变化，请重新操作');
      const envelope = C.mergeCloudEnvelope(latest,outgoing);
      envelope[C.QUOTA_KEY] = {week:allowance.week,used:allowance.used + 1};
      C.assertCloudFits(envelope);
      cloudState = 'saving';
      uploadPhase = '正在写入云端';
      updateStatus();
      if (tab === 'cloud') render();
      try { await cloud.uploadData(envelope); }
      catch (error) {
        if (error?.httpStatus === 414) throw new Error('记录超出平台云端保存容量，请先通过本机数据管理备份，本机记录不会改变');
        throw new Error('云端暂时无法保存，请稍后重试');
      }
      let verified;
      try { verified = await readCloudObject(); }
      catch (_) { throw new Error('保存结果暂无法确认，请先查看云端数据'); }
      const verifiedSnapshot = C.isObject(verified[C.CLOUD_KEY]) ? C.readCloudSnapshot(verified[C.CLOUD_KEY]) : null;
      if (!verifiedSnapshot || verifiedSnapshot.updatedAt !== outgoing.updatedAt ||
          !sameArchiveContent(verifiedSnapshot,outgoing) ||
          C.quotaInfo(verified).used !== allowance.used + 1) throw new Error('保存结果暂无法确认，请先查看云端数据');
      cloudBase = JSON.stringify(verified[C.CLOUD_KEY]);
      dirty = !sameArchiveContent(snapshot,outgoing);
      cloudState = dirty ? 'pending' : 'ok';
      uploadPhase = '已保存到云端';
      uploadFinishedAt = new Date().toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit'});
      cloudError = '';
      storageWrite();
      render();
      toast(extra ? '已保存到云端，并保留另外 ' + extra + ' 条；可下载合并到本机' :
        '已保存到云端，本机记录保持不变');
    });
  }
  async function deleteCloudArchive() {
    await cloudOperation('删除云端数据',async () => {
      const before = await readCloudObject();
      if (!Object.prototype.hasOwnProperty.call(before,C.CLOUD_KEY)) {
        toast('云端还没有归途记录');
        return;
      }
      let count;
      try { count = C.readCloudSnapshot(before[C.CLOUD_KEY]).entries.length; }
      catch (_) { throw new Error('云端记录暂时无法读取，请联系开发者'); }
      if (!window.confirm('确定删除云端的 ' + count + ' 条归途记录吗？本机记录仍会保留。删除云端后，如需恢复，请再次手动保存到云端。')) return;
      const latest = await readCloudObject();
      if (JSON.stringify(latest) !== JSON.stringify(before)) throw new Error('云端内容刚刚变化，请重新操作');
      const remaining = Object.assign({},latest);
      delete remaining[C.CLOUD_KEY];
      try { await cloud.uploadData(remaining); }
      catch (_) { throw new Error('云端暂时无法删除，请稍后重试'); }
      let verified;
      try { verified = await readCloudObject(); }
      catch (_) { throw new Error('删除结果暂无法确认，请稍后查看'); }
      if (Object.prototype.hasOwnProperty.call(verified,C.CLOUD_KEY)) throw new Error('删除结果暂无法确认，请稍后查看');
      cloudBase = JSON.stringify(null);
      dirty = true;
      cloudState = 'local';
      cloudError = '';
      storageWrite();
      render();
      toast('云端记录已删除，本机记录仍在');
    });
  }
  // The fixed body also locks older iOS WebViews; the backdrop must not pan it.
  app.addEventListener('touchmove',(event) => {
    if (modal && !event.target.closest('.modal')) event.preventDefault();
  },{passive:false});
  app.addEventListener('click',async (event) => {
    const target = event.target.closest('[data-action]');
    if (!target) return;
    const action = target.dataset.action;
    if (action === 'backdrop' && event.target !== target) return;
    if (action === 'close' || action === 'backdrop') { modal = null; clearInterval(warningTimer); warningTimer = null; render(); return; }
    if (action === 'tab') { leaveMapMode(); tab = target.dataset.tab; if (recordLimits[tab]) recordLimits[tab] = 10; modal = null; render(); window.scrollTo(0,0); return; }
    if (action === 'page') { tab = target.dataset.page; modal = null; render(); window.scrollTo(0,0); return; }
    if (action === 'add') { modal = {type:'choose'}; render(); return; }
    if (action === 'choose-kind') { modal = {type:'form',kind:target.dataset.kind}; render(); return; }
    if (action === 'detail') { modal = {type:'detail',id:target.dataset.id}; render(); return; }
    if (action === 'search') { modal = {type:'search'}; render(); return; }
    if (action === 'clear-search') { query = ''; recordLimits.books = 10; render(); return; }
    if (action === 'year') { year = Number(target.dataset.year); recordLimits.books = 10; render(); return; }
    if (action === 'filter') { kindFilter = target.dataset.filter; recordLimits.books = 10; render(); return; }
    if (action === 'region') { selectedRegion = target.dataset.region; document.querySelectorAll('.visit').forEach((item) => item.classList.toggle('selected',item.dataset.region === selectedRegion)); focusCity(selectedRegion); return; }
    if (action === 'map-toggle') { setMapMode(!mapActive); return; }
    if (action === 'map-reset') { if (map && window.BMap) { selectedRegion = ''; document.querySelectorAll('.visit').forEach((item) => item.classList.remove('selected')); fitChinaViewport(window.BMap,map); } return; }
    if (action === 'retry-map') { if (!map) { mapLoadAttempts = 2; initMap(); } return; }
    if (action === 'load-more') { loadMoreRecords(target.dataset.list,target); return; }
    if (action === 'retry-markers') { if (map && window.BMap) showCityMarkers(window.BMap,map); return; }
    if (action === 'import' || action === 'export-text') { modal = {type:action}; render(); return; }
    if (action === 'paste-import') {
      const area = document.getElementById('f-import-json');
      if (!area) return;
      try {
        if (!navigator.clipboard?.readText) throw new Error('当前贴吧版本未开放剪贴板读取');
        const content = await navigator.clipboard.readText();
        if (!content.trim()) throw new Error('剪贴板为空');
        area.value = content;
        area.focus();
        toast('已读取剪贴板，可确认导入');
      } catch (error) { area.focus(); toast('请长按输入框选择“粘贴”：' + errorText(error)); }
      return;
    }
    if (action === 'copy-export') {
      const area = document.getElementById('export-json');
      if (!area) return;
      try { await navigator.clipboard.writeText(area.value); toast('备份文本已复制'); }
      catch (_) { area.select(); toast(document.execCommand('copy') ? '备份文本已复制' : '请手动全选并复制'); }
      return;
    }
    if (action === 'theme') { snapshot.darkMode = !snapshot.darkMode; markChanged(); return; }
    if (action === 'cloud-view') { await viewCloudArchive(); return; }
    if (action === 'cloud-pull') { await pullCloudArchive(); return; }
    if (action === 'cloud-push') { showUploadWarning(); return; }
    if (action === 'upload-acknowledge') {
      if (modal?.type !== 'upload-warning' || modal.status !== 'ready' || modal.oversize || Date.now() < warningReadyAt) return;
      clearInterval(warningTimer); warningTimer = null; modal = null; render();
      await pushLocalArchive(); return;
    }
    if (action === 'cloud-delete') { await deleteCloudArchive(); return; }
    if (action === 'delete') {
      const entry = snapshot.entries.find((x) => x.id === target.dataset.id);
      if (!entry || !window.confirm('确定删除“' + entry.title + '”吗？')) return;
      snapshot.entries = snapshot.entries.filter((x) => x.id !== entry.id);
      modal = null; markChanged(); toast('记录已删除'); return;
    }
    if (action === 'clear') {
      if (!window.confirm('确定清空本机全部阅读、影视和旅途记录吗？云端已保存的记录不会删除。本机清空后可从云端下载恢复。')) return;
      snapshot.entries = []; markChanged(); toast('全部记录已清空');
    }
  });
  app.addEventListener('change',(event) => {
    if (event.target.name !== 'province') return;
    const city = document.getElementById('f-city');
    if (!city) return;
    city.innerHTML = (GUITU_REGIONS[event.target.value] || []).map((value) => '<option value="' + esc(value) + '">' + esc(value) + '</option>').join('');
  });
  app.addEventListener('submit',async (event) => {
    event.preventDefault();
    const form = event.target;
    const fields = new FormData(form);
    try {
      if (form.id === 'entry-form') {
        const kind = form.dataset.kind;
        const date = String(fields.get('date'));
        if (date > C.today()) throw new Error('日期不能晚于今天');
        const city = String(fields.get('city') || '');
        const detail = String(fields.get('detail') || '').trim();
        const entry = C.normalizeEntry({
          kind, id:Date.now() + '-' + Math.random().toString(36).slice(2),
          title:kind === 'place' ? city + (detail ? ' · ' + detail : '') : fields.get('title'),
          category:fields.get('category'),creator:fields.get('creator'),
          province:fields.get('province'),city,detail,
          expense:fields.get('expense'),date:date + 'T12:00:00',
          rating:fields.get('rating'),amount:fields.get('amount'),notes:fields.get('notes'),
          createdAt:new Date().toISOString()
        });
        C.validateEntryText(entry);
        snapshot.entries.unshift(entry); modal = null; markChanged(); toast('记录已保存');
      } else if (form.id === 'search-form') {
        query = String(fields.get('query') || '').trim(); recordLimits.search = 10; tab = 'search'; modal = null; render();
      } else if (form.id === 'import-form') {
        const pasted = String(fields.get('json') || '').trim();
        if (!pasted) throw new Error('请先粘贴备份文本');
        let parsed;
        try { parsed = JSON.parse(pasted); } catch (_) { throw new Error('备份文本格式不正确，原有记录未改变'); }
        const imported = C.validateSnapshotText(C.normalizeSnapshot(parsed));
        const merged = C.mergeSnapshots(snapshot,imported);
        const added = merged.entries.length - snapshot.entries.length;
        if (!window.confirm('备份中有 ' + imported.entries.length + ' 条记录，将新增 ' + added +
            ' 条到本机。原有记录会保留，云端不会自动更新。继续吗？')) return;
        if (added) { snapshot = merged; modal = null; markChanged(); }
        else { modal = null; render(); }
        toast(added ? '已导入 ' + added + ' 条记录' : '本机已有这些记录');
      }
    } catch (error) { toast('操作失败：' + String(error.message || error)); }
  });
  document.addEventListener('keydown',(event) => {
    if (event.key === 'Escape') {
      if (mapActive) setMapMode(false);
      else if (modal) { modal = null; render(); }
    }
  });
  document.addEventListener('visibilitychange',() => { if (document.hidden && mapActive) setMapMode(false); });
  boot();
})();
