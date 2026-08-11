public with sharing class ApplicationController {

    @AuraEnabled(cacheable=true)
    public static List<Jobs__c> getEligibleJobs(Id studentId) {

        if (studentId == null) {
            return new List<Jobs__c>();
        }

        Student__c student = [
            SELECT Id,
                   CGPA__c,
                   Branch__c
            FROM Student__c
            WHERE Id = :studentId
            LIMIT 1
        ];

        List<Jobs__c> jobs = [
            SELECT Id,
                   Name,
                   Minimum_CGPA__c,
                   Eligible_Branch__c,
                   Last_Date__c,
                   Status__c
            FROM Jobs__c
            WHERE Status__c = 'Open'
            AND (
                Last_Date__c = NULL
                OR Last_Date__c >= :Date.today()
            )
            ORDER BY Last_Date__c ASC
        ];

        List<Jobs__c> eligibleJobs =
            new List<Jobs__c>();

        for (Jobs__c job : jobs) {

            if (
                job.Minimum_CGPA__c != null &&
                student.CGPA__c != null &&
                student.CGPA__c < job.Minimum_CGPA__c
            ) {
                continue;
            }

            if (
                job.Eligible_Branch__c != null &&
                student.Branch__c != null
            ) {

                List<String> branches =
                    job.Eligible_Branch__c.split(';');

                if (!branches.contains(student.Branch__c)) {
                    continue;
                }
            }

            eligibleJobs.add(job);
        }

        return eligibleJobs;
    }

    @AuraEnabled
    public static Id submitApplication(
        Id studentId,
        Id jobId
    ) {

        try {

            return ApplicationService.submitApplication(
                studentId,
                jobId
            );

        } catch (DmlException e) {

            throw new AuraHandledException(
                e.getDmlMessage(0)
            );

        } catch (Exception e) {

            throw new AuraHandledException(
                e.getMessage()
            );
        }
    }
}