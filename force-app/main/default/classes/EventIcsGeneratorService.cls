public with sharing class EventIcsGeneratorService {
    public class FlowInput {
        @InvocableVariable
        public String eventId;
        @InvocableVariable
        public String subject;
        @InvocableVariable
        public String description;
        @InvocableVariable
        public String webinarSession1StartDate;
        @InvocableVariable
        public String webinarSession1EndDate;
        @InvocableVariable
        public String webinarSession2StartDate;
        @InvocableVariable
        public String webinarSession2EndDate;
        @InvocableVariable
        public String webinarSession3StartDate;
        @InvocableVariable
        public String webinarSession3EndDate;
        @InvocableVariable
        public String webinarSession4StartDate;
        @InvocableVariable
        public String webinarSession4EndDate;
        @InvocableVariable
        public String webinarSession5StartDate;
        @InvocableVariable
        public String webinarSession5EndDate;
    }

    public class FlowOutput {
        @InvocableVariable
        public String eventId;
        @InvocableVariable
        public String ICSFileDownloadURL1;
        @InvocableVariable
        public String ICSFileDownloadURL2;
        @InvocableVariable
        public String ICSFileDownloadURL3;
        @InvocableVariable
        public String ICSFileDownloadURL4;
        @InvocableVariable
        public String ICSFileDownloadURL5;
    }

    @InvocableMethod(
        label='Generate Event ICS URLs'
        description='Generates ICSFileDownloadURL1..5 from event/session input values. No record query/upsert is done in Apex.'
    )
    public static List<FlowOutput> generateEventIcsUrls(List<FlowInput> inputs) {
        List<FlowOutput> results = new List<FlowOutput>();
        if (inputs == null) {
            return results;
        }

        for (FlowInput inputRow : inputs) {
            FlowOutput outputRow = new FlowOutput();
            if (inputRow != null) {
                outputRow.eventId = inputRow.eventId;

                String safeSubject = String.isBlank(inputRow.subject)
                    ? 'Event ' + (String.isBlank(inputRow.eventId) ? '' : inputRow.eventId)
                    : inputRow.subject;

                outputRow.ICSFileDownloadURL1 = generateUrlForSession(
                    safeSubject,
                    inputRow.description,
                    toDateTime(inputRow.webinarSession1StartDate),
                    toDateTime(inputRow.webinarSession1EndDate)
                );
                outputRow.ICSFileDownloadURL2 = generateUrlForSession(
                    safeSubject,
                    inputRow.description,
                    toDateTime(inputRow.webinarSession2StartDate),
                    toDateTime(inputRow.webinarSession2EndDate)
                );
                outputRow.ICSFileDownloadURL3 = generateUrlForSession(
                    safeSubject,
                    inputRow.description,
                    toDateTime(inputRow.webinarSession3StartDate),
                    toDateTime(inputRow.webinarSession3EndDate)
                );
                outputRow.ICSFileDownloadURL4 = generateUrlForSession(
                    safeSubject,
                    inputRow.description,
                    toDateTime(inputRow.webinarSession4StartDate),
                    toDateTime(inputRow.webinarSession4EndDate)
                );
                outputRow.ICSFileDownloadURL5 = generateUrlForSession(
                    safeSubject,
                    inputRow.description,
                    toDateTime(inputRow.webinarSession5StartDate),
                    toDateTime(inputRow.webinarSession5EndDate)
                );
            }
            results.add(outputRow);
        }
        return results;
    }

    public static String createAndDistributeIcs(String subject, Datetime startDT, Datetime endDT, String description) {
        return IcsGeneratorService.createAndDistributeIcs(subject, startDT, endDT, description);
    }

    private static String generateUrlForSession(String subject, String description, Datetime startDt, Datetime endDt) {
        if (startDt == null) {
            return null;
        }
        Datetime resolvedEnd = (endDt == null) ? midnightEndOfStartDate(startDt) : endDt;
        return createAndDistributeIcs(subject, startDt, resolvedEnd, description);
    }

    private static Datetime midnightEndOfStartDate(Datetime startDt) {
        Date startDate = startDt.dateGmt();
        return Datetime.newInstanceGmt(startDate.addDays(1), Time.newInstance(0, 0, 0, 0));
    }

    public static Datetime toDateTime(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }
        String v = rawValue.trim();
        try {
            return (Datetime) JSON.deserialize('"' + escapeForJson(v) + '"', Datetime.class);
        } catch (Exception e) {
            // Continue.
        }
        try {
            return Datetime.valueOf(v.contains('T') ? v.replace('T', ' ').replace('Z', '') : v);
        } catch (Exception e) {
            // Continue.
        }
        try {
            return Datetime.valueOfGmt(v.contains('T') ? v.replace('T', ' ').replace('Z', '') : v);
        } catch (Exception e) {
            // Continue.
        }
        try {
            return Datetime.parse(v);
        } catch (Exception e) {
            // Continue.
        }
        try {
            Date parsedDate = Date.valueOf(v.replace('/', '-'));
            return Datetime.newInstanceGmt(parsedDate, Time.newInstance(0, 0, 0, 0));
        } catch (Exception e) {
            return null;
        }
    }

    private static String escapeForJson(String value) {
        return value.replace('\\', '\\\\').replace('"', '\\"');
    }
}
