import { LightningElement, api, track } from 'lwc';
import getProcessSteps from '@salesforce/apex/BedrockDynamicProcessController.getProcessSteps';

const STEP_CSS = {
    base: 'slds-path__item',
    current: 'slds-path__item slds-is-current slds-is-active',
    complete: 'slds-path__item slds-is-complete',
    incomplete: 'slds-path__item slds-is-incomplete'
};

export default class BedrockDynamicProcessFramework extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track processSteps = [];
    @track selectedStep = null;

    isLoading = false;
    errorMessage;
    isModalOpen = false;
    _selectedIndex = 0;

    connectedCallback() {
        this._loadSteps();
    }

    _loadSteps() {
        if (!this.objectApiName) return;
        this.isLoading = true;
        this.errorMessage = undefined;

        getProcessSteps({ recordId: this.recordId, objectApiName: this.objectApiName })
            .then(steps => {
                this._selectedIndex = 0;
                this.processSteps = this._mapSteps(steps, 0);
            })
            .catch(error => {
                this.errorMessage =
                    error?.body?.message ?? error?.message ?? 'Unable to load process configuration.';
                this.processSteps = [];
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    _mapSteps(rawSteps, selectedIndex) {
        return rawSteps.map((step, idx) => ({
            id: step.id,
            stepLabel: step.stepLabel,
            actionType: step.actionType,
            description: step.description,
            displayOrder: step.displayOrder,
            isSelected: idx === selectedIndex,
            statusLabel: idx < selectedIndex ? 'Completed' : (idx === selectedIndex ? 'Current' : 'Incomplete'),
            cssClass: idx < selectedIndex
                ? STEP_CSS.complete
                : (idx === selectedIndex ? STEP_CSS.current : STEP_CSS.incomplete)
        }));
    }

    handleStepClick(event) {
        const stepId = event.currentTarget.dataset.stepid;
        const clickedIndex = this.processSteps.findIndex(s => s.id === stepId);
        if (clickedIndex === -1) return;
        this._selectedIndex = clickedIndex;
        this.processSteps = this._mapSteps(
            this.processSteps.map(s => ({
                id: s.id,
                stepLabel: s.stepLabel,
                actionType: s.actionType,
                description: s.description,
                displayOrder: s.displayOrder
            })),
            clickedIndex
        );
        this.selectedStep = this.processSteps[clickedIndex];
        this.isModalOpen = true;
    }

    handleModalClose() {
        this.isModalOpen = false;
        this.selectedStep = null;
    }

    get hasSteps() {
        return !this.isLoading && !this.hasError && this.processSteps.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.hasError && this.processSteps.length === 0;
    }

    get hasError() {
        return !!this.errorMessage;
    }

    get emptyMessage() {
        return `No process configuration found for object: ${this.objectApiName ?? 'unknown'}`;
    }
}
