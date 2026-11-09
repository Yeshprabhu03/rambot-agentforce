// Agent action: lists upcoming Gabelli admissions events (stored as Campaigns) for a program or topic.
public without sharing class InfoSessionFinder {
    public class Request {
        @InvocableVariable(label='Program or Topic' description='Optional. Program or interest, e.g. "Business Analytics", "MBA", "Finance", "India". Leave blank for all upcoming events.')
        public String keyword;
    }

    public class Response {
        @InvocableVariable(label='Events' description='Numbered list of upcoming events with exact event names, event dates (YYYY-MM-DD) and times.')
        public String events;
        @InvocableVariable(label='Event Count')
        public Integer eventCount;
    }

    @InvocableMethod(label='Find Info Sessions' description='Finds upcoming Gabelli graduate admissions information sessions, webinars and recruiting events, optionally for a program or location.')
    public static List<Response> find(List<Request> requests) {
        List<Campaign> upcoming = [SELECT Name, StartDate, Event_Time__c, Program_Focus__c, Registration_URL__c, Type FROM Campaign
            WHERE IsActive = true AND Registration_URL__c != null AND StartDate >= TODAY ORDER BY StartDate, Name LIMIT 200];
        List<Response> out = new List<Response>();
        for (Request req : requests) {
            List<Campaign> hits = new List<Campaign>();
            List<String> words = new List<String>();
            if (String.isNotBlank(req.keyword)) {
                for (String w : req.keyword.toLowerCase().split('[^a-z0-9]+')) {
                    if (w.length() > 1 && !new Set<String>{ 'ms', 'in', 'of', 'and', 'the', 'program', 'programs', 'session', 'sessions' }.contains(w)) words.add(w);
                }
            }
            for (Campaign c : upcoming) {
                String hay = (c.Name + ' ' + c.Program_Focus__c).toLowerCase().replace('ftmba', 'full-time mba mba').replace('mssmc', 'strategic marketing communications');
                Boolean match = words.isEmpty();
                for (String w : words) if (hay.contains(w)) { match = true; break; }
                if (match) hits.add(c);
                if (hits.size() == 6) break;
            }
            Response res = new Response();
            res.eventCount = hits.size();
            if (hits.isEmpty()) {
                res.events = 'No upcoming events match. All events are listed on Fordham\'s Gabelli graduate admissions events page.';
            } else {
                List<String> lines = new List<String>();
                Integer i = 1;
                for (Campaign c : hits) {
                    lines.add(i++ + '. ' + c.Name + ' (event date ' + String.valueOf(c.StartDate) + ') - ' + Datetime.newInstance(c.StartDate, Time.newInstance(12, 0, 0, 0)).format('EEEE, MMMM d, yyyy')
                        + ', ' + c.Event_Time__c + '.');
                }
                res.events = String.join(lines, '\n');
            }
            out.add(res);
        }
        return out;
    }
}
