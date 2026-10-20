/* Data model compatible with the v0.2.2 Flutter JSON export. */
const GuituCore = (() => {
  const cloudCodec = typeof GuituCloudCodec !== 'undefined' ? GuituCloudCodec : require('./cloud-codec.js');
  const SCHEMA = 'guitu.archive.v1';
  const CLOUD_KEY = 'guitu_v022';
  const QUOTA_KEY = 'guitu_save_quota_v1';
  const KINDS = ['book', 'film', 'place'];
  const TEXT_LIMITS = {title:60,creator:30};
  const today = () => {
    const date = new Date();
    return [date.getFullYear(), String(date.getMonth() + 1).padStart(2,'0'), String(date.getDate()).padStart(2,'0')].join('-');
  };
  const isObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
  const clamp = (value, min, max, fallback) => {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.min(max, Math.max(min, Math.round(parsed))) : fallback;
  };
  const safeDate = (value) => {
    const date = new Date(value || '');
    return Number.isFinite(date.getTime()) ? date.toISOString() : new Date().toISOString();
  };
  const safeCalendarDate = (value) => {
    const day = String(value || '').slice(0,10);
    const date = new Date(day + 'T12:00:00');
    return /^\d{4}-\d{2}-\d{2}$/.test(day) && Number.isFinite(date.getTime()) &&
      [date.getFullYear(),String(date.getMonth()+1).padStart(2,'0'),String(date.getDate()).padStart(2,'0')].join('-') === day
      ? day + 'T12:00:00' : today() + 'T12:00:00';
  };
  const emptySnapshot = () => ({
    schema: SCHEMA,
    exportedAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    userName: '我的归途',
    darkMode: false,
    avatarIndex: 0,
    entries: []
  });
  function normalizeEntry(input) {
    if (!isObject(input) || !KINDS.includes(input.kind)) throw new Error('记录类型无效');
    const title = String(input.title || '').trim();
    if (!title) throw new Error('记录名称不能为空');
    const expense = input.expense === null || input.expense === undefined || input.expense === ''
      ? null : Number(input.expense);
    if (expense !== null && (!Number.isFinite(expense) || expense < 0)) throw new Error('消费金额无效');
    const entry = {
      id: String(input.id || (Date.now() + '-' + Math.random().toString(36).slice(2))),
      kind: input.kind,
      title,
      date: safeCalendarDate(input.date),
      rating: clamp(input.rating, 1, 5, 4),
      amount: input.kind === 'place' ? 1 : clamp(input.amount, 1, 999, 1),
      creator: input.creator ? String(input.creator).trim() : null,
      province: input.province ? String(input.province).trim() : null,
      city: input.city ? String(input.city).trim() : null,
      detail: input.detail ? String(input.detail).trim() : null,
      expense,
      notes: String(input.notes || '').trim(),
      createdAt: safeDate(input.createdAt)
    };
    if (input.kind !== 'place') entry.category = String(input.category || '其他').trim() || '其他';
    if (input.kind === 'place' && (!entry.province || !entry.city)) throw new Error('地点缺少省市');
    return entry;
  }
  function normalizeSnapshot(input) {
    const source = Array.isArray(input) ? {entries: input} : input;
    if (!isObject(source)) throw new Error('不是有效的归途 JSON 存档');
    if (source.schema && source.schema !== SCHEMA) throw new Error('不支持的存档版本');
    if (!Array.isArray(source.entries)) throw new Error('存档缺少 entries 数组');
    const result = emptySnapshot();
    result.userName = String(source.userName || result.userName).trim().slice(0, 24) || result.userName;
    result.darkMode = source.darkMode === true;
    result.avatarIndex = clamp(source.avatarIndex, 0, 3, 0);
    result.entries = source.entries.map(normalizeEntry);
    result.updatedAt = safeDate(source.updatedAt || source.exportedAt);
    result.exportedAt = safeDate(source.exportedAt);
    return result;
  }
  function validateEntryText(entry) {
    if (entry.kind === 'place') return entry;
    const titleLabel = entry.kind === 'book' ? '书籍名' : '影视名';
    const creatorLabel = entry.kind === 'book' ? '作者名' : '导演名';
    if (String(entry.title || '').trim().length > TEXT_LIMITS.title)
      throw new Error(titleLabel + '最多 ' + TEXT_LIMITS.title + ' 字');
    if (String(entry.creator || '').trim().length > TEXT_LIMITS.creator)
      throw new Error(creatorLabel + '最多 ' + TEXT_LIMITS.creator + ' 字');
    return entry;
  }
  function validateSnapshotText(snapshot) {
    snapshot.entries.forEach((entry,index) => {
      try { validateEntryText(entry); }
      catch (error) { throw new Error('第 ' + (index + 1) + ' 条记录：' + error.message); }
    });
    return snapshot;
  }
  const count = (entries, kind) => entries.filter((entry) => entry.kind === kind)
    .reduce((sum, entry) => sum + (kind === 'place' ? 1 : entry.amount), 0);
  const monthly = (entries, kind, year) => Array.from({length: 12}, (_, month) =>
    entries.filter((entry) => entry.kind === kind && new Date(entry.date).getFullYear() === year && new Date(entry.date).getMonth() === month)
      .reduce((sum, entry) => sum + (kind === 'place' ? 1 : entry.amount), 0));
  const categories = (entries, kind, year) => entries
    .filter((entry) => entry.kind === kind && (!year || new Date(entry.date).getFullYear() === year))
    .reduce((result, entry) => {
      const label = entry.category || '其他';
      result[label] = (result[label] || 0) + entry.amount;
      return result;
    }, {});
  function mergeCloudEnvelope(remote, snapshot) {
    if (!isObject(remote)) throw new Error('云端返回值不是对象，已停止写入');
    return Object.assign({}, remote, {[CLOUD_KEY]: cloudCodec.encode(validateSnapshotText(normalizeSnapshot(snapshot)))});
  }
  const readCloudSnapshot = (value) => normalizeSnapshot(cloudCodec.decode(value));
  const assertCloudFits = (envelope) => cloudCodec.assertFits(envelope);
  const cloudUploadSize = (envelope) => cloudCodec.encodedSize(envelope);
  const CLOUD_UPLOAD_LIMIT = cloudCodec.MAX_ENCODED_PAYLOAD;
  function mergeSnapshots(local, remote) {
    const left = normalizeSnapshot(local);
    const right = normalizeSnapshot(remote);
    const ids = new Set(left.entries.map((entry) => entry.id));
    return {...left, entries:left.entries.concat(right.entries.filter((entry) => !ids.has(entry.id)))};
  }
  function weekKey(date = new Date()) {
    const china = new Date(date.getTime() + 8 * 3600000);
    const day = china.getUTCDay() || 7;
    china.setUTCDate(china.getUTCDate() - day + 1);
    return china.toISOString().slice(0,10);
  }
  function quotaInfo(remote, date = new Date()) {
    const week = weekKey(date);
    const saved = isObject(remote) && isObject(remote[QUOTA_KEY]) ? remote[QUOTA_KEY] : {};
    const used = saved.week === week && Number.isInteger(saved.used) ? Math.max(0,saved.used) : 0;
    return {week, used, remaining:Math.max(0,5-used)};
  }
  return {SCHEMA, CLOUD_KEY, QUOTA_KEY, KINDS, TEXT_LIMITS, today, isObject, emptySnapshot, normalizeEntry,
    normalizeSnapshot, validateEntryText, validateSnapshotText, mergeSnapshots, weekKey, quotaInfo,
    count, monthly, categories, mergeCloudEnvelope, readCloudSnapshot, assertCloudFits,
    cloudUploadSize, CLOUD_UPLOAD_LIMIT};
})();
if (typeof module !== 'undefined' && module.exports) module.exports = GuituCore;
