# Herald Options

```yaml
perplexity_model: sonar-pro
research_time_window_hours: 24
source_count_target: 8
max_check_iterations: 3
voice_check_failure_behavior: send-for-revision
rules_check_failure_behavior: send-for-revision
output_destination: ./drafts/
output_filename_pattern: "{YYYY-MM-DD}-{slug}.md"
domain: kratomnewstoday.com
cadence_hint: daily
post_run_behavior: report-only
embedding_model: text-embedding-3-small
content_directory: ./content/briefings/
index_location: ./.herald/index.db
retrieval_count: 8
retrieval_similarity_threshold: 0.7
index_drafts: false
compliance_check_enabled: true
compliance_check_failure_behavior: halt-and-report
```

## Notes

**On Perplexity model choice:** This project uses `sonar-pro` rather than the default `sonar`. Kratom industry coverage benefits from the deeper synthesis sonar-pro provides — the regulatory landscape is complex enough that the cheaper model produces shallower findings. The cost difference is modest at one briefing per day; the quality difference is meaningful.

**On voice and rules check failure behavior:** Both are set to `send-for-revision`. This project auto-publishes, so we want the synthesis agent to revise its own work on voice and rules issues rather than halting. Compliance check is the safety net that halts when something serious slips through.

**On compliance check:** Enabled with `halt-and-report` because this project covers medical claims and legal advice territory daily. Compliance violations stop the pipeline. A human reviews before publish. Delayed publishes are acceptable; missed compliance violations are not.

**On content directory:** Set to `./content/briefings/` rather than the default `./content/` because Eleventy will have multiple content types eventually (briefings now, opinion pieces later, possibly tracker entries) and keeping briefings in their own subdirectory makes the collection structure clean from day one.

**On cadence:** Daily, scheduled run on the Openclaw machine. The publication launches with 30 days of backdated briefings produced via batch mode, then transitions to daily live operation.

**On domain:** kratomnewstoday.com. Used in frontmatter for canonical URLs, in schema markup, in sitemaps, and in RSS feed metadata.

**On post-run behavior:** `report-only` for now. When the full publishing workflow is wired up, this may change to `trigger-downstream` to automatically invoke the publishing agent that moves the draft into ./content/briefings/, runs the Eleventy build via git commit, and triggers the deploy. Decide closer to launch.
