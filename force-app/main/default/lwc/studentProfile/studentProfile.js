import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class StudentProfile extends LightningElement {

    @api recordId;

    connectedCallback() {
        console.log('Student Profile Record Id:', this.recordId);
    }

    handleSuccess(event) {

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Student profile updated successfully.',
                variant: 'success'
            })
        );

        console.log('Updated Student:', event.detail.id);
    }

    handleError(event) {

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: event.detail.message,
                variant: 'error'
            })
        );

        console.error('Profile update error:', event.detail);
    }
}