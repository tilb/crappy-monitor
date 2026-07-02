# Crappy Monitor

Crappy Monitor is a preset-driven visual degradation tool: it renders your app the way it actually looks on bad monitors (low DPI, washed-out panels, wrong gamma). The landing page lives in `docs/` and GitHub Pages serves it from the `/docs` folder on `main` — pushing to `main` is what publishes the site (custom domain: crappymonitor.ernestmistiaen.com).

## Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. When in doubt, invoke the skill.

Key routing rules:
- Product ideas/brainstorming → invoke /office-hours
- Strategy/scope → invoke /plan-ceo-review
- Architecture → invoke /plan-eng-review
- Design system/plan review → invoke /design-consultation or /plan-design-review
- Full review pipeline → invoke /autoplan
- Bugs/errors → invoke /investigate
- QA/testing site behavior → invoke /qa or /qa-only
- Code review/diff check → invoke /review
- Visual polish → invoke /design-review
- Ship/deploy/PR → invoke /ship or /land-and-deploy
- Save progress → invoke /context-save
- Resume context → invoke /context-restore
- Author a backlog-ready spec/issue → invoke /spec
