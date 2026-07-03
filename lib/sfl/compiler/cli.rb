# frozen_string_literal: true

require "optparse"
require "json"
require "dspy"
require_relative "retrieval/hybrid_retriever"

module SFL
  module Compiler
    # sfl-analyze command line interface. Owns argv parsing, terminal
    # output, and exit codes — and nothing else. All logic lives in the
    # analyzers; .parse is a pure function so it is testable without
    # touching a database or LLM.
    module CLI
      class UsageError < Error; end

      USAGE = <<~TEXT
        Usage: sfl-analyze <subcommand> <input> [options]

        Subcommands:
          conversation <input.jsonl>   Analyze a JSONL conversation (or a folder of
                                        them — one report per file, in subdirectories
                                        of --output-dir named after each file)
          documentation <path>         Analyze a markdown/PDF file or directory
                                        (PDFs are chunked into ~paragraph-sized,
                                        page-anchored sections, not by heading)
          knowledge-base <path>        Assess a KB directory for migration —
                                        classifies artifacts, scores quality,
                                        and produces a migration manifest
          context "<query>"            Query stored clauses, synthesize an answer
          narrate <analysis.json>      Write an LLM narrative from a report JSON
          tui                          Interactive menu (no input argument)

        Common options:
          --output-dir DIR             Where to write reports [./sfl_output]
          --disable-tracing            Skip OpenTelemetry/Langfuse tracing setup

        conversation/documentation:
          --pass1-only                 Skip LLM annotation (placeholder values)
          --narrative                  Also generate narrative_report.md (LLM)
          --topics N                   Number of topics for LDA; 0 = HDP (auto-discover)
          --resume                     Reuse cached Pass 2 results from previous runs

        conversation:
          --live                       Split-pane Bubbletea dashboard instead of
                                        plain progress lines (stats left, log right)

        documentation:
          --store                      Persist clauses + embeddings for `context`
          --sprint-id ID               Attach a Gödel-encoded question-graph
                                        footer ("Sprint G_N = ...") to the report

        context:
          --mood MOOD                  declarative|interrogative|imperative|exclamative
          --min-tenor F  --max-tenor F
          --min-modality F  --max-modality F
          --limit N                    Max clauses to retrieve [10]

        knowledge-base:
          --store                      Persist clauses + embeddings for `context`
          --images / --no-images       Analyze image files via vision LLM (default off)
          --vision-model MODEL         Vision LLM model id (falls back to VISION_MODEL env var)
          --annotated                  Also write annotated/*.md — the original text
                                        per source document, each clause tagged inline
                                        with its process type, mood, tenor, modality

        narrate:
          --output-dir DIR             Where to write narrative_report.md [JSON's directory]
      TEXT

      # @param argv [Array<String>]
      # @return [Hash] {command:, input:, options:}
      module_function def parse(argv)
        argv = argv.dup
        # Normalise hyphens so "knowledge-base" dispatches to parse_knowledge_base_options.
        command = argv.shift&.tr("-", "_")&.to_sym
        unless %i[conversation documentation knowledge_base context narrate tui].include?(command)
          raise UsageError, "Unknown subcommand: #{command}\n\n#{USAGE}"
        end

        if command == :tui
          return { command:, input: nil, options: parse_tui_options(argv) }
        end

        input = argv.shift
        raise UsageError, "#{command} requires an input argument\n\n#{USAGE}" if input.nil? || input.start_with?("--")

        options = send(:"parse_#{command}_options", argv)
        { command:, input:, options: }
      end

      # Shared across every parse_*_options method so `--disable-tracing`
      # behaves identically everywhere instead of being redefined 5×.
      module_function def add_tracing_option(opt, options)
        options[:disable_tracing] = false
        opt.on("--disable-tracing") { options[:disable_tracing] = true }
      end

      module_function def parse_conversation_options(argv)
        options = {
          output_dir: "./output/latest",
          pass1_only: false,
          resume: false,
          narrative: false,
          topics: nil,
          live: false,
        }
        OptionParser.new do |opt|
          opt.on("--output-dir DIR") { |v| options[:output_dir] = v }
          opt.on("--pass1-only") { options[:pass1_only] = true }
          opt.on("--resume") { options[:resume] = true }
          opt.on("--narrative") { options[:narrative] = true }
          opt.on("--topics N", Integer) { |v| options[:topics] = v }
          opt.on("--live") { options[:live] = true }
          add_tracing_option(opt, options)
        end.parse!(argv)
        options
      end

      module_function def parse_documentation_options(argv)
        options = {
          output_dir: "./output/latest",
          pass1_only: false,
          resume: false,
          store: false,
          narrative: false,
          topics: nil,
          sprint_id: nil,
          live: false,
        }
        OptionParser.new do |opt|
          opt.on("--output-dir DIR") { |v| options[:output_dir] = v }
          opt.on("--pass1-only") { options[:pass1_only] = true }
          opt.on("--resume") { options[:resume] = true }
          opt.on("--store") { options[:store] = true }
          opt.on("--narrative") { options[:narrative] = true }
          opt.on("--topics N", Integer) { |v| options[:topics] = v }
          opt.on("--sprint-id ID") { |v| options[:sprint_id] = v }
          opt.on("--live") { options[:live] = true }
          add_tracing_option(opt, options)
        end.parse!(argv)
        options
      end

      module_function def parse_knowledge_base_options(argv)
        options = {
          output_dir:   "./output/latest",
          store:        false,
          images:       false,
          vision_model: nil,
          resume:       false,
          annotated:    false,
        }
        OptionParser.new do |opt|
          opt.on("--output-dir DIR") { |v| options[:output_dir] = v }
          opt.on("--store") { options[:store] = true }
          opt.on("--images") { options[:images] = true }
          opt.on("--no-images") { options[:images] = false }
          opt.on("--vision-model MODEL") { |v| options[:vision_model] = v }
          opt.on("--resume") { options[:resume] = true }
          opt.on("--annotated") { options[:annotated] = true }
          add_tracing_option(opt, options)
        end.parse!(argv)
        options
      end

      module_function def parse_context_options(argv)
        options = { output_dir: nil, limit: 10, filters: {} }
        OptionParser.new do |opt|
          opt.on("--output-dir DIR") { |v| options[:output_dir] = v }
          opt.on("--limit N", Integer) { |v| options[:limit] = v }
          opt.on("--mood MOOD") { |v| options[:filters][:mood] = v }
          opt.on("--min-tenor F", Float) { |v| options[:filters][:min_tenor] = v }
          opt.on("--max-tenor F", Float) { |v| options[:filters][:max_tenor] = v }
          opt.on("--min-modality F", Float) { |v| options[:filters][:min_modality] = v }
          opt.on("--max-modality F", Float) { |v| options[:filters][:max_modality] = v }
          add_tracing_option(opt, options)
        end.parse!(argv)
        options
      end

      module_function def parse_narrate_options(argv)
        options = { output_dir: nil, generation_model: nil, verification_model: nil }
        OptionParser.new do |opt|
          opt.on("--output-dir DIR") { |v| options[:output_dir] = v }
          opt.on("--generation-model MODEL",
                 "DSPy provider for narrative drafting (Achilles role)") { |v| options[:generation_model] = v }
          opt.on("--verification-model MODEL",
                 "DSPy provider for narrative verification (Genie role); must differ from --generation-model") do |v|
            options[:verification_model] = v
          end
          add_tracing_option(opt, options)
        end.parse!(argv)
        options
      end

      module_function def parse_tui_options(argv)
        options = {}
        OptionParser.new do |opt|
          add_tracing_option(opt, options)
        end.parse!(argv)
        options
      end

      # Entry point for exe/sfl-analyze. Returns the process exit code.
      module_function def run(argv)
        parsed = parse(argv)
        send(:"run_#{parsed[:command]}", parsed[:input], parsed[:options])
        0
      rescue UsageError => e
        warn e.message
        1
      rescue BootstrapError, PassOneError, PassTwoError, NarrativeError => e
        warn "[ERROR] #{e.message}"
        1
      rescue DSPy::LM::AdapterError => e
        # Provider-side failures (rate limits, empty responses) are routine
        # operational errors, not bugs — no backtrace.
        warn "[ERROR] LLM provider error: #{e.message}"
        1
      end

      module_function def run_conversation(input, options)
        # Installed before Bootstrap/Pipeline setup (PyCall/spaCy import
        # alone is a multi-second blocking call) so a Ctrl+C anywhere in
        # this method — not just inside the turn loop — gets the clean
        # "stopping" message instead of an uncaught Interrupt backtrace.
        stop_flag = StopFlag.new
        install_interrupt_trap(stop_flag)

        # One report per file: ConversationAnalyzer#analyze's single-file
        # contract is unchanged — batching a folder of .jsonl exports is
        # purely a CLI-level orchestration concern, not an analyzer one.
        files = File.directory?(input) ? Dir.glob(File.join(input, "**", "*.jsonl")) : [input]
        raise UsageError, "No .jsonl files found in #{input}" if files.empty?

        # Early-return for --live: no spaCy/Pipeline needed in this process
        # (Sidekiq workers boot their own). Wire Gush/Redis instead.
        if options[:live]
          Bootstrap.call(require_jobs: true, require_llm: false, require_observability: false)
          return run_conversation_live(files, options)
        end

        ctx = Bootstrap.call(require_llm: !options[:pass1_only], require_observability: !options[:disable_tracing])
        pipeline = with_interrupts_deferred { Pipeline.new(db: ctx.db, cache_dir: ".sfl-cache") }

        analyzer = Analysis::ConversationAnalyzer.new(
          pipeline:,
          pass_one_only: options[:pass1_only],
          on_progress: progress_printer,
          on_turn_start: progress_starter,
          stop_requested: -> { stop_flag.stopped? }
        )

        files.each do |file|
          break if stop_flag.stopped?

          puts "=== #{File.basename(file)} ===" if files.size > 1
          result = analyzer.analyze(file, topics: options[:topics], resume: options[:resume])
          output_dir = if files.size > 1
            File.join(options[:output_dir],
              File.basename(file, ".*"))
          else
            options[:output_dir]
          end
          finish_report(result, output_dir)
          write_narrative(result, output_dir) if options[:narrative]
          print_interrupt_status(result, file, :conversation) if result.metadata[:interrupted]
        end
      ensure
        Signal.trap("INT", "DEFAULT")
      end

      # `--live`: split-pane Bubbletea dashboard backed by a Gush workflow.
      # Sidekiq workers run the actual spaCy/LLM work in separate OS processes
      # (no PyCall in this process's threads). The TUI only polls Redis.
      # Prerequisite: `bundle exec sidekiq -q gush -r ./lib/sfl/compiler/sidekiq_boot.rb`
      # must be running in another terminal alongside Redis.
      #
      # Multi-file support is deferred — one workflow per invocation for now.
      module_function def run_conversation_live(files, options)
        if files.size > 1
          warn "[WARN] --live currently supports one file per invocation; using #{files.first}"
        end
        path = files.first

        flow = ConversationAnalysisWorkflow.create(path, topics: options[:topics])
        flow.start!

        app = TUI::BatchApp.new(workflow_id: flow.id, files: [path])
        Bubbletea.run(app)

        return unless app.result

        result = Types.load_analysis_result(
          JSON.parse(JSON.generate(app.result), symbolize_names: true)
        )
        finish_report(result, options[:output_dir])
        write_narrative(result, options[:output_dir]) if options[:narrative]
      end

      module_function def run_documentation(input, options)
        # See run_conversation's comment: installed before any setup work
        # so an early Ctrl+C doesn't crash with an uncaught Interrupt.
        stop_flag = StopFlag.new
        install_interrupt_trap(stop_flag)

        # Early-return for --live: no spaCy/Pipeline needed in this process.
        if options[:live]
          Bootstrap.call(require_jobs: true, require_llm: false, require_observability: false)
          return run_documentation_live(input, options)
        end

        ctx = Bootstrap.call(require_llm: !options[:pass1_only], require_observability: !options[:disable_tracing])
        pipeline_args = { db: ctx.db, cache_dir: ".sfl-cache" }
        if options[:store]
          pipeline_args[:embedder] = Embedder.new(
            model: ctx.config.embedding_model,
            ollama_base_url: ctx.config.ollama_base_url
          )
        end
        pipeline = with_interrupts_deferred { Pipeline.new(**pipeline_args) }

        analyzer = Analysis::DocumentationAnalyzer.new(
          pipeline:,
          clause_repo: ClauseRepository.new(ctx.db),
          on_progress: progress_printer,
          on_turn_start: progress_starter,
          stop_requested: -> { stop_flag.stopped? }
        )

        result = analyzer.analyze(input, store: options[:store], topics: options[:topics], resume: options[:resume],
          sprint_id: options[:sprint_id])
        finish_report(result, options[:output_dir])
        write_narrative(result, options[:output_dir]) if options[:narrative]
        print_interrupt_status(result, input, :documentation) if result.metadata[:interrupted]
      ensure
        Signal.trap("INT", "DEFAULT")
      end

      # `--live` for documentation: same architecture as conversation --live.
      # Sidekiq workers run CompileSectionJob per section via
      # DocumentationAnalysisWorkflow; TUI polls via WorkflowPoller.
      # Prerequisite: `bundle exec sidekiq -q gush -r ./lib/sfl/compiler/sidekiq_boot.rb -c 1`
      module_function def run_documentation_live(input, options)
        flow = DocumentationAnalysisWorkflow.create(input, store: options[:store],
          sprint_id: options[:sprint_id])
        flow.start!

        app = TUI::BatchApp.new(workflow_id: flow.id, files: [input])
        Bubbletea.run(app)

        return unless app.result

        result = Types.load_analysis_result(
          JSON.parse(JSON.generate(app.result), symbolize_names: true)
        )
        finish_report(result, options[:output_dir])
        write_narrative(result, options[:output_dir]) if options[:narrative]
      end

      module_function def run_knowledge_base(input, options)
        stop_flag = StopFlag.new
        install_interrupt_trap(stop_flag)

        ctx = Bootstrap.call(require_llm: true, require_observability: !options[:disable_tracing])
        pipeline_args = { db: ctx.db, cache_dir: ".sfl-cache" }
        if options[:store]
          pipeline_args[:embedder] = Embedder.new(
            model: ctx.config.embedding_model,
            ollama_base_url: ctx.config.ollama_base_url
          )
        end
        pipeline = with_interrupts_deferred { Pipeline.new(**pipeline_args) }

        vision_model = options[:vision_model] || ctx.config.vision_model

        analyzer = Analysis::KnowledgeBaseAnalyzer.new(
          pipeline:,
          clause_repo: options[:store] ? ClauseRepository.new(ctx.db) : nil,
          on_progress: kb_progress_printer,
          stop_requested: -> { stop_flag.stopped? }
        )

        result = analyzer.analyze(
          input,
          store:          options[:store],
          resume:         options[:resume],
          analyze_images: options[:images],
          vision_model:
        )

        paths = Formatters::KBReportWriter.write(result, options[:output_dir])

        puts "\nGenerated:"
        paths.each { |format, path| puts "  #{format.to_s.upcase}: #{path}" }

        if options[:annotated]
          annotated_paths = Formatters::KBAnnotatedDocWriter.write(result, options[:output_dir])
          puts "  ANNOTATED: #{annotated_paths.size} file(s) in #{File.join(options[:output_dir], "annotated")}/"
        end

        puts "\nArtifacts: #{result.metadata[:artifact_count]} " \
          "| Stale: #{result.staleness_flags.size} " \
          "| Files: #{result.metadata[:file_count]}"
      ensure
        Signal.trap("INT", "DEFAULT")
      end

      module_function def run_context(query, options)
        ctx = Bootstrap.call(require_llm: true, require_observability: !options[:disable_tracing])
        db = ctx.db
        embedder = Embedder.new(
          model: ctx.config.embedding_model,
          ollama_base_url: ctx.config.ollama_base_url
        )
        synthesizer = ContextSynthesizer.new(
          retriever: HybridRetriever.new(db:, embedder:),
          clause_repo: ClauseRepository.new(db)
        )

        result = synthesizer.synthesize(query, filters: options[:filters], limit: options[:limit])

        if result.retrieved_count.zero?
          puts "No stored clauses matched. Ingest documents first:"
          puts "  sfl-analyze documentation <path> --store"
          return
        end

        if result.answer.nil?
          puts "Synthesis failed — showing retrieved evidence only:"
        else
          puts "## Answer (confidence: #{result.confidence})\n\n#{result.answer}\n\n"
          puts "## Evidence (#{result.retrieved_count} retrieved, #{result.cited_clause_ids.size} cited)"
        end
        print_evidence(result)

        return unless options[:output_dir]

        require "fileutils"
        require "json"
        FileUtils.mkdir_p(options[:output_dir])
        path = File.join(options[:output_dir], "context_synthesis.json")
        File.write(path, JSON.pretty_generate(result.to_h))
        puts "\nWritten: #{path}"
      end

      module_function def run_narrate(input, options)
        raise UsageError, "No such file: #{input}" unless File.file?(input)

        gen_model = options[:generation_model]
        ver_model = options[:verification_model]

        if gen_model.nil? != ver_model.nil?
          raise UsageError,
            "--generation-model and --verification-model must both be set or both omitted"
        end

        parsed = begin
          JSON.parse(File.read(input))
        rescue JSON::ParserError => e
          raise UsageError, "#{input} is not valid JSON: #{e.message}"
        end

        Bootstrap.call(require_db: false, require_observability: !options[:disable_tracing])
        digest = Analysis::NarrativeGenerator::Digest.from_json(parsed)

        narrator = gen_model ? Analysis::MultiModelNarrator.new(
          generation_model:  gen_model,
          verification_model: ver_model
        ) : nil

        report = Analysis::NarrativeGenerator.new(narrator:).generate(digest)

        source_clauses    = Array(parsed["turns"]).flat_map { |t| Array(t["clauses"]) }
        narrative_text    = report_sections_text(report)
        citation_check    = Analysis::CitationGroundingChecker.new.check(narrative_text, source_clauses)

        dir = options[:output_dir] || File.dirname(input)
        require "fileutils"
        FileUtils.mkdir_p(dir)
        path = File.join(dir, "narrative_report.md")
        Formatters::NarrativeFormatter.new(report, citation_check:).write_to(path)
        puts "Generated:\n  NARRATIVE: #{path}"
      end

      # Wizards (conversation/documentation/context/narrate) call the
      # existing CLI.run_* methods directly, each doing its own
      # Bootstrap/Pipeline wiring exactly like the non-interactive
      # subcommands — only the chat session needs separate wiring here,
      # deferred to a builder lambda so it only runs if "Chat with
      # results" is actually chosen.
      module_function def run_tui(_input, options)
        TUI::Menu.new(chat_session_builder: lambda {
          ctx = Bootstrap.call(require_llm: true, require_observability: !options[:disable_tracing])
          db = ctx.db
          embedder = Embedder.new(model: ctx.config.embedding_model, ollama_base_url: ctx.config.ollama_base_url)
          synthesizer = ContextSynthesizer.new(
            retriever: HybridRetriever.new(db:, embedder:),
            clause_repo: ClauseRepository.new(db)
          )
          Chat::Session.new(synthesizer:)
        }).run
      end

      module_function def print_evidence(result)
        result.clauses.each_with_index do |clause, idx|
          marker = result.cited_clause_ids.include?(clause[:clause_id]) ? "*" : " "
          puts "#{marker} [#{idx + 1}] #{clause[:text]} (#{clause[:document_id]})"
        end
      end

      # Fires immediately, before a turn/section's compilation starts —
      # a single turn's Pass 1 + Pass 2 can take 20-60s, so without this
      # the terminal sits static with no signal the run hasn't hung.
      # No trailing newline: progress_printer completes the same line.
      module_function def progress_starter
        lambda do |event|
          print "  #{event[:turn_id]}/#{event[:total]} (#{event[:speaker]})... "
          $stdout.flush
        end
      end

      module_function def progress_printer
        lambda do |event|
          label = event[:defaulted].zero? ? "OK" : "#{event[:defaulted]}/#{event[:clause_count]} DEFAULTED"
          puts "#{event[:elapsed]}s [#{label}]"
        end
      end

      module_function def kb_progress_printer
        lambda do |event|
          puts "  #{event[:artifact_id]}/#{event[:total]} #{event[:title]}"
        end
      end

      # "Clean quit": the first Ctrl+C sets the flag so the analyzer
      # finishes the in-flight turn/section, then stops on its own rather
      # than this handler tearing anything down directly. A second Ctrl+C
      # (flag already set) restores the default disposition and re-sends
      # SIGINT to this process, so a user who wants to hard-kill still can.
      module_function def install_interrupt_trap(stop_flag)
        Signal.trap("INT") do
          if stop_flag.stopped?
            Signal.trap("INT", "DEFAULT")
            Process.kill("INT", Process.pid)
          else
            stop_flag.stop!
            warn "\n[INFO] Stopping after the current turn finishes... (Ctrl+C again to force quit)"
          end
        end
      end

      # PyCall's spaCy import (triggered the first time Pipeline.new builds
      # a PassOneEngine) can raise Interrupt from inside CPython's own
      # signal-check machinery on SIGINT — that bypasses our Ruby-level
      # trap entirely (confirmed: install_interrupt_trap's handler still
      # fires, but the in-flight C call unwinds via a raw Interrupt anyway,
      # crashing past every rescue in CLI.run). Briefly ignoring INT for
      # just this one call turns a same-instant Ctrl+C into a no-op
      # instead of a crash; the real trap resumes immediately after.
      module_function def with_interrupts_deferred
        previous = Signal.trap("INT", "IGNORE")
        yield
      ensure
        Signal.trap("INT", previous)
      end

      module_function def print_interrupt_status(result, input, command)
        meta = result.metadata
        puts "\n⏸  Stopped after #{meta[:turn_count]}/#{meta[:total]} in #{File.basename(input.to_s)}."
        puts "   Resume with: bundle exec sfl-analyze #{command} #{input} --resume " \
          "(cached turns are skipped; only the rest gets re-analyzed)"
      end

      # Best-effort: the analysis trio is already on disk; a narrative
      # failure downgrades to a warning rather than failing the run.
      module_function def write_narrative(result, output_dir)
        digest         = Analysis::NarrativeGenerator::Digest.from_result(result)
        report         = Analysis::NarrativeGenerator.new.generate(digest)
        source_clauses = result.turns.flat_map(&:clauses)
        narrative_text = report_sections_text(report)
        citation_check = Analysis::CitationGroundingChecker.new.check(narrative_text, source_clauses)
        path = File.join(output_dir, "narrative_report.md")
        Formatters::NarrativeFormatter.new(report, citation_check:).write_to(path)
        puts "  NARRATIVE: #{path}"
      rescue NarrativeError => e
        warn "[WARN] narrative generation failed: #{e.message}"
      end

      module_function def report_sections_text(report)
        %i[overview cast_and_roles interpersonal_dynamics conversational_arc data_quality takeaways]
          .map { |k| report.public_send(k) }.join("\n\n")
      end

      module_function def finish_report(result, output_dir)
        paths = Formatters::ReportWriter.write(result, output_dir)

        clauses = result.turns.flat_map(&:clauses)
        defaulted = clauses.count { |c| c.interpersonal.annotation_source != "llm" }
        if defaulted.positive?
          pct = (defaulted * 100.0 / clauses.size).round(1)
          warn "[WARN] #{defaulted}/#{clauses.size} clauses (#{pct}%) carry fallback/stub values — see the Data Quality section."
        end

        puts "\nGenerated:"
        paths.each { |format, path| puts "  #{format.to_s.upcase}: #{path}" }
      end
    end
  end
end
