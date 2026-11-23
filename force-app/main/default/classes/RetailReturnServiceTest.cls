// SeeAllData: the org's existing Case on-create flow reads configuration that is only visible with org data.
@IsTest(SeeAllData=true)
private class RetailReturnServiceTest {
    private static final String MAYA_EMAIL = 'maya.apextest@example.com';
    private static final String SAM_EMAIL = 'sam.apextest@example.com';
    private static final Date TODAY_FIXED = Date.newInstance(2026, 11, 17);

    static void setup() {
        Account acc = new Account(Name = 'Ascend Retail Test Shoppers');
        insert acc;
        Contact maya = new Contact(FirstName = 'Maya', LastName = 'Chen', Email = MAYA_EMAIL, AccountId = acc.Id);
        Contact sam = new Contact(FirstName = 'Sam', LastName = 'Ortiz', Email = SAM_EMAIL, AccountId = acc.Id);
        insert new List<Contact>{ maya, sam };

        insert new List<Shop_Order__c>{
            shipment('A-1004', 'Cushion', -12, false, 'Delivered', maya.Id),
            shipment('A-1001', 'Linen throw', -12, false, 'Delivered', maya.Id),
            shipment('A-1001', 'Ceramic vase', -12, true, 'Delivered', maya.Id),
            shipment('A-1002', 'Wool rug', -16, true, 'Delivered', maya.Id),
            shipment('A-1003', 'Table lamp', -46, false, 'Delivered', maya.Id),
            shipment('A-1006', 'Desk', null, false, 'Shipped', maya.Id),
            shipment('A-1007', 'Throw blanket', -30, false, 'Delivered', maya.Id),
            shipment('A-1008', 'Side table', -31, false, 'Delivered', maya.Id),
            shipment('A-2001', 'Sofa', -7, false, 'Delivered', sam.Id)
        };
    }

    private static Shop_Order__c shipment(String orderNo, String item, Integer offset, Boolean finalSale, String status, Id contactId) {
        return new Shop_Order__c(
            Order_Number__c = orderNo,
            Item__c = item,
            Delivered_Date__c = offset == null ? null : TODAY_FIXED.addDays(offset),
            Final_Sale__c = finalSale,
            Status__c = status,
            Contact__c = contactId
        );
    }

    private static Id mayaId() {
        return [SELECT Id FROM Contact WHERE Email = :MAYA_EMAIL].Id;
    }

    private static RetailCreateReturn.Response createReturn(String orderNo, String item) {
        RetailCreateReturn.Request req = new RetailCreateReturn.Request();
        req.contactId = mayaId();
        req.orderNumber = orderNo;
        req.itemName = item;
        return RetailCreateReturn.createReturn(new List<RetailCreateReturn.Request>{ req })[0];
    }

    private static RetailVerifyShopper.Response verify(String orderNo, String email) {
        RetailVerifyShopper.Request req = new RetailVerifyShopper.Request();
        req.orderNumber = orderNo;
        req.email = email;
        return RetailVerifyShopper.verify(new List<RetailVerifyShopper.Request>{ req })[0];
    }

    @IsTest
    static void verifiesWithMatchingDetailsIgnoringCaseAndSpaces() {
        setup();
        RetailVerifyShopper.Response res = verify(' a-1004 ', MAYA_EMAIL.toUpperCase() + ' ');
        Assert.isTrue(res.verified);
        Assert.areEqual(String.valueOf(mayaId()), res.contactId);
    }

    @IsTest
    static void wrongEmailAndUnknownOrderGiveTheSameGenericMessage() {
        setup();
        RetailVerifyShopper.Response wrongEmail = verify('A-1004', 'wrong@example.com');
        RetailVerifyShopper.Response unknownOrder = verify('A-9999', MAYA_EMAIL);
        RetailVerifyShopper.Response otherShopper = verify('A-2001', MAYA_EMAIL);
        Assert.isFalse(wrongEmail.verified);
        Assert.isFalse(unknownOrder.verified);
        Assert.isFalse(otherShopper.verified);
        Assert.areEqual(wrongEmail.message, unknownOrder.message);
        Assert.areEqual(wrongEmail.message, otherShopper.message);
        Assert.areEqual('', wrongEmail.contactId);
    }

    @IsTest
    static void locksAfterThreeFailuresEvenWithCorrectDetails() {
        setup();
        RetailVerifyShopper.Request req = new RetailVerifyShopper.Request();
        req.orderNumber = 'A-1004';
        req.email = MAYA_EMAIL;
        req.previousFailures = 3;
        RetailVerifyShopper.Response res = RetailVerifyShopper.verify(new List<RetailVerifyShopper.Request>{ req })[0];
        Assert.isFalse(res.verified);
        Assert.areEqual(RetailVerifyShopper.LOCKED_MESSAGE, res.message);

        req.previousFailures = 1;
        res = RetailVerifyShopper.verify(new List<RetailVerifyShopper.Request>{ req })[0];
        Assert.isTrue(res.verified);
        Assert.areEqual(0, res.failures);
    }

    @IsTest
    static void lookupExplainsEachShipmentOfASplitOrder() {
        setup();
        RetailReturnService.todayOverride = TODAY_FIXED;
        RetailGetShipments.Request req = new RetailGetShipments.Request();
        req.contactId = mayaId();
        req.orderNumber = 'A-1001';
        RetailGetShipments.Response res = RetailGetShipments.getShipments(new List<RetailGetShipments.Request>{ req })[0];
        Assert.areEqual(2, res.shipmentCount);
        Assert.areEqual(1, res.eligibleCount);
        Assert.isTrue(res.summary.contains('2 separate shipments'));
        Assert.isTrue(res.summary.contains('final sale'));
    }

