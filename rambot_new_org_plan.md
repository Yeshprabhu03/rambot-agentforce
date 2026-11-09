# RamBot: move to a new Developer Edition org

**Why move:** the current org (orgfarm-b83b4684f8-dev-ed) is at 110% of its 5 MB data storage. The space is taken by agent conversation logs:
- `ConversationDefinitionEventLog`: about 2,470 records.
- `ConversationDefinitionSession`: about 300 records.

Neither can be deleted from this org:
- The API marks both log objects as not deletable.
- Deleting an old agent version fails. The builder returns a server error, and the API returns `DEPENDENCY_EXISTS` against the version's Authoring Bundle.

While the org is over its limit, it can't create agent versions or run tests. The old org stays as it is (v13 active) until the new one passes the demo checklist.

## Step 0: Export everything from the old org (do this first)

The old org still allows reads, so this can be done now.

| Item | Saved locally? | How to export |
|---|---|---|
| Apex: InfoSessionFinder, InfoSessionRegistration, ProgramCatalog, ProgramCostEstimator, ProspectLeadCapture, RamBotProspect{Perms,Reports,Seed,Setup} | Yes, `rambot-apex/` | none |
| Apex: FacultyLookup | **No** | CLI retrieve |
| Custom objects Application__c, Advising_Appointment__c, Faculty__c, Program__c (+ fields) | **No** | CLI retrieve |
| Custom fields on Lead (Program_Interest, Intended_Term, Is_International), Campaign (Event_Time, Registration_URL, Program_Focus), MessagingSession (Handoff_Summary, Handled_By) | **No** | CLI retrieve |
| Flows: Get_Application_Status, Book_Advising_Appointment, Escalate_to_Advisor, Save_Handoff_Summary, RamBot_Messaging_Routing, RamBot_Escalate_to_Advisors | **No** | CLI retrieve |
| VF page RamBotSetup, remote site RamBot_Self_Org | **No** | CLI retrieve |
| Agent v13 Agent Script | **No** (only v1 is archived) | Copy from the builder into `rambot-apex/agent-script-archive/rambot_v13.agent` |
| Reports (5, folder RamBot_Reports), dashboard RamBot_Admissions_Impact, report type RamBot_Messaging_Sessions | **No** | CLI retrieve, or rebuild with RamBotProspectReports |
| Lightning page "Messaging Session - Advisor" | **No** | CLI retrieve (FlexiPage) |
| Data: Faculty__c 187, Program__c 15, Campaign 49, Application__c 8, Advising_Appointment__c 6 | Programs only (`gabelli_programs_2026-2027.csv`) | Export to CSV through the API |
| Knowledge: Data Library "Gabelli Graduate Info" (82 scraped pages + 2026-27 files) | 6 refreshed files + 1 raw | Download the files from the library. If that's not possible, re-scrape fordham.edu (newer content anyway) |
| Test suite CSV | Yes, `rambot-data/rambot_v12_test_suite.csv` | none |

The CLI route is the most reliable way to get all of the metadata at once:
1. Install the CLI: `npm install -g @salesforce/cli`.
2. Log in to the old org: `sf org login web --alias rambot-old` (you sign in in the browser).
3. Retrieve with a `package.xml` that lists the items above, into `prep/rambot-sfdx/`.

That folder then becomes the deploy source for the new org.

## Step 1: Create the new org (you do this)

- Sign up for a new Developer Edition org with Agentforce, the same kind of signup as the current "orgfarm" org.
- Confirm that Agentforce, Data Cloud / Data Library, and Messaging for In-App and Web are available.
- I can't create accounts, so this step is yours. Once you've signed in, I take over.

## Step 2: Deploy and seed (I do this)

1. Run `sf project deploy start` for the objects, fields, Apex, flows, VF page, and FlexiPage.
2. Load the data: Programs, Faculty, Campaigns (events), and the 8 demo applications A-1001 to A-1008.
3. Data Library: upload the knowledge files and note the new `rag_feature_config_id`.
4. Recreate the agent from the v13 script plus the v14 guards in `rambot-apex/v14_code_guards.md`.
   - The new org's IDs need updating: `default_agent_user` and `rag_feature_config_id`.
5. Recreate the Service Cloud setup:
   - Messaging channel and Embedded Service deployment.
   - Queue "Admissions Advisors".
   - Routing configuration and the presence status.
   - Digital Experiences.
   - The advisor's Lightning page as the org default.
6. Permissions:
   - The agent user needs access to the Apex classes, the custom objects, and Lead edit.
   - Enable Marketing User so the agent can use Campaigns.

## Step 3: Verify, staying within the storage budget

- Each test chat writes about 15–20 log records (roughly 30–40 KB). A full 42-case suite run costs about 0.5–0.8 MB.
- Budget for the new org: no more than 2 full suite runs before the interview, and check Setup → System Overview after each run.
- Checklist:
  - 5 Preview runs each of the two v14 cases.
  - 1 full suite run.
  - 1 live web chat with a human handoff.
  - The dashboard loads.

## Interview angle

Agentforce event logs count against data storage. A Developer Edition org has 5 MB, which held only about 20 days of active testing. In a real deployment, I'd plan log retention and storage for each environment before setting up regression testing.

## Export status (Nov 7): done

Everything from Step 0 is now saved locally:

- **Metadata:** in `rambot-sfdx/` (SFDX project, API 65), retrieved with the CLI (`sf`, alias `rambot-old`). It includes:
  - 20 Apex classes, 4 VF pages, 6 flows
  - custom objects, plus the custom fields on Lead, Campaign and MessagingSession
  - 16 FlexiPages, 11 permission sets
  - the queue, the routing config, 2 service channels, the presence status
  - the messaging channel, the Embedded Service config, the bot
  - the remote site, the report type, 5 reports and the dashboard
  - the agent bundles: AiAuthoringBundle `RamBot` (v13) and `RamBot_12`, and GenAiPlannerBundle `RamBot_v13`
- **Agent Scripts:** `rambot-apex/agent-script-archive/` holds rambot_v1, v12 and v13.
- **Records:** `rambot-sfdx/data/` holds Faculty__c (187), Program__c (15), Application__c (8), Advising_Appointment__c (6, with Application__r.Name), and Campaign (49).
- **Knowledge:**
  - `rambot-data/kb/` holds the original 81-page scrape, copied from ~/Downloads/gabelli_kb.
  - The refreshed 2026-27 files are in `rambot-data/`.
  - The library files themselves sit in Data Cloud storage and can't be downloaded with the CLI.

Notes for deploying to the new org:
- Retrieve the agent bundles by name. Wildcards return nothing for them, and the project needs sourceApiVersion 65.
- Node 22 is installed through nvm for the CLI. Run `nvm use 22` before using `sf`. The default Node is still 18.
