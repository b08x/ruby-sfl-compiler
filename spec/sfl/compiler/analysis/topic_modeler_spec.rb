# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::Analysis::TopicModeler do
  let(:turns) do
    [
      create_turn(1, "alice", "The sandbox security model uses WebAssembly isolation for code execution. Deno provides runtime isolation for untrusted code. Pyodide enables Python execution within the WebAssembly sandbox."),
      create_turn(2, "bob", "Telemetry pipeline integrates with Langfuse and Phoenix for observability. OTLP traces are ingested and stored for performance monitoring. The telemetry backend uses cursor-based pagination."),
      create_turn(3, "alice", "Security architecture requires strict filesystem sandboxing. WebAssembly memory limits prevent denial of service attacks. The security model isolates code execution from the host system."),
      create_turn(4, "bob", "Trace visualization uses React with virtualized rendering for large payloads. The frontend displays real-time telemetry from the execution engine. Performance monitoring tracks latency and throughput."),
      create_turn(5, "alice", "Deno and Pyodide provide runtime isolation for untrusted code execution. The sandbox uses WebAssembly to execute Python code safely. Security controls limit resource consumption."),
      create_turn(6, "bob", "The observability stack includes Langfuse for tracing and Phoenix for monitoring. Telemetry data flows through an OTLP-compliant pipeline. Performance metrics are collected and visualized."),
      create_turn(7, "alice", "WebAssembly memory limits prevent denial of service attacks. The sandbox enforces strict resource limits on code execution. Security measures include filesystem isolation and network restrictions."),
      create_turn(8, "bob", "The telemetry backend stores traces in a database with efficient indexing. Performance monitoring dashboards display real-time metrics. Observability tools help debug and optimize the system.")
    ]
  end

  def create_turn(id, speaker, text)
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: id,
      speaker: speaker,
      timestamp: Time.now,
      message_text: text,
      clauses: [],
      avg_tenor: 0.5,
      avg_modality: 0.5,
      dominant_mood: "declarative",
      process_types: { "material" => 1 },
      participants: [],
      tenor_shift: nil
    )
  end

  describe "#fit" do
    it "trains an LDA model with specified k" do
      modeler = described_class.new(k: 2, min_cf: 1, iterations: 10)
      expect { modeler.fit(turns) }.not_to raise_error
      expect(modeler.topic_labels).to be_a(Hash)
      expect(modeler.topic_labels.size).to eq(2)
    end

    it "trains an HDP model when k is nil" do
      modeler = described_class.new(k: nil, min_cf: 1, iterations: 10)
      expect { modeler.fit(turns) }.not_to raise_error
      expect(modeler.topic_labels).to be_a(Hash)
      expect(modeler.topic_labels.size).to be >= 1
    end

    it "assigns topic distributions to turns" do
      modeler = described_class.new(k: 2, min_cf: 1, iterations: 10)
      modeler.fit(turns)

      distributions = modeler.turn_distributions
      expect(distributions.size).to eq(turns.size)
      distributions.each do |dist|
        expect(dist).to be_a(Hash)
      end

      # Verify internal turns have topic data
      modeler.instance_variable_get(:@turns).each do |turn|
        expect(turn.topic_distribution).to be_a(Hash)
        expect(turn.dominant_topic).to be_a(Integer)
      end
    end
  end

  describe "#topic_labels" do
    it "returns top words per topic" do
      modeler = described_class.new(k: 2, min_cf: 1, iterations: 10)
      modeler.fit(turns)

      modeler.topic_labels.each do |_topic_id, words|
        expect(words).to be_an(Array)
        expect(words).not_to be_empty
        words.each { |w| expect(w).to be_a(String) }
      end
    end
  end

  describe "#detect_topic_shifts" do
    it "detects topic changes between consecutive turns" do
      modeler = described_class.new(k: 2, min_cf: 1, iterations: 10)
      modeler.fit(turns)

      shifts = modeler.detect_topic_shifts(threshold: 0.0)
      expect(shifts).to be_an(Array)
      shifts.each do |shift|
        expect(shift).to include(:turn_id, :type, :from_topic, :to_topic, :magnitude, :description)
        expect(shift[:type]).to eq("topic_shift")
      end
    end

    it "returns empty array when no significant shifts" do
      modeler = described_class.new(k: 2, min_cf: 1, iterations: 10)
      modeler.fit(turns)

      # Very high threshold should filter out all shifts
      shifts = modeler.detect_topic_shifts(threshold: 2.0)
      expect(shifts).to be_empty
    end
  end

  describe "#turn_distributions" do
    it "returns distributions for all turns" do
      modeler = described_class.new(k: 2, min_cf: 1, iterations: 10)
      modeler.fit(turns)

      distributions = modeler.turn_distributions
      expect(distributions.size).to eq(turns.size)
      distributions.each do |dist|
        expect(dist).to be_a(Hash)
      end
    end
  end

  describe "#save and #load_model" do
    it "persists and reloads the model" do
      modeler = described_class.new(k: 2, min_cf: 1, iterations: 10)
      modeler.fit(turns)

      path = "/tmp/test_topic_model.bin"
      modeler.save(path)

      new_modeler = described_class.new
      new_modeler.load_model(path)

      expect(new_modeler.topic_labels.keys).to eq(modeler.topic_labels.keys)

      File.delete(path) if File.exist?(path)
    end
  end

  describe "tokenizer" do
    it "preprocesses text for topic modeling" do
      modeler = described_class.new(k: 2, min_cf: 1, iterations: 10)

      # Test the private tokenize method via fit
      modeler.fit(turns)

      # Verify tokens were generated (topics have words)
      expect(modeler.topic_labels.values.flatten).not_to be_empty
    end
  end
end
