// Ascend Retail demo data. Safe to re-run: it rebuilds shipments and return Cases for the demo shoppers
// and dates every delivery relative to today, so day 30 and day 31 stay correct on demo day.
Date t = Date.today();

Account acc;
List<Account> accs = [SELECT Id FROM Account WHERE Name = 'Ascend Retail Shoppers' LIMIT 1];
if (accs.isEmpty()) {
    acc = new Account(Name = 'Ascend Retail Shoppers');
    insert acc;
} else {
    acc = accs[0];
}

Map<String, Contact> byEmail = new Map<String, Contact>();
for (Contact c : [SELECT Id, Email FROM Contact WHERE Email IN ('maya@example.com', 'sam@example.com', 'revanth@example.com')]) {
    byEmail.put(c.Email.toLowerCase(), c);
}
List<Contact> newContacts = new List<Contact>();
if (!byEmail.containsKey('maya@example.com')) {
    newContacts.add(new Contact(FirstName = 'Maya', LastName = 'Chen', Email = 'maya@example.com', AccountId = acc.Id));
}
if (!byEmail.containsKey('sam@example.com')) {
    newContacts.add(new Contact(FirstName = 'Sam', LastName = 'Ortiz', Email = 'sam@example.com', AccountId = acc.Id));
}
if (!byEmail.containsKey('revanth@example.com')) {
    newContacts.add(new Contact(FirstName = 'Revanth', LastName = 'Martha', Email = 'revanth@example.com', AccountId = acc.Id));
}
insert newContacts;
for (Contact c : newContacts) {
    byEmail.put(c.Email.toLowerCase(), c);
}
Id maya = byEmail.get('maya@example.com').Id;
Id sam = byEmail.get('sam@example.com').Id;
Id revanth = byEmail.get('revanth@example.com').Id;
Set<Id> shoppers = new Set<Id>{ maya, sam, revanth };

List<Shop_Order__c> old = [SELECT Id FROM Shop_Order__c WHERE Contact__c IN :shoppers];
delete [SELECT Id FROM Case WHERE Shop_Order__c IN :old OR (ContactId IN :shoppers AND Origin = 'Chat')];
delete old;

insert new List<Shop_Order__c>{
    new Shop_Order__c(Order_Number__c = 'A-1004', Item__c = 'Velvet cushion', Delivered_Date__c = t.addDays(-12), Status__c = 'Delivered', Contact__c = maya),
    new Shop_Order__c(Order_Number__c = 'A-1001', Item__c = 'Linen throw', Delivered_Date__c = t.addDays(-12), Status__c = 'Delivered', Contact__c = maya),
    new Shop_Order__c(Order_Number__c = 'A-1001', Item__c = 'Ceramic vase', Delivered_Date__c = t.addDays(-12), Final_Sale__c = true, Status__c = 'Delivered', Contact__c = maya),
    new Shop_Order__c(Order_Number__c = 'A-1002', Item__c = 'Wool rug', Delivered_Date__c = t.addDays(-16), Final_Sale__c = true, Status__c = 'Delivered', Contact__c = maya),
    new Shop_Order__c(Order_Number__c = 'A-1003', Item__c = 'Brass table lamp', Delivered_Date__c = t.addDays(-46), Status__c = 'Delivered', Contact__c = maya),
    new Shop_Order__c(Order_Number__c = 'A-1005', Item__c = 'Oak dining chair', Delivered_Date__c = t.addDays(-3), Status__c = 'Delivered', Contact__c = maya),
    new Shop_Order__c(Order_Number__c = 'A-1006', Item__c = 'Walnut desk', Status__c = 'Shipped', Contact__c = maya),
    new Shop_Order__c(Order_Number__c = 'A-1007', Item__c = 'Throw blanket', Delivered_Date__c = t.addDays(-30), Status__c = 'Delivered', Contact__c = maya),
    new Shop_Order__c(Order_Number__c = 'A-1008', Item__c = 'Side table', Delivered_Date__c = t.addDays(-31), Status__c = 'Delivered', Contact__c = maya),
    new Shop_Order__c(Order_Number__c = 'A-2001', Item__c = 'Three-seat sofa', Delivered_Date__c = t.addDays(-7), Status__c = 'Delivered', Contact__c = sam),
    // Revanth: the demo site's end user.
    new Shop_Order__c(Order_Number__c = 'A-3001', Item__c = 'Linen throw', Delivered_Date__c = t.addDays(-10), Status__c = 'Delivered', Contact__c = revanth),
    new Shop_Order__c(Order_Number__c = 'A-3001', Item__c = 'Ceramic vase', Delivered_Date__c = t.addDays(-10), Final_Sale__c = true, Status__c = 'Delivered', Contact__c = revanth),
    new Shop_Order__c(Order_Number__c = 'A-3002', Item__c = 'Oak dining chair', Delivered_Date__c = t.addDays(-5), Status__c = 'Delivered', Contact__c = revanth),
    new Shop_Order__c(Order_Number__c = 'A-3003', Item__c = 'Wool rug', Delivered_Date__c = t.addDays(-16), Final_Sale__c = true, Status__c = 'Delivered', Contact__c = revanth),
    new Shop_Order__c(Order_Number__c = 'A-3004', Item__c = 'Side table', Delivered_Date__c = t.addDays(-31), Status__c = 'Delivered', Contact__c = revanth)
};

