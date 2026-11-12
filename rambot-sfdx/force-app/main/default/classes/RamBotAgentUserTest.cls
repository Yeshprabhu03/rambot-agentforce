// Runs every RamBot agent action as the real agent user, so user-mode queries are checked against
// the agent's own permission sets rather than an admin's. Uses org data (catalog, events, a chat);
// everything it writes is rolled back when the test ends.
@IsTest(SeeAllData=true)
private class RamBotAgentUserTest {
    static User agentUser() {
        return [SELECT Id FROM User WHERE Username = 'rambot@00dbm000017ak5y.ext' LIMIT 1];
    }

    @IsTest
    static void catalogActionsReadAsAgent() {
        System.runAs(agentUser()) {
            ProgramCatalog.Request pc = new ProgramCatalog.Request();
            pc.keywords = 'analytics';
            ProgramCatalog.Response programs = ProgramCatalog.getPrograms(new List<ProgramCatalog.Request>{ pc })[0];
            Assert.isTrue(programs.programCount > 0, 'Agent should read programs');
            Assert.isTrue(programs.programs.contains('Key courses'), 'Agent should read Key_Courses__c');

            ProgramCostEstimator.Request ce = new ProgramCostEstimator.Request();
            ce.program = 'MSBA';
            ce.isInternational = true;
            ProgramCostEstimator.Response cost = ProgramCostEstimator.estimate(new List<ProgramCostEstimator.Request>{ ce })[0];
            Assert.isTrue(cost.found, 'Agent should find MSBA');
            Assert.isTrue(cost.directTotal > 0, 'Estimate should have a total');

            FacultyLookup.Request fl = new FacultyLookup.Request();
            fl.department = 'Finance';
            Assert.isTrue(FacultyLookup.find(new List<FacultyLookup.Request>{ fl })[0].matchCount > 0, 'Agent should read faculty');

            InfoSessionFinder.Request ev = new InfoSessionFinder.Request();
            InfoSessionFinder.Response events = InfoSessionFinder.find(new List<InfoSessionFinder.Request>{ ev })[0];
            Assert.isNotNull(events.events, 'Agent should read events');
        }
    }

    @IsTest
    static void leadCaptureAndRegistrationAsAgent() {
        Campaign c = [SELECT Name, StartDate FROM Campaign WHERE IsActive = true AND Registration_URL__c != null AND StartDate >= TODAY ORDER BY StartDate LIMIT 1];
        System.runAs(agentUser()) {
            ProspectLeadCapture.Request lc = new ProspectLeadCapture.Request();
            lc.firstName = 'Agent';
            lc.lastName = 'Usermode';
            lc.email = 'agent.usermode.test@example.com';
            lc.programInterest = 'MS in Business Analytics';
            lc.intendedTerm = 'Fall 2027';
            lc.country = 'India';
            lc.isInternational = true;
            lc.notes = 'Test lead from RamBotAgentUserTest.';
            ProspectLeadCapture.Response saved = ProspectLeadCapture.capture(new List<ProspectLeadCapture.Request>{ lc })[0];
            Assert.isTrue(saved.saved, 'Lead capture failed as agent: ' + saved.result);

            InfoSessionRegistration.Request reg = new InfoSessionRegistration.Request();
            reg.eventName = c.Name;
            reg.eventDate = String.valueOf(c.StartDate);
            reg.firstName = 'Agent';
            reg.lastName = 'Usermode';
            reg.email = 'agent.usermode.test@example.com';
            InfoSessionRegistration.Response r = InfoSessionRegistration.register(new List<InfoSessionRegistration.Request>{ reg })[0];
            Assert.isTrue(r.registered, 'Registration failed as agent: ' + r.result);
        }
        Lead l = [SELECT Id, OwnerId, Country FROM Lead WHERE Email = 'agent.usermode.test@example.com' LIMIT 1];
        Assert.areEqual(1, [SELECT COUNT() FROM CampaignMember WHERE LeadId = :l.Id], 'Lead should be a campaign member');
    }

