"""Makes docs/icon_sheet.html: every word in the game with the pictures Vision shows for it.
Run it again after changing words:  python docs/make_icon_sheet.py
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
data = (ROOT / "scripts/game_data.gd").read_text(encoding="utf-8")
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")

icons = dict(re.findall(r'"([^"]+)": "([^"]+)"', data[data.index("const THEME_ICONS"):data.index("const THEMES")]))
themes = []
for line in data[data.index("const THEMES := {"):].split("\n"):
    m = re.match(r'\t"(.+)": \[$', line)
    if m:
        themes.append({"name": m.group(1), "icon": icons.get(m.group(1), ""), "words": []})
    m = re.match(r'\t\t\["(.*?)", "(.*?)", "(.*?)"\],$', line)
    if m:
        themes[-1]["words"].append(list(m.groups()))

names = dict(re.findall(r'\{"id": "(\w+)", "name": "([^"]+)"', main))
names.update({"root": "Your cauldron", "wisdom_shelf": "Wisdom shelf", "vision_shelf": "Vision shelf"})
spells = [[icon, names.get(i, i)] for i, icon in re.findall(r'\{"id": "(\w+)", "parent": "\w*".*?"icon": "([^"]+)"\}', main)]

art = {f.stem: f.read_text(encoding="utf-8").strip() for f in sorted((ROOT / "art/pictures").glob("*.svg"))}
page = (ROOT / "docs/icon_sheet_template.html").read_text(encoding="utf-8")
page = page.replace("/*DATA*/", "const THEMES = %s;\nconst SPELLS = %s;\nconst ART = %s;" % (
    json.dumps(themes, ensure_ascii=False), json.dumps(spells, ensure_ascii=False), json.dumps(art)))
(ROOT / "docs/icon_sheet.html").write_text(page, encoding="utf-8")
print(len(themes), "themes,", sum(len(t["words"]) for t in themes), "words,", len(spells), "spells")
