"""Safely copy incremental source changes; default to preview, never delete source/history."""
from pathlib import Path
from urllib.parse import unquote
from datetime import date
import argparse,csv,hashlib,json,re,shutil,sys,zipfile

from public_font_policy import blocked_font,transformed_bytes,update_handoff_fonts

ROOT=Path(__file__).resolve().parents[1]
CACHE={'.git','.godot','node_modules','__pycache__','.pytest_cache','.cache','.DS_Store'}
MEDIA={'.png','.jpg','.jpeg','.webp','.gif','.mp4','.ogv','.ogg','.mp3','.wav','.otf','.ttf','.zip'}
SECRET=re.compile(r'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|sk-[A-Za-z0-9_-]{25,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)')

def exclusion(path):
    if blocked_font(path):return "公开版不分发旧字体及导入文件；原件保留在本地与私有归档"
    if any(p in CACHE for p in path.parts):return '可重新生成的缓存或版本库内部文件'
    if path.suffix.lower() in {'.lnk','.tmp','.temp','.bak','.pyc'} or path.name in {'Thumbs.db','desktop.ini'}:return '本机快捷方式或临时文件'
    if path.name=='.env' or path.name.startswith('.env.') and not path.name.endswith(('.example','.sample')) or path.suffix.lower() in {'.pem','.key','.p12','.pfx'}:return '潜在密钥或本机配置'
    if any(p.lower() in {'saves','player_saves','user_data'} for p in path.parts):return '玩家个人存档或运行数据'
    return None

