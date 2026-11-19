import { LightningElement, api } from 'lwc';

/**
 * One card on the board. Presentational only: the board decides flip and match state and passes
 * the resulting class and label down.
 */
export default class MemoryCard extends LightningElement {
    @api position;
    @api cardClass = 'memory-card';
    @api cardAriaLabel = 'Face-down card';
    @api symbolText = '';
    @api imageUrl;
    @api disabled = false;

    get hasImage() {
        return Boolean(this.imageUrl);
    }

    handleClick() {
        this.dispatchEvent(new CustomEvent('cardselect', { detail: { position: this.position } }));
    }
}
