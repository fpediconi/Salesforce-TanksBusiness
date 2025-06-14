public with sharing class TankTypeController {
    @AuraEnabled(cacheable=true)
    public static List<TankTypeDTO> getAllTankTypes() {
        List<TankTypeDTO> results = new List<TankTypeDTO>();
        // Traer los Tank Type
        for (Tank_Type__c tt : [
            SELECT Id, Name 
            FROM Tank_Type__c 
            ORDER BY Name
        ]) {
            results.add(new TankTypeDTO(tt.Id, tt.Name));
        }
        return results;
    }
    
    // Clase inner para transferir datos al LWC
    public class TankTypeDTO {
        @AuraEnabled public Id    id;
        @AuraEnabled public String name;
        public TankTypeDTO(Id i, String n) {
            id = i;
            name = n;
        }
    }
}
