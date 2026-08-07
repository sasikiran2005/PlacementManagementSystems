public with sharing class ApplicationService {

    public static void validateApplications(List<Application__c> applications){

        Set<Id> studentIds = new Set<Id>();
        Set<Id> jobIds = new Set<Id>();

        for(Application__c app : applications){

            if(app.Student__c != null){
                studentIds.add(app.Student__c);
            }

            if(app.Job__c != null){
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

        for(Application__c app : applications){

            Student__c student = studentMap.get(app.Student__c);
            Jobs__c job = jobMap.get(app.Job__c);

            if(student == null || job == null){
                continue;
            }

            if(job.Status__c != 'Open'){
                app.addError('Job is not open.');
            }

            if(job.Last_Date__c != null &&
               job.Last_Date__c < Date.today()){

                app.addError('Application deadline has passed.');
            }

            if(student.CGPA__c < job.Minimum_CGPA__c){
                app.addError('Student CGPA is below minimum requirement.');
            }

            if(job.Eligible_Branch__c != null){

                List<String> branches =
                    job.Eligible_Branch__c.split(';');

                if(!branches.contains(student.Branch__c)){
                    app.addError('Student branch is not eligible.');
                }

            }

        }

    }

}