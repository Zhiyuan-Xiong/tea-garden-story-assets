"""Public edition font substitutions, also applied on subsequent source syncs."""
from pathlib import Path
import re

BLOCKED_FONT_NAMES={'Title_TangXianBinSong.otf','Title_TangXianBinSong.otf.import','User_Body.ttf','User_Body.ttf.import'}
GAME='11_Godot项目/茶园物语'

def blocked_font(path):
    return Path(path).name in BLOCKED_FONT_NAMES

def update_handoff_fonts(text):
    # Current source and the portable handoff use the same body paragraph.
    paragraphs=text.splitlines()
    for i,line in enumerate(paragraphs):
        if line.startswith('| Title_TangXianBinSong.otf |'):
            prefix='assets/source/' if 'assets/source/' in line else ''
            paragraphs[i]=f'| NotoSansSC-VF.ttf | [Noto Sans SC](<{prefix}{GAME}/fonts/NotoSansSC-VF.ttf>) | 17773244 | 公开版基础字体；OFL 1.1；正文 400、标题 600 字重 |'
            continue
        if line.startswith('| User_Body.ttf |'):
            paragraphs[i]=''
            continue
        if line.startswith('工程已有 ') and 'Title_TangXianBinSong.otf' in line:
            prefix='assets/source/' if 'assets/source/' in line else ''
            if not prefix:
                fonts=GAME+'/fonts/'
            else:fonts=prefix+GAME+'/fonts/'
            paragraphs[i]=f'公开工程统一使用之前作品集已使用的 [Noto Sans SC 可变字体](<{fonts}NotoSansSC-VF.ttf>)，保留其版权声明和 OFL 1.1 授权。正文通过 `Body_NotoSansSC.tres` 使用 400 字重，标题通过 `Title_NotoSansSC.tres` 使用 600 字重；两款旧字体及其导入文件不进入公开仓库。原始制作资料保留在本地与私有归档，历史截图记录原制作状态。'
    text='\n'.join(paragraphs)+'\n'
    # Remaining filename mentions describe the historical source, never resource references.
    text=text.replace('尚无当前可玩 Web 构建；补齐字体及 Figma／图像来源说明。','公开网页已有核心流程适配；本地完整 Godot 工程尚无独立 Web 导出包。公开工程字体已替换，Figma／图像保留来源说明。')
    return text

def transformed_bytes(relative,path):
    rel=Path(relative).as_posix()
    if rel==GAME+'/scripts/ui/ui_kit.gd':
        text=path.read_text(encoding='utf-8-sig')
        text=text.replace('res://fonts/User_Body.ttf','res://fonts/Body_NotoSansSC.tres')
        text=text.replace('res://fonts/Title_TangXianBinSong.otf','res://fonts/Title_NotoSansSC.tres')
        text=text.replace('标题优先使用用户指定字体；未收录的字才回退至用户指定的正文字体。','公开版统一使用 Noto Sans SC；标题 600 字重，正文 400 字重。')
        # Both variations share one font file; setting a fallback to the other
        # variation would create a resource cycle through their shared base.
        text=text.replace('\ttitle_font.fallbacks = [body_font]\n','')
        return text.encode('utf-8')
    if rel=='PROJECT_HANDOFF.md':
        text=update_handoff_fonts(path.read_text(encoding='utf-8-sig'))
        text='# 原始交接的公开适配副本\n\n同步当前字体和公开交付说明；最新可移植入口请阅读仓库根目录 PROJECT_HANDOFF.md。未改写的原版保留在本地源目录和私有归档。\n\n'+text
        return text.encode('utf-8')
    return None
