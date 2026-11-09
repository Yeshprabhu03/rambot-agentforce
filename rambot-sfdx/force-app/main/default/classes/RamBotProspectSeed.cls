// Seeds the RamBot prospect data: 2026-27 program catalog (fordham.edu, read 2026-11-06)
// and upcoming Gabelli admissions events as Campaigns. Safe to re-run: matches on code, and on event name and date.
public with sharing class RamBotProspectSeed {
    // Name~Code~Degree~Format~Credits~Length~STEM~F1~Prereq~Starts~Pricing~Rate~Total~Enrichment~Terms~Track~IdealFor~URL
    static final List<String> PROGRAMS = new List<String>{
        'MS in Accounting~MSA~MS~On-campus (full- or part-time)~30~Full- or part-time; classes as little as one day per week~false~true~true~Fall; Spring; Summer~Per Credit~2303~~3939~3~On-campus MS~Bachelor\'s in business, finance, accounting or science with a basic understanding of accounting rules. Supplements an undergraduate accounting degree toward CPA educational requirements (does not meet CPA requirements alone).~https://www.fordham.edu/gabelli-school-of-business/academic-programs-and-admissions/graduate-programs/academic-programs/ms-programs/accounting/',
        'MS in Artificial Intelligence in Business~MSAIB~MS~On-campus (full- or part-time)~30~Three semesters full-time; part-time available~true~true~true~Fall; Summer~Per Credit~2303~~3939~3~On-campus MS~Bachelor\'s degree holders from any background, from professionals interested in AI across the enterprise to IT professionals.~https://www.fordham.edu/gabelli-school-of-business/academic-programs-and-admissions/graduate-programs/academic-programs/ms-programs/artificial-intelligence-in-business/',
        'MS in Business Analytics~MSBA~MS~On-campus (full- or part-time)~30~As little as 12 months full-time; part-time available~true~true~true~Fall; Summer~Per Credit~2303~~3939~3~On-campus MS~Undergraduate or graduate degree in a quantitative or analytic field such as statistics, mathematics, computer science, engineering, economics or business.~https://www.fordham.edu/gabelli-school-of-business/academic-programs-and-admissions/graduate-programs/academic-programs/ms-programs/business-analytics/',
        'MS in Finance~MSF~MS~On-campus (full- or part-time)~30~As little as 12 months~true~true~true~Fall; Summer~Per Credit~2303~~3939~3~On-campus MS~Bachelor\'s in business, finance, accounting and/or science with a basic understanding of financial markets and a desire for a finance career. Formerly the MS in Global Finance.~https://www.fordham.edu/gabelli-school-of-business/academic-programs-and-admissions/graduate-programs/academic-programs/ms-programs/finance/',
        'MS in Information Technology~MSIT~MS~On-campus (full- or part-time)~30~As little as 12 months full-time; part-time available~true~true~true~Fall~Per Credit~2303~~3939~3~On-campus MS~No tech background required; helpful to understand how information systems support organizations.~https://www.fordham.edu/gabelli-school-of-business/academic-programs-and-admissions/graduate-programs/academic-programs/ms-programs/information-technology/',
        'MS in Management~MSM~MS~On-campus, online or hybrid~30~12 months full-time or 20 months part-time~false~true~false~Fall~Per Credit~2303~~3939~3~On-campus MS~Bachelor\'s in any non-business field (liberal arts, STEM, social sciences) wanting a foundation in management.~https://www.fordham.edu/gabelli-school-of-business/academic-programs-and-admissions/graduate-programs/academic-programs/ms-programs/management/',
        'MS in Marketing Intelligence~MSMI~MS~On-campus~36~Full-time on campus~true~true~true~Fall~Per Credit~2303~~3939~3~On-campus MS~Prior experience in marketing, market research or advertising.~https://www.fordham.edu/gabelli-school-of-business/academic-programs-and-admissions/graduate-programs/academic-programs/ms-programs/marketing-intelligence/',
        'MS in Media Management~MSMM~MS~On-campus (full- or part-time)~36~One year full-time or two years part-time~true~true~false~Fall; Spring; Summer~Per Credit~2303~~3939~3~On-campus MS~Background in communications, media, marketing or entertainment.~https://www.fordham.edu/gabelli-school-of-business/academic-programs-and-admissions/graduate-programs/academic-programs/ms-programs/media-management/',
        'MS in Quantitative Finance~MSQF~MS~On-campus~39~Full-time on campus~true~true~true~Fall~Per Credit~2303~~3939~3~On-campus MS~Undergraduate degree in mathematics, physics, engineering, economics or computer science. 85-90% of graduates find jobs within three months of graduation.~https://www.fordham.edu/gabelli-school-of-business/academic-programs-and-admissions/graduate-programs/academic-programs/ms-programs/quantitative-finance/',
        'Online MS in Finance~MSF-ONLINE~MS~Online (live and self-paced)~30~7-8 week sessions; full- or part-time~true~false~true~Fall~Per Credit~2303~~3939~4~Online and MBA~All professional backgrounds welcome. Not eligible for an F-1 visa or STEM OPT.~https://www.fordham.edu/gabelli-school-of-business/academic-programs-and-admissions/graduate-programs/academic-programs/ms-programs/finance/',
        'Online MS in Management~MSM-ONLINE~MS~Online~30~12 months full-time or 20 months part-time~false~false~false~Fall~Per Credit~2303~~3939~4~Online and MBA~Non-business background wanting foundation-level business knowledge, studying online.~https://www.fordham.edu/gabelli-school-of-business/academic-programs-and-admissions/graduate-programs/academic-programs/ms-programs/management/',
        'Online MS in Strategic Marketing Communications~MSSMC~MS~Online (live evening classes)~33~12-22 months~false~false~true~Fall; Spring~Per Credit~1754~~3939~4~Online and MBA~Working professionals with professional experience in media, entertainment, advertising, marketing or public relations.~https://www.fordham.edu/gabelli-school-of-business/academic-programs-and-admissions/graduate-programs/academic-programs/ms-programs/online-strategic-marketing/',
        'Full-time MBA~FTMBA~MBA~On-campus cohort (full-time)~60~Two years full-time (cohort)~true~true~false~Fall~Flat~~133949~9133~4~On-campus MS~Professionals with at least 3-5 years of work experience who want to advance or pivot (finance, technology, management, marketing, accounting). 85% of the Class of 2025 seeking jobs accepted offers within 3 months.~https://www.fordham.edu/gabelli-school-of-business/academic-programs-and-admissions/graduate-programs/academic-programs/full-time-mba/',
        'Professional MBA~PMBA~MBA~Part-time evenings (6 p.m.), with online options and weekend intensives~45~About 21 months part-time~false~false~false~Fall; Spring~Per Credit~2303~~5068~6~Online and MBA~Working professionals who want an MBA while keeping their job.~https://www.fordham.edu/gabelli-school-of-business/academic-programs-and-admissions/graduate-programs/academic-programs/professional-mba/',
        'Executive MBA~EMBA~MBA~Part-time: one 3-day weekend per month~~22 months part-time~false~false~false~Fall; Spring~Flat~~145396~~5~Online and MBA~Mid-to-senior-level working professionals; includes a one-week international capstone.~https://www.fordham.edu/gabelli-school-of-business/academic-programs-and-admissions/graduate-programs/academic-programs/executive-mba/'
    };
    // Name~Date~Time~Focus~(V)irtual or (W)orld events page~Type
    static final List<String> EVENTS = new List<String>{
        'Application Insights: MS in Business Analytics and MS in Information Technology Programs Overview~2026-11-10~9:30 AM ET (online)~MS in Business Analytics and MS in Information Technology~V~Webinar',
        'Application Insights: MS in Media Management Program Overview~2026-11-10~9:30 AM ET (online)~MS in Media Management~V~Webinar',
        'Application Insights: FTMBA Program Overview~2026-11-11~9:00 AM ET (online)~FTMBA~V~Webinar',
        'Application Insights: MS in Quantitative Finance Program Overview~2026-11-11~9:00 AM ET (online)~MS in Quantitative Finance~V~Webinar',
        'Application Insights: MSSMC Online Program Overview~2026-11-11~9:00 AM ET (online)~MSSMC Online~V~Webinar',
        'Application Insights: MS in Accounting Program Overview~2026-11-11~9:30 AM ET (online)~MS in Accounting~V~Webinar',
        'Application Insights: Part-Time MBA Programs Overview~2026-11-11~1:00 PM ET (online)~Part-Time MBA~V~Webinar',
        'Application Insights: MS in Artificial Intelligence in Business~2026-11-12~9:00 AM ET (online)~MS in Artificial Intelligence in Business~V~Webinar',
        'Application Insights: MS in Management (MiM) Program Overview~2026-11-12~9:00 AM ET (online)~MS in Management (MiM)~V~Webinar',
        'Application Insights: MS in Finance Program Overview~2026-11-12~10:00 AM ET (online)~MS in Finance~V~Webinar',
        'Application Insights: MS in Marketing Intelligence and MS Business Analytics Programs Overview~2026-11-12~10:30 AM ET (online)~MS in Marketing Intelligence and MS Business Analytics~V~Webinar',
        'Application Insights: MS Finance Online Program Overview~2026-11-12~11:30 AM ET (online)~MS Finance Online~V~Webinar',
        'Application Insights: FTMBA Program Overview~2026-12-03~9:30 AM ET (online)~FTMBA~V~Webinar',
        'Application Insights: MS in Finance Program Overview~2026-12-08~9:30 AM ET (online)~MS in Finance~V~Webinar',
        'Application Insights: MS in Marketing Intelligence and MS Business Analytics Programs Overview~2026-12-09~9:30 AM ET (online)~MS in Marketing Intelligence and MS Business Analytics~V~Webinar',
        'Application Insights: MS in Accounting Program Overview~2026-12-10~9:30 AM ET (online)~MS in Accounting~V~Webinar',
        'Application Insights: MS in Business Analytics and MS in Information Technology Programs Overview~2026-12-10~9:30 AM ET (online)~MS in Business Analytics and MS in Information Technology~V~Webinar',
        'Application Insights: MS in Artificial Intelligence in Business~2026-12-11~9:30 AM ET (online)~MS in Artificial Intelligence in Business~V~Webinar',
        'Application Insights: MS in Quantitative Finance Program Overview~2026-12-11~9:30 AM ET (online)~MS in Quantitative Finance~V~Webinar',
        'Application Insights: MS in Marketing Intelligence / Media Management / Strategic Marketing Communications Programs Overview~2026-12-16~9:30 AM ET (online)~MS in Marketing Intelligence / Media Management / Strategic Marketing Communications~V~Webinar',
        'Application Insights: FTMBA Program Overview~2027-01-07~9:30 AM ET (online)~FTMBA~V~Webinar',
        'Application Insights: MS in Marketing Intelligence and MS Business Analytics Programs Overview~2027-01-19~9:30 AM ET (online)~MS in Marketing Intelligence and MS Business Analytics~V~Webinar',
        'Application Insights: MS in Accounting Program Overview~2027-01-20~9:30 AM ET (online)~MS in Accounting~V~Webinar',
        'Application Insights: MS in Media Management Program Overview~2027-01-20~9:30 AM ET (online)~MS in Media Management~V~Webinar',
        'Application Insights: MSSMC Online Program Overview~2027-01-20~12:00 PM ET (online)~MSSMC Online~V~Webinar',
        'Application Insights: MS in Business Analytics and MS in Information Technology Programs Overview~2027-01-21~9:30 AM ET (online)~MS in Business Analytics and MS in Information Technology~V~Webinar',
        'Application Insights: MS in Finance Program Overview~2027-01-21~9:30 AM ET (online)~MS in Finance~V~Webinar',
        'Application Insights: MS Finance Online Program Overview~2027-01-21~12:00 PM ET (online)~MS Finance Online~V~Webinar',
        'Application Insights: MS in Management (MiM) Program Overview~2027-01-22~9:00 AM ET (online)~MS in Management (MiM)~V~Webinar',
        'Application Insights: MS in Artificial Intelligence in Business~2027-01-22~9:30 AM ET (online)~MS in Artificial Intelligence in Business~V~Webinar',
        'Application Insights: MS in Quantitative Finance Program Overview~2027-01-22~9:30 AM ET (online)~MS in Quantitative Finance~V~Webinar',
        'On-the-Spot Admissions Day (Virtual)~2026-11-18~9:00 AM ET (online)~All programs~V~Webinar',
        'Ready to Pivot? Finding the Right Fit with Gabelli\'s Professional MBA and Executive MBA Programs~2026-12-14~12:00 PM ET (online)~Professional MBA; Executive MBA~V~Webinar',
        'MBA with a Family? Balancing Work, Life, and Your Goals in the Professional MBA or Executive MBA~2027-01-06~12:00 PM ET (online)~Professional MBA; Executive MBA~V~Webinar',
        'Premier EMBA: Executive MBA Event New York City~2026-11-21~5:45 PM (New York)~Executive MBA; New York City, New York, USA~W~Seminar / Conference',
        'QS Discover Masters - Dhaka~2026-11-30~5:00 PM (local time)~MS programs; Dhaka, Bangladesh~W~Seminar / Conference',
        'QS Discover Masters - Kolkata~2026-12-02~5:00 PM (local time)~MS programs; Kolkata, India~W~Seminar / Conference',
        'QS Discover Masters & MBA - New Delhi~2026-12-03~2:30 PM (local time)~MS and MBA programs; New Delhi, India~W~Seminar / Conference',
        'QS Discover Masters & MBA - Mumbai~2026-12-05~10:30 AM (local time)~MS and MBA programs; Mumbai, India~W~Seminar / Conference',
        'QS Discover Masters - Ahmedabad~2026-12-07~5:00 PM (local time)~MS programs; Ahmedabad, India~W~Seminar / Conference',
        'QS Discover Masters & MBA - Bangalore~2026-12-09~2:30 PM (local time)~MS and MBA programs; Bangalore, India~W~Seminar / Conference',
        'QS Discover Masters - Hyderabad~2026-12-12~1:00 PM (local time)~MS programs; Hyderabad, India~W~Seminar / Conference',
        'Access MBA: One-to-One MBA Event - Manila~2026-11-10~4:00 PM (local time)~MBA programs; Manila, Philippines~W~Seminar / Conference',
        'QS Discover Masters - Ho Chi Minh City~2026-11-07~1:00 PM (local time)~MS programs; Ho Chi Minh City, Vietnam~W~Seminar / Conference',
        'QS Discover Masters - Hanoi~2026-11-08~1:00 PM (local time)~MS programs; Hanoi, Vietnam~W~Seminar / Conference'
    };
    static final String VIRTUAL_URL = 'https://gradadmissions.fordham.edu/portal/DiscoverGabelli-VirtualEvents';
    static final String WORLD_URL = 'https://gradadmissions.fordham.edu/portal/discovergabelli';

    public static String run() {
        Map<String, Id> existing = new Map<String, Id>();
        for (Program__c p : [SELECT Id, Program_Code__c FROM Program__c]) existing.put(p.Program_Code__c, p.Id);
        List<Program__c> progs = new List<Program__c>();
        for (String row : PROGRAMS) {
            List<String> v = row.split('~', -1);
            progs.add(new Program__c(Id = existing.get(v[1]), Name = v[0], Program_Code__c = v[1], Degree_Type__c = v[2], Format__c = v[3],
                Credits__c = dec(v[4]), Length__c = v[5], STEM_Designated__c = v[6] == 'true', F1_Eligible__c = v[7] == 'true',
                Prerequisites__c = v[8] == 'true', Start_Terms__c = v[9], Pricing_Model__c = v[10], Rate_Per_Credit__c = dec(v[11]),
                Program_Total_Tuition__c = dec(v[12]), Enrichment_Fee__c = dec(v[13]), Typical_Terms__c = dec(v[14]),
                Deadline_Track__c = v[15], Ideal_For__c = v[16], Program_URL__c = v[17]));
        }
        upsert progs;

        Map<String, Id> existingCamps = new Map<String, Id>();
        for (Campaign c : [SELECT Id, Name, StartDate FROM Campaign WHERE Registration_URL__c != null]) existingCamps.put(c.Name + c.StartDate, c.Id);
        List<Campaign> evts = new List<Campaign>();
        for (String row : EVENTS) {
            List<String> v = row.split('~', -1);
            String name = v[0].left(80);
            Date d = Date.valueOf(v[1]);
            String url = v[4] == 'V' ? VIRTUAL_URL : WORLD_URL;
            evts.add(new Campaign(Id = existingCamps.get(name + d), Name = name, StartDate = d, EndDate = d, Event_Time__c = v[2],
                Program_Focus__c = v[3].left(150), Registration_URL__c = url, Type = v[5], Status = 'Planned', IsActive = true,
                Description = 'Gabelli School graduate admissions event. Register on Fordham\'s admissions portal: ' + url));
        }
        upsert evts;
        return '\nPrograms upserted: ' + progs.size() + '\nEvents upserted: ' + evts.size();
    }

    static Decimal dec(String s) {
        return String.isBlank(s) ? null : Decimal.valueOf(s);
    }
}