    @IsTest
    static void lookupNeverReturnsAnotherShoppersOrder() {
        setup();
        RetailGetShipments.Request req = new RetailGetShipments.Request();
        req.contactId = mayaId();
        req.orderNumber = 'A-2001';
        RetailGetShipments.Response res = RetailGetShipments.getShipments(new List<RetailGetShipments.Request>{ req })[0];
        Assert.areEqual(0, res.shipmentCount);
        Assert.isFalse(res.summary.contains('Sofa'));
    }

    @IsTest
    static void lookupWithoutVerifiedShopperReturnsNothing() {
        setup();
        RetailGetShipments.Request req = new RetailGetShipments.Request();
        req.contactId = 'not-an-id';
        RetailGetShipments.Response res = RetailGetShipments.getShipments(new List<RetailGetShipments.Request>{ req })[0];
        Assert.areEqual(0, res.shipmentCount);
    }

    @IsTest
    static void wholeSplitOrderCreatesCaseOnlyForEligibleShipment() {
        setup();
        RetailReturnService.todayOverride = TODAY_FIXED;
        RetailCreateReturn.Response res = createReturn('A-1001', null);
        Assert.areEqual(1, res.casesCreated);
        Case c = [SELECT Type, Shop_Order__r.Item__c, Owner.Name FROM Case WHERE CaseNumber = :res.caseNumbers];
        Assert.areEqual('Return', c.Type);
        Assert.areEqual('Retail Returns', c.Owner.Name);
        Assert.areEqual('Linen throw', c.Shop_Order__r.Item__c);
        Assert.isTrue(res.summary.contains('Ceramic vase: not eligible'));
        Assert.isFalse(res.summary.toLowerCase().contains('refund will'));
    }

    @IsTest
    static void secondRequestReturnsExistingCaseInsteadOfDuplicate() {
        setup();
        RetailReturnService.todayOverride = TODAY_FIXED;
        RetailCreateReturn.Response first = createReturn('A-1004', 'cushion');
        RetailCreateReturn.Response second = createReturn('A-1004', 'cushion');
        Assert.areEqual(1, first.casesCreated);
        Assert.areEqual(0, second.casesCreated);
        Assert.isTrue(second.summary.contains(first.caseNumbers));
        Assert.areEqual(1, [SELECT COUNT() FROM Case WHERE Type = 'Return' AND ContactId = :mayaId()]);
    }

    @IsTest
    static void enforcesFinalSaleWindowAndDeliveryRules() {
        setup();
        RetailReturnService.todayOverride = TODAY_FIXED;
        Assert.areEqual(0, createReturn('A-1002', null).casesCreated, 'final sale');
        Assert.areEqual(0, createReturn('A-1003', null).casesCreated, '46 days');
        Assert.areEqual(0, createReturn('A-1006', null).casesCreated, 'not delivered');
        Assert.areEqual(0, createReturn('A-1008', null).casesCreated, 'day 31');
        Assert.areEqual(1, createReturn('A-1007', null).casesCreated, 'day 30');
    }

    @IsTest
    static void windowComesFromSetting() {
        setup();
        RetailReturnService.todayOverride = TODAY_FIXED;
        RetailReturnService.windowOverride = 14;
        Assert.areEqual(0, createReturn('A-1002', null).casesCreated);
        Assert.areEqual(1, createReturn('A-1004', null).casesCreated);
        Assert.areEqual(0, createReturn('A-1007', null).casesCreated);
    }

    @IsTest
    static void cannotReturnAnotherShoppersOrder() {
        setup();
        RetailReturnService.todayOverride = TODAY_FIXED;
        RetailCreateReturn.Response res = createReturn('A-2001', null);
        Assert.areEqual(0, res.casesCreated);
        Assert.areEqual('No matching shipment was found for this shopper.', res.summary);
    }

    @IsTest
    static void escalationRoutesToTheRightQueue() {
        setup();
        RetailEscalateCase.Request damage = new RetailEscalateCase.Request();
        damage.category = 'Damage';
        damage.summary = 'Verified: yes. A-1001 vase arrived smashed.';
        damage.contactId = mayaId();
        damage.orderNumber = 'A-1001';
        RetailEscalateCase.Request payment = new RetailEscalateCase.Request();
        payment.category = 'Payment';
        payment.summary = 'Charged twice.';
        RetailEscalateCase.Request unknown = new RetailEscalateCase.Request();
        unknown.category = 'Something else';
        unknown.summary = 'Asked for a person.';

        List<RetailEscalateCase.Response> res = RetailEscalateCase.escalate(
            new List<RetailEscalateCase.Request>{ damage, payment, unknown }
        );
        Assert.areEqual('Retail Damage', res[0].queueName);
        Assert.areEqual('Retail Payments', res[1].queueName);
        Assert.areEqual('Retail Returns', res[2].queueName);
        Case c = [SELECT Owner.Name, Type FROM Case WHERE CaseNumber = :res[0].caseNumber];
        Assert.areEqual('Retail Damage', c.Owner.Name);
        Assert.areEqual('Damaged Item', c.Type);
    }

    @IsTest
    static void policyArticlesActionReturnsText() {
        setup();
        RetailPolicyKnowledge.Request req = new RetailPolicyKnowledge.Request();
        req.question = 'What is your return policy?';
        RetailPolicyKnowledge.Response res = RetailPolicyKnowledge.getArticles(new List<RetailPolicyKnowledge.Request>{ req })[0];
        Assert.isNotNull(res.articles);
    }

    @IsTest
    static void defaultWindowIsThirtyDays() {
        setup();
        Assert.areEqual(30, RetailReturnService.returnWindowDays());
    }
}
