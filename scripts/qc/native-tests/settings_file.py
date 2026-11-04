"""Strict reader for Factorio's documented mod-settings PropertyTree format.

Only a missing -> newly created default settings file is normalizable. Existing
files retain byte-for-byte guards. https://wiki.factorio.com/Mod_settings_file_format
https://wiki.factorio.com/Property_tree
"""
import io
import math
import struct


def decode(data):
    stream=io.BytesIO(data)
    def take(count):
        value=stream.read(count)
        if len(value)!=count: raise ValueError('Truncated settings file')
        return value
    def number(format): return struct.unpack('<'+format,take(struct.calcsize('<'+format)))[0]
    def boolean():
        value=number('B')
        if value not in (0,1): raise ValueError('Invalid settings boolean')
        return bool(value)
    def string():
        if boolean(): return ''
        size=number('B')
        if size==255: size=number('I')
        return take(size).decode('utf-8')
    def tree(depth=0):
        if depth>20: raise ValueError('Settings nesting limit')
        kind=number('B'); boolean()
        if kind==0: return None
        if kind==1: return boolean()
        if kind in (2,6,7):
            value=number({2:'d',6:'q',7:'Q'}[kind])
            if not math.isfinite(value): raise ValueError('Nonfinite settings value')
            return value
        if kind==3: return string()
        if kind in (4,5):
            size=number('I')
            if size>100000: raise ValueError('Settings collection limit')
            result={} if kind==5 else []
            for _ in range(size):
                key=string(); value=tree(depth+1)
                if kind==4: result.append(value)
                else:
                    if key in result: raise ValueError('Duplicate settings key')
                    result[key]=value
            return result
        raise ValueError('Unknown settings PropertyTree kind')
    version=struct.unpack('<4H',take(8))
    if version[:3]!=(2,1,24) or boolean(): raise ValueError('Unexpected settings header/version')
    result=tree()
    if stream.read(1): raise ValueError('Trailing settings bytes')
    if not isinstance(result,dict) or set(result)!={'startup','runtime-global','runtime-per-user'}:
        raise ValueError('Incomplete settings sections')
    return result


def same_value(left,right):
    if isinstance(left,bool) or isinstance(right,bool): return type(left) is type(right) and left==right
    if isinstance(left,dict) and isinstance(right,dict):
        return left.keys()==right.keys() and all(same_value(left[k],right[k]) for k in left)
    return left==right


def assert_defaults(data, defaults):
    actual=decode(data)
    if set(defaults)!=set(actual): raise ValueError('Missing default settings sections')
    for scope,values in actual.items():
        expected=defaults[scope] or {}
        if not isinstance(values,dict) or not isinstance(expected,dict) or set(values)!=set(expected):
            raise ValueError('Default settings inventory mismatch: '+scope)
        for name,record in values.items():
            if not isinstance(record,dict) or set(record)!={'value'} or not same_value(record['value'],expected[name]):
                raise ValueError('Nondefault initial setting: '+scope+'/'+name)
    return actual
