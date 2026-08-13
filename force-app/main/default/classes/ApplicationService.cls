public with sharing class ApplicationService {

    /*
     * ============================================================
     * BEFORE INSERT
     * ============================================================
     *
     * Validates new applications before they are inserted.
     */
    public static void beforeInsert(
        List<Application__c> applications
    ) {

        validateApplications(applications);
    }


    /*
     * ============================================================
     * VALIDATE NEW APPLICATIONS
     * ============================================================
     *
     * Checks:
     * 1. Student exists
     * 2. Job exists
     * 3. Duplicate application
     * 4. Job is Open
     * 5. Deadline has not passed
     * 6. Student CGPA meets requirement
     * 7. Student branch is eligible
     */
    public static void validateApplications(
        List<Application__c> applications
    ) {

        Set<Id> studentIds = new Set<Id>();
        Set<Id> jobIds = new Set<Id>();

        /*
         * Collect Student and Job IDs.
         */
        for (Application__c app : applications) {

            if (app.Student__c != null) {
                studentIds.add(app.Student__c);
            }

            if (app.Job__c != null) {
                jobIds.add(app.Job__c);
            }
        }


        /*
         * Get Student records.
         */
        Map<Id, Student__c> studentMap =
            new Map<Id, Student__c>(
                [
                    SELECT
                        Id,
                        CGPA__c,
                        Branch__c
                    FROM Student__c
                    WHERE Id IN :studentIds
                ]
            );


        /*
         * Get Job records.
         */
        Map<Id, Jobs__c> jobMap =
            new Map<Id, Jobs__c>(
                [
                    SELECT
                        Id,
                        Minimum_CGPA__c,
                        Eligible_Branch__c,
                        Last_Date__c,
                        Status__c
                    FROM Jobs__c
                    WHERE Id IN :jobIds
                ]
            );


        /*
         * Find existing applications.
         *
         * This query is only used for INSERT validation.
         */
        Set<String> existingApplicationKeys =
            new Set<String>();

        if (!studentIds.isEmpty() && !jobIds.isEmpty()) {

            for (Application__c existingApp : [
                SELECT
                    Id,
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
        }


        /*
         * Track applications within the same transaction.
         *
         * This also prevents two new records for the same
         * Student + Job combination in one transaction.
         */
        Set<String> newApplicationKeys =
            new Set<String>();


        /*
         * Validate each application.
         */
        for (Application__c app : applications) {

            /*
             * Student validation.
             */
            if (app.Student__c == null) {

                app.addError(
                    'Student is required.'
                );

                continue;
            }


            /*
             * Job validation.
             */
            if (app.Job__c == null) {

                app.addError(
                    'Job is required.'
                );

                continue;
            }


            Student__c student =
                studentMap.get(app.Student__c);

            Jobs__c job =
                jobMap.get(app.Job__c);


            /*
             * Make sure related records exist.
             */
            if (student == null) {

                app.addError(
                    'Student record could not be found.'
                );

                continue;
            }


            if (job == null) {

                app.addError(
                    'Job record could not be found.'
                );

                continue;
            }


            /*
             * Create Student + Job combination key.
             */
            String applicationKey =
                String.valueOf(app.Student__c)
                + '-'
                + String.valueOf(app.Job__c);


            /*
             * Duplicate application check.
             *
             * Existing database record.
             */
            if (existingApplicationKeys.contains(applicationKey)) {

                app.addError(
                    'You have already applied for this job.'
                );

                continue;
            }


            /*
             * Duplicate application check.
             *
             * Another application in the same transaction.
             */
            if (newApplicationKeys.contains(applicationKey)) {

                app.addError(
                    'You have already applied for this job.'
                );

                continue;
            }


            /*
             * Remember this application.
             */
            newApplicationKeys.add(applicationKey);


            /*
             * Job status validation.
             */
            if (job.Status__c != 'Open') {

                app.addError(
                    'Job is not open.'
                );

                continue;
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

                continue;
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

                continue;
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
     * ============================================================
     * SUBMIT APPLICATION
     * ============================================================
     *
     * Called from the Eligible Jobs LWC.
     */
    @AuraEnabled
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


        /*
         * The before-insert trigger automatically
         * calls validateApplications().
         */
        insert application;


        return application.Id;
    }
}