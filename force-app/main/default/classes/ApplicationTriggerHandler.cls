public with sharing class ApplicationTriggerHandler {

    public static void beforeInsert(List<Application__c> newList) {
        ApplicationService.validateApplications(newList);
    }

    public static void beforeUpdate(List<Application__c> newList) {
        ApplicationService.validateApplications(newList);
    }

    public static void afterUpdate(
        List<Application__c> newList,
        Map<Id, Application__c> oldMap
    ) {

        StatisticsService.updateStatistics(newList, oldMap);

        NotificationService.sendNotifications(newList, oldMap);

    }

}