public with sharing class PlacementNotificationJob implements Queueable {

    private Id applicationId;

    public PlacementNotificationJob(Id applicationId) {
        this.applicationId = applicationId;
    }

    public void execute(QueueableContext context) {

        Application__c app = [
            SELECT Id,
                   Name
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];

        NotificationService.sendNotification(app);

    }

}