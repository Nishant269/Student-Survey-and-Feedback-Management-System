package com.example.login;

import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Timestamp;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet("/VideoGalleryServlet")
public class VideoGalleryServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        
        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("uid") == null) {
            response.sendRedirect("login.html");
            return;
        }

        String uid = (String) session.getAttribute("uid");
        String userName = (String) session.getAttribute("userName");
        Object roleObj = session.getAttribute("roleId");
        int rId = (roleObj != null) ? (Integer) roleObj : 0;
        boolean isHod = session.getAttribute("isHod") != null ? (Boolean) session.getAttribute("isHod") : false;
        
        Map<String, List<Video>> groupedVideos = new LinkedHashMap<>();
        List<Map<String, String>> requestHistory = new ArrayList<>(); 
        String userDept = "General"; 
        
        SimpleDateFormat sdf = new SimpleDateFormat("MMM dd, yyyy - hh:mm a");
        
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            
            // --- UPDATED CLOUD-ONLY DATABASE CONNECTION ---
            String dbUrl = System.getenv("DB_URL");
            String dbUser = System.getenv("DB_USER");
            String dbPassword = System.getenv("DB_PASSWORD");
            
            // Strict check to ensure variables are set before attempting to connect
            if (dbUrl == null || dbUser == null || dbPassword == null) {
                throw new Exception("Cloud Database environment variables are missing!");
            }
            
            try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPassword)) {
                
                PreparedStatement psUser = con.prepareStatement("SELECT department FROM users WHERE username = ?");
                psUser.setString(1, uid);
                ResultSet rsUser = psUser.executeQuery();
                if (rsUser.next()) {
                    String dbDept = rsUser.getString("department");
                    if(dbDept != null && !dbDept.isEmpty()) userDept = dbDept;
                }

                String sql;
                PreparedStatement ps;

                if (rId == 1) { 
                    sql = "SELECT v.*, r.posted_by AS requester FROM videos v LEFT JOIN video_requests r ON v.request_id = r.id WHERE v.status = 'approved' ORDER BY r.posted_by, v.uploaded_by, v.id DESC";
                    ps = con.prepareStatement(sql);
                } else if (rId == 4 && isHod) {
                    sql = "SELECT v.*, r.posted_by AS requester FROM videos v LEFT JOIN video_requests r ON v.request_id = r.id WHERE v.status = 'approved' AND (v.request_id = 0 OR r.posted_by IN (SELECT name FROM users WHERE department = ?) OR r.posted_by IN (SELECT username FROM users WHERE department = ?)) ORDER BY r.posted_by, v.uploaded_by, v.id DESC";
                    ps = con.prepareStatement(sql);
                    ps.setString(1, userDept);
                    ps.setString(2, userDept);
                } else if (rId == 4 || rId == 3) { // CHANGED: Removed rId == 5
                    sql = "SELECT v.*, r.posted_by AS requester FROM videos v LEFT JOIN video_requests r ON v.request_id = r.id WHERE v.status = 'approved' AND (v.request_id = 0 OR r.posted_by = ?) ORDER BY v.uploaded_by, v.id DESC";
                    ps = con.prepareStatement(sql);
                    ps.setString(1, userName);
                } else { // CHANGED: Applies to Students (2) and Alumni (5)
                    sql = "SELECT v.*, r.posted_by AS requester FROM videos v LEFT JOIN video_requests r ON v.request_id = r.id WHERE v.status = 'approved' AND v.request_id = 0 AND (v.department = ? OR v.department = 'General') ORDER BY v.uploaded_by, v.id DESC";
                    ps = con.prepareStatement(sql);
                    ps.setString(1, userDept);
                }

                ResultSet rs = ps.executeQuery();
                while (rs.next()) {
                    Video v = new Video();
                    v.setId(rs.getInt("id"));
                    v.setTitle(rs.getString("title"));
                    v.setFileName(rs.getString("filename"));
                    v.setDepartment(rs.getString("department"));
                    v.setUploadedBy(rs.getString("uploaded_by"));
                    
                    Timestamp upTime = rs.getTimestamp("uploaded_at");
                    v.setUploadedAt(upTime != null ? sdf.format(upTime) : "Unknown Date");
                    
                    int reqId = rs.getInt("request_id");
                    String requester = rs.getString("requester");
                    
                    String groupName = (reqId == 0 || requester == null) ? "Lectures by: " + v.getUploadedBy() : "Assignments Requested by: " + requester;
                    
                    if (!groupedVideos.containsKey(groupName)) {
                        groupedVideos.put(groupName, new ArrayList<>());
                    }
                    groupedVideos.get(groupName).add(v);
                }
                
                // CHANGED: Task History only available for Staff
                if (rId == 1 || rId == 3 || rId == 4) {
                    String histSql = (rId == 1) 
                        ? "SELECT * FROM video_requests ORDER BY created_at DESC" 
                        : "SELECT * FROM video_requests WHERE posted_by = ? ORDER BY created_at DESC";
                    PreparedStatement psHist = con.prepareStatement(histSql);
                    if (rId != 1) psHist.setString(1, userName);
                    
                    ResultSet rsHist = psHist.executeQuery();
                    while(rsHist.next()) {
                        Map<String,String> m = new HashMap<>();
                        m.put("id", String.valueOf(rsHist.getInt("id")));
                        m.put("desc", rsHist.getString("description"));
                        m.put("posted_by", rsHist.getString("posted_by"));
                        
                        Timestamp exp = rsHist.getTimestamp("expiry_date");
                        boolean active = true;
                        if(exp != null) {
                            active = exp.after(new Date()); 
                            m.put("expiry", sdf.format(exp));
                        } else {
                            m.put("expiry", "No Expiry Limit");
                        }
                        m.put("status", active ? "Active" : "Expired");
                        
                        requestHistory.add(m);
                    }
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }

        request.setAttribute("groupedVideos", groupedVideos);
        request.setAttribute("requestHistory", requestHistory);
        request.getRequestDispatcher("videos.jsp").forward(request, response);
    }
}