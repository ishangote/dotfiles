# OPINIONS.md

This file is a compact map of Ishan Gote's durable engineering viewpoints - the beliefs stable enough to matter, distilled away from jokes, one-off reactions, and implementation detail. It is optimized for readability and conciseness, so it consolidates repeated signals.

The section structure is not fixed. It should periodically reorganize into the clearest shape as opinions accumulate, rather than growing by appending forever.

## AI agents, orchestration, and developer tools

### Agents should be judged by useful work, not demos

Ishan judges coding agents by whether they complete valuable work in messy real codebases, not by toy demos or impressive screenshots.
He prefers agents that gather evidence with search, grep, tests, and tools instead of relying on unsupported reasoning.
He accepts slower and more tool-heavy agents when they produce more trustworthy results, because wrong answers and rework cost more than latency.
He sees hallucination as an engineering and incentive problem that can be reduced by training models to admit uncertainty and by surrounding them with verification.

### Agentic engineering changes the work rather than eliminating engineering

Ishan thinks AI is shifting software work from hand-writing code toward steering, specification, review, orchestration, system design, and product judgment.
He expects engineers to learn agentic engineering while still understanding fundamentals well enough to control and evaluate what agents produce.
He believes AI amplifies competence and judgment, which means weak taste and weak requirements can produce more slop faster.
He expects people who keep learning and building with AI to gain leverage, while people who refuse to explore the ceiling face the highest career risk.

### Requirements, tests, and review are the new bottlenecks

Ishan believes code has rarely been the deepest bottleneck in software work.
The harder questions are what is worth building, what users actually need, and how to verify that the result works.
He sees tests as central to AI coding because tests encode intent and give agents a feedback loop.
He favors TDD with agents when requirements are clear, because LLMs write better tests from intent than from the implementation they just generated.
He thinks humans should review generated tests especially carefully because bad tests can bless the wrong behavior.

### Human accountability must remain explicit

Ishan treats AI as a tool, not a teammate or co-author.
Humans remain accountable for AI-assisted changes because they choose the goals, approve the outputs, and own the consequences.
He dislikes agents auto-adding themselves as commit co-authors because it serves vendor branding more than user trust.
He would rather source control record useful AI-assistance metadata such as model, prompt, token usage, session context, and human approval.

### Good agent systems need orchestration, isolation, and fresh context

Ishan thinks effective agent work requires moving from micromanaging steps to directing agents through goals, principles, measurable objectives, and review loops.
He prefers deterministic harnesses for repeated long-running loops instead of asking one context window to remember everything.
He believes agents should use fresh context windows, isolated worktrees, explicit review phases, and fix phases to reduce context rot.
He sees overnight agents as useful for measurable optimization tasks where progress can be verified and failed attempts can be discarded.

### Agent-facing interfaces deserve first-class design

Ishan believes tools for agents should be designed as deliberately as human UIs.
Agent interfaces should optimize token efficiency, speed, composability, compact output, reliability, and easy chaining.
He is skeptical that generic MCP surfaces or human-oriented JSON APIs are always the best interface for agents.
He sees purpose-built agent CLIs and AXI-style tools as promising because shells, pipes, and concise commands give agents efficient building blocks.
He worries that broad auto-enabled tool search can save upfront tokens while adding extra turns, search failures, and lower success rates.

### Model choice should follow task shape, not fandom

Ishan is pragmatic about models and harnesses.
He sees Claude as pleasant for interactive work, while GPT or Codex can be better for non-interactive background execution, bug finding, and skill invocation.
He thinks Claude Code's popularity reflects model quality, subsidies, and lock-in more than harness quality alone.
He believes higher reasoning effort can reduce total cost on complex tasks when it avoids bad answers, correction turns, and rework.
He is wary of very large context windows and automatic memory when they add stale information, bloated context, or inefficient processes.

## Software engineering, craft, and process

### Great engineers create valuable outcomes

Ishan defines great engineers by their ability to get valuable things built.
That requires technical depth, breadth, strategy, leadership, delivery, communication, and political skill when problems have organizational constraints.
He sees compensation as an imperfect but sometimes useful market signal of created value, not as a pure measure of greatness.
He believes senior individual contributors create leverage through technical direction, ambiguous decisions, stakeholder alignment, process repair, and helping other teams succeed.

### Code quality decays without active stewardship

Ishan thinks codebases naturally drift toward entropy unless senior engineers actively hold the quality bar.
He prefers review cultures that require authors to explain how changes were tested rather than making reviewers personally rediscover every bug.
He believes solo ownership can burn people out and reduce quality when collaboration, shared context, and contributor growth would be better.
He wants principal engineers to remove processes where small changes require excessive meetings and approvals.

### Pull requests will evolve under agentic workflows

Ishan expects pull requests to become less central as work shifts from human-written code reviewed by another human to agent-written code steered and reviewed by the human author.
He still sees PRs as useful for CI gates, release automation, metadata, and team coordination.
He does not think humans must read every line of agent-written code if they provide strong requirements, require tests and evidence, and review summaries, risks, and targeted diffs.
He believes CI remains hard to replace because local validation cannot cover every platform and environment.

### Tools should make good choices easy

Ishan values ergonomics because a sound architecture that is hard to use correctly still produces performance and maintainability problems.
He likes opinionated defaults when they can be centrally optimized, while preserving customization for advanced users.
He prefers terminal-centered workflows with grep, fzf, Neovim-style editing, and low visual clutter, while recognizing configuration can become a time sink.
He values reproducible environments, demos, and personal infrastructure because they turn fragile manual memory into repeatable systems.
He prefers clear ownership boundaries between tools over ideological purity about forcing everything through one layer.
He thinks frameworks and abstractions should earn their complexity by matching the actual problem shape.
He believes terminal and developer tools deserve visual craft, pacing, and polish when those details improve comprehension without stealing attention from the user's real task.
