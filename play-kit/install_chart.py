"""把一份谱子包安装进 Arcaea 私服。

用法：
    python install_chart.py "D:\\edge下载\\buzzcutz.zip"

做的事：
  1. 从包里的 songlist.json 读出曲目 id 和元数据
  2. 把 *.aff / *.ogg / *.jpg 放进 database/songs/<id>/
  3. 把元数据合并进 database/songs/songlist
     ★ 自动补 "remote_dl": true —— 否则服务端只放行 <难度>.aff，不放行 base.ogg（曲子会没声音）
  4. 往 chart 表插一行定数（服务端算 PTT 要用；定数按 ×10 存，如 13 → 130）
"""
import json
import os
import shutil
import sqlite3
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(HERE, '..', 'arcaea-server-runtime', 'src',
                   'Arcaea-server-2.13.0', 'latest version')
SONGS = os.path.join(APP, 'database', 'songs')
SONGLIST = os.path.join(SONGS, 'songlist')
DB = os.path.join(APP, 'database', 'arcaea_database.db')

KEEP_EXT = ('.aff', '.ogg', '.mp3', '.mp4')
ART_EXT = ('.jpg', '.png')


def main(zip_path: str) -> int:
    if not os.path.isfile(zip_path):
        print('找不到文件:', zip_path)
        return 2

    z = zipfile.ZipFile(zip_path)
    names = z.namelist()

    meta_name = next((n for n in names if os.path.basename(n) == 'songlist.json'), None)
    if not meta_name:
        print('包里没有 songlist.json，无法确定曲目 id')
        return 2
    meta_raw = json.loads(z.read(meta_name).decode('utf-8'))
    songs = meta_raw.get('songs') or []
    if not songs:
        print('songlist.json 里没有 songs 数组')
        return 2
    entry = songs[0]
    song_id = entry['id']

    # 1) 落盘歌曲文件
    target = os.path.join(SONGS, song_id)
    os.makedirs(target, exist_ok=True)
    copied = []
    for n in names:
        base = os.path.basename(n)
        if not base or n.endswith('/'):
            continue
        if base == 'songlist.json':
            continue
        ext = os.path.splitext(base)[1].lower()
        if ext in KEEP_EXT or ext in ART_EXT:
            with z.open(n) as src, open(os.path.join(target, base), 'wb') as dst:
                shutil.copyfileobj(src, dst)
            copied.append(base)

    # 2) 合并进 songlist
    with open(SONGLIST, 'r', encoding='utf-8') as f:
        data = json.load(f)
    merged = entry
    merged['remote_dl'] = True          # ← 关键：放行 base.ogg
    # 只保留真正有谱面的难度：rating 为 0 的难度会骗客户端去下载不存在的 .aff（然后 404）
    real_diffs = [d for d in entry.get('difficulties', []) if (d.get('rating') or 0) > 0]
    merged['difficulties'] = real_diffs
    songs_list = [s for s in data.get('songs', []) if s.get('id') != song_id]
    songs_list.append(merged)
    data['songs'] = songs_list
    with open(SONGLIST, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=4)

    # 3) chart 表定数
    title = (entry.get('title_localized') or {}).get('en') or song_id
    ratings = {'rating_pst': -1, 'rating_prs': -1, 'rating_ftr': -1,
               'rating_byn': -1, 'rating_etr': -1}
    key_by_class = {0: 'rating_pst', 1: 'rating_prs', 2: 'rating_ftr',
                    3: 'rating_byn', 4: 'rating_etr'}
    for diff in real_diffs:
        rc = diff.get('ratingClass')
        value = diff.get('rating') or 0
        if rc in key_by_class and value and value > 0:
            ratings[key_by_class[rc]] = int(round(float(value) * 10))

    con = sqlite3.connect(DB)
    con.execute(
        '''insert into chart(song_id, name, rating_pst, rating_prs, rating_ftr, rating_byn, rating_etr)
           values(?,?,?,?,?,?,?)
           on conflict(song_id) do update set
             name=excluded.name, rating_pst=excluded.rating_pst, rating_prs=excluded.rating_prs,
             rating_ftr=excluded.rating_ftr, rating_byn=excluded.rating_byn, rating_etr=excluded.rating_etr''',
        (song_id, title, ratings['rating_pst'], ratings['rating_prs'], ratings['rating_ftr'],
         ratings['rating_byn'], ratings['rating_etr']))
    con.commit()
    con.close()

    # 4) 汇总
    print('=' * 56)
    print(f'曲目 id   : {song_id}')
    print(f'标题      : {title}')
    print(f'曲师      : {entry.get("artist")}')
    print(f'BPM       : {entry.get("bpm_base")}')
    print(f'包(set)   : {entry.get("set")}  (base = 免费包，自动解锁)')
    print(f'落地目录  : {target}')
    print(f'已放入    : {", ".join(sorted(copied))}')
    print(f'定数      : PST {ratings["rating_pst"]/10 if ratings["rating_pst"]>0 else "-"}'
          f' / PRS {ratings["rating_prs"]/10 if ratings["rating_prs"]>0 else "-"}'
          f' / FTR {ratings["rating_ftr"]/10 if ratings["rating_ftr"]>0 else "-"}'
          f' / BYD {ratings["rating_byn"]/10 if ratings["rating_byn"]>0 else "-"}'
          f' / ETR {ratings["rating_etr"]/10 if ratings["rating_etr"]>0 else "-"}')
    print('songlist  : 已合并（remote_dl=true）')
    print('chart 表  : 已写入')
    print('=' * 56)
    print('别忘了重启私服，让 songlist 缓存重新加载。')
    return 0


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    sys.exit(main(sys.argv[1]))
