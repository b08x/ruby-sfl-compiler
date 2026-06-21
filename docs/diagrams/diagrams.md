# Codebase Diagrams

_Auto-extracted from graphify callflow output._


## Architecture

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"fontSize": "15.0px", "fontFamily": "Segoe UI, system-ui, sans-serif", "primaryColor": "#1e293b", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#38bdf8", "secondaryColor": "#0f172a", "tertiaryColor": "#334155", "lineColor": "#64748b", "textColor": "#e2e8f0"}, "flowchart": {"htmlLabels": true, "curve": "basis", "nodeSpacing": 48, "rankSpacing": 64, "padding": 14, "diagramPadding": 10, "useMaxWidth": true}}}%%
flowchart LR
    EXTRACT_PIPELINE_5F350230("Extraction Pipeline<br/><small>79 nodes</small>")
    class EXTRACT_PIPELINE_5F350230 module;
    BUILD_GRAPH_321CBB04("Graph Build<br/><small>23 nodes</small>")
    class BUILD_GRAPH_321CBB04 module;
    ANALYSIS_CLUSTERING_C79796DA("Analysis & Clustering<br/><small>35 nodes</small>")
    class ANALYSIS_CLUSTERING_C79796DA module;
    OUTPUTS_DOCS_ED82387C("Outputs & Docs<br/><small>62 nodes</small>")
    class OUTPUTS_DOCS_ED82387C module;
    CLI_SKILLS_9964CBB8("CLI & Skill Installers<br/><small>2 nodes</small>")
    class CLI_SKILLS_9964CBB8 module;
    INGEST_CACHE_UPDATE_FF457338("Ingestion & Updates<br/><small>96 nodes</small>")
    class INGEST_CACHE_UPDATE_FF457338 module;
    SERVE_API_35EC8E86("Serving API<br/><small>16 nodes</small>")
    class SERVE_API_35EC8E86 module;
    CORRELATION_ANALYSIS_AA399C69("Correlation Analysis<br/><small>28 nodes</small>")
    class CORRELATION_ANALYSIS_AA399C69 module;
    CONVERSATION_ANALYSIS_17C283AE("Conversation Analysis<br/><small>27 nodes</small>")
    class CONVERSATION_ANALYSIS_17C283AE module;
    HYBRID_RETRIEVER_975D0030("Hybrid Retriever<br/><small>18 nodes</small>")
    class HYBRID_RETRIEVER_975D0030 module;
    DATABASE_MIGRATIONS_37A83AD7("Database & Migrations<br/><small>8 nodes</small>")
    class DATABASE_MIGRATIONS_37A83AD7 module;
    MARKDOWN_LOADER_7351760A("Markdown Loader<br/><small>6 nodes</small>")
    class MARKDOWN_LOADER_7351760A module;
    SPEAKER_PROFILER_3A42CFA9("Speaker Profiler<br/><small>4 nodes</small>")
    class SPEAKER_PROFILER_3A42CFA9 module;
    COHESION_ANALYSIS_FD1FF4CE("Cohesion Analysis<br/><small>3 nodes</small>")
    class COHESION_ANALYSIS_FD1FF4CE module;
    OTHER_D0941E68("Other<br/><small>9 nodes</small>")
    class OTHER_D0941E68 module;
    OUTPUTS_DOCS_ED82387C -->|method x2| INGEST_CACHE_UPDATE_FF457338
    CORRELATION_ANALYSIS_AA399C69 -->|contains x2| EXTRACT_PIPELINE_5F350230
    BUILD_GRAPH_321CBB04 -->|method| OUTPUTS_DOCS_ED82387C
    CONVERSATION_ANALYSIS_17C283AE -->|method| INGEST_CACHE_UPDATE_FF457338
    OUTPUTS_DOCS_ED82387C -->|method| EXTRACT_PIPELINE_5F350230
    EXTRACT_PIPELINE_5F350230 -->|contains| INGEST_CACHE_UPDATE_FF457338
    EXTRACT_PIPELINE_5F350230 -->|contains| SERVE_API_35EC8E86
    EXTRACT_PIPELINE_5F350230 -->|calls| CORRELATION_ANALYSIS_AA399C69
    INGEST_CACHE_UPDATE_FF457338 -->|method| ANALYSIS_CLUSTERING_C79796DA
    ANALYSIS_CLUSTERING_C79796DA -->|calls| INGEST_CACHE_UPDATE_FF457338
    classDef entry fill:#422006,stroke:#fbbf24,color:#fde68a,stroke-width:1px;
    classDef api fill:#450a0a,stroke:#f87171,color:#fee2e2,stroke-width:1px;
    classDef async fill:#2e1065,stroke:#a78bfa,color:#ede9fe,stroke-width:1px;
    classDef klass fill:#064e3b,stroke:#34d399,color:#d1fae5,stroke-width:1px;
    classDef ui fill:#831843,stroke:#f472b6,color:#fce7f3,stroke-width:1px;
    classDef module fill:#172554,stroke:#60a5fa,color:#dbeafe,stroke-width:1px;
    classDef test fill:#3f3f46,stroke:#a1a1aa,color:#f4f4f5,stroke-width:1px;
    classDef concept fill:#292524,stroke:#a8a29e,color:#fafaf9,stroke-dasharray:4 3;
    classDef function fill:#0f172a,stroke:#38bdf8,color:#e0f2fe,stroke-width:1px;
```


## Callflow 1

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"fontSize": "15.0px", "fontFamily": "Segoe UI, system-ui, sans-serif", "primaryColor": "#1e293b", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#38bdf8", "secondaryColor": "#0f172a", "tertiaryColor": "#334155", "lineColor": "#64748b", "textColor": "#e2e8f0"}, "flowchart": {"htmlLabels": true, "curve": "basis", "nodeSpacing": 48, "rankSpacing": 64, "padding": 14, "diagramPadding": 10, "useMaxWidth": true}}}%%
flowchart LR
    %% Section: Extraction Pipeline (79 nodes, 104 edges)
    subgraph extract_pipeline_compiler_llm_tools_theme_rheme_6a5fca88["compiler/llm_tools/theme_rheme_extractor.rb"]
        llm_tools_theme_rheme_extractor_themerhemeextrac_e030c4d3("ThemeRhemeExtractor<br/><small>compiler/llm_tools/theme_rheme_extractor.rb</small>")
        llm_tools_theme_rheme_extractor_themerhemeextrac_f230448e("build_sfl_prompt()<br/><small>compiler/llm_tools/theme_rheme_extractor.rb</small>")
        llm_tools_theme_rheme_extractor_themerhemeextrac_94e13851("call_llm()<br/><small>compiler/llm_tools/theme_rheme_extractor.rb</small>")
        llm_tools_theme_rheme_extractor_themerhemeextrac_6c9be6f8("execute()<br/><small>compiler/llm_tools/theme_rheme_extractor.rb</small>")
        llm_tools_theme_rheme_extractor_themerhemeextrac_6ffa85dc("parse_theme_rheme_response()<br/><small>compiler/llm_tools/theme_rheme_extractor.rb</small>")
    end
    subgraph extract_pipeline_compiler_pass_one_ideational_ex_2ca7f799["compiler/pass_one/ideational_extractor.rb"]
        pass_one_ideational_extractor_ideationalextracto_41fbfcca("IdeationalExtractor<br/><small>compiler/pass_one/ideational_extractor.rb</small>")
        pass_one_ideational_extractor_ideationalextracto_c9d244ba("extract()<br/><small>compiler/pass_one/ideational_extractor.rb</small>")
        pass_one_ideational_extractor_ideationalextracto_fba12c3a("behavioral_verb?()<br/><small>compiler/pass_one/ideational_extractor.rb</small>")
        pass_one_ideational_extractor_ideationalextracto_55363a1f("build_transitivity_hash()<br/><small>compiler/pass_one/ideational_extractor.rb</small>")
        pass_one_ideational_extractor_ideationalextracto_601cafa7("classify_process()<br/><small>compiler/pass_one/ideational_extractor.rb</small>")
    end
    subgraph extract_pipeline_sfl_compiler_bootstrap_rb_e74b4ee5["sfl/compiler/bootstrap.rb"]
        compiler_bootstrap_call_137fcbed("call()<br/><small>sfl/compiler/bootstrap.rb</small>")
        compiler_bootstrap_configure_llm_d28028e1("configure_llm()<br/><small>sfl/compiler/bootstrap.rb</small>")
        compiler_bootstrap_connect_db_01db0cda("connect_db()<br/><small>sfl/compiler/bootstrap.rb</small>")
        compiler_bootstrap_api_key_for_9cf7eece("api_key_for()<br/><small>sfl/compiler/bootstrap.rb</small>")
        compiler_bootstrap_apply_request_timeout_6cee0ce4("apply_request_timeout()<br/><small>sfl/compiler/bootstrap.rb</small>")
    end
    pass_two_pass_two_engine_sflannotator_728897c4("SFLAnnotator<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    storage_clause_repository_clauserepository_362861bc("ClauseRepository<br/><small>compiler/storage/clause_repository.rb</small>")
    storage_database_migrator_ab243aa2("Migrator<br/><small>compiler/storage/database.rb</small>")
    compiler_bootstrap_call_137fcbed -->|calls| compiler_bootstrap_configure_llm_d28028e1
    compiler_bootstrap_call_137fcbed -->|calls| compiler_bootstrap_connect_db_01db0cda
    compiler_bootstrap_configure_llm_d28028e1 -->|calls| compiler_bootstrap_api_key_for_9cf7eece
    compiler_bootstrap_configure_llm_d28028e1 -->|calls| compiler_bootstrap_apply_request_timeout_6cee0ce4
    llm_tools_theme_rheme_extractor_themerhemeextrac_e030c4d3 -->|method| llm_tools_theme_rheme_extractor_themerhemeextrac_f230448e
    llm_tools_theme_rheme_extractor_themerhemeextrac_e030c4d3 -->|method| llm_tools_theme_rheme_extractor_themerhemeextrac_94e13851
    llm_tools_theme_rheme_extractor_themerhemeextrac_e030c4d3 -->|method| llm_tools_theme_rheme_extractor_themerhemeextrac_6c9be6f8
    llm_tools_theme_rheme_extractor_themerhemeextrac_e030c4d3 -->|method| llm_tools_theme_rheme_extractor_themerhemeextrac_6ffa85dc
    llm_tools_theme_rheme_extractor_themerhemeextrac_6c9be6f8 -->|calls| llm_tools_theme_rheme_extractor_themerhemeextrac_f230448e
    llm_tools_theme_rheme_extractor_themerhemeextrac_6c9be6f8 -->|calls| llm_tools_theme_rheme_extractor_themerhemeextrac_94e13851
    llm_tools_theme_rheme_extractor_themerhemeextrac_6c9be6f8 -->|calls| llm_tools_theme_rheme_extractor_themerhemeextrac_6ffa85dc
    pass_one_ideational_extractor_ideationalextracto_41fbfcca -->|method| pass_one_ideational_extractor_ideationalextracto_fba12c3a
    pass_one_ideational_extractor_ideationalextracto_41fbfcca -->|method| pass_one_ideational_extractor_ideationalextracto_55363a1f
    pass_one_ideational_extractor_ideationalextracto_41fbfcca -->|method| pass_one_ideational_extractor_ideationalextracto_601cafa7
    pass_one_ideational_extractor_ideationalextracto_41fbfcca -->|method| pass_one_ideational_extractor_ideationalextracto_c9d244ba
    pass_one_ideational_extractor_ideationalextracto_c9d244ba -->|calls| pass_one_ideational_extractor_ideationalextracto_55363a1f
    pass_one_ideational_extractor_ideationalextracto_c9d244ba -->|calls| pass_one_ideational_extractor_ideationalextracto_601cafa7
    pass_one_ideational_extractor_ideationalextracto_601cafa7 -->|calls| pass_one_ideational_extractor_ideationalextracto_fba12c3a
    %% Omitted for readability: 61 nodes, 0 edges
    class llm_tools_theme_rheme_extractor_themerhemeextrac_e030c4d3 klass;
    class llm_tools_theme_rheme_extractor_themerhemeextrac_f230448e function;
    class llm_tools_theme_rheme_extractor_themerhemeextrac_94e13851 function;
    class llm_tools_theme_rheme_extractor_themerhemeextrac_6c9be6f8 function;
    class llm_tools_theme_rheme_extractor_themerhemeextrac_6ffa85dc function;
    class pass_one_ideational_extractor_ideationalextracto_41fbfcca klass;
    class pass_one_ideational_extractor_ideationalextracto_c9d244ba function;
    class pass_one_ideational_extractor_ideationalextracto_fba12c3a function;
    class pass_one_ideational_extractor_ideationalextracto_55363a1f function;
    class pass_one_ideational_extractor_ideationalextracto_601cafa7 function;
    class compiler_bootstrap_call_137fcbed function;
    class compiler_bootstrap_configure_llm_d28028e1 function;
    class compiler_bootstrap_connect_db_01db0cda function;
    class compiler_bootstrap_api_key_for_9cf7eece api;
    class compiler_bootstrap_apply_request_timeout_6cee0ce4 function;
    class pass_two_pass_two_engine_sflannotator_728897c4 klass;
    class storage_clause_repository_clauserepository_362861bc klass;
    class storage_database_migrator_ab243aa2 klass;
    classDef entry fill:#422006,stroke:#fbbf24,color:#fde68a,stroke-width:1px;
    classDef api fill:#450a0a,stroke:#f87171,color:#fee2e2,stroke-width:1px;
    classDef async fill:#2e1065,stroke:#a78bfa,color:#ede9fe,stroke-width:1px;
    classDef klass fill:#064e3b,stroke:#34d399,color:#d1fae5,stroke-width:1px;
    classDef ui fill:#831843,stroke:#f472b6,color:#fce7f3,stroke-width:1px;
    classDef module fill:#172554,stroke:#60a5fa,color:#dbeafe,stroke-width:1px;
    classDef test fill:#3f3f46,stroke:#a1a1aa,color:#f4f4f5,stroke-width:1px;
    classDef concept fill:#292524,stroke:#a8a29e,color:#fafaf9,stroke-dasharray:4 3;
    classDef function fill:#0f172a,stroke:#38bdf8,color:#e0f2fe,stroke-width:1px;
```


