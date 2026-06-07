import { LightningElement, api, wire } from 'lwc';
import getIndirectAccounts from '@salesforce/apex/IndirectAccountViewerController.getIndirectAccounts';

const COLUMNS = [
    { label: 'Account Name', fieldName: 'accountName', type: 'text', sortable: true },
    { label: 'Industry', fieldName: 'industry', type: 'text', sortable: true },
    { label: 'Shared Contacts', fieldName: 'sharedContactCount', type: 'number', sortable: true },
    {
        label: 'Lifetime Value',
        fieldName: 'lifetimeValue',
        type: 'currency',
        sortable: true,
        typeAttributes: { currencyCode: 'USD', minimumFractionDigits: 0 }
    },
    { label: 'Relationship Count', fieldName: 'relationshipCount', type: 'number', sortable: true }
];

export default class IndirectAccountViewer extends LightningElement {
    @api recordId;
    @api recordLimit = 10;
    @api sortBy = 'Name';
    @api sortDirection = 'ASC';

    accounts = [];
    errorMessage;
    isLoading = false;

    currentSortBy = 'Name';
    currentSortDirection = 'ASC';

    columns = COLUMNS;

    connectedCallback() {
        this.currentSortBy = this.sortBy;
        this.currentSortDirection = this.sortDirection;
        this._loadData();
    }

    _loadData() {
        if (!this.recordId) return;
        this.isLoading = true;
        this.errorMessage = undefined;

        getIndirectAccounts({
            recordId: this.recordId,
            recordLimit: this.recordLimit,
            sortBy: this.currentSortBy,
            sortDirection: this.currentSortDirection
        })
            .then(data => {
                this.accounts = data;
            })
            .catch(error => {
                this.errorMessage =
                    error?.body?.message ?? error?.message ?? 'An unexpected error occurred.';
                this.accounts = [];
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleSort(event) {
        this.currentSortBy = event.detail.fieldName;
        this.currentSortDirection = event.detail.sortDirection.toUpperCase();
        this._loadData();
    }

    get hasData() {
        return !this.isLoading && !this.hasError && this.accounts.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.hasError && this.accounts.length === 0;
    }

    get hasError() {
        return !!this.errorMessage;
    }
}
