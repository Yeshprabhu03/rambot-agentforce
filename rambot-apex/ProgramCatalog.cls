// Agent action: returns Gabelli graduate programs from the Program__c catalog (2026-27 rates) so RamBot can recommend a fit.
public with sharing class ProgramCatalog {
    public class Request {
        @InvocableVariable(label='Interest Keywords' description='Optional. Subject areas or goals in a few words, e.g. "analytics", "finance", "AI", "marketing", "management". Leave blank to get every program.')
        public String keywords;
        @InvocableVariable(label='Degree Type' description='Optional: MS or MBA. Leave blank for both.')
        public String degreeType;
        @InvocableVariable(label='STEM Only' description='Optional: true to return only STEM-designated programs (eligible for the 24-month STEM OPT extension).')
        public Boolean stemOnly;
        @InvocableVariable(label='Needs F-1 Visa' description='Optional: true if the student needs an F-1 student visa. Excludes online and part-time programs that cannot sponsor one.')
        public Boolean needsF1;
        @InvocableVariable(label='Online Only' description='Optional: true if the student wants to study online.')
        public Boolean onlineOnly;
    }

    public class Response {
        @InvocableVariable(label='Program Count' description='Number of programs returned.')
        public Integer programCount;
        @InvocableVariable(label='Programs' description='One block per program: credits, length, format, start terms, STEM and F-1 eligibility, 2026-27 tuition, who it suits, key courses, next application deadline and link.')
        public String programs;
    }

    @InvocableMethod(label='Get Program Options' description='Looks up Gabelli graduate programs with 2026-27 tuition, credits, length, format, start terms, STEM and F-1 visa eligibility, who each program suits and the next application deadline.')
    public static List<Response> getPrograms(List<Request> requests) {
        List<Response> out = new List<Response>();
        List<Program__c> all = [SELECT Name, Program_Code__c, Degree_Type__c, Format__c, Credits__c, Length__c, STEM_Designated__c,
            F1_Eligible__c, Start_Terms__c, Pricing_Model__c, Rate_Per_Credit__c, Program_Total_Tuition__c, Enrichment_Fee__c,
            Deadline_Track__c, Ideal_For__c, Key_Courses__c, Program_URL__c FROM Program__c WITH USER_MODE ORDER BY Degree_Type__c DESC, Name];
        for (Request req : requests) {
            List<Program__c> filtered = new List<Program__c>();
            for (Program__c p : all) {
                if (String.isNotBlank(req.degreeType) && !p.Degree_Type__c.equalsIgnoreCase(req.degreeType.trim())) continue;
                if (req.stemOnly == true && !p.STEM_Designated__c) continue;
                if (req.needsF1 == true && !p.F1_Eligible__c) continue;
                if (req.onlineOnly == true && !p.Format__c.containsIgnoreCase('online')) continue;
                filtered.add(p);
            }
            List<Program__c> matches = filterByKeywords(filtered, req.keywords);
            String note = '';
            if (matches.isEmpty() && !filtered.isEmpty()) {
                matches = filtered;
                note = 'No program matched the keywords exactly, so all programs that fit the other filters are listed.\n\n';
            }
            Response res = new Response();
            res.programCount = matches.size();
            List<String> blocks = new List<String>();
            for (Program__c p : matches) blocks.add(describe(p));
            res.programs = matches.isEmpty() ? 'No Gabelli program matches those requirements.' : note + String.join(blocks, '\n\n');
            out.add(res);
        }
        return out;
    }

    // Career goals and subject areas each program prepares students for (program data only describes backgrounds).
    static final Map<String, String> CAREERS = new Map<String, String>{
        'MSF' => 'finance; investment banking; banking; corporate finance; asset management; wealth management; private equity; equity research; financial analyst; markets; trading',
        'MSF-ONLINE' => 'finance; corporate finance; asset management; wealth management; financial analyst; markets',
        'MSQF' => 'quantitative finance; quant; investment banking; trading; risk management; derivatives; financial engineering; asset management; hedge fund; fintech; markets',
        'FTMBA' => 'mba; investment banking; consulting; strategy; leadership; general management; career switch; pivot; finance; marketing; product management',
        'PMBA' => 'mba; part-time mba; leadership; general management; career advancement',
        'EMBA' => 'executive mba; senior leadership; executive; general management',
        'MSA' => 'accounting; cpa; audit; assurance; tax',
        'MSBA' => 'business analytics; analytics; data science; data analyst; statistics; machine learning; business intelligence',
        'MSAIB' => 'artificial intelligence; ai; machine learning; generative ai; data science; automation',
        'MSIT' => 'information technology; it; information systems; cybersecurity; cloud; technology management; product management',
        'MSMI' => 'marketing; market research; consumer insights; marketing analytics; digital marketing; brand management',
        'MSMM' => 'media management; media; entertainment; communications; streaming; content',
        'MSSMC' => 'strategic communications; public relations; advertising; marketing communications; brand',
        'MSM' => 'management; business foundation; leadership; operations',
        'MSM-ONLINE' => 'management; business foundation; leadership'
    };

    static final Set<String> STOP = new Set<String>{ 'ms', 'in', 'of', 'and', 'the', 'program', 'programs', 'degree', 'masters', 'master',
        'want', 'career', 'careers', 'job', 'jobs', 'into', 'get', 'go', 'work', 'role', 'roles', 'field', 'a', 'an', 'to', 'for', 'my', 'from' };

    // Scores each program against the keywords and returns the strongest matches, best first.
    // Whole career phrases (e.g. "investment banking") count most, then name/code words, then career words, then "Ideal for" text.
    // Programs scoring under half of the best score are dropped so weak matches don't pad the list.
    static List<Program__c> filterByKeywords(List<Program__c> programs, String keywords) {
        if (String.isBlank(keywords)) return programs;
        String kw = ' ' + keywords.toLowerCase().replaceAll('[^a-z0-9]+', ' ').trim() + ' ';
        List<String> words = new List<String>();
        for (String w : kw.trim().split(' ')) {
            if (w.length() > 1 && !STOP.contains(w)) words.add(w);
        }
        if (words.isEmpty()) return programs;

        Map<String, Integer> score = new Map<String, Integer>();
        Integer best = 0;
        for (Program__c p : programs) {
            String nameHay = (p.Name + ' ' + p.Program_Code__c).toLowerCase();
            String careers = CAREERS.containsKey(p.Program_Code__c) ? CAREERS.get(p.Program_Code__c) : '';
            String ideal = (p.Ideal_For__c == null ? '' : p.Ideal_For__c).toLowerCase();
            Integer s = 0;
            for (String phrase : careers.split(';')) {
                String ph = phrase.trim();
                if (ph.contains(' ') && kw.contains(' ' + ph + ' ')) s += 6;
            }
            String careerWords = ' ' + careers.replaceAll('[^a-z0-9]+', ' ') + ' ';
            for (String w : words) {
                if (nameHay.contains(w)) s += 3;
                else if (careerWords.contains(' ' + w + ' ')) s += 2;
                else if (ideal.contains(w)) s += 1;
            }
            score.put(p.Program_Code__c, s);
            if (s > best) best = s;
        }
        List<Program__c> hits = new List<Program__c>();
        if (best == 0) return hits;
        Integer floor = Math.max(2, best / 2);
        for (Integer level = best; level >= floor; level--) {
            for (Program__c p : programs) {
                if (score.get(p.Program_Code__c) == level) hits.add(p);
            }
        }
        return hits;
    }

    public static String describe(Program__c p) {
        String tuition = p.Pricing_Model__c == 'Flat'
            ? money(p.Program_Total_Tuition__c) + ' total program tuition (flat rate)'
            : money(p.Rate_Per_Credit__c) + ' per credit' + (p.Credits__c != null ? ' (about ' + money(p.Rate_Per_Credit__c * p.Credits__c) + ' for ' + p.Credits__c + ' credits)' : '');
        return p.Name + ' (' + p.Program_Code__c + ')'
            + '\n- Credits: ' + (p.Credits__c == null ? 'see program page' : String.valueOf(p.Credits__c))
            + '\n- Length: ' + p.Length__c
            + '\n- Format: ' + p.Format__c
            + '\n- Start terms: ' + p.Start_Terms__c
            + '\n- STEM-designated: ' + (p.STEM_Designated__c ? 'Yes (eligible for the 24-month STEM OPT extension if on an F-1 visa)' : 'No')
            + '\n- F-1 student visa: ' + (p.F1_Eligible__c ? 'Yes' : 'No (online or part-time program)')
            + '\n- 2026-27 tuition: ' + tuition
            + (p.Enrichment_Fee__c != null ? '\n- One-time enrichment fee: ' + money(p.Enrichment_Fee__c) : '')
            + '\n- Ideal for: ' + p.Ideal_For__c
            + (String.isNotBlank(p.Key_Courses__c) ? '\n- Key courses: ' + p.Key_Courses__c : '')
            + '\n- Next deadline: ' + nextDeadline(p);
    }

    // Chat replies avoid links (the Trust Layer redacts untrusted URLs); emails include the program page.
    public static String describeWithLink(Program__c p) {
        return describe(p) + '\n- Program page: ' + p.Program_URL__c;
    }

    // Deadlines from the Gabelli graduate admissions deadlines page (read 2026-11-06).
    public static String nextDeadline(Program__c p) {
        Date today = Date.today();
        List<String> parts = new List<String>();
        if ((p.Program_Code__c == 'PMBA' || p.Program_Code__c == 'EMBA') && today <= Date.newInstance(2027, 1, 8)) {
            parts.add('Spring 2027 rolling admissions until January 8, 2027');
        }
        if (p.Deadline_Track__c == 'On-campus MS') {
            if (today <= Date.newInstance(2027, 1, 15)) parts.add('Fall 2027 Round 2: January 15, 2027 (priority scholarship consideration; decision by March 19, 2027)');
            if (today <= Date.newInstance(2027, 3, 19)) parts.add('Fall 2027 Round 3: March 19, 2027 (last date for international applicants who need a visa from abroad)');
            if (parts.isEmpty() || today > Date.newInstance(2027, 3, 19)) parts.add('Fall 2027 Round 4: rolling admissions for domestic applicants and international applicants already in the U.S.');
        } else {
            if (today <= Date.newInstance(2027, 2, 19)) parts.add('Fall 2027 Round 1: February 19, 2027 (application fee waived and priority scholarship consideration)');
            else if (today <= Date.newInstance(2027, 5, 7)) parts.add('Fall 2027 Round 2: May 7, 2027 (merit scholarship consideration)');
            else if (today <= Date.newInstance(2027, 7, 9)) parts.add('Fall 2027 Round 3: July 9, 2027');
        }
        return parts.isEmpty() ? 'see the Graduate Admissions Deadlines page' : String.join(parts, '; ');
    }

    public static String money(Decimal d) {
        return d == null ? '' : '$' + d.setScale(0).format();
    }
}