## Callflow 2

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"fontSize": "15.0px", "fontFamily": "Segoe UI, system-ui, sans-serif", "primaryColor": "#1e293b", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#38bdf8", "secondaryColor": "#0f172a", "tertiaryColor": "#334155", "lineColor": "#64748b", "textColor": "#e2e8f0"}, "flowchart": {"htmlLabels": true, "curve": "basis", "nodeSpacing": 48, "rankSpacing": 64, "padding": 14, "diagramPadding": 10, "useMaxWidth": true}}}%%
flowchart LR
    %% Section: Graph Build (23 nodes, 34 edges)
    subgraph build_graph_compiler_analysis_conversation_analy_517b4a8a["compiler/analysis/conversation_analyzer.rb"]
        analysis_conversation_analyzer_conversationanaly_22cc21a4("ConversationAnalyzer<br/><small>compiler/analysis/conversation_analyzer.rb</small>")
        analysis_conversation_analyzer_conversationanaly_11a87abc("analyze()<br/><small>compiler/analysis/conversation_analyzer.rb</small>")
        analysis_conversation_analyzer_conversationanaly_51faa16e("compile_turn()<br/><small>compiler/analysis/conversation_analyzer.rb</small>")
        analysis_conversation_analyzer_conversationanaly_8c9e44a2("compile_clauses()<br/><small>compiler/analysis/conversation_analyzer.rb</small>")
        analysis_conversation_analyzer_conversationanaly_7da27936("detect_example_passages()<br/><small>compiler/analysis/conversation_analyzer.rb</small>")
        analysis_conversation_analyzer_conversationanaly_cc598ed8("detect_key_moments()<br/><small>compiler/analysis/conversation_analyzer.rb</small>")
        analysis_conversation_analyzer_conversationanaly_08944a90("field_evolution()<br/><small>compiler/analysis/conversation_analyzer.rb</small>")
        analysis_conversation_analyzer_conversationanaly_b28b8629("generate_insights()<br/><small>compiler/analysis/conversation_analyzer.rb</small>")
        analysis_conversation_analyzer_conversationanaly_1f8808fa("load_jsonl()<br/><small>compiler/analysis/conversation_analyzer.rb</small>")
        analysis_conversation_analyzer_conversationanaly_2ca6ac64("mean()<br/><small>compiler/analysis/conversation_analyzer.rb</small>")
        analysis_conversation_analyzer_conversationanaly_8c73969d("parse_timestamp()<br/><small>compiler/analysis/conversation_analyzer.rb</small>")
        analysis_conversation_analyzer_conversationanaly_eafa79dc("report_progress()<br/><small>compiler/analysis/conversation_analyzer.rb</small>")
        analysis_conversation_analyzer_conversationanaly_049a3b17("tenor_timeline()<br/><small>compiler/analysis/conversation_analyzer.rb</small>")
        analysis_conversation_analyzer_conversationanaly_cce05129("topic_evolution()<br/><small>compiler/analysis/conversation_analyzer.rb</small>")
    end
    subgraph build_graph_compiler_formatters_json_formatter_r_91d3a391["compiler/formatters/json_formatter.rb"]
        formatters_json_formatter_jsonformatter_a9d3f8de("JSONFormatter<br/><small>compiler/formatters/json_formatter.rb</small>")
        formatters_json_formatter_jsonformatter_annotati_45808425("annotation_coverage()<br/><small>compiler/formatters/json_formatter.rb</small>")
        formatters_json_formatter_jsonformatter_build_ha_76b6e714("build_hash()<br/><small>compiler/formatters/json_formatter.rb</small>")
        formatters_json_formatter_jsonformatter_format_m_58768623("format_metadata()<br/><small>compiler/formatters/json_formatter.rb</small>")
    end
    analysis_conversation_analyzer_conversationanaly_22cc21a4 -->|method| analysis_conversation_analyzer_conversationanaly_11a87abc
    analysis_conversation_analyzer_conversationanaly_22cc21a4 -->|method| analysis_conversation_analyzer_conversationanaly_8c9e44a2
    analysis_conversation_analyzer_conversationanaly_22cc21a4 -->|method| analysis_conversation_analyzer_conversationanaly_51faa16e
    analysis_conversation_analyzer_conversationanaly_22cc21a4 -->|method| analysis_conversation_analyzer_conversationanaly_7da27936
    analysis_conversation_analyzer_conversationanaly_22cc21a4 -->|method| analysis_conversation_analyzer_conversationanaly_cc598ed8
    analysis_conversation_analyzer_conversationanaly_22cc21a4 -->|method| analysis_conversation_analyzer_conversationanaly_08944a90
    analysis_conversation_analyzer_conversationanaly_22cc21a4 -->|method| analysis_conversation_analyzer_conversationanaly_b28b8629
    analysis_conversation_analyzer_conversationanaly_22cc21a4 -->|method| analysis_conversation_analyzer_conversationanaly_1f8808fa
    analysis_conversation_analyzer_conversationanaly_22cc21a4 -->|method| analysis_conversation_analyzer_conversationanaly_2ca6ac64
    analysis_conversation_analyzer_conversationanaly_22cc21a4 -->|method| analysis_conversation_analyzer_conversationanaly_8c73969d
    analysis_conversation_analyzer_conversationanaly_22cc21a4 -->|method| analysis_conversation_analyzer_conversationanaly_eafa79dc
    analysis_conversation_analyzer_conversationanaly_22cc21a4 -->|method| analysis_conversation_analyzer_conversationanaly_049a3b17
    analysis_conversation_analyzer_conversationanaly_22cc21a4 -->|method| analysis_conversation_analyzer_conversationanaly_cce05129
    analysis_conversation_analyzer_conversationanaly_11a87abc -->|calls| analysis_conversation_analyzer_conversationanaly_51faa16e
    analysis_conversation_analyzer_conversationanaly_11a87abc -->|calls| analysis_conversation_analyzer_conversationanaly_7da27936
    analysis_conversation_analyzer_conversationanaly_11a87abc -->|calls| analysis_conversation_analyzer_conversationanaly_cc598ed8
    analysis_conversation_analyzer_conversationanaly_11a87abc -->|calls| analysis_conversation_analyzer_conversationanaly_08944a90
    analysis_conversation_analyzer_conversationanaly_11a87abc -->|calls| analysis_conversation_analyzer_conversationanaly_b28b8629
    analysis_conversation_analyzer_conversationanaly_11a87abc -->|calls| analysis_conversation_analyzer_conversationanaly_1f8808fa
    analysis_conversation_analyzer_conversationanaly_11a87abc -->|calls| analysis_conversation_analyzer_conversationanaly_eafa79dc
    analysis_conversation_analyzer_conversationanaly_11a87abc -->|calls| analysis_conversation_analyzer_conversationanaly_049a3b17
    analysis_conversation_analyzer_conversationanaly_11a87abc -->|calls| analysis_conversation_analyzer_conversationanaly_cce05129
    analysis_conversation_analyzer_conversationanaly_51faa16e -->|calls| analysis_conversation_analyzer_conversationanaly_8c9e44a2
    analysis_conversation_analyzer_conversationanaly_51faa16e -->|calls| analysis_conversation_analyzer_conversationanaly_2ca6ac64
    %% Omitted for readability: 5 nodes, 4 edges
    class analysis_conversation_analyzer_conversationanaly_22cc21a4 klass;
    class analysis_conversation_analyzer_conversationanaly_11a87abc function;
    class analysis_conversation_analyzer_conversationanaly_51faa16e function;
    class analysis_conversation_analyzer_conversationanaly_8c9e44a2 function;
    class analysis_conversation_analyzer_conversationanaly_7da27936 function;
    class analysis_conversation_analyzer_conversationanaly_cc598ed8 function;
    class analysis_conversation_analyzer_conversationanaly_08944a90 function;
    class analysis_conversation_analyzer_conversationanaly_b28b8629 function;
    class analysis_conversation_analyzer_conversationanaly_1f8808fa function;
    class analysis_conversation_analyzer_conversationanaly_2ca6ac64 function;
    class analysis_conversation_analyzer_conversationanaly_8c73969d function;
    class analysis_conversation_analyzer_conversationanaly_eafa79dc function;
    class analysis_conversation_analyzer_conversationanaly_049a3b17 function;
    class analysis_conversation_analyzer_conversationanaly_cce05129 function;
    class formatters_json_formatter_jsonformatter_a9d3f8de klass;
    class formatters_json_formatter_jsonformatter_annotati_45808425 function;
    class formatters_json_formatter_jsonformatter_build_ha_76b6e714 function;
    class formatters_json_formatter_jsonformatter_format_m_58768623 function;
    classDef entry fill:#422006,stroke:#fbbf24,color:#fde68a,stroke-width:1px;
    classDef api fill:#450a0a,stroke:#f87171,color:#fee2e2,stroke-width:1px;
    classDef async fill:#2e1065,stroke:#a78bfa,color:#ede9fe,stroke-width:1px;
    classDef klass fill:#064e3b,stroke:#34d399,color:#d1fae5,stroke-width:1px;
    classDef ui fill:#831843,stroke:#f472b6,color:#fce7f3,stroke-width:1px;
    classDef module fill:#172554,stroke:#60a5fa,color:#dbeafe,stroke-width:1px;
    classDef test fill:#3f3f46,stroke:#a1a1aa,color:#f4f4f5,stroke-width:1px;
    classDef concept fill:#292524,stroke:#a8a29e,color:#fafaf9,stroke-dasharray:4 3;
    classDef function fill:#0f172a,stroke:#38bdf8,color:#e0f2fe,stroke-width:1px;
