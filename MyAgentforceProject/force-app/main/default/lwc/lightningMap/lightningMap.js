import { LightningElement } from 'lwc';

export default class LightningMap extends LightningElement {
    zoomLevel = 14;

    mapMarkers = [
        {
            location: {
                Street: '415 Mission St',
                City: 'San Francisco',
                State: 'CA',
                PostalCode: '94105',
                Country: 'USA'
            },
            title: 'Bedrock Corporate Headquarters',
            description: 'Salesforce Tower, San Francisco'
        }
    ];
}
