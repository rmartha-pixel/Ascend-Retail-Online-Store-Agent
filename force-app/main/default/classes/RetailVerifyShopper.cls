public without sharing class RetailVerifyShopper {
    public static final String FAILURE_MESSAGE =
        'I couldn\'t verify those details. Please check the order number and the email used on the order.';
    public static final String LOCKED_MESSAGE =
        'I couldn\'t verify those details, and I can\'t try again in this chat. I can connect you with our team.';
    public static final Integer MAX_ATTEMPTS = 3;

    @InvocableMethod(
        label='Verify Shopper'
        description='Verifies an Ascend Retail shopper using their order number and the email address on that order. Returns verified=true and the shopper id only when both match.'
    )
    public static List<Response> verify(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            Id contactId = RetailReturnService.verify(req.orderNumber, req.email);
            Integer previous = req.previousFailures == null ? 0 : req.previousFailures;
            if (previous >= MAX_ATTEMPTS) {
                contactId = null;
            }
            res.verified = contactId != null;
            res.failures = res.verified ? 0 : previous + 1;
            if (res.verified) {
                res.contactId = contactId;
                Contact c = [SELECT FirstName FROM Contact WHERE Id = :contactId];
                res.firstName = c.FirstName;
                res.message = 'Verified. The shopper is ' + c.FirstName + '.';
            } else {
                res.contactId = '';
                res.message = res.failures >= MAX_ATTEMPTS ? LOCKED_MESSAGE : FAILURE_MESSAGE;
            }
            responses.add(res);
        }
        return responses;
    }

    public class Request {
        @InvocableVariable(required=true label='Order Number' description='The order number the shopper gave, for example A-1004.')
        public String orderNumber;
        @InvocableVariable(required=true label='Order Email' description='The email address the shopper gave for the order.')
        public String email;
        @InvocableVariable(label='Previous Failures' description='Failed verification attempts so far in this conversation.')
        public Integer previousFailures;
    }

    public class Response {
        @InvocableVariable(label='Verified' description='True only when the order number and email match the same order.')
        public Boolean verified;
        @InvocableVariable(label='Shopper Id' description='Internal id of the verified shopper. Never show it to the user.')
        public String contactId;
        @InvocableVariable(label='First Name' description='First name of the verified shopper.')
        public String firstName;
        @InvocableVariable(label='Message' description='Message to relay to the shopper. On failure it is generic and never says which detail was wrong.')
        public String message;
        @InvocableVariable(label='Failures' description='Failed attempts including this one; zero after a success.')
        public Integer failures;
    }
}