```


## Callflow 3

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"fontSize": "15.0px", "fontFamily": "Segoe UI, system-ui, sans-serif", "primaryColor": "#1e293b", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#38bdf8", "secondaryColor": "#0f172a", "tertiaryColor": "#334155", "lineColor": "#64748b", "textColor": "#e2e8f0"}, "flowchart": {"htmlLabels": true, "curve": "basis", "nodeSpacing": 48, "rankSpacing": 64, "padding": 14, "diagramPadding": 10, "useMaxWidth": true}}}%%
flowchart LR
    %% Section: Analysis & Clustering (35 nodes, 45 edges)
    subgraph analysis_clustering_compiler_analysis_speaker_pr_ea09ffe8["compiler/analysis/speaker_profiler.rb"]
        analysis_speaker_profiler_speakerprofiler_f8dbb0c2("SpeakerProfiler<br/><small>compiler/analysis/speaker_profiler.rb</small>")
        analysis_speaker_profiler_speakerprofiler_build_65a31526("build_profile()<br/><small>compiler/analysis/speaker_profiler.rb</small>")
        analysis_speaker_profiler_speakerprofiler_aggreg_49516921("aggregate_process_types()<br/><small>compiler/analysis/speaker_profiler.rb</small>")
        analysis_speaker_profiler_speakerprofiler_build_d489d1c2("build_profiles()<br/><small>compiler/analysis/speaker_profiler.rb</small>")
        analysis_speaker_profiler_speakerprofiler_calcul_35874cf7("calculate_mood_distribution()<br/><small>compiler/analysis/speaker_profiler.rb</small>")
        analysis_speaker_profiler_speakerprofiler_initia_4e55b369("initialize()<br/><small>compiler/analysis/speaker_profiler.rb</small>")
        analysis_speaker_profiler_speakerprofiler_mean_d08818b7("mean()<br/><small>compiler/analysis/speaker_profiler.rb</small>")
    end
    subgraph analysis_clustering_compiler_analysis_cohesion_a_7a915b48["compiler/analysis/cohesion_analyzer.rb"]
        analysis_cohesion_analyzer_cohesionanalyzer_70dd4798("CohesionAnalyzer<br/><small>compiler/analysis/cohesion_analyzer.rb</small>")
        analysis_cohesion_analyzer_cohesionanalyzer_calc_5f89f707("calculate_metrics()<br/><small>compiler/analysis/cohesion_analyzer.rb</small>")
        analysis_cohesion_analyzer_cohesionanalyzer_anal_39b06f66("analyze()<br/><small>compiler/analysis/cohesion_analyzer.rb</small>")
        analysis_cohesion_analyzer_cohesionanalyzer_calc_f6915252("calculate_density()<br/><small>compiler/analysis/cohesion_analyzer.rb</small>")
        analysis_cohesion_analyzer_cohesionanalyzer_calc_288eebb1("calculate_repetition()<br/><small>compiler/analysis/cohesion_analyzer.rb</small>")
        analysis_cohesion_analyzer_cohesionanalyzer_defa_01100d60("default_metrics()<br/><small>compiler/analysis/cohesion_analyzer.rb</small>")
    end
    subgraph analysis_clustering_compiler_analysis_correlatio_de428fc3["compiler/analysis/correlation_analyzer.rb"]
        analysis_correlation_analyzer_correlationanalyze_42517e87("CorrelationAnalyzer<br/><small>compiler/analysis/correlation_analyzer.rb</small>")
        analysis_correlation_analyzer_correlationanalyze_71ba14d5("correlate_process_tenor()<br/><small>compiler/analysis/correlation_analyzer.rb</small>")
        analysis_correlation_analyzer_correlationanalyze_a8a69b71("initialize()<br/><small>compiler/analysis/correlation_analyzer.rb</small>")
        analysis_correlation_analyzer_correlationanalyze_ffde35ac("mean()<br/><small>compiler/analysis/correlation_analyzer.rb</small>")
    end
    query_20260613_032646_parse_6dcec26c("parse()<br/><small>graphify-out/memory/query_20260613_032646_why_does_parse_connect_conversation_analysis_to_co.md</small>")
    analysis_cohesion_analyzer_cohesionanalyzer_70dd4798 -->|method| analysis_cohesion_analyzer_cohesionanalyzer_anal_39b06f66
    analysis_cohesion_analyzer_cohesionanalyzer_70dd4798 -->|method| analysis_cohesion_analyzer_cohesionanalyzer_calc_f6915252
    analysis_cohesion_analyzer_cohesionanalyzer_70dd4798 -->|method| analysis_cohesion_analyzer_cohesionanalyzer_calc_5f89f707
    analysis_cohesion_analyzer_cohesionanalyzer_70dd4798 -->|method| analysis_cohesion_analyzer_cohesionanalyzer_calc_288eebb1
    analysis_cohesion_analyzer_cohesionanalyzer_70dd4798 -->|method| analysis_cohesion_analyzer_cohesionanalyzer_defa_01100d60
    analysis_cohesion_analyzer_cohesionanalyzer_anal_39b06f66 -->|calls| analysis_cohesion_analyzer_cohesionanalyzer_calc_5f89f707
    analysis_cohesion_analyzer_cohesionanalyzer_calc_5f89f707 -->|calls| analysis_cohesion_analyzer_cohesionanalyzer_calc_f6915252
    analysis_cohesion_analyzer_cohesionanalyzer_calc_5f89f707 -->|calls| analysis_cohesion_analyzer_cohesionanalyzer_calc_288eebb1
    analysis_correlation_analyzer_correlationanalyze_42517e87 -->|method| analysis_correlation_analyzer_correlationanalyze_71ba14d5
    analysis_correlation_analyzer_correlationanalyze_42517e87 -->|method| analysis_correlation_analyzer_correlationanalyze_a8a69b71
    analysis_correlation_analyzer_correlationanalyze_42517e87 -->|method| analysis_correlation_analyzer_correlationanalyze_ffde35ac
    analysis_correlation_analyzer_correlationanalyze_71ba14d5 -->|calls| analysis_correlation_analyzer_correlationanalyze_ffde35ac
    analysis_speaker_profiler_speakerprofiler_f8dbb0c2 -->|method| analysis_speaker_profiler_speakerprofiler_aggreg_49516921
    analysis_speaker_profiler_speakerprofiler_f8dbb0c2 -->|method| analysis_speaker_profiler_speakerprofiler_build_65a31526
    analysis_speaker_profiler_speakerprofiler_f8dbb0c2 -->|method| analysis_speaker_profiler_speakerprofiler_build_d489d1c2
    analysis_speaker_profiler_speakerprofiler_f8dbb0c2 -->|method| analysis_speaker_profiler_speakerprofiler_calcul_35874cf7
    analysis_speaker_profiler_speakerprofiler_f8dbb0c2 -->|method| analysis_speaker_profiler_speakerprofiler_initia_4e55b369
    analysis_speaker_profiler_speakerprofiler_f8dbb0c2 -->|method| analysis_speaker_profiler_speakerprofiler_mean_d08818b7
    analysis_speaker_profiler_speakerprofiler_build_65a31526 -->|calls| analysis_speaker_profiler_speakerprofiler_mean_d08818b7
    analysis_speaker_profiler_speakerprofiler_build_65a31526 -->|calls| analysis_speaker_profiler_speakerprofiler_build_d489d1c2
    %% Omitted for readability: 17 nodes, 0 edges
    class analysis_speaker_profiler_speakerprofiler_f8dbb0c2 klass;
    class analysis_speaker_profiler_speakerprofiler_build_65a31526 function;
    class analysis_speaker_profiler_speakerprofiler_aggreg_49516921 function;
    class analysis_speaker_profiler_speakerprofiler_build_d489d1c2 function;
    class analysis_speaker_profiler_speakerprofiler_calcul_35874cf7 function;
    class analysis_speaker_profiler_speakerprofiler_initia_4e55b369 function;
    class analysis_speaker_profiler_speakerprofiler_mean_d08818b7 function;
    class analysis_cohesion_analyzer_cohesionanalyzer_70dd4798 klass;
    class analysis_cohesion_analyzer_cohesionanalyzer_calc_5f89f707 function;
    class analysis_cohesion_analyzer_cohesionanalyzer_anal_39b06f66 function;
    class analysis_cohesion_analyzer_cohesionanalyzer_calc_f6915252 function;
    class analysis_cohesion_analyzer_cohesionanalyzer_calc_288eebb1 function;
    class analysis_cohesion_analyzer_cohesionanalyzer_defa_01100d60 function;
    class analysis_correlation_analyzer_correlationanalyze_42517e87 klass;
    class analysis_correlation_analyzer_correlationanalyze_71ba14d5 function;
    class analysis_correlation_analyzer_correlationanalyze_a8a69b71 function;
    class analysis_correlation_analyzer_correlationanalyze_ffde35ac function;
    class query_20260613_032646_parse_6dcec26c function;
    classDef entry fill:#422006,stroke:#fbbf24,color:#fde68a,stroke-width:1px;
    classDef api fill:#450a0a,stroke:#f87171,color:#fee2e2,stroke-width:1px;
    classDef async fill:#2e1065,stroke:#a78bfa,color:#ede9fe,stroke-width:1px;
    classDef klass fill:#064e3b,stroke:#34d399,color:#d1fae5,stroke-width:1px;
    classDef ui fill:#831843,stroke:#f472b6,color:#fce7f3,stroke-width:1px;
    classDef module fill:#172554,stroke:#60a5fa,color:#dbeafe,stroke-width:1px;
    classDef test fill:#3f3f46,stroke:#a1a1aa,color:#f4f4f5,stroke-width:1px;
    classDef concept fill:#292524,stroke:#a8a29e,color:#fafaf9,stroke-dasharray:4 3;
    classDef function fill:#0f172a,stroke:#38bdf8,color:#e0f2fe,stroke-width:1px;
```


