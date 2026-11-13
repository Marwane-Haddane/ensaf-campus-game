import importlib.util
import pathlib
import unittest
source = pathlib.Path(__file__).resolve().parents[1] / "scripts/cyber/python_lab_worker.py"
spec = importlib.util.spec_from_file_location("worker", source)
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)
class RunnerTests(unittest.TestCase):
    def test_real_permutations(self):
        result = worker.run('from itertools import permutations\nfor pair in permutations(["Nora", "1998"], 2):\n    print("@".join(pair))')
        self.assertTrue(result["ok"])
        self.assertTrue(result["permutations"])
        self.assertEqual(result["text"], "Nora@1998\n1998@Nora")
    def test_case_variants(self):
        result = worker.run('name="nora"\nprint(name.title()+"-1998")')
        self.assertEqual(result["text"], "Nora-1998")
    def test_no_host_access(self):
        for source in ['import os', 'print(open("secret"))', '__import__("socket")', 'print("".__class__)', 'exec("print(1)")']:
            with self.subTest(source=source): self.assertFalse(worker.run(source)["ok"])
    def test_source_limit(self):
        self.assertFalse(worker.run("#"*12001)["ok"])
    def test_output_limit(self):
        self.assertFalse(worker.run('for x in range(4096):\n    print(x)\nprint("extra")')["ok"])
    def test_loop_budget(self):
        self.assertFalse(worker.run('for a in range(4096):\n    for b in range(4096):\n        pass')["ok"])
    def test_recursive_value(self):
        self.assertFalse(worker.run('a=[]\na.append(a)\nprint(a)')["ok"])
    def test_syntax_error(self):
        self.assertFalse(worker.run('for :')["ok"])
if __name__ == "__main__": unittest.main()
