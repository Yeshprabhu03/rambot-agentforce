// Creates the RamBot admissions reports (Analytics REST API) and dashboard (Metadata API). Fixed definitions only.
public with sharing class RamBotProspectReports {
    static final String RAMBOT_SOURCE = 'RamBot Web Chat';
    static String folderId;

    public static String run() {
        String log = '';
        if ([SELECT COUNT() FROM Folder WHERE DeveloperName = 'RamBot_Reports'] == 0) {
            log += soap('<met:metadata xsi:type="met:ReportFolder"><met:fullName>RamBot_Reports</met:fullName><met:accessType>Public</met:accessType>'
                + '<met:name>RamBot Reports</met:name><met:publicFolderAccess>ReadWrite</met:publicFolderAccess></met:metadata>');
        }
        List<Folder> folders = [SELECT Id FROM Folder WHERE DeveloperName = 'RamBot_Reports' LIMIT 1];
        if (folders.isEmpty()) return log + '\nReport folder not created.';
        folderId = folders[0].Id;
        Map<String, String> reports = new Map<String, String>{
            'RamBot Leads by Program' => leadReport('RamBot Leads by Program', 'Lead.Program_Interest__c', 'None'),
            'RamBot Leads by Day' => leadReport('RamBot Leads by Day', 'CREATED_DATE', 'Day'),
            'RamBot Leads by Intended Term' => leadReport('RamBot Leads by Intended Term', 'Lead.Intended_Term__c', 'None'),
            'RamBot Info Session Registrations' => campaignReport(),
            'RamBot Chats by Handler' => chatReport()
        };
        Map<String, Id> existing = new Map<String, Id>();
        for (Report r : [SELECT Id, Name FROM Report WHERE Name IN :reports.keySet()]) existing.put(r.Name, r.Id);
        for (String name : reports.keySet()) {
            log += existing.containsKey(name)
                ? call('PATCH', '/services/data/v62.0/analytics/reports/' + existing.get(name), 'application/json', reports.get(name)).left(200)
                : call('POST', '/services/data/v62.0/analytics/reports', 'application/json', reports.get(name)).left(200);
        }

        Map<String, String> devNames = new Map<String, String>();
        for (Report r : [SELECT Name, DeveloperName FROM Report WHERE Name IN :reports.keySet()]) devNames.put(r.Name, r.DeveloperName);
        log += '\nReports found: ' + devNames.size();
        if (devNames.size() < 5) return log;

        log += soap('<met:metadata xsi:type="met:DashboardFolder"><met:fullName>RamBot_Dashboards</met:fullName><met:accessType>Public</met:accessType>'
            + '<met:name>RamBot Dashboards</met:name><met:publicFolderAccess>ReadWrite</met:publicFolderAccess></met:metadata>');
        String left = component('Column', 'Prospects captured by program interest', devNames.get('RamBot Leads by Program'))
            + component('Bar', 'Info session registrations', devNames.get('RamBot Info Session Registrations'));
        String right = component('Line', 'Prospects captured per day', devNames.get('RamBot Leads by Day'))
            + component('Bar', 'Prospects by intended start term', devNames.get('RamBot Leads by Intended Term'))
            + component('Bar', 'Chats handled by RamBot vs handed to an advisor', devNames.get('RamBot Chats by Handler'));
        log += soapOp('upsertMetadata', '<met:metadata xsi:type="met:Dashboard"><met:fullName>RamBot_Dashboards/RamBot_Admissions_Impact</met:fullName>'
            + '<met:backgroundEndColor>#FFFFFF</met:backgroundEndColor><met:backgroundFadeDirection>Diagonal</met:backgroundFadeDirection>'
            + '<met:backgroundStartColor>#FFFFFF</met:backgroundStartColor><met:dashboardType>SpecifiedUser</met:dashboardType>'
            + '<met:description>Prospective students RamBot captured as leads and event registrations from web chat.</met:description>'
            + '<met:leftSection><met:columnSize>Wide</met:columnSize>' + left + '</met:leftSection>'
            + '<met:rightSection><met:columnSize>Wide</met:columnSize>' + right + '</met:rightSection>'
            + '<met:runningUser>' + UserInfo.getUserName() + '</met:runningUser><met:textColor>#000000</met:textColor>'
            + '<met:title>RamBot Admissions Impact</met:title><met:titleColor>#000000</met:titleColor><met:titleSize>12</met:titleSize></met:metadata>');
        return log;
    }

    static String leadReport(String name, String grouping, String granularity) {
        List<String> columns = new List<String>();
        for (String c : new List<String>{ 'FIRST_NAME', 'LAST_NAME', 'EMAIL', 'Lead.Program_Interest__c', 'Lead.Intended_Term__c', 'Lead.Is_International__c', 'CREATED_DATE' }) {
            if (c != grouping) columns.add(c);
        }
        return JSON.serialize(new Map<String, Object>{ 'reportMetadata' => new Map<String, Object>{
            'name' => name, 'reportFormat' => 'SUMMARY', 'folderId' => folderId, 'scope' => 'org',
            'reportType' => new Map<String, Object>{ 'type' => 'LeadList' },
            'detailColumns' => columns,
            'groupingsDown' => new List<Object>{ new Map<String, Object>{ 'name' => grouping, 'sortOrder' => 'Asc', 'dateGranularity' => granularity } },
            'aggregates' => new List<String>{ 'RowCount' },
            'reportFilters' => new List<Object>{ new Map<String, Object>{ 'column' => 'LEAD_SOURCE', 'operator' => 'equals', 'value' => RAMBOT_SOURCE } },
            'standardDateFilter' => new Map<String, Object>{ 'column' => 'CREATED_DATE', 'durationValue' => 'CUSTOM', 'startDate' => null, 'endDate' => null }
        } });
    }

    static String campaignReport() {
        return JSON.serialize(new Map<String, Object>{ 'reportMetadata' => new Map<String, Object>{
            'name' => 'RamBot Info Session Registrations', 'reportFormat' => 'SUMMARY', 'folderId' => folderId, 'scope' => 'org',
            'reportType' => new Map<String, Object>{ 'type' => 'CampaignList' },
            'detailColumns' => new List<String>{ 'START_DATE', 'Campaign.Event_Time__c', 'NUM_RESPONSES' },
            'groupingsDown' => new List<Object>{ new Map<String, Object>{ 'name' => 'CAMPAIGN_NAME', 'sortOrder' => 'Asc', 'dateGranularity' => 'None' } },
            'aggregates' => new List<String>{ 'RowCount' },
            'reportFilters' => new List<Object>{ new Map<String, Object>{ 'column' => 'Campaign.Registration_URL__c', 'operator' => 'notEqual', 'value' => '' } }
        } });
    }

    // Chat metrics: a formula field marks each chat as handled by RamBot alone or handed to an advisor (it has a handoff summary).
    public static String runChatSetup() {
        return soap('<met:metadata xsi:type="met:CustomField"><met:fullName>MessagingSession.Handled_By__c</met:fullName>'
                + '<met:description>RamBot only, or Handed to advisor when RamBot wrote a handoff summary before transferring.</met:description>'
                + '<met:formula>IF(ISBLANK(Handoff_Summary__c), "RamBot only", "Handed to advisor")</met:formula>'
                + '<met:formulaTreatBlanksAs>BlankAsZero</met:formulaTreatBlanksAs><met:label>Handled By</met:label><met:type>Text</met:type></met:metadata>')
            + soap('<met:metadata xsi:type="met:ReportType"><met:fullName>RamBot_Messaging_Sessions</met:fullName><met:baseObject>MessagingSession</met:baseObject>'
                + '<met:category>other</met:category><met:deployed>true</met:deployed><met:description>Web chat sessions for RamBot reporting.</met:description>'
                + '<met:label>RamBot Messaging Sessions</met:label><met:sections>'
                + chatColumn('Name') + chatColumn('Status') + chatColumn('CreatedDate') + chatColumn('Handled_By__c') + chatColumn('Handoff_Summary__c')
                + '<met:masterLabel>Messaging Sessions</met:masterLabel></met:sections></met:metadata>');
    }

    public static String runChatPerms() {
        PermissionSet admin = [SELECT Id FROM PermissionSet WHERE IsOwnedByProfile = true AND Profile.Name = 'System Administrator' LIMIT 1];
        if ([SELECT COUNT() FROM FieldPermissions WHERE ParentId = :admin.Id AND Field = 'MessagingSession.Handled_By__c'] > 0) return '\nHandled By already readable';
        Database.SaveResult r = Database.insert(new FieldPermissions(ParentId = admin.Id, SobjectType = 'MessagingSession', Field = 'MessagingSession.Handled_By__c', PermissionsRead = true, PermissionsEdit = false), false);
        return '\nHandled By read access: ' + (r.isSuccess() ? 'added' : r.getErrors()[0].getMessage());
    }

    static String chatColumn(String field) {
        return '<met:columns><met:checkedByDefault>true</met:checkedByDefault><met:field>' + field + '</met:field><met:table>MessagingSession</met:table></met:columns>';
    }

    static String chatReport() {
        return JSON.serialize(new Map<String, Object>{ 'reportMetadata' => new Map<String, Object>{
            'name' => 'RamBot Chats by Handler', 'reportFormat' => 'SUMMARY', 'folderId' => folderId, 'scope' => 'organization',
            'reportType' => new Map<String, Object>{ 'type' => 'RamBot_Messaging_Sessions__c' },
            'detailColumns' => new List<String>{ 'MessagingSession.Name', 'MessagingSession.Status', 'MessagingSession.CreatedDate' },
            'groupingsDown' => new List<Object>{ new Map<String, Object>{ 'name' => 'MessagingSession.Handled_By__c', 'sortOrder' => 'Asc', 'dateGranularity' => 'None' } },
            'aggregates' => new List<String>{ 'RowCount' }
        } });
    }

    static String component(String type, String header, String reportDevName) {
        return '<met:components><met:autoselectColumnsFromReport>true</met:autoselectColumnsFromReport><met:chartAxisRange>Auto</met:chartAxisRange>'
            + '<met:componentType>' + type + '</met:componentType><met:displayUnits>Auto</met:displayUnits>'
            + '<met:header>' + header + '</met:header><met:report>RamBot_Reports/' + reportDevName + '</met:report>'
            + (type == 'Table' ? '' : '<met:sortBy>RowLabelAscending</met:sortBy>') + '</met:components>';
    }

    static String soap(String metadata) {
        return soapOp('createMetadata', metadata);
    }

    static String soapOp(String op, String metadata) {
        String xml = '<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:met="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
            + '<soapenv:Header><met:SessionHeader><met:sessionId>' + UserInfo.getSessionId() + '</met:sessionId></met:SessionHeader></soapenv:Header>'
            + '<soapenv:Body><met:' + op + '>' + metadata + '</met:' + op + '></soapenv:Body></soapenv:Envelope>';
        return call('POST', '/services/Soap/m/62.0', 'text/xml; charset=UTF-8', xml).left(600);
    }

    static String call(String method, String path, String contentType, String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + path);
        req.setMethod(method);
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', contentType);
        if (contentType.startsWith('text/xml')) req.setHeader('SOAPAction', '""');
        req.setBody(body);
        req.setTimeout(60000);
        HttpResponse res = new Http().send(req);
        return '\n' + path + ': ' + res.getStatusCode() + ' ' + res.getBody();
    }
}