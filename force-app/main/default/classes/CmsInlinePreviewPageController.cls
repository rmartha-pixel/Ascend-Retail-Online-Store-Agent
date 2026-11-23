public with sharing class CmsInlinePreviewPageController {
    public String imageUrl { get; private set; }
    public String contentType { get; private set; }
    public String fileName { get; private set; }
    public Boolean hasImage { get; private set; }

    public CmsInlinePreviewPageController() {
        hasImage = false;
        contentType = 'image/jpeg';
        fileName = 'image.jpg';
        String contentKey = ApexPages.currentPage().getParameters().get('contentKey');
        if (String.isBlank(contentKey)) {
            return;
        }

        for (PublishedMediaCatalogService.PublishedAsset asset : PublishedMediaCatalogService.getPublishedAssetUrls()) {
            if (asset.contentKey == contentKey) {
                imageUrl = asset.url;
                fileName = contentKey + '.jpg';
                if (asset.url != null && asset.url.contains('.png')) {
                    contentType = 'image/png';
                    fileName = contentKey + '.png';
                }
                hasImage = String.isNotBlank(imageUrl);
                break;
            }
        }
    }
}
