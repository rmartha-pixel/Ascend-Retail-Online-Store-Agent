@IsTest
private class IcsGeneratorServiceTest {
    @IsTest
    static void generateIcsString_includesUtcStartAndEnd() {
        Datetime startDt = Datetime.newInstanceGmt(2026, 9, 22, 15, 0, 0);
        Datetime endDt = Datetime.newInstanceGmt(2026, 9, 22, 16, 0, 0);
        String ics = IcsGeneratorService.generateIcsString('Webinar', startDt, endDt, 'Join us');
        System.assert(ics.contains('BEGIN:VCALENDAR'));
        System.assert(ics.contains('DTSTART:20260922T150000Z'));
        System.assert(ics.contains('DTEND:20260922T160000Z'));
        System.assert(ics.contains('SUMMARY:Webinar'));
    }

    @IsTest
    static void createAndDistributeIcs_returnsContentDistributionUrl() {
        Datetime startDt = Datetime.newInstanceGmt(2026, 9, 22, 15, 0, 0);
        Datetime endDt = Datetime.newInstanceGmt(2026, 9, 22, 16, 0, 0);
        Test.startTest();
        String url = IcsGeneratorService.createAndDistributeIcs('Calendar Test', startDt, endDt, 'Desc');
        Test.stopTest();
        System.assertNotEquals(null, url);
        System.assert(url.startsWith('http'));
    }
}
