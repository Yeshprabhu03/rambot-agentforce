// One-time setup for the RamBot prospect features. Run from the RamBotSetup Visualforce page.
// Creates metadata through this org's own Tooling API, so it needs the RamBot_Self_Org remote site.
public with sharing class RamBotProspectSetup {
    public String log { get; set; }

    public RamBotProspectSetup() { log = ''; }

    public PageReference run() {
        String step = ApexPages.currentPage().getParameters().get('step');
        try {
            if (step == 'object') createProgramObject();
            else if (step == 'fields') createFields();
            else if (step == 'data') log += RamBotProspectSeed.run();
            else if (step == 'perms') log += RamBotProspectPerms.run();
            else if (step == 'reports') log += RamBotProspectReports.run();
            else if (step == 'chatsetup') log += RamBotProspectReports.runChatSetup();
            else if (step == 'chatperms') log += RamBotProspectReports.runChatPerms();
            else log += 'Pass ?step=object, fields, data, perms, chatsetup, chatperms or reports.';
        } catch (Exception e) {
            log += '\nERROR: ' + e.getMessage();
        }
        return null;
    }

    private void createProgramObject() {
        String xml = '<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:met="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
            + '<soapenv:Header><met:SessionHeader><met:sessionId>' + UserInfo.getSessionId() + '</met:sessionId></met:SessionHeader></soapenv:Header>'
            + '<soapenv:Body><met:createMetadata><met:metadata xsi:type="met:CustomObject"><met:fullName>Program__c</met:fullName>'
            + '<met:deploymentStatus>Deployed</met:deploymentStatus><met:description>Gabelli graduate programs with 2026-27 rates; read live by RamBot.</met:description>'
            + '<met:label>Program</met:label><met:nameField><met:label>Program Name</met:label><met:type>Text</met:type></met:nameField>'
            + '<met:pluralLabel>Programs</met:pluralLabel><met:sharingModel>ReadWrite</met:sharingModel></met:metadata></met:createMetadata></soapenv:Body></soapenv:Envelope>';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/Soap/m/62.0');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'text/xml; charset=UTF-8');
        req.setHeader('SOAPAction', '""');
        req.setBody(xml);
        req.setTimeout(60000);
        HttpResponse res = new Http().send(req);
        log += '\nProgram__c: ' + res.getStatusCode() + ' ' + res.getBody().left(600);
    }

    private void createFields() {
        List<Map<String, Object>> f = new List<Map<String, Object>>{
            text('Program__c.Program_Code__c', 'Program Code', 20),
            text('Program__c.Degree_Type__c', 'Degree Type', 10),
            text('Program__c.Format__c', 'Format', 150),
            num('Program__c.Credits__c', 'Credits', 4),
            text('Program__c.Length__c', 'Length', 150),
            box('Program__c.STEM_Designated__c', 'STEM Designated'),
            box('Program__c.F1_Eligible__c', 'F-1 Visa Eligible'),
            box('Program__c.Prerequisites__c', 'Prerequisites Required'),
            text('Program__c.Start_Terms__c', 'Start Terms', 60),
            text('Program__c.Pricing_Model__c', 'Pricing Model', 20),
            money('Program__c.Rate_Per_Credit__c', 'Rate Per Credit'),
            money('Program__c.Program_Total_Tuition__c', 'Program Total Tuition'),
            money('Program__c.Enrichment_Fee__c', 'Enrichment Fee'),
            num('Program__c.Typical_Terms__c', 'Typical Terms', 2),
            text('Program__c.Deadline_Track__c', 'Deadline Track', 40),
            longText('Program__c.Ideal_For__c', 'Ideal For'),
            url('Program__c.Program_URL__c', 'Program URL'),
            text('Lead.Program_Interest__c', 'Program Interest', 120),
            text('Lead.Intended_Term__c', 'Intended Term', 40),
            box('Lead.Is_International__c', 'International Applicant'),
            text('Campaign.Event_Time__c', 'Event Time', 60),
            url('Campaign.Registration_URL__c', 'Registration URL'),
            text('Campaign.Program_Focus__c', 'Program Focus', 150)
        };
        for (Map<String, Object> m : f) {
            tooling('CustomField', m);
        }
    }

    private Map<String, Object> field(String fullName, String label, Map<String, Object> md) {
        md.put('label', label);
        return new Map<String, Object>{ 'FullName' => fullName, 'Metadata' => md };
    }
    private Map<String, Object> text(String n, String l, Integer len) {
        return field(n, l, new Map<String, Object>{ 'type' => 'Text', 'length' => len });
    }
    private Map<String, Object> num(String n, String l, Integer p) {
        return field(n, l, new Map<String, Object>{ 'type' => 'Number', 'precision' => p, 'scale' => 0 });
    }
    private Map<String, Object> money(String n, String l) {
        return field(n, l, new Map<String, Object>{ 'type' => 'Currency', 'precision' => 12, 'scale' => 0 });
    }
    private Map<String, Object> box(String n, String l) {
        return field(n, l, new Map<String, Object>{ 'type' => 'Checkbox', 'defaultValue' => 'false' });
    }
    private Map<String, Object> longText(String n, String l) {
        return field(n, l, new Map<String, Object>{ 'type' => 'LongTextArea', 'length' => 5000, 'visibleLines' => 4 });
    }
    private Map<String, Object> url(String n, String l) {
        return field(n, l, new Map<String, Object>{ 'type' => 'Url' });
    }

    private void tooling(String sobjectType, Map<String, Object> body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/tooling/sobjects/' + sobjectType);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(body));
        req.setTimeout(60000);
        HttpResponse res = new Http().send(req);
        log += '\n' + body.get('FullName') + ': ' + res.getStatusCode() + ' ' + res.getBody().left(300);
    }
}