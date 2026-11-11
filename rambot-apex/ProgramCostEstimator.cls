// Agent action: calculates a 2026-27 cost estimate for one program so RamBot never does money math itself.
public with sharing class ProgramCostEstimator {
    // 2026-27 graduate fees from Fordham Student Financial Services (read 2026-11-06).
    static final Decimal FEES_PER_TERM = 377;
    static final Decimal HEALTH_INSURANCE_PER_YEAR = 1890 + 3342;
    static final Decimal INTERNATIONAL_FEE = 50;
    static final Decimal LIVING_COSTS_PER_YEAR = 36954;
    // Assumption for part-time estimates: two courses (6 credits) per term, three terms a year.
    static final Decimal PART_TIME_CREDITS_PER_TERM = 6;

    public class Request {
        @InvocableVariable(label='Program' description='Program name or code, e.g. "MS in Business Analytics" or "MSBA".' required=true)
        public String program;
        @InvocableVariable(label='International Student' description='Optional: true if the student will study on an F-1 visa. Adds the international service fee and health insurance.')
        public Boolean isInternational;
        @InvocableVariable(label='Include Living Costs' description='Optional: true to add Fordham estimated food, housing, books, transport and personal costs.')
        public Boolean includeLivingCosts;
        @InvocableVariable(label='Study Mode' description='Optional: Full-time or Part-time. Part-time assumes about 6 credits per term (Fall, Spring and Summer), so more terms of fees and a longer program. Leave blank for full-time.')
        public String studyMode;
    }

    public class Response {
        @InvocableVariable(label='Estimate' description='Line-by-line cost breakdown with totals and assumptions. Read it to the student as written.')
        public String estimate;
        @InvocableVariable(label='Direct Cost Total' description='Tuition plus required fees billed by Fordham, in US dollars.')
        public Decimal directTotal;
        @InvocableVariable(label='Program Found' description='true if the program was found.')
        public Boolean found;
    }

    @InvocableMethod(label='Estimate Program Cost' description='Calculates the 2026-27 cost of a Gabelli graduate program: tuition, fees, enrichment fee, and optionally international fees, health insurance and living costs.')
    public static List<Response> estimate(List<Request> requests) {
        List<Program__c> all = [SELECT Name, Program_Code__c, Credits__c, Pricing_Model__c, Rate_Per_Credit__c, Program_Total_Tuition__c,
            Enrichment_Fee__c, Typical_Terms__c, Length__c FROM Program__c WITH USER_MODE];
        List<Response> out = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            Program__c p = findProgram(all, req.program);
            if (p == null) {
                List<String> names = new List<String>();
                for (Program__c q : all) names.add(q.Name);
                res.found = false;
                res.estimate = 'Program not found. Gabelli graduate programs: ' + String.join(names, '; ');
                out.add(res);
                continue;
            }
            Boolean intl = req.isInternational == true;
            Boolean partTime = req.studyMode != null && req.studyMode.toLowerCase().contains('part') && p.Pricing_Model__c != 'Flat' && p.Credits__c != null;
            Integer terms = p.Typical_Terms__c == null ? 2 : p.Typical_Terms__c.intValue();
            if (partTime) terms = Math.max(terms, (Integer) Math.ceil(p.Credits__c / PART_TIME_CREDITS_PER_TERM));
            Integer years = partTime ? (Integer) Math.ceil(terms / 3.0) : (terms <= 3 ? 1 : 2);
            Decimal tuition = p.Pricing_Model__c == 'Flat' ? p.Program_Total_Tuition__c : p.Rate_Per_Credit__c * p.Credits__c;
            Decimal fees = FEES_PER_TERM * terms;
            Decimal enrichment = p.Enrichment_Fee__c == null ? 0 : p.Enrichment_Fee__c;
            Decimal intlFee = intl ? INTERNATIONAL_FEE : 0;
            Decimal health = intl ? HEALTH_INSURANCE_PER_YEAR * years : 0;
            Decimal direct = tuition + fees + enrichment + intlFee + health;

            List<String> lines = new List<String>{ p.Name + ' - estimated 2026-27 cost (' + (partTime ? 'part-time, about ' + terms + ' terms over ' + years + ' years' : p.Length__c) + ')' };
            lines.add(p.Pricing_Model__c == 'Flat'
                ? '- Tuition: ' + m(tuition) + ' (flat program rate)'
                : '- Tuition: ' + p.Credits__c + ' credits x ' + m(p.Rate_Per_Credit__c) + ' = ' + m(tuition));
            lines.add('- Required general and technology fees: ' + m(FEES_PER_TERM) + ' per term x ' + terms + ' terms = ' + m(fees));
            if (enrichment > 0) lines.add('- One-time enrichment fee (first term): ' + m(enrichment));
            if (intl) {
                lines.add('- International student service fee: ' + m(intlFee));
                lines.add('- Fordham health insurance: ' + m(HEALTH_INSURANCE_PER_YEAR) + ' per year x ' + years + ' = ' + m(health) + ' (waivable with comparable coverage)');
            }
            lines.add('Total billed by Fordham: ' + m(direct));
            Decimal total = direct;
            if (req.includeLivingCosts == true) {
                Decimal living = LIVING_COSTS_PER_YEAR * years;
                total += living;
                lines.add('- Estimated living costs (food, housing, books, transport, personal): ' + m(LIVING_COSTS_PER_YEAR) + ' per year x ' + years + ' = ' + m(living));
                lines.add('Estimated total cost of attendance: ' + m(total));
            }
            lines.add('Assumptions: 2026-27 rates for students entering Fall 2023 or later; ' + terms + ' terms' + (partTime ? ' at about 6 credits per term' : '') + '; rates may rise in later years. '
                + (partTime ? 'Tuition is the same total because it is charged per credit; part-time adds terms of fees, and F-1 students must study full-time. ' : '')
                + 'Merit scholarships ($5,000-$30,000 for MS programs, up to full tuition for the Full-time MBA) would reduce this. '
                + 'Confirm with Student Financial Services.');
            res.found = true;
            res.directTotal = direct;
            res.estimate = String.join(lines, '\n');
            out.add(res);
        }
        return out;
    }

    static Program__c findProgram(List<Program__c> all, String input) {
        if (String.isBlank(input)) return null;
        String s = input.trim().toLowerCase();
        for (Program__c p : all) if (p.Program_Code__c.toLowerCase() == s || p.Name.toLowerCase() == s) return p;
        Program__c best;
        Integer bestScore = 0;
        Set<String> stop = new Set<String>{ 'ms', 'in', 'of', 'and', 'the', 'program', 'degree', 'master', 'masters' };
        for (Program__c p : all) {
            String name = p.Name.toLowerCase();
            Integer score = 0;
            for (String w : s.split('[^a-z0-9]+')) if (w.length() > 1 && !stop.contains(w) && name.contains(w)) score++;
            if (s.contains('online') != name.contains('online')) score--;
            if (score > bestScore) { bestScore = score; best = p; }
        }
        return best;
    }

    static String m(Decimal d) {
        return '$' + d.setScale(0).format();
    }
}