public with sharing class ExternalPlacementSyncJob implements Queueable {

    private Id applicationId;

    public ExternalPlacementSyncJob(Id applicationId) {
        this.applicationId = applicationId;
    }

    public void execute(QueueableContext context) {

        System.debug('===== External Placement Sync Started =====');

        Application__c app = [
            SELECT Id, Name
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];

        // TODO: External API integration will go here later
        System.debug('Synchronizing Application: ' + app.Name);

        // Queue the next background job
        System.enqueueJob(
            new PlacementNotificationJob(applicationId)
        );

        System.debug('===== External Placement Sync Completed =====');
    }
}