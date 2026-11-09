# RamBot: Agentforce admissions agent (demo)

RamBot is a portfolio demo of an Agentforce Service Agent for Fordham Gabelli School of Business graduate admissions. It is not an official Fordham project.

It can match a prospect to a program, estimate costs, find faculty, list and register for info sessions, check application status, capture leads, answer questions from a knowledge library, and hand off to a human advisor over Messaging for In-App and Web.

## Layout

- `rambot-sfdx/`: the SFDX project (API 65). The agent script is `force-app/main/default/aiAuthoringBundles/RamBot/RamBot.agent`. Also holds Apex actions, objects, permission sets, Messaging and site config, reports and the dashboard, test specs and test results.
- `rambot-apex/`: working copies of the Apex classes and archived agent script versions.
- `rambot-data/`: program catalog, knowledge articles, and the functional and security test suites (CSV).
- `rambot_progress_log.md`: build log.
- `rambot_new_org_plan.md`: plan for moving to a fresh Developer Edition org.
- `demo_rambot_agentforce.md`: demo run sheet.

## Deploy

```bash
cd rambot-sfdx
sf project deploy start --manifest manifest/package.xml -o <org-alias>
sf agent publish authoring-bundle --api-name RamBot -o <org-alias>
```

Before deploying, replace `YOUR_ADMIN_USERNAME` (site, queue, presence config, dashboard) with your org's admin username, and set the email in `rambot-sfdx/config/agent-user.json`.
