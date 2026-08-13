# Candidate API Contract

## Purpose

This API is used to send selected student candidate information
from the Salesforce Placement Management System to the external
recruitment system.

---

## Endpoint

POST /candidates

---

## Request

### Method

POST

### Content-Type

application/json

### Request Body

{
  "studentId": "Salesforce Student Id",
  "name": "Student Name",
  "email": "student@example.com",
  "branch": "CSE",
  "cgpa": 9.2,
  "jobId": "Salesforce Job Id",
  "company": "Amazon",
  "role": "Software Engineer",
  "selectionDate": "2026-08-13"
}

---

## Success Response

### HTTP 200 / 201

{
  "success": true,
  "externalCandidateId": "EXT-1001"
}

---

## Error Responses

### 400 - Bad Request

{
  "success": false,
  "error": "Invalid candidate data"
}

### 401 - Unauthorized

{
  "success": false,
  "error": "Authentication failed"
}

### 403 - Forbidden

{
  "success": false,
  "error": "Access denied"
}

### 500 - Internal Server Error

{
  "success": false,
  "error": "External server error"
}