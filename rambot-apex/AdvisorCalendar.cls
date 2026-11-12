// Advising hours and open call times for RamBot.
// Hours: Monday to Friday, 9:00 AM to 5:00 PM Eastern Time. Calls are 30 minutes; one advisor, so one call per time.
// Public holidays are not modelled yet.
public with sharing class AdvisorCalendar {
    public static final String QUEUE_NAME = 'Admissions Advisors';
    public static final String HOURS_TEXT = 'Monday to Friday, 9:00 AM to 5:00 PM Eastern Time';
    static final String TZ = 'America/New_York';
    static final Integer OPEN_HOUR = 9;
    static final Integer CLOSE_HOUR = 17;
    static final Integer SLOT_MINUTES = 30;
    static final Integer MIN_NOTICE_MINUTES = 60;
    static final Integer DAYS_AHEAD = 14;

    @TestVisible static Datetime nowOverride;

    public static Datetime now() {
        return nowOverride != null ? nowOverride : Datetime.now();
    }

    // True on a weekday between 9:00 AM and 5:00 PM Eastern.
    public static Boolean isWithinHours(Datetime t) {
        Integer weekday = Integer.valueOf(t.format('u', TZ));
        Integer minutes = Integer.valueOf(t.format('H', TZ)) * 60 + Integer.valueOf(t.format('m', TZ));
        return weekday <= 5 && minutes >= OPEN_HOUR * 60 && minutes < CLOSE_HOUR * 60;
    }

    // An Eastern wall-clock time as a Datetime, correct across daylight saving changes.
    public static Datetime fromEastern(Date d, Integer hour, Integer minute) {
        TimeZone et = TimeZone.getTimeZone(TZ);
        Datetime wall = Datetime.newInstanceGmt(d, Time.newInstance(hour, minute, 0, 0));
        Datetime guess = wall.addSeconds(-et.getOffset(wall) / 1000);
        return wall.addSeconds(-et.getOffset(guess) / 1000);
    }

    // Parses "YYYY-MM-DD HH:MM" (24-hour, Eastern). Returns null if it isn't in that form.
    public static Datetime parseSlot(String s) {
        if (String.isBlank(s)) {
            return null;
        }
        Matcher m = Pattern.compile('(\\d{4})-(\\d{1,2})-(\\d{1,2})[ T](\\d{1,2}):(\\d{2}).*').matcher(s.trim());
        if (!m.matches()) {
            return null;
        }
        try {
            Date d = Date.newInstance(Integer.valueOf(m.group(1)), Integer.valueOf(m.group(2)), Integer.valueOf(m.group(3)));
            if (d.month() != Integer.valueOf(m.group(2)) || d.day() != Integer.valueOf(m.group(3))) {
                return null;
            }
            return fromEastern(d, Integer.valueOf(m.group(4)), Integer.valueOf(m.group(5)));
        } catch (Exception e) {
            return null;
        }
    }

    // Why a start time can't be booked, or null if it is a valid call time.
    public static String slotProblem(Datetime start) {
        Integer weekday = Integer.valueOf(start.format('u', TZ));
        Integer hour = Integer.valueOf(start.format('H', TZ));
        Integer minute = Integer.valueOf(start.format('m', TZ));
        if (weekday > 5) {
            return 'That day is a weekend. Advisor calls are ' + HOURS_TEXT + '.';
        }
        if (hour < OPEN_HOUR || hour * 60 + minute + SLOT_MINUTES > CLOSE_HOUR * 60) {
            return 'That time is outside advising hours (' + HOURS_TEXT + ').';
        }
        if (Math.mod(minute, SLOT_MINUTES) != 0) {
            return 'Calls start on the hour or half hour.';
        }
        if (start < now().addMinutes(MIN_NOTICE_MINUTES)) {
            return 'That time has passed or is less than an hour away.';
        }
        if (booked(start, start.addMinutes(1)).contains(start.getTime())) {
            return 'That time is already taken.';
        }
        return null;
    }

    // Start times of calls already booked in a window.
    static Set<Long> booked(Datetime fromT, Datetime toT) {
        Set<Long> taken = new Set<Long>();
        for (Advising_Appointment__c a : [SELECT Appointment_Time__c FROM Advising_Appointment__c
                WHERE Status__c = 'Booked' AND Appointment_Time__c >= :fromT AND Appointment_Time__c < :toT WITH USER_MODE]) {
            taken.add(a.Appointment_Time__c.getTime());
        }
        return taken;
    }

    // The next open call times: at most one morning and one afternoon time per day, so the choices are spread out.
    public static List<Datetime> openSlots(Integer count) {
        List<Datetime> out = new List<Datetime>();
        Datetime earliest = now().addMinutes(MIN_NOTICE_MINUTES);
        Date today = Date.valueOf(now().format('yyyy-MM-dd', TZ));
        Set<Long> taken = booked(now(), now().addDays(DAYS_AHEAD + 1));
        for (Integer i = 0; i <= DAYS_AHEAD && out.size() < count; i++) {
            Date d = today.addDays(i);
            Boolean morning = false;
            Boolean afternoon = false;
            for (Integer m = OPEN_HOUR * 60; m + SLOT_MINUTES <= CLOSE_HOUR * 60 && out.size() < count; m += SLOT_MINUTES) {
                Datetime start = fromEastern(d, m / 60, Math.mod(m, 60));
                Boolean isMorning = m < 12 * 60;
                if (Integer.valueOf(start.format('u', TZ)) > 5 || start < earliest || taken.contains(start.getTime())
                        || (isMorning && morning) || (!isMorning && (afternoon || m < 13 * 60))) {
                    continue;
                }
                out.add(start);
                if (isMorning) {
                    morning = true;
                } else {
                    afternoon = true;
                }
            }
        }
        return out;
    }

    // "Thursday, November 12 at 2:00 PM ET"
    public static String label(Datetime t) {
        return t.format('EEEE, MMMM d', TZ) + ' at ' + t.format('h:mm a', TZ) + ' ET';
    }

    // "2026-11-12 14:00", the form the agent passes back when booking.
    public static String code(Datetime t) {
        return t.format('yyyy-MM-dd HH:mm', TZ);
    }

    // Numbered list for the agent: label plus the slot code to book it with.
    public static String describe(List<Datetime> slots) {
        if (slots.isEmpty()) {
            return 'No open times in the next two weeks.';
        }
        List<String> lines = new List<String>();
        Integer i = 1;
        for (Datetime t : slots) {
            lines.add(i++ + '. ' + label(t) + ' [slot ' + code(t) + ']');
        }
        return String.join(lines, '\n');
    }

    // True when an Admissions Advisors queue member is set to an Available status in Omni-Channel.
    public static Boolean advisorOnline() {
        return new Presence().check(QUEUE_NAME);
    }

    // Without sharing on purpose: the agent user can't see other users' presence records, and this
    // returns only a yes/no, never who is online.
    without sharing class Presence {
        Boolean check(String queueName) {
            Set<Id> members = new Set<Id>();
            for (GroupMember gm : [SELECT UserOrGroupId FROM GroupMember
                    WHERE Group.Type = 'Queue' AND Group.Name = :queueName WITH SYSTEM_MODE]) {
                members.add(gm.UserOrGroupId);
            }
            return !members.isEmpty() && [SELECT COUNT() FROM UserServicePresence
                WHERE IsCurrentState = true AND ServicePresenceStatus.DeveloperName LIKE 'Available%' AND UserId IN :members WITH SYSTEM_MODE] > 0;
        }
    }
}
