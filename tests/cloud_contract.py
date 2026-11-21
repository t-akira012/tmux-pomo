import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
START = 1795232400  # 2026-11-21 12:40 JST

class CloudContract(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / 'scripts', self.root / 'scripts')
        shutil.copy(ROOT / 'pomo.tmux', self.root)
        (self.root / '.env').write_text('USE_LOCAL=false\nSYNC_INTERVAL=30\nTIMER_FQDN=timer.invalid\nTIMER_ACCESS_PATH=012345678901234567890123\n')
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.env = dict(os.environ, PATH=str(self.bin) + ':' + os.environ['PATH'], FAKE_NOW=str(START), TZ='Asia/Tokyo', PROBE_ROOT=str(self.root))
        self.script('tmux', '''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
root=Path(os.environ['PROBE_ROOT']);args=sys.argv[1:]
with (root/'tmux.log').open('a') as f:f.write(json.dumps(args)+'\\n')
p=root/'options.json';state=json.loads(p.read_text()) if p.exists() else {}
if args and args[0]=='show-option':print(state.get(args[-1], '#{pomo_status} #{pomo_name} #{pomo_color}' if args[-1].startswith('status-') else ''))
if args and args[0]=='set-option':state[args[-2]]=args[-1];p.write_text(json.dumps(state))
''')
        self.script('curl', '''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
root=Path(os.environ['PROBE_ROOT']);args=sys.argv[1:]
with (root/'api.log').open('a') as f:f.write(json.dumps(args)+'\\n')
if os.environ.get('FAIL_API'):sys.exit(22)
print((root/(args[-1].rsplit('/',1)[-1]+'.json')).read_text())
''')
        self.script('date', '''#!/usr/bin/env python3
import os,sys,time
if sys.argv[1:]==['+%s']:print(os.environ['FAKE_NOW'])
elif sys.argv[1]=='-r':time.tzset();print(time.strftime('%H:%M',time.localtime(int(sys.argv[2]))))
else:raise SystemExit(2)
''')
        self.script('lockf', '#!/bin/sh\nshift 3\nexec "$@"\n')
        self.running = dict(id=1, sessionName='集中', durationSeconds=120, startedAtMillis=START*1000, completedAtMillis=None, phase='running', serverNowMillis=START*1000)
        self.done = dict(self.running, completedAtMillis=(START+30)*1000, phase='completed')
        for route in ['timer', 'start', 'stop', 'duration', 'session-name']:
            self.reply(route, self.done if route=='stop' else self.running)
        self.cache(self.running)

    def tearDown(self): self.temp.cleanup()
    def script(self, name, content):
        p=self.bin/name;p.write_text(content);p.chmod(0o755)
    def reply(self, route, value): (self.root/(route+'.json')).write_text(json.dumps(value))
    def cache(self, value):
        (self.root/'.pomo-state.json').write_text(json.dumps(dict(value,fetchedAtSeconds=START)))
        (self.root/'.pomo-last-attempt').write_text(self.env['FAKE_NOW']+'\n')
    def run_script(self, script='main.sh', *args, ok=True):
        result=subprocess.run(['bash',str(self.root/'scripts/cloud'/script),*args],env=self.env,text=True,capture_output=True)
        if ok:self.assertEqual(result.returncode,0,result.stderr)
        return result
    def log(self, name='tmux.log'):
        p=self.root/name
        return [json.loads(line) for line in p.read_text().splitlines()] if p.exists() else []

    def test_time_color_and_expiry_without_another_fetch(self):
        self.assertEqual(self.run_script('main.sh','time').stdout.strip(),'02:00')
        self.assertEqual(self.run_script('main.sh','color').stdout.strip(),'brightred')
        self.env['FAKE_NOW']=str(START+121);(self.root/'.pomo-last-attempt').write_text(self.env['FAKE_NOW']+'\n')
        self.assertEqual(self.run_script('main.sh','time').stdout.strip(),'12:42')
        self.assertEqual(self.run_script('main.sh','color').stdout.strip(),'green')
        self.assertIn(['set-environment','-g','POMODORO_SESSION_FLAG','0'],self.log())
        self.assertEqual(self.log('api.log'),[])

    def test_manual_completion_stays_at_server_clock(self):
        self.cache(self.done);self.env['FAKE_NOW']=str(START+999)
        (self.root/'.pomo-last-attempt').write_text(self.env['FAKE_NOW']+'\n')
        self.assertEqual(self.run_script('main.sh','time').stdout.strip(),'12:40')
        self.assertEqual(self.run_script('main.sh','name').stdout.strip(),'集中')
        self.assertEqual(self.run_script('main.sh','color').stdout.strip(),'green')

    def test_start_prompt_and_single_named_start(self):
        self.reply('timer',self.done)
        self.run_script('main.sh','start')
        prompt=[line for line in self.log() if line[0]=='command-prompt'][-1]
        self.assertEqual(prompt[1:3],['-p','POMODORO start:'])
        self.assertIn('session-init.sh',prompt[3])
        self.run_script('session-init.sh',"a 'quoted' 日本語 name")
        request=self.log('api.log')[-1]
        self.assertEqual(request[request.index('-X')+1],'POST')
        self.assertTrue(request[-1].endswith('/start'))
        self.assertEqual(json.loads(request[request.index('--data')+1]),{'name':"a 'quoted' 日本語 name"})
        self.assertIn(['display-message','POMODORO started!!'],self.log())

    def test_stop_confirmation_and_confirmed_action(self):
        self.run_script('main.sh','stop')
        prompt=[line for line in self.log() if line[0]=='command-prompt'][-1]
        self.assertEqual(prompt[2],'Do you want stop a Pomodoro Session?(press Enter or CTRL-C):')
        self.assertIn('main.sh stop_ok',prompt[3])
        self.run_script('main.sh','stop_ok')
        self.assertTrue(self.log('api.log')[-1][-1].endswith('/stop'))
        self.assertIn(['set-environment','-g','POMODORO_FINISHED_TIME','12:40'],self.log())

    def test_rename_prompt_and_request(self):
        self.run_script('main.sh','overwrite')
        prompt=[line for line in self.log() if line[0]=='command-prompt'][-1]
        self.assertEqual(prompt[2],'POMODORO:')
        self.assertIn('session-overwrite.sh',prompt[3])
        self.run_script('session-overwrite.sh','新しい 名前')
        request=self.log('api.log')[-1]
        self.assertTrue(request[-1].endswith('/session-name'))
        self.assertEqual(json.loads(request[request.index('--data')+1]),{'name':'新しい 名前'})

    def test_duration_command_range_and_request(self):
        for value in ['1','25','1440']:
            self.run_script('change_duration.sh',value)
            request=self.log('api.log')[-1]
            self.assertEqual(json.loads(request[request.index('--data')+1]),{'seconds':int(value)*60})
        for value in ['0','1441','abc']:
            self.assertEqual(self.run_script('change_duration.sh',value,ok=False).returncode,2)

    def test_sync_failure_keeps_cache_and_retry_interval(self):
        before=(self.root/'.pomo-state.json').read_text();self.env['FAIL_API']='1'
        self.run_script('main.sh','sync')
        self.assertIn(['display-message','Timer sync failed'],self.log())
        self.assertEqual((self.root/'.pomo-state.json').read_text(),before)
        self.run_script('main.sh','time')
        self.assertEqual(len(self.log('api.log')),1)

    def test_plugin_key_bindings_and_status_placeholders(self):
        result=subprocess.run(['bash',str(self.root/'pomo.tmux')],env=self.env,text=True,capture_output=True)
        self.assertEqual(result.returncode,0,result.stderr)
        binds={line[1]:line[3] for line in self.log() if line[0]=='bind-key'}
        for key,command in [('p','start'),('P','stop'),('O','overwrite'),('o','sync')]:
            self.assertTrue(binds[key].endswith('/main.sh '+command))
        status=[line[-1] for line in self.log() if line[:3]==['set-option','-gq','status-right']][-1]
        self.assertIn('/scripts/cloud/main.sh time)',status)
        self.assertIn('#{@pomo_name}',status);self.assertIn('#{@pomo_color}',status)

    def test_name_confirmation_resyncs_and_does_not_start_an_active_timer(self):
        self.run_script('session-init.sh','名前',ok=False)
        self.assertIn(['display-message','Session has already started.'],self.log())
        self.assertEqual(len(self.log('api.log')),1)
        self.assertTrue(self.log('api.log')[0][-1].endswith('/timer'))

    def test_local_mode_keeps_existing_bindings(self):
        p=self.root/'.env';p.write_text(p.read_text().replace('USE_LOCAL=false','USE_LOCAL=true'))
        result=subprocess.run(['bash',str(self.root/'pomo.tmux')],env=self.env,text=True,capture_output=True)
        self.assertEqual(result.returncode,0,result.stderr)
        binds={line[1]:line[3] for line in self.log() if line[0]=='bind-key'}
        for key,command in [('p','start'),('P','stop'),('O','overwrite')]:
            self.assertTrue(binds[key].endswith('/scripts/local/main.sh '+command))
        self.assertEqual(binds['o'],'tmux refresh-client -S')
        self.assertEqual(self.log('api.log'),[])

if __name__=='__main__': unittest.main(verbosity=2)
