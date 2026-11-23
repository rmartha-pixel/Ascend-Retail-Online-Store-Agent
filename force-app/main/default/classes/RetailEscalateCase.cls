public without sharing class RetailEscalateCase {
    private static final Map<String, String> QUEUE_BY_CATEGORY = new Map<String, String>{
        'Damage' => 'Retail_Damage',
        'Payment' => 'Retail_Payments',
        'Returns' => 'Retail_Returns'
    };
    private static final Map<String, String> TYPE_BY_CATEGORY = new Map<String, String>{
        'Damage' => 'Damaged Item',
        'Payment' => 'Payment Dispute',
        'Returns' => 'General'
    };
    private static final Map<String, String> LABEL_BY_CATEGORY = new Map<String, String>{
        'Damage' => 'Retail Damage',
        'Payment' => 'Retail Payments',
        'Returns' => 'Retail Returns'
    };

    @InvocableMethod(
        label='Create Escalation Case'
        description='Hands the conversation to a human team by creating a Case in the right queue with a short summary. Category must be Damage, Payment or Returns.'
    )
    public static List<Response> escalate(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            String category = QUEUE_BY_CATEGORY.containsKey(req.category) ? req.category : 'Returns';
            Case c = new Case(
                Subject = 'Agent hand-off (' + LABEL_BY_CATEGORY.get(category) + ')' +
                    (String.isBlank(req.orderNumber) ? '' : ': ' + req.orderNumber),
                Description = req.summary,
                Type = TYPE_BY_CATEGORY.get(category),
                Origin = 'Chat',
                Status = 'New',
                Priority = category == 'Returns' ? 'Medium' : 'High'
            );
            Id contactId = toId(req.contactId);
            if (contactId != null) {
                c.ContactId = contactId;
            }
            insert c;
            RetailReturnService.assignToQueue(new List<Case>{ c }, QUEUE_BY_CATEGORY.get(category));

            Response res = new Response();
            res.caseNumber = [SELECT CaseNumber FROM Case WHERE Id = :c.Id].CaseNumber;
            res.queueName = LABEL_BY_CATEGORY.get(category);
            res.message = 'Case ' + res.caseNumber + ' is with our ' + res.queueName + ' team, who will follow up.';
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
        @InvocableVariable(required=true label='Category' description='Damage for damaged or broken items; Payment for double charges, chargebacks or payment disputes; Returns for everything else, including a request for a person.')
        public String category;
        @InvocableVariable(required=true label='Summary' description='Short hand-off summary: verified yes or no, order number, shipments discussed, what the shopper wants, what the agent already did, and why it is escalating.')
        public String summary;
        @InvocableVariable(label='Shopper Id' description='Id of the verified shopper, if verified.')
        public String contactId;
        @InvocableVariable(label='Order Number' description='Order number discussed, if any.')
        public String orderNumber;
    }

    public class Response {
        @InvocableVariable(label='Case Number' description='Number of the hand-off Case.')
        public String caseNumber;
        @InvocableVariable(label='Queue Name' description='Team that received the Case.')
        public String queueName;
        @InvocableVariable(label='Message' description='Confirmation to relay to the shopper.')
        public String message;
    }
}