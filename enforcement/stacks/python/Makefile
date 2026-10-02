# Lodestar command contract (see lodestar-harness rules/enforcement.md).
# Target names are fixed: hooks and CI call them. Recipes belong to this
# project; change them freely.
.PHONY: setup deps lint lint-file format-check test verify verify-full test-mutation

PYTHON ?= python
# Use the project venv when it exists (bin/ on Linux/macOS, Scripts/ on Windows).
PY = $(firstword $(wildcard .venv/bin/python .venv/Scripts/python.exe) $(PYTHON))

# deps runs in a sub-make: make expands a whole recipe before running it, so
# $(PY) would still point at the system python right after creating the venv.
# Tools go into .venv, never the system Python. VENV_ARGS=--system-site-packages
# lets the venv see packages installed only in the system Python (for example
# one that is not on PyPI).
VENV_ARGS ?=

setup:
	$(PYTHON) -m venv $(VENV_ARGS) .venv
	@$(MAKE) --no-print-directory deps

deps:
	$(PY) -m pip install -q -r requirements-dev.txt

lint:
	$(PY) -m ruff check .

# Format, then lint, one file (called by the edit hook after every edit), so
# format-check never fails on the agent's code. Non-Python files are skipped.
lint-file:
	@case "$(FILE)" in *.py) $(PY) -m ruff format -q "$(FILE)" && $(PY) -m ruff check "$(FILE)" ;; esac

format-check:
	$(PY) -m ruff format --check .

test:
	$(PY) -m pytest -q

# Fast checks, run by the Stop hook. Keep it under ~3 minutes.
verify: format-check lint test

# Everything, run by CI. Add integration/E2E targets here.
verify-full: verify

# Mutation testing (rules/testing.md): break the given files on purpose with
# cosmic-ray; the tests must fail. Prints the score and the surviving mutants.
# CI runs it on changed files in sensitive_paths: make test-mutation FILES="a.py b.py".
# It edits the files while it runs: run it on a clean tree, and check
# `git status` if it was stopped.
test-mutation:
	@$(PY) -c "$$MUTATE_PY" $(FILES)

define MUTATE_PY
import json, os, shlex, subprocess, sys, tempfile
files = [f for f in sys.argv[1:] if f.endswith(".py")]
if not files:
    sys.exit(print("mutation: no Python files to mutate"))
test = shlex.quote(sys.executable.replace("\\", "/")) + " -m pytest -x -q"
if subprocess.run(shlex.split(test), capture_output=True).returncode:
    sys.exit("mutation: the tests fail before any change; fix them first")
cr = [sys.executable, "-m", "cosmic_ray.cli"]
env = dict(os.environ, PYTHONIOENCODING="utf-8")
with tempfile.TemporaryDirectory() as d:
    cfg, db = os.path.join(d, "cr.toml"), os.path.join(d, "session.sqlite")
    with open(cfg, "w") as f:
        f.write("""[cosmic-ray]
module-path = %s
timeout = 60.0
excluded-modules = []
test-command = %s
[cosmic-ray.distributor]
name = "local"
""" % (json.dumps(files), json.dumps(test)))
    for step in ("init", "exec"):
        subprocess.run(cr + [step, cfg, db], check=True, capture_output=True, env=env)
    out = subprocess.run(cr + ["dump", db], check=True, capture_output=True, text=True, env=env).stdout
jobs = [json.loads(line) for line in out.splitlines() if line.strip()]
by = {}
for job, res in jobs:
    by.setdefault(res["test_outcome"] if res else "pending", []).append((job, res))
killed, survived = len(by.get("killed", [])), by.get("survived", [])
total = killed + len(survived)
print("Mutation score: %d%% (%d of %d mutants killed)" % (100 * killed // max(total, 1), killed, total))
if by.get("incompetent"):
    print("%d mutants could not be tested (not counted)" % len(by["incompetent"]))
if survived:
    print("Surviving mutants (each needs a test that fails on it, or a reason why not):")
for job, res in survived:
    m = job["mutations"][0]
    print("  %s:%d  %s" % (m["module_path"].replace("\\", "/"), m["start_pos"][0], m["operator_name"]))
    for line in res["diff"].splitlines():
        if line[:1] in "+-" and line[:3] not in ("+++", "---"):
            print("      " + line)
if by.get("pending"):
    sys.exit("mutation: %d mutants did not run" % len(by["pending"]))
endef
export MUTATE_PY
