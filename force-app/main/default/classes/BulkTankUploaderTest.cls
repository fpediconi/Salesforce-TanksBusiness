@isTest
private class BulkTankUploaderTest {
    
    @isTest
    static void testInsertTanks_successful() {
        // Crear un tipo de tanque válido
        Tank_Type__c tankType = new Tank_Type__c(Name = 'Tipo Test');
        insert tankType;
        
        // Crear wrappers de prueba
        List<BulkTankUploader.TankWrapper> wrappers = new List<BulkTankUploader.TankWrapper>();
        for (Integer i = 0; i < 3; i++) {
            BulkTankUploader.TankWrapper w = new BulkTankUploader.TankWrapper();
            w.SerialNumber = 'TNK-00' + i;
            w.Status = 'Available';
            w.TankTypeId = tankType.Id;
            wrappers.add(w);
        }

        // Llamar al método insertTanks
        Test.startTest();
        List<BulkTankUploader.UploadResult> results = BulkTankUploader.insertTanks(wrappers);
        Test.stopTest();

        // Validar resultados
        System.assertEquals(3, results.size(), 'Debe devolver 3 resultados');
        for (BulkTankUploader.UploadResult r : results) {
            System.assertEquals(true, r.success);
            System.assertNotEquals(null, r.recordId);
            System.assertEquals(null, r.errorMessage);
        }
    }

    @isTest
    static void testInsertTanks_withInvalidData() {
        // Crear wrappers con un TankTypeId inválido (generará error)
        List<BulkTankUploader.TankWrapper> wrappers = new List<BulkTankUploader.TankWrapper>();
        BulkTankUploader.TankWrapper w = new BulkTankUploader.TankWrapper();
        w.SerialNumber = 'TNK-9999';
        w.Status = 'Available';
        w.TankTypeId = 'a0X000000000000XXX'; // ID inválido
        wrappers.add(w);

        Test.startTest();
        List<BulkTankUploader.UploadResult> results = BulkTankUploader.insertTanks(wrappers);
        Test.stopTest();

        // Debe fallar
        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].success);
        System.assertEquals(null, results[0].recordId);
        System.assertNotEquals(null, results[0].errorMessage);
    }
}
