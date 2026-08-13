public with sharing class ApplicationTriggerHandler {

    public static void beforeInsert(
        List<Application__c> newList
    ) {

        ApplicationService.beforeInsert(newList);
    }


    public static void beforeUpdate(
        List<Application__c> newList
    ) {

        /*
         * Do not run new-application validation here.
         *
         * Existing Applications may be updated from:
         *
         * Applied → Selected
         *
         * without being treated as duplicate applications.
         */
    }


    public static void afterUpdate(
        List<Application__c> newList,
        Map<Id, Application__c> oldMap
    ) {

        StatisticsService.updateStatistics(
            newList,
            oldMap
        );


        NotificationService.sendNotifications(
            newList,
            oldMap
        );


        /*
         * Start external integration only when
         * Status actually changes to Selected.
         */
        for (Application__c app : newList) {

            Application__c oldApp =
                oldMap.get(app.Id);


            if (
                app.Status__c == 'Selected' &&
                oldApp.Status__c != 'Selected'
            ) {

                System.enqueueJob(
                    new ExternalPlacementSyncJob(app.Id)
                );
            }
        }
    }
}