import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import getActiveProcessSteps from '@salesforce/apex/BedrockDynamicProcessController.getActiveProcessSteps';

const ACTION_LAUNCH_FLOW = 'Launch Flow';
const ACTION_EDIT_RECORD = 'Edit Record';

const CSS_INCOMPLETE = 'slds-path__item slds-is-incomplete';
const CSS_CURRENT    = 'slds-path__item slds-is-current slds-is-active';

export default class BedrockDynamicProcessFramework extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    @api renderingStyle = 'Chevron';

    @track processSteps = [];
    @track selectedStep = null;
    @track isModalOpen  = false;
    @track isFlowActive = false;
    @track activeFlowApiName;
    @track flowInputVariables = [];
    @track errorMessage;

    // -------------------------------------------------------------------------
    // Dynamic field resolution
    // -------------------------------------------------------------------------

    // Account uses SDO_Sales_Region__c directly; other objects use Region__c.
    get regionField() {
        if (!this.objectApiName) return null;
        return this.objectApiName === 'Account'
            ? 'Account.SDO_Sales_Region__c'
            : `${this.objectApiName}.Region__c`;
    }

    // Only Opportunity has a standard Amount field; omit for other objects
    // to prevent getRecord from erroring on a missing field.
    get amountField() {
        const objectsWithAmount = ['Opportunity'];
        return (this.objectApiName && objectsWithAmount.includes(this.objectApiName))
            ? `${this.objectApiName}.Amount`
            : null;
    }

    get ratingField() {
        if (!this.objectApiName) return null;
        return `${this.objectApiName}.Customer_Rating__c`;
    }

    get _recordFields() {
        if (!this.objectApiName || !this.recordId) return [];
        return [this.regionField, this.amountField, this.ratingField].filter(f => f !== null);
    }

    // -------------------------------------------------------------------------
    // Wire: live record attributes
    // -------------------------------------------------------------------------

    @track _currentRegion;
    @track _currentAmount;
    @track _currentRating;

    @wire(getRecord, { recordId: '$recordId', fields: '$_recordFields' })
    wiredRecord({ error, data }) {
        if (data) {
            this._currentRegion = getFieldValue(data, this.regionField) ?? null;
            this._currentAmount = getFieldValue(data, this.amountField) ?? null;
            this._currentRating = getFieldValue(data, this.ratingField) ?? null;
        } else if (error) {
            this._currentRegion = null;
            this._currentAmount = null;
            this._currentRating = null;
        }
    }

    // -------------------------------------------------------------------------
    // Wire: matching process steps
    // -------------------------------------------------------------------------

    @wire(getActiveProcessSteps, {
        objectApiName: '$objectApiName',
        currentRegion: '$_currentRegion',
        currentAmount: '$_currentAmount',
        currentRating: '$_currentRating'
    })
    wiredSteps({ error, data }) {
        if (data) {
            this.errorMessage = undefined;
            this.processSteps = data.map((step, idx) => this._enrichStep(step, idx, -1));
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
        event.preventDefault();
        const targetId = event.currentTarget.dataset.id;
        const clicked  = this.processSteps.find(s => s.stepId === targetId);
        if (!clicked) return;

        this.processSteps = this.processSteps.map(s => ({
            ...s,
            computedClass: s.stepId === targetId ? CSS_CURRENT : CSS_INCOMPLETE,
            isSelected:    s.stepId === targetId
        }));

        // Always capture the selected step and open the description modal first.
        // The action button in the footer then executes the configured action.
        this.selectedStep = { ...clicked };
        this.isModalOpen  = true;
        this.isFlowActive = false;
    }

    // Fires when the user clicks the action button in the modal footer.
    handleActionButton() {
        const step = this.selectedStep;
        if (!step) return;

        switch (step.actionType) {
            case ACTION_LAUNCH_FLOW:
                if (step.actionTarget) {
                    this.activeFlowApiName  = step.actionTarget;
                    this.flowInputVariables = [{ name: 'recordId', type: 'String', value: this.recordId }];
                    this.isModalOpen  = false;
                    this.isFlowActive = true;
                }
                break;

            case ACTION_EDIT_RECORD:
                this.closeModal();
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId:      this.recordId,
                        objectApiName: this.objectApiName,
                        actionName:    'edit'
                    }
                });
                break;

            default:
                // 'Open Modal' — the modal itself is the action; just close it.
                this.closeModal();
                break;
        }
    }

    closeModal() {
        this.isModalOpen  = false;
        this.selectedStep = null;
    }

    closeActionContainer() {
        this.isFlowActive       = false;
        this.activeFlowApiName  = undefined;
        this.flowInputVariables = [];
        this.selectedStep       = null;
    }

    handleFlowStatusChange(event) {
        const { status } = event.detail;
        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.closeActionContainer();
        }
    }

    // -------------------------------------------------------------------------
    // Computed getters
    // -------------------------------------------------------------------------

    get isChevron() { return this.renderingStyle === 'Chevron'; }
    get isButtons()  { return this.renderingStyle === 'Buttons'; }
    get hasSteps()   { return !this.hasError && this.processSteps.length > 0; }
    get isEmpty()    { return !this.hasError && this.processSteps.length === 0; }
    get hasError()   { return !!this.errorMessage; }
    get hasModalAction() {
        return this.selectedStep && this.selectedStep.actionType !== 'Open Modal';
    }

    get emptyMessage() {
        return `No active process configuration found for: ${this.objectApiName ?? 'unknown'}`;
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    _enrichStep(step, idx, selectedIdx) {
        return {
            stepId:        step.stepId,
            stepLabel:     step.stepLabel,
            displayOrder:  step.displayOrder,
            actionType:    step.actionType,
            actionTarget:  step.actionTarget,
            description:   step.description,
            computedClass: idx === selectedIdx ? CSS_CURRENT : CSS_INCOMPLETE,
            isSelected:    idx === selectedIdx,
            buttonVariant: idx === selectedIdx ? 'brand' : 'neutral'
        };
    }
}
