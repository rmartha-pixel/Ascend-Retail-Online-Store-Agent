import { LightningElement, wire } from "lwc";
import { getContent, updateContent } from "experience/cmsEditorApi";
import { getCurrentSelectedBlock, replaceBlock } from "experience/blockBuilderApi";
import generateIcsDownloadUrl from "@salesforce/apex/EmailIcsLinkService.generateIcsDownloadUrl";

export default class EmailIcsGenerator extends LightningElement {
  subject = "";
  description = "";
  startDateTime = "";
  endDateTime = "";
  startFieldValue = "";
  endFieldValue = "";
  icsUrl = "";
  linkHtml = "";
  statusMessage = "";
  errorMessage = "";
  isBusy = false;
  selectedBlock;
  contentBody = {};

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

  get selectionLabel() {
    if (this.selectedBlock?.definition) {
      return `Selected block: ${this.selectedBlock.definition}`;
    }
    return "No block selected — Insert link adds a button/text link to the canvas.";
  }

  handleSubjectChange(event) {
    this.subject = event.target.value;
  }

  handleDescriptionChange(event) {
    this.description = event.target.value;
  }

  handleStartChange(event) {
    this.startDateTime = event.target.value;
  }

  handleEndChange(event) {
    this.endDateTime = event.target.value;
  }

  handleStartFieldChange(event) {
    this.startFieldValue = event.target.value;
  }

  handleEndFieldChange(event) {
    this.endFieldValue = event.target.value;
  }

  async handleGenerate() {
    this.errorMessage = "";
    this.statusMessage = "";
    this.isBusy = true;
    this.dispatchEvent(new CustomEvent("actionstart"));
    try {
      const result = await generateIcsDownloadUrl({
        subject: this.subject,
        description: this.description,
        startDateTime: this.startDateTime,
        endDateTime: this.endDateTime,
        startFieldValue: this.startFieldValue,
        endFieldValue: this.endFieldValue,
      });
      this.icsUrl = result.url;
      this.linkHtml = result.linkHtml;
      this.statusMessage = "ICS URL generated. Copy it or insert Add to calendar into the email.";
    } catch (error) {
      this.errorMessage = this.reduceError(error);
      this.icsUrl = "";
      this.linkHtml = "";
    } finally {
      this.isBusy = false;
      this.dispatchEvent(new CustomEvent("actiondone", { detail: { closeExtension: false } }));
    }
  }

  async handleCopyUrl() {
    if (!this.icsUrl) {
      return;
    }
    try {
      await this.copyText(this.icsUrl);
      this.statusMessage = "ICS URL copied to the clipboard.";
    } catch (error) {
      this.errorMessage = "Could not copy the ICS URL.";
    }
  }

  async handleInsert() {
    if (!this.linkHtml) {
      return;
    }
    this.errorMessage = "";
    this.dispatchEvent(new CustomEvent("actionstart"));
    try {
      if (this.selectedBlock?.id) {
        await this.insertIntoSelectedBlock();
        this.statusMessage = "Add to calendar link inserted into the selected block.";
      } else {
        await this.insertOntoCanvas();
        this.statusMessage = "Add to calendar link inserted onto the canvas.";
      }
    } catch (error) {
      this.errorMessage = this.reduceError(error);
    } finally {
      this.dispatchEvent(new CustomEvent("actiondone", { detail: { closeExtension: false } }));
    }
  }

  async insertIntoSelectedBlock() {
    const block = JSON.parse(JSON.stringify(this.selectedBlock));
    const definition = block.definition;
    block.attributes = block.attributes || {};
    const link = this.linkHtml;

    if (definition === "lightning/html") {
      block.attributes.rawHtml = `${block.attributes.rawHtml || ""}${link}`;
    } else if (definition === "lightning/paragraph" || definition === "lightning/heading") {
      block.attributes.text = `${block.attributes.text || ""}${link}`;
    } else if (definition === "lightning/button") {
      block.attributes.href = this.icsUrl;
      block.attributes.label = block.attributes.label || "Add to calendar";
    } else {
      block.type = "block";
      block.definition = "lightning/html";
      block.children = undefined;
      block.attributes = { rawHtml: link };
    }

    await replaceBlock(block, { nodeId: block.id });
  }

  async insertOntoCanvas() {
    const contentBody = JSON.parse(JSON.stringify(this.contentBody || {}));
    const rootBlock = contentBody["sfdc_cms:block"];
    if (!rootBlock?.children?.length) {
      throw new Error("Unable to find a canvas column to insert the calendar link.");
    }
    const section = rootBlock.children[0];
    const column = section.children && section.children[0];
    if (!column) {
      throw new Error("Unable to find a canvas column to insert the calendar link.");
    }
    column.children = column.children || [];
    column.children.push({
      type: "block",
      definition: "lightning/html",
      attributes: { rawHtml: this.linkHtml },
    });
    await updateContent({ contentBody });
    this.contentBody = contentBody;
  }

  async copyText(text) {
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(text);
        return;
      }
    } catch (error) {
      // Fall through.
    }
    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.style.position = "fixed";
    textarea.style.left = "-9999px";
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand("copy");
    document.body.removeChild(textarea);
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
