@RestResource(urlMapping='/cmsInlineImage/*')
global with sharing class CmsInlineImageProxy {
    @HttpGet
    global static void preview() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String contentKey = req.requestURI.substringAfterLast('/').substringBefore('?');

        PublishedMediaCatalogService.PublishedAsset match;
        for (PublishedMediaCatalogService.PublishedAsset asset : PublishedMediaCatalogService.getPublishedAssetUrls()) {
            if (asset.contentKey == contentKey) {
                match = asset;
                break;
            }
        }

        if (match == null || String.isBlank(match.url)) {
            res.statusCode = 404;
            res.responseBody = Blob.valueOf('Image not found');
            return;
        }

        HttpRequest imageReq = new HttpRequest();
        imageReq.setEndpoint(match.url);
        imageReq.setMethod('GET');
        imageReq.setTimeout(120000);
        HttpResponse imageRes = new Http().send(imageReq);

        String mimeType = imageRes.getHeader('Content-Type');
        if (String.isBlank(mimeType) || mimeType.contains('octet-stream') || mimeType.contains('text/html')) {
            mimeType = 'image/jpeg';
        }
        String fileName = contentKey + (mimeType.contains('png') ? '.png' : '.jpg');

        res.statusCode = imageRes.getStatusCode() == 200 ? 200 : imageRes.getStatusCode();
        res.addHeader('Content-Type', mimeType);
        res.addHeader('Content-Disposition', 'inline; filename="' + fileName + '"');
        res.addHeader('Cache-Control', 'public, max-age=86400');
        res.responseBody = imageRes.getBodyAsBlob();
    }
}
