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

@WebServlet("/addFeedback")
public class AddFeedbackServlet extends HttpServlet {
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
        String questions = request.getParameter("questions");

        if (questions == null || questions.trim().isEmpty()) {
            questions = "[]"; 
        }
        
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
            String dbPass = System.getenv("DB_PASSWORD");
            
            // Strict check to ensure variables are set before attempting to connect
            if (dbUrl == null || dbUser == null || dbPass == null) {
                throw new Exception("Cloud Database environment variables are missing!");
            }
            
            Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
            // ----------------------------------------------
            
            if ("All".equals(targetUser)) {
                // Removed rId == 5 because Alumni behave like students now
                if (rId == 4) { 
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
                    while(rsMen.next()) myMentees.add(rsMen.getString("username"));
                    
                    targetUser = (!myMentees.isEmpty()) ? String.join(",", myMentees) : "NONE";
                    targetDept = "Specific";
                    targetYear = "Specific";
                }
            }

            // FIX: Added link_url with an empty string ('') so MySQL doesn't crash!
            String sql = "INSERT INTO feedback_links (description, link_url, target_dept, target_year, target_user, posted_by, questions) VALUES (?, '', ?, ?, ?, ?, ?)";
            PreparedStatement ps = con.prepareStatement(sql);
            ps.setString(1, description);
            ps.setString(2, targetDept);
            ps.setString(3, targetYear);
            ps.setString(4, targetUser);
            ps.setString(5, postedBy);
            ps.setString(6, questions);
            
            ps.executeUpdate();
            con.close();
            
            // Added success message to give feedback to the user
            response.sendRedirect("home.jsp?msg=Success: Survey Pushed Successfully!");
            return;
            
        } catch (Exception e) {
            e.printStackTrace();
            response.sendRedirect("home.jsp?msg=Error: " + e.getMessage());
            return;
        }
    }
}