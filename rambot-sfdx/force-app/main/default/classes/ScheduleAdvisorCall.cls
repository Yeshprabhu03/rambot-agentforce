// Agent action: books a 30-minute call with an admissions advisor for any student, applicant or not.
// Saves the student as a Lead, creates the Advising Appointment and emails a confirmation.
// The time is checked here, not by the model: weekday, advising hours, at least an hour away, and not already taken.
public with sharing class ScheduleAdvisorCall {
    static final Set<String> TOPICS = new Set<String>{ 'Admissions', 'Financial Aid', 'Course Planning', 'Career Services' };

    public class Request {
        @InvocableVariable(label='First Name' required=true)
        public String firstName;
        @InvocableVariable(label='Last Name' required=true)
        public String lastName;
        @InvocableVariable(label='Email' required=true)
        public String email;
        @InvocableVariable(label='Slot' description='The call time as YYYY-MM-DD HH:MM in Eastern Time, 24-hour, e.g. 2026-11-13 14:00. Use the slot code from Check Advisor Availability, or the time the student asked for.' required=true)
        public String slot;
        @InvocableVariable(label='Topic' description='Optional: Admissions, Financial Aid, Course Planning or Career Services. Default Admissions.')
        public String topic;
        @InvocableVariable(label='Notes' description='One or two sentences for the advisor: what the student wants to discuss and any program of interest.')
        public String notes;
        @InvocableVariable(label='Program Interest' description='Optional: the program the student is interested in.')
        public String programInterest;
    }

    public class Response {
        @InvocableVariable(label='Booked' description='true only if the call was booked.')
        public Boolean booked;
        @InvocableVariable(label='Confirmation Number' description='The appointment number, e.g. ADV-0012. Blank if not booked.')
        public String confirmationNumber;
        @InvocableVariable(label='Call Time' description='The booked day and time in Eastern Time, to tell the student.')
        public String callTime;
        @InvocableVariable(label='Slot Error' description='Why the time could not be booked. Blank when booked.')
        public String slotError;
        @InvocableVariable(label='Other Open Slots' description='When the time could not be booked: the next open times, each ending with [slot YYYY-MM-DD HH:MM]. Never show the slot code to the student.')
        public String otherOpenSlots;
        @InvocableVariable(label='Email Result' description='Whether the confirmation email was sent.')
        public String emailResult;
    }

    @InvocableMethod(label='Schedule Advisor Call' description='Books a 30-minute call with a Gabelli admissions advisor at a weekday time between 9:00 AM and 5:00 PM Eastern, saves the student as a lead and emails them a confirmation.')
    public static List<Response> schedule(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request req : requests) {
            out.add(scheduleOne(req));
        }
        return out;
    }

    static Response scheduleOne(Request req) {
        Response res = new Response();
        res.booked = false;
        Datetime start = AdvisorCalendar.parseSlot(req.slot);
        String problem = start == null ? 'That time could not be read. Use a weekday date and time between 9:00 AM and 5:00 PM Eastern.' : AdvisorCalendar.slotProblem(start);
        if (problem != null) {
            res.slotError = problem;
            res.otherOpenSlots = AdvisorCalendar.describe(AdvisorCalendar.openSlots(4));
            return res;
        }
        if (String.isBlank(req.firstName) || String.isBlank(req.lastName) || String.isBlank(req.email) || !req.email.contains('@')) {
            res.slotError = 'A first name, last name and email address are needed to book the call.';
            return res;
        }
        String topic = String.isNotBlank(req.topic) && TOPICS.contains(req.topic.trim()) ? req.topic.trim() : 'Admissions';
        String notes = String.isBlank(req.notes) ? '' : req.notes.trim();
        try {
            Lead l = ProspectLeadCapture.upsertLead(req.firstName.trim(), req.lastName.trim(), req.email.trim().toLowerCase(), req.programInterest,
                null, null, null, 'Booked an advisor call for ' + AdvisorCalendar.label(start) + (notes == '' ? '.' : ': ' + notes));
            Advising_Appointment__c appt = new Advising_Appointment__c(Lead__c = l.Id, Appointment_Time__c = start, Status__c = 'Booked',
                Topic__c = topic, Call_Notes__c = notes.left(255));
            insert as user appt;
            res.booked = true;
            res.confirmationNumber = [SELECT Name FROM Advising_Appointment__c WHERE Id = :appt.Id WITH USER_MODE].Name;
            res.callTime = AdvisorCalendar.label(start);
            res.emailResult = sendConfirmation(l.Id, req.firstName.trim(), res.callTime, topic, res.confirmationNumber);
        } catch (Exception e) {
            res.booked = false;
            res.slotError = 'The call could not be booked right now (' + e.getMessage().left(150) + ').';
        }
        return res;
    }

    static String sendConfirmation(Id leadId, String firstName, String callTime, String topic, String confirmationNumber) {
        try {
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setTargetObjectId(leadId);
            msg.setSaveAsActivity(true);
            msg.setSenderDisplayName('Gabelli Graduate Admissions (RamBot)');
            msg.setReplyTo('admissionsgb@fordham.edu');
            msg.setSubject('Your call with Gabelli Graduate Admissions: ' + callTime);
            msg.setPlainTextBody('Hi ' + firstName + ',\n\nYour 30-minute call with a Gabelli graduate admissions advisor is booked.\n\n'
                + 'When: ' + callTime + '\nTopic: ' + topic + '\nConfirmation number: ' + confirmationNumber + '\n\n'
                + 'An advisor will contact you at this time. To change or cancel it, reply to this email.\n\n'
                + 'Gabelli Graduate Admissions, +1 212-636-6200');
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ msg });
            return 'A confirmation email was sent.';
        } catch (Exception e) {
            return 'The confirmation email could not be sent.';
        }
    }
}