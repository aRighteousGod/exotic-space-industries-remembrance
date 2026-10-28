"""Compare every native fusion craft while normalizing documented product API fields."""
import argparse
import hashlib
import json
from pathlib import Path


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before',type=Path,required=True)
    parser.add_argument('--after',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    before,after=[json.loads(p.read_text(encoding='utf-8')) for p in (args.before,args.after)]
    assert before['engine']=='2.0.77' and after['engine']=='2.1.23'
    for report in (before,after):
        assert report['passed'] and report['completed']==135 and report['assertions']==1053
    for row in before['cases']:
        for product in row['products']:
            assert product.pop('probability')==1
    for row in after['cases']:
        for product in row['products']:
            assert product.pop('independent_probability')==1
            assert product.pop('shared_probability')=={'min':0,'max':1}
    # Exact equality covers native consumption, yields, output capacity, blocked
    # progress, craft timing, recipe identity and metadata after that normalization.
    assert before['cases']==after['cases'],'Native fusion craft mismatch'
    result={'passed':True,'recipes':135,'native_assertions_each':1053,
        'normalized_product_fields':405,'remaining_differences':0,
        'sources':[{'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
            for p in (args.before,args.after)],'cases':after['cases']}
    args.output.write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='cases'}))


if __name__=='__main__':
    main()
