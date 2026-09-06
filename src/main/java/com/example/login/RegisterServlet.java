package com.example.login;

import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet("/register")
public class RegisterServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        
        String name = request.getParameter("name").trim();
        String rollNumber = request.getParameter("roll_number").trim();
        String department = request.getParameter("department");
        String year = request.getParameter("year");
        String user = request.getParameter("username");
        String pass = request.getParameter("password");
        
        int roleId = 2; // Default Student
        if(request.getParameter("role_id") != null && !request.getParameter("role_id").isEmpty()) {
             try { roleId = Integer.parseInt(request.getParameter("role_id")); } catch (NumberFormatException e) { roleId = 2; }
        }

        // Clean Data based on Role
        if (roleId == 1) { // Admin
            department = null; year = null;
            if (rollNumber == null || rollNumber.isEmpty()) rollNumber = "ADMIN";
        } else if (roleId == 3 || roleId == 4 || roleId == 5) { // Mentor, Faculty, Alumni
            year = null; // Mentors no longer have a specific year
            if (rollNumber == null || rollNumber.isEmpty()) rollNumber = "-"; 
        }

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
            // ----------------------------------------------
            
            try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPassword)) {

                // --- 1. VERIFICATION & GET EMAIL ---
                String officialEmail = null;
                String verifySql = "";

                if (roleId == 2) { 
                    verifySql = "SELECT email FROM student_details WHERE LOWER(student_name) = LOWER(?) AND roll_number = ? AND department = ? AND year = ?";
                } else if (roleId == 3) { 
                    verifySql = "SELECT email FROM mentor_details WHERE LOWER(name) = LOWER(?) AND unique_id = ? AND department = ?"; // Removed YEAR
                } else if (roleId == 4) { 
                    verifySql = "SELECT email FROM faculty_details WHERE LOWER(name) = LOWER(?) AND unique_id = ? AND department = ?";
                } else if (roleId == 5) { 
                    verifySql = "SELECT email FROM alumni_details WHERE LOWER(name) = LOWER(?) AND roll_number = ? AND department = ?";
                } else if (roleId == 1) { 
                    verifySql = "SELECT email FROM admin_details WHERE LOWER(name) = LOWER(?) AND unique_id = ?"; 
                }

                PreparedStatement psVerify = con.prepareStatement(verifySql);
                psVerify.setString(1, name);
                psVerify.setString(2, rollNumber);
                if (roleId == 2) {
                    psVerify.setString(3, department);
                    psVerify.setString(4, year);
                } else if (roleId == 3 || roleId == 4 || roleId == 5) {
                    psVerify.setString(3, department);
                }
                
                ResultSet rsVerify = psVerify.executeQuery();
                if (rsVerify.next()) {
                    officialEmail = rsVerify.getString("email");
                }

                if (officialEmail == null || officialEmail.isEmpty()) {
                    response.getWriter().println("<h1>Registration Failed</h1><p>Could not verify details or missing official email.</p><a href='register.html'>Try Again</a>");
                    return; 
                }

                // --- 2. DUPLICATE CHECK ---
                String checkSql = "SELECT id FROM users WHERE roll_number = ? AND role_id = ?";
                PreparedStatement psCheck = con.prepareStatement(checkSql);
                psCheck.setString(1, rollNumber);
                psCheck.setInt(2, roleId);
                if (psCheck.executeQuery().next()) {
                    response.getWriter().println("<h1>Account Already Exists</h1><a href='login.html'>Login Here</a>"); return;
                }
                
                // --- 3. USERNAME CHECK ---
                String userCheckSql = "SELECT id FROM users WHERE username = ?";
                PreparedStatement psUserCheck = con.prepareStatement(userCheckSql);
                psUserCheck.setString(1, user);
                if (psUserCheck.executeQuery().next()) {
                    response.getWriter().println("<h1>Username Taken</h1><a href='register.html'>Try Again</a>"); return;
                }

                // --- 4. GENERATE OTP & SAVE TO SESSION ---
                String generatedOtp = String.format("%06d", new Random().nextInt(999999));
                
                Map<String, Object> tempUserData = new HashMap<>();
                tempUserData.put("name", name);
                tempUserData.put("roll", rollNumber);
                tempUserData.put("dept", department);
                tempUserData.put("year", year);
                tempUserData.put("user", user);
                tempUserData.put("pass", pass); 
                tempUserData.put("role", roleId);
                tempUserData.put("email", officialEmail);
                
                HttpSession session = request.getSession();
                session.setAttribute("tempUserData", tempUserData);
                session.setAttribute("registrationOtp", generatedOtp);

                // --- 5. SEND EMAIL & REDIRECT ---
                boolean isSent = EmailUtil.sendOtpEmail(officialEmail, generatedOtp);
                
                if (isSent) {
                    String maskedEmail = officialEmail.replaceAll("(^[^@]{2}|(?!^)\\G)[^@]", "$1*");
                    response.sendRedirect("otp_verify.jsp?email=" + maskedEmail);
                } else {
                    response.getWriter().println("<h1>Error</h1><p>Failed to send OTP to " + officialEmail + "</p>");
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
            response.getWriter().println("Error: " + e.getMessage());
        }
    }
}