## Callflow 4

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"fontSize": "15.0px", "fontFamily": "Segoe UI, system-ui, sans-serif", "primaryColor": "#1e293b", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#38bdf8", "secondaryColor": "#0f172a", "tertiaryColor": "#334155", "lineColor": "#64748b", "textColor": "#e2e8f0"}, "flowchart": {"htmlLabels": true, "curve": "basis", "nodeSpacing": 48, "rankSpacing": 64, "padding": 14, "diagramPadding": 10, "useMaxWidth": true}}}%%
flowchart LR
    %% Section: Outputs & Docs (62 nodes, 80 edges)
    subgraph outputs_docs_compiler_analysis_documentation_ana_e30e1b1d["compiler/analysis/documentation_analyzer.rb"]
        analysis_documentation_analyzer_documentationana_84138c61("DocumentationAnalyzer<br/><small>compiler/analysis/documentation_analyzer.rb</small>")
        analysis_documentation_analyzer_documentationana_238df06d("analyze()<br/><small>compiler/analysis/documentation_analyzer.rb</small>")
        analysis_documentation_analyzer_documentationana_c48446d1("compile_section()<br/><small>compiler/analysis/documentation_analyzer.rb</small>")
        analysis_documentation_analyzer_documentationana_5d78a700("detect_example_passages()<br/><small>compiler/analysis/documentation_analyzer.rb</small>")
        analysis_documentation_analyzer_documentationana_74662ff2("detect_key_moments()<br/><small>compiler/analysis/documentation_analyzer.rb</small>")
        analysis_documentation_analyzer_documentationana_ae1cbd8d("field_evolution()<br/><small>compiler/analysis/documentation_analyzer.rb</small>")
        analysis_documentation_analyzer_documentationana_cfd8516d("generate_topic_insights()<br/><small>compiler/analysis/documentation_analyzer.rb</small>")
        analysis_documentation_analyzer_documentationana_9ff4b5a3("initialize()<br/><small>compiler/analysis/documentation_analyzer.rb</small>")
        analysis_documentation_analyzer_documentationana_f1942732("load_sections()<br/><small>compiler/analysis/documentation_analyzer.rb</small>")
        analysis_documentation_analyzer_documentationana_617723f6("mean()<br/><small>compiler/analysis/documentation_analyzer.rb</small>")
        analysis_documentation_analyzer_documentationana_d6213cab("report_progress()<br/><small>compiler/analysis/documentation_analyzer.rb</small>")
        analysis_documentation_analyzer_documentationana_4d2a8c13("timeline()<br/><small>compiler/analysis/documentation_analyzer.rb</small>")
        analysis_documentation_analyzer_documentationana_4c02b29e("topic_evolution()<br/><small>compiler/analysis/documentation_analyzer.rb</small>")
    end
    subgraph outputs_docs_compiler_analysis_tenor_tracker_rb_96f412c5["compiler/analysis/tenor_tracker.rb"]
        analysis_tenor_tracker_tenortracker_bafc7015("TenorTracker<br/><small>compiler/analysis/tenor_tracker.rb</small>")
        analysis_tenor_tracker_tenortracker_calculate_sh_d216dd7b("calculate_shifts()<br/><small>compiler/analysis/tenor_tracker.rb</small>")
    end
    formatters_base_formatter_baseformatter_dc96c473("BaseFormatter<br/><small>compiler/formatters/base_formatter.rb</small>")
    pass_one_pass_one_engine_passoneengine_1967dc5f("PassOneEngine<br/><small>compiler/pass_one/pass_one_engine.rb</small>")
    compiler_pipeline_pipeline_554e7cf0("Pipeline<br/><small>sfl/compiler/pipeline.rb</small>")
    analysis_documentation_analyzer_documentationana_84138c61 -->|method| analysis_documentation_analyzer_documentationana_238df06d
    analysis_documentation_analyzer_documentationana_84138c61 -->|method| analysis_documentation_analyzer_documentationana_c48446d1
    analysis_documentation_analyzer_documentationana_84138c61 -->|method| analysis_documentation_analyzer_documentationana_5d78a700
    analysis_documentation_analyzer_documentationana_84138c61 -->|method| analysis_documentation_analyzer_documentationana_74662ff2
    analysis_documentation_analyzer_documentationana_84138c61 -->|method| analysis_documentation_analyzer_documentationana_ae1cbd8d
    analysis_documentation_analyzer_documentationana_84138c61 -->|method| analysis_documentation_analyzer_documentationana_cfd8516d
    analysis_documentation_analyzer_documentationana_84138c61 -->|method| analysis_documentation_analyzer_documentationana_9ff4b5a3
    analysis_documentation_analyzer_documentationana_84138c61 -->|method| analysis_documentation_analyzer_documentationana_f1942732
    analysis_documentation_analyzer_documentationana_84138c61 -->|method| analysis_documentation_analyzer_documentationana_617723f6
    analysis_documentation_analyzer_documentationana_84138c61 -->|method| analysis_documentation_analyzer_documentationana_d6213cab
    analysis_documentation_analyzer_documentationana_84138c61 -->|method| analysis_documentation_analyzer_documentationana_4d2a8c13
    analysis_documentation_analyzer_documentationana_84138c61 -->|method| analysis_documentation_analyzer_documentationana_4c02b29e
    analysis_documentation_analyzer_documentationana_238df06d -->|calls| analysis_documentation_analyzer_documentationana_c48446d1
    analysis_documentation_analyzer_documentationana_238df06d -->|calls| analysis_documentation_analyzer_documentationana_5d78a700
    analysis_documentation_analyzer_documentationana_238df06d -->|calls| analysis_documentation_analyzer_documentationana_74662ff2
    analysis_documentation_analyzer_documentationana_238df06d -->|calls| analysis_documentation_analyzer_documentationana_ae1cbd8d
    analysis_documentation_analyzer_documentationana_238df06d -->|calls| analysis_documentation_analyzer_documentationana_cfd8516d
    analysis_documentation_analyzer_documentationana_238df06d -->|calls| analysis_documentation_analyzer_documentationana_f1942732
    analysis_documentation_analyzer_documentationana_238df06d -->|calls| analysis_documentation_analyzer_documentationana_d6213cab
    analysis_documentation_analyzer_documentationana_238df06d -->|calls| analysis_documentation_analyzer_documentationana_4d2a8c13
    analysis_documentation_analyzer_documentationana_238df06d -->|calls| analysis_documentation_analyzer_documentationana_4c02b29e
    analysis_documentation_analyzer_documentationana_c48446d1 -->|calls| analysis_documentation_analyzer_documentationana_617723f6
    analysis_tenor_tracker_tenortracker_bafc7015 -->|method| analysis_tenor_tracker_tenortracker_calculate_sh_d216dd7b
    %% Omitted for readability: 44 nodes, 0 edges
    class analysis_documentation_analyzer_documentationana_84138c61 klass;
    class analysis_documentation_analyzer_documentationana_238df06d function;
    class analysis_documentation_analyzer_documentationana_c48446d1 function;
    class analysis_documentation_analyzer_documentationana_5d78a700 function;
    class analysis_documentation_analyzer_documentationana_74662ff2 function;
    class analysis_documentation_analyzer_documentationana_ae1cbd8d function;
    class analysis_documentation_analyzer_documentationana_cfd8516d function;
    class analysis_documentation_analyzer_documentationana_9ff4b5a3 function;
    class analysis_documentation_analyzer_documentationana_f1942732 function;
    class analysis_documentation_analyzer_documentationana_617723f6 function;
    class analysis_documentation_analyzer_documentationana_d6213cab function;
    class analysis_documentation_analyzer_documentationana_4d2a8c13 function;
    class analysis_documentation_analyzer_documentationana_4c02b29e function;
    class analysis_tenor_tracker_tenortracker_bafc7015 klass;
    class analysis_tenor_tracker_tenortracker_calculate_sh_d216dd7b function;
    class formatters_base_formatter_baseformatter_dc96c473 klass;
    class pass_one_pass_one_engine_passoneengine_1967dc5f klass;
    class compiler_pipeline_pipeline_554e7cf0 klass;
    classDef entry fill:#422006,stroke:#fbbf24,color:#fde68a,stroke-width:1px;
    classDef api fill:#450a0a,stroke:#f87171,color:#fee2e2,stroke-width:1px;
    classDef async fill:#2e1065,stroke:#a78bfa,color:#ede9fe,stroke-width:1px;
    classDef klass fill:#064e3b,stroke:#34d399,color:#d1fae5,stroke-width:1px;
    classDef ui fill:#831843,stroke:#f472b6,color:#fce7f3,stroke-width:1px;
    classDef module fill:#172554,stroke:#60a5fa,color:#dbeafe,stroke-width:1px;
    classDef test fill:#3f3f46,stroke:#a1a1aa,color:#f4f4f5,stroke-width:1px;
    classDef concept fill:#292524,stroke:#a8a29e,color:#fafaf9,stroke-dasharray:4 3;
    classDef function fill:#0f172a,stroke:#38bdf8,color:#e0f2fe,stroke-width:1px;
```


## Callflow 5

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"fontSize": "15.0px", "fontFamily": "Segoe UI, system-ui, sans-serif", "primaryColor": "#1e293b", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#38bdf8", "secondaryColor": "#0f172a", "tertiaryColor": "#334155", "lineColor": "#64748b", "textColor": "#e2e8f0"}, "flowchart": {"htmlLabels": true, "curve": "basis", "nodeSpacing": 48, "rankSpacing": 64, "padding": 14, "diagramPadding": 10, "useMaxWidth": true}}}%%
flowchart LR
    %% Section: CLI & Skill Installers (2 nodes, 1 edges)
    openai_trackboi_6d5136dc("trackboi Agent<br/><small>agents/openai.yaml</small>")
    openai_orient_agent_95654355("orient_agent<br/><small>agents/openai.yaml</small>")
    openai_trackboi_6d5136dc -->|calls| openai_orient_agent_95654355
    class openai_trackboi_6d5136dc function;
    class openai_orient_agent_95654355 function;
    classDef entry fill:#422006,stroke:#fbbf24,color:#fde68a,stroke-width:1px;
    classDef api fill:#450a0a,stroke:#f87171,color:#fee2e2,stroke-width:1px;
    classDef async fill:#2e1065,stroke:#a78bfa,color:#ede9fe,stroke-width:1px;
    classDef klass fill:#064e3b,stroke:#34d399,color:#d1fae5,stroke-width:1px;
    classDef ui fill:#831843,stroke:#f472b6,color:#fce7f3,stroke-width:1px;
    classDef module fill:#172554,stroke:#60a5fa,color:#dbeafe,stroke-width:1px;
    classDef test fill:#3f3f46,stroke:#a1a1aa,color:#f4f4f5,stroke-width:1px;
    classDef concept fill:#292524,stroke:#a8a29e,color:#fafaf9,stroke-dasharray:4 3;
    classDef function fill:#0f172a,stroke:#38bdf8,color:#e0f2fe,stroke-width:1px;
```


## Callflow 6

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"fontSize": "15.0px", "fontFamily": "Segoe UI, system-ui, sans-serif", "primaryColor": "#1e293b", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#38bdf8", "secondaryColor": "#0f172a", "tertiaryColor": "#334155", "lineColor": "#64748b", "textColor": "#e2e8f0"}, "flowchart": {"htmlLabels": true, "curve": "basis", "nodeSpacing": 48, "rankSpacing": 64, "padding": 14, "diagramPadding": 10, "useMaxWidth": true}}}%%
flowchart LR
    %% Section: Ingestion & Updates (96 nodes, 143 edges)
    subgraph ingest_cache_update_compiler_analysis_topic_mode_2a162623["compiler/analysis/topic_modeler.rb"]
        analysis_topic_modeler_topicmodeler_7c56ddc2("TopicModeler<br/><small>compiler/analysis/topic_modeler.rb</small>")
        analysis_topic_modeler_topicmodeler_detect_topic_7a164f9f("detect_topic_shifts()<br/><small>compiler/analysis/topic_modeler.rb</small>")
        analysis_topic_modeler_topicmodeler_fit_e9c2e99c("fit()<br/><small>compiler/analysis/topic_modeler.rb</small>")
        analysis_topic_modeler_topicmodeler_initialize_be9d7e39("initialize()<br/><small>compiler/analysis/topic_modeler.rb</small>")
        analysis_topic_modeler_topicmodeler_load_model_5b54b5a8("load_model()<br/><small>compiler/analysis/topic_modeler.rb</small>")
        analysis_topic_modeler_topicmodeler_save_afa76bfb("save()<br/><small>compiler/analysis/topic_modeler.rb</small>")
        analysis_topic_modeler_topicmodeler_turn_distrib_5324a076("turn_distributions()<br/><small>compiler/analysis/topic_modeler.rb</small>")
        analysis_topic_modeler_tokenize_a0d8fa87("tokenize()<br/><small>compiler/analysis/topic_modeler.rb</small>")
        analysis_topic_modeler_cosine_distance_f4c683ed("cosine_distance()<br/><small>compiler/analysis/topic_modeler.rb</small>")
        analysis_topic_modeler_topic_name_b8f92bd8("topic_name()<br/><small>compiler/analysis/topic_modeler.rb</small>")
        analysis_topic_modeler_assign_topics_to_turns_06b015c2("assign_topics_to_turns()<br/><small>compiler/analysis/topic_modeler.rb</small>")
    end
    subgraph ingest_cache_update_compiler_formatters_markdown_d891989c["compiler/formatters/markdown_formatter.rb"]
        formatters_markdown_formatter_markdownformatter_a25bab02("MarkdownFormatter<br/><small>compiler/formatters/markdown_formatter.rb</small>")
        formatters_markdown_formatter_markdownformatter_a2c6e035("actor_label()<br/><small>compiler/formatters/markdown_formatter.rb</small>")
        formatters_markdown_formatter_markdownformatter_26329071("actors_list_label()<br/><small>compiler/formatters/markdown_formatter.rb</small>")
    end
    chat_app_app_147c126d("App<br/><small>compiler/chat/app.rb</small>")
    chat_session_session_f70f055a("Session<br/><small>compiler/chat/session.rb</small>")
    storage_pipeline_cache_pipelinecache_c1343951("PipelineCache<br/><small>compiler/storage/pipeline_cache.rb</small>")
    compiler_markdown_loader_markdownloader_06e0c660("MarkdownLoader<br/><small>sfl/compiler/markdown_loader.rb</small>")
    analysis_topic_modeler_topicmodeler_7c56ddc2 -->|method| analysis_topic_modeler_topicmodeler_detect_topic_7a164f9f
    analysis_topic_modeler_topicmodeler_7c56ddc2 -->|method| analysis_topic_modeler_topicmodeler_fit_e9c2e99c
    analysis_topic_modeler_topicmodeler_7c56ddc2 -->|method| analysis_topic_modeler_topicmodeler_initialize_be9d7e39
    analysis_topic_modeler_topicmodeler_7c56ddc2 -->|method| analysis_topic_modeler_topicmodeler_load_model_5b54b5a8
    analysis_topic_modeler_topicmodeler_7c56ddc2 -->|method| analysis_topic_modeler_topicmodeler_save_afa76bfb
    analysis_topic_modeler_topicmodeler_7c56ddc2 -->|method| analysis_topic_modeler_topicmodeler_turn_distrib_5324a076
    analysis_topic_modeler_topicmodeler_fit_e9c2e99c -->|calls| analysis_topic_modeler_tokenize_a0d8fa87
    analysis_topic_modeler_topicmodeler_detect_topic_7a164f9f -->|calls| analysis_topic_modeler_cosine_distance_f4c683ed
    analysis_topic_modeler_topicmodeler_detect_topic_7a164f9f -->|calls| analysis_topic_modeler_topic_name_b8f92bd8
    analysis_topic_modeler_assign_topics_to_turns_06b015c2 -->|calls| analysis_topic_modeler_tokenize_a0d8fa87
    formatters_markdown_formatter_markdownformatter_a25bab02 -->|method| formatters_markdown_formatter_markdownformatter_a2c6e035
    formatters_markdown_formatter_markdownformatter_a25bab02 -->|method| formatters_markdown_formatter_markdownformatter_26329071
    %% Omitted for readability: 78 nodes, 0 edges
    class analysis_topic_modeler_topicmodeler_7c56ddc2 klass;
    class analysis_topic_modeler_topicmodeler_detect_topic_7a164f9f function;
    class analysis_topic_modeler_topicmodeler_fit_e9c2e99c function;
    class analysis_topic_modeler_topicmodeler_initialize_be9d7e39 function;
    class analysis_topic_modeler_topicmodeler_load_model_5b54b5a8 function;
    class analysis_topic_modeler_topicmodeler_save_afa76bfb function;
    class analysis_topic_modeler_topicmodeler_turn_distrib_5324a076 function;
    class analysis_topic_modeler_tokenize_a0d8fa87 function;
    class analysis_topic_modeler_cosine_distance_f4c683ed function;
    class analysis_topic_modeler_topic_name_b8f92bd8 function;
    class analysis_topic_modeler_assign_topics_to_turns_06b015c2 function;
    class formatters_markdown_formatter_markdownformatter_a25bab02 klass;
    class formatters_markdown_formatter_markdownformatter_a2c6e035 function;
    class formatters_markdown_formatter_markdownformatter_26329071 function;
    class chat_app_app_147c126d klass;
    class chat_session_session_f70f055a klass;
    class storage_pipeline_cache_pipelinecache_c1343951 klass;
    class compiler_markdown_loader_markdownloader_06e0c660 klass;
    classDef entry fill:#422006,stroke:#fbbf24,color:#fde68a,stroke-width:1px;
    classDef api fill:#450a0a,stroke:#f87171,color:#fee2e2,stroke-width:1px;
    classDef async fill:#2e1065,stroke:#a78bfa,color:#ede9fe,stroke-width:1px;
    classDef klass fill:#064e3b,stroke:#34d399,color:#d1fae5,stroke-width:1px;
    classDef ui fill:#831843,stroke:#f472b6,color:#fce7f3,stroke-width:1px;
    classDef module fill:#172554,stroke:#60a5fa,color:#dbeafe,stroke-width:1px;
    classDef test fill:#3f3f46,stroke:#a1a1aa,color:#f4f4f5,stroke-width:1px;
    classDef concept fill:#292524,stroke:#a8a29e,color:#fafaf9,stroke-dasharray:4 3;
    classDef function fill:#0f172a,stroke:#38bdf8,color:#e0f2fe,stroke-width:1px;
