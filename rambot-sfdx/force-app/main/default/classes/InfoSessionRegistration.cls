// Agent action: records a prospective student's registration for an admissions event as a Campaign Member.
public without sharing class InfoSessionRegistration {
    public class Request {
        @InvocableVariable(label='Event Name' description='Exact event name from Find Info Sessions.' required=true)
        public String eventName;
        @InvocableVariable(label='Event Date' description='Event date as YYYY-MM-DD, from Find Info Sessions.' required=true)
        public String eventDate;
        @InvocableVariable(label='First Name' required=true)
        public String firstName;
        @InvocableVariable(label='Last Name' required=true)
        public String lastName;
        @InvocableVariable(label='Email' required=true)
        public String email;
        @InvocableVariable(label='Program Interest' description='Optional: program the student is interested in.')
        public String programInterest;
    }

    public class Response {
        @InvocableVariable(label='Result' description='Confirmation, including the Fordham portal link the student must also use to get the session link.')
        public String result;
        @InvocableVariable(label='Registered')
        public Boolean registered;
        @InvocableVariable(label='Existing Applicant' description='true if this email matches an application already on file. Offer a status check; never reveal application details from this flag.')
        public Boolean existingApplicant;
    }

    @InvocableMethod(label='Register for Info Session' description='Registers a prospective student for a Gabelli admissions event in Salesforce and saves them as a lead for the admissions team.')
    public static List<Response> register(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            try {
                Date d = Date.valueOf(req.eventDate.trim());
                String name = req.eventName.trim().left(80);
                List<Campaign> camps = [SELECT Id, Name, StartDate, Event_Time__c, Registration_URL__c FROM Campaign
                    WHERE StartDate = :d AND Registration_URL__c != null AND (Name = :name OR Name LIKE :('%' + name.left(40) + '%')) LIMIT 1];
                if (camps.isEmpty()) {
                    res.registered = false;
                    res.result = 'That event was not found. Call Find Info Sessions and use the exact name and date.';
                    out.add(res);
                    continue;
                }
                Campaign c = camps[0];
                Lead l = ProspectLeadCapture.upsertLead(req.firstName, req.lastName, req.email, req.programInterest, null, null, null,
                    'Registered for ' + c.Name + ' on ' + String.valueOf(c.StartDate) + '.');
                if ([SELECT COUNT() FROM CampaignMember WHERE CampaignId = :c.Id AND LeadId = :l.Id] == 0) {
                    insert new CampaignMember(CampaignId = c.Id, LeadId = l.Id, Status = 'Responded');
                }
                res.registered = true;
                res.existingApplicant = ProspectLeadCapture.lastWasApplicant;
                res.result = 'Registered ' + req.firstName + ' for ' + c.Name + ' on '
                    + Datetime.newInstance(c.StartDate, Time.newInstance(12, 0, 0, 0)).format('EEEE, MMMM d, yyyy') + ', ' + c.Event_Time__c
                    + '. The admissions team has the registration. To receive the session link, the student should also complete the short form on Fordham\'s Gabelli graduate admissions events page.';
            } catch (Exception e) {
                res.registered = false;
                res.result = 'Could not register: ' + e.getMessage().left(200);
            }
            out.add(res);
        }
        return out;
    }
}