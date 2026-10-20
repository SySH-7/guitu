"""Build one self-contained HTML file for Tieba's code upload form."""
import json
import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / 'src'
with_samples = os.environ.get('GUITU_INCLUDE_SAMPLES') == '1'
output = ROOT / 'dist' / ('guitu-tieba-0.2.2-preview.html' if with_samples else 'guitu-tieba-0.2.2.html')
html = (SRC / 'template.html').read_text(encoding='utf-8')
esbuild = os.environ.get('ESBUILD_BIN') or shutil.which('esbuild')


def source(name, loader):
    content = (SRC / name).read_text(encoding='utf-8')
    if not esbuild:
        return content
    result = subprocess.run(
        [esbuild, '--minify', '--target=es2020', f'--loader={loader}'],
        input=content, text=True, capture_output=True, check=True,
    )
    return result.stdout


replacements = {
    '/*__STYLE__*/': source('style.css', 'css'),
    '/*__REGIONS__*/': json.dumps(json.loads((SRC / 'regions.json').read_text(encoding='utf-8')), ensure_ascii=False, separators=(',', ':')),
    '/*__POINTS__*/': json.dumps(json.loads((SRC / 'province-points.json').read_text(encoding='utf-8')), ensure_ascii=False, separators=(',', ':')),
    '/*__CITY_POINTS__*/': json.dumps(json.loads((SRC / 'city-points.json').read_text(encoding='utf-8')), ensure_ascii=False, separators=(',', ':')),
    '/*__AK__*/': json.dumps(os.environ.get('BAIDU_MAP_AK', '')),
    '/*__SAMPLE__*/': json.dumps(json.loads((ROOT / 'test' / 'fictional-archive.json').read_text(encoding='utf-8')), ensure_ascii=False, separators=(',', ':')) if with_samples else 'null',
    '/*__CORE__*/': source('core.js', 'js'),
    '/*__COMPRESSION__*/': (ROOT / 'vendor' / 'pako.min.js').read_text(encoding='utf-8'),
    '/*__CLOUD_CODEC__*/': source('cloud-codec.js', 'js'),
    '/*__APP__*/': source('app.js', 'js'),
}
for marker, value in replacements.items():
    if html.count(marker) != 1:
        raise SystemExit('Missing or duplicated marker: ' + marker)
    html = html.replace(marker, value)
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(html, encoding='utf-8')
print(output, len(html.encode('utf-8')), 'bytes')
