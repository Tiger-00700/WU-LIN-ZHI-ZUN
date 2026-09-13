from pathlib import Path
import re

root = Path(r'e:\DONT-TOUCH\WU-LIN-ZHI-ZUN')
master = root / '全书大师级优化.md'

text = master.read_text(encoding='utf-8') if master.exists() else ''
# Clean any prior inserted executable chapter blocks before a deterministic rewrite.
text = re.sub(r'\n### 章节修订模板条目（可执行）\n.*?\n- 章节作者建议：\n  本章必须写成“人物弧光—物证链—环境秩序—武学代价—情绪回声”的统一写法回环，避免章节成为单纯情节跳转。\n', '\n', text, flags=re.S)
text = text.replace('\r\n', '\n').replace('\r', '\n')
lines = text.split('\n')

heading_re = re.compile(r'^##\s*([\u4e00-\u9fa5]+)·第([\u4e00-\u9fa5]+?)章·优化$')
part_num = {'第一部': 1, '第二部': 2, '第三部': 3}

new_lines = []
idx = 0
chapter_count = 0

while idx < len(lines):
    line = lines[idx]
    m = heading_re.match(line)
    if not m:
        new_lines.append(line)
        idx += 1
        continue

    part_label = m.group(1)
    ch_label = m.group(2)
    part = part_num.get(part_label, 0)
    if part == 1:
        pri = 'P0'
        focus = '硬伤清理：核对时间线、人物名义、证据链、药物路线与章节主表一致性。'
    elif part == 2:
        pri = 'P1'
        focus = '人物弧线加固：强化群像、旧仇、门派秩序与武学代价之间的可验证衔接。'
    elif part == 3:
        pri = 'P2'
        focus = '终局与语言润色：完成反派层级、秩序闭环、术语统一与三部意象系统分层。'
    else:
        pri = 'P0'
        focus = '硬伤清理：核对时间线、人物名义、证据链、药物路线与章节主表一致性。'

    new_lines.append(line)
    idx += 1

    # Copy paragraph lines under the heading until the next heading.
    while idx < len(lines) and not heading_re.match(lines[idx]):
        new_lines.append(lines[idx])
        idx += 1

    # Insert one executable template block immediately after the chapter paragraph block.
    new_lines.extend([
        '',
        '### 章节修订模板条目（可执行）',
        f'- 章节编号：{part_label}·第{ch_label}章',
        f'- 优先级：{pri}',
        '- 章节文件：待落实到正文对应文件名',
        '- 依据：修订任务表、逐条修订清单、章节修订模板',
        '- 任务动作：',
        '  1. 以“章号—标题—文件名—人物—时间—地点—功能”为唯一主表核对轴。',
        '  2. 建立本章正文与台账、人物表、地理表、药物线索、证据链功能表的单章回索。',
        '  3. 对照硬伤清理、人物弧线、反派终局、语言与叙事标准，落实本章写法细节。',
        '  4. 查出并删除工作台式标记；统一术语、意象、情绪基调与文件命名。',
        '  5. 完成章内验收：地理、时间、人物、任务线索、证据链、情绪、语义无冲突。',
        f'- 专项聚焦：{focus}',
        '- 验收标准：',
        '  - 本章人物名义、身份与生死状态一致；',
        '  - 本章时间线、地点与事件顺序可追；',
        '  - 本章药物、证据、法度或武学路径不冲突；',
        '  - 本章情绪基调与三部曲对应意象系统匹配。',
        '- 章节作者建议：',
        '  本章必须写成“人物弧光—物证链—环境秩序—武学代价—情绪回声”的统一写法回环，避免章节成为单纯情节跳转。',
        '',
    ])
    chapter_count += 1

master.write_text('\n'.join(new_lines) + '\n', encoding='utf-8')
print(f'Integrated {chapter_count} chapter-specific execution template entries into {master}.')
