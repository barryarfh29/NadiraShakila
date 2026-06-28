with open('lib/features/workspace/widgets/editor_area.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()
    for i in range(287, 312):
        print(f'{i+1}: {repr(lines[i])}')
