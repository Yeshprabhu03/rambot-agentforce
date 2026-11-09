// Grants access for the RamBot prospect features (setup objects only, so it runs apart from the data seed).
public with sharing class RamBotProspectPerms {
    static final List<String> PROGRAM_FIELDS = new List<String>{ 'Program_Code__c', 'Degree_Type__c', 'Format__c', 'Credits__c', 'Length__c',
        'STEM_Designated__c', 'F1_Eligible__c', 'Prerequisites__c', 'Start_Terms__c', 'Pricing_Model__c', 'Rate_Per_Credit__c',
        'Program_Total_Tuition__c', 'Enrichment_Fee__c', 'Typical_Terms__c', 'Deadline_Track__c', 'Ideal_For__c', 'Program_URL__c' };
    static final List<String> LEAD_FIELDS = new List<String>{ 'Program_Interest__c', 'Intended_Term__c', 'Is_International__c' };
    static final List<String> CAMPAIGN_FIELDS = new List<String>{ 'Event_Time__c', 'Registration_URL__c', 'Program_Focus__c' };
    static final List<String> ACTION_CLASSES = new List<String>{ 'ProgramCatalog', 'ProgramCostEstimator', 'ProspectLeadCapture',
        'InfoSessionFinder', 'InfoSessionRegistration' };

    public static String run() {
        String log = '';
        PermissionSet admin = [SELECT Id FROM PermissionSet WHERE IsOwnedByProfile = true AND Profile.Name = 'System Administrator' LIMIT 1];
        PermissionSet agent = [SELECT Id FROM PermissionSet WHERE Label = 'Agentforce Agent RamBot Permissions' LIMIT 1];

        List<ObjectPermissions> objs = new List<ObjectPermissions>{
            objPerm(admin.Id, 'Program__c', true, true, true, true, true, true),
            objPerm(agent.Id, 'Program__c', true, false, false, false, false, false),
            objPerm(agent.Id, 'Lead', true, true, true, false, false, false),
            objPerm(agent.Id, 'Campaign', true, false, false, false, false, false)
        };
        Map<String, Id> haveObj = new Map<String, Id>();
        for (ObjectPermissions o : [SELECT Id, ParentId, SobjectType FROM ObjectPermissions WHERE ParentId IN :new List<Id>{ admin.Id, agent.Id }]) {
            haveObj.put(o.ParentId + o.SobjectType, o.Id);
        }
        List<ObjectPermissions> newObjs = new List<ObjectPermissions>();
        List<ObjectPermissions> changedObjs = new List<ObjectPermissions>();
        for (ObjectPermissions o : objs) {
            Id existing = haveObj.get(o.ParentId + o.SobjectType);
            if (existing == null) newObjs.add(o);
            else if (o.ParentId == agent.Id && !String.valueOf(existing).startsWith('000')) changedObjs.add(new ObjectPermissions(Id = existing, PermissionsRead = o.PermissionsRead, PermissionsCreate = o.PermissionsCreate, PermissionsEdit = o.PermissionsEdit));
        }
        log += report('Object permissions', Database.insert(newObjs, false));
        log += report('Object permissions updated', Database.update(changedObjs, false));

        List<FieldPermissions> fps = new List<FieldPermissions>();
        for (String f : PROGRAM_FIELDS) {
            fps.add(fieldPerm(admin.Id, 'Program__c', f, true));
            fps.add(fieldPerm(agent.Id, 'Program__c', f, false));
        }
        for (String f : LEAD_FIELDS) {
            fps.add(fieldPerm(admin.Id, 'Lead', f, true));
            fps.add(fieldPerm(agent.Id, 'Lead', f, true));
        }
        for (String f : CAMPAIGN_FIELDS) {
            fps.add(fieldPerm(admin.Id, 'Campaign', f, true));
            fps.add(fieldPerm(agent.Id, 'Campaign', f, false));
        }
        Set<String> haveField = new Set<String>();
        for (FieldPermissions fp : [SELECT ParentId, Field FROM FieldPermissions WHERE ParentId IN :new List<Id>{ admin.Id, agent.Id }]) {
            haveField.add(fp.ParentId + fp.Field);
        }
        List<FieldPermissions> newFps = new List<FieldPermissions>();
        for (FieldPermissions fp : fps) if (!haveField.contains(fp.ParentId + fp.Field)) newFps.add(fp);
        log += report('Field permissions', Database.insert(newFps, false));

        Group queue = [SELECT Id FROM Group WHERE Type = 'Queue' AND Name = 'Admissions Advisors' LIMIT 1];
        if ([SELECT COUNT() FROM QueueSobject WHERE QueueId = :queue.Id AND SobjectType = 'Lead'] == 0) {
            log += report('Lead on Admissions Advisors queue', Database.insert(new List<QueueSobject>{ new QueueSobject(QueueId = queue.Id, SobjectType = 'Lead') }, false));
        }

        Set<Id> haveClass = new Set<Id>();
        for (SetupEntityAccess s : [SELECT SetupEntityId FROM SetupEntityAccess WHERE ParentId = :agent.Id]) haveClass.add(s.SetupEntityId);
        List<SetupEntityAccess> access = new List<SetupEntityAccess>();
        for (ApexClass c : [SELECT Id FROM ApexClass WHERE Name IN :ACTION_CLASSES]) {
            if (!haveClass.contains(c.Id)) access.add(new SetupEntityAccess(ParentId = agent.Id, SetupEntityId = c.Id));
        }
        log += report('Apex class access for RamBot', Database.insert(access, false));
        return log;
    }

    static ObjectPermissions objPerm(Id ps, String obj, Boolean r, Boolean c, Boolean e, Boolean d, Boolean va, Boolean ma) {
        return new ObjectPermissions(ParentId = ps, SobjectType = obj, PermissionsRead = r, PermissionsCreate = c,
            PermissionsEdit = e, PermissionsDelete = d, PermissionsViewAllRecords = va, PermissionsModifyAllRecords = ma);
    }

    static FieldPermissions fieldPerm(Id ps, String obj, String field, Boolean edit) {
        return new FieldPermissions(ParentId = ps, SobjectType = obj, Field = obj + '.' + field, PermissionsRead = true, PermissionsEdit = edit);
    }

    static String report(String label, List<Database.SaveResult> results) {
        Integer ok = 0;
        String errors = '';
        for (Database.SaveResult r : results) {
            if (r.isSuccess()) ok++;
            else errors += ' | ' + r.getErrors()[0].getMessage();
        }
        return '\n' + label + ': ' + ok + ' added' + errors;
    }
}