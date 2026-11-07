---
name: repo-consistency-audit
description: Find places where this repo contradicts itself, such as version pins, documented versus actual architecture, config paths pointing at directories that no longer exist, tooling installed but never run, and rules in .claude that no longer match the code. Use whenever asked to check the repo for stale docs, mismatched Ruby versions, dead config, unused gems, orphaned classes or an out-of-date README, and before onboarding someone. Read-only unless told to fix. Not for what the API promises clients (api-contract-audit).
---

Scope: $ARGUMENTS (default: all sections)

Audit the repository for internal contradictions. A stale README teaches the wrong architecture
to every new reader, and a config path pointing at a directory that no longer exists silently
does nothing.

Report findings; fix only what the user asks for.

## 1. Version pins must agree

| Runtime | Declared in |
| --- | --- |
| Ruby | `.ruby-version`, `Gemfile` (`ruby` line), `Dockerfile` (`ARG RUBY_VERSION`), `README.md`, `.rubocop.yml` (`TargetRubyVersion`), `CLAUDE.md` |
| Rails | `Gemfile`, `Gemfile.lock`, `README.md`, `config/application.rb` (`load_defaults`), `CLAUDE.md` |
| Bundler | `Gemfile.lock` (`BUNDLED WITH`) |

```sh
cat .ruby-version
grep -nE "^ruby|gem 'rails'" Gemfile
grep -nE "RUBY_VERSION" Dockerfile
grep -nE "Ruby|Rails" README.md
```

## 2. Documented architecture must match the tree

Compare `CLAUDE.md`, `.claude/rules/rails-architecture.md` and `README.md` against `ls app/`. A
layer named in the docs that does not exist, or a directory in `app/` no doc mentions, is a finding.

## 3. Rules must match the code

The rules in `.claude/rules` and the skills in `.claude/skills` make specific claims. Spot-check
them: every path they name exists, every class and helper exists, and what they say a gem does
still holds for the locked version. Rules record known breakage, such as pagination in
`.claude/rules/controllers.md`; if the code has been fixed, the rule is what is now stale.

## 4. Config paths must point at directories that exist

```sh
grep -n "add_group\|add_filter" spec/rails_helper.rb
grep -nE "Exclude|Include" -A3 .rubocop.yml
grep -n "autoload_lib\|eager_load_paths" config/application.rb
```

For each path, check the directory exists. `.rubocop.yml` also has `spec/**/*'` entries with a
stray quote, which match nothing.

## 5. Installed tooling must actually run

This repo has no CI and no git hooks, so "where does it run" may have no answer. For each gem that
exists to be run (`brakeman`, `rubocop`, `simplecov`, `bullet`, `annotaterb`), find a documented
command or say that nothing enforces it.

## 6. Declared configuration must be used

- a test gem with no specs using it
- an ENV var in `.env.sample` that no code reads, or read by code but absent from `.env.sample`
- a key in a config file that the locked gem version no longer reads

```sh
grep -rnE "ENV(\[|\.fetch)" config/ app/ spec/ | grep -oE "ENV(\[|\.fetch\()['\"][A-Z_]+" | sort -u
cat .env.sample
```

## 7. Dead code

A class with no caller and no spec is where contract bugs hide. Search for callers of each object in
`app/operations`, `app/queries` and `app/decorators`, and of helpers such as `filter_params` and
`order_params` in `ApplicationController`. Report the orphans.

## Reporting

Group by severity: things that are actively wrong, things that silently do nothing, and cosmetic
staleness. Give the file:line and the one-line fix for each.
