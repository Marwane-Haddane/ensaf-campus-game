from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from urllib.request import urlopen
root=Path('assets/ui/icons')
icons={'home':('filled','home'),'folder':('filled','folder'),'drive':('outline','database'),'terminal':('outline','terminal-2'),'network':('outline','network'),'volume':('outline','volume'),'close':('outline','x'),'maximize':('outline','square'),'minimize':('outline','minus'),'back':('outline','arrow-left'),'forward':('outline','arrow-right'),'up':('outline','arrow-up'),'refresh':('outline','refresh'),'file':('outline','file-text'),'applications':('outline','shield-lock'),'monitor':('outline','device-desktop'),'pause':('outline','player-pause'),'chevron':('outline','chevron-right')}
def get(item):
 name,(kind,icon)=item
 url=f'https://raw.githubusercontent.com/tabler/tabler-icons/main/icons/{kind}/{icon}.svg'
 data=urlopen(url,timeout=25).read().decode()
 data=data.replace('currentColor','#389cec' if name in ('home','folder') else '#d5dce4')
 (root/f'{name}.svg').write_text(data,encoding='utf-8')
 return name
with ThreadPoolExecutor(max_workers=6) as pool:
 for name in pool.map(get,icons.items()): print(name)
(root/'LICENSE.txt').write_bytes(urlopen('https://raw.githubusercontent.com/tabler/tabler-icons/main/LICENSE',timeout=25).read())

