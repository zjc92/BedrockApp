import { LightningElement } from 'lwc';

export default class BedrockHeadquartersMap extends LightningElement {
    zoomLevel = 15;

    mapMarkers = [
        {
            location: {
                Street: 'The Landmark @ One Market, Suite 300',
                City: 'San Francisco',
                State: 'CA',
                PostalCode: '94105',
                Country: 'USA'
            },
            title: 'Bedrock Corporate Headquarters',
            description: 'The Landmark @ One Market, Suite 300, San Francisco, CA 94105'
        }
    ];
}
