import json, sys

XMIND_FILES = {
    'VSA': r'j:\Xmind\vsa_out\content.json',
    'MauHinh': r'j:\Xmind\mauhinh_out\content.json',
    'Ichimoku': r'j:\Xmind\cautao_out\content.json',
    'NenDaoChieu': r'j:\Xmind\nendaochu_out\content.json',
    'GiauThoi': r'j:\Xmind\giau_out\content.json',
}

def extract_text(node, depth=0):
    lines = []
    title = node.get('title', '').strip()
    if title and not node.get('titleUnedited'):
        prefix = '  ' * depth + ('- ' if depth > 0 else '# ')
        lines.append(prefix + title.replace('\n', ' | '))
    for child in node.get('children', {}).get('attached', []):
        lines.extend(extract_text(child, depth + 1))
    for child in node.get('children', {}).get('detached', []):
        lines.extend(extract_text(child, depth + 1))
    return lines

out_path = r'd:\ChungKhoan\dnse_stock_app\xmind_full.md'
with open(out_path, 'w', encoding='utf-8') as out:
    for name, path in XMIND_FILES.items():
        with open(path, encoding='utf-8') as f:
            data = json.load(f)
        out.write(f'\n\n{"="*60}\n')
        out.write(f'## FILE: {name}\n')
        out.write(f'{"="*60}\n')
        for sheet in data:
            root = sheet.get('rootTopic', {})
            for line in extract_text(root, 0):
                out.write(line + '\n')

print('Done! Saved to xmind_full.md')
