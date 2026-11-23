public without sharing class RetailPolicyKnowledge {
    public static final String URL_PREFIX = 'ascend-retail-';

    @InvocableMethod(
        label='Get Returns Policy Articles'
        description='Returns the text of the published Ascend Retail knowledge articles: Returns policy, Refund timelines and Final-sale items. Answer policy questions only from this text.'
    )
    public static List<Response> getArticles(List<Request> requests) {
        String prefix = URL_PREFIX + '%';
        List<String> blocks = new List<String>();
        for (Knowledge__kav a : [
            SELECT Title, FAQ_Answer__c, Summary
            FROM Knowledge__kav
            WHERE PublishStatus = 'Online' AND Language = 'en_US' AND UrlName LIKE :prefix
            ORDER BY Title
        ]) {
            String body = String.isBlank(a.FAQ_Answer__c) ? a.Summary : a.FAQ_Answer__c.stripHtmlTags();
            blocks.add('Article: ' + a.Title + '\n' + body);
        }

        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            res.articleCount = blocks.size();
            res.articles = blocks.isEmpty() ? 'No policy articles are published.' : String.join(blocks, '\n\n');
            responses.add(res);
        }
        return responses;
    }

    public class Request {
        @InvocableVariable(label='Question' description='The shopper\'s policy question.')
        public String question;
    }

    public class Response {
        @InvocableVariable(label='Articles' description='Full text of each policy article, prefixed with its title.')
        public String articles;
        @InvocableVariable(label='Article Count' description='Number of articles returned.')
        public Integer articleCount;
    }
}