```


## Callflow 7

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"fontSize": "15.0px", "fontFamily": "Segoe UI, system-ui, sans-serif", "primaryColor": "#1e293b", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#38bdf8", "secondaryColor": "#0f172a", "tertiaryColor": "#334155", "lineColor": "#64748b", "textColor": "#e2e8f0"}, "flowchart": {"htmlLabels": true, "curve": "basis", "nodeSpacing": 48, "rankSpacing": 64, "padding": 14, "diagramPadding": 10, "useMaxWidth": true}}}%%
flowchart LR
    %% Section: Serving API (16 nodes, 22 edges)
    subgraph serve_api_compiler_retrieval_hybrid_retriever_rb_edab0fcc["compiler/retrieval/hybrid_retriever.rb"]
        retrieval_hybrid_retriever_hybridretriever_be70b989("HybridRetriever<br/><small>compiler/retrieval/hybrid_retriever.rb</small>")
        retrieval_hybrid_retriever_hybridretriever_retri_614a2f3b("retrieve()<br/><small>compiler/retrieval/hybrid_retriever.rb</small>")
        retrieval_hybrid_retriever_hybridretriever_apply_95985841("apply_filters()<br/><small>compiler/retrieval/hybrid_retriever.rb</small>")
        retrieval_hybrid_retriever_hybridretriever_initi_33e29682("initialize()<br/><small>compiler/retrieval/hybrid_retriever.rb</small>")
        retrieval_hybrid_retriever_hybridretriever_keywo_b8a9169c("keyword_search()<br/><small>compiler/retrieval/hybrid_retriever.rb</small>")
        retrieval_hybrid_retriever_hybridretriever_recip_07a4ff26("reciprocal_rank_fusion()<br/><small>compiler/retrieval/hybrid_retriever.rb</small>")
        retrieval_hybrid_retriever_hybridretriever_seman_536c621c("semantic_search()<br/><small>compiler/retrieval/hybrid_retriever.rb</small>")
        retrieval_hybrid_retriever_85ebcc67("hybrid_retriever.rb")
    end
    subgraph serve_api_compiler_retrieval_embedder_rb_f1a565d3["compiler/retrieval/embedder.rb"]
        retrieval_embedder_embedder_18bbb897("Embedder<br/><small>compiler/retrieval/embedder.rb</small>")
        retrieval_embedder_embedder_embed_63c12c1f("embed()<br/><small>compiler/retrieval/embedder.rb</small>")
        retrieval_embedder_embedder_initialize_740507d3("initialize()<br/><small>compiler/retrieval/embedder.rb</small>")
        retrieval_embedder_embedder_call_ruby_llm_df4ff24e("call_ruby_llm()<br/><small>compiler/retrieval/embedder.rb</small>")
        retrieval_embedder_embedder_configure_ruby_llm_03dfcaa9("configure_ruby_llm()<br/><small>compiler/retrieval/embedder.rb</small>")
        retrieval_embedder_embedder_openai_compatible_ba_530b291f("openai_compatible_base()<br/><small>compiler/retrieval/embedder.rb</small>")
        retrieval_embedder_507174a5("embedder.rb")
    end
    sfl_compiler_configure_6d77cc62("configure()<br/><small>lib/sfl/compiler.rb</small>")
    retrieval_embedder_embedder_18bbb897 -->|method| retrieval_embedder_embedder_call_ruby_llm_df4ff24e
    retrieval_embedder_embedder_18bbb897 -->|method| retrieval_embedder_embedder_configure_ruby_llm_03dfcaa9
    retrieval_embedder_embedder_18bbb897 -->|method| retrieval_embedder_embedder_embed_63c12c1f
    retrieval_embedder_embedder_18bbb897 -->|method| retrieval_embedder_embedder_initialize_740507d3
    retrieval_embedder_embedder_18bbb897 -->|method| retrieval_embedder_embedder_openai_compatible_ba_530b291f
    retrieval_embedder_embedder_initialize_740507d3 -->|calls| retrieval_embedder_embedder_configure_ruby_llm_03dfcaa9
    retrieval_embedder_embedder_embed_63c12c1f -->|calls| retrieval_embedder_embedder_call_ruby_llm_df4ff24e
    retrieval_embedder_embedder_configure_ruby_llm_03dfcaa9 -->|calls| retrieval_embedder_embedder_openai_compatible_ba_530b291f
    retrieval_hybrid_retriever_hybridretriever_be70b989 -->|method| retrieval_hybrid_retriever_hybridretriever_apply_95985841
    retrieval_hybrid_retriever_hybridretriever_be70b989 -->|method| retrieval_hybrid_retriever_hybridretriever_initi_33e29682
    retrieval_hybrid_retriever_hybridretriever_be70b989 -->|method| retrieval_hybrid_retriever_hybridretriever_keywo_b8a9169c
    retrieval_hybrid_retriever_hybridretriever_be70b989 -->|method| retrieval_hybrid_retriever_hybridretriever_recip_07a4ff26
    retrieval_hybrid_retriever_hybridretriever_be70b989 -->|method| retrieval_hybrid_retriever_hybridretriever_retri_614a2f3b
    retrieval_hybrid_retriever_hybridretriever_be70b989 -->|method| retrieval_hybrid_retriever_hybridretriever_seman_536c621c
    retrieval_hybrid_retriever_hybridretriever_retri_614a2f3b -->|calls| retrieval_hybrid_retriever_hybridretriever_apply_95985841
    retrieval_hybrid_retriever_hybridretriever_retri_614a2f3b -->|calls| retrieval_hybrid_retriever_hybridretriever_keywo_b8a9169c
    retrieval_hybrid_retriever_hybridretriever_retri_614a2f3b -->|calls| retrieval_hybrid_retriever_hybridretriever_recip_07a4ff26
    retrieval_hybrid_retriever_hybridretriever_retri_614a2f3b -->|calls| retrieval_hybrid_retriever_hybridretriever_seman_536c621c
    class retrieval_hybrid_retriever_hybridretriever_be70b989 klass;
    class retrieval_hybrid_retriever_hybridretriever_retri_614a2f3b function;
    class retrieval_hybrid_retriever_hybridretriever_apply_95985841 function;
    class retrieval_hybrid_retriever_hybridretriever_initi_33e29682 function;
    class retrieval_hybrid_retriever_hybridretriever_keywo_b8a9169c function;
    class retrieval_hybrid_retriever_hybridretriever_recip_07a4ff26 function;
    class retrieval_hybrid_retriever_hybridretriever_seman_536c621c function;
    class retrieval_hybrid_retriever_85ebcc67 module;
    class retrieval_embedder_embedder_18bbb897 klass;
    class retrieval_embedder_embedder_embed_63c12c1f function;
    class retrieval_embedder_embedder_initialize_740507d3 function;
    class retrieval_embedder_embedder_call_ruby_llm_df4ff24e function;
    class retrieval_embedder_embedder_configure_ruby_llm_03dfcaa9 function;
    class retrieval_embedder_embedder_openai_compatible_ba_530b291f function;
    class retrieval_embedder_507174a5 module;
    class sfl_compiler_configure_6d77cc62 function;
    classDef entry fill:#422006,stroke:#fbbf24,color:#fde68a,stroke-width:1px;
    classDef api fill:#450a0a,stroke:#f87171,color:#fee2e2,stroke-width:1px;
    classDef async fill:#2e1065,stroke:#a78bfa,color:#ede9fe,stroke-width:1px;
    classDef klass fill:#064e3b,stroke:#34d399,color:#d1fae5,stroke-width:1px;
    classDef ui fill:#831843,stroke:#f472b6,color:#fce7f3,stroke-width:1px;
    classDef module fill:#172554,stroke:#60a5fa,color:#dbeafe,stroke-width:1px;
    classDef test fill:#3f3f46,stroke:#a1a1aa,color:#f4f4f5,stroke-width:1px;
    classDef concept fill:#292524,stroke:#a8a29e,color:#fafaf9,stroke-dasharray:4 3;
    classDef function fill:#0f172a,stroke:#38bdf8,color:#e0f2fe,stroke-width:1px;
```


