public with sharing class ApplicationService {

    @AuraEnabled
    public static Student__c getStudent(Id studentId) {
        return [
            SELECT Id,
                   Name,
                   CGPA__c,
                   Branch__c,
                   Backlogs__c
            FROM Student__c
            WHERE Id = :studentId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static Job__c getJob(Id jobId) {
        return [
            SELECT Id,
                   Name,
                   Minimum_CGPA__c,
                   Eligible_Branch__c,
                   Last_Date__c
            FROM Job__c
            WHERE Id = :jobId
            LIMIT 1
        ];
    }

    public static Boolean checkDuplicateApplication(Id studentId, Id jobId) {

        List<Application__c> apps = [
            SELECT Id
            FROM Application__c
            WHERE Student__c = :studentId
            AND Job__c = :jobId
            LIMIT 1
        ];

        return !apps.isEmpty();
    }

    public static Boolean validateEligibility(Student__c student, Job__c job) {

        // Check CGPA
        if (student.CGPA__c < job.Minimum_CGPA__c) {
            return false;
        }

        // Check last date
        if (job.Last_Date__c < Date.today()) {
            return false;
        }

        // Check eligible branch
        if (job.Eligible_Branch__c != null &&
            !job.Eligible_Branch__c.contains(student.Branch__c)) {
            return false;
        }

        return true;
    }

    @AuraEnabled
    public static String createApplication(Id studentId, Id jobId) {

        Student__c student = getStudent(studentId);
        Job__c job = getJob(jobId);

        // Check duplicate application
        if (checkDuplicateApplication(studentId, jobId)) {
            return 'Duplicate Application';
        }

        // Check eligibility
        if (!validateEligibility(student, job)) {
            return 'Student Not Eligible';
        }

        // Create application
        Application__c app = new Application__c();
        app.Student__c = studentId;
        app.Job__c = jobId;
        app.Status__c = 'Applied';
        app.Application_Date__c = Date.today();

        insert app;

        return 'Application Submitted Successfully';
    }

    @AuraEnabled
    public static String updateApplicationStatus(Id applicationId, String status) {

        Application__c app = [
            SELECT Id, Status__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];

        app.Status__c = status;

        update app;

        return 'Application Status Updated Successfully';
    }
}