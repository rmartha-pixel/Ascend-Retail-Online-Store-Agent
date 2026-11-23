@IsTest
private class EmailIcsLinkServiceTest {
    @IsTest
    static void generateIcsDownloadUrl_usesPastedFieldValuesOverPickers() {
        Test.startTest();
        EmailIcsLinkService.IcsLinkResult result = EmailIcsLinkService.generateIcsDownloadUrl(
            'Office Hours',
            'Bring questions',
            '2020-01-01T00:00:00',
            '2020-01-01T01:00:00',
            '2026-09-22T15:00:00Z',
            '2026-09-22T16:00:00Z'
        );
        Test.stopTest();
        System.assertNotEquals(null, result.url);
        System.assertEquals('Office Hours', result.subject);
        System.assert(result.linkHtml.contains('Add to calendar'));
        System.assert(result.linkHtml.contains(result.url.replace('&', '&amp;')));
    }
}
