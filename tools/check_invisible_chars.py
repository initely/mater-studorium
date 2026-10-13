#!/usr/bin/env python3
"""Ищет в файлах репозитория невидимые, bidi и управляющие символы.

Зачем: «Trojan Source» (подмена отображения кода bidi-символами), невидимые
символы в идентификаторах, строках и регулярных выражениях, «пустые» имена.
В тестах и инструментах такие символы нужны намеренно, но записывать их надо
escape-последовательностями (`\\u200b`), чтобы они были видны глазами и ревью.

Запуск из корня репозитория:  python3 -I tools/check_invisible_chars.py
Проверяются файлы из `git ls-files`; бинарные файлы и файлы не в UTF-8
пропускаются. Исключений нет. Код 1 и строки `файл:строка:столбец:U+XXXX`,
если что-то найдено.

Сам скрипт не содержит этих символов буквально: диапазоны заданы числами.
"""

import subprocess
import sys

# (первый, последний) коды включительно.
RANGES = [
    (0x0000, 0x0008),
    (0x000B, 0x000C),
    (0x000E, 0x001F),
    (0x007F, 0x009F),
    (0x00AD, 0x00AD),  # мягкий перенос
    (0x034F, 0x034F),  # combining grapheme joiner
    (0x061C, 0x061C),  # Arabic letter mark
    (0x115F, 0x1160),  # Hangul filler
    (0x180E, 0x180E),
    (0x200B, 0x200F),  # zero-width и bidi-метки
    (0x2028, 0x202E),  # разделители строк, bidi-встраивания
    (0x2060, 0x2064),
    (0x2066, 0x2069),  # bidi-изоляты
    (0x3164, 0x3164),  # Hangul filler
    (0xFE00, 0xFE0F),  # вариационные селекторы
    (0xFEFF, 0xFEFF),  # BOM допустим только в самом начале файла
    (0xFFA0, 0xFFA0),  # Hangul filler (полуширинный)
    (0xE0000, 0xE007F),  # теги
]

BOM = 0xFEFF


def is_invisible(code: int) -> bool:
    return any(lo <= code <= hi for lo, hi in RANGES)


def main() -> int:
    files = subprocess.run(
        ['git', 'ls-files', '-z'], check=True, capture_output=True
    ).stdout.split(b'\0')
    found = 0
    for raw in files:
        if not raw:
            continue
        path = raw.decode('utf-8', 'surrogateescape')
        try:
            with open(path, 'rb') as f:
                data = f.read()
        except OSError:
            continue  # удалён в рабочем дереве или не файл (подмодуль)
        try:
            text = data.decode('utf-8')
        except UnicodeDecodeError:
            continue  # бинарный файл или не UTF-8
        line = 1
        col = 0
        for index, ch in enumerate(text):
            col += 1
            code = ord(ch)
            if ch == '\n':
                line += 1
                col = 0
                continue
            if code == BOM and index == 0:
                continue
            if is_invisible(code):
                print(f'{path}:{line}:{col}:U+{code:04X}')
                found += 1
    if found:
        print(f'найдено невидимых символов: {found}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
