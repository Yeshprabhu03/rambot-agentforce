// Runs as the Automated Process user, which may edit MessagingEndUser (the agent user's license may not).
trigger RamBotHandoffTrigger on RamBot_Handoff__e (after insert) {
    List<MessagingEndUser> updates = new List<MessagingEndUser>();
    for (RamBot_Handoff__e e : Trigger.new) {
        if (String.isBlank(e.End_User_Id__c)) {
            continue;
        }
        MessagingEndUser meu = new MessagingEndUser(Id = e.End_User_Id__c);
        if (String.isNotBlank(e.Student_Name__c)) {
            meu.Name = e.Student_Name__c;
        }
        if (String.isNotBlank(e.Lead_Id__c)) {
            meu.LeadId = e.Lead_Id__c;
        }
        updates.add(meu);
    }
    for (Database.SaveResult sr : Database.update(updates, false)) {
        if (!sr.isSuccess()) {
            System.debug(LoggingLevel.WARN, 'RamBotHandoffTrigger: ' + sr.getErrors());
        }
    }
}
