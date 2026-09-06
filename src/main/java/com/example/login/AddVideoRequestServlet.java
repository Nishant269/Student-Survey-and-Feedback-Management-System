package com.example.login;

import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.List;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet("/addVideoRequest")
public class AddVideoRequestServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        
        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("userName") == null) {
            response.sendRedirect("login.html");
            return;
        }

        String postedBy = (String) session.getAttribute("userName");
        String uid = (String) session.getAttribute("uid");
        Object roleObj = session.getAttribute("roleId");
        int rId = (roleObj != null) ? (Integer) roleObj : 0;
        
        String description = request.getParameter("description");
        String expiryDate = request.getParameter("expiry_date"); 
        
        // 1. Get Form Values
        String[] depts = request.getParameterValues("target_dept");
        String targetDept = (depts != null) ? String.join(",", depts) : "All";
        
        String[] years = request.getParameterValues("target_year");
        String targetYear = (years != null) ? String.join(",", years) : "All";
        
        String[] users = request.getParameterValues("target_user");
        String targetUser = (users != null && !users[0].equals("All")) ? String.join(",", users) : "All";

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
            
            Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPassword);
            // ----------------------------------------------
            
            // --- 2. APPLY ROLE-BASED DEFAULTS ---
            if ("All".equals(targetUser)) {
                if (rId == 4 || rId == 5) { 
                    PreparedStatement psFac = con.prepareStatement("SELECT department FROM users WHERE username = ?");
                    psFac.setString(1, uid);
                    ResultSet rsFac = psFac.executeQuery();
                    if(rsFac.next()){
                        targetDept = rsFac.getString("department");
                    }
                } else if (rId == 3) {
                    List<String> myMentees = new ArrayList<>();
                    PreparedStatement psMen = con.prepareStatement("SELECT username FROM users WHERE mentor_uid = ?");
                    psMen.setString(1, uid);
                    ResultSet rsMen = psMen.executeQuery();
                    while(rsMen.next()) {
                        myMentees.add(rsMen.getString("username"));
                    }
                    if (!myMentees.isEmpty()) {
                        targetUser = String.join(",", myMentees);
                    } else {
                        targetUser = "NONE"; 
                    }
                    targetDept = "Specific";
                    targetYear = "Specific";
                }
            }

            // 3. Save to DB 
            String sql = "INSERT INTO video_requests (description, target_dept, target_year, target_user, posted_by, expiry_date) VALUES (?, ?, ?, ?, ?, ?)";
            PreparedStatement ps = con.prepareStatement(sql);
            ps.setString(1, description);
            ps.setString(2, targetDept);
            ps.setString(3, targetYear);
            ps.setString(4, targetUser);
            ps.setString(5, postedBy);
            
            // FIXED: Using java.sql.Types.TIMESTAMP instead of DATETIME
            if (expiryDate != null && !expiryDate.isEmpty()) {
                ps.setString(6, expiryDate.replace("T", " ") + ":00");
            } else {
                ps.setNull(6, java.sql.Types.TIMESTAMP);
            }
            
            ps.executeUpdate();
            con.close();
            
            response.sendRedirect("home.jsp?msg=Success: Video task pushed!");
        } catch (Exception e) {
            e.printStackTrace();
            response.sendRedirect("home.jsp?msg=Error: " + e.getMessage());
        }
    }
}