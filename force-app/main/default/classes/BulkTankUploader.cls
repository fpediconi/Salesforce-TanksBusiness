public with sharing class BulkTankUploader {
    @AuraEnabled
    public static List<UploadResult> insertTanks(List<TankWrapper> tankWrappers) {
        // 1) DEBUG: imprimimos en los logs qué está llegando desde LWC
        for (Integer i = 0; i < tankWrappers.size(); i++) {
            TankWrapper w = tankWrappers[i];
            System.debug('>> DEBUG APEX: wrapper[' + i + '] = '
                         + 'SerialNumber=' + w.SerialNumber
                         + ', Status='       + w.Status
                         + ', TankTypeId='   + w.TankTypeId);
        }

        // 2) Construimos los registros a insertar
        List<Tank__c> tanksToInsert = new List<Tank__c>();
        for (TankWrapper w : tankWrappers) {
            Tank__c t = new Tank__c();
            t.Serial_Number__c = w.SerialNumber;
            t.Status__c        = w.Status;
            t.Tank_Type__c     = w.TankTypeId;
            tanksToInsert.add(t);
        }

        // 3) Insertamos en modo parcial (allOrNone = false)
        Database.SaveResult[] results = Database.insert(tanksToInsert, false);

        // 4) Construimos la lista de resultados para devolver a LWC
        List<UploadResult> output = new List<UploadResult>();
        for (Integer i = 0; i < results.size(); i++) {
            UploadResult ur = new UploadResult();
            ur.index = i;
            if (results[i].isSuccess()) {
                ur.success      = true;
                ur.recordId     = results[i].getId();
                ur.errorMessage = null;
            } else {
                ur.success      = false;
                ur.recordId     = null;
                ur.errorMessage = results[i].getErrors()[0].getMessage();
            }
            output.add(ur);
        }
        return output;
    }

    // -------- Wrapper que recibe LWC --------
    public class TankWrapper {
        @AuraEnabled public String SerialNumber { get; set; }
        @AuraEnabled public String Status       { get; set; }
        @AuraEnabled public String TankTypeId   { get; set; }
    }

    // -------- Wrapper que devuelve a LWC --------
    public class UploadResult {
        @AuraEnabled public Integer index        { get; set; }
        @AuraEnabled public Boolean success      { get; set; }
        @AuraEnabled public Id      recordId     { get; set; }
        @AuraEnabled public String  errorMessage { get; set; }
    }
}
