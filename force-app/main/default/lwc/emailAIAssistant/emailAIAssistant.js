import { LightningElement, wire } from "lwc";
import { getContent, updateContent } from "experience/cmsEditorApi";
import { getCurrentSelectedBlock, replaceBlock } from "experience/blockBuilderApi";
import getPublishedAssetUrls from "@salesforce/apex/PublishedMediaCatalogService.getPublishedAssetUrls";
import resolveEmailImageReference from "@salesforce/apex/PublishedMediaCatalogService.resolveEmailImageReference";

export default class EmailAIAssistant extends LightningElement {
  assets = [];
  searchTerm = "";
  isLoading = true;
  errorMessage = "";
  statusMessage = "";
  selectedBlock;
  contentBody = {};

  @wire(getPublishedAssetUrls)
  wiredAssets({ data, error }) {
    this.isLoading = false;
    if (data) {
      this.assets = data;
      this.errorMessage = "";
    } else if (error) {
      this.assets = [];
      this.errorMessage = this.reduceError(error);
    }
  }

  @wire(getContent, {})
  onContent({ data }) {
    if (data) {
      this.contentBody = data.contentBody;
    }
  }

  @wire(getCurrentSelectedBlock, {})
  onCurrentSelectedBlock({ data }) {
    this.selectedBlock = data ? JSON.parse(JSON.stringify(data)) : null;
  }

  get hasError() {
    return Boolean(this.errorMessage);
  }

  get hasAssets() {
    return this.filteredAssets.length > 0;
  }

  get filteredAssets() {
    const term = (this.searchTerm || "").toLowerCase();
    return (this.assets || []).filter((asset) => {
      if (!asset.url) {
        return false;
      }
      if (!term) {
        return true;
      }
      return (
        (asset.title || "").toLowerCase().includes(term) ||
        (asset.channelName || "").toLowerCase().includes(term)
      );
    });
  }

  get isInsertDisabled() {
    return false;
  }

  get selectionLabel() {
    if (this.selectedBlock?.definition) {
      return `Selected block: ${this.selectedBlock.definition}`;
    }
    return "No block selected — Insert adds an image to the email canvas.";
  }

  handleSearchChange(event) {
    this.searchTerm = event.target.value;
  }

  async handleCopyUrl(event) {
    event.preventDefault();
    event.stopPropagation();
    const previewUrl = event.currentTarget.dataset.previewUrl || event.currentTarget.dataset.url;
    if (!previewUrl) {
      return;
    }
    try {
      await this.copyText(previewUrl);
      window.open(previewUrl, "_blank", "noopener,noreferrer");
      this.statusMessage = "Preview opened in a new tab. The preview URL was copied to the clipboard.";
    } catch (error) {
      this.errorMessage = "Could not open the image preview.";
    }
  }

