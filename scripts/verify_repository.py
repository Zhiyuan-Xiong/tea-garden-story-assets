"""Verify actual source bytes, portable handoff links and Godot catalog resources."""
from pathlib import Path
from urllib.parse import unquote
import hashlib,json,re,struct,sys

ROOT=Path(__file__).resolve().parents[1]

def sha256(path):
    result=hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):result.update(chunk)
    return result.hexdigest()

def main():
    manifest=json.loads((ROOT/'docs/FILE_MANIFEST.json').read_text(encoding='utf-8'))
    failures=[]
    for item in [*manifest['copies'],*manifest.get('additions',[])]:
        path=ROOT/item['repository']
        if not path.is_file():failures.append('缺失文件：'+item['repository']);continue
        with path.open('rb') as stream:header=stream.read(80)
        if header.startswith(b'version https://git-lfs.github.com/spec/v1'):
            failures.append('尚未下载 LFS 文件：'+item['repository']);continue
        if path.stat().st_size!=item['bytes'] or sha256(path)!=item['sha256']:
            failures.append('内容与清单不符：'+item['repository'])
        if item.get('source','').startswith('00_规范与清单/'):
            duplicate=ROOT/'docs/specifications'/Path(item['source']).name
            if not duplicate.is_file() or sha256(duplicate)!=item['sha256']:
                failures.append('规范副本不一致：'+str(duplicate.relative_to(ROOT)))
    from public_font_policy import blocked_font
    forbidden=[p.relative_to(ROOT).as_posix() for p in (ROOT/'assets').rglob('*') if p.is_file() and blocked_font(p)]
    failures.extend('公开版残留旧字体：'+p for p in forbidden)
    links=0
    for rel in ['README.md','PROJECT_HANDOFF.md','工作流.md','docs/README.md']:
        path=ROOT/rel;text=path.read_text(encoding='utf-8')
        targets=re.findall(r'\]\((?:<([^>]+)>|([^\s)]+))\)',text)
        targets += [('',s) for s in re.findall(r'(?:src|srcset)="([^"]+)"',text)]
        for angle,raw in targets:
            target=unquote(angle or raw).split('#')[0]
            if not target or re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:',target):continue
            links+=1
            if not (path.parent/target).exists():failures.append(f'链接不存在：{rel} → {target}')
        if rel=='PROJECT_HANDOFF.md' and re.search(r'\]\(<[A-Za-z]:[/\\]',text):
            failures.append('根目录交接仍包含本机绝对文件链接')
    game=ROOT/'assets/source/11_Godot项目/茶园物语'
    catalog=json.loads((game/'data/asset_catalog.json').read_text(encoding='utf-8-sig'))
    for asset_id,item in catalog.items():
        raw=item.get('path','')
        if not raw.startswith('res://'):
            failures.append('非工程资源路径：'+asset_id);continue
        path=game/raw.removeprefix('res://')
        if not path.is_file():failures.append(f'资源缺失：{asset_id} → {raw}');continue
        if path.suffix.lower()=='.png':
            with path.open('rb') as stream:header=stream.read(24)
            if header[:8]==b'\x89PNG\r\n\x1a\n':
                size=struct.unpack('>II',header[16:24])
                if size!=(item.get('width'),item.get('height')):
                    failures.append(f'资源尺寸不符：{asset_id} {size}')
    result={'sourceFilesVerified':len(manifest['copies']),'publicAdditionsVerified':len(manifest.get('additions',[])),'relativeLinksChecked':links,'catalogResourcesChecked':len(catalog),'failures':failures}
    print(json.dumps(result,ensure_ascii=False,indent=2))
    if failures:
        print('若发现 LFS 指针，请先执行 git lfs install 与 git lfs pull。',file=sys.stderr)
        return 1
    return 0

if __name__=='__main__':raise SystemExit(main())
