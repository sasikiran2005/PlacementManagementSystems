public with sharing class NotificationService {

    public static void sendNotifications(
        List<Application__c> newList,
        Map<Id, Application__c> oldMap
    ) {

        for (Application__c app : newList) {

            if (app.Status__c == 'Selected'
                && oldMap.get(app.Id).Status__c != 'Selected') {

                System.debug('Notification sent.');

            }

        }

    }

    public static void sendNotification(Application__c app) {

        System.debug('Notification sent for Application: ' + app.Name);

    }

}