  async copyText(text) {
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(text);
        return;
      }
    } catch (error) {
      // Fall through to the textarea copy path used inside Lightning Locker.
    }
    this.copyWithTextarea(text);
  }

  async handleInsert(event) {
    const dataset = event.currentTarget.dataset;
    const asset = {
      url: dataset.url,
      contentKey: dataset.contentKey,
      title: dataset.title,
      altText: dataset.alt,
      useCmsReference: dataset.useCmsReference === "true" || dataset.useCmsReference === "",
    };
        this.dispatchEvent(new CustomEvent("actionstart"));
    this.statusMessage = "";
    this.errorMessage = "";

    try {
      const resolved = await resolveEmailImageReference({
        contentKey: asset.contentKey,
        title: asset.title,
        sourceUrl: asset.url,
      });
      const insertAsset = {
        ...asset,
        contentKey: resolved.contentKey,
        title: resolved.title,
        useCmsReference: true,
      };
      if (this.selectedBlock?.id) {
        await this.insertIntoSelectedBlock(insertAsset);
        this.statusMessage = "Image inserted into the selected block.";
      } else {
        await this.insertOntoCanvas(insertAsset);
        this.statusMessage = "Image inserted onto the canvas.";
      }
      this.dispatchEvent(
        new CustomEvent("actiondone", {
          detail: { closeExtension: false },
        }),
      );
    } catch (error) {
      this.errorMessage = this.reduceError(error);
    }
  }

  async insertIntoSelectedBlock(asset) {
    const block = JSON.parse(JSON.stringify(this.selectedBlock));
    const definition = block.definition;
    block.attributes = block.attributes || {};

    if (definition === "lightning/image") {
      this.applyImageInfo(block, asset);
      await this.persistSelectedImageBlock(block);
      return;
    }
    if (definition === "lightning/html") {
      const imgTag = this.buildImgTag(asset);
      block.attributes.rawHtml = `${block.attributes.rawHtml || ""}${imgTag}`;
    } else if (definition === "lightning/paragraph" || definition === "lightning/heading") {
      const currentText = block.attributes.text || "";
      block.attributes.text = `${currentText}${this.buildImgTag(asset)}`;
    } else {
      this.convertToImageBlock(block, asset);
    }

    await replaceBlock(block, { nodeId: block.id });
  }

  async insertOntoCanvas(asset) {
    const contentBody = JSON.parse(JSON.stringify(this.contentBody || {}));
    const rootBlock = contentBody["sfdc_cms:block"];
    if (!rootBlock?.children?.length) {
      throw new Error("Unable to find a canvas column to insert the image.");
    }
    const section = rootBlock.children[0];
    const column = section.children && section.children[0];
    if (!column) {
      throw new Error("Unable to find a canvas column to insert the image.");
    }
    column.children = column.children || [];
    column.children.push(this.buildImageBlock(asset));
    await updateContent({ contentBody });
  }

  applyImageInfo(block, asset) {
    const contentKey = String(asset.contentKey || "").trim();
    const title = String(asset.title || "").trim();
    if (!contentKey) {
      throw new Error("This CMS card is missing a content key, so it cannot be inserted.");
    }
    // Email Image blocks only allow source.type = imageReference plus a required ref.
    block.attributes.imageInfo = {
      altText: "",
      overrideAltText: false,
      url: `/cms/media/${contentKey}`,
      source: {
        type: "imageReference",
        ref: title || contentKey,
      },
    };

    block.attributes.imageCaption = "";
    block.attributes.title = "";
    delete block.attributes.contentKey;
    if (!block.attributes.imageFitConfig) {
      block.attributes.imageFitConfig = { width: { value: 100, unit: "%" } };
    }
  }

  async persistSelectedImageBlock(updatedBlock) {
    const contentBody = JSON.parse(JSON.stringify(this.contentBody || {}));
    const rootBlock = contentBody["sfdc_cms:block"];
    const merged = this.mergeImageInfoIntoTree(rootBlock, updatedBlock);
    if (merged) {
      await updateContent({ contentBody });
      this.contentBody = contentBody;
      return;
    }
    await replaceBlock(updatedBlock, { nodeId: updatedBlock.id });
  }

  mergeImageInfoIntoTree(node, updatedBlock) {
    if (!node || !updatedBlock?.attributes?.imageInfo) {
      return false;
    }
    if (this.mergeImageInfoById(node, updatedBlock)) {
      return true;
    }
    return this.mergeImageInfoIntoEmptyImage(node, updatedBlock);
  }

  mergeImageInfoById(node, updatedBlock) {
    if (!node || !updatedBlock?.id) {
      return false;
    }
    if (Array.isArray(node.children)) {
      for (let i = 0; i < node.children.length; i++) {
        const child = node.children[i];
        if (child?.id === updatedBlock.id) {
          this.copyImageInfo(child, updatedBlock);
          return true;
        }
        if (this.mergeImageInfoById(child, updatedBlock)) {
          return true;
        }
      }
    }
    return false;
  }

  mergeImageInfoIntoEmptyImage(node, updatedBlock) {
    if (!node || typeof node !== "object") {
      return false;
    }
    const isImage = node.definition === "lightning/image" || node.name === "sfdc_cms:image";
    if (isImage && this.isMissingImageSource(node)) {
      this.copyImageInfo(node, updatedBlock);
      return true;
    }
    if (Array.isArray(node.children)) {
      for (let i = 0; i < node.children.length; i++) {
        if (this.mergeImageInfoIntoEmptyImage(node.children[i], updatedBlock)) {
          return true;
        }
      }
    }
    return false;
  }

  isMissingImageSource(node) {
    const source = node?.attributes?.imageInfo?.source;
    if (source == null || source === "") {
      return true;
    }
    if (typeof source === "object" && !source.ref && !source.url && !source.type) {
      return true;
    }
    return false;
  }

  copyImageInfo(target, updatedBlock) {
    target.attributes = target.attributes || {};
    target.attributes.imageInfo = updatedBlock.attributes.imageInfo;
    target.attributes.imageCaption = "";
    target.attributes.title = "";
  }

  convertToImageBlock(block, asset) {
    block.type = "block";
    block.definition = "lightning/image";
    block.children = undefined;
    block.attributes = {
      "lightning:padding": "{!$brand.spacing.none}",
      "lightning:margin": "{!$brand.spacing.none}",
      "lightning:horizontalAlignment": "center",
      "lightning:borderRadius": "{!$brand.borderRadius.square}",
      "lightning:borderWidth": "{!$brand.borderWeight.none}",
      imageFitConfig: { width: { value: 100, unit: "%" } },
    };
    this.applyImageInfo(block, asset);
  }

  buildImageBlock(asset) {
    const block = {
      type: "block",
      definition: "lightning/image",
      attributes: {
        "lightning:padding": "{!$brand.spacing.none}",
        "lightning:margin": "{!$brand.spacing.none}",
        "lightning:horizontalAlignment": "center",
        "lightning:borderRadius": "{!$brand.borderRadius.square}",
        "lightning:borderWidth": "{!$brand.borderWeight.none}",
        imageFitConfig: { width: { value: 100, unit: "%" } },
      },
    };
    this.applyImageInfo(block, asset);
    return block;
  }

  buildImgTag(asset) {
    const url = this.escapeHtml(asset.url);
    return `<img src="${url}" alt="" style="max-width:100%;height:auto;" />`;
  }

  copyWithTextarea(text) {
    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.style.position = "fixed";
    textarea.style.left = "-9999px";
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand("copy");
    document.body.removeChild(textarea);
  }

  escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  reduceError(error) {
    if (!error) {
      return "Something went wrong.";
    }
    if (Array.isArray(error.body)) {
      return error.body.map((e) => e.message).join(", ");
    }
    if (error.body?.message) {
      return error.body.message;
    }
    return error.message || "Something went wrong.";
  }
}
