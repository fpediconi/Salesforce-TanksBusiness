@isTest
private class TankTriggerTest {

    // Simulación del servicio Bitly
    class MockBitlyResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"link": "https://sforce.co/fake123"}');
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void testSingleInsertGeneratesShortUrl() {
        // Registrar el mock
        Test.setMock(HttpCalloutMock.class, new MockBitlyResponse());

        // Iniciar test
        Test.startTest();

        // 1. Crear tipo de tanque de prueba
        Tank_Type__c type = new Tank_Type__c(
            Name = 'Tipo Test',
            Capacity__c = 100,
            List_Price__c = 1500,
            Brand__c = 'Marca Test'
        );
        insert type;

        // 2. Crear un solo tanque (esto debe disparar el trigger y generar el short URL)
        Tank__c tank = new Tank__c(
            Name = 'TanqueTest',
            Tank_Type__c = type.Id,
            Serial_Number__c = 'SN-001',
            Status__c = 'Available' // Usá el valor exacto del picklist en tu org
        );

        insert tank;

        Test.stopTest(); // Ejecuta el @future

        // 3. Verificamos que se haya guardado el Short URL simulado
        Tank__c result = [SELECT Id, Short_URL__c FROM Tank__c WHERE Id = :tank.Id];
        System.assertEquals('https://sforce.co/fake123', result.Short_Url__c, 'El campo Short_Url__c debería haber sido actualizado con el link simulado');
    }

    @isTest
    static void testBulkInsertDoesNotTriggerCallout() {
        // Registrar mock (por si igual intenta hacerlo)
        Test.setMock(HttpCalloutMock.class, new MockBitlyResponse());

        List<Tank__c> tanques = new List<Tank__c>();
        Tank_Type__c type = new Tank_Type__c(
            Name = 'Tipo Test',
            Capacity__c = 100,
            List_Price__c = 1500,
            Brand__c = 'Marca Test'
        );

        insert type;

        for (Integer i = 0; i < 5; i++) {
            tanques.add(new Tank__c(
            Name = 'TanqueTest' + i,
            Tank_Type__c = type.Id,
            Serial_Number__c = 'SN-00' + i,
            Status__c = 'Available' // Usá el valor exacto del picklist en tu org
            ));
        }

        Test.startTest();
        insert tanques;
        Test.stopTest();

        // Ninguno debería tener short URL porque fue un insert masivo
        for (Tank__c t : [SELECT Short_URL__c FROM Tank__c WHERE Id IN :tanques]) {
            System.assertEquals(null, t.Short_Url__c, 'No debería haberse generado Short_URL en inserciones en lote');
        }
    }
}
