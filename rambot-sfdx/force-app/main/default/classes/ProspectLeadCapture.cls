// Agent action: saves a prospective student as a Lead for the admissions team and can email them their program summary.
public without sharing class ProspectLeadCapture {
    // Set by upsertLead: true when the email matches an Application already on file.
    public static Boolean lastWasApplicant = false;

    public class Request {
        @InvocableVariable(label='First Name' required=true)
        public String firstName;
        @InvocableVariable(label='Last Name' required=true)
        public String lastName;
        @InvocableVariable(label='Email' required=true)
        public String email;
        @InvocableVariable(label='Program Interest' description='Program(s) the student is interested in, e.g. "MS in Business Analytics".')
        public String programInterest;
        @InvocableVariable(label='Intended Term' description='When they want to start, e.g. "Fall 2027".')
        public String intendedTerm;
        @InvocableVariable(label='Country' description='Optional: country the student lives in.')
        public String country;
        @InvocableVariable(label='International Student' description='Optional: true if the student will need an F-1 visa.')
        public Boolean isInternational;
        @InvocableVariable(label='Conversation Notes' description='2-4 sentences for the admissions counselor: background, goals, questions asked and what was recommended.')
        public String notes;
        @InvocableVariable(label='Send Email Summary' description='Optional: true to email the student a summary of their program(s) of interest, deadlines and next steps. The email is built from Fordham program records, not written by the agent.')
        public Boolean sendEmailSummary;
        // Kept for compatibility with agent versions before v8; ignored.
        @InvocableVariable(label='Email Summary' description='Deprecated. Use Send Email Summary.')
        public String emailSummary;
    }

    public class Response {
        @InvocableVariable(label='Result' description='What was saved and whether the email was sent.')
        public String result;
        @InvocableVariable(label='Saved' description='true if the Lead was saved.')
        public Boolean saved;
        @InvocableVariable(label='Existing Applicant' description='true if this email matches an application already on file. Offer a status check; never reveal application details from this flag.')
        public Boolean existingApplicant;
    }

    @InvocableMethod(label='Capture Prospect Interest' description='Saves a prospective student as a Lead routed to the Gabelli admissions team, and optionally emails them a summary. Only call after the student agrees to share their name and email.')
    public static List<Response> capture(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            try {
                Lead l = upsertLead(req.firstName, req.lastName, req.email, req.programInterest, req.intendedTerm, req.country, req.isInternational, req.notes);
                res.saved = true;
                res.existingApplicant = lastWasApplicant;
                res.result = 'Saved for the Gabelli admissions team. A counselor will follow up.';
                if (req.sendEmailSummary == true) res.result += ' ' + sendSummary(l, buildSummary(req.firstName, req.programInterest));
            } catch (Exception e) {
                res.saved = false;
                res.result = 'Could not save the details: ' + e.getMessage();
            }
            out.add(res);
        }
        return out;
    }

    public static Lead upsertLead(String firstName, String lastName, String email, String program, String term, String country, Boolean intl, String notes) {
        List<Lead> existing = [SELECT Id, Description FROM Lead WHERE Email = :email AND IsConverted = false ORDER BY CreatedDate DESC LIMIT 1];
        Lead l = existing.isEmpty() ? new Lead() : existing[0];
        l.FirstName = firstName;
        l.LastName = lastName;
        l.Email = email;
        if (String.isNotBlank(program)) l.Program_Interest__c = program.left(120);
        if (String.isNotBlank(term)) l.Intended_Term__c = term.left(40);
        if (String.isNotBlank(country)) l.Country = country;
        if (intl != null) l.Is_International__c = intl;
        if (String.isNotBlank(notes)) {
            String stamp = 'RamBot ' + Datetime.now().format('yyyy-MM-dd HH:mm') + ': ' + notes;
            l.Description = String.isBlank(l.Description) ? stamp : (l.Description + '\n' + stamp).left(32000);
        }
        // Flag returning applicants for the counselor. Email alone is not verification, so details stay on the Lead only.
        List<Application__c> apps = [SELECT Name, Program__c, Status__c FROM Application__c WHERE Student_Email__c = :email LIMIT 5];
        lastWasApplicant = !apps.isEmpty();
        if (lastWasApplicant) {
            List<String> refs = new List<String>();
            for (Application__c a : apps) refs.add(a.Name + ' (' + a.Program__c + ', ' + a.Status__c + ')');
            String flag = 'Existing applicant: ' + String.join(refs, '; ');
            if (String.isBlank(l.Description)) l.Description = flag;
            else if (!l.Description.contains(flag)) l.Description = (l.Description + '\n' + flag).left(32000);
        }
        if (l.Id == null) {
            l.Company = 'Prospective Student';
            l.LeadSource = 'RamBot Web Chat';
            List<Group> queue = [SELECT Id FROM Group WHERE Type = 'Queue' AND Name = 'Admissions Advisors' LIMIT 1];
            if (!queue.isEmpty()) l.OwnerId = queue[0].Id;
            insert l;
        } else {
            update l;
        }
        return l;
    }

    // Templated from Program__c so emails only contain catalog facts.
    static String buildSummary(String firstName, String programInterest) {
        List<String> blocks = new List<String>();
        String interest = programInterest == null ? '' : programInterest.toLowerCase();
        for (Program__c p : [SELECT Name, Program_Code__c, Degree_Type__c, Format__c, Credits__c, Length__c, STEM_Designated__c, F1_Eligible__c,
                Start_Terms__c, Pricing_Model__c, Rate_Per_Credit__c, Program_Total_Tuition__c, Enrichment_Fee__c, Deadline_Track__c, Ideal_For__c, Program_URL__c
                FROM Program__c ORDER BY Name]) {
            if (interest.contains(p.Name.toLowerCase()) || interest.contains(p.Program_Code__c.toLowerCase())) blocks.add(ProgramCatalog.describeWithLink(p));
        }
        return 'Hi ' + firstName + ',\n\nThank you for your interest in the Gabelli School of Business at Fordham. Here is a summary of what we discussed.\n\n'
            + (blocks.isEmpty() ? 'Programs of interest: ' + programInterest + '\n' : String.join(blocks, '\n\n') + '\n')
            + '\nNext steps:\n- Join a free online info session: https://gradadmissions.fordham.edu/portal/DiscoverGabelli-VirtualEvents\n'
            + '- Apply online (GMAT/GRE optional; $150 fee, waived in Round 1).\n'
            + '- An admissions counselor will follow up with you.\n\nTuition shown is for 2026-27 and may change; merit scholarships are considered automatically when you apply.';
    }

    static String sendSummary(Lead l, String body) {
        try {
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setTargetObjectId(l.Id);
            msg.setSaveAsActivity(true);
            msg.setSenderDisplayName('Gabelli Graduate Admissions (RamBot)');
            msg.setReplyTo('admissionsgb@fordham.edu');
            msg.setSubject('Your Gabelli graduate program summary');
            msg.setPlainTextBody(body + '\n\nQuestions? Reply to this email or call Gabelli Graduate Admissions at +1 212-636-6200.\nApply: https://www.fordham.edu/gabelli-school-of-business/academic-programs-and-admissions/graduate-programs/graduate-admissions/');
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ msg });
            return 'The summary email was sent.';
        } catch (Exception e) {
            return 'The summary email could not be sent (' + e.getMessage().left(120) + ').';
        }
    }
}