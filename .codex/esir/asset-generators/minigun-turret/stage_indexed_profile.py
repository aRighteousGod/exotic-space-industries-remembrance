"""Stage the indexed default layout without changing the full-color HD profile."""
import argparse,hashlib,json,re
from pathlib import Path

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def table_span(text,name):
    start=text.index('        '+name+' = {');opening=text.index('{',start)
    depth=0;quote=None;escape=False
    for i in range(opening,len(text)):
        c=text[i]
        if quote:
            if escape:escape=False
            elif c=='\\':escape=True
            elif c==quote:quote=None
        elif c in ('"',"'"):quote=c
        elif c=='{':depth+=1
        elif c=='}':
            depth-=1
            if depth==0:return start,i+1
    raise ValueError('Unclosed profile')

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--repo',type=Path,required=True)
    p.add_argument('--conversion',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--source',type=Path,help='Original pre-derivative Lua metadata for replay after integration')
    a=p.parse_args();repo=a.repo.resolve();out=a.output.resolve();assert out.is_relative_to(repo/'output')
    report=json.loads((a.conversion/'conversion-report.json').read_text());assert report['complete']
    source=a.source or repo/'exotic-space-industries-remembrance/prototypes/electricity-age/gatling-turret/graphics-data.lua'
    text=source.read_text(encoding='utf-8');s0,s1=table_span(text,'sd');h0,h1=table_span(text,'hd')
    assert 'artwork_derivative =' not in text,'Use --source with the preserved pre-derivative Lua metadata'
    hd=text[h0:h1];default=hd.replace('        hd = {','        sd = {',1)
    default=default.replace('"__minigun-turret-HD__/','ei_graphics_6_path.."')
    assert '__minigun-turret-HD__' not in default and 'scale = 0.5' in default
    result=text[:s0]+default+text[s1:]
    marker='    schema = "esir.minigun.graphics.v2",'
    derivative='\n    -- Original finalizer receipts below certify source geometry/full-color pixels.\n    -- This derivative has separate palette, alpha and native evidence.\n    artwork_derivative = {encoding = "indexed-rgba", density = 64, palette_entries = 256,\n        palette_sha256 = "'+report['palette_sha256']+'", original_pixel_equality = false},'
    result=result.replace(marker,marker+derivative,1)
    result=result.replace('-- Native-calibrated full atlas; staged integration still requires final load/package gates.',
        '-- Indexed HD default in Graphics 6; optional HD retains full-color source art.')
    assert result[table_span(result,'hd')[0]:table_span(result,'hd')[1]]==hd
    out.mkdir(parents=True,exist_ok=True);(out/'graphics-data.lua').write_text(result,encoding='utf-8')
    (out/'profile-report.json').write_text(json.dumps({'source_sha256':sha(source),'result_sha256':sha(out/'graphics-data.lua'),
        'hd_profile_unchanged':True,'default_profile_from_hd':True,'density':64,'scale':0.5,
        'conversion_report_sha256':sha(a.conversion/'conversion-report.json')},indent=2)+'\n')

if __name__=='__main__':main()
