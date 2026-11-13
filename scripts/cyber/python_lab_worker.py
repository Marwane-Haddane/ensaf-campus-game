"""Bounded Python teaching interpreter. No eval/exec, host imports or file APIs exposed."""
import ast
import itertools
import json
import sys

class Lab:
    def __init__(self):
        self.env = {}
        self.output = []
        self.steps = 0
        self.used_permutations = False
    def tick(self):
        self.steps += 1
        if self.steps > 80000:
            raise ValueError("Execution budget exceeded; reduce your search space.")
    def bound(self, value):
        pending = [(value, 0)]
        count = 0
        while pending:
            item, depth = pending.pop()
            count += 1
            if count > 20000 or depth > 8:
                raise ValueError("Nested value exceeds lab budget.")
            if isinstance(item, (list, tuple, set)):
                pending.extend((child, depth + 1) for child in item)
        if isinstance(value, (str, list, tuple, set, dict)) and len(value) > 4096:
            raise ValueError("Value exceeds 4096 elements/characters.")
        if isinstance(value, int) and abs(value) > 1000000:
            raise ValueError("Integer exceeds lab limit.")
        return value
    def expr(self, n):
        self.tick()
        if isinstance(n, ast.Constant): return self.bound(n.value)
        if isinstance(n, ast.Name):
            if n.id not in self.env: raise ValueError("Unknown name: " + n.id)
            return self.env[n.id]
        if isinstance(n, (ast.List, ast.Tuple, ast.Set)):
            values = [self.expr(x) for x in n.elts]
            return self.bound(set(values) if isinstance(n, ast.Set) else tuple(values) if isinstance(n, ast.Tuple) else values)
        if isinstance(n, ast.BinOp) and isinstance(n.op, ast.Add): return self.bound(self.expr(n.left) + self.expr(n.right))
        if isinstance(n, ast.Subscript): return self.expr(n.value)[self.expr(n.slice)]
        if isinstance(n, ast.Compare) and len(n.ops) == 1:
            a,b = self.expr(n.left), self.expr(n.comparators[0])
            if isinstance(n.ops[0], ast.NotIn): return a not in b
            if isinstance(n.ops[0], ast.In): return a in b
            if isinstance(n.ops[0], ast.Eq): return a == b
            if isinstance(n.ops[0], ast.NotEq): return a != b
        if isinstance(n, ast.Call):
            args = [self.expr(x) for x in n.args]
            if n.keywords: raise ValueError("Keyword arguments are not supported in this lab.")
            if isinstance(n.func, ast.Name):
                name = n.func.id
                if name == "print":
                    line = " ".join(str(self.bound(x)) for x in args)
                    if len(line) > 128 or len(self.output) >= 4096: raise ValueError("Output limit: 4096 lines, 128 characters each.")
                    self.output.append(line)
                    return None
                if name in ("permutations", "product") and self.env.get(name) == "itertools." + name:
                    if not args or any(not isinstance(x,(str,list,tuple)) for x in args[:1]): raise ValueError("Expected a sequence.")
                    if name == "permutations":
                        if len(args[0]) > 8: raise ValueError("Use at most 8 clue tokens.")
                        self.used_permutations = True
                        values = itertools.permutations(*args)
                    else: values = itertools.product(*args)
                    result = list(itertools.islice(values, 4097))
                    return self.bound(result)
                allowed = {"str":str,"len":len,"set":set,"list":list,"sorted":sorted,"range":lambda *a:list(range(*a)) if len(range(*a)) <= 4096 else (_ for _ in ()).throw(ValueError("Range too large"))}
                if name in allowed: return self.bound(allowed[name](*args))
            if isinstance(n.func, ast.Attribute):
                obj = self.expr(n.func.value)
                name = n.func.attr
                if isinstance(obj,str) and name in ("lower","upper","title","capitalize","join","replace","strip"):
                    return self.bound(getattr(obj,name)(*args))
                if isinstance(obj,set) and name == "add": obj.add(*args); self.bound(obj); return None
                if isinstance(obj,list) and name == "append": obj.append(*args); self.bound(obj); return None
            raise ValueError("Unsupported function. Use print, permutations, product, str, len, set, list, sorted or range.")
        raise ValueError("Unsupported expression: " + type(n).__name__)
    def block(self, nodes):
        for n in nodes:
            self.tick()
            if isinstance(n, ast.ImportFrom) and n.module == "itertools" and n.level == 0:
                for alias in n.names:
                    if alias.name not in ("permutations","product"): raise ValueError("Only itertools permutations/product are available.")
                    self.env[alias.asname or alias.name] = "itertools."+alias.name
            elif isinstance(n, ast.Assign) and len(n.targets)==1 and isinstance(n.targets[0],ast.Name): self.env[n.targets[0].id] = self.expr(n.value)
            elif isinstance(n, ast.Expr): self.expr(n.value)
            elif isinstance(n, ast.For) and isinstance(n.target, ast.Name):
                for value in self.expr(n.iter):
                    self.env[n.target.id] = value
                    self.block(n.body)
                self.block(n.orelse)
            elif isinstance(n, ast.If): self.block(n.body if self.expr(n.test) else n.orelse)
            elif isinstance(n, ast.Pass): pass
            else: raise ValueError("Unsupported statement: " + type(n).__name__ + ". Use assignments, for loops and if statements.")

def run(source):
    try:
        if len(source)>12000: raise ValueError("Script exceeds 12 KB.")
        tree = ast.parse(source)
        lab = Lab()
        lab.block(tree.body)
        return {"ok":True,"text":"\n".join(lab.output),"permutations":lab.used_permutations,"steps":lab.steps}
    except Exception as error:
        return {"ok":False,"error":str(error)}

if __name__ == "__main__":
    request = json.loads(sys.stdin.read(16000)) if len(sys.argv)<2 else json.loads(open(sys.argv[1], encoding="utf-8").read(16000))
    print(json.dumps(run(request.get("source",""))))
