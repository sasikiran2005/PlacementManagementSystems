public with sharing class ExternalPlacementSyncJob
    implements Queueable, Database.AllowsCallouts {

    private Id applicationId;

    public ExternalPlacementSyncJob(Id applicationId) {
        this.applicationId = applicationId;
    }

    public void execute(QueueableContext context) {

        System.debug(
            '===== External Placement Sync Started ====='
        );

        Application__c app = [
            SELECT
                Id,
                Name,
                Status__c,
                Application_Date__c,

                Student__c,
                Student__r.Name,
                Student__r.Email__c,
                Student__r.Branch__c,
                Student__r.CGPA__c,

                Job__c,
                Job__r.Name,
                Job__r.Role__c,

                Integration_Status__c,
                External_Candidate_Id__c,
                Last_Integration_Attempt__c,
                Integration_Error__c

            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];


        /*
         * ========================================================
         * Idempotency check
         * ========================================================
         */
        if (
            app.Integration_Status__c == 'Sent' &&
            String.isNotBlank(
                app.External_Candidate_Id__c
            )
        ) {

            System.debug(
                'Candidate already synchronized. Skipping.'
            );

            return;
        }


        /*
         * ========================================================
         * Build candidate request
         * ========================================================
         */
        Map<String, Object> candidateData =
            new Map<String, Object>();

        candidateData.put(
            'studentId',
            String.valueOf(app.Student__c)
        );

        candidateData.put(
            'name',
            app.Student__r.Name
        );

        candidateData.put(
            'email',
            app.Student__r.Email__c
        );

        candidateData.put(
            'branch',
            app.Student__r.Branch__c
        );

        candidateData.put(
            'cgpa',
            app.Student__r.CGPA__c
        );

        candidateData.put(
            'jobId',
            String.valueOf(app.Job__c)
        );

        candidateData.put(
            'company',
            app.Job__r.Name
        );

        candidateData.put(
            'role',
            app.Job__r.Role__c
        );

        candidateData.put(
            'selectionDate',
            String.valueOf(
                app.Application_Date__c
            )
        );


        String requestBody =
            JSON.serialize(candidateData);


        System.debug(
            'Candidate Request: ' +
            requestBody
        );


        /*
         * ========================================================
         * HTTP REQUEST
         * ========================================================
         */
        HttpRequest request =
            new HttpRequest();

        request.setEndpoint(
            'callout:External_Recruitment_API/candidates'
        );

        request.setMethod('POST');

        request.setHeader(
            'Content-Type',
            'application/json'
        );

        request.setBody(requestBody);

        request.setTimeout(120000);


        /*
         * ========================================================
         * CALL OUT FIRST
         *
         * IMPORTANT:
         * No DML must happen before http.send().
         * ========================================================
         */
        try {

            Http http = new Http();

            HttpResponse response =
                http.send(request);


            Integer statusCode =
                response.getStatusCode();

            String responseBody =
                response.getBody();


            System.debug(
                'External API Status: ' +
                statusCode
            );

            System.debug(
                'External API Response: ' +
                responseBody
            );


            /*
             * ====================================================
             * SUCCESS
             * ====================================================
             */
            if (
                statusCode == 200 ||
                statusCode == 201
            ) {

                String externalCandidateId =
                    extractExternalCandidateId(
                        responseBody
                    );


                /*
                 * httpbin is a mock API and does not create
                 * a real candidate ID.
                 */
                if (
                    String.isBlank(
                        externalCandidateId
                    )
                ) {

                    externalCandidateId =
                        'EXT-MOCK-' +
                        String.valueOf(app.Id);
                }


                /*
                 * DML happens AFTER the callout.
                 */
                app.Integration_Status__c =
                    'Sent';

                app.External_Candidate_Id__c =
                    externalCandidateId;

                app.Integration_Error__c =
                    null;

                app.Last_Integration_Attempt__c =
                    System.now();

                update app;


                System.debug(
                    'Candidate synchronized successfully.'
                );


                /*
                 * Continue notification workflow.
                 */
                System.enqueueJob(
                    new PlacementNotificationJob(
                        applicationId
                    )
                );


                System.debug(
                    '===== External Placement Sync Completed ====='
                );

                return;
            }


            /*
             * ====================================================
             * 400 BAD REQUEST
             * ====================================================
             */
            if (statusCode == 400) {

                markFailed(
                    app,
                    '400 Bad Request: ' +
                    responseBody
                );

                return;
            }


            /*
             * ====================================================
             * 401 UNAUTHORIZED
             * ====================================================
             */
            if (statusCode == 401) {

                markFailed(
                    app,
                    '401 Unauthorized: Authentication failed.'
                );

                return;
            }


            /*
             * ====================================================
             * 403 FORBIDDEN
             * ====================================================
             */
            if (statusCode == 403) {

                markFailed(
                    app,
                    '403 Forbidden: Access denied.'
                );

                return;
            }


            /*
             * ====================================================
             * 500+ SERVER ERROR
             * ====================================================
             */
            if (statusCode >= 500) {

                markRetryRequired(
                    app,
                    String.valueOf(statusCode) +
                    ' Server Error: ' +
                    responseBody
                );

                return;
            }


            /*
             * ====================================================
             * OTHER HTTP ERROR
             * ====================================================
             */
            markFailed(
                app,
                'Unexpected HTTP response ' +
                statusCode +
                ': ' +
                responseBody
            );

        } catch (Exception e) {

            /*
             * The callout has already finished/failed.
             * It is now safe to perform DML.
             */
            markRetryRequired(
                app,
                'Integration exception: ' +
                e.getMessage()
            );

            System.debug(
                'Integration Exception: ' +
                e.getMessage()
            );
        }
    }


    /*
     * ============================================================
     * Extract external candidate ID
     * ============================================================
     */
    private static String extractExternalCandidateId(
        String responseBody
    ) {

        if (String.isBlank(responseBody)) {
            return null;
        }

        try {

            Map<String, Object> responseData =
                (Map<String, Object>)
                JSON.deserializeUntyped(
                    responseBody
                );


            if (
                responseData.containsKey(
                    'externalCandidateId'
                )
            ) {

                Object idValue =
                    responseData.get(
                        'externalCandidateId'
                    );

                if (idValue != null) {
                    return String.valueOf(idValue);
                }
            }


            if (
                responseData.containsKey(
                    'data'
                )
            ) {

                Object dataValue =
                    responseData.get('data');


                if (
                    dataValue instanceof Map<String, Object>
                ) {

                    Map<String, Object> data =
                        (Map<String, Object>)
                        dataValue;


                    if (
                        data.containsKey(
                            'externalCandidateId'
                        )
                    ) {

                        return String.valueOf(
                            data.get(
                                'externalCandidateId'
                            )
                        );
                    }
                }
            }

        } catch (Exception e) {

            System.debug(
                'Could not parse external candidate ID: ' +
                e.getMessage()
            );
        }

        return null;
    }


    /*
     * ============================================================
     * Mark Failed
     * ============================================================
     */
    private static void markFailed(
        Application__c app,
        String errorMessage
    ) {

        app.Integration_Status__c =
            'Failed';

        app.Integration_Error__c =
            errorMessage;

        app.Last_Integration_Attempt__c =
            System.now();

        update app;


        System.debug(
            'Integration Failed: ' +
            errorMessage
        );
    }


    /*
     * ============================================================
     * Mark Retry Required
     * ============================================================
     */
    private static void markRetryRequired(
        Application__c app,
        String errorMessage
    ) {

        app.Integration_Status__c =
            'Retry Required';

        app.Integration_Error__c =
            errorMessage;

        app.Last_Integration_Attempt__c =
            System.now();

        update app;


        System.debug(
            'Integration requires retry: ' +
            errorMessage
        );
    }
}