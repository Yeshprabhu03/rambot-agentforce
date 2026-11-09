# RamBot v14: move the two inconsistent behaviors into code

Status: **applied Nov 7 in the new org** (orgfarm-74f758c996, RamBot v3 active there). Final script: `agent-script-archive/rambot_v14.agent`. Published with `sf agent validate/publish authoring-bundle`; the validator confirmed that `before_reasoning`, `available when`, `if`/`run`/`set` in instructions, and `set ... = @outputs.x` are valid Agent Script.

## 1. Handoff must have a confirmation turn (fixes "skipped confirmation" 2 of 3 runs)

Add to `variables:`
```
    escalation_turns: mutable number = 0
        description: "Turns the student has spent in Escalation in this chat."
        visibility: "Internal"
```

In `subagent escalation:` add a deterministic step that runs before the model each turn:
```
    before_reasoning:
        set @variables.escalation_turns = @variables.escalation_turns + 1
```

Gate the transfer and the summary in `reasoning.actions`:
```
            Save_Handoff_Summary: @actions.Save_Handoff_Summary
                available when @variables.escalation_turns >= 2
                with messagingSessionId = @variables.RoutableId
                with summary = ...
            transfer_to_advisor: @utils.escalate
                available when @variables.escalation_turns >= 2
                description: "Transfer the conversation live to an admissions advisor in the Admissions Advisors queue."
```
Effect: on the first Escalation turn the model has no transfer tool, so it can only summarize and ask. The transfer becomes available only after the student replies. The platform enforces this, not the prompt.

## 2. Status check runs deterministically (fixes Kevin "could not verify" without running, 1 of 2 runs)

Add to `variables:`
```
    application_number: mutable string = ""
        visibility: "Internal"
    application_email: mutable string = ""
        visibility: "Internal"
    status_checked: mutable boolean = False
        visibility: "Internal"
```

In `subagent Application_Status:` let the model only capture the two values:
```
        actions:
            capture_application_details: @utils.setVariables
                with application_number = ...
                with application_email = ...
```
Then run the lookup from code once both values are present:
```
        instructions: ->
            if @variables.application_number != "" and @variables.application_email != "" and @variables.status_checked == False:
                run @actions.Get_Application_Status
                    with applicationNumber = @variables.application_number
                    with studentEmail = @variables.application_email
                set @variables.status_checked = True
            | (existing instructions, plus:) Only describe a result that Get Application Status returned in this conversation.
```
Fallback if `run` inside instructions isn't accepted: keep the model-called action, and add `available when @variables.status_checked == False` plus an output-driven `set @variables.status_checked = True`. Change the "could not verify" wording to come only from the action's `found = false` output.

## 3. Verify
- Preview: "I want to talk to a real person" ×5. The transfer must never fire on the first turn.
- Preview: "Has my application been decided? A-1006, kevin.liu@example.com" ×5. The trace must show Get_Application_Status every time.
- Rerun the 42-case suite (new suite, since the old one has a stalled run) and compare with runs 1–2.

## Results (new org, CLI programmatic preview)

| Case | Runs | Result |
|---|---|---|
| Kevin, A-1006 + email | 5 | 5/5 ran Get_Application_Status and returned Waitlisted, MS Business Analytics, Spring 2027 |
| A-1004 + wrong email | 1 | Lookup ran, said it could not verify, revealed nothing |
| "I want to talk to a real person" → confirm | 5 | Turn 1: 5/5 asked for the issue, no transfer possible. Turn 2: 5/5 Escalate |

## What changed on the way
- **Router answered for itself.** The first escalation test showed turn 2 starting at the router, which replied "I'll connect you" without routing or transferring (a false claim). Fix: `before_reasoning` in `agent_router`: `if @variables.escalation_turns > 0: transition to @subagent.escalation`.
- **"Could not verify" without checking (1 of 5 before the fix).** The model replied without calling either tool. Fix: the failure wording now lives in a conditional instruction that only appears when `status_checked == True and status_found == False`, with `status_found` set from the action output.
- Not verifiable in preview: whether Save_Handoff_Summary ran before the transfer (preview has no messaging session). Check on live chat once Messaging is set up.
