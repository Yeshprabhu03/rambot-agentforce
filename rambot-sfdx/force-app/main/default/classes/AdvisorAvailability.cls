// Agent action: tells RamBot whether a student can chat with an advisor right now, and the next open call times.
// Live chat is offered only during advising hours and only when an advisor is set to Available in Omni-Channel.
public with sharing class AdvisorAvailability {
    public class Request {
        @InvocableVariable(label='Slot Count' description='Optional. How many open call times to list. Default 4.')
        public Integer slotCount;
    }

    public class Response {
        @InvocableVariable(label='Live Available' description='true when it is advising hours and an admissions advisor is online now, so a live chat transfer can be offered.')
        public Boolean liveAvailable;
        @InvocableVariable(label='Within Hours' description='true when it is currently advising hours (Monday to Friday, 9:00 AM to 5:00 PM Eastern).')
        public Boolean withinHours;
        @InvocableVariable(label='Advising Hours' description='Advising hours to tell the student.')
        public String advisingHours;
        @InvocableVariable(label='Open Slots' description='Numbered list of the next open 30-minute call times. Each line ends with [slot YYYY-MM-DD HH:MM]; pass that code to Schedule Advisor Call and never show it to the student.')
        public String openSlots;
    }

    @InvocableMethod(label='Check Advisor Availability' description='Checks whether an admissions advisor can chat live right now (advising hours and an advisor online in Omni-Channel) and lists the next open 30-minute call times.')
    public static List<Response> check(List<Request> requests) {
        Boolean within = AdvisorCalendar.isWithinHours(AdvisorCalendar.now());
        Boolean online = within && AdvisorCalendar.advisorOnline();
        List<Response> out = new List<Response>();
        for (Request req : requests) {
            Integer count = req == null || req.slotCount == null || req.slotCount < 1 ? 4 : Math.min(req.slotCount, 8);
            Response res = new Response();
            res.withinHours = within;
            res.liveAvailable = online;
            res.advisingHours = AdvisorCalendar.HOURS_TEXT;
            res.openSlots = AdvisorCalendar.describe(AdvisorCalendar.openSlots(count));
            out.add(res);
        }
        return out;
    }
}