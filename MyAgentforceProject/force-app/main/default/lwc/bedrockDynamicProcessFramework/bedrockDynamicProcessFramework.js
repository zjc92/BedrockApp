import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getActiveProcessSteps from '@salesforce/apex/BedrockDynamicProcessController.getActiveProcessSteps';

const CSS_INCOMPLETE = 'slds-path__item slds-is-incomplete';
const CSS_CURRENT    = 'slds-path__item slds-is-current slds-is-active';
const CSS_COMPLETE   = 'slds-path__item slds-is-complete';

export default class BedrockDynamicProcessFramework extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api renderingStyle = 'Chevron';

    @track processSteps = [];
    @track selectedStep = null;

    isModalOpen = false;
    errorMessage;

    // -------------------------------------------------------------------------
    // Dynamic field resolution — built from objectApiName at runtime
    // -------------------------------------------------------------------------

    get regionField() {
        return this.objectApiName
            ? `${this.objectApiName}.Region__c`
            : null;
    }

    get amountField() {
        return this.objectApiName
            ? `${this.objectApiName}.Amount`
            : null;
    }

    get _recordFields() {
        if (!this.objectApiName || !this.recordId) return [];
        return [this.regionField, this.amountField];
    }

    // -------------------------------------------------------------------------
    // Wire: fetch live record attributes
    // -------------------------------------------------------------------------

    @track _currentRegion;
    @track _currentAmount;

    @wire(getRecord, { recordId: '$recordId', fields: '$_recordFields' })
    wiredRecord({ error, data }) {
        if (data) {
            this._currentRegion = getFieldValue(data, this.regionField) ?? null;
            this._currentAmount = getFieldValue(data, this.amountField) ?? null;
        } else if (error) {
            // Individual field errors (e.g. undeployed field) come back as a
            // partial-data response, not a top-level error, so this branch only
            // fires on a hard record-fetch failure. Null both to degrade safely.
            this._currentRegion = null;
            this._currentAmount = null;
        }
    }

    // -------------------------------------------------------------------------
    // Wire: fetch matching process steps
    // -------------------------------------------------------------------------

    @wire(getActiveProcessSteps, {
        objectApiName: '$objectApiName',
        currentRegion: '$_currentRegion',
        currentAmount: '$_currentAmount'
    })
    wiredSteps({ error, data }) {
        if (data) {
            this.errorMessage = undefined;
            this.processSteps = data.map((step, idx) =>
                this._enrichStep(step, idx, 0)
            );
        } else if (error) {
            this.errorMessage =
                error?.body?.message ??
                error?.message ??
                'Unable to load process configuration.';
            this.processSteps = [];
        }
    }

    // -------------------------------------------------------------------------
    // Event handlers
    // -------------------------------------------------------------------------

    handleChevronClick(event) {
        const targetId = event.currentTarget.dataset.id;
        this.processSteps = this.processSteps.map((step, idx) => ({
            ...step,
            computedClass: step.stepId === targetId ? CSS_CURRENT : CSS_INCOMPLETE
        }));
        this.selectedStep = this.processSteps.find(s => s.stepId === targetId) ?? null;
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.selectedStep = null;
    }

    // -------------------------------------------------------------------------
    // Computed getters
    // -------------------------------------------------------------------------

    get isChevron() {
        return this.renderingStyle === 'Chevron';
    }

    get isButtons() {
        return this.renderingStyle === 'Buttons';
    }

    get hasSteps() {
        return !this.hasError && this.processSteps.length > 0;
    }

    get isEmpty() {
        return !this.hasError && this.processSteps.length === 0;
    }

    get hasError() {
        return !!this.errorMessage;
    }

    get emptyMessage() {
        return `No active process configuration found for: ${this.objectApiName ?? 'unknown'}`;
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    _enrichStep(step, idx, selectedIdx) {
        return {
            stepId:       step.stepId,
            stepLabel:    step.stepLabel,
            displayOrder: step.displayOrder,
            actionType:   step.actionType,
            description:  step.description,
            computedClass: idx === selectedIdx ? CSS_CURRENT : CSS_INCOMPLETE,
            isSelected:   idx === selectedIdx,
            buttonVariant: idx === selectedIdx ? 'brand' : 'neutral'
        };
    }
}
