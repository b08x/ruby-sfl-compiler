---
id: "comment_01KVY8ZS954FGR8H2AQX1375MM"
cardId: "card-sprintrolejob-generic-gush-job-for-achilles-tort-1lhl2bf"
createdAt: "2026-06-25T02:15:49.285Z"
updatedAt: "2026-06-25T02:15:49.285Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Implemented in `lib/sfl/compiler/jobs/sprint_role_job.rb` (commit 66a58d0). One generic `Gush::Job`: `Object.const_get(params[:signature_class])` builds the DSPy module, `predictor.configure { |c| c.lm = DSPy::LM.new(params[:lm], api_key: Bootstrap.api_key_for(...)) }` for per-instance LM, `predictor.call(**input)`, `output(result.to_h)`.

One real finding worth recording: verified via gem source (`dspy-1.0.1/lib/dspy/prediction.rb`) that `DSPy::Prediction#to_h` exists and deep-serializes (`DSPy::Utils::Serialization.deep_serialize(@_struct.serialize)`, stripping `_prediction_marker`) — this is what makes `output(result.to_h)` JSON-safe without hand-picking fields like `SFLAnnotator` does. Docs didn't show this method explicitly so I confirmed against source per the project's "verify gem APIs" standard.

4 new specs (LM per-instance, JSON-round-trippable output, symbolized input keys, 3 distinct LM providers across roles). Full suite: 331 examples, 0 failures. 2 remaining rubocop Metrics offenses match the existing precedent in `CompileTurnJob`/its spec — not fixed, same as that file. `CrabConstraintJob` and `SprintWorkflow` are next.