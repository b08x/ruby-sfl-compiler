# frozen_string_literal: true

# There is no C code here. This file exists only so RubyGems' native
# extension phase (`gem install` / `bundle install` with a git/path
# source) runs it, which lets us check for and vendor this gem's
# Python dependency (spaCy + its model) at install time instead of
# failing at runtime the first time PassOneEngine touches PyCall.
#
# RubyGems builds extensions in place inside the installed gem
# (Gem::Ext::Builder#build_extension resolves extension_dir from
# spec.full_gem_path, not a tmp copy), so `__dir__` here is the
# permanent ext/sfl_compiler/ path and writing vendor/ two levels up
# lands inside the installed gem, not a throwaway build directory.

require "English"
require "fileutils"

GEM_ROOT = File.expand_path("../..", __dir__)
VENDOR_DIR = File.join(GEM_ROOT, "vendor", "python")
MARKER_FILE = File.join(VENDOR_DIR, ".sfl_compiler_installed")

PYTHON = ENV["SFL_PYTHON"] || ENV["PYTHON"] || "python3"
SPACY_REQUIREMENT = ENV["SFL_SPACY_REQUIREMENT"] || "spacy"
SPACY_MODEL = ENV["SPACY_MODEL"] || "en_core_web_sm"

def run!(*cmd, env: {})
  puts "-> #{cmd.join(' ')}"
  return if system(env, *cmd)

  abort "[sfl-compiler] command failed (#{$CHILD_STATUS.exitstatus}): #{cmd.join(' ')}"
end

def python_available?
  system(PYTHON, "--version", out: File::NULL, err: File::NULL)
end

def write_stub_makefile
  # No compilation step; "all"/"install"/"clean" just need to exist so
  # `make` (invoked by RubyGems after this script) succeeds.
  recipe = "all:\n\t@:\n\ninstall:\n\t@:\n\nclean:\n\t@:\n"
  File.write(File.join(__dir__, "Makefile"), recipe)
end

unless python_available?
  abort <<~MSG
    [sfl-compiler] Python interpreter '#{PYTHON}' not found on PATH.
    Install Python 3.9+ (spaCy's minimum) and re-run `bundle install`/`gem install`,
    or point at a specific interpreter with SFL_PYTHON=/path/to/python3.
  MSG
end

if File.exist?(MARKER_FILE) && ENV["SFL_FORCE_PYTHON_VENDOR"] != "1"
  puts "[sfl-compiler] vendored Python deps already present at #{VENDOR_DIR}, skipping " \
    "(set SFL_FORCE_PYTHON_VENDOR=1 to reinstall)"
else
  FileUtils.mkdir_p(VENDOR_DIR)

  # --target keeps every installed package self-contained under
  # vendor/python inside this gem's own install directory: nothing
  # touches the system or user Python site-packages.
  run!(PYTHON, "-m", "pip", "install", "--upgrade", "--target", VENDOR_DIR, SPACY_REQUIREMENT)

  # Delegate model selection to spaCy's own downloader rather than
  # hardcoding a model wheel version/URL: spaCy resolves the model
  # release that's actually compatible with whatever spaCy version pip
  # just installed above (which varies by Python version/platform
  # wheel availability), avoiding a hardcoded pin drifting out of sync
  # and forcing a from-source rebuild of native deps like blis/thinc.
  # PYTHONPATH makes the vendored spaCy importable; extra args after
  # the model name are forwarded by spaCy straight to `pip install`.
  run!(PYTHON, "-m", "spacy", "download", SPACY_MODEL, "--target", VENDOR_DIR,
    env: { "PYTHONPATH" => VENDOR_DIR })

  File.write(MARKER_FILE, "#{SPACY_REQUIREMENT} #{SPACY_MODEL}\n")
end

write_stub_makefile
