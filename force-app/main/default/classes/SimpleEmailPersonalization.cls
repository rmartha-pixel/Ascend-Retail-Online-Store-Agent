// Minimal Apex Class Data Provider DTO for Marketing Cloud Next.
// Flow assigns values; the email reads them via {!$Expression.fieldName}.
public with sharing class SimpleEmailPersonalization {
    @AuraEnabled public String firstName { get; set; }
    @AuraEnabled public String vehicleName { get; set; }
    @AuraEnabled public String pickupLocationName { get; set; }
}
