public with sharing class GeminiEmailBlockGenerator {
    private static final String EMAIL_BLOCKS_SYSTEM_PROMPT =
        'You are an expert email content generator. Generate structured email blocks based on the user\'s request. ' +
        'You MUST respond with a valid JSON object containing a subjectLine and an array of blocks.\n\n' +
        'Response format:\n' +
        '{\n' +
        '  "subjectLine": "A compelling email subject line (max 60 characters)",\n' +
        '  "blocks": [ array of block objects ]\n' +
        '}\n\n' +
        'Available block types and their exact structure:\n\n' +
        'Add text color, textDecorationLine, fontSize, and padding as required so that the email blocks look good and professional.\n' +
        '1. HEADING block (for h1, h2, h3, etc.):\n' +
        '{\n' +
        '  "attributes": {\n' +
        '    "align": "left",\n' +
        '    "lightning:colorGroup": {\n' +
        '      "textColor": "#1a1a1a"\n' +
        '    },\n' +
        '    "lightning:padding": {\n' +
        '       "bottom": { "unit": "px", "value": 16.0 },\n' +
        '       "left": { "unit": "px", "value": 16.0 },\n' +
        '       "right": { "unit": "px", "value": 16.0 },\n' +
        '       "top": { "unit": "px", "value": 16.0 }\n' +
        '    },\n' +
        '    "lightning:typography": {\n' +
        '        "fontFamily": "{!$brand.fontFamily.arial}",\n' +
        '        "fontSize": { "unit": "px", "value": 18.0 },\n' +
        '        "fontWeight": "{!$brand.fontWeight.bold}",\n' +
        '        "letterSpacing": "normal",\n' +
        '        "lineHeight": 1.5,\n' +
        '        "textDecoration": { "textDecorationLine": [] },\n' +
        '        "textTransform": "none"\n' +
        '    },\n' +
        '    "text": "YOUR HEADING TEXT HERE"\n' +
        '  },\n' +
        '  "definition": "lightning/heading",\n' +
        '  "type": "block"\n' +
        '}\n\n' +
        '2. PARAGRAPH block:\n' +
        '{\n' +
        '  "attributes": {\n' +
        '    "align": "left",\n' +
        '    "lightning:colorGroup": {\n' +
        '      "textColor": "#3c4043"\n' +
        '    },\n' +
        '    "lightning:padding": {\n' +
        '       "bottom": { "unit": "px", "value": 16.0 },\n' +
        '       "left": { "unit": "px", "value": 16.0 },\n' +
        '       "right": { "unit": "px", "value": 16.0 },\n' +
        '       "top": { "unit": "px", "value": 16.0 }\n' +
        '    },\n' +
        '    "lightning:typography": {\n' +
        '        "fontFamily": "{!$brand.fontFamily.arial}",\n' +
        '        "fontSize": { "unit": "px", "value": 16.0 },\n' +
        '        "fontWeight": "{!$brand.fontWeight.regular}",\n' +
        '        "letterSpacing": "normal",\n' +
        '        "lineHeight": 1.5,\n' +
        '        "textDecoration": { "textDecorationLine": [] },\n' +
        '        "textTransform": "none"\n' +
        '    },\n' +
        '    "text": "YOUR PARAGRAPH TEXT HERE"\n' +
        '  },\n' +
        '  "definition": "lightning/paragraph",\n' +
        '  "type": "block"\n' +
        '}\n\n' +
        '3. HTML block (lightning/html) for custom images, links, and stylized text:\n' +
        '{\n' +
        '  "type": "block",\n' +
        '  "definition": "lightning/html",\n' +
        '  "attributes": {\n' +
        '    "rawHtml": "The text body of the HTML component containing HTML code",\n' +
        '    "lightning:colorGroup": {\n' +
        '      "backgroundColor": "{!$brand.colorScheme.root}",\n' +
        '      "textColor": "{!$brand.colorScheme.contrast}",\n' +
        '      "linkColor": "{!$brand.colorScheme.primaryAccent}",\n' +
        '      "borderColor": "{!$brand.colorScheme.neutral}"\n' +
        '    },\n' +
        '    "lightning:padding": "{!$brand.spacing.none}",\n' +
        '    "lightning:margin": "{!$brand.spacing.none}",\n' +
        '    "lightning:borderRadius": "{!$brand.borderRadius.square}",\n' +
        '    "lightning:borderWidth": "{!$brand.borderWeight.none}"\n' +
        '  }\n' +
        '}\n\n' +
        'Rules:\n' +
        '1. Use "rawHtml" for the content of the HTML block.\n' +
        '2. Ensure rawHtml contains valid, email-safe HTML code (images, links, styled spans).\n' +
        '3. When including images, use ONLY the published CMS asset URLs provided below. Never invent URLs.\n' +
        '4. Keep text content engaging and professional.\n' +
        '5. IMPORTANT: Return ONLY the JSON object, no markdown code blocks, no explanations.\n\n';

    @AuraEnabled
    public static String generateEmailBlocks(String prompt) {
        try {
            if (String.isBlank(prompt)) {
                throw new AuraHandledException('Prompt is required');
            }

            String assetCatalog = PublishedMediaCatalogService.formatAssetsForPrompt(
                PublishedMediaCatalogService.getPublishedAssetUrls()
            );
            String fullPrompt =
                EMAIL_BLOCKS_SYSTEM_PROMPT +
                'Published CMS asset URLs you may use in HTML img src attributes:\n' +
                assetCatalog +
                '\n\nUser Request:\n' +
                prompt;

            String result = callGeminiAPI(fullPrompt, 8192);
            return cleanHtmlResponse(result);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('Error in generateEmailBlocks: ' + e.getMessage());
            throw new AuraHandledException('Error generating email blocks: ' + e.getMessage());
        }
    }

    private static String callGeminiAPI(String prompt, Integer maxOutputTokens) {
        Map<String, Object> geminiRequest = new Map<String, Object>{
            'contents' => new List<Object>{
                new Map<String, Object>{
                    'parts' => new List<Object>{ new Map<String, Object>{ 'text' => prompt } }
                }
            },
            'generationConfig' => new Map<String, Object>{
                'temperature' => 0.7,
                'maxOutputTokens' => maxOutputTokens
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:GeminiNC');
        req.setHeader('Content-Type', 'application/json');
        req.setMethod('POST');
        req.setTimeout(120000);
        req.setBody(JSON.serialize(geminiRequest));

        Http http = new Http();
        HttpResponse res = http.send(req);
        Integer statusCode = res.getStatusCode();

        if (statusCode == 200) {
            return parseGeminiResponse(res.getBody());
        } else if (statusCode == 429) {
            throw new CalloutException('Rate limit exceeded. ' + parseErrorResponse(res.getBody()));
        } else if (statusCode == 400) {
            throw new CalloutException('Bad request: ' + parseErrorResponse(res.getBody()));
        } else if (statusCode == 401 || statusCode == 403) {
            throw new CalloutException('Authentication failed. Please check your Gemini API key configuration.');
        }
        throw new CalloutException('API error (Status ' + statusCode + '): ' + parseErrorResponse(res.getBody()));
    }

    private static String parseGeminiResponse(String responseBody) {
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

        if (responseMap.containsKey('candidates')) {
            List<Object> candidates = (List<Object>) responseMap.get('candidates');
            if (candidates != null && !candidates.isEmpty()) {
                Map<String, Object> firstCandidate = (Map<String, Object>) candidates[0];
                if (firstCandidate.containsKey('content')) {
                    Map<String, Object> content = (Map<String, Object>) firstCandidate.get('content');
                    if (content.containsKey('parts')) {
                        List<Object> parts = (List<Object>) content.get('parts');
                        if (parts != null && !parts.isEmpty()) {
                            Map<String, Object> firstPart = (Map<String, Object>) parts[0];
                            if (firstPart.containsKey('text')) {
                                return (String) firstPart.get('text');
                            }
                        }
                    }
                }
            }
        }
        throw new CalloutException('Unable to extract text from Gemini response. Unexpected structure.');
    }

    private static String cleanHtmlResponse(String response) {
        if (String.isBlank(response)) {
            return response;
        }

        String cleaned = response.trim();
        if (cleaned.startsWith('```json')) {
            cleaned = cleaned.removeStart('```json').trim();
        } else if (cleaned.startsWith('```html')) {
            cleaned = cleaned.removeStart('```html').trim();
        } else if (cleaned.startsWith('```')) {
            cleaned = cleaned.removeStart('```').trim();
        }
        if (cleaned.startsWith('json\n')) {
            cleaned = cleaned.removeStart('json').trim();
        }
        if (cleaned.endsWith('```')) {
            cleaned = cleaned.removeEnd('```').trim();
        }
        return cleaned;
    }

    private static String parseErrorResponse(String responseBody) {
        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            if (responseMap.containsKey('error')) {
                Map<String, Object> errorObj = (Map<String, Object>) responseMap.get('error');
                if (errorObj.containsKey('message')) {
                    return (String) errorObj.get('message');
                }
                if (errorObj.containsKey('status')) {
                    return (String) errorObj.get('status');
                }
            }
            return responseBody;
        } catch (Exception ex) {
            return responseBody;
        }
    }
}
