import { LightningElement, api } from 'lwc';
import getRelationshipTree from '@salesforce/apex/IndirectAccountViewerController.getRelationshipTree';

const USD_FORMATTER = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
});

export default class IndirectAccountViewer extends LightningElement {
    @api recordId;
    @api recordLimit = 10;
    @api sortBy = 'Name';
    @api sortDirection = 'ASC';

    rootAccountName;
    directContacts = [];
    indirectAccounts = [];
    errorMessage;
    isLoading = false;

    connectedCallback() {
        this._loadData();
    }

    _loadData() {
        if (!this.recordId) return;
        this.isLoading = true;
        this.errorMessage = undefined;

        getRelationshipTree({
            recordId: this.recordId,
            recordLimit: this.recordLimit,
            sortBy: this.sortBy,
            sortDirection: this.sortDirection
        })
            .then(tree => {
                this.rootAccountName = tree.rootAccountName;
                this.directContacts = tree.directContacts ?? [];
                this.indirectAccounts = (tree.indirectAccounts ?? []).map(acc => ({
                    ...acc,
                    formattedRevenue: acc.lifetimeValue != null
                        ? USD_FORMATTER.format(acc.lifetimeValue)
                        : null
                }));
            })
            .catch(error => {
                this.errorMessage =
                    error?.body?.message ?? error?.message ?? 'An unexpected error occurred.';
                this.directContacts = [];
                this.indirectAccounts = [];
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get hasData() {
        return !this.isLoading && !this.hasError &&
            (this.directContacts.length > 0 || this.indirectAccounts.length > 0);
    }

    get isEmpty() {
        return !this.isLoading && !this.hasError &&
            this.directContacts.length === 0 && this.indirectAccounts.length === 0;
    }

    get hasError() {
        return !!this.errorMessage;
    }
}
