const test = require('node:test');
const assert = require('node:assert/strict');
const C = require('../src/core.js');

const originalExport = {
  schema: 'guitu.archive.v1', exportedAt: '2026-09-20T12:00:00',
  userName: '小归', darkMode: true, avatarIndex: 2,
  entries: [
    {id:'1',kind:'book',title:'山海',category:'小说',date:'2026-09-01T00:00:00',
      rating:5,amount:2,creator:'作者',notes:'喜欢',createdAt:'2026-09-01T12:00:00'},
    {id:'2',kind:'film',title:'星空',category:'科幻',date:'2026-09-04T00:00:00',
      rating:4,amount:3,creator:'导演',notes:'',createdAt:'2026-09-04T12:00:00'},
    {id:'3',kind:'place',title:'杭州市 · 西湖',date:'2026-08-02T00:00:00',
      rating:5,amount:1,province:'浙江省',city:'杭州市',detail:'西湖',expense:120.5,
      notes:'晴天',createdAt:'2026-08-02T12:00:00'}
  ]
};

test('reads v0.2.2 Android export without changing record meaning', () => {
  const snapshot = C.normalizeSnapshot(originalExport);
  assert.equal(snapshot.userName,'小归');
  assert.equal(snapshot.darkMode,true);
  assert.equal(snapshot.avatarIndex,2);
  assert.equal(snapshot.entries[2].province,'浙江省');
  assert.equal(snapshot.entries[2].expense,120.5);
  assert.equal(snapshot.entries[2].category,undefined);
  assert.equal(snapshot.entries[0].date.slice(0,10),'2026-09-01');
  assert.equal(C.count(snapshot.entries,'book'),2);
  assert.equal(C.count(snapshot.entries,'film'),3);
  assert.equal(C.count(snapshot.entries,'place'),1);
  assert.equal(C.monthly(snapshot.entries,'book',2026)[8],2);
  assert.deepEqual(C.categories(snapshot.entries,'film',2026),{科幻:3});
});

test('merges own cloud key while preserving other platform data', () => {
  const remote = {otherGame:{score:10},unknown:'keep'};
  const merged = C.mergeCloudEnvelope(remote,originalExport);
  assert.deepEqual(merged.otherGame,{score:10});
  assert.equal(merged.unknown,'keep');
  assert.equal(C.readCloudSnapshot(merged[C.CLOUD_KEY]).entries.length,3);
  assert.equal(remote[C.CLOUD_KEY],undefined);
});

test('rejects invalid import before it replaces an existing archive', () => {
  assert.throws(() => C.normalizeSnapshot({schema:'wrong',entries:[]}),/版本/);
  assert.throws(() => C.normalizeSnapshot({entries:[{kind:'place',title:'无城市'}]}),/省市/);
  assert.throws(() => C.normalizeSnapshot({entries:[{kind:'book',title:''}]}),/名称/);
});

test('merges new records while preserving local edits to matching IDs', () => {
  const local = C.normalizeSnapshot(originalExport);
  const remote = C.normalizeSnapshot(originalExport);
  remote.entries[0].title = '另一设备的修改';
  remote.entries.push({...remote.entries[0],id:'remote-only',title:'云端新增'});
  const merged = C.mergeSnapshots(local,remote);
  assert.equal(merged.entries.length,4);
  assert.equal(merged.entries[0].title,'山海');
  assert.equal(merged.entries[3].title,'云端新增');
});

test('weekly count resets on Monday in China time', () => {
  const sunday = new Date('2026-09-27T15:59:00Z');
  const monday = new Date('2026-09-27T16:01:00Z');
  const remote = {[C.QUOTA_KEY]:{week:C.weekKey(sunday),used:5}};
  assert.equal(C.quotaInfo(remote,sunday).remaining,0);
  assert.equal(C.quotaInfo(remote,monday).remaining,5);
});

test('limits book and film text at entry, import and cloud boundaries without truncating saved data', () => {
  for (const kind of ['book','film']) {
    const valid = C.normalizeEntry({kind,title:'书'.repeat(60),creator:'名'.repeat(30)});
    assert.equal(C.validateEntryText(valid),valid);
    assert.throws(() => C.validateEntryText({...valid,title:'书'.repeat(61)}),/最多 60 字/);
    assert.throws(() => C.validateEntryText({...valid,creator:'名'.repeat(31)}),/最多 30 字/);
    const legacy = C.normalizeSnapshot({entries:[{...valid,title:'书'.repeat(61)}]});
    assert.equal(legacy.entries[0].title.length,61);
    assert.throws(() => C.validateSnapshotText(legacy),/第 1 条记录/);
    assert.throws(() => C.mergeCloudEnvelope({},legacy),/最多 60 字/);
    assert.equal(legacy.entries[0].title.length,61);
  }
});
