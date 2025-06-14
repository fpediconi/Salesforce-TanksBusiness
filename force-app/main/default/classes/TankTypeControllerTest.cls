@isTest
private class TankTypeControllerTest {
    
    @isTest
    static void testGetAllTankTypes() {
        // Insertar datos de prueba
        Tank_Type__c tt1 = new Tank_Type__c(Name = 'Alpha');
        Tank_Type__c tt2 = new Tank_Type__c(Name = 'Beta');
        insert new List<Tank_Type__c>{ tt1, tt2 };

        Test.startTest();
        List<TankTypeController.TankTypeDTO> result = TankTypeController.getAllTankTypes();
        Test.stopTest();

        System.assertEquals(2, result.size(), 'Debe devolver dos tipos de tanque');
        System.assertNotEquals(null, result[0].id);
        System.assertNotEquals(null, result[0].name);
    }
}
