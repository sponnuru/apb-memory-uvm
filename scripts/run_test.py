#!/usr/bin/env python3
import argparse,re,subprocess,sys
from pathlib import Path
from check_vcd import check
p=argparse.ArgumentParser();p.add_argument('--seed',type=int,action='append',required=True);args=p.parse_args()
for seed in args.seed:
    wave=Path(f'build/apb_seed_{seed}.vcd');log=Path(f'build/run_seed_{seed}.log');wave.unlink(missing_ok=True)
    with log.open('w') as out:
        try: result=subprocess.run(['./build/obj/Vtb_top',f'+verilator+seed+{seed}',f'+WAVE_FILE={wave}'],stdout=out,stderr=subprocess.STDOUT,text=True,timeout=120)
        except subprocess.TimeoutExpired: raise SystemExit(f'FAIL seed={seed}: timeout; see {log}')
    text=log.read_text();print(text)
    clean=all(re.search(rf'UVM_{s}\s*:\s*0\b',text) for s in ('ERROR','FATAL'))
    if result.returncode or not clean or '[APB_STATS]' not in text: raise SystemExit(f'FAIL seed={seed}')
    stats,end=check(wave);print(f'PASS seed={seed}; {stats}; waveform_end={end} ps')
