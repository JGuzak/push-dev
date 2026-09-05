#!/usr/bin/env python3
"""Exercise payload commands against a fake kernel, never real modules."""
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

PAYLOAD = Path(__file__).resolve().parents[1] / 'scripts' / 'payload'
MOCK = r'''#!/usr/bin/env python3
import os
from pathlib import Path
import shutil
import sys
cmd, args = Path(sys.argv[0]).name, sys.argv[1:]
root = Path(os.environ['TEST_SYS_ROOT'])
if cmd == 'id':
    print(os.environ.get('TEST_UID', '0'))
elif cmd == 'uname':
    print('test-kernel')
elif cmd == 'modinfo':
    if args[1] == 'name':
        print(os.environ.get('TEST_MODULE_NAME', Path(args[2]).stem.replace('-', '_')))
    else:
        print(os.environ.get('TEST_VERMAGIC', 'test-kernel SMP'))
else:
    with Path(os.environ['TEST_CALLS']).open('a') as output:
        output.write(cmd + ' ' + ' '.join(args) + '\n')
    if cmd == 'insmod':
        if os.environ.get('TEST_LOAD_FAIL') == '1':
            sys.exit(1)
        if os.environ.get('TEST_LOAD_NO_STATE') != '1':
            (root / Path(args[0]).stem.replace('-', '_')).mkdir()
    elif cmd == 'rmmod':
        count_file = root.parent / 'rmmod-count'
        count = int(count_file.read_text()) + 1 if count_file.exists() else 1
        count_file.write_text(str(count))
        if count <= int(os.environ.get('TEST_BUSY_ATTEMPTS', '0')):
            print('module in use', file=sys.stderr)
            sys.exit(1)
        shutil.rmtree(root / args[0])
'''


class PayloadTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.package = self.root / 'package with spaces'
        self.package.mkdir()
        self.sysroot = self.root / 'modules'
        self.sysroot.mkdir()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        mock = self.bin / 'mock'
        mock.write_text(MOCK)
        mock.chmod(0o755)
        for name in ('id', 'uname', 'modinfo', 'insmod', 'rmmod', 'sleep'):
            (self.bin / name).symlink_to(mock)
        self.env = dict(os.environ, PATH=str(self.bin) + ':' + os.environ['PATH'],
                        TEST_SYS_ROOT=str(self.sysroot), TEST_CALLS=str(self.root / 'calls'))

    def package_modules(self, *names):
        lines = []
        for name in names:
            data = ('fake module ' + name).encode()
            (self.package / (name + '.ko')).write_bytes(data)
            lines.append(hashlib.sha256(data).hexdigest() + '  ' + name + '.ko\n')
        (self.package / 'checksums.txt').write_text(''.join(lines))

    def loaded(self, name):
        (self.sysroot / name).mkdir()
        (self.sysroot / name / 'refcnt').write_text('1\n')

    def calls(self):
        path = self.root / 'calls'
        return path.read_text().splitlines() if path.exists() else []

    def run_payload(self, script='install', *args, ok=True):
        # Only sysfs access and OS commands are mocked; CLI and lifecycle logic
        # execute unchanged. Real checksum tools verify the fixture manifests.
        shell = '''source "$1"
shift
module_sys_path() { printf '%s/%s\n' "$TEST_SYS_ROOT" "$1"; }
check_usbmon_clean() { [[ "${TEST_USBMON_RESIDUE:-0}" == 0 ]]; }
main "$@"
'''
        result = subprocess.run(['bash', '-eu', '-c', shell, 'test',
                                 str(PAYLOAD / (script + '.sh')),
                                 '-p', str(self.package), *args], env=self.env,
                                text=True, capture_output=True, timeout=15)
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return result

    def test_fresh_load_and_idempotence(self):
        self.package_modules('example')
        self.run_payload()
        self.run_payload()
        self.assertEqual(len(self.calls()), 1)

    def test_root_and_help(self):
        self.package_modules('example')
        self.env['TEST_UID'] = '1000'
        for script in ('install', 'uninstall'):
            self.run_payload(script, '--help')
            self.run_payload(script, ok=False)
        self.assertEqual(self.calls(), [])

    def test_arguments_and_empty_package(self):
        self.run_payload('install', '--force', ok=False)
        self.run_payload('uninstall', '-p', ok=False)
        self.run_payload(ok=False)
        self.assertEqual(self.calls(), [])

    def test_checksum_failure_before_unload(self):
        self.package_modules('example')
        self.loaded('example')
        (self.package / 'example.ko').write_text('corrupt')
        self.run_payload('install', '--reload', ok=False)
        self.assertEqual(self.calls(), [])

    def test_manifest_coverage(self):
        self.package_modules('example')
        (self.package / 'extra.ko').write_text('unlisted')
        self.run_payload(ok=False)
        self.assertEqual(self.calls(), [])

    def test_release_mismatch(self):
        self.package_modules('example')
        self.env['TEST_VERMAGIC'] = 'different-kernel SMP'
        self.run_payload(ok=False)
        self.assertEqual(self.calls(), [])

    def test_invalid_and_duplicate_names(self):
        self.package_modules('first', 'second')
        for name in ('../../unsafe', 'duplicate'):
            self.env['TEST_MODULE_NAME'] = name
            self.run_payload(ok=False)
        self.assertEqual(self.calls(), [])

    def test_reload_order(self):
        self.package_modules('first', 'second')
        self.loaded('first')
        self.loaded('second')
        self.run_payload('install', '--reload')
        self.assertEqual(self.calls()[:2], ['rmmod second', 'rmmod first'])
        self.assertEqual(len(self.calls()), 4)

    def test_uninstall_idempotent_and_recovery(self):
        self.package_modules('example')
        self.loaded('example')
        (self.package / 'checksums.txt').unlink()
        self.env['TEST_VERMAGIC'] = 'different-kernel'
        self.run_payload('uninstall')
        self.run_payload('uninstall')
        self.assertEqual(self.calls(), ['rmmod example'])
        self.assertTrue((self.package / 'example.ko').exists())

    def test_busy_failure_bounded(self):
        self.package_modules('example')
        self.loaded('example')
        self.env['TEST_BUSY_ATTEMPTS'] = '99'
        self.run_payload('install', '--reload', ok=False)
        self.assertEqual(self.calls().count('rmmod example'), 5)
        self.assertEqual(self.calls().count('sleep 1'), 4)
        self.assertFalse(any(call.startswith('insmod') for call in self.calls()))

    def test_busy_then_success(self):
        self.package_modules('example')
        self.loaded('example')
        self.env['TEST_BUSY_ATTEMPTS'] = '2'
        self.run_payload('uninstall')
        self.assertEqual(self.calls().count('rmmod example'), 3)

    def test_usbmon_loaded_and_reload_guard(self):
        self.package_modules('usbmon')
        self.loaded('usbmon')
        self.run_payload()
        self.run_payload('install', '--reload', ok=False)
        self.assertEqual(self.calls(), [])

    def test_usbmon_stale_blocks_load(self):
        self.package_modules('usbmon')
        self.env['TEST_USBMON_RESIDUE'] = '1'
        self.run_payload(ok=False)
        self.assertEqual(self.calls(), [])

    def test_usbmon_unload_reports_residue(self):
        self.package_modules('usbmon')
        self.loaded('usbmon')
        self.env['TEST_USBMON_RESIDUE'] = '1'
        self.run_payload('uninstall', ok=False)
        self.assertEqual(self.calls(), ['rmmod usbmon'])
        self.assertFalse((self.sysroot / 'usbmon').exists())

    def test_load_failure_and_postcondition(self):
        self.package_modules('example')
        self.env['TEST_LOAD_FAIL'] = '1'
        self.run_payload(ok=False)
        del self.env['TEST_LOAD_FAIL']
        self.env['TEST_LOAD_NO_STATE'] = '1'
        self.run_payload(ok=False)


if __name__ == '__main__':
    unittest.main()
