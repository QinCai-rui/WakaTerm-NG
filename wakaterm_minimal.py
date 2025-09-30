#!/usr/bin/env python3
"""WakaTerm NG - MINIMAL - MAXIMUM SPEED"""
import os,sys,time
def track_command():
    if len(sys.argv)<2 or '--help' in sys.argv:
        if '--help' in sys.argv: print("usage: wakaterm [--debug] <command>\nWakaTerm NG - Ultra-fast Terminal Activity Logger")
        return
    debug='--debug' in sys.argv; command=' '.join(a for a in sys.argv[1:] if not a.startswith('--'))
    if not command or command.strip().split()[0] in ('ls','cd','pwd','clear','exit','history'): 
        if debug: print(f"WAKATERM DEBUG: Ignoring '{command}'", file=sys.stderr)
        return
    try:
        import json,hashlib;from datetime import datetime
        cwd,t=os.getcwd(),time.time(); cmd=os.path.basename(command.split()[0])
        p=cwd
        while p!='/':
            if any(os.path.exists(os.path.join(p,x)) for x in ('.git','package.json')): project=os.path.basename(p); break
            p=os.path.dirname(p)
            if p==os.path.dirname(p): break
        else: project=os.path.basename(cwd) or 'terminal'
        lang={'python':'Python','python3':'Python','node':'JavaScript','npm':'JavaScript','git':'Git'}.get(cmd,'Shell')
        entry={"timestamp":t,"datetime":datetime.fromtimestamp(t).isoformat(),"command":command,"base_command":cmd,"cwd":cwd,"project":project,"language":lang,"entity":f"terminal://{project}/{cmd}#{hashlib.md5(f'{cmd}:{cwd}'.encode()).hexdigest()[:12]}","duration":2.0,"plugin":"wakaterm-ng/2.2.0-minimal"}
        if debug: print(f"WAKATERM DEBUG: Logging '{command}' in '{project}' ({lang})", file=sys.stderr)
        log_dir=os.path.expanduser('~/.local/share/wakaterm-logs'); os.makedirs(log_dir, exist_ok=True)
        with open(os.path.join(log_dir,f"wakaterm-{datetime.now().strftime('%Y-%m-%d')}.jsonl"),'a') as f: f.write(json.dumps(entry)+'\n')
        try:
            import shutil,subprocess
            if shutil.which('wakatime-cli'): subprocess.Popen(['wakatime-cli','--entity',entry['entity'],'--entity-type','url','--project',project,'--language',lang,'--time',str(t),'--plugin',entry['plugin'],'--category','coding','--timeout','5'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except: pass
    except Exception as e:
        if debug: print(f"WAKATERM DEBUG: Error: {e}", file=sys.stderr)
if __name__=='__main__': track_command()
