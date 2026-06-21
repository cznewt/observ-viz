import sys
from enum import IntEnum
from pathlib import Path


class Result(IntEnum):
    success = 0
    fail = 1


result = Result.fail

all_engs = []
docs_path = Path("docs")
ref_path = docs_path / "ref"
eng_path = ref_path / "engines"

for path in Path("vector-engine/src").glob("**/*.py"):
    if path.parent.name in ["engines"]:
        kind = path.parent.name
        import_path = ".".join(path.with_suffix("").parts[2:])
        if kind == "engines":
            all_engs.append(import_path)
            rst_path = eng_path / (import_path + ".rst")

        rst_path.parent.mkdir(parents=True, exist_ok=True)
        rst_path.write_text(
            f"""
{import_path}
{'='*len(import_path)}

.. automodule:: {import_path}
    :members:
"""
        )

        # print(import_path)
        # print(kind, path)

eng_rst = eng_path / "all.rst"
eng_rst.parent.mkdir(parents=True, exist_ok=True)

eng_rst.write_text(
    f"""
.. all-saltext.vector.engines:

-------
Engines
-------

.. autosummary::
    :toctree:

{chr(10).join(sorted('    '+eng for eng in all_engs))}
"""
)
