# frozen_string_literal: true

require "optparse"

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
          conversation <input.jsonl>   Analyze a JSONL conversation
          documentation <path>         Analyze a markdown file or directory
          context "<query>"            Query stored clauses, synthesize an answer

        Common options:
          --output-dir DIR             Where to write reports [./sfl_output]

        conversation/documentation:
          --pass1-only                 Skip LLM annotation (placeholder values)

        documentation:
          --store                      Persist clauses + embeddings for `context`

        context:
          --mood MOOD                  declarative|interrogative|imperative|exclamative
          --min-tenor F  --max-tenor F
          --min-modality F  --max-modality F
          --limit N                    Max clauses to retrieve [10]
      TEXT

      module_function

      # @param argv [Array<String>]
      # @return [Hash] {command:, input:, options:}
      def parse(argv)
        argv = argv.dup
        command = argv.shift&.to_sym
        unless %i[conversation documentation context].include?(command)
          raise UsageError, "Unknown subcommand: #{command}\n\n#{USAGE}"
        end

        input = argv.shift
        raise UsageError, "#{command} requires an input argument\n\n#{USAGE}" if input.nil? || input.start_with?("--")

        options = send(:"parse_#{command}_options", argv)
        { command: command, input: input, options: options }
      end

      def parse_conversation_options(argv)
        options = { output_dir: "./sfl_output", pass1_only: false }
        OptionParser.new do |opt|
          opt.on("--output-dir DIR") { |v| options[:output_dir] = v }
          opt.on("--pass1-only") { options[:pass1_only] = true }
        end.parse!(argv)
        options
      end

      def parse_documentation_options(argv)
        options = { output_dir: "./sfl_output", pass1_only: false, store: false }
        OptionParser.new do |opt|
          opt.on("--output-dir DIR") { |v| options[:output_dir] = v }
          opt.on("--pass1-only") { options[:pass1_only] = true }
          opt.on("--store") { options[:store] = true }
        end.parse!(argv)
        options
      end

      def parse_context_options(argv)
        options = { output_dir: nil, limit: 10, filters: {} }
        OptionParser.new do |opt|
          opt.on("--output-dir DIR") { |v| options[:output_dir] = v }
          opt.on("--limit N", Integer) { |v| options[:limit] = v }
          opt.on("--mood MOOD") { |v| options[:filters][:mood] = v }
          opt.on("--min-tenor F", Float) { |v| options[:filters][:min_tenor] = v }
          opt.on("--max-tenor F", Float) { |v| options[:filters][:max_tenor] = v }
          opt.on("--min-modality F", Float) { |v| options[:filters][:min_modality] = v }
          opt.on("--max-modality F", Float) { |v| options[:filters][:max_modality] = v }
        end.parse!(argv)
        options
      end

      # Entry point for exe/sfl-analyze. Returns the process exit code.
      def run(argv)
        parsed = parse(argv)
        send(:"run_#{parsed[:command]}", parsed[:input], parsed[:options])
        0
      rescue UsageError => e
        warn e.message
        1
      rescue BootstrapError, PassOneError, PassTwoError => e
        warn "[ERROR] #{e.message}"
        1
      rescue DSPy::LM::AdapterError => e
        # Provider-side failures (rate limits, empty responses) are routine
        # operational errors, not bugs — no backtrace.
        warn "[ERROR] LLM provider error: #{e.message}"
        1
      end

      def run_conversation(input, options)
        ctx = Bootstrap.call(require_llm: !options[:pass1_only])
        pipeline = Pipeline.new(db: ctx.db)
        analyzer = Analysis::ConversationAnalyzer.new(
          pipeline: pipeline,
          pass_one_only: options[:pass1_only],
          on_progress: progress_printer
        )

        result = analyzer.analyze(input)
        finish_report(result, options[:output_dir])
      end

      def run_documentation(input, options)
        ctx = Bootstrap.call(require_llm: !options[:pass1_only])
        pipeline_args = { db: ctx.db }
        pipeline_args[:embedder] = Embedder.new if options[:store]
        pipeline = Pipeline.new(**pipeline_args)
        analyzer = Analysis::DocumentationAnalyzer.new(
          pipeline: pipeline,
          clause_repo: ClauseRepository.new(ctx.db),
          on_progress: progress_printer
        )

        result = analyzer.analyze(input, store: options[:store])
        finish_report(result, options[:output_dir])
      end

      def run_context(query, options)
        ctx = Bootstrap.call(require_llm: true)
        db = ctx.db
        synthesizer = ContextSynthesizer.new(
          retriever: HybridRetriever.new(db: db, embedder: Embedder.new),
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
          print_evidence(result)
        else
          puts "## Answer (confidence: #{result.confidence})\n\n#{result.answer}\n\n"
          puts "## Evidence (#{result.retrieved_count} retrieved, #{result.cited_clause_ids.size} cited)"
          print_evidence(result)
        end

        if options[:output_dir]
          require "fileutils"
          require "json"
          FileUtils.mkdir_p(options[:output_dir])
          path = File.join(options[:output_dir], "context_synthesis.json")
          File.write(path, JSON.pretty_generate(result.to_h))
          puts "\nWritten: #{path}"
        end
      end

      def print_evidence(result)
        result.clauses.each_with_index do |clause, idx|
          marker = result.cited_clause_ids.include?(clause[:clause_id]) ? "*" : " "
          puts "#{marker} [#{idx + 1}] #{clause[:text]} (#{clause[:document_id]})"
        end
      end

      def progress_printer
        lambda do |event|
          label = event[:defaulted].zero? ? "OK" : "#{event[:defaulted]}/#{event[:clause_count]} DEFAULTED"
          puts "  #{event[:turn_id]}/#{event[:total]} (#{event[:speaker]}) #{event[:elapsed]}s [#{label}]"
        end
      end

      def finish_report(result, output_dir)
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
