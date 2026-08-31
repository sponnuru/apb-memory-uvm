#!/usr/bin/env python3
"""Check APB protocol properties and completed-transfer count from a VCD."""
from pathlib import Path
import argparse

def check(path):
    scopes=[]; ids={}; vals={}; changes={}; now=0; prev_clk=0; access=None
    stats={'rising_edges':0,'setups':0,'completions':0,'waited':0,'errors':0}
    names=('pclk','preset_n','psel','penable','pwrite','paddr','pwdata','pstrb','prdata','pready','pslverr')
    def sample():
        nonlocal prev_clk,access
        vals.update(changes);changes.clear()
        if len(ids)!=len(names): return
        clk=vals.get(ids['pclk'],0)
        if clk==1 and prev_clk==0:
            stats['rising_edges']+=1
            if not vals[ids['preset_n']]: access=None
            else:
                sel,en,ready=(vals[ids[x]] for x in ('psel','penable','pready'))
                assert not en or sel, f'{path}: PENABLE without PSEL at {now} ps'
                current=tuple(vals[ids[x]] for x in ('pwrite','paddr','pwdata','pstrb'))
                if sel and not en:
                    access=current;stats['setups']+=1
                elif sel and en:
                    assert access is not None, f'{path}: access without setup at {now} ps'
                    assert current==access, f'{path}: request changed during access at {now} ps'
                    if ready:
                        stats['completions']+=1;stats['errors']+=vals[ids['pslverr']];access=None
                    else: stats['waited']+=1
        prev_clk=clk
    for line in Path(path).read_text().splitlines():
        w=line.split()
        if not w: continue
        if w[0]=='$scope': scopes.append(w[2])
        elif w[0]=='$upscope': scopes.pop()
        elif w[0]=='$var' and scopes[-1:]==['dut'] and w[4] in names: ids[w[4]]=w[3]
        elif line.startswith('#'): sample();now=int(line[1:])
        elif line[0] in '01xz' and line[1:] in ids.values():
            assert line[0] in '01';changes[line[1:]]=int(line[0])
        elif line[0]=='b' and len(w)==2 and w[1] in ids.values(): changes[w[1]]=int(w[0][1:],2)
    sample()
    assert stats['setups']==312 and stats['completions']==312 and stats['errors']==4, stats
    assert stats['waited']>=312 and now>0, stats
    return stats,now
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('waveforms',nargs='+')
    for f in p.parse_args().waveforms:
        stats,end=check(f);print(f'WAVEFORM PASS {f}: {stats}; end={end} ps')
