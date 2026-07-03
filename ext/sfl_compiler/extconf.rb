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
UV_VENDOR_DIR = File.join(GEM_ROOT, "vendor", "uv")
MARKER_FILE = File.join(VENDOR_DIR, ".sfl_compiler_installed")
# Read by SFL::Compiler::Bootstrap at runtime to point PyCall at this
# exact interpreter instead of whatever `python3` the host resolves to.
INTERPRETER_FILE = File.join(VENDOR_DIR, ".sfl_compiler_python_path")

# uv provisions its own standalone CPython builds on demand, so we pin
# an exact, known-good version instead of inheriting whatever `python3`
# the host resolves to. This is what broke on a Python 3.14 host: no
# prebuilt wheels existed yet for spaCy's native deps (blis/thinc),
# forcing a from-source Cython build that failed outright.
PYTHON_VERSION = ENV["SFL_PYTHON_VERSION"] || "3.12"
SPACY_REQUIREMENT = ENV["SFL_SPACY_REQUIREMENT"] || "spacy"
SPACY_MODEL = ENV["SPACY_MODEL"] || "en_core_web_sm"

def run!(*cmd, env: {})
  puts "-> #{cmd.join(' ')}"
  return if system(env, *cmd)

  abort "[sfl-compiler] command failed (#{$CHILD_STATUS.exitstatus}): #{cmd.join(' ')}"
end

def capture!(*cmd)
  output = IO.popen(cmd, &:read)
  abort "[sfl-compiler] command failed (#{$CHILD_STATUS.exitstatus}): #{cmd.join(' ')}" unless $CHILD_STATUS.success?

  output.strip
end

def write_stub_makefile
  # No compilation step; "all"/"install"/"clean" just need to exist so
  # `make` (invoked by RubyGems after this script) succeeds.
  recipe = "all:\n\t@:\n\ninstall:\n\t@:\n\nclean:\n\t@:\n"
  File.write(File.join(__dir__, "Makefile"), recipe)
end

def uv_available?
  system("uv", "--version", out: File::NULL, err: File::NULL)
end

# Installs uv into vendor/uv (not the host's ~/.local/bin) via the
# official installer, so a host with neither Python nor uv ends up with
# everything this gem needs self-contained under its own install dir.
def bootstrap_uv!
  unless system("curl", "--version", out: File::NULL, err: File::NULL)
    abort <<~MSG
      [sfl-compiler] 'uv' is not on PATH and 'curl' is not available to install it.
      Install uv yourself (see https://docs.astral.sh/uv/getting-started/installation/)
      and re-run `bundle install`/`gem install`.
    MSG
  end

  puts "[sfl-compiler] 'uv' not found on PATH; installing to #{UV_VENDOR_DIR} via the official " \
    "installer (https://astral.sh/uv/install.sh)"
  FileUtils.mkdir_p(UV_VENDOR_DIR)

  installer_env = { "UV_INSTALL_DIR" => UV_VENDOR_DIR, "UV_NO_MODIFY_PATH" => "1" }
  run!("sh", "-c", "curl -LsSf https://astral.sh/uv/install.sh | sh", env: installer_env)

  uv_bin = File.join(UV_VENDOR_DIR, "uv")
  abort "[sfl-compiler] uv installer ran but #{uv_bin} was not produced" unless File.executable?(uv_bin)

  uv_bin
end

UV = uv_available? ? "uv" : bootstrap_uv!

FileUtils.mkdir_p(VENDOR_DIR)

# Idempotent and near-instant once installed (uv just checks its cache),
# so this runs every time to keep INTERPRETER_FILE accurate even when the
# pip install below is skipped.
run!(UV, "python", "install", PYTHON_VERSION)

python = capture!(UV, "python", "find", PYTHON_VERSION)
abort "[sfl-compiler] uv could not locate a Python #{PYTHON_VERSION} interpreter" if python.empty?
File.write(INTERPRETER_FILE, "#{python}\n")

if File.exist?(MARKER_FILE) && ENV["SFL_FORCE_PYTHON_VENDOR"] != "1"
  puts "[sfl-compiler] vendored Python deps already present at #{VENDOR_DIR}, skipping " \
    "(set SFL_FORCE_PYTHON_VENDOR=1 to reinstall)"
else
  # --target keeps every installed package self-contained under
  # vendor/python inside this gem's own install directory: nothing
  # touches the system or user Python site-packages.
  #
  # "click" is forced explicitly: spaCy's CLI (spacy/cli/_util.py)
  # imports it directly, but recent typer releases (0.16+) dropped
  # click as a hard dependency, so an unpinned `spacy` install can
  # silently omit it and fail at `spacy download`/`spacy info` time.
  #
  # "numpy<2" is forced explicitly: the Ruby `numpy` gem pycall/ruby-spacy
  # depend on (0.4.0, the only release) hardcodes `numpy.chararray`, which
  # NumPy 2.0 removed outright. An unpinned `spacy` install resolves the
  # latest NumPy and PyCall.init blows up at require time with
  # `NoMethodError: undefined method 'chararray'` the moment Bootstrap
  # points ruby-spacy at this vendor dir.
  run!(UV, "pip", "install", "--python", python, "--target", VENDOR_DIR,
    SPACY_REQUIREMENT, "click", "numpy<2")

  # Delegate model selection to spaCy's own downloader rather than
  # hardcoding a model wheel version/URL: spaCy resolves the model
  # release that's actually compatible with whatever spaCy version was
  # just installed, avoiding a hardcoded pin drifting out of sync.
  # PYTHONPATH makes the vendored spaCy importable; extra args after
  # the model name are forwarded by spaCy straight to `pip install`.
  run!(python, "-m", "spacy", "download", SPACY_MODEL, "--target", VENDOR_DIR,
    env: { "PYTHONPATH" => VENDOR_DIR })

  File.write(MARKER_FILE, "python==#{PYTHON_VERSION} #{SPACY_REQUIREMENT} #{SPACY_MODEL}\n")
end

write_stub_makefile