def sha256(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()

def secret_check(path):
    if path.suffix.lower()=='.zip':
        with zipfile.ZipFile(path) as archive:
            for entry in archive.infolist():
                rel=Path(entry.filename.replace('\\','/'))
                if not entry.is_dir() and (exclusion(rel) or rel.is_absolute() or '..' in rel.parts):raise ValueError('压缩包存在需审查项：'+str(path))
                if not entry.is_dir() and rel.suffix.lower() not in MEDIA:
                    try:
                        if SECRET.search(archive.read(entry).decode('utf-8-sig')):raise ValueError('压缩包疑似包含密钥：'+str(path))
                    except UnicodeDecodeError:pass
    elif path.suffix.lower() not in MEDIA and path.stat().st_size<10*1024**2:
        try:
            if SECRET.search(path.read_text(encoding='utf-8-sig')):raise ValueError('疑似密钥：'+str(path))
        except UnicodeDecodeError:pass

def handoff(source):
    original=(source/'PROJECT_HANDOFF.md').read_text(encoding='utf-8')
    prefix=source.as_posix()+'/'
    def convert(match):
        value=unquote(match.group(1)).replace('\\','/')
        if value.lower().startswith(prefix.lower()):return '](<assets/source/'+value[len(prefix):]+'>)'
        # Existing absolute roots from earlier machines are mapped by known folder names.
        for folder in ['00_规范与清单','01_Figma参考','02_地形与植物','03_建筑与场景','04_UI组件','05_人物','06_道具与图标','08_预览','09_生成记录','10_最终交付','11_Godot项目','12_第一轮场景调整','13_Figma原图拆分与景深调整','14_循环动效','15_茶村配景与入口','16_茶村自由布置植物','17_茶树生长阶段','18_茶田土壤区块','19_云雾茶园Figma还原']:
            marker='/'+folder+'/'
            if re.match(r'^[A-Za-z]:/',value) and marker in value:return '](<assets/source/'+folder+'/'+value.split(marker,1)[1]+'>)'
        return match.group(0)
    updated=re.sub(r'\]\(<([^>]+)>\)',convert,original)
    updated=re.sub(r'^canonical_root:.*$', 'canonical_root: assets/source',updated,flags=re.M)
    updated=re.sub(r'^godot_project:.*$', 'godot_project: assets/source/11_Godot项目/茶园物语',updated,flags=re.M)
    current=(ROOT/'PROJECT_HANDOFF.md').read_text(encoding='utf-8')
    marker='## GitHub 交接导航';priority='## 0. '
    if marker in current and priority in current:
        note=current[current.index(marker):current.index(priority)]
        if marker not in updated:updated=updated[:updated.index(priority)]+note+updated[updated.index(priority):]
    return update_handoff_fonts(updated)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',required=True,type=Path)
    parser.add_argument('--apply',action='store_true',help='确认预览后实际复制；不删除文件')
    args=parser.parse_args();source=args.source.resolve()
    if not (source/'PROJECT_HANDOFF.md').is_file() or not (source/'11_Godot项目/茶园物语/project.godot').is_file():parser.error('源目录必须包含完整交接与 Godot 工程')
    if source==ROOT or ROOT in source.parents or source in ROOT.parents:parser.error('源目录与仓库不可互相包含')
    manifest=json.loads((ROOT/'docs/FILE_MANIFEST.json').read_text(encoding='utf-8'))
    old={x['source']:x for x in manifest['copies']};copies={};excluded=[];changes=[];snapshots={}
    for path in sorted(source.rglob('*')):
        if not path.is_file():continue
        if path.is_symlink():raise ValueError('请先检查符号链接：'+str(path))
        rel=path.relative_to(source);reason=exclusion(rel);st=path.stat();snapshots[path]=(st.st_size,st.st_mtime_ns)
        if reason:excluded.append({'source':rel.as_posix(),'bytes':st.st_size,'reason':reason});continue
        secret_check(path);source_digest=sha256(path);payload=transformed_bytes(rel,path)
        digest=hashlib.sha256(payload).hexdigest() if payload is not None else source_digest
        row={'source':rel.as_posix(),'repository':'assets/source/'+rel.as_posix(),'bytes':len(payload) if payload is not None else st.st_size,'sha256':digest}
        if payload is not None:row.update(source_sha256=source_digest,source_bytes=st.st_size,status='public_font_adaptation')
        copies[row['source']]=row;target=ROOT/row['repository']
        if not target.is_file() or sha256(target)!=digest:changes.append(row)
    retained=[{**v,'status':'retained_history'} for k,v in old.items() if k not in copies and not blocked_font(k)]
    updated_handoff=handoff(source)
    for a,b in re.findall(r'\]\((?:<([^>]+)>|([^\s)]+))\)',updated_handoff):
        target=unquote(a or b).split('#')[0]
        if target.startswith('assets/source/') and target.removeprefix('assets/source/') not in copies and not (ROOT/target).exists():
            # Directory links are valid if the source directory exists.
            if not (source/target.removeprefix('assets/source/')).is_dir():raise ValueError('交接链接缺少对应素材：'+target)
    print(json.dumps({'mode':'apply' if args.apply else 'preview','changedFiles':len(changes),'retainedHistory':len(retained),'excludedFiles':len(excluded)},ensure_ascii=False))
    if not args.apply:
        print('预览完成。添加 --apply 执行复制；源文件和历史素材不会被删除。');return 0
    for row in changes:
        origin=source/row['source'];target=ROOT/row['repository'];target.parent.mkdir(parents=True,exist_ok=True)
        if (origin.stat().st_size,origin.stat().st_mtime_ns)!=snapshots[origin]:raise ValueError('源文件同步期间改变：'+str(origin))
        payload=transformed_bytes(row["source"],origin)
        if payload is None:shutil.copy2(origin,target)
        else:target.write_bytes(payload)
        if sha256(target)!=row['sha256']:raise ValueError('复制校验失败：'+str(target))
    specs=ROOT/'docs/specifications';specs.mkdir(exist_ok=True)
    for path in (source/'00_规范与清单').iterdir():
        if path.is_file() and not exclusion(path.relative_to(source)):shutil.copy2(path,specs/path.name)
    (ROOT/'PROJECT_HANDOFF.md').write_text(updated_handoff,encoding='utf-8',newline='\n')
    allrows=sorted([*copies.values(),*retained],key=lambda row:row['source'])
    manifest.update(snapshot_date=date.today().isoformat(),source_root=str(source),copies=allrows,excluded=excluded)
    (ROOT/'docs/FILE_MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    with (ROOT/'docs/ASSET_INDEX.csv').open('w',encoding='utf-8-sig',newline='') as stream:
        writer=csv.writer(stream);writer.writerow(['原始路径','仓库实际路径','格式','字节数','SHA256','说明'])
        for row in allrows:writer.writerow([row['source'],row['repository'],Path(row['source']).suffix,row['bytes'],row['sha256'],row.get('status','原始文件')])
        for row in manifest.get('additions',[]):writer.writerow(['公开版新增',row['repository'],Path(row['repository']).suffix,row['bytes'],row['sha256'],'公开版补充：字体、展示或工程导入配置'])
    with (ROOT/'docs/EXCLUDED_FILES.csv').open('w',encoding='utf-8-sig',newline='') as stream:
        writer=csv.writer(stream);writer.writerow(['原始路径','字节数','排除原因'])
        for row in excluded:writer.writerow([row['source'],row['bytes'],row['reason']])
    if any((p.stat().st_size,p.stat().st_mtime_ns)!=state for p,state in snapshots.items()):raise ValueError('同步期间源目录发生变化，请检查后重新执行')
    print('素材、规范和索引已同步。请运行 verify_repository.py，核对 README 分类统计并检查 git diff 后提交。')
    return 0

if __name__=='__main__':raise SystemExit(main())
