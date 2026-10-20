/* Cloud transport only. Local records and user backups remain ordinary JSON. */
const GuituCloudCodec = (() => {
  'use strict';
  const P = typeof pako !== 'undefined' ? pako : require('../vendor/pako.min.js');
  const ENCODING = 'guitu.deflate-base64url.v1';
  // Leave headroom below the 31,000-byte request verified on the real platform.
  // The SDK adds its endpoint, game_id and payload parameter around this value.
  const MAX_ENCODED_PAYLOAD = 30000;
  const MAX_DECODED_BYTES = 8 * 1024 * 1024;
  const tooLarge = () => new Error('记录较多，暂时超出云端保存容量。请先通过本机数据管理备份，本机记录不会改变');
  function toBase64(bytes) {
    let binary = '';
    for (let i = 0; i < bytes.length; i += 8192)
      binary += String.fromCharCode.apply(null,bytes.subarray(i,i + 8192));
    return btoa(binary).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
  }
  function fromBase64(text) {
    if (typeof text !== 'string' || !text.length || text.length > Math.ceil(MAX_DECODED_BYTES * 4 / 3) + 4 ||
        !/^[A-Za-z0-9_-]+$/.test(text) || text.length % 4 === 1)
      throw new Error('云端记录格式不正确');
    const binary = atob(text.replace(/-/g,'+').replace(/_/g,'/'));
    return Uint8Array.from(binary,(character) => character.charCodeAt(0));
  }
  function encode(snapshot) {
    const raw = new TextEncoder().encode(JSON.stringify(snapshot));
    if (raw.length > MAX_DECODED_BYTES) throw tooLarge();
    return {encoding:ENCODING,data:toBase64(P.deflate(raw,{level:9}))};
  }
  function decode(value) {
    if (!value || typeof value !== 'object' || Array.isArray(value))
      throw new Error('云端记录格式不正确');
    if (!Object.prototype.hasOwnProperty.call(value,'encoding')) return value;
    if (value.encoding !== ENCODING) throw new Error('云端存档版本不支持');
    const bytes = fromBase64(value.data);
    const chunks = [];
    let size = 0;
    const inflater = new P.Inflate({chunkSize:16384});
    inflater.onData = (chunk) => {
      size += chunk.length;
      if (size > MAX_DECODED_BYTES) throw tooLarge();
      chunks.push(chunk);
    };
    inflater.push(bytes,true);
    if (inflater.err || !inflater.ended) throw new Error('云端记录损坏，已停止读取');
    const raw = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) { raw.set(chunk,offset); offset += chunk.length; }
    return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(raw));
  }
  function encodedSize(envelope) {
    return encodeURIComponent(JSON.stringify(envelope)).length;
  }
  function assertFits(envelope) {
    if (encodedSize(envelope) > MAX_ENCODED_PAYLOAD) throw tooLarge();
    return envelope;
  }
  return {ENCODING,MAX_ENCODED_PAYLOAD,MAX_DECODED_BYTES,encode,decode,encodedSize,assertFits};
})();
if (typeof module !== 'undefined' && module.exports) module.exports = GuituCloudCodec;
