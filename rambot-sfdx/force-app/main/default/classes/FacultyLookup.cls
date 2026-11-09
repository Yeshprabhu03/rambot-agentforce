public without sharing class FacultyLookup {
    public class Request {
        @InvocableVariable(label='Faculty Name' description='Name of a Gabelli faculty member: full, first or last name, a nickname like Ben, or a misspelled name. Leave blank when listing faculty by department or topic. Do not include titles like Professor or Dr.' required=false)
        public String facultyName;
        @InvocableVariable(label='Department or Topic' description='Optional. A department or research topic such as Marketing, Finance or Data Science, used to list faculty in that area. Leave blank when looking up a specific person.' required=false)
        public String department;
    }

    public class Result {
        @InvocableVariable(label='Match Count' description='How many faculty members matched. 0 means none found.')
        public Integer matchCount;
        @InvocableVariable(label='Match Type' description='How results were found: name (exact or first-name prefix), fuzzy (spelling was close but not exact, so confirm with the user), department (topic matched title, department or research areas), related (topic only matched words in faculty bios, so describe them as related), or none.')
        public String matchType;
        @InvocableVariable(label='Matches' description='Matching faculty records with name, title, department, faculty type, research areas, education, bio and profile URL, best matches first.')
        public List<Faculty__c> matches;
    }

    static final Set<String> TITLES = new Set<String>{ 'professor', 'prof', 'dr', 'dean', 'mr', 'ms', 'mrs', 'phd', 'cpa' };

    // Words too generic to identify a topic at a business school.
    static final Set<String> GENERIC = new Set<String>{
        'business', 'management', 'school', 'gabelli', 'fordham', 'course', 'courses', 'class', 'classes',
        'teach', 'teaches', 'teaching', 'taught', 'faculty', 'professor', 'professors', 'who', 'what', 'which',
        'the', 'and', 'of', 'in', 'for', 'on', 'at', 'to', 'program', 'programs', 'ms', 'mba', 'graduate', 'studies', 'study'
    };

    @InvocableMethod(label='Find Faculty' description='Finds Gabelli School faculty by name (tolerates partial names, nicknames like Ben for Benjamin, and small typos) or lists faculty by department or research topic.')
    public static List<Result> find(List<Request> requests) {
        List<Faculty__c> everyone = [
            SELECT Name, Title__c, Department__c, Faculty_Type__c, Research_Areas__c, Education__c, Bio__c, Profile_URL__c
            FROM Faculty__c ORDER BY Name LIMIT 2000
        ];
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(search(req, everyone));
        }
        return results;
    }

    static Result search(Request req, List<Faculty__c> everyone) {
        Result res = new Result();
        res.matches = new List<Faculty__c>();
        res.matchType = 'none';

        List<String> q = words(req.facultyName);
        if (!q.isEmpty()) {
            for (Integer tier = 1; tier <= 3 && res.matches.isEmpty(); tier++) {
                for (Faculty__c f : everyone) {
                    if (allMatch(q, words(f.Name), tier)) {
                        res.matches.add(f);
                    }
                }
                if (!res.matches.isEmpty()) {
                    res.matchType = tier == 3 ? 'fuzzy' : 'name';
                }
            }
        }

        String topic = String.isNotBlank(req.department) ? req.department : (res.matches.isEmpty() ? req.facultyName : null);
        if (res.matches.isEmpty() && String.isNotBlank(topic)) {
            topicSearch(topic, everyone, res);
        }

        Integer cap = (res.matchType == 'department' || res.matchType == 'related') ? 25 : 10;
        while (res.matches.size() > cap) {
            res.matches.remove(res.matches.size() - 1);
        }
        res.matchCount = res.matches.size();
        return res;
    }

    // 1) Exact phrase in department, title or research areas (the original behaviour).
    // 2) Otherwise each meaningful word (stem) of the topic, scored: title/department/research hits count 3, bio hits count 1.
    static void topicSearch(String topic, List<Faculty__c> everyone, Result res) {
        String phrase = topic.trim().toLowerCase();
        List<Faculty__c> exact = new List<Faculty__c>();
        for (Faculty__c f : everyone) {
            if (core(f).contains(phrase)) {
                exact.add(f);
            }
        }

        List<String> stems = new List<String>();
        for (String w : phrase.split('[^a-z0-9]+')) {
            if (w.length() >= 3 && !GENERIC.contains(w)) {
                stems.add(stem(w));
            }
        }
        if (stems.isEmpty()) {
            res.matches.addAll(exact);
            if (!exact.isEmpty()) {
                res.matchType = 'department';
            }
            return;
        }

        Map<Id, Integer> score = new Map<Id, Integer>();
        Set<Id> exactIds = new Set<Id>();
        for (Faculty__c f : exact) {
            exactIds.add(f.Id);
        }
        Boolean anyCore = !exact.isEmpty();
        for (Faculty__c f : everyone) {
            String c = core(f);
            String bio = f.Bio__c == null ? '' : f.Bio__c.toLowerCase();
            Integer s = exactIds.contains(f.Id) ? 100 : 0;
            for (String st : stems) {
                if (c.contains(st)) {
                    s += 3;
                    anyCore = true;
                } else if (bio.contains(st)) {
                    s += 1;
                }
            }
            if (s > 0) {
                score.put(f.Id, s);
            }
        }

        // Highest score first; ties keep alphabetical order from the query.
        // When some faculty match in title, department or research areas, drop bio-only matches (score below 3).
        Integer floor = anyCore ? 3 : 1;
        List<Faculty__c> ranked = new List<Faculty__c>();
        for (Integer top = 100 + 3 * stems.size(); top >= floor; top--) {
            for (Faculty__c f : everyone) {
                if (score.get(f.Id) == top) {
                    ranked.add(f);
                }
            }
        }
        res.matches.addAll(ranked);
        if (!ranked.isEmpty()) {
            res.matchType = anyCore ? 'department' : 'related';
        }
    }

    static String core(Faculty__c f) {
        return (f.Department__c + ' | ' + f.Title__c + ' | ' + f.Research_Areas__c).toLowerCase();
    }

    // Light stemming so "analytics" matches "analytic" and "marketing" matches "market".
    static String stem(String w) {
        for (String suffix : new List<String>{ 'ing', 'ics', 'ies', 'es', 's' }) {
            if (w.length() > suffix.length() + 3 && w.endsWith(suffix)) {
                return w.substring(0, w.length() - suffix.length());
            }
        }
        return w;
    }

    static List<String> words(String s) {
        List<String> out = new List<String>();
        if (String.isBlank(s)) {
            return out;
        }
        for (String w : s.toLowerCase().split('[^a-z0-9]+')) {
            if (w.length() >= 2 && !TITLES.contains(w)) {
                out.add(w);
            }
        }
        return out;
    }

    static Boolean allMatch(List<String> q, List<String> name, Integer tier) {
        for (String t : q) {
            Boolean hit = false;
            for (String w : name) {
                if (w == t || (tier >= 2 && t.length() >= 3 && w.startsWith(t))
                    || (tier == 3 && t.length() >= 4 && w.getLevenshteinDistance(t) <= (t.length() <= 6 ? 1 : 2))) {
                    hit = true;
                    break;
                }
            }
            if (!hit) {
                return false;
            }
        }
        return true;
    }
}