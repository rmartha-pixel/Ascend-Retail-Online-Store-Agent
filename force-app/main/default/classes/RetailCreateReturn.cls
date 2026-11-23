public without sharing class RetailCreateReturn {
    @InvocableMethod(
        label='Create Return Request'
        description='Creates a return request Case (Type = Return) for each eligible shipment of the verified shopper\'s order. Re-checks every rule, never duplicates an existing request, and never issues a refund.'
    )
    public static List<Response> createReturn(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            Id contactId = toId(req.contactId);
            RetailReturnService.ReturnOutcome outcome = RetailReturnService.createReturns(
                contactId,
                req.orderNumber,
                req.itemName,
                req.reason
            );
            res.casesCreated = outcome.createdCaseNumbers.size();
            res.caseNumbers = String.join(outcome.createdCaseNumbers, ', ');
            if (!outcome.anyMatch) {
                res.summary = 'No matching shipment was found for this shopper.';
            } else {
                res.summary = String.join(outcome.lines, '\n');
                if (res.casesCreated > 0) {
                    res.summary += '\nOur returns team will email next steps. Filing a return does not issue a refund.';
                }
            }
            responses.add(res);
        }
        return responses;
    }

    private static Id toId(String value) {
        try {
            return String.isBlank(value) ? null : Id.valueOf(value);
        } catch (Exception e) {
            return null;
        }
    }

    public class Request {
        @InvocableVariable(required=true label='Shopper Id' description='Id of the verified shopper, from Verify Shopper.')
        public String contactId;
        @InvocableVariable(required=true label='Order Number' description='Order number to return, for example A-1001.')
        public String orderNumber;
        @InvocableVariable(label='Item Name' description='Optional item to return when the shopper names one, for example cushion. Leave empty to consider every shipment in the order.')
        public String itemName;
        @InvocableVariable(label='Reason' description='Optional reason for the return in the shopper\'s words.')
        public String reason;
    }

    public class Response {
        @InvocableVariable(label='Summary' description='One line per shipment considered: created Case number, existing Case number, or why it cannot be returned.')
        public String summary;
        @InvocableVariable(label='Cases Created' description='Number of new return Cases created.')
        public Integer casesCreated;
        @InvocableVariable(label='Case Numbers' description='Comma-separated new Case numbers.')
        public String caseNumbers;
    }
}