// A-3002 already has a return open, so asking again shows the one-return-per-shipment rule.
Shop_Order__c chair = [SELECT Id FROM Shop_Order__c WHERE Order_Number__c = 'A-3002' AND Contact__c = :revanth LIMIT 1];
Group returnsQueue = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = 'Retail_Returns' LIMIT 1];
Case openReturn = new Case(
    ContactId = revanth,
    AccountId = acc.Id,
    Shop_Order__c = chair.Id,
    Type = 'Return',
    Origin = 'Chat',
    Subject = 'Return request: A-3002 Oak dining chair',
    Description = 'Return requested for the oak dining chair on order A-3002.'
);
insert openReturn;
openReturn.OwnerId = returnsQueue.Id;
update openReturn;

// Knowledge: three FAQ articles, published.
Id faqType = [SELECT Id FROM RecordType WHERE SobjectType = 'Knowledge__kav' AND DeveloperName = 'SDO_Knowledge_FAQ' LIMIT 1].Id;
Map<String, List<String>> articles = new Map<String, List<String>>{
    'ascend-retail-returns-policy' => new List<String>{
        'Ascend Retail: Returns policy',
        'Can I return an item?',
        '<p>You can request a return within <b>30 days</b> of the delivered date shown on your shipment. Day 30 is still eligible; day 31 is not.</p>' +
        '<p>A shipment that has not been delivered yet cannot be returned. If an order arrived in more than one shipment, each shipment is assessed on its own.</p>' +
        '<p>Only one return request can be open per shipment. Requesting a return does not issue a refund; our returns team emails next steps.</p>'
    },
    'ascend-retail-refund-timelines' => new List<String>{
        'Ascend Retail: Refund timelines',
        'How long do refunds take?',
        '<p>After we receive and inspect a returned item, refunds are processed within <b>5 to 7 business days</b> to the original payment method.</p>' +
        '<p>Your bank may take a few more days to show the credit. Refund decisions are made by the returns team after inspection; our assistant cannot approve or promise a refund.</p>'
    },
    'ascend-retail-final-sale-items' => new List<String>{
        'Ascend Retail: Final-sale items',
        'Can I return a final-sale item?',
        '<p>Items marked <b>Final sale</b> cannot be returned or exchanged, even within 30 days of delivery.</p>' +
        '<p>If a final-sale item arrived damaged, contact our team so a specialist can review it.</p>'
    }
};

List<Knowledge__kav> existing = [SELECT Id, KnowledgeArticleId, PublishStatus, UrlName FROM Knowledge__kav WHERE UrlName IN :articles.keySet() AND Language = 'en_US'];
Set<String> present = new Set<String>();
for (Knowledge__kav k : existing) {
    present.add(k.UrlName);
}
List<Knowledge__kav> drafts = new List<Knowledge__kav>();
for (String url : articles.keySet()) {
    if (present.contains(url)) {
        continue;
    }
    List<String> v = articles.get(url);
    drafts.add(new Knowledge__kav(
        RecordTypeId = faqType,
        Title = v[0],
        UrlName = url,
        Language = 'en_US',
        FAQ_Question__c = v[1],
        FAQ_Answer__c = v[2],
        Summary = v[1],
        IsVisibleInPkb = true,
        IsVisibleInCsp = true,
        IsVisibleInPrm = true
    ));
}
insert drafts;
for (Knowledge__kav k : [SELECT KnowledgeArticleId FROM Knowledge__kav WHERE Id IN :drafts]) {
    KbManagement.PublishingService.publishArticle(k.KnowledgeArticleId, true);
}

System.debug('Ascend seed complete. Shipments: ' + [SELECT COUNT() FROM Shop_Order__c WHERE Contact__c IN :shoppers] +
    ', published articles: ' + [SELECT COUNT() FROM Knowledge__kav WHERE UrlName LIKE 'ascend-retail-%' AND PublishStatus = 'Online']);
