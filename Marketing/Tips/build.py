import json
d=json.load(open('tips.json'))
t=open('ae/template.jsx').read()
out=t.replace('__TIPS_JSON__', json.dumps(d, ensure_ascii=True, indent=1))
open('ae/Build_Reforged_Tips.jsx','w',encoding='utf-8-sig').write(out)
