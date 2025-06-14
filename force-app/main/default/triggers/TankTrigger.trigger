trigger TankTrigger on Tank__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        if (!TankTriggerHandler.isBulkInsert(Trigger.size)) {
            TankTriggerHandler.handleSingleInsert(Trigger.new);
        }
    }
}
