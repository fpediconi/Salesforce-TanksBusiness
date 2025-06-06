public class TankTriggerHandler {

    public static Boolean isBulkInsert(Integer size) {
        return size > 1;
    }

    public static void handleSingleInsert(List<Tank__c> newTanks) {
        for (Tank__c tank : newTanks) {
            generateShortUrlAsync(tank.Id);
        }
    }

    @future(callout=true)
    public static void generateShortUrlAsync(Id tankId) {
        try {
            Tank__c tank = [SELECT Id, Short_Url__c FROM Tank__c WHERE Id = :tankId LIMIT 1];

            String fullUrl = URL.getOrgDomainUrl().toExternalForm() +
                            '/lightning/r/Tank__c/' + tank.Id + '/view';

            String shortUrl = BitlyService.shortenUrl(fullUrl);

            if (String.isNotBlank(shortUrl)) {
                tank.Short_Url__c = shortUrl;
            } else {
                tank.Short_Url__c = '⚠️ No se pudo generar la URL corta.';
            }

            update tank;

        } catch (Exception e) {
            Tank__c fallback = new Tank__c(
                Id = tankId,
                Short_Url__c = '⚠️ Error inesperado en la integración. Contactar soporte.'
            );
            try {
                update fallback;
            } catch (Exception ignore) {
                // Silenciamos esta excepción para evitar reintentos encadenados
            }
        }
    }



}
