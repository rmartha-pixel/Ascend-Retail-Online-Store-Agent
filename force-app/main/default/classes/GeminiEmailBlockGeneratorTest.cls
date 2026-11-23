@IsTest
private class GeminiEmailBlockGeneratorTest {
    private class GeminiMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"candidates":[{"content":{"parts":[{"text":"{\\"subjectLine\\":\\"Welcome\\",\\"blocks\\":[]}"}]}}]}'
            );
            return res;
        }
    }

    @IsTest
    static void generateEmailBlocks_requiresPrompt() {
        try {
            GeminiEmailBlockGenerator.generateEmailBlocks('');
            System.assert(false, 'Expected exception for blank prompt');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void generateEmailBlocks_parsesGeminiResponse() {
        Test.setMock(HttpCalloutMock.class, new GeminiMock());
        Test.startTest();
        String result = GeminiEmailBlockGenerator.generateEmailBlocks('Create a welcome email');
        Test.stopTest();
        System.assert(result.contains('Welcome'));
    }
}
