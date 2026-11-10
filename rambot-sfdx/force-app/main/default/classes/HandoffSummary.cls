// Agent action: saves the handoff summary on the chat and tells the advisor who the student is.
// Names the chat's Messaging User after the student and links the chat to their Lead when one exists,
// so the advisor sees "Tyler Markel" and the Lead instead of "Guest".
public without sharing class HandoffSummary {
    static final Integer SUMMARY_MAX = 255;

    public class Request {
        @InvocableVariable(label='messagingSessionId' description='The ID of the current messaging session.' required=true)
        public String messagingSessionId;
        @InvocableVariable(label='summary' description='Under 250 characters: the student\'s issue, what RamBot already answered or checked, and what the student needs from the advisor.' required=true)
        public String summary;
        @InvocableVariable(label='studentName' description='Optional. The student\'s first and last name, only if they gave it in this conversation. Leave blank otherwise; never guess.')
        public String studentName;
        @InvocableVariable(label='studentEmail' description='Optional. The student\'s email address, only if they gave it in this conversation. Leave blank otherwise.')
        public String studentEmail;
    }

    public class Response {
        @InvocableVariable(label='summarySaved' description='Confirms the handoff summary was saved.')
        public String summarySaved;
    }

    @InvocableMethod(label='Save Handoff Summary' description='Saves a short handoff summary onto the current chat record, names the chat after the student and links their Lead, so the human advisor sees it first.')
    public static List<Response> save(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            res.summarySaved = saveOne(req);
            out.add(res);
        }
        return out;
    }

    static String saveOne(Request req) {
        List<MessagingSession> sessions = [SELECT Id, MessagingEndUserId FROM MessagingSession WHERE Id = :req.messagingSessionId LIMIT 1];
        if (sessions.isEmpty()) {
            return 'Not saved: chat not found.';
        }
        MessagingSession ms = sessions[0];

        String email = String.isBlank(req.studentEmail) ? null : req.studentEmail.trim().toLowerCase();
        String name = String.isBlank(req.studentName) ? null : req.studentName.trim();
        Lead lead;
        if (email != null) {
            List<Lead> leads = [SELECT Id, Name FROM Lead WHERE Email = :email AND IsConverted = false ORDER BY LastModifiedDate DESC LIMIT 1];
            if (!leads.isEmpty()) {
                lead = leads[0];
            }
            if (name == null && lead != null) {
                name = lead.Name;
            }
            if (name == null) {
                List<Application__c> apps = [SELECT Student_Name__c FROM Application__c WHERE Student_Email__c = :email LIMIT 1];
                if (!apps.isEmpty()) {
                    name = apps[0].Student_Name__c;
                }
            }
        }

        // Who the student is goes first, then the agent's summary, within the field's 255 characters.
        String who = name == null ? '' : name + (email == null ? '' : ' (' + email + ')') + ': ';
        String text = who + (req.summary == null ? '' : req.summary.trim());
        if (text.length() > SUMMARY_MAX) {
            text = text.left(SUMMARY_MAX - 3) + '...';
        }
        // Update a fresh record: the queried one carries MessagingEndUserId, which can't be written back.
        // The summary is what the advisor needs most, so it is saved on its own first.
        update new MessagingSession(Id = ms.Id, Handoff_Summary__c = text);

        // Naming the user and linking the Lead are best effort: a failure here must not lose the summary.
        Boolean linked = false;
        if (lead != null) {
            linked = Database.update(new MessagingSession(Id = ms.Id, LeadId = lead.Id), false).isSuccess();
        }
        // The agent user's license can't edit MessagingEndUser, so a platform event hands that to the Automated Process user.
        Boolean named = false;
        if (ms.MessagingEndUserId != null && (name != null || lead != null)) {
            Database.SaveResult sr = EventBus.publish(new RamBot_Handoff__e(
                End_User_Id__c = ms.MessagingEndUserId,
                Student_Name__c = name == null ? null : name.left(80),
                Lead_Id__c = lead == null ? null : lead.Id));
            named = sr.isSuccess();
        }
        return 'Saved' + (named && name != null ? ' for ' + name : '') + (linked ? ', linked to their Lead' : '') + '.';
    }
}