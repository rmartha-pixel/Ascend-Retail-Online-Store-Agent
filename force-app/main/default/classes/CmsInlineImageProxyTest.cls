@IsTest
private class CmsInlineImageProxyTest {
    private class ImageMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'image/jpeg');
            res.setBodyAsBlob(Blob.valueOf('fake-image'));
            return res;
        }
    }

    @IsTest
    static void preview_returnsNotFoundForUnknownKey() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/cmsInlineImage/UNKNOWNKEY';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        CmsInlineImageProxy.preview();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
    }
}
