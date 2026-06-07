import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getRelationshipTree from '@salesforce/apex/IndirectAccountViewerController.getRelationshipTree';

const USD_FORMATTER = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
});

function parseRoles(roleString) {
    if (!roleString) return [];
    return roleString.split(';').map((r, i) => ({ key: i, label: r.trim() })).filter(r => r.label);
}

function mapContact(node) {
    return {
        ...node,
        roles: parseRoles(node.role)
    };
}

function mapIndirectAccount(acc) {
    return {
        ...acc,
        formattedRevenue: acc.lifetimeValue != null ? USD_FORMATTER.format(acc.lifetimeValue) : null,
        sharedContacts: (acc.sharedContacts ?? []).map(mapContact)
    };
}

export default class IndirectAccountViewer extends NavigationMixin(LightningElement) {
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
                this.directContacts = (tree.directContacts ?? []).map(mapContact);
                this.indirectAccounts = (tree.indirectAccounts ?? []).map(mapIndirectAccount);
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

    navigateToRecord(event) {
        const recordId = event.currentTarget.dataset.recordid;
        const objectApiName = event.currentTarget.dataset.objectapiname;
        if (!recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, objectApiName, actionName: 'view' }
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
