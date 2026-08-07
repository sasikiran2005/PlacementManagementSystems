public with sharing class OfferPostProcessingJob implements Queueable {

    private Id applicationId;

    public OfferPostProcessingJob(Id applicationId) {
        this.applicationId = applicationId;
    }

    public void execute(QueueableContext context) {

        System.debug('===== Queueable Job Started =====');

        Application__c application = [
            SELECT Id,
                   Name,
                   Status__c,
                   Student__c,
                   Job__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];

        System.debug('Processing Application : ' + application.Name);

        System.enqueueJob(
            new ExternalPlacementSyncJob(application.Id)
        );

        System.debug('===== Queueable Job Finished =====');

    }

}