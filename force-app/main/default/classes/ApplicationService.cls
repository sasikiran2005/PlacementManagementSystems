public with sharing class ApplicationService {

    public static void validateApplications(
        List<Application__c> applications
    ) {

        Set<Id> studentIds = new Set<Id>();
        Set<Id> jobIds = new Set<Id>();

        for (Application__c app : applications) {

            if (app.Student__c != null) {
                studentIds.add(app.Student__c);
            }

            if (app.Job__c != null) {
                jobIds.add(app.Job__c);
            }
        }

        Map<Id, Student__c> studentMap = new Map<Id, Student__c>(
            [
                SELECT Id,
                       CGPA__c,
                       Branch__c
                FROM Student__c
                WHERE Id IN :studentIds
            ]
        );

        Map<Id, Jobs__c> jobMap = new Map<Id, Jobs__c>(
            [
                SELECT Id,
                       Minimum_CGPA__c,
                       Eligible_Branch__c,
                       Last_Date__c,
                       Status__c
                FROM Jobs__c
                WHERE Id IN :jobIds
            ]
        );

        /*
         * Check for duplicate applications.
         */
        Set<String> existingApplicationKeys =
            new Set<String>();

        for (Application__c existingApp : [
            SELECT Id,
                   Student__c,
                   Job__c
            FROM Application__c
            WHERE Student__c IN :studentIds
            AND Job__c IN :jobIds
        ]) {

            String key =
                String.valueOf(existingApp.Student__c)
                + '-'
                + String.valueOf(existingApp.Job__c);

            existingApplicationKeys.add(key);
        }

        /*
         * Validate every application.
         */
        for (Application__c app : applications) {

            Student__c student =
                studentMap.get(app.Student__c);

            Jobs__c job =
                jobMap.get(app.Job__c);

            if (student == null || job == null) {
                continue;
            }

            /*
             * Duplicate application check.
             */
            String applicationKey =
                String.valueOf(app.Student__c)
                + '-'
                + String.valueOf(app.Job__c);

            if (existingApplicationKeys.contains(applicationKey)) {

                app.addError(
                    'You have already applied for this job.'
                );

                continue;
            }

            /*
             * Job status validation.
             */
            if (job.Status__c != 'Open') {

                app.addError(
                    'Job is not open.'
                );
            }

            /*
             * Deadline validation.
             */
            if (
                job.Last_Date__c != null &&
                job.Last_Date__c < Date.today()
            ) {

                app.addError(
                    'Application deadline has passed.'
                );
            }

            /*
             * CGPA validation.
             */
            if (
                job.Minimum_CGPA__c != null &&
                student.CGPA__c != null &&
                student.CGPA__c < job.Minimum_CGPA__c
            ) {

                app.addError(
                    'Student CGPA is below minimum requirement.'
                );
            }

            /*
             * Branch validation.
             */
            if (
                job.Eligible_Branch__c != null &&
                student.Branch__c != null
            ) {

                List<String> branches =
                    job.Eligible_Branch__c.split(';');

                if (!branches.contains(student.Branch__c)) {

                    app.addError(
                        'Student branch is not eligible.'
                    );
                }
            }
        }
    }


    /*
     * Creates an application after all business
     * validations have passed.
     */
    public static Id submitApplication(
        Id studentId,
        Id jobId
    ) {

        if (studentId == null || jobId == null) {

            throw new AuraHandledException(
                'Student and Job are required.'
            );
        }

        Application__c application =
            new Application__c();

        application.Student__c = studentId;
        application.Job__c = jobId;
        application.Status__c = 'Applied';

        insert application;

        return application.Id;
    }
}