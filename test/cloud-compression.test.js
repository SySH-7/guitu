const test = require('node:test');
const assert = require('node:assert/strict');
const C = require('../src/core.js');
const G = require('../src/cloud-codec.js');
const P = require('../vendor/pako.min.js');
const {largeArchive} = require('./large-fixtures.js');

test('cloud storage is compressed, preserves platform metadata and all record values', () => {
  const snapshot = largeArchive(100);
  snapshot.entries[0].notes = '旧记录备注：晴天 🌞';
  snapshot.entries[0].detail = '保留内容';
  snapshot.entries[0].expense = 12.5;
  const before = JSON.stringify(snapshot);
  const remote = {other:{unchanged:true},[C.QUOTA_KEY]:{week:C.weekKey(),used:2}};
  const envelope = C.mergeCloudEnvelope(remote,snapshot);
  assert.equal(envelope[C.CLOUD_KEY].encoding,G.ENCODING);
  assert.equal(envelope[C.CLOUD_KEY].entries,undefined);
  assert.deepEqual(C.readCloudSnapshot(envelope[C.CLOUD_KEY]),snapshot);
  assert.deepEqual(envelope.other,remote.other);
  assert.deepEqual(envelope[C.QUOTA_KEY],remote[C.QUOTA_KEY]);
  assert.equal(JSON.stringify(snapshot),before,'encoding must not mutate local records');
  C.assertCloudFits(envelope);
});

test('large, varied archives remain lossless even when their encoded transport exceeds capacity', () => {
  for (const perKind of [300,500]) {
    const snapshot = largeArchive(perKind);
    const envelope = C.mergeCloudEnvelope({},snapshot);
    assert.deepEqual(C.readCloudSnapshot(envelope[C.CLOUD_KEY]),snapshot);
    assert.equal(new Set(snapshot.entries.map(e=>e.id)).size,perKind*3);
    assert.throws(()=>C.assertCloudFits(envelope),/超出云端保存容量/);
  }
});

test('corrupted, truncated and unsupported compressed data are rejected', () => {
  const value = G.encode(largeArchive(1));
  assert.throws(()=>G.decode({...value,encoding:'unsupported'}),/不支持/);
  assert.throws(()=>G.decode({...value,data:'broken!'}),/格式/);
  assert.throws(()=>G.decode({...value,data:value.data.slice(0,-12)}),/损坏/);
  const bytes = Uint8Array.from(atob(value.data.replace(/-/g,'+').replace(/_/g,'/')),c=>c.charCodeAt(0));
  bytes[bytes.length-1] ^= 1;
  const broken = btoa(String.fromCharCode(...bytes)).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
  assert.throws(()=>G.decode({...value,data:broken}),/损坏/);
});

test('decompression is stopped before oversized output is accepted', () => {
  const compressed = P.deflate('x'.repeat(G.MAX_DECODED_BYTES + 1));
  const data = btoa(String.fromCharCode(...compressed)).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
  assert.throws(()=>G.decode({encoding:G.ENCODING,data}),/超出云端保存容量/);
});

test('cloud capacity check includes all platform keys and quota metadata', () => {
  const envelope = C.mergeCloudEnvelope({other:'中'.repeat(4000)},largeArchive(1));
  assert.throws(()=>C.assertCloudFits(envelope),/超出云端保存容量/);
});

test('capacity boundary accepts the limit and rejects even one encoded byte above it', () => {
  const envelope={data:''};
  envelope.data='A'.repeat(G.MAX_ENCODED_PAYLOAD-G.encodedSize(envelope));
  assert.equal(C.cloudUploadSize(envelope),C.CLOUD_UPLOAD_LIMIT);
  C.assertCloudFits(envelope);
  envelope.data+='A';
  assert.throws(()=>C.assertCloudFits(envelope),/超出云端保存容量/);
});
