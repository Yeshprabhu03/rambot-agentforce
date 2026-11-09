# Demo: RamBot on Agentforce (3 minutes)

Built in the new Agentforce Builder (Version 2, committed). Subagents: Agent Router, Program Information, Escalation, Off Topic, Ambiguous Question, Application Status, Advising Appointments.

**Use for:** Tarang (10 Nov), "What have you built with Agentforce?", and as the base for the discovery/demo panels at all three Salesforce teams.

## The story (frame it as a customer, not a school project)

**Customer:** Gabelli graduate admissions. A small team answering the same questions all year: program details, "where's my application?", "can I talk to an advisor?"
**Pain:** [ADD a number if you have it: e.g., inbox volume, response time.] Questions spike around deadlines; staff spend time on repeat questions instead of advising.
**Goal:** Answer the repeat questions instantly, take simple actions, and hand off to a person when it matters.

## Script

| Time | Say | Show |
|---|---|---|
| 0:00–0:30 | The customer, their pain, what success looks like. | Nothing yet. Just talk. |
| 0:30–1:00 | "Here's how I designed it: a router sends each question to a focused subagent, and anything off topic or unclear gets handled safely." | Explorer panel: the subagent list. |
| 1:00–1:40 | Program question. | Live Test: ask about a specific program. Open the trace: router → Program Information. |
| 1:40–2:10 | Action. | Ask application status (or book an advising appointment). Show what it pulls or does. |
| 2:10–2:30 | Guardrails. | Ask something off topic or vague. Show Off Topic / Ambiguous Question handling, then ask for a human → Escalation. |
| 2:30–3:00 | Value + testing. | "I tested 25–30 scenarios in Testing Center before trusting it." Close: what this saves the team, and what you'd ask in discovery to size it with their numbers. |

## Before you demo
- [CHECK] What do **Application Status** and **Advising Appointments** actually do? Read real records or a Flow, or just answer from instructions? If they take a real action, lead with that; it's the strongest part. If not, say honestly "next I'd wire this to a Flow."
- **"What can you do?" routes to Off Topic** (trace shows Off Topic / SMALL_TALK). It answers well, but a sharp viewer may notice. Consider a small "Greeting / Capabilities" path, or just don't open the trace for that question.
- The version shows **Activate**. Preview works without activating, but activate it if you want to show it in a deployed channel.
- Pre-write your demo questions in a note so you don't make typos live.
- Close other browser tabs (password reset, job boards) before screen-sharing.
- For SMB framing, add one line at the end: "The same pattern fits a 50-person company's service inbox: order status instead of application status."