## Callflow 8

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"fontSize": "15.0px", "fontFamily": "Segoe UI, system-ui, sans-serif", "primaryColor": "#1e293b", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#38bdf8", "secondaryColor": "#0f172a", "tertiaryColor": "#334155", "lineColor": "#64748b", "textColor": "#e2e8f0"}, "flowchart": {"htmlLabels": true, "curve": "basis", "nodeSpacing": 48, "rankSpacing": 64, "padding": 14, "diagramPadding": 10, "useMaxWidth": true}}}%%
flowchart LR
    %% Section: Correlation Analysis (28 nodes, 57 edges)
    pass_two_pass_two_engine_passtwoengine_268bffbd("PassTwoEngine<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_passtwoengine_annotate_6c590c2c("annotate_chunk()<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_sflbatchannotator_99ae68a1("SFLBatchAnnotator<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_passtwoengine_annotate_00557472("annotate_interpersonal()<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_passtwoengine_interpers_0b7e007d("interpersonal_from()<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_passtwoengine_annotate_997aef16("annotate_batch()<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_passtwoengine_annotate_1ca3b46a("annotate()<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_passtwoengine_annotated_22970e3e("annotated_clause()<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_passtwoengine_call_anno_24048e16("call_annotator_with_watchdog()<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_passtwoengine_clamp01_88144aeb("clamp01()<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_passtwoengine_default_b_b8b96196("default_batch_annotator()<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_passtwoengine_default_c_2608e9ff("default_circuit_breaker()<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_passtwoengine_default_i_fbc66946("default_interpersonal()<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_passtwoengine_default_t_eb6d181e("default_textual()<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_passtwoengine_dep_seque_1f98b988("dep_sequence()<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_passtwoengine_format_sy_1ebe5285("format_syntactic_context()<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_passtwoengine_log_and_w_8b1ba086("log_and_warn()<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_passtwoengine_normalize_db6a0c60("normalize_theme_type()<br/><small>compiler/pass_two/pass_two_engine.rb</small>")
    pass_two_pass_two_engine_passtwoengine_268bffbd -->|method| pass_two_pass_two_engine_passtwoengine_annotate_1ca3b46a
    pass_two_pass_two_engine_passtwoengine_268bffbd -->|method| pass_two_pass_two_engine_passtwoengine_annotate_997aef16
    pass_two_pass_two_engine_passtwoengine_268bffbd -->|method| pass_two_pass_two_engine_passtwoengine_annotate_6c590c2c
    pass_two_pass_two_engine_passtwoengine_268bffbd -->|method| pass_two_pass_two_engine_passtwoengine_annotate_00557472
    pass_two_pass_two_engine_passtwoengine_268bffbd -->|method| pass_two_pass_two_engine_passtwoengine_annotated_22970e3e
    pass_two_pass_two_engine_passtwoengine_268bffbd -->|method| pass_two_pass_two_engine_passtwoengine_call_anno_24048e16
    pass_two_pass_two_engine_passtwoengine_268bffbd -->|method| pass_two_pass_two_engine_passtwoengine_clamp01_88144aeb
    pass_two_pass_two_engine_passtwoengine_268bffbd -->|method| pass_two_pass_two_engine_passtwoengine_default_b_b8b96196
    pass_two_pass_two_engine_passtwoengine_268bffbd -->|method| pass_two_pass_two_engine_passtwoengine_default_c_2608e9ff
    pass_two_pass_two_engine_passtwoengine_268bffbd -->|method| pass_two_pass_two_engine_passtwoengine_default_i_fbc66946
    pass_two_pass_two_engine_passtwoengine_268bffbd -->|method| pass_two_pass_two_engine_passtwoengine_default_t_eb6d181e
    pass_two_pass_two_engine_passtwoengine_268bffbd -->|method| pass_two_pass_two_engine_passtwoengine_dep_seque_1f98b988
    pass_two_pass_two_engine_passtwoengine_268bffbd -->|method| pass_two_pass_two_engine_passtwoengine_format_sy_1ebe5285
    pass_two_pass_two_engine_passtwoengine_268bffbd -->|method| pass_two_pass_two_engine_passtwoengine_interpers_0b7e007d
    pass_two_pass_two_engine_passtwoengine_268bffbd -->|method| pass_two_pass_two_engine_passtwoengine_log_and_w_8b1ba086
    pass_two_pass_two_engine_passtwoengine_268bffbd -->|method| pass_two_pass_two_engine_passtwoengine_normalize_db6a0c60
    pass_two_pass_two_engine_passtwoengine_annotate_997aef16 -->|calls| pass_two_pass_two_engine_passtwoengine_annotate_6c590c2c
    pass_two_pass_two_engine_passtwoengine_annotate_1ca3b46a -->|calls| pass_two_pass_two_engine_passtwoengine_annotate_00557472
    pass_two_pass_two_engine_passtwoengine_annotate_6c590c2c -->|calls| pass_two_pass_two_engine_passtwoengine_annotated_22970e3e
    pass_two_pass_two_engine_passtwoengine_annotate_6c590c2c -->|calls| pass_two_pass_two_engine_passtwoengine_call_anno_24048e16
    pass_two_pass_two_engine_passtwoengine_annotate_6c590c2c -->|calls| pass_two_pass_two_engine_passtwoengine_default_i_fbc66946
    pass_two_pass_two_engine_passtwoengine_annotate_6c590c2c -->|calls| pass_two_pass_two_engine_passtwoengine_default_t_eb6d181e
    pass_two_pass_two_engine_passtwoengine_annotate_6c590c2c -->|calls| pass_two_pass_two_engine_passtwoengine_format_sy_1ebe5285
    pass_two_pass_two_engine_passtwoengine_annotate_6c590c2c -->|calls| pass_two_pass_two_engine_passtwoengine_interpers_0b7e007d
    %% Omitted for readability: 10 nodes, 9 edges
    class pass_two_pass_two_engine_passtwoengine_268bffbd klass;
    class pass_two_pass_two_engine_passtwoengine_annotate_6c590c2c function;
    class pass_two_pass_two_engine_sflbatchannotator_99ae68a1 klass;
    class pass_two_pass_two_engine_passtwoengine_annotate_00557472 function;
    class pass_two_pass_two_engine_passtwoengine_interpers_0b7e007d function;
    class pass_two_pass_two_engine_passtwoengine_annotate_997aef16 function;
    class pass_two_pass_two_engine_passtwoengine_annotate_1ca3b46a function;
    class pass_two_pass_two_engine_passtwoengine_annotated_22970e3e function;
    class pass_two_pass_two_engine_passtwoengine_call_anno_24048e16 function;
    class pass_two_pass_two_engine_passtwoengine_clamp01_88144aeb function;
    class pass_two_pass_two_engine_passtwoengine_default_b_b8b96196 function;
    class pass_two_pass_two_engine_passtwoengine_default_c_2608e9ff function;
    class pass_two_pass_two_engine_passtwoengine_default_i_fbc66946 function;
    class pass_two_pass_two_engine_passtwoengine_default_t_eb6d181e function;
    class pass_two_pass_two_engine_passtwoengine_dep_seque_1f98b988 function;
    class pass_two_pass_two_engine_passtwoengine_format_sy_1ebe5285 function;
    class pass_two_pass_two_engine_passtwoengine_log_and_w_8b1ba086 function;
    class pass_two_pass_two_engine_passtwoengine_normalize_db6a0c60 function;
    classDef entry fill:#422006,stroke:#fbbf24,color:#fde68a,stroke-width:1px;
    classDef api fill:#450a0a,stroke:#f87171,color:#fee2e2,stroke-width:1px;
    classDef async fill:#2e1065,stroke:#a78bfa,color:#ede9fe,stroke-width:1px;
    classDef klass fill:#064e3b,stroke:#34d399,color:#d1fae5,stroke-width:1px;
    classDef ui fill:#831843,stroke:#f472b6,color:#fce7f3,stroke-width:1px;
    classDef module fill:#172554,stroke:#60a5fa,color:#dbeafe,stroke-width:1px;
    classDef test fill:#3f3f46,stroke:#a1a1aa,color:#f4f4f5,stroke-width:1px;
    classDef concept fill:#292524,stroke:#a8a29e,color:#fafaf9,stroke-dasharray:4 3;
    classDef function fill:#0f172a,stroke:#38bdf8,color:#e0f2fe,stroke-width:1px;
```


## Callflow 9

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"fontSize": "15.0px", "fontFamily": "Segoe UI, system-ui, sans-serif", "primaryColor": "#1e293b", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#38bdf8", "secondaryColor": "#0f172a", "tertiaryColor": "#334155", "lineColor": "#64748b", "textColor": "#e2e8f0"}, "flowchart": {"htmlLabels": true, "curve": "basis", "nodeSpacing": 48, "rankSpacing": 64, "padding": 14, "diagramPadding": 10, "useMaxWidth": true}}}%%
flowchart LR
    %% Section: Conversation Analysis (27 nodes, 37 edges)
    subgraph conversation_analysis_compiler_analysis_narrativ_4453dc56["compiler/analysis/narrative_generator.rb"]
        analysis_narrative_generator_digest_de4de09b("Digest<br/><small>compiler/analysis/narrative_generator.rb</small>")
        analysis_narrative_generator_digest_from_result_25a0b57f("from_result()<br/><small>compiler/analysis/narrative_generator.rb</small>")
        analysis_narrative_generator_narrativegenerator_c8f33c62("generate()<br/><small>compiler/analysis/narrative_generator.rb</small>")
        analysis_narrative_generator_narrativegenerator_faf2d70e("NarrativeGenerator<br/><small>compiler/analysis/narrative_generator.rb</small>")
        analysis_narrative_generator_sflnarrator_2b7404e6("SFLNarrator<br/><small>compiler/analysis/narrative_generator.rb</small>")
        analysis_narrative_generator_narrativegenerator_f8107ada("initialize()<br/><small>compiler/analysis/narrative_generator.rb</small>")
        analysis_narrative_generator_sflnarrator_call_3518a2d2("call()<br/><small>compiler/analysis/narrative_generator.rb</small>")
        analysis_narrative_generator_digest_source_c5591de9("source()<br/><small>compiler/analysis/narrative_generator.rb</small>")
        analysis_narrative_generator_digest_to_text_ec47dea8("to_text()<br/><small>compiler/analysis/narrative_generator.rb</small>")
        analysis_narrative_generator_digest_coverage_c23d0b19("coverage()<br/><small>compiler/analysis/narrative_generator.rb</small>")
        analysis_narrative_generator_digest_deep_stringi_45daccf7("deep_stringify()<br/><small>compiler/analysis/narrative_generator.rb</small>")
        analysis_narrative_generator_digest_initialize_09b676aa("initialize()<br/><small>compiler/analysis/narrative_generator.rb</small>")
        analysis_narrative_generator_digest_profiles_has_41c5ffb4("profiles_hash()<br/><small>compiler/analysis/narrative_generator.rb</small>")
        analysis_narrative_generator_digest_turn_line_d825a90e("turn_line()<br/><small>compiler/analysis/narrative_generator.rb</small>")
        analysis_narrative_generator_sflnarrator_initial_c3df9c83("initialize()<br/><small>compiler/analysis/narrative_generator.rb</small>")
    end
    subgraph conversation_analysis_compiler_formatters_csv_fo_969c9aac["compiler/formatters/csv_formatter.rb"]
        formatters_csv_formatter_csvformatter_3f1012c3("CSVFormatter<br/><small>compiler/formatters/csv_formatter.rb</small>")
        formatters_csv_formatter_csvformatter_format_pro_e1c31950("format_process_counts()<br/><small>compiler/formatters/csv_formatter.rb</small>")
        formatters_csv_formatter_csvformatter_headers_eaec50ca("headers()<br/><small>compiler/formatters/csv_formatter.rb</small>")
    end
    analysis_narrative_generator_narrativegenerator_faf2d70e -->|method| analysis_narrative_generator_narrativegenerator_c8f33c62
    analysis_narrative_generator_narrativegenerator_faf2d70e -->|method| analysis_narrative_generator_narrativegenerator_f8107ada
    analysis_narrative_generator_narrativegenerator_f8107ada -->|calls| analysis_narrative_generator_sflnarrator_call_3518a2d2
    analysis_narrative_generator_narrativegenerator_c8f33c62 -->|calls| analysis_narrative_generator_digest_source_c5591de9
    analysis_narrative_generator_narrativegenerator_c8f33c62 -->|calls| analysis_narrative_generator_digest_to_text_ec47dea8
    analysis_narrative_generator_narrativegenerator_c8f33c62 -->|calls| analysis_narrative_generator_sflnarrator_call_3518a2d2
    analysis_narrative_generator_digest_de4de09b -->|method| analysis_narrative_generator_digest_coverage_c23d0b19
    analysis_narrative_generator_digest_de4de09b -->|method| analysis_narrative_generator_digest_deep_stringi_45daccf7
    analysis_narrative_generator_digest_de4de09b -->|method| analysis_narrative_generator_digest_from_result_25a0b57f
    analysis_narrative_generator_digest_de4de09b -->|method| analysis_narrative_generator_digest_initialize_09b676aa
    analysis_narrative_generator_digest_de4de09b -->|method| analysis_narrative_generator_digest_profiles_has_41c5ffb4
    analysis_narrative_generator_digest_de4de09b -->|method| analysis_narrative_generator_digest_source_c5591de9
    analysis_narrative_generator_digest_de4de09b -->|method| analysis_narrative_generator_digest_to_text_ec47dea8
    analysis_narrative_generator_digest_de4de09b -->|method| analysis_narrative_generator_digest_turn_line_d825a90e
    analysis_narrative_generator_digest_from_result_25a0b57f -->|calls| analysis_narrative_generator_digest_coverage_c23d0b19
    analysis_narrative_generator_digest_from_result_25a0b57f -->|calls| analysis_narrative_generator_digest_deep_stringi_45daccf7
    analysis_narrative_generator_digest_from_result_25a0b57f -->|calls| analysis_narrative_generator_digest_profiles_has_41c5ffb4
    analysis_narrative_generator_digest_to_text_ec47dea8 -->|calls| analysis_narrative_generator_digest_turn_line_d825a90e
    analysis_narrative_generator_sflnarrator_2b7404e6 -->|method| analysis_narrative_generator_sflnarrator_call_3518a2d2
    analysis_narrative_generator_sflnarrator_2b7404e6 -->|method| analysis_narrative_generator_sflnarrator_initial_c3df9c83
    formatters_csv_formatter_csvformatter_3f1012c3 -->|method| formatters_csv_formatter_csvformatter_format_pro_e1c31950
    formatters_csv_formatter_csvformatter_3f1012c3 -->|method| formatters_csv_formatter_csvformatter_headers_eaec50ca
    %% Omitted for readability: 9 nodes, 0 edges
    class analysis_narrative_generator_digest_de4de09b klass;
    class analysis_narrative_generator_digest_from_result_25a0b57f function;
    class analysis_narrative_generator_narrativegenerator_c8f33c62 function;
    class analysis_narrative_generator_narrativegenerator_faf2d70e klass;
    class analysis_narrative_generator_sflnarrator_2b7404e6 klass;
    class analysis_narrative_generator_narrativegenerator_f8107ada function;
    class analysis_narrative_generator_sflnarrator_call_3518a2d2 function;
    class analysis_narrative_generator_digest_source_c5591de9 function;
    class analysis_narrative_generator_digest_to_text_ec47dea8 function;
    class analysis_narrative_generator_digest_coverage_c23d0b19 function;
    class analysis_narrative_generator_digest_deep_stringi_45daccf7 function;
    class analysis_narrative_generator_digest_initialize_09b676aa function;
    class analysis_narrative_generator_digest_profiles_has_41c5ffb4 function;
    class analysis_narrative_generator_digest_turn_line_d825a90e function;
    class analysis_narrative_generator_sflnarrator_initial_c3df9c83 function;
    class formatters_csv_formatter_csvformatter_3f1012c3 klass;
    class formatters_csv_formatter_csvformatter_format_pro_e1c31950 function;
    class formatters_csv_formatter_csvformatter_headers_eaec50ca function;
    classDef entry fill:#422006,stroke:#fbbf24,color:#fde68a,stroke-width:1px;
    classDef api fill:#450a0a,stroke:#f87171,color:#fee2e2,stroke-width:1px;
    classDef async fill:#2e1065,stroke:#a78bfa,color:#ede9fe,stroke-width:1px;
    classDef klass fill:#064e3b,stroke:#34d399,color:#d1fae5,stroke-width:1px;
    classDef ui fill:#831843,stroke:#f472b6,color:#fce7f3,stroke-width:1px;
    classDef module fill:#172554,stroke:#60a5fa,color:#dbeafe,stroke-width:1px;
    classDef test fill:#3f3f46,stroke:#a1a1aa,color:#f4f4f5,stroke-width:1px;
    classDef concept fill:#292524,stroke:#a8a29e,color:#fafaf9,stroke-dasharray:4 3;
    classDef function fill:#0f172a,stroke:#38bdf8,color:#e0f2fe,stroke-width:1px;
```


## Callflow 10

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"fontSize": "15.0px", "fontFamily": "Segoe UI, system-ui, sans-serif", "primaryColor": "#1e293b", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#38bdf8", "secondaryColor": "#0f172a", "tertiaryColor": "#334155", "lineColor": "#64748b", "textColor": "#e2e8f0"}, "flowchart": {"htmlLabels": true, "curve": "basis", "nodeSpacing": 48, "rankSpacing": 64, "padding": 14, "diagramPadding": 10, "useMaxWidth": true}}}%%
flowchart LR
    %% Section: Hybrid Retriever (18 nodes, 17 edges)
    compiler_types_0103137e("types.rb")
    compiler_types_analysisresult_7beff7c2("AnalysisResult<br/><small>sfl/compiler/types.rb</small>")
    compiler_types_annotatedclause_ffd3d9b3("AnnotatedClause<br/><small>sfl/compiler/types.rb</small>")
    compiler_types_cohesionmetrics_bf728e18("CohesionMetrics<br/><small>sfl/compiler/types.rb</small>")
    compiler_types_conversationturn_3fe64342("ConversationTurn<br/><small>sfl/compiler/types.rb</small>")
    compiler_types_dispatchdecision_5fa64a85("DispatchDecision<br/><small>sfl/compiler/types.rb</small>")
    compiler_types_examplepassage_1bda8070("ExamplePassage<br/><small>sfl/compiler/types.rb</small>")
    compiler_types_ideationalpayload_fdfaf973("IdeationalPayload<br/><small>sfl/compiler/types.rb</small>")
    compiler_types_interpersonalpayload_09352c53("InterpersonalPayload<br/><small>sfl/compiler/types.rb</small>")
    compiler_types_keymoment_0c86f98e("KeyMoment<br/><small>sfl/compiler/types.rb</small>")
    compiler_types_narrativereport_b9e8b3f0("NarrativeReport<br/><small>sfl/compiler/types.rb</small>")
    compiler_types_participant_f44bd4e8("Participant<br/><small>sfl/compiler/types.rb</small>")
    compiler_types_speakerprofile_ec550106("SpeakerProfile<br/><small>sfl/compiler/types.rb</small>")
    compiler_types_syntacticclause_db1f85c9("SyntacticClause<br/><small>sfl/compiler/types.rb</small>")
    compiler_types_syntactictoken_a2705bcd("SyntacticToken<br/><small>sfl/compiler/types.rb</small>")
    compiler_types_synthesisresult_d025be6a("SynthesisResult<br/><small>sfl/compiler/types.rb</small>")
    compiler_types_taskresult_a1ef7e9f("TaskResult<br/><small>sfl/compiler/types.rb</small>")
    compiler_types_textualpayload_5d74bbc5("TextualPayload<br/><small>sfl/compiler/types.rb</small>")
    compiler_types_0103137e -->|contains| compiler_types_analysisresult_7beff7c2
    compiler_types_0103137e -->|contains| compiler_types_annotatedclause_ffd3d9b3
    compiler_types_0103137e -->|contains| compiler_types_cohesionmetrics_bf728e18
    compiler_types_0103137e -->|contains| compiler_types_conversationturn_3fe64342
    compiler_types_0103137e -->|contains| compiler_types_dispatchdecision_5fa64a85
    compiler_types_0103137e -->|contains| compiler_types_examplepassage_1bda8070
    compiler_types_0103137e -->|contains| compiler_types_ideationalpayload_fdfaf973
    compiler_types_0103137e -->|contains| compiler_types_interpersonalpayload_09352c53
    compiler_types_0103137e -->|contains| compiler_types_keymoment_0c86f98e
    compiler_types_0103137e -->|contains| compiler_types_narrativereport_b9e8b3f0
    compiler_types_0103137e -->|contains| compiler_types_participant_f44bd4e8
    compiler_types_0103137e -->|contains| compiler_types_speakerprofile_ec550106
    compiler_types_0103137e -->|contains| compiler_types_syntacticclause_db1f85c9
    compiler_types_0103137e -->|contains| compiler_types_syntactictoken_a2705bcd
    compiler_types_0103137e -->|contains| compiler_types_synthesisresult_d025be6a
    compiler_types_0103137e -->|contains| compiler_types_taskresult_a1ef7e9f
    compiler_types_0103137e -->|contains| compiler_types_textualpayload_5d74bbc5
    class compiler_types_0103137e module;
    class compiler_types_analysisresult_7beff7c2 klass;
    class compiler_types_annotatedclause_ffd3d9b3 klass;
    class compiler_types_cohesionmetrics_bf728e18 klass;
    class compiler_types_conversationturn_3fe64342 klass;
    class compiler_types_dispatchdecision_5fa64a85 klass;
    class compiler_types_examplepassage_1bda8070 klass;
    class compiler_types_ideationalpayload_fdfaf973 klass;
    class compiler_types_interpersonalpayload_09352c53 klass;
    class compiler_types_keymoment_0c86f98e klass;
    class compiler_types_narrativereport_b9e8b3f0 klass;
    class compiler_types_participant_f44bd4e8 klass;
    class compiler_types_speakerprofile_ec550106 klass;
    class compiler_types_syntacticclause_db1f85c9 klass;
    class compiler_types_syntactictoken_a2705bcd klass;
    class compiler_types_synthesisresult_d025be6a klass;
    class compiler_types_taskresult_a1ef7e9f klass;
    class compiler_types_textualpayload_5d74bbc5 klass;
    classDef entry fill:#422006,stroke:#fbbf24,color:#fde68a,stroke-width:1px;
    classDef api fill:#450a0a,stroke:#f87171,color:#fee2e2,stroke-width:1px;
    classDef async fill:#2e1065,stroke:#a78bfa,color:#ede9fe,stroke-width:1px;
    classDef klass fill:#064e3b,stroke:#34d399,color:#d1fae5,stroke-width:1px;
    classDef ui fill:#831843,stroke:#f472b6,color:#fce7f3,stroke-width:1px;
    classDef module fill:#172554,stroke:#60a5fa,color:#dbeafe,stroke-width:1px;
    classDef test fill:#3f3f46,stroke:#a1a1aa,color:#f4f4f5,stroke-width:1px;
    classDef concept fill:#292524,stroke:#a8a29e,color:#fafaf9,stroke-dasharray:4 3;
    classDef function fill:#0f172a,stroke:#38bdf8,color:#e0f2fe,stroke-width:1px;
```


## Callflow 11

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"fontSize": "15.0px", "fontFamily": "Segoe UI, system-ui, sans-serif", "primaryColor": "#1e293b", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#38bdf8", "secondaryColor": "#0f172a", "tertiaryColor": "#334155", "lineColor": "#64748b", "textColor": "#e2e8f0"}, "flowchart": {"htmlLabels": true, "curve": "basis", "nodeSpacing": 48, "rankSpacing": 64, "padding": 14, "diagramPadding": 10, "useMaxWidth": true}}}%%
flowchart LR
    %% Section: Database & Migrations (8 nodes, 13 edges)
    scripts_scrub_incidents_apply_entity_mapping_f8fb1efd("apply_entity_mapping()<br/><small>scripts/scrub_incidents.rb</small>")
    scripts_scrub_incidents_build_entity_mapping_b17a3cec("build_entity_mapping()<br/><small>scripts/scrub_incidents.rb</small>")
    scripts_scrub_incidents_extract_text_23940f12("extract_text()<br/><small>scripts/scrub_incidents.rb</small>")
    scripts_scrub_incidents_scrub_known_terms_4f3cb32f("scrub_known_terms()<br/><small>scripts/scrub_incidents.rb</small>")
    scripts_scrub_incidents_scrub_structured_pii_2c510e14("scrub_structured_pii()<br/><small>scripts/scrub_incidents.rb</small>")
    scripts_scrub_incidents_main_845d37d9("main()<br/><small>scripts/scrub_incidents.rb</small>")
    scripts_scrub_incidents_scrub_text_d4ba3010("scrub_text()<br/><small>scripts/scrub_incidents.rb</small>")
    scripts_scrub_incidents_1ccb66f6("scrub_incidents.rb")
    scripts_scrub_incidents_extract_text_23940f12 -->|calls| scripts_scrub_incidents_main_845d37d9
    scripts_scrub_incidents_build_entity_mapping_b17a3cec -->|calls| scripts_scrub_incidents_main_845d37d9
    scripts_scrub_incidents_apply_entity_mapping_f8fb1efd -->|calls| scripts_scrub_incidents_scrub_text_d4ba3010
    scripts_scrub_incidents_scrub_structured_pii_2c510e14 -->|calls| scripts_scrub_incidents_scrub_text_d4ba3010
    scripts_scrub_incidents_scrub_known_terms_4f3cb32f -->|calls| scripts_scrub_incidents_main_845d37d9
    scripts_scrub_incidents_scrub_text_d4ba3010 -->|calls| scripts_scrub_incidents_main_845d37d9
    class scripts_scrub_incidents_apply_entity_mapping_f8fb1efd function;
    class scripts_scrub_incidents_build_entity_mapping_b17a3cec function;
    class scripts_scrub_incidents_extract_text_23940f12 function;
    class scripts_scrub_incidents_scrub_known_terms_4f3cb32f function;
    class scripts_scrub_incidents_scrub_structured_pii_2c510e14 function;
    class scripts_scrub_incidents_main_845d37d9 function;
    class scripts_scrub_incidents_scrub_text_d4ba3010 function;
    class scripts_scrub_incidents_1ccb66f6 module;
    classDef entry fill:#422006,stroke:#fbbf24,color:#fde68a,stroke-width:1px;
    classDef api fill:#450a0a,stroke:#f87171,color:#fee2e2,stroke-width:1px;
    classDef async fill:#2e1065,stroke:#a78bfa,color:#ede9fe,stroke-width:1px;
    classDef klass fill:#064e3b,stroke:#34d399,color:#d1fae5,stroke-width:1px;
    classDef ui fill:#831843,stroke:#f472b6,color:#fce7f3,stroke-width:1px;
    classDef module fill:#172554,stroke:#60a5fa,color:#dbeafe,stroke-width:1px;
    classDef test fill:#3f3f46,stroke:#a1a1aa,color:#f4f4f5,stroke-width:1px;
    classDef concept fill:#292524,stroke:#a8a29e,color:#fafaf9,stroke-dasharray:4 3;
    classDef function fill:#0f172a,stroke:#38bdf8,color:#e0f2fe,stroke-width:1px;
```


## Callflow 12

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"fontSize": "15.0px", "fontFamily": "Segoe UI, system-ui, sans-serif", "primaryColor": "#1e293b", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#38bdf8", "secondaryColor": "#0f172a", "tertiaryColor": "#334155", "lineColor": "#64748b", "textColor": "#e2e8f0"}, "flowchart": {"htmlLabels": true, "curve": "basis", "nodeSpacing": 48, "rankSpacing": 64, "padding": 14, "diagramPadding": 10, "useMaxWidth": true}}}%%
flowchart LR
    %% Section: Markdown Loader (6 nodes, 5 edges)
    experiments_01_fca_proof_of_concept_simplefca_92ccc686("SimpleFCA<br/><small>experiments/01_fca_proof_of_concept.rb</small>")
    experiments_01_fca_proof_of_concept_simplefca_fi_91c2f2d2("find_concepts()<br/><small>experiments/01_fca_proof_of_concept.rb</small>")
    experiments_01_fca_proof_of_concept_simplefca_fi_51459eb9("find_implications()<br/><small>experiments/01_fca_proof_of_concept.rb</small>")
    experiments_01_fca_proof_of_concept_simplefca_in_af3fe7af("initialize()<br/><small>experiments/01_fca_proof_of_concept.rb</small>")
    experiments_01_fca_proof_of_concept_7c5e32ba("01_fca_proof_of_concept.rb")
    experiments_01_fca_proof_of_concept_extract_attr_19379f6b("extract_attributes()<br/><small>experiments/01_fca_proof_of_concept.rb</small>")
    experiments_01_fca_proof_of_concept_simplefca_92ccc686 -->|method| experiments_01_fca_proof_of_concept_simplefca_fi_91c2f2d2
    experiments_01_fca_proof_of_concept_simplefca_92ccc686 -->|method| experiments_01_fca_proof_of_concept_simplefca_fi_51459eb9
    experiments_01_fca_proof_of_concept_simplefca_92ccc686 -->|method| experiments_01_fca_proof_of_concept_simplefca_in_af3fe7af
    class experiments_01_fca_proof_of_concept_simplefca_92ccc686 klass;
    class experiments_01_fca_proof_of_concept_simplefca_fi_91c2f2d2 function;
    class experiments_01_fca_proof_of_concept_simplefca_fi_51459eb9 function;
    class experiments_01_fca_proof_of_concept_simplefca_in_af3fe7af function;
    class experiments_01_fca_proof_of_concept_7c5e32ba module;
    class experiments_01_fca_proof_of_concept_extract_attr_19379f6b function;
    classDef entry fill:#422006,stroke:#fbbf24,color:#fde68a,stroke-width:1px;
    classDef api fill:#450a0a,stroke:#f87171,color:#fee2e2,stroke-width:1px;
    classDef async fill:#2e1065,stroke:#a78bfa,color:#ede9fe,stroke-width:1px;
    classDef klass fill:#064e3b,stroke:#34d399,color:#d1fae5,stroke-width:1px;
    classDef ui fill:#831843,stroke:#f472b6,color:#fce7f3,stroke-width:1px;
    classDef module fill:#172554,stroke:#60a5fa,color:#dbeafe,stroke-width:1px;
    classDef test fill:#3f3f46,stroke:#a1a1aa,color:#f4f4f5,stroke-width:1px;
    classDef concept fill:#292524,stroke:#a8a29e,color:#fafaf9,stroke-dasharray:4 3;
    classDef function fill:#0f172a,stroke:#38bdf8,color:#e0f2fe,stroke-width:1px;
```


## Callflow 13

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"fontSize": "15.0px", "fontFamily": "Segoe UI, system-ui, sans-serif", "primaryColor": "#1e293b", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#38bdf8", "secondaryColor": "#0f172a", "tertiaryColor": "#334155", "lineColor": "#64748b", "textColor": "#e2e8f0"}, "flowchart": {"htmlLabels": true, "curve": "basis", "nodeSpacing": 48, "rankSpacing": 64, "padding": 14, "diagramPadding": 10, "useMaxWidth": true}}}%%
flowchart LR
    %% Section: Speaker Profiler (4 nodes, 3 edges)
    chat_menu_menu_46f79af4("Menu<br/><small>compiler/chat/menu.rb</small>")
    chat_menu_menu_initialize_e6293780("initialize()<br/><small>compiler/chat/menu.rb</small>")
    chat_menu_menu_run_912643f3("run()<br/><small>compiler/chat/menu.rb</small>")
    chat_menu_268fcb71("menu.rb")
    chat_menu_menu_46f79af4 -->|method| chat_menu_menu_initialize_e6293780
    chat_menu_menu_46f79af4 -->|method| chat_menu_menu_run_912643f3
    class chat_menu_menu_46f79af4 klass;
    class chat_menu_menu_initialize_e6293780 function;
    class chat_menu_menu_run_912643f3 function;
    class chat_menu_268fcb71 module;
    classDef entry fill:#422006,stroke:#fbbf24,color:#fde68a,stroke-width:1px;
    classDef api fill:#450a0a,stroke:#f87171,color:#fee2e2,stroke-width:1px;
    classDef async fill:#2e1065,stroke:#a78bfa,color:#ede9fe,stroke-width:1px;
    classDef klass fill:#064e3b,stroke:#34d399,color:#d1fae5,stroke-width:1px;
    classDef ui fill:#831843,stroke:#f472b6,color:#fce7f3,stroke-width:1px;
    classDef module fill:#172554,stroke:#60a5fa,color:#dbeafe,stroke-width:1px;
    classDef test fill:#3f3f46,stroke:#a1a1aa,color:#f4f4f5,stroke-width:1px;
    classDef concept fill:#292524,stroke:#a8a29e,color:#fafaf9,stroke-dasharray:4 3;
    classDef function fill:#0f172a,stroke:#38bdf8,color:#e0f2fe,stroke-width:1px;
```


## Callflow 14

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"fontSize": "15.0px", "fontFamily": "Segoe UI, system-ui, sans-serif", "primaryColor": "#1e293b", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#38bdf8", "secondaryColor": "#0f172a", "tertiaryColor": "#334155", "lineColor": "#64748b", "textColor": "#e2e8f0"}, "flowchart": {"htmlLabels": true, "curve": "basis", "nodeSpacing": 48, "rankSpacing": 64, "padding": 14, "diagramPadding": 10, "useMaxWidth": true}}}%%
flowchart LR
    %% Section: Cohesion Analysis (3 nodes, 2 edges)
    scripts_parse_metacognitive_coprocessor_665feac7("parse_metacognitive_coprocessor.rb")
    scripts_parse_metacognitive_coprocessor_log_4b3307f5("log()<br/><small>scripts/parse_metacognitive_coprocessor.rb</small>")
    scripts_parse_metacognitive_coprocessor_separato_39b10a7d("separator()<br/><small>scripts/parse_metacognitive_coprocessor.rb</small>")
    scripts_parse_metacognitive_coprocessor_665feac7 -->|contains| scripts_parse_metacognitive_coprocessor_log_4b3307f5
    scripts_parse_metacognitive_coprocessor_665feac7 -->|contains| scripts_parse_metacognitive_coprocessor_separato_39b10a7d
    class scripts_parse_metacognitive_coprocessor_665feac7 module;
    class scripts_parse_metacognitive_coprocessor_log_4b3307f5 function;
    class scripts_parse_metacognitive_coprocessor_separato_39b10a7d function;
    classDef entry fill:#422006,stroke:#fbbf24,color:#fde68a,stroke-width:1px;
    classDef api fill:#450a0a,stroke:#f87171,color:#fee2e2,stroke-width:1px;
    classDef async fill:#2e1065,stroke:#a78bfa,color:#ede9fe,stroke-width:1px;
    classDef klass fill:#064e3b,stroke:#34d399,color:#d1fae5,stroke-width:1px;
    classDef ui fill:#831843,stroke:#f472b6,color:#fce7f3,stroke-width:1px;
    classDef module fill:#172554,stroke:#60a5fa,color:#dbeafe,stroke-width:1px;
    classDef test fill:#3f3f46,stroke:#a1a1aa,color:#f4f4f5,stroke-width:1px;
    classDef concept fill:#292524,stroke:#a8a29e,color:#fafaf9,stroke-dasharray:4 3;
    classDef function fill:#0f172a,stroke:#38bdf8,color:#e0f2fe,stroke-width:1px;
```


## Callflow 15

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"fontSize": "15.0px", "fontFamily": "Segoe UI, system-ui, sans-serif", "primaryColor": "#1e293b", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#38bdf8", "secondaryColor": "#0f172a", "tertiaryColor": "#334155", "lineColor": "#64748b", "textColor": "#e2e8f0"}, "flowchart": {"htmlLabels": true, "curve": "basis", "nodeSpacing": 48, "rankSpacing": 64, "padding": 14, "diagramPadding": 10, "useMaxWidth": true}}}%%
flowchart LR
    %% Section: Other (9 nodes, 2 edges)
    subgraph other_experiments_02_id3_feature_importance_rb_dd68e326["experiments/02_id3_feature_importance.rb"]
        experiments_02_id3_feature_importance_5024f2d6("02_id3_feature_importance.rb")
        experiments_02_id3_feature_importance_extract_fe_7d76e0e5("extract_features()<br/><small>experiments/02_id3_feature_importance.rb</small>")
    end
    subgraph other_scripts_process_incidents_rb_65e61696["scripts/process_incidents.rb"]
        scripts_process_incidents_f749399e("process_incidents.rb")
        scripts_process_incidents_compile_pass_one_only_11a722d6("compile_pass_one_only()<br/><small>scripts/process_incidents.rb</small>")
    end
    chat_styles_a129d0fa("styles.rb")
    compiler_analysis_8f972526("analysis.rb")
    compiler_chat_cc273e26("chat.rb")
    compiler_formatters_a381510d("formatters.rb")
    compiler_version_39975b2e("version.rb")
    experiments_02_id3_feature_importance_5024f2d6 -->|contains| experiments_02_id3_feature_importance_extract_fe_7d76e0e5
    scripts_process_incidents_f749399e -->|contains| scripts_process_incidents_compile_pass_one_only_11a722d6
    class experiments_02_id3_feature_importance_5024f2d6 module;
    class experiments_02_id3_feature_importance_extract_fe_7d76e0e5 function;
    class scripts_process_incidents_f749399e module;
    class scripts_process_incidents_compile_pass_one_only_11a722d6 function;
    class chat_styles_a129d0fa module;
    class compiler_analysis_8f972526 module;
    class compiler_chat_cc273e26 module;
    class compiler_formatters_a381510d module;
    class compiler_version_39975b2e module;
    classDef entry fill:#422006,stroke:#fbbf24,color:#fde68a,stroke-width:1px;
    classDef api fill:#450a0a,stroke:#f87171,color:#fee2e2,stroke-width:1px;
    classDef async fill:#2e1065,stroke:#a78bfa,color:#ede9fe,stroke-width:1px;
    classDef klass fill:#064e3b,stroke:#34d399,color:#d1fae5,stroke-width:1px;
    classDef ui fill:#831843,stroke:#f472b6,color:#fce7f3,stroke-width:1px;
    classDef module fill:#172554,stroke:#60a5fa,color:#dbeafe,stroke-width:1px;
    classDef test fill:#3f3f46,stroke:#a1a1aa,color:#f4f4f5,stroke-width:1px;
    classDef concept fill:#292524,stroke:#a8a29e,color:#fafaf9,stroke-dasharray:4 3;
    classDef function fill:#0f172a,stroke:#38bdf8,color:#e0f2fe,stroke-width:1px;
```
