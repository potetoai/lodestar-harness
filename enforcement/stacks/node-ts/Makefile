# Lodestar command contract (see lodestar-harness rules/enforcement.md).
# Target names are fixed: hooks and CI call them. Recipes belong to this
# project; change them freely.
# Expects devDependencies: eslint, prettier, typescript, @stryker-mutator/core
# (installed by `make setup`).
.PHONY: setup lint lint-file format-check typecheck test test-related verify verify-quick verify-full test-mutation

NPX = npx --no-install

setup:
	@if [ -f package-lock.json ]; then npm ci; else npm install; fi

lint:
	$(NPX) eslint .

# Format, then lint, one file (called by the edit hook after every edit), so
# format-check never fails on the agent's code. Prettier skips unknown types;
# ESLint runs on script files only.
lint-file:
	@$(NPX) prettier --write --ignore-unknown --log-level warn "$(FILE)"
	@case "$(FILE)" in *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) $(NPX) eslint "$(FILE)" ;; esac

format-check:
	$(NPX) prettier --check .

typecheck:
	$(NPX) tsc --noEmit

test:
	npm test

# The tests that import the changed files (CHANGED, set by the Stop hook):
# Vitest `related`, Jest `--findRelatedTests`; another runner runs them all.
test-related:
	@if [ -z "$(strip $(CHANGED))" ]; then echo "test-related: no changed files"; \
	elif [ -f node_modules/.bin/vitest ]; then $(NPX) vitest related --run --passWithNoTests $(CHANGED); \
	elif [ -f node_modules/.bin/jest ]; then $(NPX) jest --passWithNoTests --findRelatedTests $(CHANGED); \
	else npm test; fi

# Quick checks, run by the Stop hook on every stop: seconds, not minutes. CI
# runs the full verify on the PR; while CI cannot run, the hook runs verify.
verify-quick: format-check lint typecheck test-related

# All fast checks, run by CI and by the Stop hook while CI cannot run. Keep it
# under ~3 minutes. The last line records the pass, so the Stop hook does not
# run it a second time.
verify: format-check lint typecheck test
	@[ "$(MAKELEVEL)" != 0 ] || [ ! -f .claude/hooks/verify-before-stop.sh ] || bash .claude/hooks/verify-before-stop.sh --record-pass

# Everything, run by CI. Add integration/E2E targets here.
verify-full: verify

# Mutation testing (rules/testing.md): break the given files on purpose with
# Stryker; `npm test` must fail. Prints the score and the surviving mutants.
# CI runs it on changed files in sensitive_paths: make test-mutation FILES="a.ts b.ts".
test-mutation:
	@files=$$(printf '%s\n' $(FILES) | grep -E '\.[cm]?[jt]sx?$$' | paste -sd, -); \
	if [ -z "$$files" ]; then echo "mutation: no JS/TS files to mutate"; \
	elif ! $(NPX) stryker --version >/dev/null 2>&1; then echo "Mutation testing not set up: add the devDependency @stryker-mutator/core"; \
	else $(NPX) stryker run --testRunner command --mutate "$$files" --reporters clear-text --logLevel warn --concurrency 2; fi
