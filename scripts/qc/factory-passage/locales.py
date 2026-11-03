"""Focused eight-locale key, parameter and Informatron contract checks."""
import json,pathlib,re
root=pathlib.Path(__file__).resolve().parents[3]
locales=('en','de','fr','ja','pl','ru','zh-CN','zh-TW')
def read(locale):
    source=(root/'exotic-space-industries-remembrance/locale'/locale/'factory-passage.cfg').read_text(encoding='utf8')
    result={};section=''
    for line in source.splitlines():
        if line.startswith('['):section=line[1:-1]
        elif '=' in line:
            key,value=line.split('=',1);full=section+'.'+key
            assert full not in result,(locale,'duplicate',full)
            assert value.strip(),(locale,'empty',full)
            result[full]=value
    return result
english=read('en');checks=0
for locale in locales:
    values=read(locale);assert values.keys()>=english.keys(),(locale,english.keys()-values.keys());checks+=1
    for key in english:
        value=values[key]
        assert sorted(re.findall(r'__\d+__',value))==sorted(re.findall(r'__\d+__',english[key])),(locale,key)
        checks+=1
    assert len([k for k in values if k.startswith('ei-factory-passage-guide.')])==14
    checks+=1
print(json.dumps(dict(passed=True,checks=checks,locales=locales,keys_per_locale=len(english))))