    @IsTest
    static void morePathsAsAgent() {
        System.runAs(agentUser()) {
            ProgramCostEstimator.Request pt = new ProgramCostEstimator.Request();
            pt.program = 'MS in Business Analytics';
            pt.studyMode = 'Part-time';
            pt.includeLivingCosts = true;
            ProgramCostEstimator.Request flat = new ProgramCostEstimator.Request();
            flat.program = 'FTMBA';
            ProgramCostEstimator.Request missing = new ProgramCostEstimator.Request();
            missing.program = 'MS in Underwater Basket Weaving';
            List<ProgramCostEstimator.Response> costs = ProgramCostEstimator.estimate(new List<ProgramCostEstimator.Request>{ pt, flat, missing });
            Assert.isTrue(costs[0].found && costs[1].found, 'Part-time and flat-rate estimates should work');
            Assert.isFalse(costs[2].found, 'Unknown program should not be found');

            Faculty__c someone = [SELECT Name FROM Faculty__c LIMIT 1];
            FacultyLookup.Request byName = new FacultyLookup.Request();
            byName.facultyName = someone.Name;
            FacultyLookup.Request typo = new FacultyLookup.Request();
            typo.facultyName = someone.Name.left(someone.Name.length() - 1) + 'x';
            FacultyLookup.Request bio = new FacultyLookup.Request();
            bio.department = 'sustainability investing';
            List<FacultyLookup.Result> found = FacultyLookup.find(new List<FacultyLookup.Request>{ byName, typo, bio });
            Assert.isTrue(found[0].matchCount > 0, 'Name lookup should work as agent');

            ProspectLeadCapture.Request first = new ProspectLeadCapture.Request();
            first.firstName = 'Agent';
            first.lastName = 'Returning';
            first.email = 'agent.returning.test@example.com';
            first.programInterest = 'MSBA';
            first.notes = 'First visit.';
            ProspectLeadCapture.capture(new List<ProspectLeadCapture.Request>{ first });
            first.notes = 'Second visit.';
            first.sendEmailSummary = true;
            ProspectLeadCapture.Response again = ProspectLeadCapture.capture(new List<ProspectLeadCapture.Request>{ first })[0];
            Assert.isTrue(again.saved, 'Returning lead update failed as agent: ' + again.result);
        }
        Assert.areEqual(1, [SELECT COUNT() FROM Lead WHERE Email = 'agent.returning.test@example.com'], 'Returning student should update, not duplicate');
    }

    @IsTest
    static void handoffTriggerRenamesUser() {
        List<MessagingSession> chats = [SELECT MessagingEndUserId FROM MessagingSession WHERE MessagingEndUserId != null ORDER BY CreatedDate DESC LIMIT 1];
        if (chats.isEmpty()) {
            return;
        }
        Test.startTest();
        EventBus.publish(new RamBot_Handoff__e(End_User_Id__c = chats[0].MessagingEndUserId, Student_Name__c = 'Trigger Test Name'));
        Test.stopTest();
        Assert.areEqual('Trigger Test Name', [SELECT Name FROM MessagingEndUser WHERE Id = :chats[0].MessagingEndUserId].Name);
    }

