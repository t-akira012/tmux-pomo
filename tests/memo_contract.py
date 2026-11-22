import json
import subprocess
import unittest
import cloud_contract


class MemoContract(unittest.TestCase):
    setUp = cloud_contract.CloudContract.setUp
    tearDown = cloud_contract.CloudContract.tearDown
    script = cloud_contract.CloudContract.script
    reply = cloud_contract.CloudContract.reply
    cache = cloud_contract.CloudContract.cache
    run_script = cloud_contract.CloudContract.run_script
    log = cloud_contract.CloudContract.log

    def prepare(self, original='- [ ] 日本語\n\n', saved=None):
        self.reply('memo', {'text': original})
        if saved is not None:
            self.env['SAVED_MEMO'] = saved
        self.script('nvim', '''#!/usr/bin/env python3
import os,sys
from pathlib import Path
if 'SAVED_MEMO' in os.environ: Path(sys.argv[1]).write_text(os.environ['SAVED_MEMO'])
if os.environ.get('EDITOR_FAIL'): sys.exit(1)
''')
        p = self.bin / 'tmux'
        p.write_text(p.read_text().replace('import json,os,sys', 'import json,os,sys,subprocess') + '''
if args and args[0]=='display-popup':
    sys.exit(subprocess.run(args[args.index('bash'):]).returncode)
''')
        p = self.bin / 'curl'
        p.write_text(p.read_text().replace("if os.environ.get('FAIL_API'):sys.exit(22)", """if os.environ.get('FAIL_API') or (os.environ.get('FAIL_PUT') and args[args.index('-X')+1]=='PUT'):sys.exit(22)
if '--data-binary' in args:
    (root/'uploaded.json').write_text(Path(args[args.index('--data-binary')+1][1:]).read_text())"""))

    def memo_dir(self):
        popup = [x for x in self.log() if x[0] == 'display-popup'][-1]
        from pathlib import Path
        return Path(popup[-1])

    def test_saved_content_puts_exact_text_then_cleans(self):
        saved = '- [x] 日本語 "quoted"\n\n'
        self.prepare(saved=saved)
        self.run_script('memo.sh')
        self.assertEqual(json.loads((self.root/'uploaded.json').read_text()), {'text': saved})
        requests = self.log('api.log')
        self.assertEqual([x[x.index('-X')+1] for x in requests], ['GET', 'PUT'])
        self.assertTrue(all(x[-1].endswith('/memo') for x in requests))
        self.assertFalse(self.memo_dir().exists())

    def test_discard_or_unchanged_does_not_put(self):
        self.prepare()
        self.run_script('memo.sh')
        self.assertEqual(len(self.log('api.log')), 1)
        self.assertFalse(self.memo_dir().exists())

    def test_empty_saved_memo_puts_empty_string(self):
        self.prepare(saved='')
        self.run_script('memo.sh')
        self.assertEqual(json.loads((self.root/'uploaded.json').read_text()), {'text': ''})

    def test_failed_pull_never_opens_editor(self):
        self.prepare()
        self.env['FAIL_API'] = '1'
        self.run_script('memo.sh', ok=False)
        self.assertFalse(any(x[0]=='display-popup' for x in self.log()))

    def test_failed_put_retains_saved_file(self):
        self.prepare(saved='saved draft\n')
        self.env['FAIL_PUT'] = '1'
        self.run_script('memo.sh', ok=False)
        directory = self.memo_dir()
        try:
            self.assertEqual((directory/'memo.md').read_text(), 'saved draft\n')
            self.assertTrue(any(str(directory/'memo.md') in x[-1] for x in self.log() if x[0]=='display-message'))
        finally:
            import shutil
            shutil.rmtree(directory)

    def test_editor_failure_keeps_file_and_never_puts(self):
        self.prepare(saved='saved before failure')
        self.env['EDITOR_FAIL'] = '1'
        self.run_script('memo.sh', ok=False)
        directory = self.memo_dir()
        try:
            self.assertTrue((directory/'memo.md').exists())
            self.assertEqual(len(self.log('api.log')), 1)
        finally:
            import shutil
            shutil.rmtree(directory)


if __name__ == '__main__':
    unittest.main(verbosity=2)
