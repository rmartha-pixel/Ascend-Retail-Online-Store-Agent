public without sharing class RetailGetShipments {
    @InvocableMethod(
        label='Get My Shipments'
        description='Lists the verified shopper\'s own shipments with status, delivered date and whether each one can be returned. A split order returns one line per shipment.'
    )
    public static List<Response> getShipments(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            Id contactId = toId(req.contactId);
            List<RetailReturnService.Shipment> shipments = RetailReturnService.getShipments(contactId, req.orderNumber);
            res.shipmentCount = shipments.size();
            res.eligibleCount = 0;
            if (shipments.isEmpty()) {
                res.summary = String.isBlank(req.orderNumber)
                    ? 'No shipments were found for this shopper.'
                    : 'No order ' + req.orderNumber + ' was found for this shopper.';
            } else {
                List<String> lines = new List<String>();
                Set<String> orders = new Set<String>();
                for (RetailReturnService.Shipment s : shipments) {
                    lines.add(s.describe());
                    orders.add(s.record.Order_Number__c);
                    if (s.isEligible()) {
                        res.eligibleCount++;
                    }
                }
                String header = '';
                if (orders.size() == 1 && shipments.size() > 1) {
                    header = 'Order ' + shipments[0].record.Order_Number__c + ' arrived in ' + shipments.size() + ' separate shipments.\n';
                }
                res.summary = header + String.join(lines, '\n');
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
        @InvocableVariable(label='Order Number' description='Optional order number to look up. Leave empty to list all of the shopper\'s shipments.')
        public String orderNumber;
    }

    public class Response {
        @InvocableVariable(label='Summary' description='One line per shipment: item, delivery status and return eligibility with the reason.')
        public String summary;
        @InvocableVariable(label='Shipment Count' description='Number of shipments found.')
        public Integer shipmentCount;
        @InvocableVariable(label='Eligible Count' description='Number of shipments that can be returned now.')
        public Integer eligibleCount;
    }
}