    @IsTest
    static void advisorAvailabilityAndCallsAsAgent() {
        // Wednesday 3 March 2027, 10:00 AM Eastern.
        AdvisorCalendar.nowOverride = AdvisorCalendar.fromEastern(Date.newInstance(2027, 3, 3), 10, 0);
        System.runAs(agentUser()) {
            AdvisorAvailability.Response open = AdvisorAvailability.check(new List<AdvisorAvailability.Request>{ new AdvisorAvailability.Request() })[0];
            Assert.isTrue(open.withinHours, 'Wednesday 10 AM ET is within hours');
            Assert.isTrue(open.openSlots.contains('[slot 2027-03-03 11:00]'), open.openSlots);
            Assert.isTrue(open.openSlots.contains('[slot 2027-03-03 13:00]'), 'First afternoon slot after lunch: ' + open.openSlots);

            ScheduleAdvisorCall.Request ok = callRequest('2027-03-04 14:00');
            ScheduleAdvisorCall.Response booked = ScheduleAdvisorCall.schedule(new List<ScheduleAdvisorCall.Request>{ ok })[0];
            Assert.isTrue(booked.booked, 'Booking failed as agent: ' + booked.slotError);
            Assert.isTrue(booked.confirmationNumber.startsWith('ADV-'), booked.confirmationNumber);
            Assert.areEqual('Thursday, March 4 at 2:00 PM ET', booked.callTime);

            List<String> badSlots = new List<String>{ '2027-03-04 14:00', '2027-03-06 11:00', '2027-03-04 17:00', '2027-03-04 14:15', '2027-03-03 10:30', '2027-02-30 10:00', 'tomorrow at 2' };
            List<String> expected = new List<String>{ 'already taken', 'weekend', 'outside advising hours', 'half hour', 'less than an hour', 'could not be read', 'could not be read' };
            for (Integer i = 0; i < badSlots.size(); i++) {
                ScheduleAdvisorCall.Response r = ScheduleAdvisorCall.schedule(new List<ScheduleAdvisorCall.Request>{ callRequest(badSlots[i]) })[0];
                Assert.isFalse(r.booked, badSlots[i] + ' should not book');
                Assert.isTrue(r.slotError.contains(expected[i]), badSlots[i] + ': ' + r.slotError);
                Assert.isTrue(r.otherOpenSlots.contains('[slot '), 'Should offer other times');
            }
            ScheduleAdvisorCall.Request noEmail = callRequest('2027-03-05 10:00');
            noEmail.email = 'not-an-email';
            Assert.isFalse(ScheduleAdvisorCall.schedule(new List<ScheduleAdvisorCall.Request>{ noEmail })[0].booked, 'Needs a real email');
        }
        Advising_Appointment__c appt = [SELECT Lead__c, Topic__c, Call_Notes__c FROM Advising_Appointment__c
            WHERE Lead__r.Email = 'agent.call.test@example.com' LIMIT 1];
        Assert.areEqual('Financial Aid', appt.Topic__c);

        // Saturday: outside hours, so no live chat even if someone is online.
        AdvisorCalendar.nowOverride = AdvisorCalendar.fromEastern(Date.newInstance(2027, 3, 6), 11, 0);
        System.runAs(agentUser()) {
            AdvisorAvailability.Response weekend = AdvisorAvailability.check(new List<AdvisorAvailability.Request>{ new AdvisorAvailability.Request() })[0];
            Assert.isFalse(weekend.withinHours);
            Assert.isFalse(weekend.liveAvailable);
            Assert.isTrue(weekend.openSlots.startsWith('1. Monday, March 8 at 9:00 AM ET'), weekend.openSlots);
        }
        Assert.isNotNull(AdvisorCalendar.advisorOnline(), 'Presence check runs');
    }

    static ScheduleAdvisorCall.Request callRequest(String slot) {
        ScheduleAdvisorCall.Request r = new ScheduleAdvisorCall.Request();
        r.firstName = 'Agent';
        r.lastName = 'Caller';
        r.email = 'agent.call.test@example.com';
        r.slot = slot;
        r.topic = 'Financial Aid';
        r.notes = 'Wants to discuss scholarships for the MSBA.';
        r.programInterest = 'MS in Business Analytics';
        return r;
    }

    @IsTest
    static void handoffSummaryAsAgent() {
        List<MessagingSession> chats = [SELECT Id FROM MessagingSession ORDER BY CreatedDate DESC LIMIT 1];
        if (chats.isEmpty()) {
            return;
        }
        System.runAs(agentUser()) {
            HandoffSummary.Request req = new HandoffSummary.Request();
            req.messagingSessionId = chats[0].Id;
            req.summary = 'Test summary from RamBotAgentUserTest.';
            req.studentName = 'Agent Usermode';
            req.studentEmail = 'nobody.usermode@example.com';
            String result = HandoffSummary.save(new List<HandoffSummary.Request>{ req })[0].summarySaved;
            Assert.isTrue(result.startsWith('Saved'), 'Handoff failed as agent: ' + result);
        }
        MessagingSession ms = [SELECT Handoff_Summary__c FROM MessagingSession WHERE Id = :chats[0].Id];
        Assert.isTrue(ms.Handoff_Summary__c.startsWith('Agent Usermode (nobody.usermode@example.com): Test summary'), ms.Handoff_Summary__c);
    }
}
