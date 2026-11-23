@IsTest
private class SimpleEmailPersonalizationTest {
    @IsTest
    static void dto_fieldsCanBeSet() {
        SimpleEmailPersonalization dto = new SimpleEmailPersonalization();
        dto.firstName = 'Revanth';
        dto.vehicleName = 'Audi A3 Sedan or similar';
        dto.pickupLocationName = 'Munich Airport';

        System.assertEquals('Revanth', dto.firstName);
        System.assertEquals('Audi A3 Sedan or similar', dto.vehicleName);
        System.assertEquals('Munich Airport', dto.pickupLocationName);
    }
}
