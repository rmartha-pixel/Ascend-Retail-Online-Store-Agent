/**
 * Business rules for the Ascend Retail returns agent.
 * Runs without sharing because the agent user owns no shopper data; every query is
 * scoped to the verified Contact Id instead, so a mis-routed call still cannot read
 * another shopper's shipments.
 */
public without sharing class RetailReturnService {
    public static final String REASON_ELIGIBLE = 'ELIGIBLE';
    public static final String REASON_NOT_DELIVERED = 'NOT_DELIVERED';
    public static final String REASON_FINAL_SALE = 'FINAL_SALE';
    public static final String REASON_WINDOW_CLOSED = 'WINDOW_CLOSED';
    public static final String REASON_ALREADY_REQUESTED = 'ALREADY_REQUESTED';

    public static final String CASE_TYPE_RETURN = 'Return';

    @TestVisible
    private static Date todayOverride;
    @TestVisible
    private static Integer windowOverride;

    public static Date today() {
        return todayOverride != null ? todayOverride : Date.today();
    }

    public static Integer returnWindowDays() {
        if (windowOverride != null) {
            return windowOverride;
        }
        Retail_Return_Setting__mdt setting = Retail_Return_Setting__mdt.getInstance('Default');
        if (setting == null || setting.Return_Window_Days__c == null) {
            return 30;
        }
        return setting.Return_Window_Days__c.intValue();
    }

    public static String normalizeOrderNumber(String orderNumber) {
        return String.isBlank(orderNumber) ? null : orderNumber.deleteWhitespace().toUpperCase();
    }

    public static String normalizeEmail(String email) {
        return String.isBlank(email) ? null : email.trim().toLowerCase();
    }

    /** Returns the Contact Id when the order number and order email match, otherwise null. */
    public static Id verify(String orderNumber, String email) {
        String normOrder = normalizeOrderNumber(orderNumber);
        String normEmail = normalizeEmail(email);
        if (normOrder == null || normEmail == null) {
            return null;
        }
        List<Shop_Order__c> matches = [
            SELECT Contact__c
            FROM Shop_Order__c
            WHERE Order_Number__c = :normOrder AND Contact__r.Email = :normEmail AND Contact__c != NULL
            LIMIT 1
        ];
        return matches.isEmpty() ? null : matches[0].Contact__c;
    }

    public class Shipment {
        public Shop_Order__c record;
        public String reason;
        public String existingCaseNumber;
        public Integer daysSinceDelivery;

        public Boolean isEligible() {
            return reason == REASON_ELIGIBLE;
        }

        public String describe() {
            String line = record.Order_Number__c + ' — ' + record.Item__c + ': ';
            if (record.Status__c != 'Delivered' || record.Delivered_Date__c == null) {
                line += 'status ' + record.Status__c + ', not delivered yet.';
            } else {
                line +=
                    'delivered ' +
                    record.Delivered_Date__c.format() +
                    ' (' +
                    daysSinceDelivery +
                    (daysSinceDelivery == 1 ? ' day ago).' : ' days ago).');
            }
            line += ' Return: ' + explain() + '';
            return line;
        }

        public String explain() {
            Integer window = returnWindowDays();
            switch on reason {
                when 'ELIGIBLE' {
                    return 'eligible — within the ' + window + '-day return window.';
                }
                when 'NOT_DELIVERED' {
                    return 'not eligible yet — it has not been delivered.';
                }
                when 'FINAL_SALE' {
                    return 'not eligible — this item was sold as final sale.';
                }
                when 'WINDOW_CLOSED' {
                    return 'not eligible — delivered more than ' + window + ' days ago.';
                }
                when 'ALREADY_REQUESTED' {
                    return 'a return request already exists (Case ' + existingCaseNumber + ').';
                }
                when else {
                    return 'unknown.';
                }
            }
        }
    }

    /** All shipments belonging to the verified shopper, optionally limited to one order number. */
    public static List<Shipment> getShipments(Id contactId, String orderNumber) {
        List<Shipment> result = new List<Shipment>();
        if (contactId == null) {
            return result;
        }
        String normOrder = normalizeOrderNumber(orderNumber);
        List<Shop_Order__c> records;
        if (normOrder == null) {
            records = [
                SELECT Id, Order_Number__c, Item__c, Delivered_Date__c, Final_Sale__c, Status__c, Contact__c
                FROM Shop_Order__c
                WHERE Contact__c = :contactId
                ORDER BY Order_Number__c, Item__c
            ];
        } else {
            records = [
                SELECT Id, Order_Number__c, Item__c, Delivered_Date__c, Final_Sale__c, Status__c, Contact__c
                FROM Shop_Order__c
                WHERE Contact__c = :contactId AND Order_Number__c = :normOrder
                ORDER BY Item__c
            ];
        }
        if (records.isEmpty()) {
            return result;
        }

        Map<Id, String> existingReturns = new Map<Id, String>();
        for (Case c : [
            SELECT CaseNumber, Shop_Order__c
            FROM Case
            WHERE Shop_Order__c IN :records AND Type = :CASE_TYPE_RETURN
        ]) {
            existingReturns.put(c.Shop_Order__c, c.CaseNumber);
        }

        Date todayDate = today();
        Integer window = returnWindowDays();
        for (Shop_Order__c rec : records) {
            Shipment s = new Shipment();
            s.record = rec;
            s.daysSinceDelivery = rec.Delivered_Date__c == null ? null : rec.Delivered_Date__c.daysBetween(todayDate);
            if (existingReturns.containsKey(rec.Id)) {
                s.reason = REASON_ALREADY_REQUESTED;
                s.existingCaseNumber = existingReturns.get(rec.Id);
            } else if (rec.Status__c != 'Delivered' || rec.Delivered_Date__c == null) {
                s.reason = REASON_NOT_DELIVERED;
            } else if (rec.Final_Sale__c) {
                s.reason = REASON_FINAL_SALE;
            } else if (s.daysSinceDelivery > window) {
                s.reason = REASON_WINDOW_CLOSED;
            } else {
                s.reason = REASON_ELIGIBLE;
            }
            result.add(s);
        }
        return result;
    }

    public class ReturnOutcome {
        public List<String> createdCaseNumbers = new List<String>();
        public List<String> lines = new List<String>();
        public Boolean anyMatch = false;
    }

    /**
     * Creates one return Case per eligible shipment of the order. If itemName is given,
     * only shipments whose item contains that text are considered. Never creates a
     * duplicate: an existing return Case number is reported instead.
     */
    public static ReturnOutcome createReturns(Id contactId, String orderNumber, String itemName, String reason) {
        ReturnOutcome outcome = new ReturnOutcome();
        List<Shipment> shipments = getShipments(contactId, orderNumber);
        String itemFilter = String.isBlank(itemName) ? null : itemName.trim().toLowerCase();

        List<Case> toInsert = new List<Case>();
        List<Shipment> insertedFor = new List<Shipment>();
        for (Shipment s : shipments) {
            if (itemFilter != null && !s.record.Item__c.toLowerCase().contains(itemFilter)) {
                continue;
            }
            outcome.anyMatch = true;
            if (s.isEligible()) {
                toInsert.add(
                    new Case(
                        ContactId = contactId,
                        Shop_Order__c = s.record.Id,
                        Type = CASE_TYPE_RETURN,
                        Origin = 'Chat',
                        Status = 'New',
                        Subject = 'Return request: ' + s.record.Order_Number__c + ' — ' + s.record.Item__c,
                        Description = String.isBlank(reason)
                            ? 'Created by the Ascend Retail agent.'
                            : 'Reason given by shopper: ' + reason
                    )
                );
                insertedFor.add(s);
            } else {
                outcome.lines.add(s.record.Item__c + ': ' + s.explain());
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
            assignToQueue(toInsert, 'Retail_Returns');
            Map<Id, Case> numbers = new Map<Id, Case>([SELECT CaseNumber FROM Case WHERE Id IN :toInsert]);
            for (Integer i = 0; i < toInsert.size(); i++) {
                String num = numbers.get(toInsert[i].Id).CaseNumber;
                outcome.createdCaseNumbers.add(num);
                outcome.lines.add(insertedFor[i].record.Item__c + ': return request created (Case ' + num + ').');
            }
        }
        return outcome;
    }

    /**
     * Set after insert because the org's Case on-create automation overwrites the owner.
     * The agent runtime also applies the default assignment rule to every Case save, which
     * hands the Case to the org's default Case owner, so the owner is re-applied in a
     * Queueable that runs outside the agent request.
     */
    public static void assignToQueue(List<Case> cases, String queueDeveloperName) {
        Id qId = queueId(queueDeveloperName);
        if (qId == null || cases.isEmpty()) {
            return;
        }
        Set<Id> caseIds = new Set<Id>();
        for (Case c : cases) {
            caseIds.add(c.Id);
        }
        new QueueOwnerAssignment(caseIds, qId).apply();
        if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(new QueueOwnerAssignment(caseIds, qId));
        }
    }

    public class QueueOwnerAssignment implements Queueable {
        private final Set<Id> caseIds;
        private final Id queueId;

        public QueueOwnerAssignment(Set<Id> caseIds, Id queueId) {
            this.caseIds = caseIds;
            this.queueId = queueId;
        }

        public void execute(QueueableContext context) {
            apply();
        }

        public void apply() {
            List<Case> updates = new List<Case>();
            for (Case c : [SELECT Id, OwnerId FROM Case WHERE Id IN :caseIds]) {
                if (c.OwnerId != queueId) {
                    updates.add(new Case(Id = c.Id, OwnerId = queueId));
                }
            }
            if (!updates.isEmpty()) {
                update updates;
            }
        }
    }

    public static Id queueId(String developerName) {
        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue' AND DeveloperName = :developerName
            LIMIT 1
        ];
        return queues.isEmpty() ? null : queues[0].Id;
    }
}
