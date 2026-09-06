package com.example.login;

public class Video {
    private int id;
    private String title;
    private String fileName;
    private String department;
    private String uploadedBy;
    private String requester;
    private String uploadedAt; // NEW

    // Getters and Setters
    public int getId() { return id; }
    public void setId(int id) { this.id = id; }
    
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    
    public String getFileName() { return fileName; }
    public void setFileName(String fileName) { this.fileName = fileName; }
    
    public String getDepartment() { return department; }
    public void setDepartment(String department) { this.department = department; }

    public String getUploadedBy() { return uploadedBy; }
    public void setUploadedBy(String uploadedBy) { this.uploadedBy = uploadedBy; }

    public String getRequester() { return requester; }
    public void setRequester(String requester) { this.requester = requester; }
    
    public String getUploadedAt() { return uploadedAt; }
    public void setUploadedAt(String uploadedAt) { this.uploadedAt = uploadedAt; }
}