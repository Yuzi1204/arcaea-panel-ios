"""检查 database/songs 里到底有没有可玩的歌曲文件。

服务端每首歌需要 database/songs/<song_id>/ 下至少：
  0.aff / 1.aff / 2.aff / 3.aff / 4.aff   —— 各难度谱面
  base.ogg                                —— 音频
在本机跑一次就知道「能玩几首」。
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(HERE, '..', 'arcaea-server-runtime', 'src',
                   'Arcaea-server-2.13.0', 'latest version')
SONGS_DIR = os.path.join(APP, 'database', 'songs')
DB_INIT = os.path.join(APP, 'database', 'init')


def load_json(name):
    path = os.path.join(DB_INIT, name)
    if not os.path.isfile(path):
        return []
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)


def collect_song_ids():
    ids = set()
    # packs.json / singles.json 里每项形如 {"song_id": ["a","b"], ...} 或 {"id": ...}
    for name in ('packs.json', 'singles.json'):
        for entry in load_json(name):
            for key, value in entry.items():
                if isinstance(value, str) and key.lower() in ('id', 'song_id', 'songid'):
                    ids.add(value)
                elif isinstance(value, list):
                    for v in value:
                        if isinstance(v, str) and v and v[0].isalnum() and ' ' not in v and len(v) < 40:
                            ids.add(v)
    return ids


def main():
    if not os.path.isdir(SONGS_DIR):
        print('找不到歌曲目录:', SONGS_DIR)
        return 2

    dirs = {d for d in os.listdir(SONGS_DIR) if os.path.isdir(os.path.join(SONGS_DIR, d))}
    ids = collect_song_ids()

    playable = []
    partial = []
    for d in sorted(dirs):
        base = os.path.join(SONGS_DIR, d)
        files = set(os.listdir(base))
        has_chart = any(f.endswith('.aff') for f in files)
        has_audio = any(f.endswith('.ogg') or f.endswith('.mp3') for f in files)
        if has_chart and has_audio:
            playable.append(d)
        else:
            partial.append(d)

    print('=' * 56)
    print(f'曲目目录数        : {len(dirs)}')
    print(f'包内登记曲目数    : {len(ids)}')
    print(f'可玩（谱面+音频） : {len(playable)}')
    print(f'不完整            : {len(partial)}')
    print('=' * 56)

    if playable:
        print('\n已可玩的曲子（前 30）：')
        print('  ' + ', '.join(playable[:30]))
    if partial:
        print('\n缺文件（不完整）：', ', '.join(partial[:30]))

    if not dirs:
        print('\n结论：database/songs/ 是空的 —— 服务端目前提供不了任何歌曲文件。')
        print('      登录/存档/查分/买曲/世界模式都正常，但没下载过谱面的曲子无法开始游玩。')
        print('      服务端不随仓库提供歌曲文件（版权原因），见 iPad-连接指南.md 最后一节。')
    elif len(playable) == 0:
        print('\n结论：有目录但没有完整的谱面+音频，仍无法游玩。')
    else:
        print(f'\n结论：当前可玩 {len(playable)} 首。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
