import { LightningElement } from 'lwc';

const PRODUCTS = [
    { id: 'p1', name: 'Velvet cushion', detail: 'Moss green, 45 × 45 cm', price: '$39', swatch: 'swatch swatch-moss', badge: 'Bestseller', badgeClass: 'badge' },
    { id: 'p2', name: 'Linen throw', detail: 'Stonewashed oat', price: '$89', swatch: 'swatch swatch-oat', badge: 'New', badgeClass: 'badge' },
    { id: 'p3', name: 'Ceramic vase', detail: 'Hand-glazed terracotta', price: '$54', swatch: 'swatch swatch-clay', badge: 'Final sale', badgeClass: 'badge badge-final' },
    { id: 'p4', name: 'Oak dining chair', detail: 'Solid white oak', price: '$229', swatch: 'swatch swatch-oak', badge: 'In stock', badgeClass: 'badge' }
];

const CATEGORIES = [
    { id: 'c1', name: 'Living', count: '120 pieces', tile: 'tile tile-living' },
    { id: 'c2', name: 'Bedroom', count: '86 pieces', tile: 'tile tile-bedroom' },
    { id: 'c3', name: 'Dining', count: '64 pieces', tile: 'tile tile-dining' },
    { id: 'c4', name: 'Decor', count: '210 pieces', tile: 'tile tile-decor' }
];

const STEPS = [
    { id: 's1', number: '1', title: 'Verify in seconds', body: 'Share your order number and the email on the order. Nothing is shown until both match.' },
    { id: 's2', number: '2', title: 'See every shipment', body: 'Split orders are checked shipment by shipment, with a plain reason for anything that can’t go back.' },
    { id: 's3', number: '3', title: 'Get a case number', body: 'Eligible items get a return request straight away. Our team emails the next steps.' }
];

const POLICIES = [
    { id: 'r1', title: '30-day returns', body: 'Request a return within 30 days of the delivered date on your shipment.' },
    { id: 'r2', title: 'Final-sale items', body: 'Pieces marked Final sale can’t be returned or exchanged.' },
    { id: 'r3', title: 'Refund timelines', body: 'Refunds are processed in 5 to 7 business days after we receive and inspect your return.' }
];

export default class AscendStorefront extends LightningElement {
    products = PRODUCTS;
    categories = CATEGORIES;
    steps = STEPS;
    policies = POLICIES;
    chatHint = false;

    get year() {
        return new Date().getFullYear();
    }

    handleOpenAssistant() {
        let launched = false;
        try {
            const bootstrap = window.embeddedservice_bootstrap;
            if (bootstrap && bootstrap.utilAPI && typeof bootstrap.utilAPI.launchChat === 'function') {
                bootstrap.utilAPI.launchChat();
                launched = true;
            }
        } catch (e) {
            launched = false;
        }
        this.chatHint = !launched;
    }

    handleDismissHint() {
        this.chatHint = false;
    }

    handleScrollToReturns() {
        const target = this.template.querySelector('[data-id="returns"]');
        if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }
}
